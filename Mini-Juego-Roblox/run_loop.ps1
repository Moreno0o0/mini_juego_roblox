# run_perfection_loop.ps1 - Bucle Infinito Multi-Nodo (Windows RX 9070 XT + Mac M4 + Antigravity Cloud)
$PlanFile = ".\PLAN.md"
$Iteration = 1

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  INICIANDO BUCLE INFINITO DE PERFECCION (3 NODOS + SKILL ACTIVA) " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Asegurar que Ollama este corriendo en segundo plano en la RX 9070 XT
if (-not (Get-Process -Name "ollama*" -ErrorAction SilentlyContinue)) {
    Write-Host "Iniciando servidor Ollama en RX 9070 XT..." -ForegroundColor Yellow
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

while ($true) {
    Write-Host "`n>>> [CICLO DE PERFECCION #$Iteration] <<<" -ForegroundColor Yellow

    # 1. Ejecutar inferencia en RX 9070 XT y Auditoria en Mac M4
    .\invoke_cluster.ps1

    # 2. Auditoria dura de codigo y geometria en disco
    $AllCode = Get-ChildItem -Path ".\src" -Recurse -Filter "*.luau" -ErrorAction SilentlyContinue
    $TotalLines = ($AllCode | Get-Content | Measure-Object -Line).Lines
    $AuditText = if (Test-Path ".agents\audit_report.md") { Get-Content ".agents\audit_report.md" -Raw } else { "ESTADO: REPROBADO" }

    Write-Host "[METRICAS ACTUALES] Archivos Luau: $($AllCode.Count) \vert{} Lineas de codigo:$TotalLines" -ForegroundColor Cyan

    # 3. Verificar si hay tareas pendientes o si el Auditor reprobo el estado actual
    $PendingTasks = Select-String -Path$PlanFile -Pattern "^\s*-\s*\[\s*\]"

    if (-not $PendingTasks) {
        if ($AuditText -match "APROBADO_100" -and $TotalLines -gt 3500) {
            Write-Host "¡PERFECCION ALCANZADA! El Auditor y las metricas certifican el juego al 100%." -ForegroundColor Green
            break
        } else {
            Write-Host "[JUEZ DE CALIDAD] El agente marco [x] prematuramente, pero el juego sigue incompleto o basico." -ForegroundColor Red
            Write-Host "[JUEZ DE CALIDAD] Inyectando nueva ronda de tareas de remodelacion y pulido en PLAN.md..." -ForegroundColor Yellow

            $NewTasks = @"

---
## RONDA DE CORRECCION OBLIGATORIA (ITERACION #$Iteration - GENERADA POR AUDITOR LOCAL)
- [ ] **Correccion Critica $Iteration.1 (Geometria de Salas y Maquinas):** Eliminar los 5 pisos planos de colores exteriores en `Place1.rbxl` y construir las 5 `MinigameChambers` como salas cerradas subterraneas completas (con paredes, techo, iluminacion y obstaculos fisicos animados) y remodelar las 5 maquinas con +20 piezas arcade detalladas siguiendo `.agents/cache_gpu/gpu_3d_blueprint.md`. Limpiar los modelos `Char` y `Char1` sueltos del Workspace.
- [ ] **Correccion Critica $Iteration.2 (Jugabilidad Completa de los 5 Minijuegos y Armas):** Implementar el 100% de las observaciones del auditor en `.agents/audit_report.md`. Asegurar que al entrar a cada maquina el jugador sea teletransportado a la sala subterranea correspondiente, juegue el minijuego real con controles responsivos, reciba el arma 3D detallada y pueda combatir en la arena.
- [ ] **Correccion Critica $Iteration.3 (Sincronizacion en Vivo con Roblox Studio):** Inyectar y actualizar toda la geometria directamente en el Workspace activo de Roblox Studio via MCP (ademas de guardar en `src/` y compilar `build.rbxlx`), verificando con `solo_playtest` y `get_runtime_logs` que haya 0 errores.
"@
            Add-Content -Path $PlanFile -Value$NewTasks -Encoding UTF8
        }
    }

    # 4. Lanzar Antigravity CLI forzando el uso de la Skill y los reportes de la GPU y Mac
    $Prompt = @"
Activa y sigue estrictamente la skill `.agents/skills/local_cluster/SKILL.md`.
1. Lee `@GEMINI.md`, `@PROMPT_LOOP.md`, `@PLAN.md`, el blueprint generado por la GPU RX 9070 XT en `@.agents/cache_gpu/gpu_3d_blueprint.md` y el reporte de defectos del Auditor Mac M4 en `@.agents/audit_report.md`.
2. IMPORTANTE EN ROBLOX STUDIO: En el Workspace actual hay personajes de prueba (`Char`, `Char1`), las 5 maquinas son cubos simples y las 5 salas de minijuego son pisos planos de colores pegados afuera de las zonas. DEBES limpiarlos y reemplazarlos tanto en los scripts constructores de `src/server/` como en el `Workspace` vivo de Roblox Studio usando las herramientas MCP.
3. Resuelve todas las tareas `- [ ]` de `PLAN.md`, verifica con `selene`, `luau-lsp` y `solo_playtest`, y no te detengas.
"@

    Write-Host "[ORQUESTADOR] Lanzando Antigravity (agy) con contexto de GPU RX 9070 XT + Auditoria Mac M4..." -ForegroundColor Green
    agy --dangerously-skip-permissions -p $Prompt

    $Iteration++
    Start-Sleep -Seconds 3
}