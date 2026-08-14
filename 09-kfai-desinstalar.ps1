<#
  KFAI - Desinstalador (09-kfai-desinstalar.ps1)
  Remove o que o KFAI configurou nesta maquina, de forma guiada e segura.

  Por padrao mexe so no que e do proprio KFAI:
    - para os servicos (router proprio, 9Router e Ollama);
    - tira o autostart do Windows;
    - restaura/limpa o provider "kfai" da config global do opencode.
  Desinstalar os programas em si (Ollama, opencode, 9Router, AionUi, Node)
  e OPCIONAL - o script pergunta antes de cada um. Nada e apagado sem o sim.

  Uso:
    .\09-kfai-desinstalar.ps1              guiado: pergunta tudo
    .\09-kfai-desinstalar.ps1 -SoKfai      remove so as configs do KFAI, nao toca nos apps
    .\09-kfai-desinstalar.ps1 -Tudo        remove configs E desinstala os apps, sem perguntar
    .\09-kfai-desinstalar.ps1 -Limpo       desinstalacao LIMPA: alem do normal, apaga
                                          backups antigos, arquivos temporarios, pasta
                                          9router-src, modelos do Ollama, dados do AionUi
                                          e oferece apagar a pasta do KFAI inteira.
#>
[CmdletBinding()]
param(
  [switch]$SoKfai,
  [switch]$Tudo,
  [switch]$Limpo
)
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step([string]$m){ Write-Host "`n== $m ==" -ForegroundColor Cyan }

function Ask-YesNo([string]$Msg){
  if($SoKfai){ return $false }
  if($Tudo){ return $true }
  try { $r = Read-Host "$Msg (s/N)" } catch { $r = '' }
  return ($r -match '^(s|sim|y|yes)$')
}

# pergunta para coisas destrutivas (modelos, dados do app): com -Tudo nao pergunta
function Ask-Deep([string]$Msg){
  if($Tudo){ return $true }
  if($SoKfai){ return $false }
  try { $r = Read-Host "$Msg (s/N)" } catch { $r = '' }
  return ($r -match '^(s|sim|y|yes)$')
}

# O primeiro "confirma?" nao e suprimido pelos flags -SoKfai/-Tudo:
# quem escolheu um flag ja esta confirmando.
function Ask-FirstConfirm{
  if($SoKfai -or $Tudo){ return $true }
  return (Ask-YesNo "Deseja realmente desinstalar o KFAI desta maquina")
}

# acha o desinstalador silencioso de um programa (Inno: unins000.exe; NSIS: Uninstall*.exe)
function Find-Uninstaller([string]$Dir){
  if(-not (Test-Path -LiteralPath $Dir)){ return $null }
  $un = Join-Path $Dir "unins000.exe"
  if(Test-Path -LiteralPath $un){ return $un }
  $f = Get-ChildItem -LiteralPath $Dir -Filter "unins*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if($f){ return $f.FullName }
  $f = Get-ChildItem -LiteralPath $Dir -Filter "Uninstall*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if($f){ return $f.FullName }
  return $null
}

function Run-Silent([string]$FilePath,[string[]]$Args){
  try {
    Start-Process -FilePath $FilePath -ArgumentList $Args -Wait -ErrorAction SilentlyContinue
    return $true
  } catch { return $false }
}

Write-Host ""
Write-Host "KFAI - Desinstalador" -ForegroundColor White
if(-not (Ask-FirstConfirm)){
  Write-Host "Cancelado. Nada foi alterado." -ForegroundColor Green
  exit 0
}

# 1. para os servicos (router proprio, Ollama e 9Router)
Write-Step "Parando servicos"
$start = Join-Path $Root "05-kfai-start.ps1"
if(Test-Path -LiteralPath $start){
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start -Stop -With9Router | Out-Null
  Write-Host "Servicos parados." -ForegroundColor Green
} else {
  Write-Host "Script 05-kfai-start.ps1 nao encontrado; servicos podem continuar rodando." -ForegroundColor Yellow
}

# 2. tira o autostart do Windows
Write-Step "Removendo autostart do Windows"
if(Test-Path -LiteralPath $start){
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start -Unregister | Out-Null
}
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "KFAI Router" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "KFAI Ollama" -ErrorAction SilentlyContinue
Write-Host "Autostart removido (KFAI Router / KFAI Ollama)." -ForegroundColor Green

# 3. limpa a config global do opencode (provider "kfai")
Write-Step "Limpando a config global do opencode"
$ocDir = Join-Path $env:USERPROFILE ".config\opencode"
$ocPath = Join-Path $ocDir "opencode.json"
$bakDir = Join-Path $ocDir "backup"
if(Test-Path -LiteralPath $ocPath){
  $bak = Get-ChildItem -LiteralPath $bakDir -Filter "opencode.json.bak-*" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($bak){
    Write-Host "Restaurando o backup de antes do KFAI..." -ForegroundColor Cyan
    Copy-Item -LiteralPath $bak.FullName -Destination $ocPath -Force
    Write-Host "Config restaurada a partir de: $($bak.Name)" -ForegroundColor Green
  } else {
    try {
      $cfg = Get-Content -LiteralPath $ocPath -Raw | ConvertFrom-Json
      $hadKfai = $false
      if($cfg.provider -and $cfg.provider.kfai){
        $cfg.provider.PSObject.Properties.Remove('kfai') | Out-Null
        $hadKfai = $true
        Write-Host "Provider 'kfai' removido do opencode (o resto da config foi preservado)." -ForegroundColor Green
      }
      if([string]$cfg.model -like 'kfai/*'){
        $cfg.PSObject.Properties.Remove('model') | Out-Null
        $hadKfai = $true
        Write-Host "Modelo padrao 'kfai/...' removido (o opencode volta a pedir a escolha)." -ForegroundColor Green
      }
      if(-not $hadKfai){
        Write-Host "Nenhuma config do KFAI encontrada no opencode. Nada a limpar." -ForegroundColor DarkGray
      }
      $cfg | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ocPath -Encoding utf8
    } catch {
      Write-Host "Nao consegui editar a config do opencode automaticamente." -ForegroundColor Yellow
      Write-Host "Se quiser, remova manualmente a secao 'kfai' em: $ocPath" -ForegroundColor Yellow
    }
  }
} else {
  Write-Host "Nenhuma config global do opencode encontrada." -ForegroundColor DarkGray
}

# 4. AionUi: o provider so sai de dentro do proprio app
Write-Step "AionUi"
Write-Host "No AionUi, remova o provider 'KFAI Router' manualmente:" -ForegroundColor Yellow
Write-Host "  Configuracoes > Provedores > KFAI Router > Remover" -ForegroundColor Yellow
Write-Host "(o AionUi nao permite mexer nos provedores por fora do app, por seguranca dele.)" -ForegroundColor DarkGray

# 5. desinstalar os programas em si (opcional, pergunta um a um)
Write-Step "Desinstalar os programas (opcional)"
Write-Host "Isso NAO e necessario: o KFAI para de funcionar sem desinstalar os apps." -ForegroundColor DarkGray
Write-Host "Mas se voce quer remover tudo, responda sim abaixo." -ForegroundColor DarkGray

# opencode CLI (npm global)
if(Get-Command opencode -ErrorAction SilentlyContinue){
  if(Ask-YesNo "Desinstalar o opencode CLI (npm global)"){
    Write-Host "Desinstalando opencode-ai..." -ForegroundColor Cyan
    & npm uninstall -g opencode-ai 2>&1 | Out-Null
    Write-Host "opencode-ai desinstalado." -ForegroundColor Green
  }
}

# 9Router (npm global)
$nineCli = "$env:APPDATA\npm\node_modules\9router\cli.js"
if(Test-Path -LiteralPath $nineCli){
  if(Ask-YesNo "Desinstalar o 9Router (npm global)"){
    Write-Host "Desinstalando 9router..." -ForegroundColor Cyan
    & npm uninstall -g 9router 2>&1 | Out-Null
    Write-Host "9router desinstalado." -ForegroundColor Green
  }
} elseif(Test-Path "$env:USERPROFILE\9router-src\package.json"){
  Write-Host "9Router instalado pela fonte (9router-src): apague a pasta manualmente." -ForegroundColor Yellow
}

# Ollama (IA local)
$ollDir = "$env:LOCALAPPDATA\Programs\Ollama"
$ollUn = Find-Uninstaller $ollDir
if($ollUn){
  if(Ask-YesNo "Desinstalar o Ollama (IA local)"){
    Write-Host "Desinstalando Ollama..." -ForegroundColor Cyan
    Run-Silent $ollUn @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') | Out-Null
    Write-Host "Ollama desinstalado (os modelos baixados tambem saem)." -ForegroundColor Green
  }
} elseif(Get-Command ollama -ErrorAction SilentlyContinue){
  Write-Host "Ollama instalado, mas nao achei o desinstalador automatico." -ForegroundColor Yellow
  Write-Host "Desinstale em: Configuracoes > Aplicativos > Ollama." -ForegroundColor Yellow
}

# AionUi (app grafico)
$auiDir = "$env:LOCALAPPDATA\Programs\AionUi"
$auiUn = Find-Uninstaller $auiDir
if($auiUn){
  if(Ask-YesNo "Desinstalar o AionUi (app grafico)"){
    Write-Host "Desinstalando AionUi..." -ForegroundColor Cyan
    Run-Silent $auiUn @('/S') | Out-Null
    Write-Host "AionUi desinstalado." -ForegroundColor Green
  }
} elseif(Test-Path -LiteralPath (Join-Path $auiDir "AionUi.exe")){
  Write-Host "AionUi instalado, mas nao achei o desinstalador automatico." -ForegroundColor Yellow
  Write-Host "Desinstale em: Configuracoes > Aplicativos > AionUi." -ForegroundColor Yellow
}

# Node.js: so o instalado na pasta do usuario PELO KFAI (o do sistema nao mexe)
$nodeUser = "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
if(Test-Path -LiteralPath $nodeUser){
  if(Ask-YesNo "Remover o Node.js que o KFAI instalou na pasta do usuario"){
    Write-Host "Removendo Node.js da pasta do usuario..." -ForegroundColor Cyan
    Remove-Item -LiteralPath "$env:LOCALAPPDATA\Programs\nodejs" -Recurse -Force -ErrorAction SilentlyContinue
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if($userPath -like "*nodejs*"){
      $novo = (($userPath -split ';') | Where-Object { $_ -notlike "*\nodejs*" }) -join ';'
      [Environment]::SetEnvironmentVariable("Path",$novo,"User")
      Write-Host "Entrada do Node.js removida do PATH do usuario." -ForegroundColor Green
    }
    Write-Host "Node.js do usuario removido." -ForegroundColor Green
  }
} else {
  Write-Host "Node.js: e do sistema; o KFAI nao o desinstala (outros programas podem depender dele)." -ForegroundColor DarkGray
}

# 6. limpeza profunda (modo -Limpo): sobras que uma desinstalacao normal deixa
if($Limpo){
  Write-Step "Limpeza profunda (modo limpo)"
  Write-Host "Vou apagar tambem as sobras que a desinstalacao normal deixa." -ForegroundColor Cyan

  # backups antigos da config do opencode
  Get-ChildItem -LiteralPath $bakDir -Filter "opencode.json.bak-*" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  Write-Host "Backups antigos da config do opencode apagados." -ForegroundColor DarkGray

  # arquivos temporarios do instalador
  Remove-Item -LiteralPath (Join-Path $env:TEMP "Modelfile-kfai") -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $env:TEMP "OllamaSetup.exe") -Force -ErrorAction SilentlyContinue
  Get-ChildItem -LiteralPath $env:TEMP -Filter "AionUi-*-win-x64.exe" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  Write-Host "Arquivos temporarios do instalador apagados." -ForegroundColor DarkGray

  # pasta 9router-src (instalacao pela fonte)
  $nineSrc = "$env:USERPROFILE\9router-src"
  if(Test-Path -LiteralPath $nineSrc){
    if(Ask-Deep "Apagar a pasta 9router-src (fonte do 9Router)"){
      Remove-Item -LiteralPath $nineSrc -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "Pasta 9router-src apagada." -ForegroundColor Green
    }
  }

  # modelos do Ollama (a pasta .ollama) - so se nao estiver mais em uso
  $ollHome = "$env:USERPROFILE\.ollama"
  if(Test-Path -LiteralPath $ollHome){
    if(Ask-Deep "Apagar os modelos baixados do Ollama (~\.ollama, podem ser varios GB)"){
      Get-Process ollama -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $ollHome -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "Modelos do Ollama apagados." -ForegroundColor Green
    }
  }

  # dados do AionUi (conversas/config do app)
  $auiData = "$env:APPDATA\AionUi"
  if(Test-Path -LiteralPath $auiData){
    if(Ask-Deep "Apagar os dados do AionUi (~\AppData\Roaming\AionUi, conversas e config)"){
      Remove-Item -LiteralPath $auiData -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "Dados do AionUi apagados." -ForegroundColor Green
    }
  }
}

# 7. oferta final: apagar a pasta do KFAI inteira (so no modo limpo)
if($Limpo -and -not $SoKfai){
  $del = $false
  if($Tudo){ $del = $true } else {
    try { $r = Read-Host "Apagar tambem a pasta do KFAI (esta pasta, com tudo dentro)? (s/N)" } catch { $r = '' }
    $del = ($r -match '^(s|sim|y|yes)$')
  }
  if($del){
    Write-Host "A pasta do KFAI sera apagada em 3 segundos..." -ForegroundColor Yellow
    # um powershell novo espera este script sair e entao remove a pasta inteira
    $ps = (Get-Command powershell).Source
    $cmd = "Start-Sleep -Seconds 3; Remove-Item -LiteralPath '$Root' -Recurse -Force"
    Start-Process $ps -ArgumentList '-NoProfile','-Command',$cmd -WindowStyle Hidden
  }
}

Write-Step "Concluido"
if($Limpo -and -not $SoKfai){
  Write-Host "Desinstalacao LIMPA concluida: nao sobraram configs, backups nem modelos do KFAI." -ForegroundColor Green
} else {
  Write-Host "O KFAI foi desinstalado desta maquina." -ForegroundColor Green
  Write-Host "Para terminar, apague a pasta do KFAI manualmente (ela contem este arquivo)." -ForegroundColor Yellow
}
Write-Host "Se criou atalhos na Area de Trabalho ou no Menu Iniciar, apague-os tambem." -ForegroundColor Yellow
