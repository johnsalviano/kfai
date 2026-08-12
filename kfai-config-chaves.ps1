# KFAI - Assistente de Configuração de Chaves (primeira vez / quando faltar)
# Detecta quais provedores de IA do 9Router ja tem chave e quais faltam.
# Para cada um que falta, mostra o link do site onde gerar a chave e, no final,
# abre o painel do 9Router para o usuario colar as chaves geradas.
#
# Uso:
#   .\kfai-config-chaves.ps1          mostra o estado e guia a configuracao
#   .\kfai-config-chaves.ps1 -Open    abre automaticamente os sites das chaves que faltam
#   .\kfai-config-chaves.ps1 -Test    so checa o estado (nao abre nada, nao pergunta)
#
# Nenhuma chave e exibida ou salva por este script: ele so le (somente-leitura)
# o banco local do 9Router para saber quais provedores ja estao configurados.
[CmdletBinding()]
param(
  [switch]$Open,    # abre os sites das chaves que faltam sem perguntar
  [switch]$Test,    # so mostra o estado, sem perguntas
  [string]$DbPath   # (uso avancado) caminho do banco do 9Router
)
$ErrorActionPreference = 'Stop'

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
if(-not $Root -and $MyInvocation.MyCommand.Path){ $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if(-not $Root){ $Root = Get-Location }
$NodeStatusJs = Join-Path $Root "scripts\kfai-9router-status.js"

# Providers de IA gratuitos que o 9Router entende, com o link onde gerar a chave.
# O usuario ja configurou -> nao aparece como "falta". O link e so para os que faltam.
$Providers = @(
  @{ Provider = 'openrouter';     Nome = 'OpenRouter';        Link = 'https://openrouter.ai/keys' ;   Como = 'Crie a conta, va em "Keys" e gere uma chave (comeca com sk-or-).' }
  @{ Provider = 'gemini';         Nome = 'Google Gemini';     Link = 'https://aistudio.google.com' ; Como = 'Entre com sua conta Google, clique em "Get API key" e copie a chave (comeca com AIza).' }
  @{ Provider = 'nvidia';         Nome = 'NVIDIA NIM';        Link = 'https://build.nvidia.com' ;    Como = 'Cadastre-se, escolha um modelo e clique em "Get API Key" (comeca com nvapi-).' }
  @{ Provider = 'cloudflare-ai';  Nome = 'Cloudflare AI';     Link = 'https://dash.cloudflare.com' ; Como = 'Crie a conta e gere um API Token com acesso a "Workers AI".' }
  @{ Provider = 'api-airforce';   Nome = 'API.airforce';      Link = 'https://api.airforce' ;        Como = 'Crie uma conta gratis; sua chave primaria ja aparece no Dashboard (comeca com sk-air-).' }
  @{ Provider = 'poolside';       Nome = 'Poolside';          Link = 'https://platform.poolside.ai' ;Como = 'Entre com sua conta, va na aba "API Keys" e clique em "New key".' }
  @{ Provider = 'byteplus';       Nome = 'BytePlus ModelArk'; Link = 'https://console.volcengine.com/iam' ; Como = 'Crie a conta, va em IAM (Identity and Access Management) e gere um Access Key.' }
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
  Write-Host "Rode primeiro o instalador: .\install.ps1  (ele instala o 9Router)." -ForegroundColor Yellow
  Write-Host "Depois volte aqui para configurar as chaves."
  exit 1
}

$Configured = Get-ConfiguredProviders -Db $Db -NodeJs $NodeJs -Better $Better
if($null -eq $Configured){
  Write-Host "Nao consegui ler o 9Router. Se ele estiver rodando, tente fechar e abrir de novo." -ForegroundColor Yellow
  exit 1
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

# Ollama local nao precisa de chave: mostra como dica, nunca como "falta".
$OllamaOk = $hasKey['ollama']

# Providers que o usuario tem no 9Router mas nao estao na lista acima (so info)
$Outros = @()
foreach($p in $Configured){
  if($p.provider -and -not ($Providers | Where-Object { $_.Provider -eq $p.provider }) -and $p.hasKey){
    $Outros += $p.provider
  }
}

Write-Host "Estado do 9Router: $(if($NineUp){'rodando (porta 20128)'} else {'instalado mas PARADO (inicie com kfai-start.ps1)'})" -ForegroundColor $(if($NineUp){'Green'}else{'Yellow'})
Write-Host ""

if($Ok.Count -gt 0){
  Write-Host "Ja configurados (OK):" -ForegroundColor Green
  foreach($p in $Ok){
    Write-Host ("  [OK] {0}" -f $p.Nome) -ForegroundColor Green
  }
}

if($OllamaOk){
  Write-Host "  [OK] Ollama (cloud) - chave configurada" -ForegroundColor Green
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

Write-Host "Depois de gerar cada chave, ela vai para o 9Router (abro o painel no final)." -ForegroundColor White

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
Write-Host "Agora abra o painel do 9Router para colar as chaves geradas." -ForegroundColor Cyan
Write-Host "  Painel: http://localhost:20128/dashboard" -ForegroundColor Cyan
Write-Host "  (Ou rode: kfai-start.ps1  para iniciar o 9Router, depois abra o link acima.)" -ForegroundColor DarkGray
Write-Host ""
$resp = ''
try { $resp = Read-Host "Abrir o painel do 9Router agora? (s/N)" } catch { $resp = '' }
if($resp -match '^(s|sim|y|yes)$'){
  if(-not $NineUp){
    Write-Host "O 9Router esta parado. Iniciando..." -ForegroundColor Yellow
    $start = Join-Path $Root "kfai-start.ps1"
    if(Test-Path $start){
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start | Out-Null
      Start-Sleep -Seconds 3
    }
  }
  Start-Process "http://localhost:20128/dashboard"
}
Write-Host ""
Write-Host "Depois de colar as chaves no painel, rode de novo:" -ForegroundColor Green
Write-Host "  .\kfai-config-chaves.ps1   (para conferir se tudo ficou certo)" -ForegroundColor Green
Read-Host "Pressione Enter para fechar"
