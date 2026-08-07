# limpeza-disco.ps1 - Limpeza segura de arquivos temporarios
# Nao toca em arquivos pessoais. Mostra o que vai apagar antes de remover.
$ErrorActionPreference = 'Stop'

$alvos = @(
  "$env:TEMP\*",
  "$env:LOCALAPPDATA\Temp\*",
  "C:\Windows\Temp\*"
)

$total = 0
$itens = @()

foreach($t in $alvos){
  Get-Item $t -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
      $itens += [pscustomobject]@{ Caminho=$_.FullName; TamanhoMB=[math]::Round($size/1MB,1) }
    } catch { $itens += [pscustomobject]@{ Caminho=$_.FullName; TamanhoMB=0 } }
  }
}

Write-Host "== Limpeza segura de temporarios =="
$itens | Format-Table -AutoSize

$totalMB = ($itens | Measure-Object TamanhoMB -Sum).Sum
Write-Host "Total que pode ser liberado: $([math]::Round($totalMB,1)) MB"
$resp = Read-Host "Apagar esses arquivos? (S/N)"
if($resp -match '^[sS]$'){
  foreach($i in $itens){ Remove-Item $i.Caminho -Recurse -Force -ErrorAction SilentlyContinue }
  Write-Host "Limpeza concluida." -ForegroundColor Green
} else {
  Write-Host "Nada foi apagado."
}