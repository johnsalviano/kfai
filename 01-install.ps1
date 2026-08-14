<#
  KFAI - Kit de Ferramentas de Agente de IA
  Instalador (pt-BR, guiado)
  Nao instala Ollama em PC fraco demais. Detecta hardware e escolhe modelo certo.
  Nao toca em chaves de ninguem - tudo nasce com SUA_CHAVE_AQUI.
  -Atualizar: sobe de versao (no lugar) os programas que ja estao instalados
  e tiverem versao nova. NUNCA instala uma segunda copia do mesmo programa.
  -Limpo: apaga a config/combos ANTIGOS do KFAI e configura do zero (resolve
  bug de configuracao). NAO apaga suas chaves do 9Router nem os modelos baixados.
#>
[CmdletBinding()]
param(
  [switch]$SkipOllama,
  [switch]$Atualizar,
  [switch]$Limpo,
  [string]$MsiOptions
)
$ErrorActionPreference = 'Stop'

# Descobre a pasta deste instalador de forma resiliente:
# - quando rodado como .ps1, usa $PSScriptRoot (ou $MyInvocation...);
# - quando compilado em .exe (ps2exe), $PSCommandPath/$MyInvocation ficam vazios
#   e a pasta e a mesma do proprio executavel.
$Root = $PSScriptRoot
if(-not $Root -and $MyInvocation.MyCommand.Path){ $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if(-not $Root){
  try { $Root = Split-Path -Parent ([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {}
}
if(-not $Root){ $Root = Get-Location }

# MSI (KFAI-Instalador.msi): recebe as opcoes marcadas no wizard como
# "OLLAMA;OPENCODE;AIONUI;AUTOSTART" (cada campo "1" = marcado). Fora do MSI
# (rodado na mao), $MsiOptions fica vazio e o comportamento nao muda.
$SkipOpencode  = $false
$SkipAionUi    = $false
$SkipAutostart = $false
if($MsiOptions){
  $opt = $MsiOptions -split ';'
  if($opt[0] -ne '1'){ $SkipOllama = $true }
  if($opt[1] -ne '1'){ $SkipOpencode = $true }
  if($opt[2] -ne '1'){ $SkipAionUi = $true }
  if($opt[3] -ne '1'){ $SkipAutostart = $true }
}

$CanonicalRepoUrl = 'https://github.com/johnsalviano/kfai'

# Versao do kit: vem do arquivo VERSION na raiz do pacote.
function Get-KitVersion {
  $v = Join-Path $Root "VERSION"
  if(Test-Path -LiteralPath $v){ return (Get-Content -LiteralPath $v -Raw).Trim() }
  return '0.2.0'
}

function Write-Step([string]$m){ Write-Host "`n== $m ==" -ForegroundColor Cyan }

function Test-OfficialOrigin {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $origin = (& git -C $Root remote get-url origin 2>$null)
  $ErrorActionPreference = $prevEap
  $origin = if($origin){ $origin.Trim() } else { '' }
  # Normaliza para comparar igual: '.../kfai.git' e '.../kfai' sao o mesmo repo.
  $originNormalized  = ($origin  -replace '\.git$', '')
  $canonicalNormalized = ($CanonicalRepoUrl -replace '\.git$', '')
  if(-not $origin){
    # Sem remote: veio de ZIP/extraido, copia manual ou executavel compilado.
    # Nao da para confirmar a origem por git — avisamos e pedimos confirmacao
    # explicita ao usuario (para nao travar o instalador em executavel).
    Write-Step "ALERTA: nao consegui confirmar a origem deste instalador"
    Write-Host "Nao ha repositorio git (remote) nesta pasta. Copias extraidas de ZIP" -ForegroundColor Yellow
    Write-Host "ou repassadas por terceiros PODEM ser adulteradas." -ForegroundColor Yellow
    Write-Host "Confira o SHA-256 mostrado no final contra o publicado em $CanonicalRepoUrl" -ForegroundColor Yellow
    Write-Host "ou rode o instalador a partir do repositorio oficial." -ForegroundColor Yellow
    try {
      $resp = Read-Host "Voce baixou este instalador do repositorio oficial $CanonicalRepoUrl? (s/N)"
    } catch {
      $resp = ''
    }
    if($resp -match '^(s|sim|y|yes)$'){ return $true }
    Write-Host "Instalacao cancelada pelo usuario. Baixe do repositorio oficial para continuar." -ForegroundColor Red
    return $false
  }
  if($originNormalized -ne $canonicalNormalized){
    Write-Step "ALERTA: origem deste script nao e a oficial"
    Write-Host "Origin : $origin" -ForegroundColor Red
    Write-Host "Oficial: $CanonicalRepoUrl" -ForegroundColor Yellow
    Write-Host "Voce pode estar usando uma copia adulterada. Rode o KFAI a partir do repositorio oficial." -ForegroundColor Red
    return $false
  }
  return $true
}

function Show-IntegrityHash {
  # Em .ps1 o caminho e o proprio script; em .exe (ps2exe) e o executavel em si.
  $self = $PSCommandPath
  if(-not $self){
    try { $self = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch {}
  }
  if(-not $self){
    Write-Host "Nao consegui calcular o hash proprio." -ForegroundColor Yellow
    return
  }
  $h = (Get-FileHash -LiteralPath $self -Algorithm SHA256).Hash
  Write-Host "`nIntegridade (SHA-256) deste instalador:"
  Write-Host $h -ForegroundColor Green
  Write-Host "Compare com o valor publicado na pagina oficial do repositorio KFAI." -ForegroundColor Yellow
}

function Get-RealVram {
  # AdapterRAM do WMI trunca em ~4GB (campo UInt32) - bug conhecido da Microsoft.
  # Fonte confiavel: NVML do driver NVIDIA (nvidia-smi). Fallback: WMI.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $smi = & nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null
    $ErrorActionPreference = $prevEap
    if($smi){
      $mib = $smi | Select-Object -First 1
      $n = 0.0
      if([double]::TryParse(($mib -replace '[^0-9.]',''), [ref]$n) -and $n -gt 0){
        return @{ VramGb = [math]::Round($n / 1024, 1); Source = 'nvidia-smi' }
      }
    }
  } catch { }
  $ErrorActionPreference = $prevEap
  $adapter = Get-CimInstance Win32_VideoController | Sort-Object AdapterRAM -Descending | Select-Object -First 1
  $vramGb = if($adapter.AdapterRAM){ [math]::Round($adapter.AdapterRAM / 1GB, 1) } else { 0 }
  return @{ VramGb = $vramGb; Source = 'WMI (AdapterRAM, pode subestimar placa >4GB)' }
}

function Get-HardwareInfo {
  $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
  $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
  $gpus = Get-CimInstance Win32_VideoController
  $adapter = $gpus | Sort-Object AdapterRAM -Descending | Select-Object -First 1
  $vram = Get-RealVram
  return @{ Ram = $ramGb; Cpu = $cpu; Vram = $vram.VramGb; VramSource = $vram.Source; Gpu = $adapter.Name }
}

function ChooseLocalModel($hw){
  if($hw.Ram -le 3){ return $null }
  # qwen3 tem tools + contexto longo nativo (4b = 2.5GB, 256K ctx). Ver
  # https://ollama.com/library/qwen3 c/ tag tools.
  if($hw.Vram -ge 6){ return 'qwen3:4b' }
  if($hw.Ram -lt 8){ return 'qwen3:0.6b' }
  if($hw.Ram -lt 16){ return 'qwen3:4b' }
  if($hw.Vram -ge 4){ return 'qwen3:4b' }
  if($hw.Ram -ge 32){ return 'qwen3:14b' }
  return 'qwen3:4b'
}

function Test-IsAdmin {
  $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- acha um instalador incluso no pacote (pasta instaladores\) ---
# O pacote pode vir com os apps empacotados para nao depender de downloads
# nem de o usuario rodar instaladores na mao. Retorna o caminho ou $null.
function Get-BundledInstaller {
  param([string]$Pattern)
  $dir = Join-Path $Root "instaladores"
  if(-not (Test-Path -LiteralPath $dir)){ return $null }
  $m = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -like $Pattern } | Select-Object -First 1
  if($m){ return $m.FullName }
  return $null
}

# --- roda um instalador incluso em modo silencioso ---
# MSI usa msiexec /qn; exe NSIS usa /S. Nao exige interacao do usuario.
function Install-BundledInstaller {
  param(
    [string]$DisplayName,
    [string]$Pattern,
    [string[]]$SilentArgs
  )
  $file = Get-BundledInstaller -Pattern $Pattern
  if(-not $file){ return @{ Ok=$false; Bundled=$false } }
  Write-Host "Instalando $DisplayName em silencio (instalador incluso no pacote)..."
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    if($file -like '*.msi'){
      Start-Process msiexec -ArgumentList "/i","`"$file`"","/qn","/norestart" -Wait -ErrorAction SilentlyContinue
    } else {
      $p = Start-Process -FilePath $file -ArgumentList $SilentArgs -Wait -PassThru -ErrorAction SilentlyContinue
    }
  } catch { }
  $ErrorActionPreference = $prevEap
  return @{ Ok=$true; Bundled=$true }
}

# --- pega a versao "latest" de um repo no GitHub (API oficial) ---
function Get-GitHubLatestTag {
  param([string]$Repo)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent'='KFAI' } -TimeoutSec 30
    $ErrorActionPreference = $prevEap
    if($rel -and $rel.tag_name){ return $rel.tag_name.TrimStart('v') }
  } catch { $ErrorActionPreference = $prevEap }
  return ''
}

# --- SHA-256 oficial de um asset de release do GitHub (API publica) ---
# O GitHub publica o digest (sha256) de cada asset na API de releases.
# Retorna '' quando nao ha checksum publicado (ex.: releases sem assets).
function Get-GitHubAssetSha256 {
  param([string]$Repo, [string]$AssetName)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent'='KFAI' } -TimeoutSec 30
    $ErrorActionPreference = $prevEap
    if(-not $rel -or -not $rel.assets){ return '' }
    foreach($a in $rel.assets){
      if($a.name -eq $AssetName -and $a.digest){ return ([string]$a.digest).Trim() }
    }
  } catch { $ErrorActionPreference = $prevEap }
  return ''
}

# --- confere a integridade de um arquivo baixado (SHA-256) ---
# Aceita o digest do GitHub ("sha256:...") ou hash puro. Se nenhum esperado
# for informado (fonte oficial nao publica checksum), passa sem bloquear.
function Assert-FileSha256 {
  param(
    [string]$Path,
    [string]$ExpectedSha256,
    [string]$DisplayName
  )
  if([string]::IsNullOrWhiteSpace($ExpectedSha256)){ return $true }
  $clean = $ExpectedSha256.Trim().ToLowerInvariant()
  if($clean -like 'sha256:*'){ $clean = $clean.Substring(7) }
  if($clean -notmatch '^[0-9a-f]{64}$'){
    Write-Host "AVISO: hash esperado de $DisplayName em formato invalido; verificacao pulada." -ForegroundColor Yellow
    return $true
  }
  try {
    $h = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if($h -eq $clean){ return $true }
    Write-Host "FALHA de integridade: $DisplayName NAO confere com o SHA-256 oficial." -ForegroundColor Red
    Write-Host "  Esperado: $clean" -ForegroundColor Red
    Write-Host "  Baixado:  $h" -ForegroundColor Red
    return $false
  } catch {
    Write-Host "AVISO: nao consegui calcular o SHA-256 de $DisplayName." -ForegroundColor Yellow
    return $true
  }
}

# --- baixa um instalador exe do proprio site oficial e roda em silencio ---
# Usa sempre a versao mais recente oficial. NSIS aceita /S.
# Se -ExpectedSha256 for informado (checksum publicado pela fonte oficial),
# o arquivo baixado e conferido antes de executar.
function Install-FromOfficialUrl {
  param(
    [string]$DisplayName,
    [string]$Url,
    [string]$LocalName,
    [string]$ExpectedSha256
  )
  $local = Join-Path $env:TEMP $LocalName
  Write-Host "Baixando $DisplayName (versao mais recente oficial, pode demorar)..."
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    Invoke-WebRequest -Uri $Url -OutFile $local -UseBasicParsing -TimeoutSec 900
    if(Test-Path -LiteralPath $local){
      if(Assert-FileSha256 -Path $local -ExpectedSha256 $ExpectedSha256 -DisplayName $DisplayName){
        Write-Host "Instalando $DisplayName em silencio..."
        Start-Process -FilePath $local -ArgumentList '/S' -Wait -ErrorAction SilentlyContinue
      } else {
        Write-Host "Instalacao de $DisplayName ABORTADA (hash nao confere)." -ForegroundColor Red
      }
    }
  } catch {
    Write-Host "Falha ao baixar $DisplayName de $Url." -ForegroundColor Yellow
  }
  Remove-Item -LiteralPath $local -Force -ErrorAction SilentlyContinue
  $ErrorActionPreference = $prevEap
}

# Node.js e pre-requisito do 9Router. Retorna true se node+npm funcionam.
function Test-NodeJs {
  $node = (Get-Command node -ErrorAction SilentlyContinue).Source
  $npm  = (Get-Command npm  -ErrorAction SilentlyContinue).Source
  if(-not $node -or -not $npm){ return $false }
  return $true
}

# Versao LTS atual do Node (API oficial). Fallback em caso de offline.
function Get-NodeLtsVersion {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $json = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -TimeoutSec 30
    $ErrorActionPreference = $prevEap
    $lts = @($json | Where-Object { $_.lts }) | Select-Object -First 1
    if($lts -and $lts.version){ return $lts.version }
  } catch { $ErrorActionPreference = $prevEap }
  return 'v22.16.0'  # fallback se a API nao responder
}

# Instala Node.js na pasta do USUARIO (sem admin). Fonte oficial nodejs.org.
function Install-NodeJsPerUser {
  param([string]$Version)
  $destDir = Join-Path $env:LOCALAPPDATA "Programs\nodejs"
  $zipPath = Join-Path $env:TEMP "node-$Version-win-x64.zip"
  $extract = Join-Path $env:TEMP "node-$Version-win-x64"
  $url = "https://nodejs.org/dist/$Version/node-$Version-win-x64.zip"
  $sumsUrl = "https://nodejs.org/dist/$Version/SHASUMS256.txt"

  Write-Host "Baixando Node.js $Version (arquivo oficial, ~30 MB)..."
  try {
    # A fonte oficial publica os hashes SHA-256 de todos os arquivos.
    # Baixamos a lista e conferimos o zip antes de extrair (integridade).
    $expected = ""
    try {
      $sums = (Invoke-WebRequest -Uri $sumsUrl -UseBasicParsing -TimeoutSec 30).Content
      $line = ($sums -split "`n" | Where-Object { $_ -like "*node-$Version-win-x64.zip*" } | Select-Object -First 1)
      if($line){ $expected = (($line -split '\s+')[0]).Trim() }
    } catch { }
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
    if(-not (Assert-FileSha256 -Path $zipPath -ExpectedSha256 $expected -DisplayName "Node.js $Version")){
      Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
      Write-Error "Falha de integridade no download do Node.js. Baixe manualmente de https://nodejs.org e rode este script de novo."
      return $false
    }
  } catch {
    Write-Error "Falha ao baixar Node.js de $url. Verifique sua internet."
    return $false
  }

  Write-Host "Extraindo para a pasta do usuario..."
  if(Test-Path $extract){ Remove-Item $extract -Recurse -Force }
  Expand-Archive -LiteralPath $zipPath -DestinationPath $env:TEMP -Force

  New-Item -ItemType Directory -Path $destDir -Force | Out-Null
  Copy-Item -Path (Join-Path $extract "*") -Destination $destDir -Recurse -Force
  Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
  Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue

  # Adiciona ao PATH do usuario (registro HKCU, sem admin) e da sessao atual.
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if($userPath -notlike "*$destDir*"){
    [Environment]::SetEnvironmentVariable("Path", "$destDir;$userPath", "User")
  }
  $env:Path = "$destDir;$env:Path"
  return $true
}

# Instala Node.js tentando primeiro o modo normal (administrador).
# Se o PC for de empresa/gerenciado e nao tiver admin (ou a instalacao normal
# for bloqueada), cai para a pasta do usuario local (sem precisar de permissao).
# Avisa o usuario SO nesse caso especifico.
function Ensure-NodeJs {
  if(Test-NodeJs){ Write-Host "Node.js OK (node + npm encontrados)."; return $true }
  Write-Step "Node.js nao encontrado - necessario antes de tudo"
  Write-Host "O 9Router (roteador de IA em nuvem) exige Node.js. Vamos resolver isso."

  # Prefere o MSI que vem junto no pacote (instaladores\) antes de baixar.
  $bundledMsi = Get-BundledInstaller -Pattern 'node-*.msi'
  if($bundledMsi){
    Write-Host "Instalador do Node.js incluso no pacote encontrado. Instalando em silencio..."
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Start-Process msiexec -ArgumentList "/i","`"$bundledMsi`"","/qn","/norestart" -Wait -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $ErrorActionPreference = $prevEap
    if(Test-NodeJs){
      Write-Host "Node.js instalado com sucesso (MSI do pacote)." -ForegroundColor Green
      return $true
    }
    Write-Host "MSI executado, mas node/npm ainda nao reconhecidos. Tentando o caminho normal..." -ForegroundColor Yellow
  }

  if(Test-IsAdmin){
    # Com admin: tenta instalacao automatica (winget). Se falhar, per-usuario.
    Write-Host "Voce e administrador. Tentando instalar o Node.js LTS (winget)..."
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
    $wingetOk = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prevEap
    if($wingetOk){
      Start-Sleep -Seconds 3
      if(Test-NodeJs){ Write-Host "Node.js instalado com sucesso." -ForegroundColor Green; return $true }
      Write-Host "Instalado, mas node/npm ainda nao estao no PATH desta sessao." -ForegroundColor Yellow
    }
    Write-Host "Instalacao normal nao concluiu. Cai para a pasta do usuario local..." -ForegroundColor Yellow
  } else {
    # Sem admin: instala na pasta do usuario local, sem depender de permissao.
    Write-Host "Sem permissao de administrador nesta sessao. Tudo bem:" -ForegroundColor Yellow
    Write-Host "vou instalar o Node.js na pasta do USUARIO (nao precisa de" -ForegroundColor Yellow
    Write-Host "administrador nem de senha)." -ForegroundColor Yellow
  }

  $version = Get-NodeLtsVersion
  if(Install-NodeJsPerUser -Version $version){
    Start-Sleep -Seconds 2
    if(Test-NodeJs){
      Write-Host "Node.js $version instalado na pasta do usuario. Node e npm funcionando." -ForegroundColor Green
      return $true
    }
    Write-Error "Node.js instalado, mas node/npm ainda nao foram reconhecidos. Abra um terminal novo e rode este script de novo."
    return $false
  }
  return $false
}

# Origem verificada (git remote) so quando rodado como script avulso.
# No MSI oficial (KFAI-Instalador.msi) a origem ja e garantida pelo pacote,
# e na pasta instalada nao ha repositorio git — pular para nao travar.
if(-not $MsiOptions -and -not (Test-OfficialOrigin)){ exit 1 }

if(-not (Ensure-NodeJs)){ Write-Host "Impossivel continuar sem Node.js. Abra um terminal novo apos instalar e tente de novo." -ForegroundColor Red; exit 1 }

Write-Step "KFAI - Kit de Ferramentas de Agente de IA (v$(Get-KitVersion))"
$hw = Get-HardwareInfo
Write-Host "RAM: $($hw.Ram) GB | CPU: $($hw.Cpu) | GPU VRAM: $($hw.Vram) GB ($($hw.Gpu)) [fonte: $($hw.VramSource)]"

$model = ChooseLocalModel $hw
$useLocal = ($model -ne $null -and -not $SkipOllama)

# --- verifica se o Ollama esta instalado (antes de tentar usar) ---
function Test-OllamaInstalled {
  $cmd = (Get-Command ollama -ErrorAction SilentlyContinue).Source
  $serverUp = $false
  try {
    $c = New-Object Net.Sockets.TcpClient
    try { $c.Connect("127.0.0.1", 11434); $serverUp = $true } finally { $c.Dispose() }
  } catch {}
  return @{ Cmd = $cmd; ServerUp = $serverUp }
}

# --- garante o Ollama instalado. Baixa o instalador oficial (latest) e
# roda em silencio. A URL fixa aponta sempre para a versao mais recente. ---
function Ensure-Ollama {
  $oll = Test-OllamaInstalled
  if($oll.Cmd){
    Write-Host "Ollama instalado: $($oll.Cmd)"
    return $true
  }
  Write-Host "Ollama nao encontrado. Baixando instalador oficial..." -ForegroundColor Yellow
  Install-FromOfficialUrl -DisplayName 'Ollama' -Url 'https://ollama.com/download/OllamaSetup.exe' -LocalName 'OllamaSetup.exe'
  Start-Sleep -Seconds 3
  $oll2 = Test-OllamaInstalled
  if($oll2.Cmd){
    Write-Host "Ollama instalado com sucesso (ultima versao oficial)." -ForegroundColor Green
    return $true
  }
  Write-Host "Ollama instalado, mas nao localizado nesta sessao." -ForegroundColor Yellow
  Write-Host "Abra um terminal novo e rode: ollama --version" -ForegroundColor Yellow
  return $true
}

# --- verifica se um modelo ja esta baixado no Ollama (sem duplicar download) ---
function Test-OllamaModel {
  param([string]$Name)
  try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 10
    if($null -eq $tags.models){ return $false }
    $found = $false
    foreach($m in $tags.models){
      if($m.name -eq $Name -or $m.name.StartsWith("$($Name):")){ $found = $true; break }
    }
    return $found
  } catch { return $false }
}

# --- cria o modelo derivado -64k (num_ctx 65536 baked) para agentes locais ---
# O Ollama usa contexto 4096 por padrao e trunca silenciosamente, quebrando
# tool calling. Modelos com "tools" precisam de contexto grande. Os docs
# oficiais do opencode exigem 64k+: https://docs.ollama.com/integrations/opencode
function Ensure-NumCtxModel {
  param([string]$BaseModel)
  if(-not $BaseModel){ return "" }
  $base = ($BaseModel -replace ':.*$', '')
  $derived = "$base-64k"
  if(Test-OllamaModel -Name $derived){
    Write-Host "Modelo $derived ja existe (contexto 64k)." -ForegroundColor DarkGray
    return $derived
  }
  Write-Host "Criando $derived (contexto 64k para agentes)..." -ForegroundColor Cyan
  $mf = Join-Path $env:TEMP "Modelfile-kfai"
  try {
    Set-Content -Path $mf -Value "FROM $BaseModel`nPARAMETER num_ctx 65536" -Encoding utf8
    $null = ollama create $derived -f $mf 2>&1
    if(Test-OllamaModel -Name $derived){
      Write-Host "$derived criado. Agora o agente local nao quebra por contexto 4096." -ForegroundColor Green
      return $derived
    }
    Write-Host "AVISO: nao criei $derived. O agente local pode truncar contexto." -ForegroundColor Yellow
    return $BaseModel
  } catch {
    Write-Host "AVISO: nao criei $derived. O agente local pode truncar contexto." -ForegroundColor Yellow
    return $BaseModel
  }
}

# --- verifica se o 9Router esta instalado (CLI npm global OU 9router-src) ---
function Test-NineRouterInstalled {
  $cliNpm = "$env:APPDATA\npm\node_modules\9router\cli.js"
  $src    = "$env:USERPROFILE\9router-src\package.json"
  $viaNpm = Test-Path $cliNpm
  $viaSrc = Test-Path $src
  $portUp = $false
  try {
    $c = New-Object Net.Sockets.TcpClient
    try { $c.Connect("127.0.0.1", 20128); $portUp = $true } finally { $c.Dispose() }
  } catch {}
  if($viaNpm -or $viaSrc){ return @{ Ok=$true; ViaNpm=$viaNpm; ViaSrc=$viaSrc; PortUp=$portUp } }
  return @{ Ok=$false; ViaNpm=$false; ViaSrc=$false; PortUp=$portUp }
}

# --- verifica se o opencode esta instalado e sua versao (instalada vs mais recente) ---
function Test-OpencodeInstalled {
  $cmd = (Get-Command opencode -ErrorAction SilentlyContinue).Source
  if(-not $cmd){ return @{ Ok=$false; Version=''; Latest=''; Outdated=$false } }
  $ver = ''
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { $ver = (& opencode --version 2>$null | Select-Object -Last 1).Trim() } catch {}
  $ErrorActionPreference = $prevEap
  return @{ Ok=$true; Version=$ver; Latest=''; Outdated=$false }
}

# --- garante o app grafico OpenCode Desktop instalado ---
# Baixa a versao mais recente oficial do GitHub e instala em silencio.
function Ensure-OpencodeDesktop {
  if((Test-OpencodeInstalled).Ok){
    Write-Host "OpenCode CLI ja instalado; app grafico opcional." -ForegroundColor DarkGray
    return $true
  }
  $tag = Get-GitHubLatestTag -Repo 'anomalyco/opencode'
  if($tag){
    $url = "https://github.com/anomalyco/opencode/releases/download/v$tag/opencode-desktop-win-x64.exe"
    # Checksum oficial publicado pelo proprio GitHub na API de releases.
    $sha = Get-GitHubAssetSha256 -Repo 'anomalyco/opencode' -AssetName 'opencode-desktop-win-x64.exe'
    Install-FromOfficialUrl -DisplayName "OpenCode Desktop ($tag)" -Url $url -LocalName "opencode-desktop-win-x64.exe" -ExpectedSha256 $sha
    return $true
  }
  Write-Host "Nao consegui descobrir a versao mais recente do OpenCode." -ForegroundColor Yellow
  Write-Host "Instale do site oficial: https://opencode.ai" -ForegroundColor Yellow
  return $false
}

# --- versao mais recente do opencode no npm ---
function Get-OpencodeLatestVersion {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $latest = (& npm view opencode-ai version 2>$null | Select-Object -Last 1).Trim()
    $ErrorActionPreference = $prevEap
    if($latest){ return $latest }
  } catch { $ErrorActionPreference = $prevEap }
  return ''
}

# --- compara versoes "x.y.z" para saber se a instalada e mais nova/antiga ---
function Test-VersionOutdated {
  param([string]$Installed, [string]$Latest)
  if(-not $Installed -or -not $Latest){ return $false }
  $a = $Installed.TrimStart('v') -split '\.' | ForEach-Object { try { [int]$_ } catch { 0 } }
  $b = $Latest.TrimStart('v')  -split '\.' | ForEach-Object { try { [int]$_ } catch { 0 } }
  for($i=0; $i -lt [math]::Max($a.Count,$b.Count); $i++){
    $x = if($i -lt $a.Count){ $a[$i] } else { 0 }
    $y = if($i -lt $b.Count){ $b[$i] } else { 0 }
    if($x -lt $y){ return $true }
    if($x -gt $y){ return $false }
  }
  return $false
}

# --- versao do Ollama instalado (cliente) ---
function Get-OllamaVersion {
  $out = (& ollama --version 2>$null) -join "`n"
  $m = $out | Select-String -Pattern 'version is\s+(v?[\d.]+)' | Select-Object -First 1
  if($m){ return $m.Matches[0].Groups[1].Value.TrimStart('v') }
  return ''
}

# --- versao do 9Router instalado via npm global ---
function Get-NineRouterVersion {
  $out = (& npm ls -g 9router --depth=0 2>$null) -join "`n"
  $m = $out | Select-String -Pattern '9router@([\w.\-]+)' | Select-Object -First 1
  if($m){ return $m.Matches[0].Groups[1].Value }
  return ''
}

# --- pergunta se quer atualizar (s/N). Em modo -Atualizar nunca pergunta. ---
function Confirm-Update([string]$Name,[string]$Ver,[string]$Latest){
  try { $r = Read-Host "Atualizar $Name ($Ver -> $Latest) agora? (s/N)" } catch { $r = '' }
  return ($r -match '^(s|sim|y|yes)$')
}

# --- atualiza (NO LUGAR) os programas que tiverem versao nova ---
# Nunca instala segunda copia: Ollama/AionUi/OpenCode Desktop usam o instalador
# oficial (que substitui a instalacao existente); opencode/9Router usam npm -g
# (que substitui a versao global). Com -Atualizar atualiza sem perguntar.
function Update-KfaiTools {
  param([switch]$Auto)
  $atualizado = 0
  $nenhum = $true

  # Ollama
  $oll = Test-OllamaInstalled
  if($oll.Cmd){
    $ver = Get-OllamaVersion
    $latest = Get-GitHubLatestTag -Repo 'ollama/ollama'
    if($latest -and $ver -and (Test-VersionOutdated -Installed $ver -Latest $latest)){
      $nenhum = $false
      Write-Host "Ollama desatualizado ($ver -> $latest)." -ForegroundColor Yellow
      if($Auto -or (Confirm-Update 'Ollama' $ver $latest)){
        Install-FromOfficialUrl -DisplayName "Ollama ($latest)" -Url 'https://ollama.com/download/OllamaSetup.exe' -LocalName 'OllamaSetup.exe'
        Start-Sleep -Seconds 3
        $v2 = Get-OllamaVersion
        if($v2 -and -not (Test-VersionOutdated -Installed $v2 -Latest $latest)){
          Write-Host "Ollama atualizado para $v2." -ForegroundColor Green
          $atualizado++
        } else {
          Write-Host "Ollama nao confirmou a atualizacao. Baixe em https://ollama.com/download quando puder." -ForegroundColor Yellow
        }
      } else {
        Write-Host "Ok, Ollama fica em $ver." -ForegroundColor DarkGray
      }
    } else {
      Write-Host "Ollama atualizado ($ver)." -ForegroundColor DarkGray
    }
  }

  # Opencode CLI (npm -g substitui a mesma instalacao)
  $oc = Test-OpencodeInstalled
  if($oc.Ok){
    $latest = Get-OpencodeLatestVersion
    if($latest -and (Test-VersionOutdated -Installed $oc.Version -Latest $latest)){
      $nenhum = $false
      Write-Host "Opencode desatualizado ($($oc.Version) -> $latest)." -ForegroundColor Yellow
      if($Auto -or (Confirm-Update 'Opencode' $oc.Version $latest)){
        Write-Host "Atualizando opencode para $latest..." -ForegroundColor Cyan
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        npm install -g opencode-ai@latest 2>&1 | Out-Null
        $npmOk = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEap
        $v2 = (Test-OpencodeInstalled).Version
        if($npmOk -and $v2 -and -not (Test-VersionOutdated -Installed $v2 -Latest $latest)){
          Write-Host "Opencode atualizado para $v2." -ForegroundColor Green
          $atualizado++
        } else {
          Write-Host "Opencode nao confirmou a atualizacao; tente: opencode upgrade" -ForegroundColor Yellow
        }
      } else {
        Write-Host "Ok, opencode fica em $($oc.Version)." -ForegroundColor DarkGray
      }
    } else {
      Write-Host "Opencode atualizado ($($oc.Version))." -ForegroundColor DarkGray
    }
  }

  # 9Router via npm global (9router-src nao mexe: e instalacao de desenvolvedor)
  $nine = Test-NineRouterInstalled
  if($nine.Ok -and $nine.ViaNpm){
    $ver = Get-NineRouterVersion
    $latest = (& npm view 9router version 2>$null | Select-Object -Last 1)
    if($latest){ $latest = $latest.Trim() }
    if($latest -and $ver -and (Test-VersionOutdated -Installed $ver -Latest $latest)){
      $nenhum = $false
      Write-Host "9Router desatualizado ($ver -> $latest)." -ForegroundColor Yellow
      if($Auto -or (Confirm-Update '9Router' $ver $latest)){
        Write-Host "Atualizando 9Router para $latest..." -ForegroundColor Cyan
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        npm install -g 9router@latest 2>&1 | Out-Null
        $npmOk = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEap
        $v2 = Get-NineRouterVersion
        if($npmOk -and $v2 -and -not (Test-VersionOutdated -Installed $v2 -Latest $latest)){
          Write-Host "9Router atualizado para $v2." -ForegroundColor Green
          $atualizado++
        } else {
          Write-Host "9Router nao confirmou a atualizacao." -ForegroundColor Yellow
        }
      } else {
        Write-Host "Ok, 9Router fica em $ver." -ForegroundColor DarkGray
      }
    } else {
      Write-Host "9Router atualizado ($ver)." -ForegroundColor DarkGray
    }
  }

  # AionUi (instalador oficial substitui a instalacao existente)
  $aui = Test-AionUiInstalled
  if($aui.Ok){
    $latest = Get-GitHubLatestTag -Repo 'iOfficeAI/AionUi'
    if($latest -and $aui.Version -and (Test-VersionOutdated -Installed $aui.Version -Latest $latest)){
      $nenhum = $false
      Write-Host "AionUi desatualizado ($($aui.Version) -> $latest)." -ForegroundColor Yellow
      if($Auto -or (Confirm-Update 'AionUi' $aui.Version $latest)){
        $url = "https://static.aionui.com/releases/$latest/AionUi-$latest-win-x64.exe"
        Install-FromOfficialUrl -DisplayName "AionUi ($latest)" -Url $url -LocalName "AionUi-$latest-win-x64.exe"
        Start-Sleep -Seconds 3
        $v2 = (Test-AionUiInstalled).Version
        if($v2 -and -not (Test-VersionOutdated -Installed $v2 -Latest $latest)){
          Write-Host "AionUi atualizado para $v2." -ForegroundColor Green
          $atualizado++
        } else {
          Write-Host "AionUi nao confirmou a atualizacao (ele pode atualizar pelo menu do app)." -ForegroundColor Yellow
        }
      } else {
        Write-Host "Ok, AionUi fica em $($aui.Version)." -ForegroundColor DarkGray
      }
    } else {
      Write-Host "AionUi atualizado ($($aui.Version))." -ForegroundColor DarkGray
    }
  }

  if($nenhum){
    Write-Host "Tudo na versao mais recente. Nada a atualizar." -ForegroundColor Green
  } elseif($atualizado -gt 0){
    Write-Host "Atualizado(s) no lugar (sem criar versao nova): $atualizado." -ForegroundColor Green
  }
}

# --- verifica se o AionUi esta instalado e sua versao ---
function Test-AionUiInstalled {
  $exe = "$env:LOCALAPPDATA\Programs\AionUi\AionUi.exe"
  if(-not (Test-Path $exe)){
    # procura em outros locais comuns
    $alt = Get-ChildItem "$env:LOCALAPPDATA\Programs\AionUi\AionUi.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if($alt){ $exe = $alt.FullName } else { return @{ Ok=$false; Exe=''; Version='' } }
  }
  $ver = ''
  try { $ver = (Get-Item $exe).VersionInfo.FileVersion } catch {}
  return @{ Ok=$true; Exe=$exe; Version=$ver }
}

# --- garante o AionUi instalado ---
# Descobre a versao mais recente oficial (GitHub tag) e monta o link estavel
# de download (static.aionui.com/releases/<ver>/AionUi-<ver>-win-x64.exe).
function Ensure-AionUi {
  $aui = Test-AionUiInstalled
  if($aui.Ok){ return $true }
  $tag = Get-GitHubLatestTag -Repo 'iOfficeAI/AionUi'
  if($tag){
    $url = "https://static.aionui.com/releases/$tag/AionUi-$tag-win-x64.exe"
    # O AionUi nao publica checksum oficial dos binarios (nem no GitHub nem
    # no static.aionui.com). Fica a mitigacao de HTTPS + dominio oficial.
    Install-FromOfficialUrl -DisplayName "AionUi ($tag)" -Url $url -LocalName "AionUi-$tag-win-x64.exe"
    Start-Sleep -Seconds 3
    if((Test-AionUiInstalled).Ok){
      Write-Host "AionUi instalado." -ForegroundColor Green
      return $true
    }
    Write-Host "AionUi instalado, mas o app ainda nao foi localizado nesta sessao." -ForegroundColor Yellow
    Write-Host "Ele aparece no menu Iniciar mesmo assim." -ForegroundColor Yellow
    return $true
  }
  Write-Host "Nao consegui descobrir a versao mais recente do AionUi." -ForegroundColor Yellow
  Write-Host "Instale do site oficial: https://aionui.com" -ForegroundColor Yellow
  return $false
}

# --- garante as CLI globais do opencode e do 9Router via npm ---
# Node.js ja veio antes. Usa npm install -g (pacote oficial no registry).
function Ensure-NpmDeps {
  param([bool]$SkipOpencode = $false)
  if(-not $SkipOpencode){
    $oc = Test-OpencodeInstalled
    if($oc.Ok){
      Write-Host "OpenCode CLI OK (versao $($oc.Version))."
    } else {
      Write-Host "OpenCode CLI nao encontrado. Instalando via npm global..."
      $prevEap = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      npm install -g opencode-ai 2>&1 | Out-Null
      $npmOk = ($LASTEXITCODE -eq 0)
      $ErrorActionPreference = $prevEap
      if($npmOk -and (Test-OpencodeInstalled).Ok){
        Write-Host "OpenCode CLI instalado via npm." -ForegroundColor Green
      } else {
        Write-Host "Nao consegui instalar o opencode-ai via npm." -ForegroundColor Yellow
        Write-Host "Tente depois: npm install -g opencode-ai" -ForegroundColor Yellow
      }
    }
  } else {
    Write-Host "OpenCode CLI pulado por opcao (wizard MSI)." -ForegroundColor DarkGray
  }

  $nine = Test-NineRouterInstalled
  if($nine.Ok){
    Write-Host "9Router OK ($(if($nine.ViaNpm){'npm global'}else{'9router-src'}))."
  } else {
    Write-Host "9Router nao encontrado. Instalando via npm global..."
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    npm install -g 9router 2>&1 | Out-Null
    $npmOk = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prevEap
    if($npmOk -and (Test-NineRouterInstalled).Ok){
      Write-Host "9Router instalado via npm." -ForegroundColor Green
    } else {
      Write-Host "Nao consegui instalar o 9router via npm." -ForegroundColor Yellow
      Write-Host "Tente depois: npm install -g 9router" -ForegroundColor Yellow
    }
  }
}

# --- local do config global do opencode do USUARIO (mesmo lugar em .ps1 e .exe) ---
function Get-OpencodeGlobalPath {
  $xdg = $env:XDG_CONFIG_HOME
  $dir = if($xdg){ Join-Path $xdg "opencode" } else { Join-Path $env:USERPROFILE ".config\opencode" }
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  return (Join-Path $dir "opencode.json")
}

# --- aplica o provider KFAI (router local) no opencode.json global do usuario ---
# Sempre roda: o opencode usa o MESMO arquivo tanto na instalacao .ps1 quanto no
# .exe, e e um arquivo de texto (JSON) que o instalador pode editar com seguranca.
function Apply-OpencodeCombos {
  $path = Get-OpencodeGlobalPath
  Write-Host "Config global do opencode: $path"

  # backup do arquivo atual (se existir) antes de tocar
  if(Test-Path -LiteralPath $path){
    $bakDir = Join-Path (Split-Path -Parent $path) "backup"
    New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
    $bak = Join-Path $bakDir ("opencode.json.bak-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
    Copy-Item -LiteralPath $path -Destination $bak -Force
    Write-Host "Backup da config atual em: $bak" -ForegroundColor DarkGray
  }

  $cfg = $null
  if(Test-Path -LiteralPath $path){
    try { $cfg = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { $cfg = $null }
  }
  if($null -eq $cfg){ $cfg = [pscustomobject]@{ provider = @{} } }
  if($null -eq $cfg.provider){ $cfg | Add-Member -NotePropertyName provider -NotePropertyValue @{} }

  # provider KFAI Router (combos) - preserva o que o usuario ja tiver em "kfai"
  $kfai = [pscustomobject]@{
    npm   = "@ai-sdk/openai-compatible"
    name  = "KFAI Router"
    options = @{
      baseURL = "http://localhost:20129/v1"
      apiKey  = "kfai"
    }
    models = @{
      "full-cloud" = @{ name = "KFAI - Full Cloud (nuvem gratuita)"; limit = @{ context = 200000; output = 65536 } }
      "full-local" = @{ name = "KFAI - Full Local (somente Ollama)"; limit = @{ context = 200000; output = 65536 } }
      "cloud-plus-local" = @{ name = "KFAI - Cloud + Local (nuvem 1a, local fallback)"; limit = @{ context = 200000; output = 65536 } }
    }
  }
  $cfg.provider | Add-Member -NotePropertyName kfai -NotePropertyValue $kfai -Force

  # 9Router e o servidor PRINCIPAL: o combo padrao passa a ser cloud-plus-local
  # (nuvem primeiro via 9Router; so cai para o Ollama local se o 9Router falhar).
  # Se o usuario ja escolheu outro modelo, respeita a escolha dele.
  $serverSideChoice = @{ "9router/ps/poolside/laguna-s-2.1" = "kfai/cloud-plus-local" }
  if($null -eq $cfg.model -or $serverSideChoice.ContainsKey([string]$cfg.model)){
    $cfg | Add-Member -NotePropertyName model -NotePropertyValue "kfai/cloud-plus-local" -Force
    $cfg.model = "kfai/cloud-plus-local"
  }

  $cfg | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
  Write-Host "Combos do KFAI adicionados ao opencode (provider kfai: full-cloud, cloud-plus-local, full-local)." -ForegroundColor Green
}

# --- aplica os combos no AionUi, quando der (so funciona DENTRO do AionUi) ---
# Se este instalador rodar de dentro do AionUi (aioncore disponivel), aplica na
# hora. Caso contrario, avisa como fazer (script 04-kfai-aionui-combos.ps1).
function Apply-AionUiCombos {
  if($env:AIONUI_HELPER_BIN -and (Test-Path -LiteralPath $env:AIONUI_HELPER_BIN)){
    Write-Host "AionUi detectado no ambiente. Aplicando combos e removendo perfis pagos..." -ForegroundColor Cyan
    $aux = Join-Path $Root "04-kfai-aionui-combos.ps1"
    if(Test-Path -LiteralPath $aux){
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $aux
      return
    }
  }
  Write-Host "AionUi nao aplica combos agora (so funciona dentro do app)." -ForegroundColor Yellow
  Write-Host "Para aplicar no AionUi, abra o app e rode: .\04-kfai-aionui-combos.ps1" -ForegroundColor Yellow
}

# --- relatorio de apps e dependencias (instalado? versao? atualizado?) ---
function Show-AppsReport {
  Write-Step "Verificacao de apps e dependencias"
  $nodeOk = Test-NodeJs
  $nodeVer = ''
  if($nodeOk){ $nodeVer = (& node --version 2>$null).Trim() }
  Write-Host "Node.js : $(if($nodeOk){ "OK ($nodeVer)" } else { 'FALTANDO' })"

  $ollama = Test-OllamaInstalled
  Write-Host "Ollama  : $(if($ollama.Cmd){ "OK ($($ollama.Cmd))" } else { 'FALTANDO' })"
  Write-Host "          servidor: $(if($ollama.ServerUp){ 'rodando (11434)' } else { 'parado' })"

  $nine = Test-NineRouterInstalled
  if($nine.Ok){
    $how = if($nine.ViaNpm){ 'npm global' } elseif($nine.ViaSrc){ '9router-src' }
    Write-Host "9Router : OK ($how)"
    Write-Host "          rodando: $(if($nine.PortUp){ 'sim (20128)' } else { 'nao' })"
  } else {
    Write-Host "9Router : FALTANDO"
  }

  $oc = Test-OpencodeInstalled
  if($oc.Ok){
    $ocLatest = Get-OpencodeLatestVersion
    $ocOutdated = Test-VersionOutdated -Installed $oc.Version -Latest $ocLatest
    $status = if($ocOutdated){ "DESATUALIZADO (tem $($oc.Version), novo e $ocLatest)" } else { "atualizado ($($oc.Version))" }
    Write-Host "Opencode: OK - $status"
    $script:OcOutdated = $ocOutdated
  } else {
    Write-Host "Opencode: FALTANDO"
    $script:OcOutdated = $false
  }

  $aui = Test-AionUiInstalled
  if($aui.Ok){
    Write-Host "AionUi  : OK (versao $($aui.Version))"
    Write-Host "          atualizacao: pelo proprio app (menu de ajuda/sobre)"
  } else {
    Write-Host "AionUi  : FALTANDO (instalador em https://aionui.com ou loja)"
  }
  Write-Host ""
}

Write-Host ""
if($useLocal){
  Write-Step "IA local - passo 1: Ollama"
  if(-not (Ensure-Ollama)){
    Write-Host "Impossivel continuar sem o Ollama. Rode este script de novo apos instalar." -ForegroundColor Red
    exit 1
  }

  Write-Step "IA local - passo 2: modelo $model"
  if(Test-OllamaModel -Name $model){
    Write-Host "Modelo $model JA esta baixado. Nada a fazer." -ForegroundColor Green
  } else {
    Write-Host "Modelo $model nao encontrado. Baixando via ollama pull (pode levar alguns minutos)..."
    ollama pull $model
    if(Test-OllamaModel -Name $model){
      Write-Host "Modelo local pronto: $model" -ForegroundColor Green
    } else {
      Write-Host "AVISO: nao consegui confirmar o download do modelo. Rode 'ollama pull $model' depois." -ForegroundColor Yellow
    }
  }

  # contexto 64k para o agente local (o default 4096 quebra tool calling)
  if(Test-OllamaModel -Name $model){
    $script:NumCtxModel = Ensure-NumCtxModel -BaseModel $model
  } else {
    $script:NumCtxModel = $model
  }
} else {
  if($model -eq $null){
    Write-Step "Seu PC nao roda modelo local (pouca memoria). Kit usara Full Cloud."
  } else {
    Write-Step "IA local pulada por opcao. Baixe depois com: ollama pull $model"
  }
}

Write-Step "Passo: dependencias npm (CLI do opencode + 9Router)"
Ensure-NpmDeps -SkipOpencode:$SkipOpencode

if(-not $SkipOpencode){
  Write-Step "Passo: OpenCode Desktop (app grafico)"
  Ensure-OpencodeDesktop
} else {
  Write-Host "OpenCode Desktop pulado por opcao (wizard MSI)." -ForegroundColor DarkGray
}

if(-not $SkipAionUi){
  Write-Step "Passo: AionUi (interface)"
  Ensure-AionUi
} else {
  Write-Host "AionUi pulado por opcao (wizard MSI)." -ForegroundColor DarkGray
}

Show-AppsReport

# atualiza (no lugar) qualquer programa que tenha versao nova; com -Atualizar
# faz sozinho, sem perguntar. Nunca cria segunda copia do mesmo programa.
Write-Step "Atualizacoes (sobe de versao no lugar, sem duplicar)"
Update-KfaiTools -Auto:$Atualizar

Write-Step "Combos de IA - opencode + AionUi"
Write-Host "Vou adicionar os combos do KFAI (provider kfai) no opencode e, se possivel, no AionUi."

# modo limpo: remove a config/combos ANTIGOS do KFAI antes de aplicar de novo.
# Isso resolve config bugada sem apagar chaves (9Router) nem modelos (Ollama).
if($Limpo){
  Write-Step "Limpeza (modo limpo) - removendo config antiga do KFAI"
  $cleanPath = Get-OpencodeGlobalPath
  if(Test-Path -LiteralPath $cleanPath){
    try {
      $cfg = Get-Content -LiteralPath $cleanPath -Raw | ConvertFrom-Json
      if($cfg.provider -and $cfg.provider.kfai){
        $cfg.provider.PSObject.Properties.Remove('kfai') | Out-Null
        Write-Host "Provider 'kfai' antigo removido do opencode." -ForegroundColor DarkGray
      }
      if([string]$cfg.model -like 'kfai/*'){
        $cfg.PSObject.Properties.Remove('model') | Out-Null
        Write-Host "Modelo padrao 'kfai/...' antigo removido (sera escolhido de novo)." -ForegroundColor DarkGray
      }
      $cfg | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $cleanPath -Encoding utf8
    } catch {
      Write-Host "Nao consegui limpar a config do opencode; vou sobrescrever o provider kfai de novo." -ForegroundColor Yellow
    }
  }
  $cleanBak = Join-Path (Split-Path -Parent $cleanPath) "backup"
  Get-ChildItem -LiteralPath $cleanBak -Filter "opencode.json.bak-*" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  Write-Host "Backups antigos de config apagados." -ForegroundColor DarkGray
  Remove-Item -LiteralPath (Join-Path $env:TEMP "Modelfile-kfai") -Force -ErrorAction SilentlyContinue
  Write-Host "Config antiga do KFAI removida. Aplicando do zero..." -ForegroundColor Green
}
if(-not $SkipOpencode){
  Apply-OpencodeCombos
} else {
  Write-Host "Combos do opencode pulados por opcao (wizard MSI)." -ForegroundColor DarkGray
}
if(-not $SkipAionUi){
  Apply-AionUiCombos
}

# Autostart (9Router + Ollama) no login do Windows — somente quando a
# instalacao veio do wizard MSI com a opcao marcada (padrao: marcada).
if($MsiOptions -and -not $SkipAutostart){
  Write-Step "Autostart no login do Windows (9Router + Ollama)"
  $start = Join-Path $Root "05-kfai-start.ps1"
  if(Test-Path -LiteralPath $start){
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $start -Register
  } else {
    Write-Host "05-kfai-start.ps1 nao encontrado; autostart nao configurado." -ForegroundColor Yellow
  }
}

Write-Step "Chaves de IA gratuitas (9Router)"
$cfgChaves = Join-Path $Root "02-kfai-config-chaves.ps1"
if(Test-Path -LiteralPath $cfgChaves){
  # passo 1: checa o estado sem abrir nada nem perguntar
  # exit 0 = tudo OK | 1 = nao leu o 9Router | 2 = faltam chaves
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cfgChaves -Test
  $exitKey = $LASTEXITCODE
  if($exitKey -eq 1){
    Write-Host "Nao deu para ler o 9Router agora. Depois rode: .\02-kfai-config-chaves.ps1" -ForegroundColor Yellow
  } elseif($exitKey -eq 2){
    Write-Host ""
    $resp = ''
    try { $resp = Read-Host "Quer que eu te guie na configuracao das chaves que faltam? (s/N)" } catch { $resp = '' }
    if($resp -match '^(s|sim|y|yes)$'){
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cfgChaves
    } else {
      Write-Host "Ok. Guia completo em: $(Join-Path $Root 'docs\GUIA-CHAVES-GRATIS.md')" -ForegroundColor DarkGray
      Write-Host "Ou rode depois: .\02-kfai-config-chaves.ps1" -ForegroundColor DarkGray
    }
  } else {
    Write-Host "Todas as chaves ja configuradas no 9Router." -ForegroundColor Green
  }
} else {
  Write-Host "Assistente de chaves nao encontrado (02-kfai-config-chaves.ps1)." -ForegroundColor Yellow
}

Write-Step "Guia de proximos passos"
$guiaChaves = Join-Path $Root "docs\GUIA-CHAVES-GRATIS.md"
Write-Host @"
1. Abra o 9Router e ative as conexoes gratuitas de sua escolha.
2. Adicione suas chaves gratuitas: rode .\02-kfai-config-chaves.ps1
   (ele abre os sites das chaves que faltam; guia completo em:
    $guiaChaves)
3. Escolha o combo ja instalado no opencode (mudar o modelo):
   - kfai/full-cloud      -> so IAs gratuitas da nuvem
   - kfai/cloud-plus-local-> nuvem primeiro, seu PC de reserva
   - kfai/full-local      -> somente seu PC (Ollama)
   Tambem pode trocar o arquivo inteiro usando os presets em config\opencode\.
$(if($script:NumCtxModel){ "   Modelo local recomendado (contexto 64k): $($script:NumCtxModel)`n" })
   Pronto! Use as skills da pasta skills\ para otimizar seu PC.
"@ -ForegroundColor Cyan
Show-IntegrityHash
Write-Host "`nKFAI instalado. Curto e simples." -ForegroundColor Green