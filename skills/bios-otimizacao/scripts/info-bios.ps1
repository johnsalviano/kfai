# info-bios.ps1 - Identifica placa-mae e versao da BIOS (somente leitura)
$ErrorActionPreference = 'Stop'

Write-Host "== Informacoes de BIOS / Placa-mae =="
$mb  = Get-CimInstance Win32_BaseBoard
$bios= Get-CimInstance Win32_BIOS

Write-Host "Fabricante placa: $($mb.Manufacturer)"
Write-Host "Modelo placa    : $($mb.Product)"
Write-Host "Versao BIOS      : $($bios.SMBIOSBIOSVersion) (data $($bios.ReleaseDate))"
Write-Host ""
Write-Host "Dica: teclas comuns para entrar na BIOS: Del, F2, F10 ou F12."
Write-Host "(anonte; a tecla exata varia por placa-mae. Veja o modelo acima.)"