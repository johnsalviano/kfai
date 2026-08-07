# lista-inicializacao.ps1 - Lista programas que iniciam junto com o Windows
# So lista, nao altera nada. A decisao de desativar e do usuario.
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "== Programas de inicializacao (somente leitura) =="
Write-Host ""
Write-Host "[ Gerenciador de Tarefas - coluna Inicializar ]"
Write-Host "Abra: Ctrl+Shift+Esc  >  aba Inicializar"
Write-Host ""
Write-Host "[ Programas com 'Run' no registro ]"
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | Format-List

Write-Host ""
Write-Host "Dica: desative no Gerenciador de Tarefas apenas o que voce reconhece"
Write-Host "(ex.: updater de programas que nao usa). NAO desative antivirus/drivers."
Write-Host "Muitos programas entrar na inicializacao deixam o PC mais lento ao ligar."