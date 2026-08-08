# KFAI - Abre um agente de IA ligando router + ollama apenas enquanto o agente estiver aberto.
# Uso:
#   .\kfai-launch.ps1 -App aionui     abre o AionUi (espera fechar) e desliga servicos
#   .\kfai-launch.ps1 -App opencode   abre o opencode no terminal atual
#   .\kfai-launch.ps1 -App hermes     abre o Hermes no terminal atual
#   .\kfai-launch.ps1 -App "C:\caminho\app.exe"  abre qualquer executavel
#   .\kfai-launch.ps1 -App opencode -KeepOn   abre mas NAO desliga os servicos ao fechar
#   .\kfai-launch.ps1 -App aionui -With9Router  prefere IA local; so cai pro 9Router se o Ollama falhar
[CmdletBinding()]
param(
  [string]$App = "aionui",
  [switch]$KeepOn,
  [switch]$With9Router
)

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Start  = Join-Path $Root "kfai-start.ps1"
$StartArgs = @()
if($With9Router){ $StartArgs += "-With9Router" }

# --- apps conhecidos: nome -> (tipo, caminho, nome do processo) ---
$known = @{
  "aionui"  = @{ Type="gui";  Exe="C:\Users\USUARIO\AppData\Local\Programs\AionUi\AionUi.exe";   Proc="AionUi" }
  "opencode"= @{ Type="cli";  Exe="opencode";                                                  Proc="opencode" }
  "hermes"  = @{ Type="cli";  Exe="C:\Users\USUARIO\AppData\Local\hermes\hermes-agent\venv\Scripts\hermes.exe"; Proc="hermes" }
}

# --- resolve o alvo ---
$info = $null
if($known.ContainsKey($App.ToLower())){
  $info = $known[$App.ToLower()]
} elseif(Test-Path -LiteralPath $App){
  $info = @{ Type="gui"; Exe=$App; Proc=[IO.Path]::GetFileNameWithoutExtension($App) }
} else {
  $cmd = Get-Command $App -ErrorAction SilentlyContinue
  if($cmd -and $cmd.Source){
    $info = @{ Type="cli"; Exe=$cmd.Source; Proc=[IO.Path]::GetFileNameWithoutExtension($cmd.Source) }
  } else {
    Write-Error "App desconhecido: '$App'. Use um nome conhecido (aionui|opencode|hermes) ou um caminho de exe."
    exit 1
  }
}

# --- 1) liga servicos (se ainda nao estiverem) ---
if($With9Router){ Write-Host "[kfai] Ligando router + ollama + 9Router..." } else { Write-Host "[kfai] Ligando router + ollama..." }
& $Start @StartArgs

# --- 2) abre o agente e espera fechar ---
if($info.Type -eq "cli"){
  # roda no console atual (openmode TUI / hermes)
  & $info.Exe
} else {
  $p = Start-Process -FilePath $info.Exe -PassThru
  $p.WaitForExit()
}

# --- 3) desliga servicos, a menos que outro agente ainda esteja aberto ---
if(-not $KeepOn){
  $stillOpen = $false
  foreach($name in @("AionUi","aioncore","opencode","hermes")){
    if(Get-Process -Name $name -ErrorAction SilentlyContinue){ $stillOpen = $true; break }
  }
  if($stillOpen){
    Write-Host "[kfai] Outro agente de IA ainda esta aberto. Servicos mantidos."
  } else {
    Write-Host "[kfai] Agente fechado. Desligando servicos..."
    & $Start -Stop @StartArgs
  }
} else {
  Write-Host "[kfai] -KeepOn: servicos mantidos rodando."
}
Write-Host "[kfai] Fim."
