# Plan de Desarrollo — Sistema de Carritos de Hot Dog
**Recurso:** `yt-hotdog`
**Versión objetivo:** 1.0.0
**Frameworks:** ESX / QBCore (detección automática)
**Dependencias:** ox_inventory, ox_target, oxmysql

---

## Índice

1. [Resumen del sistema](#1-resumen-del-sistema)
2. [Estructura de carpetas](#2-estructura-de-carpetas)
3. [Dependencias externas](#3-dependencias-externas)
4. [Diseño de base de datos](#4-diseño-de-base-de-datos)
5. [Configuración](#5-configuración-configconfiglua)
6. [Items y recetas de crafting](#6-items-y-recetas-de-crafting)
7. [Lógica del cliente](#7-lógica-del-cliente-clientmainlua)
8. [Lógica del servidor](#8-lógica-del-servidor-servermainlua)
9. [Localización](#9-localización)
10. [Seguridad y validaciones](#10-seguridad-y-validaciones)
11. [Checklist de implementación](#11-checklist-de-implementación)

---

## 1. Resumen del sistema

El sistema coloca props de carritos de Hot Dog en ubicaciones fijas del mapa. Los jugadores se acercan al carrito, y a través de **ox_target** aparece la opción de interactuar. Al interactuar se abre la **mesa de crafting de ox_inventory**, donde pueden fabricar productos (Hot Dog, Hot Dog con queso, etc.) consumiendo ingredientes de su inventario.

### Flujo de usuario

```
Jugador se acerca al carrito
        │
        ▼
ox_target muestra la opción "Fabricar Hot Dog"
        │
        ▼
Verificación de acceso (job requerido o acceso libre)
        │
        ▼
Se abre la crafting bench de ox_inventory
        │
        ▼
Jugador selecciona receta → consume ingredientes → recibe producto
        │
        ▼
Log de transacción guardado en BD
```

### Características principales

| Feature | Descripción |
|---|---|
| Props del mapa | Carritos de Hot Dog en coordenadas configurables |
| ox_target | Zona de interacción sobre el prop (no radiusZone) |
| Crafting bench | Abre mesa de crafting de ox_inventory por carrito |
| Control de acceso | Por job (lista de trabajos), por grupo (admin, etc.) o libre para todos |
| Blips | Blip en el mapa por cada carrito (configurable on/off) |
| Cooldown | Tiempo entre usos por jugador (anti-spam) |
| Log BD | Registro de cada crafteo con jugador, item, cantidad y timestamp |
| Multi-idioma | Español e inglés incluidos |

---

## 2. Estructura de carpetas

```
yt-hotdog/
├── client/
│   └── main.lua              # Spawneo de props, ox_target, apertura de crafting
├── server/
│   └── main.lua              # Validaciones, callbacks, logs en BD
├── locales/
│   ├── es.lua
│   └── en.lua
├── config/
│   └── config.lua            # Carritos, recetas, permisos, flags
├── sql/
│   └── install.sql           # DROP + CREATE de tablas de logs
├── fxmanifest.lua
└── README.md
```

> No se necesita carpeta `html/` porque ox_inventory provee su propia UI de crafting.

---

## 3. Dependencias externas

| Recurso | Uso | Versión mínima |
|---|---|---|
| `oxmysql` | Consultas a la BD | 2.x |
| `ox_inventory` | Crafting bench + items | 2.x |
| `ox_target` | Zona de interacción en el prop | 3.x |
| `es_extended` | Framework (si usa ESX) | ESX Legacy |
| `qb-core` | Framework (si usa QBCore) | última estable |

### Declaración en `fxmanifest.lua`

```lua
fx_version 'cerulean'
game 'gta5'

name        'yt-hotdog'
description 'Sistema de carritos de Hot Dog con crafting'
version     '1.0.0'
author      'YourTeam'

shared_scripts {
    'config/config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependencies {
    'oxmysql',
    'ox_inventory',
    'ox_target',
}
```

---

## 4. Diseño de base de datos

### `sql/install.sql`

```sql
-- =============================================
-- Recurso: yt-hotdog
-- ADVERTENCIA: elimina y recrea las tablas
-- =============================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `yt_hotdog_logs`;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE IF NOT EXISTS `yt_hotdog_logs` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `player_name`VARCHAR(100) NOT NULL DEFAULT '',
    `item`       VARCHAR(100) NOT NULL,
    `cantidad`   INT(11)      NOT NULL DEFAULT 1,
    `carrito_id` INT(11)      NOT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `identifier` (`identifier`),
    KEY `item` (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 5. Configuración (`config/config.lua`)

```lua
Config = {}

-- Framework: 'auto', 'esx', 'qbcore'
Config.Framework = 'auto'

-- Idioma
Config.Locale = 'es'

-- Debug: solo en desarrollo
Config.Debug = false

-- Tiempo de cooldown entre usos del carrito (ms)
Config.Cooldown = 5000

-- ─── CONTROL DE ACCESO ────────────────────────────────────────
-- Modo de acceso:
--   'all'   → cualquier jugador puede usar los carritos
--   'job'   → solo jugadores con los jobs definidos en Config.AllowedJobs
--   'group' → solo jugadores con los grupos/permisos en Config.AllowedGroups
Config.AccessMode = 'all'

Config.AllowedJobs = {
    'cook',
    'vendor',
}

Config.AllowedGroups = {
    'admin',
    'superadmin',
}

-- ─── BLIPS ────────────────────────────────────────────────────
Config.EnableBlips = true
Config.BlipSprite  = 106   -- Sprite de comida rápida
Config.BlipColor   = 5     -- Amarillo
Config.BlipScale   = 0.8
Config.BlipLabel   = 'Carrito de Hot Dog'

-- ─── DISTANCIA DE INTERACCIÓN ─────────────────────────────────
Config.TargetDistance = 2.0

-- ─── CARRITOS ─────────────────────────────────────────────────
-- Cada entrada define un carrito en el mapa.
-- 'prop'       → modelo del objeto (hash)
-- 'coords'     → vector4 (x, y, z, heading)
-- 'bench'      → nombre de la crafting bench registrada en ox_inventory
-- 'job'        → overrides el Config.AccessMode solo para este carrito (opcional)
Config.Carritos = {
    {
        id     = 1,
        label  = 'Carrito Centro',
        prop   = 'prop_hotdog_01',
        coords = vector4(69.25, -1388.64, 29.37, 180.0),
        bench  = 'hotdog_cart_1',
    },
    {
        id     = 2,
        label  = 'Carrito Aeropuerto',
        prop   = 'prop_hotdog_01',
        coords = vector4(-1027.35, -2731.98, 13.76, 90.0),
        bench  = 'hotdog_cart_2',
    },
    -- Agregar más carritos según se necesite...
}

-- ─── RECETAS ──────────────────────────────────────────────────
-- Las recetas se registran en ox_inventory desde el servidor.
-- Aquí se definen para que el servidor las registre al iniciar.
-- 'name'       → nombre del item resultante (debe existir en ox_inventory items)
-- 'duration'   → tiempo de crafteo en ms
-- 'ingredients'→ tabla de { item = 'nombre', count = cantidad }

Config.Recipes = {
    {
        name       = 'hotdog',
        duration   = 3000,
        ingredients = {
            { item = 'pan_salchicha', count = 1 },
            { item = 'salchicha',     count = 1 },
        },
    },
    {
        name       = 'hotdog_queso',
        duration   = 4000,
        ingredients = {
            { item = 'pan_salchicha', count = 1 },
            { item = 'salchicha',     count = 1 },
            { item = 'queso',         count = 1 },
        },
    },
    {
        name       = 'hotdog_completo',
        duration   = 5000,
        ingredients = {
            { item = 'pan_salchicha', count = 1 },
            { item = 'salchicha',     count = 1 },
            { item = 'queso',         count = 1 },
            { item = 'mostaza',       count = 1 },
            { item = 'ketchup',       count = 1 },
        },
    },
}
```

---

## 6. Items y recetas de crafting

### Items que deben existir en `ox_inventory/data/items.lua`

Los siguientes items deben añadirse al archivo de items de ox_inventory (o en el archivo de items del servidor si se usa un archivo externo):

```lua
-- Ingredientes
['pan_salchicha']   = { label = 'Pan de Salchicha',  weight = 100, stack = true, close = true },
['salchicha']       = { label = 'Salchicha',          weight = 80,  stack = true, close = true },
['queso']           = { label = 'Queso',              weight = 50,  stack = true, close = true },
['mostaza']         = { label = 'Mostaza',            weight = 30,  stack = true, close = true },
['ketchup']         = { label = 'Ketchup',            weight = 30,  stack = true, close = true },

-- Productos finales
['hotdog']          = { label = 'Hot Dog',            weight = 200, stack = true, close = true,
                        consume = 0.3, description = 'Un hot dog sencillo.' },
['hotdog_queso']    = { label = 'Hot Dog con Queso',  weight = 220, stack = true, close = true,
                        consume = 0.4, description = 'Hot dog con queso.' },
['hotdog_completo'] = { label = 'Hot Dog Completo',   weight = 260, stack = true, close = true,
                        consume = 0.5, description = 'Hot dog con todos los ingredientes.' },
```

### Registro de crafting benches en ox_inventory

Las crafting benches deben registrarse en el servidor al iniciar el recurso (ver sección 8).

```lua
-- Ejemplo de registro (se hace dinámicamente desde Config.Carritos)
exports.ox_inventory:RegisterCraft({
    id      = 'hotdog_cart_1',     -- debe coincidir con Config.Carritos[n].bench
    target  = false,               -- no abre con entity target, lo abrimos manualmente
    groups  = {},                  -- vacío = cualquiera; se controla desde nuestro código
    recipes = { ... },             -- se construye desde Config.Recipes
})
```

---

## 7. Lógica del cliente (`client/main.lua`)

### Responsabilidades

1. Detectar framework al iniciar
2. Spawnear los props de carritos en las coordenadas de `Config.Carritos`
3. Registrar un blip por carrito (si `Config.EnableBlips = true`)
4. Registrar zonas de ox_target sobre cada prop
5. Al pulsar la opción del target:
   - Verificar acceso (modo `all`, `job` o `group`)
   - Si tiene acceso → `TriggerServerEvent` para validar server-side y obtener OK
   - Si el servidor responde OK → abrir la crafting bench con `exports.ox_inventory:openCraft(bench)`

### Pseudocódigo del cliente

```lua
-- Al iniciar:
for cada carrito en Config.Carritos do
    spawnar prop en carrito.coords
    si Config.EnableBlips entonces crear blip
    registrar ox_target sobre el prop:
        opción "Fabricar Hot Dog"
        onSelect → TriggerServerEvent('yt-hotdog:servidor:solicitarAcceso', carrito.id)
end

-- Al recibir confirmación del servidor:
RegisterNetEvent('yt-hotdog:cliente:abrirCrafting', function(benchName)
    exports.ox_inventory:openCraft(benchName)
end)
```

### Notas de optimización

- Los props se spawnean una sola vez en `CreateThread` al inicio, no en loops.
- El ox_target maneja la detección de proximidad internamente; no usar loops de distancia propios.
- Los blips se crean una sola vez y no se eliminan mientras el recurso esté activo.

---

## 8. Lógica del servidor (`server/main.lua`)

### Responsabilidades

1. Detectar framework al iniciar
2. Registrar todas las crafting benches de ox_inventory al arrancar
3. Recibir el evento de solicitud de acceso del cliente
4. Validar:
   - El jugador existe en el framework
   - El `carrito_id` es válido (está en Config)
   - Cooldown: el jugador no ha usado el carrito recientemente
   - Permisos: según el `Config.AccessMode` (all / job / group)
5. Si todo OK → `TriggerClientEvent('yt-hotdog:cliente:abrirCrafting', source, benchName)`
6. Registrar en BD el evento (log de apertura o de crafteo)

### Pseudocódigo del servidor

```lua
-- Al iniciar: registrar crafting benches
CreateThread(function()
    Wait(500) -- esperar a que ox_inventory cargue
    for cada carrito en Config.Carritos do
        exports.ox_inventory:RegisterCraft({
            id      = carrito.bench,
            target  = false,
            groups  = {},       -- acceso controlado por nuestro código
            recipes = BuildRecipes(Config.Recipes),
        })
    end
end)

-- Validar acceso
RegisterNetEvent('yt-hotdog:servidor:solicitarAcceso', function(carritoId)
    local source = source

    -- 1. Validar que el carrito existe
    local carrito = GetCarritoById(carritoId)
    if not carrito then return end

    -- 2. Cooldown
    if not CheckCooldown(source, 'carrito_' .. carritoId, Config.Cooldown) then
        TriggerClientEvent('yt-hotdog:cliente:notificar', source, _U('cooldown'))
        return
    end

    -- 3. Validar jugador en framework
    local identifier = GetIdentifier(source)
    if not identifier then return end

    -- 4. Validar permisos
    if not TieneAcceso(source) then
        TriggerClientEvent('yt-hotdog:cliente:notificar', source, _U('no_autorizado'))
        return
    end

    -- 5. OK: abrir crafting en cliente
    TriggerClientEvent('yt-hotdog:cliente:abrirCrafting', source, carrito.bench)
end)
```

### Función `TieneAcceso(source)`

```lua
local function TieneAcceso(source)
    if Config.AccessMode == 'all' then
        return true
    elseif Config.AccessMode == 'job' then
        local job = GetPlayerJob(source)  -- helper ESX/QBCore
        for _, allowedJob in ipairs(Config.AllowedJobs) do
            if job == allowedJob then return true end
        end
        return false
    elseif Config.AccessMode == 'group' then
        -- Usar IsPlayerAceAllowed o el sistema de grupos del framework
        for _, group in ipairs(Config.AllowedGroups) do
            if IsPlayerAceAllowed(source, 'yt-hotdog.' .. group) then
                return true
            end
        end
        return false
    end
    return false
end
```

---

## 9. Localización

### `locales/es.lua`

```lua
Locales = Locales or {}
Locales['es'] = {
    ['no_autorizado']     = 'No tienes permiso para usar este carrito.',
    ['cooldown']          = 'Debes esperar antes de volver a usar el carrito.',
    ['crafting_abierto']  = 'Mesa de fabricación abierta.',
    ['error_generico']    = 'Ha ocurrido un error, inténtalo de nuevo.',
    ['interactuar']       = 'Fabricar Hot Dog',
    ['carrito_label']     = 'Carrito de Hot Dog',
}
```

### `locales/en.lua`

```lua
Locales = Locales or {}
Locales['en'] = {
    ['no_autorizado']     = 'You do not have permission to use this cart.',
    ['cooldown']          = 'You must wait before using the cart again.',
    ['crafting_abierto']  = 'Crafting table opened.',
    ['error_generico']    = 'An error occurred, please try again.',
    ['interactuar']       = 'Craft Hot Dog',
    ['carrito_label']     = 'Hot Dog Cart',
}
```

---

## 10. Seguridad y validaciones

| Punto | Validación |
|---|---|
| `carritoId` recibido del cliente | Verificar que existe en `Config.Carritos` en el servidor |
| Permisos | Siempre validados en servidor, nunca solo en cliente |
| Cooldown | Por `source + carritoId`, guardado en tabla server-side |
| Crafting bench | Registrada server-side con `ox_inventory`; ox_inventory valida los ingredientes internamente |
| Rate limiting | Cooldown de `Config.Cooldown` ms entre solicitudes por jugador |
| Datos SQL | Solo guardar logs con datos validados; usar consultas parametrizadas |

### Datos que el cliente puede enviar al servidor

Solo se envía `carritoId` (número). Nunca el nombre de la bench, nunca el resultado del crafteo. El servidor resuelve todo.

---

## 11. Checklist de implementación

### Fase 1 — Setup base
- [ ] Crear estructura de carpetas `yt-hotdog/`
- [ ] Escribir `fxmanifest.lua`
- [ ] Escribir `sql/install.sql` (DROP + CREATE de `yt_hotdog_logs`)
- [ ] Añadir items a `ox_inventory` (ingredientes + productos)

### Fase 2 — Configuración
- [ ] Escribir `config/config.lua` con carritos, recetas, permisos
- [ ] Escribir `locales/es.lua` y `locales/en.lua`
- [ ] Implementar función `_U()` en config

### Fase 3 — Servidor
- [ ] Detección de framework (ESX/QBCore)
- [ ] Helpers: `GetPlayer`, `GetIdentifier`, `GetPlayerJob`
- [ ] Función `TieneAcceso(source)` con los tres modos
- [ ] Registro de crafting benches al iniciar (`RegisterCraft`)
- [ ] Evento `yt-hotdog:servidor:solicitarAcceso` con todas las validaciones
- [ ] Sistema de cooldown server-side
- [ ] Log a BD (`yt_hotdog_logs`) al abrir crafting

### Fase 4 — Cliente
- [ ] Detección de framework
- [ ] Spawneo de props al iniciar
- [ ] Creación de blips (respetando `Config.EnableBlips`)
- [ ] Registro de ox_target sobre cada prop
- [ ] Evento `yt-hotdog:cliente:abrirCrafting` → `exports.ox_inventory:openCraft`
- [ ] Evento `yt-hotdog:cliente:notificar` para mensajes de error/cooldown

### Fase 5 — Testing
- [ ] Probar con `Config.AccessMode = 'all'`
- [ ] Probar con `Config.AccessMode = 'job'` (con y sin job correcto)
- [ ] Probar con `Config.AccessMode = 'group'`
- [ ] Probar cooldown (usar carrito dos veces seguidas)
- [ ] Probar crafting con ingredientes suficientes
- [ ] Probar crafting sin ingredientes (ox_inventory debe bloquear)
- [ ] Verificar que los logs se guardan en BD
- [ ] Probar con ESX
- [ ] Probar con QBCore
- [ ] Verificar que no hay `Wait(0)` innecesarios (revisar MS de CPU)

---

## Notas adicionales

- **Props disponibles en GTA V** para carritos de comida: `prop_hotdog_01`, `prop_food_bs_hotdog` — verificar cuál tiene mejor aspecto y colisión correcta con ox_target.
- **ox_inventory crafting bench**: `exports.ox_inventory:openCraft(benchName)` abre la UI directamente. No requiere NUI propia.
- **ox_target**: usar `exports.ox_target:addLocalEntity` sobre la entidad del prop spawneado, no `addBoxZone`, para que la zona siga al prop si este se mueve.
- **Sincronización de props**: si en el futuro se quiere que el prop lo vea solo el jugador que inicia sesión o todos, usar `Object.new` con `networked = true` o spawnear en el servidor y sincronizar. Para esta versión, spawnear en el cliente es suficiente ya que los carritos son decoración estática.
