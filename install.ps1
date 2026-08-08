<#
  KFAI - Kit de Ferramentas de Agente de IA
  Instalador (pt-BR, guiado)
  Nao instala Ollama em PC fraco demais. Detecta hardware e escolhe modelo certo.
  Nao toca em chaves de ninguem - tudo nasce com SUA_CHAVE_AQUI.
#>
[CmdletBinding()]
param(
  [switch]$SkipOllama
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

$CanonicalRepoUrl = 'https://github.com/johnsalviano/kfai'

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
  # 7B Q4 cabe em ~4.7GB de VRAM; 6GB deixa folga confortavel
  if($hw.Vram -ge 6){ return 'qwen2.5:7b' }
  if($hw.Ram -lt 8){ return 'qwen2.5:1.5b' }
  if($hw.Ram -lt 16){ return 'qwen2.5:3b' }
  if($hw.Vram -ge 4){ return 'qwen2.5:7b' }
  if($hw.Ram -ge 32){ return 'qwen2.5:14b' }
  return 'qwen2.5:7b'
}

function Test-IsAdmin {
  $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

  Write-Host "Baixando Node.js $Version (arquivo oficial, ~30 MB)..."
  try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
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
    # Sem admin: pode ser PC de empresa que bloqueia instalacao de programas.
    Write-Host "Voce NAO tem permissao de administrador nesta maquina (comum em PCs gerenciados por empresa)." -ForegroundColor Yellow
    Write-Host "Instalacao normal seria barrada. Instalando Node.js na PASTA DO USUARIO local," -ForegroundColor Yellow
    Write-Host "que NAO precisa de administrador e fica fora do controle do sistema da empresa." -ForegroundColor Yellow
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

if(-not (Test-OfficialOrigin)){ exit 1 }

if(-not (Ensure-NodeJs)){ Write-Host "Impossivel continuar sem Node.js. Abra um terminal novo apos instalar e tente de novo." -ForegroundColor Red; exit 1 }

Write-Step "KFAI - Kit de Ferramentas de Agente de IA"
$hw = Get-HardwareInfo
Write-Host "RAM: $($hw.Ram) GB | CPU: $($hw.Cpu) | GPU VRAM: $($hw.Vram) GB ($($hw.Gpu)) [fonte: $($hw.VramSource)]"

$model = ChooseLocalModel $hw
$useLocal = ($model -ne $null -and -not $SkipOllama)

# --- verifica se o Ollama esta instalado (antes de tentar usar) ---
function Test-OllamaInstalled {
  $cmd = (Get-Command ollama -ErrorAction SilentlyContinue).Source
  $serverUp = $false
  try { (New-Object Net.Sockets.TcpClient).Connect("127.0.0.1", 11434); $serverUp = $true } catch {}
  return @{ Cmd = $cmd; ServerUp = $serverUp }
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

# --- cria o modelo derivado -32k (num_ctx 32768 baked) para agentes locais ---
# O Ollama usa contexto 4096 por padrao e trunca silenciosamente, quebrando
# tool calling. Modelos com "tools" precisam de contexto grande.
function Ensure-NumCtxModel {
  param([string]$BaseModel)
  if(-not $BaseModel){ return "" }
  $base = ($BaseModel -replace ':.*$', '')
  $derived = "$base-32k"
  if(Test-OllamaModel -Name $derived){
    Write-Host "Modelo $derived ja existe (contexto 32k)." -ForegroundColor DarkGray
    return $derived
  }
  Write-Host "Criando $derived (contexto 32k para agentes)..." -ForegroundColor Cyan
  $mf = Join-Path $env:TEMP "Modelfile-kfai"
  try {
    Set-Content -Path $mf -Value "FROM $BaseModel`nPARAMETER num_ctx 32768" -Encoding utf8
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
  try { (New-Object Net.Sockets.TcpClient).Connect("127.0.0.1", 20128); $portUp = $true } catch {}
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
      apiKey  = "{env:KFAI_ROUTER_KEY}"
    }
    models = @{
      "full-cloud" = @{ name = "KFAI - Full Cloud (nuvem gratuita)"; limit = @{ context = 200000; output = 65536 } }
      "full-local" = @{ name = "KFAI - Full Local (somente Ollama)"; limit = @{ context = 200000; output = 65536 } }
      "cloud-plus-local" = @{ name = "KFAI - Cloud + Local (nuvem 1a, local fallback)"; limit = @{ context = 200000; output = 65536 } }
    }
  }
  $cfg.provider | Add-Member -NotePropertyName kfai -NotePropertyValue $kfai -Force

  $cfg | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
  Write-Host "Combos do KFAI adicionados ao opencode (provider kfai: full-cloud, cloud-plus-local, full-local)." -ForegroundColor Green
}

# --- aplica os combos no AionUi, quando der (so funciona DENTRO do AionUi) ---
# Se este instalador rodar de dentro do AionUi (aioncore disponivel), aplica na
# hora. Caso contrario, avisa como fazer (script kfai-aionui-combos.ps1).
function Apply-AionUiCombos {
  if($env:AIONUI_HELPER_BIN -and (Test-Path -LiteralPath $env:AIONUI_HELPER_BIN)){
    Write-Host "AionUi detectado no ambiente. Aplicando combos e removendo perfis pagos..." -ForegroundColor Cyan
    $aux = Join-Path $Root "kfai-aionui-combos.ps1"
    if(Test-Path -LiteralPath $aux){
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $aux
      return
    }
  }
  Write-Host "AionUi nao aplica combos agora (so funciona dentro do app)." -ForegroundColor Yellow
  Write-Host "Para aplicar no AionUi, abra o app e rode: .\kfai-aionui-combos.ps1" -ForegroundColor Yellow
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
  $ollama = Test-OllamaInstalled
  if(-not $ollama.Cmd){
    Write-Host "Ollama NAO instalado. Abrindo guia de instalacao..." -ForegroundColor Yellow
    Start-Process "https://ollama.com/download/windows"
    Write-Host "Instale o Ollama, rode este script de novo." -ForegroundColor Yellow
    exit 1
  }
  Write-Host "Ollama instalado: $($ollama.Cmd)"

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

  # contexto 32k para o agente local (o default 4096 quebra tool calling)
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

Write-Step "Passo: 9Router (roteador de IA em nuvem)"
$nine = Test-NineRouterInstalled
if($nine.Ok){
  $how = if($nine.ViaNpm){ "CLI npm global" } elseif($nine.ViaSrc){ "9router-src (build local)" }
  Write-Host "9Router JA instalado ($how)."
  if($nine.PortUp){
    Write-Host "E ja esta rodando na porta 20128." -ForegroundColor Green
  } else {
    Write-Host "Instalado mas nao esta rodando. Inicie com kfai-start.ps1 -With9Router." -ForegroundColor Yellow
  }
} else {
  Write-Host "9Router NAO instalado. Instalando via npm (pacote oficial)..." -ForegroundColor Yellow
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  npm install -g 9router 2>&1 | Out-Null
  $npmOk = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $prevEap
  if($npmOk -and (Test-NineRouterInstalled).Ok){
    Write-Host "9Router instalado com sucesso (CLI npm global)." -ForegroundColor Green
  } else {
    Write-Host "Nao consegui instalar o 9Router automaticamente." -ForegroundColor Red
    Write-Host "Instale manualmente: npm install -g 9router" -ForegroundColor Yellow
  }
}

Show-AppsReport

# se o opencode estiver desatualizado, oferece atualizar na hora
if($script:OcOutdated){
  $ocVer = (Test-OpencodeInstalled).Version
  $ocLatest = Get-OpencodeLatestVersion
  Write-Host "Opencode desatualizado ($ocVer -> $ocLatest)." -ForegroundColor Yellow
  $resp = ''
  try { $resp = Read-Host "Atualizar agora com 'opencode upgrade'? (s/N)" } catch { $resp = '' }
  if($resp -match '^(s|sim|y|yes)$'){
    opencode upgrade 2>&1 | Out-Null
    if(Test-VersionOutdated -Installed (Test-OpencodeInstalled).Version -Latest $ocLatest){
      Write-Host "Opencode nao atualizou (talvez a instalacao via npm nao siga o binario)." -ForegroundColor Yellow
      Write-Host "Tente: npm install -g opencode-ai@latest" -ForegroundColor Yellow
    } else {
      Write-Host "Opencode atualizado para $((Test-OpencodeInstalled).Version)." -ForegroundColor Green
    }
  } else {
    Write-Host "Ok, fica para depois. Rode 'opencode upgrade' quando quiser." -ForegroundColor DarkGray
  }
}

Write-Step "Combos de IA - opencode + AionUi"
Write-Host "Vou adicionar os combos do KFAI (provider kfai) no opencode e, se possivel, no AionUi."
Apply-OpencodeCombos
Apply-AionUiCombos

Write-Step "Chaves de IA gratuitas (9Router)"
$cfgChaves = Join-Path $Root "kfai-config-chaves.ps1"
if(Test-Path -LiteralPath $cfgChaves){
  # passo 1: checa o estado sem abrir nada nem perguntar
  # exit 0 = tudo OK | 1 = nao leu o 9Router | 2 = faltam chaves
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cfgChaves -Test
  $exitKey = $LASTEXITCODE
  if($exitKey -eq 1){
    Write-Host "Nao deu para ler o 9Router agora. Depois rode: .\kfai-config-chaves.ps1" -ForegroundColor Yellow
  } elseif($exitKey -eq 2){
    Write-Host ""
    $resp = ''
    try { $resp = Read-Host "Quer que eu te guie na configuracao das chaves que faltam? (s/N)" } catch { $resp = '' }
    if($resp -match '^(s|sim|y|yes)$'){
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cfgChaves
    } else {
      Write-Host "Ok. Links das chaves em docs/GUIA-CHAVES-GRATIS.md" -ForegroundColor DarkGray
      Write-Host "Ou rode depois: .\kfai-config-chaves.ps1" -ForegroundColor DarkGray
    }
  } else {
    Write-Host "Todas as chaves ja configuradas no 9Router." -ForegroundColor Green
  }
} else {
  Write-Host "Assistente de chaves nao encontrado (kfai-config-chaves.ps1)." -ForegroundColor Yellow
}

Write-Step "Guia de proximos passos"
Write-Host @"
1. Abra o 9Router e ative as conexoes gratuitas de sua escolha.
2. Adicione suas chaves gratuitas: rode .\kfai-config-chaves.ps1
   (ele abre os sites das chaves que faltam; links em docs/GUIA-CHAVES-GRATIS.md).
3. Escolha o combo ja instalado no opencode (mudar o modelo):
   - kfai/full-cloud      -> so IAs gratuitas da nuvem
   - kfai/cloud-plus-local-> nuvem primeiro, seu PC de reserva
   - kfai/full-local      -> somente seu PC (Ollama)
   Tambem pode trocar o arquivo inteiro usando os presets em config\opencode\.
$(if($script:NumCtxModel){ "   Modelo local recomendado (contexto 32k): $($script:NumCtxModel)`n" })
   Pronto! Use as skills da pasta skills\ para otimizar seu PC.
"@ -ForegroundColor Cyan
Show-IntegrityHash
Write-Host "`nKFAI instalado. Curto e simples." -ForegroundColor Green