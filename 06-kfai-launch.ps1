# KFAI - Abre um agente de IA ligando router + ollama apenas enquanto o agente estiver aberto.
# Uso:
#   .\06-kfai-launch.ps1 -App aionui     abre o AionUi (espera fechar) e desliga servicos
#   .\06-kfai-launch.ps1 -App opencode   abre o opencode no terminal atual
#   .\06-kfai-launch.ps1 -App hermes     abre o Hermes no terminal atual
#   .\06-kfai-launch.ps1 -App "C:\caminho\app.exe"  abre qualquer executavel
#   .\06-kfai-launch.ps1 -App opencode -KeepOn   abre mas NAO desliga os servicos ao fechar
#   .\06-kfai-launch.ps1 -App aionui -With9Router  so IA em nuvem via 9Router (desliga Ollama local)
[CmdletBinding()]
param(
  [string]$App = "aionui",
  [switch]$KeepOn,
  [switch]$With9Router
)

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Start  = Join-Path $Root "05-kfai-start.ps1"
$StartArgs = @()
if($With9Router){ $StartArgs += "-With9Router" }

# --- apps conhecidos: nome -> (tipo, caminho, nome do processo) ---
$known = @{
  "aionui"  = @{ Type="gui";  Exe="$env:LOCALAPPDATA\Programs\AionUi\AionUi.exe";   Proc="AionUi" }
  "opencode"= @{ Type="cli";  Exe="opencode";                                                  Proc="opencode" }
  "hermes"  = @{ Type="cli";  Exe="$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\hermes.exe"; Proc="hermes" }
}

# --- resolve o alvo ---
$info = $null
if($known.ContainsKey($App.ToLower())){
  $info = $known[$App.ToLower()]
  if($info.Type -eq "gui" -and -not (Test-Path -LiteralPath $info.Exe)){
    # caminho padrao nao existe: procura em outros locais comuns
    $alt = Get-ChildItem "$env:LOCALAPPDATA\Programs\$($info.Proc)\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if($alt){ $info.Exe = $alt.FullName } else { Write-Error "Nao encontrei o executavel de '$App'. Passe o caminho completo."; exit 1 }
  }
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

# --- 1) abre o agente logo (nao fica esperando servicos subirem) ---
if($info.Type -eq "cli"){
  # CLI: liga servicos ANTES porque o console ja vai ser usado pelo app.
  if($With9Router){ Write-Host "[kfai] Ligando router + ollama + 9Router..." } else { Write-Host "[kfai] Ligando router + ollama..." }
  & $Start @StartArgs
  # roda no console atual (opencode TUI / hermes)
  & $info.Exe
} else {
  # App grafico (AionUi). Abre a janela NA HORA e sobe os servicos em paralelo,
  # em segundo plano: sem tela preta, sem esperar ~11s do start.
  $logDir = Join-Path $Root "logs"
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  $outLog = Join-Path $logDir "app.stdout.log"
  $errLog = Join-Path $logDir "app.stderr.log"
  $startOut = Join-Path $logDir "start.stdout.log"
  $startErr = Join-Path $logDir "start.stderr.log"

  # 1a) dispara o start em background (processo separado, escondido)
  Write-Host "[kfai] Subindo servicos em segundo plano..."
  $ps = (Get-Command powershell -ErrorAction SilentlyContinue).Source
  $startArgs = @("-NoProfile","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File","$Start")
  if($With9Router){ $startArgs += "-With9Router" }
  Start-Process -FilePath $ps -ArgumentList $startArgs -WindowStyle Hidden -RedirectStandardOutput $startOut -RedirectStandardError $startErr | Out-Null

  # 1b) abre o app imediatamente (nao espera o background)
  $p = Start-Process -FilePath $info.Exe -PassThru -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog
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
