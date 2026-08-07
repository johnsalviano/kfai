# testar-dns.ps1 - Compara tempo de resposta de DNS conhecidos (so leitura)
# Na troca de DNS. Mostra qual responde mais rapido p/ a pessoa decidir.
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "== Comparacao de DNS =="
Write-Host "DNS = 'lista telefonica' da internet. Um DNS rapido pode abrir paginas mais cedo."
Write-Host ""

$testes = @(
  @{ Nome='Google';     Servidor='8.8.8.8' }
  @{ Nome='Cloudflare'; Servidor='1.1.1.1' }
  @{ Nome='Provedor';   Servidor='208.67.222.222' }  # OpenDNS como referencia
)

foreach($t in $testes){
  $tempo = Measure-Command { ping -n 4 $t.Servidor | Out-Null }
  Write-Host ("{0,-12} {1}  ->  {2,6:N0} ms (media de 4 pings)" -f $t.Nome, $t.Servidor, $tempo.TotalMilliseconds/4)
}

Write-Host ""
Write-Host "Mudar o DNS e OPCIONAL e deve ser combinado antes. Se quiser trocar:"
Write-Host "  Configuracoes de Rede > adaptador > IPV4 > DNS manual"
Write-Host "  Ex.: 1.1.1.1 (Cloudflare) ou 8.8.8.8 (Google)"
Write-Host "Anote o DNS antigo para poder voltar."