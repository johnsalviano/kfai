<#
.SYNOPSIS
    Lista modelos disponíveis no KFAI por capacidade (chat, imagem, tts, stt, embeddings, web).

.DESCRIPTION
    Usa os endpoints /v1/models/<kind> do router KFAI (porta 20129) que faz proxy pro 9Router.
    Mostra ID, provedor (owned_by), tipo (kind) e, se disponível, metadados (contextWindow).

.NOTES
    Requer: 9Router rodando (porta 20128) e router KFAI rodando (porta 20129).
    Se o 9Router tiver requireApiKey=true, defina $env:NINEROUTER_KEY.
#>

param(
    [ValidateSet("chat","image","tts","stt","embedding","web","all")]
    [string]$Kind = "all",
    [switch]$Details
)

$routerUrl = "http://127.0.0.1:20129"
$headers = @{}
if ($env:NINEROUTER_KEY) { $headers["Authorization"] = "Bearer $env:NINEROUTER_KEY" }

function Get-Models {
    param($endpoint)
    try {
        $resp = Invoke-RestMethod -Method Get -Uri "$routerUrl$endpoint" -Headers $headers -TimeoutSec 10
        return $resp.data
    } catch {
        Write-Error ("Falha ao consultar {0}: {1}" -f $endpoint, $_.Exception.Message)
        return @()
    }
}

function Show-Models {
    param($models, $title)
    if (-not $models) { return }
    Write-Host "`n=== $title ===" -ForegroundColor Cyan
    $models | ForEach-Object {
        $id = $_.id
        $owned = if ($_.owned_by) { $_.owned_by } else { "" }
        $kind = if ($_.kind) { $_.kind } else { "" }
        $line = "  $id"
        if ($owned) { $line += "  [$owned]" }
        if ($kind) { $line += "  <$kind>" }
        Write-Host $line -ForegroundColor White
        if ($Details -and $_.contextWindow) {
            Write-Host "    contextWindow: $($_.contextWindow)" -ForegroundColor DarkGray
        }
    }
}

switch ($Kind) {
    "chat"      { Show-Models (Get-Models "/v1/models") "Chat / LLM" }
    "image"     { Show-Models (Get-Models "/v1/models/image") "Geração de Imagem" }
    "tts"       { Show-Models (Get-Models "/v1/models/tts") "Text-to-Speech" }
    "stt"       { Show-Models (Get-Models "/v1/models/stt") "Speech-to-Text" }
    "embedding" { Show-Models (Get-Models "/v1/models/embedding") "Embeddings" }
    "web"       {
        $web = Get-Models "/v1/models/web"
        $search = $web | Where-Object { $_.kind -eq "webSearch" }
        $fetch  = $web | Where-Object { $_.kind -eq "webFetch" }
        Show-Models $search "Busca Web (webSearch)"
        Show-Models $fetch  "Fetch URL (webFetch)"
    }
    "all" {
        Show-Models (Get-Models "/v1/models") "Chat / LLM"
        Show-Models (Get-Models "/v1/models/image") "Geração de Imagem"
        Show-Models (Get-Models "/v1/models/tts") "Text-to-Speech"
        Show-Models (Get-Models "/v1/models/stt") "Speech-to-Text"
        Show-Models (Get-Models "/v1/models/embedding") "Embeddings"
        $web = Get-Models "/v1/models/web"
        $search = $web | Where-Object { $_.kind -eq "webSearch" }
        $fetch  = $web | Where-Object { $_.kind -eq "webFetch" }
        Show-Models $search "Busca Web (webSearch)"
        Show-Models $fetch  "Fetch URL (webFetch)"
    }
}

if ($Details) {
    Write-Host "`nUse -Details para ver contextWindow (requer /v1/models/info por modelo)." -ForegroundColor DarkGray
}