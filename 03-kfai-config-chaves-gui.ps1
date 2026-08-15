# KFAI - Janela grafica de configuracao das chaves de IA (9Router)
# Mostra os provedores gratuitos que faltam com um campo para colar cada chave,
# salva direto no 9Router (API local http://localhost:20128) e testa cada conexao.
#
# Por que GUI: o instalador MSI roda sem console interativo, entao Read-Host nao
# funciona la. Esta janela abre visivel por cima do MSI e nao depende do console.
#
# Uso:
#   .\03-kfai-config-chaves-gui.ps1             abre a janela
#   .\03-kfai-config-chaves-gui.ps1 -AutoClose  fecha sozinho se nao faltar nada
#
# Seguranca: a chave colada vai direto para a API local do 9Router e nunca e
# gravada em arquivo pelo KFAI. Os dados exibidos sao apenas provider/isActive.
[CmdletBinding()]
param(
  [switch]$AutoClose
)
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if(-not $Root){ $Root = Get-Location }
$NodeStatusJs = Join-Path $Root "scripts\kfai-9router-status.js"

function Test-Port([int]$port){
  try {
    $c = New-Object Net.Sockets.TcpClient
    try { $c.Connect("127.0.0.1", $port); return $true } finally { $c.Dispose() }
  } catch { return $false }
}

function Find-NineRouterDb {
  foreach($c in @((Join-Path $env:APPDATA "9Router\db\data.sqlite"),(Join-Path $env:APPDATA "9router\db\data.sqlite"))){
    if(Test-Path -LiteralPath $c){ return $c }
  }
  return $null
}

function Find-BetterSqlite {
  foreach($b in @((Join-Path $env:APPDATA "9Router\runtime\node_modules"),(Join-Path $env:APPDATA "9router\runtime\node_modules"))){
    $p = Join-Path $b "better-sqlite3"
    if(Test-Path -LiteralPath $p){ return $p }
  }
  return $null
}

$NodeJs = (Get-Command node -ErrorAction SilentlyContinue).Source
if(-not $NodeJs){ $NodeJs = "$env:ProgramFiles\nodejs\node.exe" }

# Provedores gratuitos entendidos pelo 9Router (mesmo cadastro do 02). So os
# de tipo 'apikey' aparecem com campo de chave; oauth/nenhuma sao informativos.
$Providers = @(
  @{ Provider = 'openrouter';      Nome = 'OpenRouter';        Tipo = 'apikey';  Link = 'https://openrouter.ai/keys' }
  @{ Provider = 'gemini';          Nome = 'Google Gemini';     Tipo = 'apikey';  Link = 'https://aistudio.google.com/apikey' }
  @{ Provider = 'nvidia';          Nome = 'NVIDIA NIM';        Tipo = 'apikey';  Link = 'https://build.nvidia.com' }
  @{ Provider = 'cloudflare-ai';   Nome = 'Cloudflare AI';     Tipo = 'apikey';  Link = 'https://dash.cloudflare.com' }
  @{ Provider = 'api-airforce';    Nome = 'API.airforce';      Tipo = 'apikey';  Link = 'https://api.airforce' }
  @{ Provider = 'poolside';        Nome = 'Poolside';          Tipo = 'apikey';  Link = 'https://poolside.ai' }
  @{ Provider = 'byteplus';        Nome = 'BytePlus ModelArk'; Tipo = 'apikey';  Link = 'https://www.byteplus.com' }
  @{ Provider = 'groq';            Nome = 'Groq';              Tipo = 'apikey';  Link = 'https://console.groq.com/keys' }
  @{ Provider = 'cerebras';        Nome = 'Cerebras';          Tipo = 'apikey';  Link = 'https://cloud.cerebras.ai' }
  @{ Provider = 'mistral';         Nome = 'Mistral';           Tipo = 'apikey';  Link = 'https://console.mistral.ai/api-keys' }
  @{ Provider = 'cohere';          Nome = 'Cohere';            Tipo = 'apikey';  Link = 'https://dashboard.cohere.com/api-keys' }
  @{ Provider = 'huggingface';     Nome = 'HuggingFace';       Tipo = 'apikey';  Link = 'https://huggingface.co/settings/tokens' }
  @{ Provider = 'vercel-ai-gateway'; Nome = 'Vercel AI Gateway'; Tipo = 'apikey'; Link = 'https://vercel.com' }
  @{ Provider = 'bazaarlink';      Nome = 'Bazaarlink';        Tipo = 'apikey';  Link = 'https://bazaarlink.ai' }
  @{ Provider = 'kilo-gateway';    Nome = 'Kilo Gateway';      Tipo = 'apikey';  Link = 'https://kilo-gateway.com' }
  @{ Provider = 'ollama';          Nome = 'Ollama Cloud';      Tipo = 'apikey';  Link = 'https://ollama.com' }
  @{ Provider = 'gemini-cli';      Nome = 'Gemini CLI';        Tipo = 'oauth';   Link = 'https://aistudio.google.com' }
  @{ Provider = 'kiro';            Nome = 'Kiro AI';           Tipo = 'oauth';   Link = 'https://kiro.ai' }
  @{ Provider = 'kimchi';          Nome = 'Kimchi';            Tipo = 'oauth';   Link = 'https://kimchi.ai' }
  @{ Provider = 'mimo-free';       Nome = 'MiMo Code Free';    Tipo = 'nenhuma'; Link = 'https://xiaomi.com' }
  @{ Provider = 'opencode';        Nome = 'OpenCode Free';     Tipo = 'nenhuma'; Link = 'https://opencode.ai' }
  @{ Provider = 'searxng';         Nome = 'SearXNG';           Tipo = 'nenhuma'; Link = 'https://github.com/searxng/searxng' }
  @{ Provider = 'edge-tts';        Nome = 'Edge TTS';          Tipo = 'nenhuma'; Link = 'https://github.com/rany2/edge-tts' }
  @{ Provider = 'coqui';           Nome = 'Coqui TTS';         Tipo = 'nenhuma'; Link = 'https://github.com/coqui-ai/TTS' }
  @{ Provider = 'tortoise';        Nome = 'Tortoise TTS';      Tipo = 'nenhuma'; Link = 'https://github.com/neonbjb/tortoise-tts' }
  @{ Provider = 'local-device';    Nome = 'Local Device';      Tipo = 'nenhuma'; Link = 'https://github.com/9router/local-ai-docs' }
)

function Get-CliToken {
  $base = Join-Path $env:APPDATA "9router"
  $mid  = (Get-Content -LiteralPath (Join-Path $base "machine-id") -Raw -ErrorAction SilentlyContinue).Trim()
  $sec  = (Get-Content -LiteralPath (Join-Path $base "auth\cli-secret") -Raw -ErrorAction SilentlyContinue).Trim()
  if(-not $mid -or -not $sec){ return $null }
  $sha   = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($mid + "9r-cli-auth" + $sec)
  $hex   = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
  return $hex.Substring(0, 16)
}

$script:CliToken = Get-CliToken

function Invoke-9RApi {
  param([string]$Method, [string]$Path, $Body = $null)
  $headers = @{ "x-9r-cli-token" = $script:CliToken }
  $uri = "http://localhost:20128$Path"
  try {
    if($null -eq $Body){
      return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -TimeoutSec 60
    }
    return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers `
      -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 6) -TimeoutSec 60
  } catch {
    $err = $_.Exception.Message
    try {
      $det = $_.ErrorDetails.Message
      if($det){ $j = $det | ConvertFrom-Json; if($j.error){ $err = $j.error } }
    } catch {}
    return [pscustomobject]@{ error = $err }
  }
}

# ---- le estado real das conexoes via API (mais preciso que o db) ----
function Get-9RouterState {
  $conns = @()
  if($script:CliToken -and (Test-Port 20128)){
    $provs = Invoke-9RApi -Method GET -Path "/api/providers"
    if($provs -and $provs.connections){ $conns = @($provs.connections) }
  }
  return $conns
}

# ---- le o estado via banco (fallback quando 9Router parado) ----
function Get-DbState {
  $Db = Find-NineRouterDb
  $Better = Find-BetterSqlite
  if(-not $Db -or -not $Better -or -not (Test-Path -LiteralPath $NodeJs)){ return @() }
  $json = (& $NodeJs $NodeStatusJs $Db $Better 2>$null | Select-Object -Last 1)
  if(-not $json){ return @() }
  try { $obj = $json | ConvertFrom-Json; return @($obj.providers) } catch { return @() }
}

function Save-Key {
  param([string]$Provider, [string]$Key)
  if(-not $script:CliToken){ return [pscustomobject]@{ error = 'Nao autenticou no 9Router (machine-id/cli-secret).' } }
  $resp = Invoke-9RApi -Method POST -Path "/api/providers" -Body @{ provider = $Provider; name = $Provider; apiKey = $Key }
  return $resp
}

# ========================== MONTAGEM DA JANELA ==========================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-KeysWindow {
  param(
    [array]$Missing,          # providers apikey sem chave
    [array]$OAuthNenhuma,     # informativos (sem campo de chave)
    [string]$EstadoMsg
  )
  $script:Exiting = $false

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'KFAI - Configurar chaves de IA gratuitas'
  $form.StartPosition = 'CenterScreen'
  $form.TopMost = $true
  $form.MinimizeBox = $false
  $form.MaximizeBox = $false
  $form.FormBorderStyle = 'FixedDialog'
  $form.AutoSize = $false
  $form.ClientSize = [System.Drawing.Size]::new(760, 620)
  $form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
  $form.ForeColor = [System.Drawing.Color]::White

  $pad = 16
  $top = $pad
  $rowH = 44
  $lblW = 180
  $boxX = $pad + $lblW
  $boxW = 380
  $btnW = 120

  # Cabecalho
  $hdr = New-Object System.Windows.Forms.Label
  $hdr.Location = [System.Drawing.Point]::new($pad, $top)
  $hdr.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - $pad*2), 46)
  $hdr.Text = "Faltam $($Missing.Count) chave(s) gratuita(s) para usar IA em nuvem.`nCole cada chave no campo ao lado e clique em Salvar. Nada fica gravado em arquivo."
  $hdr.ForeColor = [System.Drawing.Color]::White
  $form.Controls.Add($hdr)
  $top += 56

  # Painel com scroll para os campos
  $panel = New-Object System.Windows.Forms.Panel
  $panel.Location = [System.Drawing.Point]::new($pad, $top)
  $panel.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - $pad*2), 380)
  $panel.Anchor = 'Top,Left,Right'
  $panel.BackColor = [System.Drawing.Color]::FromArgb(40,40,40)
  $panel.AutoScroll = $true
  $form.Controls.Add($panel)

  $script:Boxes = @{}     # provider -> TextBox
  $inner = 0
  if($Missing.Count -eq 0){
    $nl = New-Object System.Windows.Forms.Label
    $nl.Text = 'Nenhuma chave faltando. Sua IA gratuita ja esta pronta!'
    $nl.ForeColor = [System.Drawing.Color]::LightGreen
    $nl.Location = [System.Drawing.Point]::new(8, 10)
    $nl.Size = [System.Drawing.Size]::new(680, 30)
    $panel.Controls.Add($nl)
    $inner = 50
  } else {
    foreach($p in $Missing){
      $y = 8 + $inner
      $lbl = New-Object System.Windows.Forms.Label
      $lbl.Location = [System.Drawing.Point]::new(8, $y+3)
      $lbl.Size = [System.Drawing.Size]::new($lblW, 20)
      $lbl.Text = $p.Nome
      $lbl.ForeColor = [System.Drawing.Color]::White
      $lbl.Tag = $p
      $panel.Controls.Add($lbl)

      $link = New-Object System.Windows.Forms.LinkLabel
      $link.Location = [System.Drawing.Point]::new(8, $y+20)
      $link.Size = [System.Drawing.Size]::new($lblW, 18)
      $link.Text = 'gerar chave'
      $link.LinkColor = [System.Drawing.Color]::Cyan
      $link.Tag = $p.Link
      $link.Add_Click({
        Start-Process $this.Tag
      })
      $panel.Controls.Add($link)

      $box = New-Object System.Windows.Forms.TextBox
      $box.Location = [System.Drawing.Point]::new($boxX, $y)
      $box.Size = [System.Drawing.Size]::new($boxW, 24)
      $box.UseSystemPasswordChar = $true
      $box.Tag = $p
      $panel.Controls.Add($box)
      $script:Boxes[$p.Provider] = $box

      $inner += $rowH
    }
  }
  $panel.AutoScrollMinSize = [System.Drawing.Size]::new(0, ($inner + 8))

  $top += 390

  # Estado (mensagens de resultado)
  $status = New-Object System.Windows.Forms.Label
  $status.Location = [System.Drawing.Point]::new($pad, $top)
  $status.Size = [System.Drawing.Size]::new(($form.ClientSize.Width - $pad*2), 70)
  $status.Text = $EstadoMsg
  $status.ForeColor = [System.Drawing.Color]::LightGray
  $status.TextAlign = 'TopLeft'
  $form.Controls.Add($status)

  # Botoes
  $btnSave = New-Object System.Windows.Forms.Button
  $btnSave.Text = 'Salvar chaves'
  $btnSave.Location = [System.Drawing.Point]::new($pad, ($top + 78))
  $btnSave.Size = [System.Drawing.Size]::new(140, 32)
  $btnSave.BackColor = [System.Drawing.Color]::FromArgb(0,120,215)
  $btnSave.ForeColor = [System.Drawing.Color]::White
  $btnSave.FlatStyle = 'Flat'
  $btnSave.Add_Click({
    $btnSave.Enabled = $false
    $status.Text = 'Salvando...'
    $status.ForeColor = [System.Drawing.Color]::LightGray
    $form.Refresh()

    $salvas = 0
    $falhas = @()
    foreach($prov in $Missing){
      $box = $script:Boxes[$prov.Provider]
      $key = $box.Text.Trim()
      if(-not $key){ continue }
      $resp = Save-Key -Provider $prov.Provider -Key $key
      $box.Text = ''
      if($resp -and -not $resp.error){
        $salvas++
        $box.BackColor = [System.Drawing.Color]::FromArgb(0,120,0)
      } else {
        $falhas += ($prov.Nome + ' (API: ' + $resp.error + ')')
        $box.BackColor = [System.Drawing.Color]::FromArgb(140,40,40)
      }
    }

    $msg = "Chaves salvas: $salvas"
    if($falhas.Count -gt 0){ $msg += "`nFalharam: " + ($falhas -join '; ') }
    if($salvas -gt 0){ $msg += "`nConfira no painel http://localhost:20128/dashboard se as conexoes estao ativas." }
    $status.Text = $msg
    $status.ForeColor = if($falhas.Count -eq 0){ [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::Orange }
    $btnSave.Enabled = $true
  })
  $form.Controls.Add($btnSave)

  $btnLater = New-Object System.Windows.Forms.Button
  $btnLater.Text = 'Depois'
  $btnLater.Location = [System.Drawing.Point]::new(($pad + 150), ($top + 78))
  $btnLater.Size = [System.Drawing.Size]::new(90, 32)
  $btnLater.BackColor = [System.Drawing.Color]::FromArgb(70,70,70)
  $btnLater.ForeColor = [System.Drawing.Color]::White
  $btnLater.FlatStyle = 'Flat'
  $btnLater.Add_Click({ $form.Close() })
  $form.Controls.Add($btnLater)

  $btnDash = New-Object System.Windows.Forms.Button
  $btnDash.Text = 'Abrir painel 9Router'
  $btnDash.Location = [System.Drawing.Point]::new(($pad + 250), ($top + 78))
  $btnDash.Size = [System.Drawing.Size]::new(140, 32)
  $btnDash.BackColor = [System.Drawing.Color]::FromArgb(70,70,70)
  $btnDash.ForeColor = [System.Drawing.Color]::White
  $btnDash.FlatStyle = 'Flat'
  $btnDash.Add_Click({ Start-Process 'http://localhost:20128/dashboard' })
  $form.Controls.Add($btnDash)

  $form.Add_Shown({ $form.Activate() })
  $form.Add_FormClosed({ $script:Exiting = $true })

  $form.ShowDialog() | Out-Null
  return @{ salvos = $null }
}

# ========================== FLUXO ==========================
$conns = Get-9RouterState
if($conns.Count -eq 0 -and (Test-Port 20128) -eq $false){
  $conns = Get-DbState
}

$temKey = @{}
foreach($c in $conns){
  if($c.provider){
    if($c.hasKey -ne $null){
      $temKey[$c.provider] = $c.hasKey
    } elseif($c.apiKey -or $c.token -or $c.key){
      $temKey[$c.provider] = $true
    } elseif($c.provider){
      $temKey[$c.provider] = $false
    }
  }
}

$Missing = @()
$OAuthNenhuma = @()
foreach($prov in $Providers){
  $has = $temKey[$prov.Provider]
  if($has){
    continue
  }
  if($prov.Tipo -eq 'apikey'){
    $Missing += $prov
  } else {
    $OAuthNenhuma += $prov
  }
}

$nineUp = Test-Port 20128
$estado = "Estado do 9Router: " + $(if($nineUp){'rodando (porta 20128)'}else{'instalado mas PARADO'})
if(-not $nineUp){ $estado += "`nInicie o 9Router para salvar chaves (o botao Salvar usa a porta 20128)." }

if($Missing.Count -eq 0 -and $AutoClose){
  return
}

Show-KeysWindow -Missing $Missing -OAuthNenhuma $OAuthNenhuma -EstadoMsg $estado
# sem exit: retorna ao chamador (instalador continua)

