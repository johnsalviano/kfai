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
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step([string]$m){ Write-Host "`n== $m ==" -ForegroundColor Cyan }

function Get-HardwareInfo {
  $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
  $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
  $gpus = Get-CimInstance Win32_VideoController
  $adapter = $gpus | Sort-Object AdapterRAM -Descending | Select-Object -First 1
  $vramGb = if($adapter.AdapterRAM){ [math]::Round($adapter.AdapterRAM / 1GB, 1) } else { 0 }
  return @{ Ram = $ramGb; Cpu = $cpu; Vram = $vramGb; Gpu = $adapter.Name }
}

function ChooseLocalModel($hw){
  if($hw.Ram -le 3){ return $null }
  if($hw.Ram -lt 8){ return 'qwen2.5:1.5b' }
  if($hw.Ram -lt 16){ return 'qwen2.5:3b' }
  if($hw.Vram -ge 4){ return 'qwen2.5:7b' }
  if($hw.Ram -ge 32){ return 'qwen2.5:14b' }
  return 'qwen2.5:7b'
}

Write-Step "KFAI - Kit de Ferramentas de Agente de IA"
$hw = Get-HardwareInfo
Write-Host "RAM: $($hw.Ram) GB | CPU: $($hw.Cpu) | GPU VRAM: $($hw.Vram) GB ($($hw.Gpu))"

$model = ChooseLocalModel $hw
$useLocal = ($model -ne $null -and -not $SkipOllama)

Write-Host ""
if($useLocal){
  Write-Step "Modelo local escolhido para seu PC: $model"
  if(-not (Get-Command ollama -ErrorAction SilentlyContinue)){
    Write-Host "Ollama nao encontrado. Abrindo guia de instalacao..." -ForegroundColor Yellow
    Start-Process "https://ollama.com/download/windows"
    Write-Host "Instale o Ollama, rode este script de novo." -ForegroundColor Yellow
    exit 1
  }
  Write-Host "Baixando modelo via ollama pull (pode levar alguns minutos)..."
  ollama pull $model
  Write-Host "Modelo local pronto: $model" -ForegroundColor Green
} else {
  if($model -eq $null){
    Write-Step "Seu PC nao roda modelo local (pouca memoria). Kit usara Full Cloud."
  } else {
    Write-Step "IA local pulada por opcao. Baixe depois com: ollama pull $model"
  }
}

Write-Step "Guia de proximos passos"
Write-Host @"
1. Abra o 9Router e ative as conexoes gratuitas de sua escolha.
2. Adicione suas chaves gratuitas (links em docs/GUIA-CHAVES-GRATIS.md).
3. Copie o config de combo desejado para o opencode:
   - Full Cloud      -> config\opencode\full-cloud.json
   - Cloud + Local   -> config\opencode\cloud-plus-local.json
   - Full Local      -> config\opencode\full-local.json  (troque KFAI_LOCAL_MODEL pelo modelo, se necessario)
   Pronto! Use as skills da pasta skills\ para otimizar seu PC.
"@ -ForegroundColor Cyan
Write-Host "`nKFAI instalado. Curto e simples." -ForegroundColor Green