# KFAI - Inicia o roteador proprio e o Ollama em SEGUNDO PLANO (sem janelas)
# Uso:
#   .\kfai-start.ps1           inicia router + ollama escondidos
#   .\kfai-start.ps1 -Stop     para tudo
#   .\kfai-start.ps1 -Status   mostra o que esta rodando + compatibilidade do PC
#   .\kfai-start.ps1 -Register adiciona ao login do Windows (autostart)
#   .\kfai-start.ps1 -Unregister remove do login
#   .\kfai-start.ps1 -With9Router  SO IA em nuvem via 9Router (porta 20128);
#                                  nao sobe o Ollama local. Para PC fraco.
#
# O 9Router e o GATEWAY de nuvem do KFAI (full-cloud / cloud-plus-local): ele
# sobe SEMPRE que estiver instalado. O Ollama sobe se o PC aguentar IA local.
# Os dois podem rodar ao mesmo tempo (portas diferentes; o router.conf decide).
#
# No inicio SEMPRE verifica:
#   1) se o PC aguenta IA local (RAM/VRAM/CPU);
#   2) qual o comando correto do Ollama e do 9Router instalados na maquina
#      (os caminhos podem mudar de maquina para maquina).
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

# Acha um pythonw.exe de VERDADE (sem console). O do PATH pode ser um launcher
# de venv criado pelo uv que relanca o script com o python.exe base (com
# console) - e esse processo filho abre a janela preta. Preferimos pythonw
# fora de venv; se so existir o do venv, usamos o pythonw do "home" dele.
function Find-Pythonw {
  $cands = @()
  # uv pythons standalone (nao sao venv)
  Get-ChildItem "$env:APPDATA\uv\python" -Recurse -Filter "pythonw.exe" -ErrorAction SilentlyContinue |
    ForEach-Object { $cands += $_.FullName }
  # installs python.org por-usuario
  Get-ChildItem "$env:LOCALAPPDATA\Programs\Python" -Recurse -Filter "pythonw.exe" -ErrorAction SilentlyContinue |
    ForEach-Object { $cands += $_.FullName }
  # C:\Python*
  Get-ChildItem "C:\" -Directory -Filter "Python*" -ErrorAction SilentlyContinue |
    ForEach-Object { $p = Join-Path $_.FullName "pythonw.exe"; if(Test-Path -LiteralPath $p){ $cands += $p } }
  # pythonw do PATH (ultimo recurso)
  $pw = (Get-Command pythonw -ErrorAction SilentlyContinue).Source
  if($pw){ $cands += $pw }
  $visto = @{}
  foreach($c in $cands){
    if(-not $c -or -not (Test-Path -LiteralPath $c) -or $visto[$c]){ continue }
    $visto[$c] = $true
    # Se for o de um venv (tem pyvenv.cfg na pasta raiz do venv), usa o pythonw
    # do "home" apontado pelo proprio venv (o real, sem console).
    $venvCfg = Join-Path (Split-Path -Parent (Split-Path -Parent $c)) "pyvenv.cfg"
    if(Test-Path -LiteralPath $venvCfg){
      $m = Select-String -Path $venvCfg -Pattern '^home\s*=\s*(.+)$' | Select-Object -First 1
      if($m -and $m.Matches[0].Groups[1].Value){
        $baseW = Join-Path $m.Matches[0].Groups[1].Value.Trim() "pythonw.exe"
        if(Test-Path -LiteralPath $baseW){ return $baseW }
      }
      continue
    }
    return $c
  }
  return $null
}
$Pythonw = Find-Pythonw
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
  # Prioridade: caminhos de instalacao conhecidos (nao confia em exe no PATH,
  # que pode ser um falso ollama.exe plantado por malware para ser executado aqui).
  foreach($base in @("$env:LOCALAPPDATA\Programs\Ollama", "$env:ProgramFiles\Ollama", "$env:ProgramFiles\Ollama App")){
    foreach($name in @("ollama.exe", "ollama app.exe")){
      $c = Join-Path $base $name
      if(Test-Path $c){ $candidates += $c }
    }
  }
  # So depois tenta o PATH (instalacao por winget/choco/etc).
  $p = (Get-Command ollama -ErrorAction SilentlyContinue).Source
  if($p){ $candidates += $p }
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
  # Mantem o modelo na RAM 30min (evita cold start de 3-10s a cada request) e permite
  # requisições paralelas. Usuario pode sobrescrever com env vars proprias.
  if(-not $env:OLLAMA_KEEP_ALIVE){ $env:OLLAMA_KEEP_ALIVE = "30m" }
  if(-not $env:OLLAMA_NUM_PARALLEL){ $env:OLLAMA_NUM_PARALLEL = "2" }
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
    Write-Host "Nota: Ollama e 9Router ligados juntos (normal no novo router.conf)."
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
  # Modo so-nuvem (PC fraco): nao sobe Ollama local.
  if(-not $script:NineCmd){ Write-Error "9Router nao encontrado; -With9Router nao e possivel."; exit 1 }
  Write-Host "Modo 9Router (IA em nuvem). Ollama local desligado."
  Stop-OllamaAndRouter
  Start-NineRouter | Out-Null
} else {
  # Modo padrao: 9Router (gateway de nuvem) + Ollama local (se o PC aguentar).
  if($script:NineCmd){
    Start-NineRouter | Out-Null
  } else {
    Write-Host "AVISO: 9Router nao encontrado. Full Cloud / Cloud + Local ficam sem nuvem."
  }
  if(-not $Compat.Ok){
    Write-Host "PC NAO SUPORTA IA LOCAL ($($Compat.Motivo)). So IA em nuvem (9Router)."
    Start-KfaiRouter
  } else {
    Start-Ollama | Out-Null
    Start-KfaiRouter
    if(-not (Test-Port 11434)){ Write-Host "AVISO: Ollama nao respondeu ainda. Se o PC e fraco, ele pode demorar." }
  }
}
Write-Host "Pronto. Tudo rodando sem janelas."
