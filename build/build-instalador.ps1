<#
  KFAI - Build do instalador em executavel (.exe)
  Converte install.ps1 em KFAI-Instalador.exe usando o ps2exe.
  Quem preferir pode usar o .ps1 direto; o .exe e so uma comodidade
  para quem tem a Execution Policy do PowerShell bloqueada.

  Requisitos: modulo ps2exe (Install-Module ps2exe -Scope CurrentUser)
  Uso: .\build\build-instalador.ps1 [-SkipPs2ExeInstall]
#>
[CmdletBinding()]
param(
  [switch]$SkipPs2ExeInstall
)

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$In   = Join-Path $Root "install.ps1"
$Out  = Join-Path $Root "KFAI-Instalador.exe"

if(-not (Test-Path -LiteralPath $In)){
  Write-Error "install.ps1 nao encontrado em $In"
  exit 1
}

if(-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)){
  if($SkipPs2ExeInstall){
    Write-Error "ps2exe nao instalado. Instale com: Install-Module ps2exe -Scope CurrentUser"
    exit 1
  }
  Write-Host "Instalando o modulo ps2exe (uma vez so)..." -ForegroundColor Cyan
  Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}

Write-Host "Gerando executavel a partir de install.ps1..." -ForegroundColor Cyan
# Sem -NoError/-NoOutput: essas flags do ps2exe suprimem TODA saida e prompts
# do exe (tela preta "sem nada"). O instalador precisa mostrar o que faz.
Invoke-ps2exe -InputFile $In -OutputFile $Out -Verbose:$false

if(-not (Test-Path -LiteralPath $Out)){
  Write-Error "Falha ao gerar o executavel."
  exit 1
}

$h = (Get-FileHash -LiteralPath $Out -Algorithm SHA256).Hash
Write-Host ""
Write-Host "Executavel gerado: $Out" -ForegroundColor Green
Write-Host "SHA-256: $h"
Write-Host ""
Write-Host "Anexe ao release e publique o hash no README."
