param(
    [string]$GpuEndpoint = "http://127.0.0.1:11434/api/generate",
    [string]$MacEndpoint = "http://localhost:11435/api/generate",
    [string]$GpuModel = "qwen2.5-coder:14b",
    [string]$MacModel = "qwen2.5-coder:14b"
)

$CacheDir = Join-Path $PSScriptRoot ".agents\cache_gpu"
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

$AgentsDir = Join-Path $PSScriptRoot ".agents"
if (-not (Test-Path $AgentsDir)) {
    New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null
}

$CodeSnapshot = Get-ChildItem -Path (Join-Path $PSScriptRoot "src") -Recurse -Filter "*.luau" -ErrorAction SilentlyContinue | ForEach-Object {
    "=== ARCHIVO: $($_.FullName) ===`n" + (Get-Content $_.FullName -Raw)
} | Out-String

if ([string]::IsNullOrWhiteSpace($CodeSnapshot)) { 
    $CodeSnapshot = "Sin archivos Luau aun." 
}

Write-Host "[GPU RX 9070 XT] Consultando modelo local mediante inference_skill.py (Ollama 127.0.0.1:11434)..." -ForegroundColor Magenta
$GpuPrompt = "Actua como programador experto en Roblox Luau (--!strict). Genera las funciones procedurales para reemplazar las maquinas de cubos simples por cabinas Arcade detalladas (+20 piezas) y construir las 5 camaras subterraneas bajo Y=-150 con obstaculos fisicos reales."

$PythonScript = Join-Path $PSScriptRoot "inference_skill.py"

try {
    # Invocar inference_skill.py para obligar el uso de la GPU RX 9070 XT y Mac M4 con fallback
    $GpuResponse = & python $PythonScript --prompt $GpuPrompt --target "local" --model $GpuModel
    $GpuResponse | Set-Content -Path (Join-Path $CacheDir "gpu_3d_blueprint.md") -Encoding UTF8
    Write-Host "[GPU RX 9070 XT] Blueprint generado con exito." -ForegroundColor Green
} catch {
    Write-Host "[AVISO GPU] Error al invocar inference_skill.py: $_" -ForegroundColor Yellow
}

$AuditPrompt = "Auditor de Roblox Studio: Revisa el proyecto. Si las maquinas siguen siendo cubos o las salas son plataformas planas exteriores, inicia con 'ESTADO: REPROBADO' y enumera los fallos."
try {
    $AuditResponse = & python $PythonScript --prompt $AuditPrompt --target "mac" --model $MacModel
    $AuditResponse | Set-Content -Path (Join-Path $AgentsDir "audit_report.md") -Encoding UTF8
    Write-Host "[NODO MAC / DUAL-LLM] Reporte de auditoria completado." -ForegroundColor Cyan
} catch {
    "ESTADO: REPROBADO`nFaltan camaras subterraneas y cabinas arcade 3D reales." | Set-Content -Path (Join-Path $AgentsDir "audit_report.md") -Encoding UTF8
}
