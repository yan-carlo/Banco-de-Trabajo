# Optimizacion.md — Protocolo de Revisión Pre-Venta para Scripts FiveM

Cuando te pidan revisar y preparar un script FiveM para poner en venta, sigue este protocolo en orden. No saltes pasos. No declares el script listo hasta completar todos.

---

## FASE 1 — LECTURA TOTAL DEL CÓDIGO

Antes de cambiar **una sola línea**, lee cada archivo en este orden:

1. `fxmanifest.lua` — dependencias, orden de carga, scripts declarados
2. `config/config.lua` — todos los valores configurables, función `_U`
3. `locales/*.lua` — claves disponibles
4. `sql/install.sql` — estructura de la tabla
5. `server/main.lua` — lógica de servidor, eventos, helpers
6. `server/callbacks.lua` — callbacks registrados
7. `client/main.lua` — threads, eventos cliente, flujos de UI
8. Cualquier archivo adicional (`vehicle_utils.lua`, etc.)

**Objetivo:** entender qué hace cada función, qué recibe y qué devuelve. No asumir — leer.

---

## FASE 2 — CHECKLIST DE SEGURIDAD (servidor)

Revisar cada evento de servidor. Para cada uno verificar:

```
□ ¿Primera línea captura `local source = source`?
□ ¿Hay cooldown con CheckCooldown antes de cualquier lógica?
□ ¿Se valida que el jugador existe en el framework antes de usarlo?
□ ¿Todos los datos del cliente tienen validación de tipo Y rango?
□ ¿Las queries SQL usan parámetros (?) — nunca concatenación de strings?
□ ¿Hay optimistic lock en BD para operaciones críticas (compra, transferencia)?
□ ¿Se verifica en BD el estado del recurso, no solo lo que envía el cliente?
```

Si algún punto falla → corregir antes de continuar.

---

## FASE 3 — CHECKLIST DE OPTIMIZACIÓN (cliente)

```
□ ¿Hay algún Wait(0) fuera del bloque "jugador cerca"? → Moverlo o eliminarlo
□ ¿Se usa GetDistanceBetweenCoords en algún hilo? → Reemplazar con #(v1 - v2)
□ ¿Se llama PlayerPedId() o GetEntityCoords() en cada frame? → Cachear en thread separado
□ ¿Hay un solo thread mezclando proximidad + render + lógica? → Separar en 3 threads
□ ¿El Wait lejos es dinámico (PollingInterval) y no fijo en 0 o 1? → Verificar
□ ¿GetGamePool / GetVehiclePool se llaman en loop? → Revisar frecuencia
□ ¿Se envía TriggerClientEvent(-1, ...) cuando solo un jugador lo necesita? → Enviar por source
```

**Patrón correcto de threads (si el script usa proximidad):**

```lua
-- Thread 1: caché de posición (500ms)
-- Thread 2: proximidad → ajusta isNear (PollingInterval / 500ms)
-- Thread 3: render/interacción → Wait(0) SOLO si isNear == true
```

---

## FASE 4 — CHECKLIST DE CALIDAD DE CÓDIGO

```
□ ¿Hay strings hardcodeados fuera de locales/? → Mover a locales
□ ¿Hay valores de configuración enterrados en el código? → Mover a config.lua
□ ¿Hay funciones de más de 30 líneas? → Extraer sub-funciones
□ ¿Hay anidación de más de 3 niveles de if? → Reescribir con guard clauses
□ ¿Los comentarios explican el PORQUÉ (no el qué)? → Eliminar comentarios obvios
□ ¿Las funciones que usan exports externos tienen pcall + GetResourceState? → Verificar
□ ¿La función _U() está en config.lua y se usa en todo el código? → Confirmar
□ ¿El fxmanifest.lua declara todos los archivos reales que existen? → Verificar
```

---

## FASE 5 — CHECKLIST DE BASE DE DATOS

```
□ ¿install.sql tiene DROP TABLE IF EXISTS antes del CREATE? → Requerido
□ ¿Las columnas tienen tipos apropiados (no TEXT donde cabe VARCHAR)? → Revisar
□ ¿Hay índices en las columnas que aparecen en WHERE con frecuencia? → Agregar si falta
□ ¿Hay UNIQUE KEY que pueda romperse en casos de uso reales? → Analizar
□ ¿Las queries de UPDATE verifican affected rows para detectar race conditions? → Revisar
□ ¿Se usa MySQL.query.await correctamente (result y result[1])? → Verificar nil checks
```

---

## FASE 6 — CHECKLIST DE COMPATIBILIDAD

```
□ ¿El script detecta ESX/QBCore automáticamente sin hardcodear uno? → Verificar
□ ¿Los helpers GetPlayer, GetIdentifier, GetBankMoney, GetJob cubren ambos frameworks? → Confirmar
□ ¿Los plugins (target, inventario, menú) se usan a través de wrappers? → Verificar
□ ¿Config.Framework / Config.TargetSystem / Config.InventorySystem existen en config.lua? → Confirmar
□ ¿Las dependencias opcionales NO están en dependencies{} del fxmanifest? → Verificar
□ ¿Hay eventos de conexión/desconexión registrados para ambos frameworks? → Revisar
```

---

## FASE 7 — CORRECCIÓN DE ERRORES

**Reglas al corregir:**

1. **Una corrección a la vez** — leer el error completo, localizar la causa raíz
2. **Cambiar solo lo necesario** — no refactorizar ni "limpiar" al mismo tiempo
3. **No eliminar lógica** para suprimir un error — entender por qué falla
4. **Después de cada fix**, volver a revisar las fases 2-6 afectadas

**Casos más comunes:**

| Síntoma | Causa raíz | Fix correcto |
|---|---|---|
| `attempt to index nil value` | Variable puede ser nil en ciertos casos | nil check + return/default |
| Evento se dispara dos veces | Sin cooldown o callback en vuelo | CheckCooldown o flag de bloqueo |
| Compra duplicada | Sin optimistic lock en BD | `UPDATE WHERE status='sale'`, verificar affected |
| Crash al desconectar | No se limpian datos en `playerDropped` | Limpiar cooldowns, transferencias activas |
| Plate no coincide en BD | Espacios trailing en GTA | Sanitizar plate con `plate:gsub('%s+','')` |

---

## FASE 8 — VERIFICACIÓN FINAL

Antes de declarar el script listo para venta:

```
□ Leer install.sql completo una vez más — ¿se puede ejecutar en limpio?
□ Leer fxmanifest.lua — ¿todos los archivos existen y están en orden correcto?
□ Leer config.lua — ¿todo lo que un admin necesitaría cambiar está aquí?
□ Buscar en todo el código: strings en inglés/español fuera de locales/ → ninguno
□ Buscar en todo el código: números mágicos (distancias, precios, tiempos) fuera de config → ninguno
□ Buscar en todo el código: `GetDistanceBetweenCoords` → cero ocurrencias
□ Buscar en todo el código: `Wait(0)` → solo dentro de bloques de render activo
□ Confirmar que locales/en.lua existe con todas las mismas claves que locales/es.lua
```

---

## REGLA DE ORO

> **Entender primero, cambiar después.**
> Un script con menos líneas pero más correcto siempre vale más que uno con más código y bugs silenciosos.
> Si algo no se entiende completamente, seguir leyendo hasta entenderlo — nunca asumir.
