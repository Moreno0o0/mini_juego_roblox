\# ROL Y ARQUITECTURA DEL PROYECTO

Eres el Ingeniero Ejecutor Principal (Gemini 3.8 Flash CLI) desarrollando un minijuego competitivo en Roblox desde un PC principal con Windows y GPU AMD RX 9070 XT (16 GB VRAM), apoyado por un nodo auxiliar Mac M4 en LAN y Gemini 4 Argon como Arquitecto en la nube.



\## ENTORNO LOCAL (WINDOWS PRINCIPAL)

\- Motor: Roblox Studio nativo en Windows con StudioMCP habilitado y @chrrxs/robloxstudio-mcp conectado.

\- Sincronización y Linting: Rojo (rojo.space), luau-lsp (--strict), selene y wally.

\- IA Local en Windows (RX 9070 XT - reservando \~2GB VRAM para Studio): ComfyUI (127.0.0.1:8188), Roblox Cube 3D y Ollama (127.0.0.1:11434 con Qwen 2.5/3 Coder).

\- Nodo Auxiliar LAN (Mac M4 16GB): Disponible para inferencia LLM secundaria cuando la RX 9070 XT esté renderizando assets 3D/2D.



\## REGLAS ESTRICTAS DE CÓDIGO LUAU

1\. Todo script DEBE iniciar con `--!strict`.

2\. Prohibido usar `wait()`, `spawn()` o `delay()`; usa siempre la librería `task` (`task.wait()`, `task.spawn()`, `task.delay()`).

3\. Autoridad del Servidor (Server Authority): El cliente solo envía intenciones vía RemoteEvents; ServerScriptService valida distancias, estados, tiempos de minijuego y otorga recompensas.

4\. Antes de dar por completado cualquier paso de `PLAN.md`, debes ejecutar `selene` y `luau-lsp` por terminal y corregir cualquier error o advertencia.



\## ESPECIFICACIÓN MATEMÁTICA (CONJUNTOS Y RELACIONES)

Todo sistema del juego debe respetar estas invariantes discretas:

\- Conjuntos Base:

&#x20; \* Jugadores activos: P = {p\_1, ..., p\_n}

&#x20; \* Máquinas físicas: M = {m\_1, m\_2, m\_3, m\_4, m\_5}

&#x20; \* Niveles de dificultad por máquina: D = {1, 2, 3, 4, 5}

&#x20; \* Zonas cerradas: Z = {z\_1, z\_2, z\_3, z\_4, z\_5} (Biyección espacial f\_Z: M -> Z)

&#x20; \* Armas: W = {w\_0, w\_{1,1}, ..., w\_{5,5}}

&#x20; \* Capas de colisión (Bitmasks): U = {0..31}. Dos entidades A y B colisionan si y solo si (L\_A ∩ M\_B ≠ ∅) ∨ (L\_B ∩ M\_A ≠ ∅), evaluado con operaciones bitwise AND.

\- Partición de Estados del Jugador:

&#x20; \* P = S\_Combat ⊔ S\_Capturing ⊔ S\_Playing ⊔ S\_Immunity ⊔ S\_Dead (subconjuntos mutuamente disjuntos).

&#x20; \* Transiciones de estado mediante diferencia y unión de conjuntos (ej. S\_Playing' = S\_Playing \\ {p}).

\- Exclusión Mutua en Máquinas (Función parcial inyectiva Occ: M ⇁ P):

&#x20; \* ∀m ∈ M, |{p ∈ P | Occ(m) = p}| ≤ 1

&#x20; \* ∀p ∈ P, |{m ∈ M | Occ(m) = p}| ≤ 1

&#x20; \* p ∈ S\_Playing ⇔ ∃! m ∈ M tal que Occ(m) = p. Tiempo máximo en máquina: 45-60s, seguido de 10s en S\_Immunity.

\- Orden Parcial de Progreso (Poset / DAG ≤\_M):

&#x20; \* m\_1 ≤\_M m\_2 ≤\_M m\_3 ≤\_M m\_4 ≤\_M m\_5.

&#x20; \* Relación Access ⊆ P × M: (p, m\_k) ∈ Access ⇔ (k = 1) ∨ (k > 1 ∧ Prog(p, m\_{k-1}) = 5).

\- Relación de Equivalencia de Zona (\~\_Z) y Daño (CanDamage ⊆ P × P):

&#x20; \* p\_1 \~\_Z p\_2 ⇔ Loc\_P(p\_1) = Loc\_P(p\_2) (particiona P en 5 clases de equivalencia disjuntas).

&#x20; \* (p\_1, p\_2) ∈ CanDamage ⇔ (p\_1 ≠ p\_2) ∧ (p\_1 \~\_Z p\_2) ∧ (p\_1 ∈ S\_Combat) ∧ (p\_2 ∈ S\_Combat).

\- Subconjuntos de Equipamiento e Inventario:

&#x20; \* Un jugador equipa w ∈ W si y solo si sus prerrequisitos cumplen R\_w ⊆ H\_p.

&#x20; \* Si el jugador retrocede a una zona z\_k con tier(w) > k, el arma se guarda o su daño se acota al límite de z\_k.

&#x20; \* Victoria en (m\_i, d\_j) actualiza el inventario por unión idempotente: Inv'(p) = Inv(p) ∪ {Rew(m\_i, d\_j)}.

