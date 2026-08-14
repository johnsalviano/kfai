# KFAI - Aplica os combos de IA no AionUi e remove os perfis pagos.
# Rode ESTE script DENTRO do AionUi (PowerShell do proprio app), porque ele
# usa a CLI interna do AionUi (aioncore), que so funciona com o app aberto.
# Uso:
#   .\04-kfai-aionui-combos.ps1            aplica combos e remove perfis pagos
#   .\04-kfai-aionui-combos.ps1 -SkipPagos nao toca nos perfis pagos
#   .\04-kfai-aionui-combos.ps1 -Show      so mostra o estado atual
[CmdletBinding()]
param(
  [switch]$SkipPagos,
  [switch]$Show
)
$ErrorActionPreference = 'Stop'

$helper = $env:AIONUI_HELPER_BIN
if(-not $helper -or -not (Test-Path -LiteralPath $helper)){
  Write-Host "AIONUI_HELPER_BIN nao encontrado. Rode este script de DENTRO do AionUi" -ForegroundColor Red
  Write-Host "(menu do app: abra um PowerShell do proprio AionUi e rode .\04-kfai-aionui-combos.ps1)." -ForegroundColor Yellow
  exit 1
}

function Read-Env([string]$k){ (Get-ChildItem Env: | Where-Object { $_.Name -eq $k } | Select-Object -First 1).Value }
$need = @("AIONUI_BASE_URL","AIONUI_CONVERSATION_ID","AIONUI_USER_ID")
$missing = $need | Where-Object { -not (Read-Env $_) }
if($missing){
  Write-Host "Faltam variaveis do AionUi: $($missing -join ', ')" -ForegroundColor Red
  Write-Host "Rode este script de dentro do AionUi (PowerShell interno do app)." -ForegroundColor Yellow
  exit 1
}

function Invoke-Config {
  param([string[]]$ArgsList, [string]$Stdin)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = ($Stdin | & $helper @ArgsList 2>&1)
  $err = $LASTEXITCODE
  $ErrorActionPreference = $prevEap
  if($err -ne 0){ throw (($out | Out-String).Trim()) }
  return ($out | Out-String | ConvertFrom-Json)
}

# --- mostra os providers atuais (so nomes/base_url/modelos) ---
$list = (Invoke-Config -ArgsList @("config","providers","list"))
Write-Host "`nProviders do AionUi agora:" -ForegroundColor Cyan
foreach($pr in $list.data){
  $models = if($pr.models){ " [" + ($pr.models -join ', ') + "]" } else { "" }
  Write-Host ("  - {0}  ({1}){2}" -f $pr.name, $pr.base_url, $models)
}

if($Show){ exit 0 }

Write-Host "`nPasso 1: aplicar combos do KFAI (provider KFAI Router -> router local 20129)..." -ForegroundColor Cyan
$router = $list.data | Where-Object { $_.name -eq "KFAI Router" }
$comboModels = @("full-cloud","cloud-plus-local","full-local")
if($router){
  $updated = Invoke-Config -ArgsList @("config","providers","update") -Stdin (@{
    provider_id = $router.id
    models      = $comboModels
  } | ConvertTo-Json -Compress)
  if($updated.success){ Write-Host "  KFAI Router atualizado com os combos: $($comboModels -join ', ')" -ForegroundColor Green }
} else {
  $created = Invoke-Config -ArgsList @("config","providers","create") -Stdin (@{
    name     = "KFAI Router"
    platform = "openai"
    base_url = "http://localhost:20129/v1"
    api_key  = "kfai"
    models   = $comboModels
  } | ConvertTo-Json -Compress)
  if($created.success){ Write-Host "  KFAI Router criado com os combos: $($comboModels -join ', ')" -ForegroundColor Green }
}

if($SkipPagos){
  Write-Host "`n-SkipPagos: perfis pagos mantidos." -ForegroundColor DarkGray
  exit 0
}

Write-Host "`nPasso 2: remover perfis pagos (Anthropic e OpenAI)..." -ForegroundColor Cyan
$pagos = @($list.data | Where-Object { $_.name -in @("Anthropic","OpenAI") })
if(-not $pagos){
  Write-Host "  Nenhum perfil pago encontrado. Ok." -ForegroundColor Green
} else {
  foreach($pr in $pagos){
    $r = Invoke-Config -ArgsList @("config","providers","delete") -Stdin (@{ provider_id = $pr.id } | ConvertTo-Json -Compress)
    if($r.success){ Write-Host "  Removido: $($pr.name)" -ForegroundColor Green }
  }
}

Write-Host "`nPronto! Combos do KFAI disponiveis no AionUi (KFAI Router):" -ForegroundColor Green
Write-Host "  - full-cloud        -> so IAs gratuitas da nuvem" -ForegroundColor White
Write-Host "  - cloud-plus-local  -> nuvem primeiro, seu PC de reserva" -ForegroundColor White
Write-Host "  - full-local        -> somente seu PC (Ollama)" -ForegroundColor White
