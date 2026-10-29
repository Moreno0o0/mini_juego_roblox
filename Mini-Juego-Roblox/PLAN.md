# PLAN MAESTRO DE INGENIERÍA (25 MICRO-TAREAS ATÓMICAS)

---

## FASE 1: ARQUITECTURA DE ARCHIVOS, LIBRERÍA DE CONJUNTOS Y CONTRATOS DE RED

- [x] **Paso 1.1: Estructura Rojo, Toolchain y Linter Estático**
  - **Archivos:** `default.project.json`, `selene.toml`, `wally.toml`, `.gitignore`.
  - **Conjuntos y Relaciones:** Partición estricta del conjunto de módulos $\mathcal{M} = \mathcal{M}_{\text{Server}} \sqcup \mathcal{M}_{\text{Shared}} \sqcup \mathcal{M}_{\text{Client}}$ con $\mathcal{M}_{\text{Server}} \cap \mathcal{M}_{\text{Client}} = \emptyset$. La relación de dependencia `require` ($R_{\text{req}}$) debe formar un Orden Parcial Estricto (DAG sin ciclos).
  - **Implementación:** Crear árbol `src/server`, `src/client`, `src/shared` y subcarpetas `Minigames`, `Combat`, `Machines`, `UI`, `Config`. Instalar paquetes de Wally (`ProfileStore` / `ByteNet` o contenedores de red equivalentes).
  - **Criterio de Aceptación (Test):** `rojo build -o build.rbxlx` y `selene src/` deben devolver 0 errores.

- [x] **Paso 1.2: Motor Matemático de Conjuntos y Relaciones (`src/shared/SetUtils.luau`)**
  - **Archivos:** `src/shared/Types.luau`, `src/shared/SetUtils.luau`.
  - **Conjuntos y Relaciones:** Implementar en Luau `--!strict` el tipo genérico `Set<T> = {[T]: boolean}` y `Relation<A, B> = {[A]: {[B]: boolean}}`.
  - **Operaciones Obligatorias a Programar:**
    1. `Union(A, B)`: $A \cup B$
    2. `Intersection(A, B)`: $A \cap B$
    3. `Difference(A, B)`: $A \setminus B$ (para eliminar estados incompatibles o dianas abatidas).
    4. `IsSubset(A, B)`: $A \subseteq B$ (para validar prerrequisitos de armas $R_w \subseteq H_p$).
    5. `BitmaskCanCollide(layerA, maskA, layerB, maskB)`: Evalúa $(L_A \cap M_B \neq \emptyset) \lor (L_B \cap M_A \neq \emptyset)$ usando `bit32.band`.
    6. `VerifyPartition(universe, subsets)`: Comprueba que los subconjuntos sean mutuamente disjuntos ($S_i \cap S_j = \emptyset$) y su unión sea igual al universo.
  - **Criterio de Aceptación (Test):** Ejecutar `eval_server_runtime` vía MCP corriendo pruebas unitarias sobre las 6 funciones matemáticas y verificando que `luau-lsp --strict` pase sin advertencias.

- [x] **Paso 1.3: Diccionarios Estáticos de Zonas, Máquinas y Armas (Con IA Local Ollama)**
  - **Archivos:** `src/shared/Config/ZonesConfig.luau`, `src/shared/Config/WeaponsConfig.luau`, `src/shared/Config/MachinesConfig.luau`.
  - **Conjuntos y Relaciones:**
    * Conjunto de Zonas $Z = \{z_1, z_2, z_3, z_4, z_5\}$ y Máquinas $M = \{m_1, m_2, m_3, m_4, m_5\}$ vinculados por biyección espacial $f_Z(m_i) = z_i$.
    * Conjunto de Armas $W$ particionado en 5 Tiers correspondientes a cada recinto:
      - Zona 1 (Novatos): Puños (`w_0`), Bate de madera (`w_1`).
      - Zona 2 (Intermedio): Cuchillo (`w_2a`), Resortera (`w_2b`).
      - Zona 3 (Avanzado): Espada corta (`w_3a`), Pistola básica (`w_3b`).
      - Zona 4 (Experto): Katana (`w_4a`), Escopeta (`w_4b`).
      - Zona 5 (Cumbre/Coliseo): Martillo pesado (`w_5a`), Rifle de plasma (`w_5b`).
    * Función inyectiva de recompensa $Rew: M \times D \to W$ que mapea cada par `(machineId, difficulty)` a un desbloqueo de arma o mejora de estadísticas.
  - **Implementación:** Invocar a Qwen Coder en Ollama (`127.0.0.1:11434`) para poblar las estadísticas completas (daño base, *cooldown* de ataque, alcance, proyectil, prerrequisitos $R_w$ y *tier* máximo permitido por zona).
  - **Criterio de Aceptación (Test):** Validar con `eval_server_runtime` que toda combinación $(m, d) \in \{1..5\} \times \{1..5\}$ devuelva un registro válido y no nulo en `WeaponsConfig` y `MachinesConfig`.

- [x] **Paso 1.4: Contratos de Red y Validador Anti-Exploit (`src/shared/Network.luau`)**
  - **Archivos:** `src/shared/Network.luau`, `src/server/SecurityValidator.luau`.
  - **Conjuntos y Relaciones:** Conjunto de eventos $E_{C \to S} = \{\text{RequestCapture}, \text{SubmitMinigameResult}, \text{RequestAttack}, \text{RequestEquip}, \text{RequestZoneChange}\}$ y $E_{S \to C} = \{\text{SyncState}, \text{StartMinigameClient}, \text{ForceExitMachine}, \text{CombatFeedback}\}$. Relación autoritativa $\text{Valid} \subseteq P \times E_{C \to S} \times \mathcal{S}_{\text{server}}$ con *rate-limiting* (antispam de paquetes).
  - **Criterio de Aceptación (Test):** Prueba en vivo con `eval_server_runtime` verificando que llamadas con tipos corruptos o fuera de *cooldown* sean rechazadas sin lanzar excepciones en el servidor.

---

## FASE 2: ARQUITECTURA ESPACIAL 3D, BITMASKS DE COLISIÓN Y EXCLUSIÓN MUTUA

- [x] **Paso 2.1: Sistema de Capas de Colisión por Bitmasks (`src/server/CollisionManager.luau`)**
  - **Archivos:** `src/server/CollisionManager.luau`.
  - **Conjuntos y Relaciones:** Universo de canales $U = \{0..31\}$. Asignar grupos en `PhysicsService` y máscaras de bits a jugadores según su progreso en el Poset $\le_M$. Un jugador $p$ colisiona (no puede atravesar) la compuerta de la Zona $z_k$ si y solo si $(p, m_k) \notin Access$. Si $(p, m_k) \in Access$, la intersección de su máscara con la barrera de la compuerta se vuelve vacía ($L_p \cap M_{\text{Gate}_k} = \emptyset$), permitiéndole cruzar fluidamente mientras bloquea a los demás.
  - **Criterio de Aceptación (Test):** Validar en `eval_server_runtime` que al actualizar el nivel de un jugador a `Prog(p, m_1) = 5`, su grupo/máscara permita atravesar la compuerta de `Zone_1` a `Zone_2`.

- [x] **Paso 2.2: Construcción Procedural en Roblox Studio de los 5 Recintos y Cabinas (Vía StudioMCP)**
  - **Herramientas MCP:** `generate_procedural_model`, `inspect_instance`, `search_game_tree`.
  - **Conjuntos y Relaciones:** Grafo de escena (*Scene Graph*) estructurado como Orden Parcial (Poset) dentro de `Workspace.World`:
    * `Workspace.World.Zones.Zone_1` hasta `Zone_5` (dispuestos en progresión lineal o coliseo escalonado, separados por compuertas `Gate_1_2`, `Gate_2_3`, `Gate_3_4`, `Gate_4_5`).
    * En cada `Zone_k`: crear `SpawnLocations`, plataforma circular de captura `CapturePad_k` (con indicador visual de progreso), y la estructura física `Machine_k` con cabina aislada de cristal blindado (`ArmoredGlass`), puerta corrediza, letrero `StatusSign` (`SurfaceGui` mostrando "DISPONIBLE" en verde u "OCUPADO + Nickname" en rojo) y un `MinigameChamber_k` aislado bajo el mapa para teletransporte o cámara fija.
  - **Criterio de Aceptación (Test):** Inspeccionar vía `search_game_tree` que las 5 zonas, 4 compuertas intermedias, 5 plataformas y 5 cabinas existan con sus `Attributes` (`MachineId`, `ZoneId`) correctamente asignados.

- [x] **Paso 2.3: Autómata de Partición de Estados del Jugador (`src/server/PlayerStateService.luau`)**
  - **Archivos:** `src/server/PlayerStateService.luau`.
  - **Conjuntos y Relaciones:** Partición estricta del conjunto de jugadores activos:
    $$P = S_{\text{Combat}} \sqcup S_{\text{Capturing}} \sqcup S_{\text{Playing}} \sqcup S_{\text{Immunity}} \sqcup S_{\text{Dead}}$$
    Toda transición de estado de un jugador $p$ debe ejecutar `SetUtils.Difference` en el conjunto origen y `SetUtils.Union` en el conjunto destino de forma atómica, verificando la invariante `SetUtils.VerifyPartition`.
    * Al entrar a $S_{\text{Playing}}$: se instancia un `ForceField`, se desequipo cualquier `Tool` de combate y se aísla al jugador en la cabina.
    * Al salir de $S_{\text{Playing}}$ (por victoria, derrota o *timeout* de 45-60s): el jugador pasa obligatoriamente a $S_{\text{Immunity}}$ durante exactamente **10 segundos** (con efecto visual semitransparente/escudo) antes de regresar a $S_{\text{Combat}}$.
  - **Criterio de Aceptación (Test):** Simular en `eval_server_runtime` el ciclo completo `Combat -> Capturing -> Playing -> Immunity -> Combat` y comprobar que `VerifyPartition` devuelva `true` en cada paso.

- [x] **Paso 2.4: Motor de Exclusión Mutua y Captura de Máquinas (`src/server/MachineManager.luau`)**
  - **Archivos:** `src/server/MachineManager.luau`.
  - **Conjuntos y Relaciones:** Función parcial inyectiva $Occ: M \rightharpoonup P$.
    * **Invariante 1:** $\forall m \in M, \vert{}\{p \in P \mid Occ(m) = p\}\vert{} \le 1$.
    * **Invariante 2:** $\forall p \in P, \vert{}\{m \in M \mid Occ(m) = p\}\vert{} \le 1$.
    * **Mecánica de Disputa ("Rey de la Colina" + ProximityPrompt):** Un jugador reclama la máquina $m_k$ manteniéndose sobre `CapturePad_k` durante **3 segundos continuos sin recibir daño** (si recibe daño o entra otro rival a disputar, el temporizador se pausa/reinicia) o activando el `ProximityPrompt` si no hay rivales en un radio de 15 studs.
    * **Límite de Tiempo Estricto:** Al asignarse $Occ(m_k) = p$, inicia un temporizador autoritativo en el servidor de $T_{\max} \in [45\text{s}, 60\text{s}]$ según la dificultad. Si el tiempo expira sin respuesta del cliente, el servidor ejecuta $Occ(m_k) = \emptyset$, abre la cabina y expulsa al jugador a $S_{\text{Immunity}}$.
    * **Seguridad de Desconexión:** En `Players.PlayerRemoving`, si $\exists m \in M$ tal que $Occ(m) = p$, liberar inmediatamente $Occ(m) = \emptyset$.
  - **Criterio de Aceptación (Test):** Ejecutar un test concurrente en `eval_server_runtime` donde 3 jugadores simulados soliciten ocupar $m_1$ en el mismo fotograma (`task.spawn`); verificar que exactamente 1 lo logre y los otros 2 reciban rechazo.

- [x] **Paso 2.5: Servicio de Progresión en el Poset y Control de Fronteras (`src/server/ProgressionService.luau`)**
  - **Archivos:** `src/server/ProgressionService.luau`.
  - **Conjuntos y Relaciones:** Orden parcial $m_1 \le_M m_2 \le_M m_3 \le_M m_4 \le_M m_5$ y función $Prog: P \times M \to \{0, 1, 2, 3, 4, 5\}$. Relación de acceso:
    $$(p, m_k) \in Access \iff (k = 1) \lor (k > 1 \land Prog(p, m_{k-1}) = 5)$$
    Al superar la dificultad $d$ en $m_k$, si $d = Prog(p, m_k) + 1$, se actualiza $Prog'(p, m_k) = d$. Si alcanza $5$, se desbloquea el acceso a la Zona $z_{k+1}$ y Máquina $m_{k+1}$.
  - **Criterio de Aceptación (Test):** Validar en runtime que un jugador con `Prog(p, 1) = 4` no pueda activar $m_2$ ni cruzar `Gate_1_2`, pero al subir a `Prog(p, 1) = 5` ambos permisos den `true`.

---

## FASE 3: FÁBRICA LOCAL DE ASSETS 3D/2D Y MATRICES DE LOS 25 NIVELES (RX 9070 XT)

- [x] **Paso 3.1: Generación e Integración de Mallas 3D de Máquinas y Armas (Cube 3D / Procedural MCP)**
  - **Nodo Ejecutor:** PC Windows (RX 9070 XT con Cube 3D / StudioMCP).
  - **Conjuntos y Relaciones:** Construcción de los modelos 3D para las 5 máquinas temáticas (`MachineModel_1` a `5`) y las 9 armas desbloqueables (`WoodBat`, `Knife`, `Slingshot`, `ShortSword`, `BasicPistol`, `Katana`, `Shotgun`, `HeavyHammer`, `PlasmaRifle`) almacenadas en `ReplicatedStorage.Assets.Weapons`. Cada arma es un Poset jerárquico con un `Handle`, `Hitbox` o `MuzzlePoint` y animaciones/efectos visuales.
  - **Criterio de Aceptación (Test):** Verificar mediante `inspect_instance` que las 9 herramientas (`Tool`) existan en `ReplicatedStorage.Assets.Weapons` con su `PrimaryPart` y `Handle` configurados sin piezas sueltas (`Anchored = false`, `Massless = true` en partes secundarias).

- [x] **Paso 3.2: Generación de Texturas PBR e Íconos 2D en ComfyUI (RX 9070 XT)**
  - **Nodo Ejecutor:** ComfyUI local (`127.0.0.1:8188`).
  - **Implementación:** Generar íconos 2D para las 10 armas, insignias de los 5 niveles de dificultad y texturas de neón para las pantallas de las máquinas arcade. Integrarlos o crear un sistema de *fallback* vectorial limpio en `ScreenGui` si un asset externo aún no tiene ID de nube.
  - **Criterio de Aceptación (Test):** Comprobar en cliente que ningún componente de UI muestre texturas rotas o en blanco.

- [x] **Paso 3.3: Matriz Matemática de los 25 Niveles $L = M \times D$ (`src/shared/Config/MinigameLevelsData.luau`)**
  - **Nodo Ejecutor:** Ollama Qwen Coder (`127.0.0.1:11434`) + validación en Windows.
  - **Conjuntos y Relaciones:** Producto cartesiano $L = M \times D$ ($\vert{}L\vert{} = 25$ configuraciones). Debe cumplir estrictamente la **Función Monótona Creciente de Complejidad** $\Phi(m_i, d_a) < \Phi(m_i, d_b)$ para todo $d_a < d_b$, y definir el **Tiempo Mínimo Físicamente Posible** ($T_{\min}(m_i, d_j)$) que usará el servidor para detectar *speedhacks* o respuestas falsas de clientes con exploits.
  - **Criterio de Aceptación (Test):** Script de prueba en `eval_server_runtime` que recorra $m \in \{1..5\}$ y verifique matemáticamente que $\Phi(m, 1) < \Phi(m, 2) < \Phi(m, 3) < \Phi(m, 4) < \Phi(m, 5)$ y $0 < T_{\min}(m, d) < T_{\max}(m, d) \le 60$.

---

## FASE 4: SISTEMA DE COMBATE PVP, CLASES DE EQUIVALENCIA Y REGLA ANTI-ABUSO

- [x] **Paso 4.1: Relación de Equivalencia de Zona ($\sim_Z$) y Relación `CanDamage` (`src/server/CombatSystem.luau`)**
  - **Archivos:** `src/server/CombatSystem.luau`, `src/client/WeaponController.luau`.
  - **Conjuntos y Relaciones:**
    * Relación de equivalencia espacial: $p_1 \sim_Z p_2 \iff Loc_P(p_1) = Loc_P(p_2)$ (reflexiva, simétrica y transitiva; particiona a los jugadores en 5 clases de equivalencia disjuntas $P / \sim_Z$ correspondientes a las 5 zonas).
    * Relación binaria de daño permitido $CanDamage \subseteq P \times P$:
      $$(p_1, p_2) \in CanDamage \iff (p_1 \neq p_2) \land (p_1 \sim_Z p_2) \land (p_1 \in S_{\text{Combat}} \cup S_{\text{Capturing}}) \land (p_2 \in S_{\text{Combat}} \cup S_{\text{Capturing}})$$
      *(Nota crítica: Si $p_2 \in S_{\text{Playing}} \cup S_{\text{Immunity}} \cup S_{\text{Dead}}$, entonces $(p_1, p_2) \notin CanDamage$, garantizando inmunidad absoluta dentro de la máquina y en los 10s posteriores)*.
    * Implementar detección de impacto por *OverlapParams* espaciales para armas cuerpo a cuerpo y *RaycastParams* autoritativo en el servidor para armas a distancia (resortera, pistola, escopeta, rifle de plasma), con empuje (*knockback*) para sacar a rivales de la plataforma `CapturePad`.
  - **Criterio de Aceptación (Test):** En `eval_server_runtime`, probar que `CanPlayerDamage(p1, p2)` devuelva `false` si están en zonas distintas, `false` si `p2` está en `Playing` o `Immunity`, y `true` únicamente cuando ambos están en la misma zona y en estado de combate.

- [x] **Paso 4.2: Subconjuntos de Equipamiento y Escalado Anti-Abuso al Retroceder de Zona (`src/server/InventoryService.luau`)**
  - **Archivos:** `src/server/InventoryService.luau`.
  - **Conjuntos y Relaciones:**
    * Un jugador $p$ posee un inventario $Inv(p) \subseteq W$. Al ganar $(m_i, d_j)$, se aplica unión idempotente: $Inv'(p) = Inv(p) \cup \{Rew(m_i, d_j)\}$.
    * Prerrequisito de equipamiento: $p$ puede equipar $w \in W \iff R_w \subseteq H_p$ (donde $H_p$ es el conjunto de niveles $(m, d)$ superados por $p$).
    * **Regla Anti-Abuso (Noob-Stomping Prevention):** Sea $z_k = Loc_P(p)$ la zona actual del jugador. Si el jugador retrocede a una zona inferior donde $\text{tier}(w) > k$, el servidor aplica automáticamente dos medidas:
      1. Desequipa las armas con $\text{tier}(w) > k$ y equipa la mejor arma de su inventario tal que $\text{tier}(w') \le k$.
      2. En `CombatSystem`, acota cualquier cálculo de daño mediante $\text{Damage}_{\text{final}} = \min(\text{Damage}(w), \text{MaxZoneDamage}(z_k))$.
  - **Criterio de Aceptación (Test):** Simular en `eval_server_runtime` un jugador con el Rifle de Plasma (Zona 5) entrando a la Zona 1 (Novatos) y verificar que su arma activa cambie automáticamente al Bate de Madera (Zona 1) y su daño nunca exceda el tope de la Zona 1.

---

## FASE 5: PROGRAMACIÓN INDIVIDUAL DE LOS 5 MINIJUEGOS (CLIENTE + VALIDACIÓN SERVIDOR)

- [x] **Paso 5.1: Máquina 1 — *Reflex / Quick Time Event (QTE)* (`src/client/Minigames/M1_ReflexQTE.luau`)**
  - **Archivos:** `src/client/Minigames/M1_ReflexQTE.luau`, validador en `src/server/MinigameValidators.luau`.
  - **Conjuntos y Relaciones:** Alfabeto de entrada $\Sigma = \{\text{W, A, S, D, E, Q, Space}\}$ (con botones táctiles en pantalla para soporte universal). Secuencia objetivo como función $S_{\text{target}}: \{1, \dots, N_d\} \to \Sigma$, donde $N_1 = 4$ teclas lentas y $N_5 = 12$ teclas rápidas con estímulos distractores (trampas visuales en rojo que NO deben presionarse). Victoria si $\forall i \in \{1..N_d\}, S_{\text{input}}(i) = S_{\text{target}}(i)$ dentro de la ventana $\Delta t_d$. El servidor genera la semilla/secuencia al iniciar y valida que el tiempo total sea $\ge T_{\min}(1, d)$.
  - **Criterio de Aceptación (Test):** Prueba automatizada en `solo_playtest` superando la dificultad 1 y fallando a propósito en una trampa visual en dificultad 5, verificando logs limpios.

- [x] **Paso 5.2: Máquina 2 — *Micro-Parkour (Laser Grid)* (`src/client/Minigames/M2_LaserGrid.luau`)**
  - **Archivos:** `src/client/Minigames/M2_LaserGrid.luau`.
  - **Conjuntos y Relaciones:** Dentro de la cámara física `MinigameChamber_2`, el jugador debe cruzar un corredor con haces láser móviles $V_{\text{laser}}(t)$ y plataformas que desaparecen periódicamente en dificultades altas ($d \ge 4$). El jugador gana si su caja de colisión $B_p(t)$ toca la meta $V_{\text{goal}}$ manteniendo en todo momento $B_p(t) \cap V_{\text{laser}}(t) = \emptyset$. Si la intersección no es vacía, pierde el intento inmediatamente y es expulsado de la máquina.
  - **Criterio de Aceptación (Test):** Simular en `solo_playtest` el cruce del corredor en dificultad 1 y comprobar que tocar un láser aborte la partida y active los 10s de inmunidad exterior.

- [x] **Paso 5.3: Máquina 3 — *Target Practice (Galería de Tiro)* (`src/client/Minigames/M3_TargetPractice.luau`)**
  - **Archivos:** `src/client/Minigames/M3_TargetPractice.luau`.
  - **Conjuntos y Relaciones:** Cámara acoplada en primera persona frente al monitor 3D/Viewport de la Máquina 3. Conjunto dinámico de dianas emergentes $T_{\text{active}}(t) = \{t_1, \dots, t_m\}$ y dianas de penalización $T_{\text{penalty}}(t)$. Cada clic proyecta un rayo $r$. Si existe intersección dirigida $Hit(r, t_i)$ con $t_i \in T_{\text{active}}$, se aplica diferencia de conjuntos $T_{\text{active}}' = T_{\text{active}} \setminus \{t_i\}$ y suma puntos. Si $Hit(r) = \emptyset$ (disparo fallado) o impacta $T_{\text{penalty}}$ en dificultades altas, resta tiempo/puntos.
  - **Criterio de Aceptación (Test):** Verificar en `solo_playtest` la transición de cámara al monitor, eliminación de dianas por diferencia de conjuntos y penalización por fallo en dificultad 5.

- [x] **Paso 5.4: Máquina 4 — *Memory Matrix (Secuencia 4x4)* (`src/client/Minigames/M4_MemoryMatrix.luau`)**
  - **Archivos:** `src/client/Minigames/M4_MemoryMatrix.luau`.
  - **Conjuntos y Relaciones:** Cuadrícula en el suelo de la cabina modelada como el producto cartesiano $G = \{1, 2, 3, 4\} \times \{1, 2, 3, 4\}$ ($\vert{}G\vert{} = 16$ paneles luminosos). El servidor genera un camino dirigido (relación ordenada de pasos) $P_{\text{seq}} = \langle g_1, g_2, \dots, g_{L_d} \rangle$ con $g_i \in G$ y longitud $L_1 = 4$ hasta $L_5 = 9$. Fase 1: los paneles se iluminan secuencialmente. Fase 2: el jugador debe pisar o seleccionar los paneles en el orden exacto antes de que expire el cronómetro.
  - **Criterio de Aceptación (Test):** Prueba en `solo_playtest` validando que pisar el panel correcto avance el índice $i \to i+1$ y pisar un par $(x, y) \neq g_i$ termine el intento en derrota.

- [x] **Paso 5.5: Máquina 5 — *Bullet Hell (Supervivencia de Proyectiles)* (`src/client/Minigames/M5_BulletHell.luau`)**
  - **Archivos:** `src/client/Minigames/M5_BulletHell.luau`.
  - **Conjuntos y Relaciones:** Arena circular cerrada de radio $R$ vista desde cámara cenital/isométrica. Conjunto dinámico de proyectiles (orbes de energía y cuchillas que rebotan en la circunferencia) $B(t) = \{b_1, \dots, b_k\}$.
    * *Dificultad 1:* $\vert{}B(t)\vert{} = 3$ proyectiles lentos con rebote lineal durante $20\text{s}$.
    * *Dificultad 5:* Tormenta de proyectiles con patrones helicoidales y radiales durante $40\text{s}$.
    * **Condición de Supervivencia:** En cada fotograma $\Delta t$, el conjunto de colisiones métricas debe ser vacío: $\{b \in B(t) \mid \Vert{}\vec{x}_p(t) - \vec{x}_b(t)\Vert{} \le r_p + r_b\} = \emptyset$. Si sobrevive todo el intervalo $T_d$, gana el arma definitiva de la Cumbre.
  - **Criterio de Aceptación (Test):** Ejecutar prueba en `solo_playtest` verificando las ecuaciones paramétricas helicoidales de los proyectiles y que la colisión métrica detecte impactos con precisión milimétrica.

---

## FASE 6: PERSISTENCIA DE DATOS E INTERFAZ DE USUARIO REACTIVA (HUD)

- [x] **Paso 6.1: Persistencia Confiable con `DataStoreService` / `ProfileStore` (`src/server/DataService.luau`)**
  - **Archivos:** `src/server/DataService.luau`.
  - **Conjuntos y Relaciones:** Función de serialización biyectiva que transforma la matriz de progreso $Prog(p, \cdot)$ y el conjunto de inventario $Inv(p) \subseteq W$ en una estructura JSON segura para `DataStoreService` (con soporte de modo *Mock/Studio* si las APIs de nube están desactivadas localmente). Al reconectar, restaura el estado de conjuntos, desbloquea las compuertas de zona correspondientes en `CollisionManager` y entrega las armas desbloqueadas.
  - **Criterio de Aceptación (Test):** Simular guardado y recarga de perfil en `eval_server_runtime` comprobando que $Inv_{\text{loaded}}(p) = Inv_{\text{saved}}(p)$ y $Prog_{\text{loaded}}(p) = Prog_{\text{saved}}(p)$.

- [x] **Paso 6.2: Interfaz Reactiva Completa (`ScreenGui`, Selector de Dificultad, HUD de Estado e Inventario)**
  - **Archivos:** `src/client/UI/UIManager.luau`, `src/client/UI/MachineHUD.luau`, `src/client/UI/ProgressTracker.luau`.
  - **Implementación:**
    1. Barra superior con la Zona actual ($z_1..z_5$), el Estado del jugador (`Combat`, `Capturing`, `Playing`, `Immunity` con cuenta regresiva de 10s) y el progreso de la máquina actual ($0/5$ estrellas).
    2. Barra de captura circular en pantalla cuando el jugador está sobre `CapturePad_k` (0.0s a 3.0s).
    3. Al entrar a la máquina $m_k$, selector rápido de dificultad $d \in \{1..5\}$ (mostrando desbloqueadas hasta $\min(Prog(p, m_k) + 1, 5)$) y cronómetro gigante de 45-60s.
    4. Notificaciones animadas al desbloquear una nueva arma o abrir la compuerta a la siguiente zona.
  - **Criterio de Aceptación (Test):** Lanzar `solo_playtest`, verificar que todos los contenedores `ScreenGui` tengan `ResetOnSpawn = false` y comprobar en `get_runtime_logs` 0 errores de interfaz.

---

## FASE 7: AUDITORÍA MULTIJUGADOR, STRESS-TEST Y PULIDO FINAL

- [x] **Paso 7.1: Simulación Multijugador de Disputa y Exclusión Mutua (`multiplayer_playtest`)**
  - **Herramientas MCP:** `multiplayer_playtest`, `eval_server_runtime`, `eval_client_runtime`, `get_runtime_logs`.
  - **Pruebas Empíricas de Conjuntos:**
    1. Lanzar de 2 a 4 clientes simulados.
    2. Hacer que Cliente 1 y Cliente 2 peleen en `CapturePad_1`; verificar que recibir daño reinicie el contador de 3 segundos de captura.
    3. Cuando Cliente 1 entra a `Machine_1` ($Occ(m_1) = p_1$), hacer que Cliente 2 lo ataque con todas las armas y trate de activar la máquina; confirmar que Cliente 1 no recibe daño ($(p_2, p_1) \notin CanDamage$) y `Machine_1` rechaza a Cliente 2.
  - **Criterio de Aceptación (Test):** 0 violaciones de invariantes en el servidor y `get_runtime_logs` completamente libre de errores rojos.

- [x] **Paso 7.2: Prueba de Recorrido Completo (Zona 1 a Zona 5) y Regla Anti-Abuso**
  - **Pruebas Empíricas:** Simular la victoria secuencial de un jugador desde $(m_1, 1)$ hasta $(m_5, 5)$, comprobando el cruce físico por las 4 compuertas intermedias y el otorgamiento de las 10 armas. Luego, teletransportar al jugador de regreso a la Zona 1 y verificar que el servidor reemplace o limite automáticamente su arma de Zona 5.
  - **Criterio de Aceptación (Test):** Confirmación automatizada de todas las aserciones (`assert`) en el servidor.

- [x] **Paso 7.3: Prueba de Desconexión Abrupta, Fugas de Memoria y Clausura Transitiva**
  - **Pruebas Empíricas:** Forzar la desconexión o muerte de un jugador mientras está dentro de una máquina ($p \in S_{\text{Playing}}$). Verificar que la máquina vuelva a estado `Available` ($Occ(m) = \emptyset$), las luces de "OCUPADO" pasen a verde ("DISPONIBLE") y todas las conexiones `RBXScriptConnection` del minijuego se limpien (`Disconnect()` / `Janitor` / `Maid`).
  - **Criterio de Aceptación (Test):** 0 máquinas bloqueadas permanentemente (*deadlocks*) tras desconexión.

- [x] **Paso 7.4: Auditoría Final de Calidad y Generación de `PROYECTO_COMPLETADO.md`**
  - **Implementación:** Ejecutar `luau-lsp --strict` y `selene` en todo el repositorio `src/`. Redactar `PROYECTO_COMPLETADO.md` con el resumen de arquitectura, la tabla de pruebas superadas de cada conjunto/relación y las instrucciones para publicar en Roblox.
  - **Criterio de Aceptación (Test):** Todas las casillas anteriores marcadas con `[x]` y commit final limpio en Git.
---

## FASE 8: REMODELACIÓN ARQUITECTÓNICA 3D, CIERRE TOPOLÓGICO Y CÁMARAS DE MINIJUEGO

- [x] **Paso 8.1: Cierre Hermético de las 5 Zonas (Clausura Topológica Espacial)**
  - **Problema actual:** Las 5 zonas son plataformas abiertas sobre el Baseplate; un jugador puede saltar por los lados y rodear las compuertas `Gate_1_2` a `Gate_4_5`.
  - **Implementación obligatoria:**
    1. Eliminar o desactivar el acceso libre al `Baseplate` exterior alrededor de las arenas.
    2. Construir para cada `Zone_k` ($k \in \{1..5\}$) un recinto completamente cerrado tipo Coliseo/Arena Cyberpunk (de al menos `80x80` studs por zona) con **muros laterales sólidos de 30 studs de altura**, pilares con tiras de neón del color temático de cada zona (Zona 1: Azul, Zona 2: Verde, Zona 3: Amarillo, Zona 4: Naranja, Zona 5: Rojo/Morado) y un techo o barrera invisible superior (`InvisibleRoof`) para que nadie pueda saltar por encima.
    3. Las compuertas `Gate_k` deben cubrir de pared a pared y del suelo al techo el pasillo conector entre `Zone_k` y `Zone_{k+1}`, garantizando geométricamente que el único camino entre $z_k$ y $z_{k+1}$ sea atravesar la compuerta controlada por `CollisionManager`.
  - **Criterio de Aceptación (Test):** Verificar vía script en `eval_server_runtime` con *Raycasts* y cajas envolventes que cada zona tenga 4 paredes + techo cerrados sin huecos laterales.

- [x] **Paso 8.2: Rediseño Detallado de las 5 Máquinas Arcade y Plataformas de Captura**
  - **Problema actual:** Las máquinas son simples cubos transparentes vacíos con un bloque negro arriba y dos cuadros cian sin texto.
  - **Implementación obligatoria:**
    1. En cada zona debe haber **una sola Plataforma de Captura circular (`CapturePad_k`)** en el centro frente a la máquina, compuesta por un cilindro metálico base, un anillo de neón y un `BillboardGui` flotante que diga `"ZONA DE CAPTURA - MANTENTE 3s SIN DAÑO"` y muestre el progreso `0.0s / 3.0s`.
    2. Reconstruir cada `Machine_k` como una **Cabina Arcade de Alta Tecnología** (mínimo 15 piezas por máquina): base escalonada con bordes de neón, columnas metálicas en las 4 esquinas, paredes de cristal blindado con textura/transparencia, puerta frontal corrediza real, consola arcade interior con pantalla luminosa (`Screen`), palanca/botones y un `SurfaceGui` frontal grande y legible con el nombre del minijuego (`M1: REFLEX QTE`, `M2: LASER GRID`, etc.), el estado (`DISPONIBLE` en verde / `OCUPADO POR [Jugador]` en rojo) y las 5 estrellas de dificultad.
  - **Criterio de Aceptación (Test):** Inspeccionar el árbol de `Workspace` verificando que cada máquina tenga al menos 15 partes ensambladas y textos `SurfaceGui` y `BillboardGui` activos.

- [x] **Paso 8.3: Construcción de las 5 Salas Físicas de Minijuego (`MinigameChambers`)**
  - **Problema actual:** El cubo de cristal es demasiado pequeño para correr el parkour de láseres, la matriz 4x4 o el Bullet Hell.
  - **Implementación obligatoria:** Construir bajo el mapa (o a 500 studs de altura/distancia, completamente cerradas e iluminadas) 5 salas dedicadas (`MinigameChamber_1` a `5`) adonde el personaje es teletransportado al entrar en $S_{\text{Playing}}$ y devuelto a la puerta de la máquina al salir con sus 10s de $S_{\text{Immunity}}$:
    1. `Chamber_1 (QTE)`: Cabina envolvente con pantallas gigantes de neón que cambian de color al acertar o fallar teclas.
    2. `Chamber_2 (Laser Grid)`: Corredor físico de `20x80` studs con foso inferior, plataformas móviles/intermitentes, vigas láser rojas animadas (`V_laser(t)`) y un pad verde brillante de meta (`V_goal`) al final.
    3. `Chamber_3 (Target Practice)`: Galería de tiro de `40x60` studs con mostrador para el jugador y rieles al fondo donde emergen y se mueven físicamente las dianas 3D (`T_active` verdes y `T_penalty` rojas).
    4. `Chamber_4 (Memory Matrix)`: Sala con una cuadrícula física real de `4x4` (16 plataformas cuadradas de `6x6` studs separadas por ranuras) en el suelo que se iluminan en secuencia y detectan las pisadas del jugador.
    5. `Chamber_5 (Bullet Hell)`: Coliseo circular cerrado de `50` studs de diámetro con paredes de energía donde rebotan físicamente los orbes y cuchillas giratorias (`B(t)`).
  - **Criterio de Aceptación (Test):** Probar en `solo_playtest` el teletransporte de ida y vuelta a cada una de las 5 cámaras y verificar que contengan sus objetos interactivos reales.

- [x] **Paso 8.4: Ensamblaje de Modelos 3D de las 10 Armas y Limpieza de Piezas Sueltas**
  - **Problema actual:** Hay bloques blancos sueltos junto al Spawn de la Zona 1 y las armas necesitan geometría reconocible.
  - **Implementación obligatoria:**
    1. Eliminar cualquier bloque de prueba suelto en la Zona 1.
    2. Generar modelos multi-parte reconocibles (usando `Part`, `WedgePart`, `Cylinder`, `SpecialMesh` y efectos `Trail`/`ParticleEmitter`) para las 10 armas en `ReplicatedStorage.Assets.Weapons` (Bate de madera, Cuchillo, Resortera, Espada corta, Pistola, Katana, Escopeta, Martillo pesado, Rifle de plasma), asegurándose de que todas estén soldadas con `WeldConstraint` al `Handle` y tengan `Anchored = false`.
  - **Criterio de Aceptación (Test):** Equipar las 10 armas en un personaje de prueba durante `solo_playtest` y verificar que se sostengan en la mano derecha sin caerse al suelo ni teletransportar al jugador.