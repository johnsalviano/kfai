# KFAI - Assistente de Provedores Custom (Provider Nodes) do 9Router
# Conecta servicos de IA que NAO estao no catalogo do 9Router usando endpoints
# compativeis com OpenAI (ex.: https://SUA_API/v1/chat/completions) ou com
# Anthropic (ex.: https://SUA_API/v1/messages).
#
# Uso:
#   .\03-kfai-config-provider-nodes.ps1               mostra o estado (nodes existentes)
#   .\03-kfai-config-provider-nodes.ps1 -Adicionar    fluxo interativo: cria o node,
#                                                  salva a chave no 9Router, testa
#                                                  e opcionalmente adiciona modelos
#                                                  ao combo "todas-free".
#   .\03-kfai-config-provider-nodes.ps1 -Remover      apaga um node existente
#   .\03-kfai-config-provider-nodes.ps1 -Test         so mostra o estado, sem perguntas
#
# Como funciona por baixo:
#   O 9Router chama isso de "provider node": um endereco + prefixo que voce
#   registra na API local (http://localhost:20128). Depois de registrar, o node
#   vira um "provedor" normal: voce cola a chave de API, testa e usa em combos
#   com o nome <prefixo>/<modelo>.
#
#   Endpoints usados (mesma API local que o painel usa):
#     POST /api/provider-nodes          cria o node {name, prefix, apiType?, baseUrl, type}
#     POST /api/provider-nodes/validate testa baseUrl + chave antes de criar
#     POST /api/providers               salva a chave de API do node
#     POST /api/providers/:id/test      testa a conexao com a chave
#     DELETE /api/provider-nodes/:id    apaga o node
#
# Seguranca: a chave digitada vai direto do seu teclado para a API local do
# 9Router (localhost:20128) e NUNCA e exibida, gravada em arquivo ou enviada
# para fora. Quem guarda a chave e o proprio 9Router.
[CmdletBinding()]
param(
  [switch]$Adicionar, # fluxo interativo: criar node + salvar chave + testar
  [switch]$Remover,   # apagar um node existente
  [switch]$Test       # so mostra o estado, sem perguntar
)
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Test-Port([int]$port){
  try {
    $c = New-Object Net.Sockets.TcpClient
    try { $c.Connect("127.0.0.1", $port); return $true } finally { $c.Dispose() }
  } catch { return $false }
}

# Mesmo token que o CLI do 9Router usa:
#   token = sha256(machine-id + "9r-cli-auth" + cli-secret)[0..15]
# Os arquivos ficam em %APPDATA%\9router. Nunca exibir o token nem a chave.
function Get-CliToken {
  $base = Join-Path $env:APPDATA "9router"
  $mid  = (Get-Content -LiteralPath (Join-Path $base "machine-id") -Raw -ErrorAction SilentlyContinue).Trim()
  $sec  = (Get-Content -LiteralPath (Join-Path $base "auth\cli-secret") -Raw -ErrorAction SilentlyContinue).Trim()
  if(-not $mid -or -not $sec){ return $null }
  $sha    = [System.Security.Cryptography.SHA256]::Create()
  $bytes  = [System.Text.Encoding]::UTF8.GetBytes($mid + "9r-cli-auth" + $sec)
  $hex    = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
  return $hex.Substring(0, 16)
}

function Invoke-9RApi {
  param([string]$Method, [string]$Path, $Body = $null)
  $headers = @{ "x-9r-cli-token" = $script:CliToken }
  $uri = "http://localhost:20128$Path"
  try {
    if($null -eq $Body){
      return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -TimeoutSec 60
    }
    return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers `
      -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 8) -TimeoutSec 60
  } catch {
    $err = $_.Exception.Message
    try {
      $det = $_.ErrorDetails.Message
      if($det){ $j = $det | ConvertFrom-Json; if($j.error){ $err = $j.error } }
    } catch {}
    return [pscustomobject]@{ error = $err }
  }
}

# Lista os nodes custom e as conexoes (chaves) associadas a cada um.
function Show-Status {
  $nodes = Invoke-9RApi -Method GET -Path "/api/provider-nodes"
  $nodeList = @()
  if($nodes -and $nodes.nodes){ $nodeList = @($nodes.nodes) }

  if($nodeList.Count -eq 0){
    Write-Host "Nenhum provedor custom cadastrado ainda." -ForegroundColor DarkGray
    Write-Host "Para conectar um servico fora do catalogo (endpoint OpenAI/Anthropic-compatible):" -ForegroundColor DarkGray
    Write-Host "  .\03-kfai-config-provider-nodes.ps1 -Adicionar" -ForegroundColor White
    return
  }

  # Conexoes do 9Router para saber quais nodes ja tem chave salva
  $conns = @()
  $provs = Invoke-9RApi -Method GET -Path "/api/providers"
  if($provs -and $provs.connections){ $conns = @($provs.connections) }

  Write-Host "Provedores custom cadastrados:" -ForegroundColor White
  foreach($n in $nodeList){
    $tipo = if($n.type -eq 'anthropic-compatible'){ 'Anthropic-compatible' } elseif($n.type -eq 'openai-compatible'){ 'OpenAI-compatible' } else { $n.type }
    $temChave = @($conns) | Where-Object { $_.provider -eq $n.id }
    $flag = if($temChave){ 'chave salva' } else { 'SEM chave' }
    $cor = if($temChave){ 'Green' } else { 'Yellow' }
    Write-Host ("  [{0}] {1}" -f $flag, $n.name) -ForegroundColor $cor
    Write-Host ("       tipo: {0} | prefixo: {1}" -f $tipo, $n.prefix) -ForegroundColor DarkGray
    Write-Host ("       baseUrl: {0}" -f $n.baseUrl) -ForegroundColor DarkGray
    if($n.apiType){ Write-Host ("       API: {0}" -f $n.apiType) -ForegroundColor DarkGray }
    Write-Host ("       id: {0}" -f $n.id) -ForegroundColor DarkGray
  }
}

# ---------------------------------------------------------------------------
# Fluxo interativo de adicao
# ---------------------------------------------------------------------------
function Add-ProviderNodeInteractive {
  $script:CliToken = Get-CliToken
  if(-not $script:CliToken){
    Write-Host "Nao consegui autenticar no 9Router (machine-id/cli-secret nao encontrados)." -ForegroundColor Yellow
    Write-Host "Abra o painel http://localhost:20128 uma vez e tente de novo." -ForegroundColor DarkGray
    return
  }
  if(-not (Test-Port 20128)){
    Write-Host "O 9Router esta PARADO. Inicie primeiro com: .\05-kfai-start.ps1" -ForegroundColor Yellow
    return
  }

  Write-Host ""
  Write-Host "=== ADICIONAR PROVEDOR CUSTOM (endpoint OpenAI/Anthropic-compatible) ===" -ForegroundColor Cyan
  Write-Host "Serve para conectar servicos de IA que nao estao no catalogo do 9Router." -ForegroundColor DarkGray
  Write-Host "A chave vai direto para o 9Router (nada fica em arquivo)." -ForegroundColor DarkGray

  # 1) Tipo do node
  Write-Host ""
  Write-Host "Qual o tipo de endpoint?" -ForegroundColor White
  Write-Host "  [1] OpenAI-compatible  (ex.: https://SUA_API/v1/chat/completions)" -ForegroundColor White
  Write-Host "  [2] Anthropic-compatible (ex.: https://SUA_API/v1/messages)" -ForegroundColor White
  $sel = Read-Host "> "
  $tipo = 'openai-compatible'
  if($sel -match '^2$'){ $tipo = 'anthropic-compatible' }

  # 2) Nome
  $nome = Read-Host "Nome (ex.: Meu Gateway de IA)"
  if(-not $nome){ $nome = "Custom $tipo" }

  # 3) Prefixo (aparece nos combos como <prefixo>/<modelo>)
  Write-Host 'Prefixo curto e unico (sem espacos). Ele e o "nome" do provedor nos combos:' -ForegroundColor DarkGray
  $prefixo = Read-Host "Prefixo (ex.: meu-gateway)"
  if(-not $prefixo){ $prefixo = 'custom' }
  $prefixo = $prefixo.Trim().ToLower() -replace '\s+','-'

  # 4) API type (so OpenAI-compatible)
  $apiType = $null
  if($tipo -eq 'openai-compatible'){
    Write-Host ""
    Write-Host "Formato de API:" -ForegroundColor White
    Write-Host "  [1] Chat Completions (/chat/completions)" -ForegroundColor White
    Write-Host "  [2] Responses API (/responses)" -ForegroundColor White
    $selApi = Read-Host "> "
    $apiType = if($selApi -match '^2$'){ 'responses' } else { 'chat' }
  }

  # 5) Base URL
  $padrao = if($tipo -eq 'anthropic-compatible'){ 'https://api.anthropic.com/v1' } else { 'https://api.openai.com/v1' }
  $baseUrl = Read-Host "Base URL [padrao: $padrao]"
  if(-not $baseUrl){ $baseUrl = $padrao }

  Write-Host ""
  Write-Host ("Resumo: tipo={0}  prefixo={1}  baseUrl={2}" -f $tipo, $prefixo, $baseUrl) -ForegroundColor Cyan
  if($apiType){ Write-Host ("        apiType={0}" -f $apiType) -ForegroundColor Cyan }

  # 6) (Opcional) testar o endpoint com uma chave antes de salvar
  $perg = Read-Host "Quer testar o endpoint agora com a chave de API (recomendado)? (s/N)"
  if($perg -match '^(s|sim|y|yes)$'){
    Write-Host "Cole a chave de API do servico (nao aparecera na tela):"
    $secKey = Read-Host "> " -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secKey)
    $apiKeyTmp = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    if($apiKeyTmp){
      $modelo = Read-Host "Id de um modelo para testar (opcional, so Enter para pular)"
      $valBody = @{ baseUrl = $baseUrl; apiKey = $apiKeyTmp; type = $tipo }
      if($modelo){ $valBody.modelId = $modelo }
      Write-Host "Testando endpoint..." -ForegroundColor DarkGray
      $val = Invoke-9RApi -Method POST -Path "/api/provider-nodes/validate" -Body $valBody
      if($val -and $val.valid){
        Write-Host "  [OK] endpoint respondeu com a chave." -ForegroundColor Green
      } else {
        Write-Host ("  [atencao] o endpoint nao passou no teste: {0}" -f ($val.error)) -ForegroundColor Yellow
        Write-Host "  Pode ser chave errada, URL errada ou o servico nao aceitar o teste." -ForegroundColor DarkGray
        $continuar = Read-Host "Mesmo assim quer salvar o node? (s/N)"
        if(-not ($continuar -match '^(s|sim|y|yes)$')){ Write-Host "Cancelado." -ForegroundColor DarkGray; return }
      }
      $apiKeyTmp = $null
    } else {
      Write-Host "Chave vazia, seguindo sem o teste." -ForegroundColor Yellow
    }
  }

  # 7) Cria o node
  Write-Host "Criando o node no 9Router..." -ForegroundColor DarkGray
  $nodeBody = @{ name = $nome; prefix = $prefixo; baseUrl = $baseUrl; type = $tipo }
  if($apiType){ $nodeBody.apiType = $apiType }
  $nodeResp = Invoke-9RApi -Method POST -Path "/api/provider-nodes" -Body $nodeBody
  if(-not $nodeResp -or $nodeResp.error){
    Write-Host ("FALHA ao criar o node: {0}" -f ($nodeResp.error)) -ForegroundColor Red
    return
  }
  $node = $nodeResp.node
  $nodeId = $node.id
  Write-Host ("  [OK] node criado: {0}" -f $node.name) -ForegroundColor Green
  Write-Host ("       id: {0}" -f $nodeId) -ForegroundColor DarkGray

  # 8) Salva a chave de API do node (se tiver)
  $pergKey = Read-Host "Salvar a chave de API deste provedor no 9Router agora? (s/N)"
  $connId = $null
  if($pergKey -match '^(s|sim|y|yes)$'){
    Write-Host "Cole a chave de API (nao aparecera na tela):"
    $secKey = Read-Host "> " -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secKey)
    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    if(-not $apiKey){
      Write-Host "Chave vazia; o node ficou salvo, mas sem chave." -ForegroundColor Yellow
    } else {
      $connNome = Read-Host ("Nome da conexao [padrao: {0}]: " -f $node.name)
      if(-not $connNome){ $connNome = $node.name }
      $resp = Invoke-9RApi -Method POST -Path "/api/providers" -Body @{ provider = $nodeId; name = $connNome; apiKey = $apiKey }
      $apiKey = $null
      if(-not $resp -or $resp.error){
        Write-Host ("FALHA ao salvar a chave: {0}" -f ($resp.error)) -ForegroundColor Red
        Write-Host "O node continua salvo; a chave pode ser adicionada depois no painel." -ForegroundColor DarkGray
      } else {
        $connId = $resp.connection.id
        Write-Host "  [OK] chave salva no 9Router." -ForegroundColor Green

        $respTest = Invoke-9RApi -Method POST -Path "/api/providers/$connId/test"
        if($respTest -and $respTest.valid){
          Write-Host "  [OK] conexao testada com sucesso." -ForegroundColor Green
        } elseif($respTest -and $respTest.valid -eq $false){
          Write-Host ("  [atencao] conexao salva, mas o teste falhou: {0}" -f $respTest.error) -ForegroundColor Yellow
          Write-Host "  Confira a base URL e a chave no painel do 9Router." -ForegroundColor DarkGray
        } else {
          Write-Host "  [info] nao foi possivel testar agora." -ForegroundColor DarkGray
        }
      }
    }
  }

  # 9) Oferece adicionar modelos ao combo todas-free
  $combos = Invoke-9RApi -Method GET -Path "/api/combos"
  $todasFree = $null
  if($combos -and $combos.combos){ $todasFree = @($combos.combos) | Where-Object { $_.name -eq 'todas-free' } | Select-Object -First 1 }
  if($todasFree){
    $pergCombo = Read-Host "Adicionar modelos deste provedor ao combo 'todas-free'? (s/N)"
    if($pergCombo -match '^(s|sim|y|yes)$'){
      Write-Host "Digite os ids dos modelos separados por virgula (o combo ganhara <prefixo>/<modelo>):"
      $lista = Read-Host "Ex.: claude-3-5-sonnet, gpt-4o-mini"
      $ids = @($lista -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      $novos = @()
      if($ids.Count -gt 0){
        $atuais = @($todasFree.models)
        foreach($id in $ids){
          $comboModelo = "{0}/{1}" -f $prefixo, $id
          if($atuais -notcontains $comboModelo){ $novos += $comboModelo }
        }
        if($novos.Count -eq 0){
          Write-Host "  Nenhum modelo novo para adicionar (ja estao todos no combo)." -ForegroundColor DarkGray
        } else {
          $upd = Invoke-9RApi -Method PUT -Path "/api/combos/$($todasFree.id)" -Body @{ models = @(@($todasFree.models) + $novos) }
          if($upd -and -not $upd.error){
            Write-Host ("  [OK] {0} modelo(s) adicionados ao combo todas-free." -f $novos.Count) -ForegroundColor Green
          } else {
            Write-Host ("  Nao consegui adicionar ao combo: {0}" -f $upd.error) -ForegroundColor Yellow
          }
        }
      } else {
        Write-Host "  Nenhum id informado; nada adicionado." -ForegroundColor DarkGray
      }
    }
  } else {
    Write-Host ("  (combo 'todas-free' nao encontrado; os modelos aparecem como {0}/... no painel)" -f $prefixo) -ForegroundColor DarkGray
  }

  Write-Host ""
  Write-Host ("Pronto! No agente, use o modelo como  {0}/<modelo>  (ou no combo, se adicionou)." -f $prefixo) -ForegroundColor Green
  Write-Host "Para conferir:  .\03-kfai-config-provider-nodes.ps1" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Fluxo interativo de remocao
# ---------------------------------------------------------------------------
function Remove-ProviderNodeInteractive {
  $script:CliToken = Get-CliToken
  if(-not $script:CliToken){
    Write-Host "Nao consegui autenticar no 9Router." -ForegroundColor Yellow
    return
  }
  if(-not (Test-Port 20128)){
    Write-Host "O 9Router esta PARADO. Inicie primeiro com: .\05-kfai-start.ps1" -ForegroundColor Yellow
    return
  }

  $nodes = Invoke-9RApi -Method GET -Path "/api/provider-nodes"
  $nodeList = @()
  if($nodes -and $nodes.nodes){ $nodeList = @($nodes.nodes) }
  if($nodeList.Count -eq 0){
    Write-Host "Nenhum provedor custom para remover." -ForegroundColor Yellow
    return
  }

  Write-Host "`nProvedores custom cadastrados:" -ForegroundColor White
  for($n=0; $n -lt $nodeList.Count; $n++){
    $tipo = if($nodeList[$n].type -eq 'anthropic-compatible'){ 'Anthropic' } elseif($nodeList[$n].type -eq 'openai-compatible'){ 'OpenAI' } else { $nodeList[$n].type }
    Write-Host ("  [{0,2}] {1}  ({2}-compatible, prefixo {3})" -f ($n+1), $nodeList[$n].name, $tipo, $nodeList[$n].prefix) -ForegroundColor White
  }
  Write-Host "Qual voce quer remover? (0 para cancelar)" -ForegroundColor Cyan
  $sel = Read-Host "> "
  $idx = 0
  if(-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $nodeList.Count){
    Write-Host "Cancelado." -ForegroundColor DarkGray
    return
  }
  $node = $nodeList[$idx-1]
  $conf = Read-Host ("Remover o node '{0}'? Isso apaga o node do 9Router. (s/N)" -f $node.name)
  if(-not ($conf -match '^(s|sim|y|yes)$')){ Write-Host "Cancelado." -ForegroundColor DarkGray; return }

  # Apaga a conexao (chave) ligada ao node, se existir
  $provs = Invoke-9RApi -Method GET -Path "/api/providers"
  $conns = @()
  if($provs -and $provs.connections){ $conns = @($provs.connections) }
  foreach($c in $conns){
    if($c.provider -eq $node.id){
      Invoke-9RApi -Method DELETE -Path "/api/providers/$($c.id)" | Out-Null
      Write-Host ("  Chave da conexao '{0}' removida." -f $c.name) -ForegroundColor DarkGray
    }
  }

  $del = Invoke-9RApi -Method DELETE -Path "/api/provider-nodes/$($node.id)"
  if($del -and $del.success){
    Write-Host ("  [OK] node '{0}' removido." -f $node.name) -ForegroundColor Green
  } else {
    Write-Host ("  Nao consegui remover o node: {0}" -f $del.error) -ForegroundColor Red
  }
}

# ---------------------------------------------------------------------------
# Entrada principal
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "  KFAI - Provedores Custom (Provider Nodes) do 9Router" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host ""

if($Adicionar){
  Add-ProviderNodeInteractive
  exit 0
}
if($Remover){
  Remove-ProviderNodeInteractive
  exit 0
}

$NineUp = Test-Port 20128
$ok = $true
if(-not $NineUp){
  Write-Host "O 9Router esta PARADO (porta 20128). Inicie com: .\05-kfai-start.ps1" -ForegroundColor Yellow
  Write-Host "Sem ele nao da para listar os nodes custom." -ForegroundColor Yellow
  if($Test){ exit 2 }
  Read-Host "Pressione Enter para fechar"
  exit 1
}

$script:CliToken = Get-CliToken
if(-not $script:CliToken){
  Write-Host "Nao consegui autenticar no 9Router. Abra o painel http://localhost:20128 uma vez." -ForegroundColor Yellow
  if($Test){ exit 2 }
  Read-Host "Pressione Enter para fechar"
  exit 1
}

Show-Status

Write-Host ""
Write-Host "Comandos:" -ForegroundColor Cyan
Write-Host "  .\03-kfai-config-provider-nodes.ps1 -Adicionar   criar novo provedor custom" -ForegroundColor White
Write-Host "  .\03-kfai-config-provider-nodes.ps1 -Remover     remover um provedor custom" -ForegroundColor White

if($Test){ exit 0 }
Write-Host ""
Read-Host "Pressione Enter para fechar"
exit 0
