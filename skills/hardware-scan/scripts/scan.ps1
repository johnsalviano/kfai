# scan.ps1 - Leitura de hardware real (somente leitura)
$ErrorActionPreference = 'Stop'

function GB($bytes){ if($null -eq $bytes){ return 0 } [math]::Round($bytes/1GB,1) }

$ram  = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$gpus = Get-CimInstance Win32_VideoController | Sort-Object AdapterRAM -Descending

Write-Host "== Hardware Scan =="
Write-Host "RAM total: $((GB $ram)) GB"
Write-Host "CPU: $($cpu.Name) ($($cpu.NumberOfCores) nucleos / $($cpu.NumberOfLogicalProcessors) threads)"
foreach($g in $gpus){ Write-Host "GPU: $($g.Name) - $(GB $g.AdapterRAM) GB VRAM" }
foreach($d in $disk){ Write-Host "Disco $($d.DeviceID): livre $((GB $d.FreeSpace)) GB / total $((GB $d.Size)) GB" }

# Classificacao p/ IA local
if($ram -le 3gb){ Write-Host "`nResultado: PC FRACO - rode Full Cloud (nao usa IA local)" }
elseif($ram -lt 8gb){ Write-Host "`nResultado: IA local leve -> qwen3:0.6b (ou llama3.2:1b)" }
elseif($ram -lt 16gb){ Write-Host "`nResultado: IA local media -> qwen3:4b (ou llama3.2:3b)" }
elseif($gpus.Count -gt 0 -and ($gpus[0].AdapterRAM -ge 4gb)){ Write-Host "`nResultado: IA local boa -> qwen3:8b (ou llama3.2:8b)" }
else{ Write-Host "`nResultado: IA local boa -> qwen3:8b (ou llama3.2:8b)" }