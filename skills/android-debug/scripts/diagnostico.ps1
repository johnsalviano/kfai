# diagnostico.ps1 - Relatorio Android (somente leitura) via ADB
$ErrorActionPreference = 'Stop'

if(-not (Get-Command adb -ErrorAction SilentlyContinue)){
  Write-Host "ADB nao encontrado. Instale Android Platform-Tools:"
  Write-Host "  https://developer.android.com/tools/releases/platform-tools"
  exit 1
}

Write-Host "== Dispositivos ADB =="
adb devices

$serial = (adb devices | Select-String -Pattern "\tdevice$" | ForEach-Object { ($_ -split "\t")[0] } | Select-Object -First 1)
if(-not $serial){
  Write-Host "Nenhum aparelho conectado. No celular, ative: Opcoes do desenvolvedor >"
  Write-Host "Depuracao USB. (Em emulador ja instalado, abra-o antes.)"
  exit 1
}

Write-Host ""
Write-Host "== Apps instalados (pacotes) =="
adb -s $serial shell pm list packages -3 2>$null | ForEach-Object { $_ -replace '^package:','' } | Select-Object -First 60

Write-Host ""
Write-Host "== Bateria =="
adb -s $serial shell dumpsys battery 2>$null | Select-String "level|status"

Write-Host ""
Write-Host "Dica para acelerar: apps que voce nao usa -> desinstalar. Cache de app"
Write-Host "pesado -> Config > Apps > armazenamento > limpar cache."