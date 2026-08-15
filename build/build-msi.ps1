<#
  KFAI - Build do instalador MSI (wizard grafico)
  Monta o pacote (payload) com os arquivos do kit, gera o Payload.wxs
  (componentes de arquivo), chama o WiX 4 e produz KFAI-Instalador.msi.

  Requisitos (uma vez so):
    dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
    dotnet tool install --global wix --version 4.0.6
    wix extension add WixToolset.UI.wixext/4.0.6

  Uso:
    .\build\build-msi.ps1            gera build\msi\staging\ + KFAI-Instalador.msi
    .\build\build-msi.ps1 -SkipStaging   usa o staging que ja existe (mais rapido)
#>
[CmdletBinding()]
param(
  [switch]$SkipStaging
)

$Root   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MsiDir = Join-Path $Root "build\msi"
$Stage  = Join-Path $MsiDir "staging"
$Out    = Join-Path $Root "KFAI-Instalador.msi"

$Version = (Get-Content -LiteralPath (Join-Path $Root "VERSION") -Raw).Trim()
if($Version -match '^(\d+)\.(\d+)\.(\d+)(-.*)?$'){
  $Version = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
} else {
  Write-Error "VERSION invalido: $Version"
  exit 1
}

# ============ 1) monta o payload (copias limpas, sem segredos/artefatos) ============
if(-not $SkipStaging){
  Write-Host "Montando payload em $Stage ..." -ForegroundColor Cyan
  if(Test-Path -LiteralPath $Stage){ Remove-Item -LiteralPath $Stage -Recurse -Force }
  New-Item -ItemType Directory -Path $Stage -Force | Out-Null

  # Arquivos da raiz que entram no pacote (nunca router.conf: tem chaves reais).
  $Raiz = @(
    "01-install.ps1","02-kfai-config-chaves.ps1","03-kfai-config-chaves-gui.ps1",
    "03-kfai-config-provider-nodes.ps1","04-kfai-aionui-combos.ps1","05-kfai-start.ps1","06-kfai-launch.ps1",
    "07-KFAI-Abrir-Opencode.vbs","08-KFAI-Abrir-AionUi.vbs","09-kfai-desinstalar.ps1",
    "router.py","router.conf.example","VERSION","LICENSE","AGENTS.md",
    "CONTRIBUTING.md","INSTRUCOES.md","README.md","README.en.md","SECURITY.md","llms.txt"
  )
  foreach($f in $Raiz){
    $src = Join-Path $Root $f
    if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $Stage -Force }
  }

  # pastas inteiras
  foreach($dir in @("scripts","config","skills","docs")){
    $src = Join-Path $Root $dir
    if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $Stage -Recurse -Force }
  }

  # lixo que nao pode entrar
  Get-ChildItem -LiteralPath $Stage -Recurse -Force |
    Where-Object { $_.Name -match '^(router\.conf|data\.sqlite.*|.*\.log)$' } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

# ============ 2) gera o Payload.wxs (arvore de pastas + componentes) ============
function ConvertTo-WixId([string]$RelPath){
  $id = ($RelPath -replace '[^A-Za-z0-9]', '_')
  if($id -match '^[0-9]'){ $id = "x$id" }
  return $id
}

$sb = New-Object System.Text.StringBuilder
$compIds = New-Object System.Collections.Generic.List[string]
[void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
[void]$sb.AppendLine('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">')
[void]$sb.AppendLine('  <Fragment>')
[void]$sb.AppendLine('    <DirectoryRef Id="INSTALLFOLDER">')

# constroi a arvore de diretorios recursivamente e emite componentes de arquivo
function Add-DirToWix {
  param(
    [string]$FsDir,      # pasta no disco (staging\...)
    [string]$RelPath,    # caminho relativo ("" para a raiz)
    [string]$DirId       # Id do Directory atual ("INSTALLFOLDER" para a raiz)
  )
  foreach($child in (Get-ChildItem -LiteralPath $FsDir -Force | Sort-Object Name)){
    if($child.PSIsContainer){
      $rel = if($RelPath){ "$RelPath\$($child.Name)" } else { $child.Name }
      $cid = "D_$(ConvertTo-WixId $rel)"
      [void]$sb.AppendLine('      ' * (Get-Indent $rel) + "<Directory Id=`"$cid`" Name=`"$($child.Name)`">")
      Add-DirToWix -FsDir $child.FullName -RelPath $rel -DirId $cid
      [void]$sb.AppendLine('      ' * (Get-Indent $rel) + "</Directory>")
    } else {
      $rel = if($RelPath){ "$RelPath\$($child.Name)" } else { $child.Name }
      $fileId = "F_$(ConvertTo-WixId $rel)"
      $compId = "C_$(ConvertTo-WixId $rel)"
      $compIds.Add($compId)
      [void]$sb.AppendLine('      ' * (Get-Indent $RelPath) + "<Component Id=`"$compId`" Directory=`"$DirId`" Guid=`"*`">")
      [void]$sb.AppendLine('      ' * (Get-Indent $RelPath) + "  <File Id=`"$fileId`" Source=`"$($child.FullName)`" KeyPath=`"yes`" />")
      [void]$sb.AppendLine('      ' * (Get-Indent $RelPath) + "</Component>")
    }
  }
}

function Get-Indent([string]$RelPath){
  $depth = 0
  if($RelPath){ $depth = ($RelPath -split '\\').Count }
  return [math]::Max(1, $depth + 2)
}

Add-DirToWix -FsDir $Stage -RelPath "" -DirId "INSTALLFOLDER"

[void]$sb.AppendLine('    </DirectoryRef>')
[void]$sb.AppendLine('    <ComponentGroup Id="KfaiPayloadFiles">')
foreach($cid in $compIds){
  [void]$sb.AppendLine("      <ComponentRef Id=`"$cid`" />")
}
[void]$sb.AppendLine('    </ComponentGroup>')
[void]$sb.AppendLine('  </Fragment>')

# ============ 3) atalhos do Menu Iniciar (componentes proprios) ============
[void]$sb.AppendLine('  <Fragment>')
[void]$sb.AppendLine('    <DirectoryRef Id="KF_StartMenu">')
[void]$sb.AppendLine('      <Component Id="C_ScOpenCode" Guid="*" Condition="KF_INSTALL_SHORTCUTS = &quot;1&quot;">')
[void]$sb.AppendLine('        <Shortcut Id="ScOpenCode" Name="KFAI - Abrir OpenCode" Target="[INSTALLFOLDER]07-KFAI-Abrir-Opencode.vbs" WorkingDirectory="INSTALLFOLDER" />')
[void]$sb.AppendLine('        <RemoveFolder Id="RmKF_StartMenu" Directory="KF_StartMenu" On="uninstall" />')
[void]$sb.AppendLine('        <RegistryValue Root="HKCU" Key="Software\KFAI\Shortcuts" Name="Opencode" Type="integer" Value="1" KeyPath="yes" />')
[void]$sb.AppendLine('      </Component>')
[void]$sb.AppendLine('      <Component Id="C_ScAionUi" Guid="*" Condition="KF_INSTALL_SHORTCUTS = &quot;1&quot;">')
[void]$sb.AppendLine('        <Shortcut Id="ScAionUi" Name="KFAI - Abrir AionUi" Target="[INSTALLFOLDER]08-KFAI-Abrir-AionUi.vbs" WorkingDirectory="INSTALLFOLDER" />')
[void]$sb.AppendLine('        <RegistryValue Root="HKCU" Key="Software\KFAI\Shortcuts" Name="AionUi" Type="integer" Value="1" KeyPath="yes" />')
[void]$sb.AppendLine('      </Component>')
[void]$sb.AppendLine('    </DirectoryRef>')
[void]$sb.AppendLine('    <ComponentGroup Id="KfaiShortcuts">')
[void]$sb.AppendLine('      <ComponentRef Id="C_ScOpenCode" />')
[void]$sb.AppendLine('      <ComponentRef Id="C_ScAionUi" />')
[void]$sb.AppendLine('    </ComponentGroup>')
[void]$sb.AppendLine('  </Fragment>')

[void]$sb.AppendLine('</Wix>')

$Payload = Join-Path $MsiDir "Payload.wxs"
$sb.ToString() | Set-Content -LiteralPath $Payload -Encoding utf8
Write-Host "Payload.wxs gerado: $Payload" -ForegroundColor Green

# ============ 4) build do MSI ============
Write-Host "Compilando KFAI v$Version (MSI, wizard pt-BR)..." -ForegroundColor Cyan
# ProductCode NOVO a cada build: sem isso, instalar por cima de uma versao
# instalada com o mesmo ProductCode trava com "ja foi instalada outra versao".
# O UpgradeCode permanece fixo, entao o MajorUpgrade substitui a versao antiga.
$ProductCode = [guid]::NewGuid().ToString().ToUpperInvariant()
$uiExt = "WixToolset.UI.wixext/4.0.6"
$uiExtDll = Join-Path $env:USERPROFILE ".wix\extensions\WixToolset.UI.wixext\4.0.6\wixext4\WixToolset.UI.wixext.dll"
if(Test-Path -LiteralPath $uiExtDll){ $uiExt = $uiExtDll }
$args = @(
  (Join-Path $MsiDir "KFAI.wxs"),
  (Join-Path $MsiDir "WixUI_KFAI.wxs"),
  $Payload,
  "-ext",$uiExt,
  "-arch","x64",
  "-culture","pt-BR",
  "-loc",(Join-Path $MsiDir "pt-BR.wxl"),
  "-d","Version=$Version",
  "-d","ProductCode=$ProductCode",
  "-o",$Out,
  "-pdbtype","none"
)
& wix build @args
if($LASTEXITCODE -ne 0){
  Write-Error "Falha ao compilar o MSI (wix build exit $LASTEXITCODE)."
  exit 1
}

if(-not (Test-Path -LiteralPath $Out)){
  Write-Error "MSI nao foi gerado."
  exit 1
}

$h = (Get-FileHash -LiteralPath $Out -Algorithm SHA256).Hash
$sizeMb = [math]::Round((Get-Item -LiteralPath $Out).Length / 1MB, 2)

# ============ 5) validacao ICE ============
# ICE38/64/91 sao falsos positivos esperados em instalacao por-usuario
# (Scope="perUser": arquivos no perfil com keypath de arquivo). Suprimidos.
Write-Host "Validando com ICE..." -ForegroundColor Cyan
& wix msi validate $Out -sice ICE38 -sice ICE64 -sice ICE91
if($LASTEXITCODE -ne 0){
  Write-Error "MSI nao passou na validacao ICE (exit $LASTEXITCODE)."
  exit 1
}
Write-Host "ICE: OK" -ForegroundColor Green

Write-Host ""
Write-Host "Instalador MSI gerado: $Out" -ForegroundColor Green
Write-Host "Tamanho: $sizeMb MB"
Write-Host "SHA-256: $h"
Write-Host ""
Write-Host "Anexe ao release e publique o hash no README."
