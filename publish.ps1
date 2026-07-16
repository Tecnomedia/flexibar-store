<#
.SYNOPSIS
Publica (o actualiza) una App en el catalogo de la tienda.

.EXAMPLE
./publish.ps1 -PackPath ..\facturas.flexiapp.json -Id facturas-code128 -Category "Administración" -Tags facturas,pdf -Changelog "Primera versión"
Despues: git add -A; git commit; git push  (GitHub Pages publica solo).
#>
param(
    [Parameter(Mandatory)] [string]$PackPath,
    [Parameter(Mandatory)] [string]$Id,
    [Parameter(Mandatory)] [string]$Category,
    [string[]]$Tags = @(),
    [string]$MinAppVersion = "",
    [string]$Changelog = ""
)
$ErrorActionPreference = "Stop"

if ($Id -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "Id '$Id' invalido: usar slug kebab-case." }

# --- Validar el pack (mismo contrato que el importador) ---
$raw = [IO.File]::ReadAllText($PackPath)
$pack = $raw | ConvertFrom-Json
if ($pack.formatVersion -ne "1.0") { throw "formatVersion '$($pack.formatVersion)' no soportada (esperado 1.0)." }
if ([string]::IsNullOrWhiteSpace($pack.app.name)) { throw "El pack no tiene app.name." }
$null = $pack.app.pipelineJson | ConvertFrom-Json   # pipeline debe ser JSON valido

# --- hasScripts: heuristica informativa (el consentimiento real lo hace la app sobre el pack descargado) ---
$hasScripts = $false
foreach ($campo in @($pack.app.eventsJson, $pack.app.pipelineJson, $pack.app.actionButtonsJson, $pack.app.transferJson)) {
    if ($campo -match '"script"\s*:\s*"[^"]') { $hasScripts = $true }
}
if (-not [string]::IsNullOrWhiteSpace($pack.app.verificationScriptSource)) { $hasScripts = $true }
if (-not [string]::IsNullOrWhiteSpace($pack.app.verificationAssemblyPath)) { $hasScripts = $true }

# --- Copiar el pack y calcular sha256 ---
$destRel = "apps/$Id.flexiapp.json"
$dest = Join-Path $PSScriptRoot $destRel
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot "apps") | Out-Null
Copy-Item $PackPath $dest -Force
$sha = (Get-FileHash $dest -Algorithm SHA256).Hash

# --- Actualizar catalog.json ---
$catalogPath = Join-Path $PSScriptRoot "catalog.json"
$catalog = if (Test-Path $catalogPath) {
    Get-Content $catalogPath -Raw | ConvertFrom-Json
} else {
    [pscustomobject]@{ catalogVersion = "1.0"; updatedAt = ""; apps = @() }
}

$existing = $catalog.apps | Where-Object { $_.id -eq $Id }
$version = if ($existing) { $existing.version + 1 } else { 1 }

$entry = [ordered]@{
    id              = $Id
    version         = $version
    name            = $pack.app.name
    description     = $pack.app.description
    category        = $Category
    tags            = @($Tags)
    iconKey         = "$($pack.app.iconKey)"
    iconAccent      = "$($pack.app.iconAccent)"
    backgroundColor = "$($pack.app.backgroundColor)"
    hasScripts      = $hasScripts
    formatVersion   = "1.0"
    minAppVersion   = $MinAppVersion
    packUrl         = $destRel
    sha256          = $sha
    publishedAt     = (Get-Date -Format "yyyy-MM-dd")
    changelog       = $Changelog
}

$apps = @($catalog.apps | Where-Object { $_.id -ne $Id }) + [pscustomobject]$entry
$result = [ordered]@{
    catalogVersion = "1.0"
    updatedAt      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    apps           = $apps | Sort-Object id
}

# UTF-8 SIN BOM: el cliente parsea el fichero tal cual.
[IO.File]::WriteAllText($catalogPath, ($result | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

Write-Host "Publicada '$($pack.app.name)' ($Id) v$version — hasScripts=$hasScripts"
Write-Host "Ahora: git add -A && git commit -m 'publica $Id v$version' && git push"
