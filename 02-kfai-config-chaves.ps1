# KFAI - Assistente de Configuração de Chaves (primeira vez / quando faltar)
# Detecta quais provedores de IA do 9Router ja tem chave e quais faltam.
# Para cada um que falta, mostra o link do site onde gerar a chave.
#
# Uso:
#   .\02-kfai-config-chaves.ps1             mostra o estado e guia a configuracao
#   .\02-kfai-config-chaves.ps1 -Adicionar  fluxo interativo: voce cola a chave e o
#                                        script SALVA DIRETO no 9Router (API local),
#                                        testa e opcionalmente adiciona os modelos
#                                        ao combo "todas-free" (usado pelos perfis).
#   .\02-kfai-config-chaves.ps1 -Open       abre os sites das chaves que faltam
#   .\02-kfai-config-chaves.ps1 -Test       so checa o estado (nao abre nada, nao pergunta)
#
# Seguranca: o script so le (somente-leitura) o banco local do 9Router para saber
# quais provedores ja estao configurados. A chave digitada no -Adicionar vai
# direto para a API local do 9Router (http://localhost:20128) e NUNCA e exibida
# nem gravada em arquivo pelo KFAI - quem guarda a chave e o proprio 9Router.
[CmdletBinding()]
param(
  [switch]$Adicionar, # fluxo interativo: colar chave e salvar no 9Router
  [switch]$Open,      # abre os sites das chaves que faltam sem perguntar
  [switch]$Test,      # so mostra o estado, sem perguntas
  [string]$DbPath     # (uso avancado) caminho do banco do 9Router
)
$ErrorActionPreference = 'Stop'

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
if(-not $Root -and $MyInvocation.MyCommand.Path){ $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if(-not $Root){ $Root = Get-Location }
$NodeStatusJs = Join-Path $Root "scripts\kfai-9router-status.js"

# Provedores de IA gratuitos que o 9Router entende, com o link onde gerar a chave.
# O usuario ja configurou -> nao aparece como "falta". O link e so para os que faltam.
# Tipo:
#   apikey  = aceita chave de API -> o fluxo -Adicionar consegue salvar a chave sozinho.
#   oauth   = conexao por login (abrir o painel do 9Router e clicar em "Conectar").
#   nenhuma = nao usa chave (self-hosted / sem login) - so configurar quando quiser.
$Providers = @(
  @{ Provider = 'openrouter';     Nome = 'OpenRouter';        Tipo = 'apikey'; Link = 'https://openrouter.ai/keys' ;               Como = 'Crie a conta, va em "Keys" e gere uma chave (comeca com sk-or-).' }
  @{ Provider = 'gemini';         Nome = 'Google Gemini';     Tipo = 'apikey'; Link = 'https://aistudio.google.com/apikey' ;        Como = 'Entre com sua conta Google, clique em "Get API key" e copie a chave (comeca com AIza).' }
  @{ Provider = 'nvidia';         Nome = 'NVIDIA NIM';        Tipo = 'apikey'; Link = 'https://build.nvidia.com' ;                 Como = 'Cadastre-se, escolha um modelo e clique em "Get API Key" (comeca com nvapi-).' }
  @{ Provider = 'cloudflare-ai';  Nome = 'Cloudflare AI';     Tipo = 'apikey'; Link = 'https://dash.cloudflare.com' ;              Como = 'Crie a conta e gere um API Token com acesso a "Workers AI".' }
  @{ Provider = 'api-airforce';   Nome = 'API.airforce';      Tipo = 'apikey'; Link = 'https://api.airforce' ;                    Como = 'Crie uma conta gratis; sua chave primaria ja aparece no Dashboard (comeca com sk-air-).' }
  @{ Provider = 'poolside';       Nome = 'Poolside';          Tipo = 'apikey'; Link = 'https://poolside.ai' ;                     Como = 'Entre com sua conta, va na aba "API Keys" e clique em "New key".' }
  @{ Provider = 'byteplus';       Nome = 'BytePlus ModelArk'; Tipo = 'apikey'; Link = 'https://www.byteplus.com' ;                Como = 'Crie a conta, va em IAM (Identity and Access Management) e gere um Access Key.' }
  @{ Provider = 'groq';           Nome = 'Groq';              Tipo = 'apikey'; Link = 'https://console.groq.com/keys' ;            Como = 'Crie a conta (sem cartao), va em "API Keys" e crie uma chave (comeca com gsk-).' }
  @{ Provider = 'cerebras';       Nome = 'Cerebras';          Tipo = 'apikey'; Link = 'https://cloud.cerebras.ai' ;               Como = 'Crie a conta, va em "API Keys" e gere uma chave.' }
  @{ Provider = 'mistral';        Nome = 'Mistral';           Tipo = 'apikey'; Link = 'https://console.mistral.ai/api-keys' ;     Como = 'Crie a conta (verificacao por telefone + opt-in), va em "API Keys" e crie uma chave.' }
  @{ Provider = 'cohere';         Nome = 'Cohere';            Tipo = 'apikey'; Link = 'https://dashboard.cohere.com/api-keys' ;   Como = 'Crie a conta, va em "API Keys" e crie uma chave.' }
  @{ Provider = 'huggingface';    Nome = 'HuggingFace';       Tipo = 'apikey'; Link = 'https://huggingface.co/settings/tokens' ;  Como = 'Crie a conta, va em "Access Tokens" e crie um token (comeca com hf_).' }
  @{ Provider = 'vercel-ai-gateway'; Nome = 'Vercel AI Gateway'; Tipo = 'apikey'; Link = 'https://vercel.com' ;                   Como = 'Crie a conta, va em "AI Gateway" e gere a chave do gateway.' }
  @{ Provider = 'bazaarlink';     Nome = 'Bazaarlink';        Tipo = 'apikey'; Link = 'https://bazaarlink.ai' ;                   Como = 'Crie a conta e gere a chave no painel.' }
  @{ Provider = 'kilo-gateway';   Nome = 'Kilo Gateway';      Tipo = 'apikey'; Link = 'https://kilo-gateway.com' ;                Como = 'Crie a conta e gere a chave (free tier).' }
  @{ Provider = 'ollama';         Nome = 'Ollama Cloud';      Tipo = 'apikey'; Link = 'https://ollama.com' ;                      Como = 'Crie a conta em ollama.com e gere uma chave (no painel).' }
  @{ Provider = 'gemini-cli';     Nome = 'Gemini CLI';        Tipo = 'oauth';  Link = 'https://aistudio.google.com' ;             Como = 'Conecte sua conta Google no 9Router (OAuth) para usar gratis.' }
  @{ Provider = 'kiro';           Nome = 'Kiro AI';           Tipo = 'oauth';  Link = 'https://kiro.ai' ;                        Como = 'Conecte a conta Kiro no 9Router (OAuth) para usar gratis.' }
  @{ Provider = 'kimchi';         Nome = 'Kimchi';            Tipo = 'oauth';  Link = 'https://kimchi.ai' ;                      Como = 'Conecte a conta Kimchi no 9Router (OAuth) para usar gratis.' }
  @{ Provider = 'mimo-free';      Nome = 'MiMo Code Free';    Tipo = 'nenhuma'; Link = 'https://xiaomi.com' ;                    Como = 'Sem chave: ative no 9Router (limite de uso diario).' }
  @{ Provider = 'opencode';       Nome = 'OpenCode Free';     Tipo = 'nenhuma'; Link = 'https://opencode.ai' ;                   Como = 'Sem chave: ative no 9Router.' }
  @{ Provider = 'searxng';        Nome = 'SearXNG';           Tipo = 'nenhuma'; Link = 'https://github.com/searxng/searxng' ;     Como = 'Self-hosted: instale o SearXNG e configure o endereco no 9Router.' }
  @{ Provider = 'edge-tts';       Nome = 'Edge TTS';          Tipo = 'nenhuma'; Link = 'https://github.com/rany2/edge-tts' ;      Como = 'Gratuito, sem chave: ative no 9Router.' }
  @{ Provider = 'coqui';          Nome = 'Coqui TTS';         Tipo = 'nenhuma'; Link = 'https://github.com/coqui-ai/TTS' ;        Como = 'Self-hosted: rode o Coqui localmente e configure no 9Router.' }
  @{ Provider = 'tortoise';       Nome = 'Tortoise TTS';      Tipo = 'nenhuma'; Link = 'https://github.com/neonbjb/tortoise-tts' ;Como = 'Self-hosted: rode o Tortoise localmente e configure no 9Router.' }
  @{ Provider = 'local-device';   Nome = 'Local Device';      Tipo = 'nenhuma'; Link = 'https://github.com/9router/local-ai-docs';Como = 'Self-hosted: use modelos locais (LLM/audio) via 9Router.' }
)

function Test-Port([int]$port){
  try {
    $c = New-Object Net.Sockets.TcpClient
    try { $c.Connect("127.0.0.1", $port); return $true } finally { $c.Dispose() }
  } catch { return $false }
}

# --- 1) Acha o banco do 9Router + o better-sqlite3 (ambos vem com o 9Router) ---
function Find-NineRouterDb {
  $cands = @(
    (Join-Path $env:APPDATA "9Router\db\data.sqlite"),
    (Join-Path $env:APPDATA "9router\db\data.sqlite")
  )
  foreach($c in $cands){ if(Test-Path -LiteralPath $c){ return $c } }
  return $null
}

function Find-BetterSqlite {
  $bases = @(
    (Join-Path $env:APPDATA "9Router\runtime\node_modules"),
    (Join-Path $env:APPDATA "9router\runtime\node_modules"),
    (Join-Path $env:APPDATA "npm\node_modules\9router\runtime\node_modules")
  )
  foreach($b in $bases){
    $p = Join-Path $b "better-sqlite3"
    if(Test-Path -LiteralPath $p){ return $p }
  }
  return $null
}

# --- 2) Lê quais providers estão configurados (sem expor segredos) ---
function Get-ConfiguredProviders {
  param([string]$Db, [string]$NodeJs, [string]$Better)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $json = (& $NodeJs $NodeStatusJs $Db $Better 2>$null | Select-Object -Last 1)
  $ErrorActionPreference = $prevEap
  if(-not $json){ return $null }
  try { $obj = $json | ConvertFrom-Json; return $obj.providers } catch { return $null }
}

$NodeJs = (Get-Command node -ErrorAction SilentlyContinue).Source
if(-not $NodeJs){ $NodeJs = "$env:ProgramFiles\nodejs\node.exe" }

# ============================================================================
# API local do 9Router (so no fluxo -Adicionar). Mesmo token que o CLI usa:
#   token = sha256(machine-id + "9r-cli-auth" + cli-secret)[0..15]
# Os arquivos machine-id e cli-secret sao criados pelo proprio 9Router e ficam
# em %APPDATA%\9router. NUNCA exibir o token ou a chave digitada.
# ============================================================================
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
      return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -TimeoutSec 40
    }
    return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers `
      -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 6) -TimeoutSec 40
  } catch {
    $err = $_.Exception.Message
    try {
      $det = $_.ErrorDetails.Message
      if($det){ $j = $det | ConvertFrom-Json; if($j.error){ $err = $j.error } }
    } catch {}
    return [pscustomobject]@{ error = $err }
  }
}

# Fluxo interativo: colar a chave e salvar DIRETO no 9Router via API local.
function Add-ProviderKeyInteractive {
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

  Write-Host "`n=== ADICIONAR CHAVE (via API local do 9Router) ===" -ForegroundColor Cyan
  Write-Host "Voce cola a chave aqui e o KFAI salva direto no 9Router (nada fica em arquivo)." -ForegroundColor DarkGray

  $combos = Invoke-9RApi -Method GET -Path "/api/combos"
  $todasFree = $null
  if($combos -and $combos.combos){ $todasFree = @($combos.combos) | Where-Object { $_.name -eq 'todas-free' } | Select-Object -First 1 }

  $comChave = @($Providers | Where-Object { $_.Tipo -eq 'apikey' })

  while($true){
    # Atualiza o estado real das conexoes com chave
    $provs = Invoke-9RApi -Method GET -Path "/api/providers"
    $conns = @()
    if($provs -and $provs.connections){ $conns = @($provs.connections) }
    $temKey = @{}
    foreach($c in $conns){
      if($c.provider){ $temKey[$c.provider] = $true }
    }

    Write-Host "`nProvedores grátis com chave:" -ForegroundColor White
    $faltando = @()
    foreach($p in $comChave){
      if($temKey[$p.Provider]){
        Write-Host ("  [OK] {0}" -f $p.Nome) -ForegroundColor Green
      } else {
        $faltando += $p
      }
    }

    if($faltando.Count -eq 0){
      Write-Host "`nTodas as chaves gratuitas estao configuradas!" -ForegroundColor Green
      return
    }

    Write-Host "`nFaltam configurar:" -ForegroundColor Yellow
    for($n=0; $n -lt $faltando.Count; $n++){
      Write-Host ("  [{0,2}] {1}" -f ($n+1), $faltando[$n].Nome) -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Escolha o numero do provedor para colar a chave (ou 0 para sair):" -ForegroundColor Cyan
    $sel = Read-Host "> "
    if($sel -match '^0$' -or $sel -eq ''){ Write-Host "Nada adicionado." -ForegroundColor DarkGray; return }
    $idx = 0
    if(-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $faltando.Count){
      Write-Host "Escolha invalida. Tente de novo." -ForegroundColor Yellow
      continue
    }

    $prov = $faltando[$idx-1]
    Write-Host ""
    Write-Host ("== {0} ==" -f $prov.Nome) -ForegroundColor White
    Write-Host ("Link para gerar: {0}" -f $prov.Link) -ForegroundColor Cyan
    Write-Host $prov.Como -ForegroundColor DarkGray

    $nome = Read-Host ("Nome da conexao [padrao: {0}]: " -f $prov.Provider)
    if(-not $nome){ $nome = $prov.Provider }

    Write-Host "Cole a chave agora (nao aparecera na tela):"
    $secKey = Read-Host "> " -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secKey)
    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    if(-not $apiKey){
      Write-Host "Chave vazia. Cancelado." -ForegroundColor Yellow
      continue
    }

    Write-Host "Salvando no 9Router..." -ForegroundColor DarkGray
    $resp = Invoke-9RApi -Method POST -Path "/api/providers" -Body @{ provider = $prov.Provider; name = $nome; apiKey = $apiKey }
    $apiKey = $null

    if(-not $resp -or $resp.error){
      Write-Host ("FALHA ao salvar: {0}" -f ($resp.error)) -ForegroundColor Red
      Write-Host "Confira se a chave esta correta e se o provedor existe no 9Router." -ForegroundColor DarkGray
      continue
    }

    $connId = $resp.connection.id
    $connNome = $resp.connection.name
    Write-Host ("Chave salva! Conexao: {0}" -f $connNome) -ForegroundColor Green

    # Testa a conexao
    $respTest = Invoke-9RApi -Method POST -Path "/api/providers/$connId/test"
    if($respTest -and $respTest.valid){
      Write-Host "  [OK] conexao testada com sucesso." -ForegroundColor Green
    } elseif($respTest -and $respTest.valid -eq $false){
      Write-Host "  [atencao] conexao salva, mas o teste falhou: $($respTest.error)" -ForegroundColor Yellow
      Write-Host "  A chave pode estar errada ou o servico pode estar lento. Confira no painel." -ForegroundColor DarkGray
    } else {
      Write-Host "  [info] nao foi possivel testar agora (pode demorar/estar offline)." -ForegroundColor DarkGray
    }

    # Oferece adicionar os modelos ao combo todas-free (usado pelos perfis full-cloud)
    if($todasFree){
      $perg = Read-Host "Adicionar os modelos deste provedor ao combo 'todas-free' (usado nos perfis)? (s/N)"
      if($perg -match '^(s|sim|y|yes)$'){
        $m = Invoke-9RApi -Method GET -Path "/api/providers/$connId/models"
        $novos = @()
        if($m -and $m.models){
          $atuais = @($todasFree.models)
          foreach($md in @($m.models)){
            if($md.id){
              $comboModelo = "{0}/{1}" -f $prov.Provider, $md.id
              if($atuais -notcontains $comboModelo){ $novos += $comboModelo }
            }
          }
        }
        if($novos.Count -eq 0){
          Write-Host "  Nenhum modelo novo para adicionar (ja estao todos no combo)." -ForegroundColor DarkGray
        } else {
          $upd = Invoke-9RApi -Method PUT -Path "/api/combos/$($todasFree.id)" -Body @{ models = @(@($todasFree.models) + $novos) }
          if($upd -and -not $upd.error){
            Write-Host ("  [OK] {0} modelo(s) adicionados ao combo todas-free." -f $novos.Count) -ForegroundColor Green
          } else {
            Write-Host ("  Nao consegui adicionar ao combo: {0}" -f $upd.error) -ForegroundColor Yellow
            Write-Host "  Voce pode adicionar manualmente no painel: Perfis/Combos." -ForegroundColor DarkGray
          }
        }
      }
    } else {
      Write-Host "  (combo 'todas-free' nao encontrado; seus modelos aparecem como $($prov.Provider)/... no painel)" -ForegroundColor DarkGray
    }
    Write-Host ""
  }
}


Write-Host ""
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "  KFAI - Configuracao das chaves de IA (primeira vez)" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host ""

$Db = $DbPath
if(-not $Db){ $Db = Find-NineRouterDb }
$Better = Find-BetterSqlite
$NineUp = Test-Port 20128

if(-not $Db -or -not $Better){
  Write-Host "O 9Router (roteador de IA em nuvem) ainda nao esta instalado." -ForegroundColor Yellow
  Write-Host "Rode primeiro o instalador: .\01-install.ps1  (ele instala o 9Router)." -ForegroundColor Yellow
  Write-Host "Depois volte aqui para configurar as chaves."
  exit 1
}

$Configured = Get-ConfiguredProviders -Db $Db -NodeJs $NodeJs -Better $Better
if($null -eq $Configured){
  Write-Host "Nao consegui ler o 9Router. Se ele estiver rodando, tente fechar e abrir de novo." -ForegroundColor Yellow
  exit 1
}

# Modo -Adicionar: fluxo interativo que salva a chave direto no 9Router.
if($Adicionar){
  Add-ProviderKeyInteractive
  exit 0
}

# Mapa provider -> tem chave salva
$hasKey = @{}
$isAct  = @{}
foreach($p in $Configured){
  if($p.provider){ $hasKey[$p.provider] = ($p.hasKey -and $p.isActive); $isAct[$p.provider] = $p.isActive }
}

$Faltando = @()
$Ok = @()
foreach($prov in $Providers){
  $status = $hasKey[$prov.Provider]
  if($status){ $Ok += $prov } else { $Faltando += $prov }
}

# Ollama LOCAL (id 'ollama-local' no 9Router) nao precisa de chave. O 'ollama'
# da tabela acima e o Ollama Cloud (chave de API) e ja e tratado normalmente.
$OllamaLocalOk = $hasKey['ollama-local']

# Providers que o usuario tem no 9Router mas nao estao na lista acima (so info)
$Outros = @()
foreach($p in $Configured){
  if($p.provider -and -not ($Providers | Where-Object { $_.Provider -eq $p.provider }) -and $p.hasKey){
    $Outros += $p.provider
  }
}

Write-Host "Estado do 9Router: $(if($NineUp){'rodando (porta 20128)'} else {'instalado mas PARADO (inicie com 05-kfai-start.ps1)'})" -ForegroundColor $(if($NineUp){'Green'}else{'Yellow'})
Write-Host ""

if($Ok.Count -gt 0){
  Write-Host "Ja configurados (OK):" -ForegroundColor Green
  foreach($p in $Ok){
    Write-Host ("  [OK] {0}" -f $p.Nome) -ForegroundColor Green
  }
}

if($OllamaLocalOk){
  Write-Host "  [OK] Ollama (local) configurado" -ForegroundColor Green
} else {
  Write-Host "  [info] Ollama (local): IA que roda no seu PC, nao precisa de chave. Instale em https://ollama.com" -ForegroundColor DarkGray
}
Write-Host ""

if($Faltando.Count -eq 0){
  Write-Host "Nenhuma chave faltando. Seu KFAI esta pronto para usar IA gratuita na nuvem!" -ForegroundColor Green
  if($Test){ exit 0 }
  Read-Host "Pressione Enter para fechar"
  exit 0
}

Write-Host ("FALTAM {0} chave(s) para usar a IA gratuita na nuvem:" -f $Faltando.Count) -ForegroundColor Yellow
Write-Host ""
for($i=0; $i -lt $Faltando.Count; $i++){
  $p = $Faltando[$i]
  Write-Host ("{0}) {1}" -f ($i+1), $p.Nome) -ForegroundColor White
  Write-Host ("   Link: {0}" -f $p.Link) -ForegroundColor Cyan
  Write-Host ("   Como: {0}" -f $p.Como) -ForegroundColor DarkGray
  Write-Host ""
}
if($Outros.Count -gt 0){
  Write-Host "Extra: voce tambem tem: $($Outros -join ', ')" -ForegroundColor DarkGray
  Write-Host ""
}

Write-Host "Depois de gerar cada chave, rode:  .\02-kfai-config-chaves.ps1 -Adicionar" -ForegroundColor White
Write-Host "Ele salva a chave direto no 9Router e testa, sem voce abrir o painel." -ForegroundColor DarkGray

$doOpen = $Open
if(-not $doOpen -and -not $Test){
  $resp = ''
  try { $resp = Read-Host "Quer que eu abra o navegador nos sites das chaves que faltam? (s/N)" } catch { $resp = '' }
  $doOpen = ($resp -match '^(s|sim|y|yes)$')
}
if($doOpen){
  Write-Host ""
  Write-Host "Abrindo os sites das chaves que faltam..." -ForegroundColor Cyan
  foreach($p in $Faltando){
    Write-Host ("  -> {0}: {1}" -f $p.Nome, $p.Link) -ForegroundColor DarkGray
    Start-Process $p.Link
    Start-Sleep -Milliseconds 700
  }
}

if($Test){ exit 2 }

Write-Host ""
Write-Host "Para salvar as chaves que voce gerou, tem duas opcoes:" -ForegroundColor Cyan
Write-Host "  1) Automatico: .\02-kfai-config-chaves.ps1 -Adicionar  (cola a chave, salva e testa)" -ForegroundColor White
Write-Host "  2) Manual:     abrir o painel http://localhost:20128/dashboard e colar cada chave" -ForegroundColor White
Write-Host ""
$resp = ''
try { $resp = Read-Host "Quer que eu rode o -Adicionar agora? (s/N)" } catch { $resp = '' }
if($resp -match '^(s|sim|y|yes)$'){
  if(-not $NineUp){
    Write-Host "O 9Router esta parado. Iniciando..." -ForegroundColor Yellow
    $start = Join-Path $Root "05-kfai-start.ps1"
    if(Test-Path $start){
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start | Out-Null
      Start-Sleep -Seconds 3
    }
  }
  Add-ProviderKeyInteractive
} else {
  Write-Host "Abra o painel do 9Router para colar as chaves geradas." -ForegroundColor Cyan
  Write-Host "  Painel: http://localhost:20128/dashboard" -ForegroundColor Cyan
  $resp = ''
  try { $resp = Read-Host "Abrir o painel do 9Router agora? (s/N)" } catch { $resp = '' }
  if($resp -match '^(s|sim|y|yes)$'){
    if(-not $NineUp){
      Write-Host "O 9Router esta parado. Iniciando..." -ForegroundColor Yellow
      $start = Join-Path $Root "05-kfai-start.ps1"
      if(Test-Path $start){
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start | Out-Null
        Start-Sleep -Seconds 3
      }
    }
    Start-Process "http://localhost:20128/dashboard"
  }
}
Write-Host ""
Write-Host "Depois de colar as chaves no painel, rode de novo:" -ForegroundColor Green
Write-Host "  .\02-kfai-config-chaves.ps1   (para conferir se tudo ficou certo)" -ForegroundColor Green
Read-Host "Pressione Enter para fechar"
