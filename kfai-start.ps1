# KFAI - Inicia o roteador proprio e o Ollama em SEGUNDO PLANO (sem janelas)
# Uso:
#   .\kfai-start.ps1           inicia router + ollama escondidos
#   .\kfai-start.ps1 -Stop     para tudo
#   .\kfai-start.ps1 -Status   mostra o que esta rodando
#   .\kfai-start.ps1 -Register adiciona ao login do Windows (autostart)
#   .\kfai-start.ps1 -Unregister remove do login
[CmdletBinding()]
param(
  [switch]$Stop,
  [switch]$Status,
  [switch]$Register,
  [switch]$Unregister
)

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Router = Join-Path $Root "router.py"
$Pythonw = (Get-Command pythonw -ErrorAction SilentlyContinue).Source
if(-not $Pythonw){ $Pythonw = (Join-Path (Split-Path (Get-Command python).Source) "pythonw.exe") }
# Servidor puro (sem GUI de bandeja): ollama.exe serve em background.
# "ollama app.exe" e a GUI - nao usar: abre bandeja e consome recursos a toa.
$OllamaApp = "C:\Users\USUARIO\AppData\Local\Programs\Ollama\ollama.exe"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunName = "KFAI Router"
$OllamaRunName = "KFAI Ollama"

function Test-Port([int]$port){
  try { (New-Object Net.Sockets.TcpClient).Connect("127.0.0.1", $port); return $true } catch { return $false }
}

if($Status){
  $r = if(Test-Port 20129){ "LIGADO (porta 20129)" } else { "desligado" }
  $o = if(Test-Port 11434){ "LIGADO (porta 11434)" } else { "desligado" }
  $a = if((Get-ItemProperty $RunKey -ErrorAction SilentlyContinue).$RunName){ "ativo" } else { "inativo" }
  Write-Host "Router   : $r"
  Write-Host "Ollama   : $o"
  Write-Host "Autostart: $a"
  exit 0
}

if($Stop){
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'router\.py' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Get-Process ollama,"ollama app" -ErrorAction SilentlyContinue | Stop-Process -Force
  Write-Host "Router e Ollama parados."
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
if(-not (Test-Port 11434)){
  Write-Host "Iniciando servidor Ollama (ollama.exe serve, sem GUI)..."
  Start-Process -FilePath $OllamaApp -ArgumentList "serve" -WindowStyle Hidden
  Start-Sleep -Seconds 8
} else {
  Write-Host "Ollama ja estava ligado."
}
if(-not (Test-Path $Router)){ Write-Error "router.py nao encontrado em $Root"; exit 1 }
if(-not (Test-Port 20129)){
  Write-Host "Iniciando roteador KFAI (segundo plano)..."
  Start-Process -FilePath $Pythonw -ArgumentList "`"$Router`"" -WindowStyle Hidden -WorkingDirectory $Root
  Start-Sleep -Seconds 3
} else {
  Write-Host "Roteador ja estava ligado."
}
Write-Host "Pronto. Tudo rodando sem janelas."
if(-not (Test-Port 11434)){ Write-Host "AVISO: Ollama nao respondeu ainda. Se o PC e fraco, ele pode demorar." }
