\# MODO DE EJECUCIÓN: BUCLE AUTÓNOMO ININTERRUMPIDO (ZERO-STOP LOOP)



Tu objetivo es completar el 100% de las tareas pendientes (`- \[ ]`) en `@PLAN.md` cumpliendo estrictamente las reglas de `@GEMINI.md`.



\## REGLAS DEL BUCLE (PROHIBIDO DETENERSE)

1\. \*\*NO PIDAS CONFIRMACIÓN HUMANA:\*\* Está estrictamente prohibido preguntar "¿Quieres que continúe con el siguiente paso?" o "¿Te parece bien esta implementación?". Toma decisiones técnicas autónomas basadas en `@GEMINI.md`.

2\. \*\*PROHIBIDO EL CÓDIGO INCOMPLETO:\*\* Queda prohibido escribir `-- TODO`, `-- placeholder`, funciones vacías o simulaciones falsas. Todo módulo debe estar 100% implementado.

3\. \*\*CICLO OBLIGATORIO POR CADA MICRO-TAREA (`- \[ ]`):\*\*

&#x20;  - \*\*Fase A (Lectura):\*\* Identifica la primera tarea con `- \[ ]` en `PLAN.md`.

&#x20;  - \*\*Fase B (Generación Local si aplica):\*\* Si la tarea requiere datos estáticos masivos o assets, invoca primero los endpoints locales en Windows (`127.0.0.1:11434` para Ollama Qwen Coder o `127.0.0.1:8188` para ComfyUI / Cube 3D) o el nodo Mac M4 en LAN.

&#x20;  - \*\*Fase C (Implementación):\*\* Escribe los scripts `.luau` con `--!strict` y manipula el `DataModel` en Roblox Studio usando las herramientas MCP (`search\_game\_tree`, `inspect\_instance`, `generate\_procedural\_model`, `insert\_asset`).

&#x20;  - \*\*Fase D (Verificación Estática):\*\* Ejecuta en terminal `luau-lsp --strict` y `selene`. Si hay 1 solo error o warning, corrígelo antes de avanzar.

&#x20;  - \*\*Fase E (Verificación Dinámica en Runtime):\*\* Usa `@chrrxs/robloxstudio-mcp` (`solo\_playtest`, `eval\_server\_runtime`, `eval\_client\_runtime`, `get\_runtime\_logs`) para ejecutar la prueba matemática de conjuntos/relaciones exigida en el "Criterio de Aceptación" de esa tarea. Si `get\_runtime\_logs` muestra errores, repáralos en bucle hasta que el test devuelva `PASS`.

&#x20;  - \*\*Fase F (Check y Commit):\*\* Edita `PLAN.md` cambiando `- \[ ]` por `- \[x]` en esa tarea, ejecuta `git add . \&\& git commit -m "Complete Step X.Y"` y \*\*PASA INMEDIATAMENTE A LA SIGUIENTE TAREA `- \[ ]` EN LA MISMA RESPUESTA\*\* sin detenerte.

4\. \*\*CONDICIÓN DE PARADA ÚNICA:\*\* Solo puedes detener el bucle cuando `PLAN.md` tenga absolutamente todas las casillas marcadas como `- \[x]` y hayas escrito el archivo `PROYECTO\_COMPLETADO.md` con el reporte final de pruebas.

