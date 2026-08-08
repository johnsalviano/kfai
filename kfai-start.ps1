# KFAI - Inicia o roteador proprio e o Ollama em SEGUNDO PLANO (sem janelas)
# Uso:
#   .\kfai-start.ps1           inicia router + ollama escondidos
#   .\kfai-start.ps1 -Stop     para tudo
#   .\kfai-start.ps1 -Status   mostra o que esta rodando
#   .\kfai-start.ps1 -Register adiciona ao login do Windows (autostart)
#   .\kfai-start.ps1 -Unregister remove do login
#   .\kfai-start.ps1 -With9Router  usa IA local primeiro; so cai pro 9Router
#                                  (porta 20128) se o Ollama falhar. NUNCA os
#                                  dois ligados ao mesmo tempo.
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
# Servidor puro (sem GUI de bandeja): ollama.exe serve em background.
# "ollama app.exe" e a GUI - nao usar: abre bandeja e consome recursos a toa.
$OllamaApp = "C:\Users\USUARIO\AppData\Local\Programs\Ollama\ollama.exe"
# 9Router: CLI npm global. -tray sobe bandeja; nos rodamos SEM bandeja, escondido.
$Node     = (Get-Command node -ErrorAction SilentlyContinue).Source
$NineCli  = "C:\Users\USUARIO\AppData\Roaming\npm\node_modules\9router\cli.js"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunName = "KFAI Router"
$OllamaRunName = "KFAI Ollama"

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
  if(-not (Test-Port 11434)){
    Write-Host "Iniciando servidor Ollama (ollama.exe serve, sem GUI)..."
    Start-Process -FilePath $OllamaApp -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 8
  } else {
    Write-Host "Ollama ja estava ligado."
  }
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
  if(-not (Test-Path $Node) -or -not (Test-Path $NineCli)){ Write-Error "9Router nao encontrado (node=$Node, cli=$NineCli)"; return }
  if(-not (Test-Port 20128)){
    Write-Host "Iniciando 9Router (sem bandeja, escondido)..."
    Start-Process -FilePath $Node -ArgumentList "`"$NineCli`" -n --skip-update" -WindowStyle Hidden
    Start-Sleep -Seconds 8
  } else {
    Write-Host "9Router ja estava ligado."
  }
}

function Stop-OllamaAndRouter{
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'router\.py' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Get-Process ollama,"ollama app" -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Stop-NineRouter{
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match '9router\\' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if($Status){
  $r = if(Test-Port 20129){ "LIGADO (porta 20129)" } else { "desligado" }
  $o = if(Test-Port 11434){ "LIGADO (porta 11434)" } else { "desligado" }
  $n = if(Test-Port 20128){ "LIGADO (porta 20128)" } else { "desligado" }
  $a = if((Get-ItemProperty $RunKey -ErrorAction SilentlyContinue).$RunName){ "ativo" } else { "inativo" }
  Write-Host "Router   : $r"
  Write-Host "Ollama   : $o"
  Write-Host "9Router  : $n"
  Write-Host "Autostart: $a"
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
  $ps = (Get-Command powershell).Source
  New-ItemProperty -Path $RunKey -Name $RunName -PropertyType String -Value "`"$ps`" -NoProfile -WindowStyle Hidden -File `"$Root\kfai-start.ps1`"" -Force | Out-Null
  New-ItemProperty -Path $RunKey -Name $OllamaRunName -PropertyType String -Value "`"$OllamaApp`" serve" -Force | Out-Null
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
  # Prefere o local. So sobe o 9Router se o Ollama estiver sem servico/modelo.
  Start-Ollama
  Start-KfaiRouter
  if(Test-OllamaWorking){
    Write-Host "Ollama local OK (tem modelo). Usando IA local. 9Router fica desligado."
  } else {
    Write-Host "Ollama local indisponivel (sem modelo ou sem resposta). Caindo para o 9Router..."
    Stop-OllamaAndRouter
    Start-NineRouter
    Write-Host "Usando 9Router (IA em nuvem). Ollama local desligado."
  }
} else {
  Start-Ollama
  Start-KfaiRouter
}
Write-Host "Pronto. Tudo rodando sem janelas."
if(-not (Test-Port 11434)){ Write-Host "AVISO: Ollama nao respondeu ainda. Se o PC e fraco, ele pode demorar." }
