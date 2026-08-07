# teste-ping.ps1 - Verifica ping e perda de pacotes p/ 2 servidores
Write-Host "== Teste de conexao (ping/latencia) =="
Write-Host "Ping baixo = boa resposta. Perda de pacotes = queda / travamento."
Write-Host ""

foreach($h in @('8.8.8.8','1.1.1.1')){
  Write-Host "--- $h ---"
  ping -n 8 $h | Select-String "estat|Packets|Mínimo|Minimo|perdidos|loss" | ForEach-Object { $_.Line }
  Write-Host ""
}
Write-Host "Dica: ping instavel (picos grandes) sugere problema de WiFi ou roteador."
Write-Host "Se cair muito, teste com cabo de rede direto."