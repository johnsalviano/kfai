# KFAI - Inicia o roteador proprio e o Ollama em SEGUNDO PLANO (sem janelas)
# Uso:
#   .\kfai-start.ps1           inicia router + ollama escondidos
#   .\kfai-start.ps1 -Stop     para tudo
#   .\kfai-start.ps1 -Status   mostra o que esta rodando + compatibilidade do PC
#   .\kfai-start.ps1 -Register adiciona ao login do Windows (autostart)
#   .\kfai-start.ps1 -Unregister remove do login
#   .\kfai-start.ps1 -With9Router  prefere IA local; so cai pro 9Router
#                                  (porta 20128) se o PC nao suportar IA local
#                                  ou o Ollama falhar. NUNCA os dois ao mesmo tempo.
#
# No inicio SEMPRE verifica:
#   1) se o PC aguenta IA local (RAM/VRAM/CPU);
#   2) qual o comando correto do Ollama e do 9Router instalados na maquina
#      (os caminhos podem mudar de maquina para maquina).
# Se o PC nao suportar IA local, usa o 9Router como padrao.
[CmdletBinding()]
param(
  [switch]$Stop,
  [switch]$Status,
  [switch]$Register,
  [switch]$Unregister,
  [switch]$With9Router
)

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Router = Join-Path $Root "router.py"
$Pythonw = (Get-Command pythonw -ErrorAction SilentlyContinue).Source
if(-not $Pythonw){ $Pythonw = (Join-Path (Split-Path (Get-Command python).Source) "pythonw.exe") }
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunName = "KFAI Router"
$OllamaRunName = "KFAI Ollama"

# ================= DETECCAO DE COMANDOS (variam de maquina p/ maquina) =================

# Acha o executavel do Ollama. Pode ser:
#   - "ollama.exe serve" (servidor puro, preferido)
#   - "ollama app.exe"   (GUI de bandeja, evita)
#   - caminho no PATH / instalacao padrao / winget
function Find-OllamaCommand{
  $candidates = @()
  $p = (Get-Command ollama -ErrorAction SilentlyContinue).Source
  if($p){ $candidates += $p }
  foreach($base in @("$env:LOCALAPPDATA\Programs\Ollama", "$env:ProgramFiles\Ollama", "$env:ProgramFiles\Ollama App")){
    foreach($name in @("ollama.exe", "ollama app.exe")){
      $c = Join-Path $base $name
      if(Test-Path $c){ $candidates += $c }
    }
  }
  if($candidates.Count -eq 0){ return $null }
  # Preferencia: ollama.exe (serve puro) sobre "ollama app.exe" (bandeja).
  $serve = $candidates | Where-Object { $_ -notmatch ' app\.exe$' } | Select-Object -First 1
  if($serve){ return $serve }
  return $candidates[0]
}

# Acha o 9Router. Precisa do node + do cli.js. Pode estar no npm global
# (9router/cli.js), em 9router-src, em .next/standalone, ou no PATH.
function Find-NineRouterCommand{
  $node = (Get-Command node -ErrorAction SilentlyContinue).Source
  if(-not $node){ $node = "$env:ProgramFiles\nodejs\node.exe" }
  $cli = $null
  $candidates = @(
    "$env:APPDATA\npm\node_modules\9router\cli.js",
    "$env:APPDATA\npm\node_modules\@9router\cli.js",
    "$env:LOCALAPPDATA\9router\cli.js",
    "$env:USERPROFILE\9router-src\.next\standalone\server.js",
    "$env:USERPROFILE\9router-src\server.js"
  )
  foreach($c in $candidates){ if(Test-Path $c){ $cli = $c; break } }
  if(-not $cli){
    $pathCmd = (Get-Command 9router -ErrorAction SilentlyContinue).Source
    if($pathCmd){ $cli = $pathCmd }
  }
  if(-not (Test-Path $node) -or -not $cli){ return $null }
  return @{ Node = $node; Cli = $cli }
}

# ================= COMPATIBILIDADE COM IA LOCAL =================

function Get-VramGpu{
  $vram = 0
  try {
    $smi = (Get-Command nvidia-smi -ErrorAction SilentlyContinue).Source
    if($smi){
      $lines = @(& $smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null)
      if($lines -and $lines[0]){
        $vram = [math]::Max($vram, [double]($lines[0].Trim()) / 1024)
      }
    }
  } catch {}
  if($vram -eq 0){
    try {
      Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'NVIDIA|Radeon|GeForce|RTX|GTX|ARC' } |
        ForEach-Object { $vram = [math]::Max($vram, [double]($_.AdapterRAM) / 1GB) }
    } catch {}
  }
  return [math]::Round($vram, 1)
}

# Regras (PC fraco = nao roda IA local):
#   - RAM total < 8 GB        -> fraco
#   - VRAM >= 6 GB            -> roda bem (GPU)
#   - VRAM 4-5 GB             -> roda modelos pequenos (3B)
#   - VRAM < 4 GB mas RAM >= 16 GB -> roda modelos pequenos na CPU (lento)
#   - VRAM < 4 GB e RAM < 16 GB     -> fraco
# KFAI_FORCE_NO_LOCAL=1  força tratar como PC incompativel (so nuvem/9Router).
function Test-PcSuportaLocal{
  if($env:KFAI_FORCE_NO_LOCAL -eq "1"){
    return @{ Ok=$false; Motivo="forcado por KFAI_FORCE_NO_LOCAL (so nuvem)" }
  }
  try { $ramGB = [double](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB } catch { $ramGB = 0 }
  $vramGB = Get-VramGpu
  if($ramGB -lt 8){ return @{ Ok=$false; Motivo="menos de 8 GB de RAM (tem $([math]::Round($ramGB,1)) GB)" } }
  if($vramGB -ge 6){ return @{ Ok=$true;  Motivo="VRAM $vramGB GB" } }
  if($vramGB -ge 4){ return @{ Ok=$true;  Motivo="VRAM $vramGB GB (modelos pequenos)" } }
  if($ramGB -ge 16){ return @{ Ok=$true;  Motivo="sem GPU forte, mas RAM $([math]::Round($ramGB,1)) GB (IA local na CPU, lenta)" } }
  return @{ Ok=$false; Motivo="sem GPU com VRAM adequada e menos de 16 GB de RAM" }
}

function Test-Port([int]$port){
  try { (New-Object Net.Sockets.TcpClient).Connect("127.0.0.1", $port); return $true } catch { return $false }
}

# Ollama "funciona" se responder na porta E tiver pelo menos 1 modelo baixado.
function Test-OllamaWorking{
  if(-not (Test-Port 11434)){ return $false }
  try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 10
    return ($null -ne $tags.models -and @($tags.models).Count -gt 0)
  } catch { return $false }
}

function Start-Ollama{
  if(-not $script:OllamaCmd){ Write-Error "Ollama nao encontrado nesta maquina."; return $false }
  if(-not (Test-Port 11434)){
    if($script:OllamaCmd -match ' app\.exe$'){
      Write-Host "Iniciando Ollama (GUI de bandeja - unica opcao instalada)..."
      Start-Process -FilePath $script:OllamaCmd -WindowStyle Hidden
    } else {
      Write-Host "Iniciando servidor Ollama ($script:OllamaCmd serve, sem GUI)..."
      Start-Process -FilePath $script:OllamaCmd -ArgumentList "serve" -WindowStyle Hidden
    }
    Start-Sleep -Seconds 8
  } else {
    Write-Host "Ollama ja estava ligado."
  }
  return $true
}

function Start-KfaiRouter{
  if(-not (Test-Path $Router)){ Write-Error "router.py nao encontrado em $Root"; return }
  if(-not (Test-Port 20129)){
    Write-Host "Iniciando roteador KFAI (segundo plano)..."
    Start-Process -FilePath $Pythonw -ArgumentList "`"$Router`"" -WindowStyle Hidden -WorkingDirectory $Root
    Start-Sleep -Seconds 3
  } else {
    Write-Host "Roteador ja estava ligado."
  }
}

function Start-NineRouter{
  if(-not $script:NineCmd){ Write-Error "9Router nao encontrado nesta maquina."; return $false }
  if(-not (Test-Port 20128)){
    Write-Host "Iniciando 9Router (sem bandeja, escondido)..."
    $cliIsStandalone = $script:NineCmd.Cli -match 'server\.js$'
    if($cliIsStandalone){
      # Build standalone do Next (server.js): precisa rodar a partir da pasta do build
      $dir = Split-Path -Parent $script:NineCmd.Cli
      $env:PORT = "20128"
      Start-Process -FilePath $script:NineCmd.Node -ArgumentList "`"$($script:NineCmd.Cli)`"" -WindowStyle Hidden -WorkingDirectory $dir
    } else {
      # CLI npm global: node cli.js -n --skip-update
      Start-Process -FilePath $script:NineCmd.Node -ArgumentList "`"$($script:NineCmd.Cli)`" -n --skip-update" -WindowStyle Hidden
    }
    Start-Sleep -Seconds 8
  } else {
    Write-Host "9Router ja estava ligado."
  }
  return $true
}

function Stop-OllamaAndRouter{
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'router\.py' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Get-Process ollama,"ollama app" -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Stop-NineRouter{
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match '9router' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

# ================= VERIFICACOES NO INICIO (sempre) =================
$script:OllamaCmd = Find-OllamaCommand
$script:NineCmd   = Find-NineRouterCommand
$Compat = Test-PcSuportaLocal

if($Status){
  $r = if(Test-Port 20129){ "LIGADO (porta 20129)" } else { "desligado" }
  $o = if(Test-Port 11434){ "LIGADO (porta 11434)" } else { "desligado" }
  $n = if(Test-Port 20128){ "LIGADO (porta 20128)" } else { "desligado" }
  $a = if((Get-ItemProperty $RunKey -ErrorAction SilentlyContinue).$RunName){ "ativo" } else { "inativo" }
  Write-Host "Router   : $r"
  Write-Host "Ollama   : $o"
  Write-Host "9Router  : $n"
  Write-Host "Autostart: $a"
  Write-Host ""
  Write-Host "-- Compatibilidade com IA local --"
  if($Compat.Ok){
    Write-Host "PC COMPATIVEL ($($Compat.Motivo))."
  } else {
    Write-Host "PC NAO SUPORTA IA LOCAL ($($Compat.Motivo))."
    Write-Host "Use -With9Router para rodar so via 9Router (nuvem)."
  }
  Write-Host "Ollama : $(if($script:OllamaCmd){$script:OllamaCmd}else{'nao encontrado'})"
  if($script:NineCmd){ Write-Host "9Router: $($script:NineCmd.Node) $($script:NineCmd.Cli)" } else { Write-Host "9Router: nao encontrado" }
  if($o -eq "LIGADO (porta 11434)" -and $n -eq "LIGADO (porta 20128)"){
    Write-Host "AVISO: Ollama e 9Router ligados AO MESMO TEMPO (nao recomendado)."
  }
  exit 0
}

if($Stop){
  Stop-OllamaAndRouter
  if($With9Router){
    Stop-NineRouter
    Write-Host "Local e 9Router parados."
  } else {
    Write-Host "Router e Ollama parados."
  }
  exit 0
}

if($Register){
  if(-not $script:OllamaCmd){ Write-Error "Ollama nao encontrado; nao posso registrar autostart."; exit 1 }
  $ps = (Get-Command powershell).Source
  New-ItemProperty -Path $RunKey -Name $RunName -PropertyType String -Value "`"$ps`" -NoProfile -WindowStyle Hidden -File `"$Root\kfai-start.ps1`"" -Force | Out-Null
  if($script:OllamaCmd -match ' app\.exe$'){
    New-ItemProperty -Path $RunKey -Name $OllamaRunName -PropertyType String -Value "`"$script:OllamaCmd`"" -Force | Out-Null
  } else {
    New-ItemProperty -Path $RunKey -Name $OllamaRunName -PropertyType String -Value "`"$script:OllamaCmd`" serve" -Force | Out-Null
  }
  Write-Host "Autostart no login ativado (router + ollama)."
  exit 0
}

if($Unregister){
  Remove-ItemProperty -Path $RunKey -Name $RunName -ErrorAction SilentlyContinue
  Remove-ItemProperty -Path $RunKey -Name $OllamaRunName -ErrorAction SilentlyContinue
  Write-Host "Autostart removido."
  exit 0
}

# --- inicio normal ---
if($With9Router){
  if(-not $Compat.Ok){
    # PC fraco: nao tenta IA local. 9Router vira o padrao.
    Write-Host "PC nao suporta IA local ($($Compat.Motivo))."
    Write-Host "Usando 9Router como padrao (IA em nuvem)."
    Start-NineRouter | Out-Null
  } else {
    # PC suporta: prefere o local; so cai pro 9Router se o Ollama falhar.
    Start-Ollama | Out-Null
    Start-KfaiRouter
    if(Test-OllamaWorking){
      Write-Host "Ollama local OK (tem modelo). Usando IA local. 9Router fica desligado."
    } else {
      Write-Host "Ollama local indisponivel (sem modelo ou sem resposta). Caindo para o 9Router..."
      Stop-OllamaAndRouter
      Start-NineRouter | Out-Null
      Write-Host "Usando 9Router (IA em nuvem). Ollama local desligado."
    }
  }
} else {
  if(-not $Compat.Ok){
    Write-Host "AVISO: PC nao suporta IA local ($($Compat.Motivo))."
    Write-Host "Rode com -With9Router para usar IA em nuvem (9Router)."
  }
  Start-Ollama | Out-Null
  Start-KfaiRouter
  if(-not (Test-Port 11434)){ Write-Host "AVISO: Ollama nao respondeu ainda. Se o PC e fraco, ele pode demorar." }
}
Write-Host "Pronto. Tudo rodando sem janelas."
