# CLAUDE.md — Guía Oficial para Desarrollo de Scripts FiveM

Este archivo es la **ley del proyecto**. La IA debe seguir cada regla sin excepción al crear, modificar u optimizar cualquier script FiveM de este repositorio.

---

## 1. REGLAS ABSOLUTAS (nunca romper)

| # | Regla |
|---|---|
| 1 | Toda validación de datos va en el **servidor**, nunca en el cliente |
| 2 | Cero strings hardcodeados — todo en `locales/` |
| 3 | Todo configurable en `config/config.lua` — nada enterrado en el código |
| 4 | `Wait(0)` solo cuando el jugador está en rango; siempre dinámico |
| 5 | SQL siempre parametrizado — nunca concatenar strings en queries |
| 6 | Al corregir un bug, tocar **solo** lo necesario — no refactorizar a la vez |
| 7 | Cada plugin (inventario, target, menú) tiene un wrapper; nunca llamada directa |
| 8 | `pcall` + `GetResourceState` antes de usar cualquier export externo |
| 9 | Un `CreateThread` por responsabilidad — nunca mezclar lógica de proximidad con dibujo |
| 10 | Usar `#(v1 - v2)` para distancias, nunca `GetDistanceBetweenCoords` |

---

## 2. ESTRUCTURA OBLIGATORIA DE CARPETAS

```
mi-recurso/
├── client/
│   ├── main.lua          ← Lógica principal del cliente
│   └── ...               ← Archivos adicionales
├── server/
│   ├── main.lua          ← Lógica principal del servidor
│   └── ...
├── locales/
│   ├── es.lua            ← Español (OBLIGATORIO, idioma base)
│   └── en.lua            ← Inglés
├── config/
│   └── config.lua        ← TODA la configuración aquí
├── sql/
│   └── install.sql       ← Siempre DROP + CREATE desde cero
├── fxmanifest.lua
└── README.md
```

> `html/` solo si el script usa NUI. No crear carpetas vacías.

---

## 3. FXMANIFEST.LUA

```lua
fx_version 'cerulean'
game 'gta5'

name        'mi-recurso'
description 'Descripción breve'
version     '1.0.0'
author      'YN Scripts'

shared_scripts {
    '@ox_lib/init.lua',       -- Si usa ox_lib
    'config/config.lua',
    'locales/*.lua',
}

client_scripts { 'client/*.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
```

> No listar dependencias opcionales (qb-target, ox_target, etc.) en `dependencies` — se detectan en runtime.

---

## 4. CONFIG.LUA — CONFIGURABILIDAD TOTAL

**Todo** lo que un administrador podría querer cambiar debe estar en config.lua. Este es el template canónico:

```lua
Config = {}

-- ── Compatibilidad ────────────────────────────────────────────────────────────
Config.Framework       = 'auto'   -- 'auto' | 'esx' | 'qbcore'
Config.UILib           = 'auto'   -- 'auto' | 'oxlib' | 'native'
Config.MenuSystem      = 'auto'   -- 'auto' | 'oxlib' | 'qbmenu'
Config.InventorySystem = 'auto'   -- 'auto' | 'ox_inventory' | 'qb-inventory'
Config.TargetSystem    = 'auto'   -- 'auto' | 'ox_target' | 'qb-target' | 'none'

-- ── General ───────────────────────────────────────────────────────────────────
Config.Locale              = 'es'
Config.Debug               = false
Config.InteractionDistance = 2.5    -- metros para interactuar
Config.PollingInterval     = 1000   -- ms del hilo lejos (mínimo 500)

-- ── Jobs y permisos ───────────────────────────────────────────────────────────
Config.Jobs = {
    ['police']   = { minGrade = 0 },
    ['mechanic'] = { minGrade = 2 },
}

-- ── Blips ────────────────────────────────────────────────────────────────────
Config.Blip = {
    enabled = true,
    sprite  = 1,
    color   = 2,
    scale   = 0.8,
    label   = 'Mi Recurso',
}

-- ── Markers (si no usa target) ────────────────────────────────────────────────
Config.Marker = {
    enabled = true,
    type    = 1,
    size    = vector3(0.5, 0.5, 0.5),
    color   = { r = 255, g = 165, b = 0, a = 180 },
}

-- ── Ubicaciones ───────────────────────────────────────────────────────────────
Config.Locations = {
    {
        label  = 'Punto 1',
        coords = vector4(0.0, 0.0, 0.0, 0.0),
        blip   = true,   -- mostrar blip en este punto
        marker = true,   -- mostrar marker
    },
}

-- ── Items (si usa inventario) ──────────────────────────────────────────────────
Config.Items = {
    requerido  = 'item_name',
    recompensa = 'reward_item',
    cantidad   = 1,
}

-- ── Cooldowns ─────────────────────────────────────────────────────────────────
Config.Cooldowns = {
    accion_principal = 5000,   -- ms
    accion_secundaria = 30000,
}

-- ── Función de traducción (no modificar) ──────────────────────────────────────
function _U(key, ...)
    local locale = Locales and (Locales[Config.Locale] or Locales['es'])
    if not locale then return '[' .. key .. ']' end
    local msg = locale[key]
    if not msg then return '[' .. key .. ']' end
    if select('#', ...) > 0 then return string.format(msg, ...) end
    return msg
end
```

---

## 5. COMPATIBILIDAD ESX / QBCORE

### Detección (igual en client y server)

```lua
local Framework     = nil
local FrameworkName = nil

CreateThread(function()
    if Config.Framework == 'auto' then
        if GetResourceState('es_extended') == 'started' then
            FrameworkName = 'esx'
        elseif GetResourceState('qb-core') == 'started' then
            FrameworkName = 'qbcore'
        end
    else
        FrameworkName = Config.Framework
    end

    if FrameworkName == 'esx' then
        Framework = exports['es_extended']:getSharedObject()
    elseif FrameworkName == 'qbcore' then
        Framework = exports['qb-core']:GetCoreObject()
    end
end)
```

### Helpers de servidor (obligatorios)

```lua
local function GetPlayer(source)
    if FrameworkName == 'esx' then
        return Framework.GetPlayerFromId(source)
    elseif FrameworkName == 'qbcore' then
        return Framework.Functions.GetPlayer(source)
    end
end

local function GetIdentifier(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
end

local function GetBankMoney(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        return xPlayer.getAccount('bank').money
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.money['bank'] or 0
    end
    return 0
end

local function GetJob(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.job and xPlayer.job.name or nil
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.job and Player.PlayerData.job.name or nil
    end
end
```

### Eventos de conexión/desconexión (patrón compatible)

```lua
-- En server/main.lua (dentro del CreateThread de init, después de asignar FrameworkName)
if FrameworkName == 'esx' then
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer) OnPlayerJoin(playerId) end)
    AddEventHandler('esx:playerDropped', function(playerId) OnPlayerLeave(playerId) end)
elseif FrameworkName == 'qbcore' then
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player) OnPlayerJoin(Player.PlayerData.source) end)
    AddEventHandler('QBCore:Server:PlayerUnload', function(src) OnPlayerLeave(src) end)
end
```

---

## 6. COMPATIBILIDAD DE PLUGINS

Cada plugin se detecta en runtime y se usa a través de wrappers locales. **Nunca llamar directamente** a un export de plugin sin pasar por el wrapper.

### 6.1 UI / Notificaciones (client)

```lua
local UILib = nil

CreateThread(function()
    -- Espera a que el init del framework termine
    Wait(100)
    if Config.UILib == 'auto' then
        if GetResourceState('ox_lib') == 'started' then
            UILib = 'oxlib'
        end
    else
        UILib = Config.UILib
    end
end)

local function Notify(msg, nType, duration)
    nType    = nType or 'info'
    duration = duration or 5000
    if UILib == 'oxlib' then
        lib.notify({ description = msg, type = nType, duration = duration })
    elseif FrameworkName == 'esx' then
        Framework.ShowNotification(msg)
    elseif FrameworkName == 'qbcore' then
        Framework.Functions.Notify(msg, nType, duration)
    end
end
```

### 6.2 Menús contextuales (client)

```lua
-- ox_lib (preferido)
local function OpenMenu(menuId, title, options)
    if UILib == 'oxlib' then
        lib.registerContext({ id = menuId, title = title, options = options })
        lib.showContext(menuId)
    elseif GetResourceState('qb-menu') == 'started' then
        -- Convertir formato ox_lib → qb-menu
        local items = {}
        for _, opt in ipairs(options) do
            items[#items + 1] = {
                title   = opt.title,
                description = opt.description,
                event   = opt.event,
                args    = opt.args,
                isServer = opt.serverEvent ~= nil,
                disabled = opt.disabled,
            }
        end
        exports['qb-menu']:createMenu({ id = menuId, title = title, items = items })
        exports['qb-menu']:openMenu(menuId)
    end
end
```

> `lib.inputDialog` y `lib.alertDialog` de ox_lib no tienen equivalente directo en qb-menu. Si el script los requiere, listar ox_lib como dependencia **obligatoria** y documentarlo en el README.

### 6.3 Inventarios (server)

```lua
local InvSystem = nil

CreateThread(function()
    if Config.InventorySystem == 'auto' then
        if GetResourceState('ox_inventory') == 'started' then
            InvSystem = 'ox'
        elseif GetResourceState('qb-inventory') == 'started' then
            InvSystem = 'qb'
        end
    else
        InvSystem = Config.InventorySystem == 'ox_inventory' and 'ox' or 'qb'
    end
end)

local function AddItem(source, item, amount, metadata)
    if InvSystem == 'ox' then
        exports.ox_inventory:AddItem(source, item, amount, metadata)
    elseif InvSystem == 'qb' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then Player.Functions.AddItem(item, amount, false, metadata) end
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add')
    end
end

local function RemoveItem(source, item, amount, slot)
    if InvSystem == 'ox' then
        return exports.ox_inventory:RemoveItem(source, item, amount, nil, slot)
    elseif InvSystem == 'qb' then
        local Player = Framework.Functions.GetPlayer(source)
        if not Player then return false end
        local ok = Player.Functions.RemoveItem(item, amount, slot)
        if ok then TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove') end
        return ok
    end
    return false
end

local function GetItemCount(source, item)
    if InvSystem == 'ox' then
        return exports.ox_inventory:GetItem(source, item, nil, true) or 0
    elseif InvSystem == 'qb' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then
            local itemData = Player.Functions.GetItemByName(item)
            return itemData and itemData.amount or 0
        end
    end
    return 0
end

local function HasItem(source, item, amount)
    return GetItemCount(source, item) >= (amount or 1)
end
```

### 6.4 Sistema de targets (client)

```lua
local TargetLib = nil

CreateThread(function()
    Wait(100)
    if Config.TargetSystem == 'auto' then
        if GetResourceState('ox_target') == 'started' then
            TargetLib = 'ox'
        elseif GetResourceState('qb-target') == 'started' then
            TargetLib = 'qb'
        end
    elseif Config.TargetSystem ~= 'none' then
        TargetLib = Config.TargetSystem == 'ox_target' and 'ox' or 'qb'
    end
end)

-- Añadir target a una entidad local
local function AddEntityTarget(entity, options, distance)
    distance = distance or Config.InteractionDistance
    if TargetLib == 'ox' then
        exports.ox_target:addLocalEntity(entity, options)
    elseif TargetLib == 'qb' then
        exports['qb-target']:AddTargetEntity(entity, { options = options, distance = distance })
    end
end

-- Eliminar target de una entidad local
local function RemoveEntityTarget(entity)
    if TargetLib == 'ox' then
        exports.ox_target:removeLocalEntity(entity)
    elseif TargetLib == 'qb' then
        exports['qb-target']:RemoveTargetEntity(entity)
    end
end

-- Añadir target a un modelo
local function AddModelTarget(models, options, distance)
    distance = distance or Config.InteractionDistance
    if TargetLib == 'ox' then
        exports.ox_target:addModel(models, options)
    elseif TargetLib == 'qb' then
        exports['qb-target']:AddTargetModel(models, { options = options, distance = distance })
    end
end

-- Zona esférica interactuable
local function AddSphereZone(name, coords, radius, options, distance)
    distance = distance or Config.InteractionDistance
    if TargetLib == 'ox' then
        exports.ox_target:addSphereZone({ name = name, coords = coords, radius = radius, options = options })
    elseif TargetLib == 'qb' then
        exports['qb-target']:AddCircleZone(name, coords, radius, { useZ = true }, { options = options, distance = distance })
    end
end
```

> Cuando `Config.TargetSystem = 'none'`, el script cae en el hilo de proximidad clásico con marker + tecla E.

---

## 7. OPTIMIZACIÓN — CLIENTE

### Arquitectura de 3 threads (patrón canónico)

```lua
-- ── THREAD 1: Caché de posición — actualiza cada 500ms ────────────────────────
local cachedPed    = 0
local cachedCoords = vector3(0, 0, 0)

CreateThread(function()
    while true do
        Wait(500)
        cachedPed    = PlayerPedId()
        cachedCoords = GetEntityCoords(cachedPed)
    end
end)

-- ── THREAD 2: Proximidad — ajusta estado, nunca dibuja ────────────────────────
local isNear         = false
local nearestLocation = nil

CreateThread(function()
    while true do
        local closest, closestDist = nil, math.huge

        for _, loc in ipairs(Config.Locations) do
            local dist = #(cachedCoords - loc.coords.xyz)  -- ← vector math, no GetDistanceBetweenCoords
            if dist < closestDist then
                closestDist = dist
                closest     = loc
            end
        end

        if closestDist <= Config.InteractionDistance then
            isNear          = true
            nearestLocation = closest
        else
            isNear          = false
            nearestLocation = nil
        end

        -- Wait dinámico: lejos = revisar cada segundo, cerca = cada 500ms
        Wait(isNear and 500 or Config.PollingInterval)
    end
end)

-- ── THREAD 3: Render — solo activo cuando el jugador está cerca ───────────────
CreateThread(function()
    while true do
        if isNear and nearestLocation then
            -- Dibujar marker
            if Config.Marker.enabled then
                DrawMarker(
                    Config.Marker.type,
                    nearestLocation.coords.x, nearestLocation.coords.y, nearestLocation.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                    Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                    false, true, 2, false, nil, nil, false
                )
            end

            -- Hint de interacción
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(_U('press_e'))
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, 38) then  -- E
                OnInteract(nearestLocation)
            end

            Wait(0)  -- ← Wait(0) SOLO aquí, dentro del bloque near
        else
            Wait(Config.PollingInterval)
        end
    end
end)
```

### Reglas de rendimiento cliente

```lua
-- ❌ MAL: Wait(0) siempre activo aunque el jugador esté lejos
CreateThread(function()
    while true do
        Wait(0)
        local coords = GetEntityCoords(PlayerPedId())
        if #(coords - Config.Locations[1].coords.xyz) < 2.0 then -- ...
        end
    end
end)

-- ❌ MAL: GetDistanceBetweenCoords (nativo costoso, ~0.28ms)
local d = GetDistanceBetweenCoords(x1,y1,z1, x2,y2,z2, true)

-- ✅ BIEN: Aritmética vectorial directa (~0.13ms, 50% más rápido)
local d = #(vector3(x1, y1, z1) - vector3(x2, y2, z2))

-- ❌ MAL: PlayerPedId() y GetEntityCoords en cada frame
CreateThread(function()
    while true do
        Wait(0)
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
    end
end)

-- ✅ BIEN: Caché en thread separado (Thread 1 del patrón anterior)

-- ❌ MAL: GetVehiclePool o GetGamePool en cada frame
CreateThread(function()
    while true do
        Wait(0)
        local vehicles = GetGamePool('CVehicle')  -- escanea todos los vehículos
    end
end)

-- ✅ BIEN: Solo cuando sea necesario, con Wait alto y resultado cacheado
```

### Desactivar threads cuando no son necesarios

```lua
-- Usar flag para pausar un thread sin destruirlo
local threadActive = false

CreateThread(function()
    while true do
        if threadActive then
            -- lógica activa
            Wait(0)
        else
            Wait(1000)  -- idle: revisar el flag cada segundo
        end
    end
end)

-- Activar/desactivar desde eventos
AddEventHandler('mi-recurso:cliente:activar', function()
    threadActive = true
end)
AddEventHandler('mi-recurso:cliente:desactivar', function()
    threadActive = false
end)
```

---

## 8. OPTIMIZACIÓN — SERVIDOR

```lua
-- ── Rate limiting (obligatorio en todos los eventos críticos) ─────────────────
local cooldowns = {}

local function CheckCooldown(source, action, ms)
    local key = source .. '_' .. action
    local now = GetGameTimer()
    if cooldowns[key] and (now - cooldowns[key]) < ms then return false end
    cooldowns[key] = now
    return true
end

-- ── Broadcast solo cuando sea imprescindible ──────────────────────────────────
-- ❌ MAL: Enviar a todos aunque solo uno lo necesite
TriggerClientEvent('mi-recurso:update', -1, datos)

-- ✅ BIEN: Enviar solo al destinatario
TriggerClientEvent('mi-recurso:update', source, datos)

-- ✅ BIEN: Enviar a jugadores en radio
local function TriggerInRadius(coords, radius, event, ...)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local ped = GetPlayerPed(src)
        if #(coords - GetEntityCoords(ped)) <= radius then
            TriggerClientEvent(event, src, ...)
        end
    end
end

-- ── Limpiar datos al desconectar (siempre) ────────────────────────────────────
AddEventHandler('playerDropped', function()
    local source = source
    -- limpiar cooldowns
    for key in pairs(cooldowns) do
        if key:match('^' .. source .. '_') then
            cooldowns[key] = nil
        end
    end
    -- limpiar caché de jugador
    playerCache[source] = nil
end)

-- ── Caché de datos del jugador (evita queries repetidas) ──────────────────────
local playerCache = {}

local function GetCachedPlayerData(source)
    if playerCache[source] then return playerCache[source] end
    local result = MySQL.query.await('SELECT * FROM mi_tabla WHERE identifier = ?', { GetIdentifier(source) })
    playerCache[source] = result and result[1] or {}
    return playerCache[source]
end
```

---

## 9. SISTEMA DE EVENTOS SEGUROS

### Validación completa (patrón servidor)

```lua
RegisterNetEvent('mi-recurso:server:accion', function(datos)
    local source = source  -- captura inmediata (importante)

    -- 1. Rate limiting
    if not CheckCooldown(source, 'accion', Config.Cooldowns.accion_principal) then return end

    -- 2. Jugador existe en el framework
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    -- 3. Validar tipo y rango de datos
    if type(datos) ~= 'table' then return end
    if type(datos.cantidad) ~= 'number' then return end
    if datos.cantidad < 1 or datos.cantidad > 1000 then return end
    if type(datos.plate) ~= 'string' or #datos.plate > 8 then return end

    -- 4. Validar permisos / job si aplica
    local job = GetJob(source)
    if not Config.Jobs[job] then
        NotifyClient(source, _U('sin_permiso'), 'error')
        return
    end

    -- 5. Validar estado en BD (nunca confiar en el cliente)
    local dbData = MySQL.query.await('SELECT * FROM mi_tabla WHERE id = ?', { datos.id })
    if not dbData or #dbData == 0 then return end

    -- 6. Ejecutar lógica
end)
```

### Nomenclatura de eventos

```
Formato:  'nombre-recurso:lado:accion'
Ejemplos:
  mi-recurso:server:guardarDatos
  mi-recurso:client:actualizarUI
  mi-recurso:client:abrirMenu
```

---

## 10. BASE DE DATOS — OXMYSQL

```lua
-- ✅ Consulta con await (simple y limpia)
local result = MySQL.query.await('SELECT * FROM tabla WHERE identifier = ?', { identifier })
if result and #result > 0 then
    -- procesar result[1]
end

-- ✅ Insert y obtener ID
local id = MySQL.insert.await(
    'INSERT INTO tabla (identifier, datos) VALUES (?, ?)',
    { identifier, json.encode(datos) }
)

-- ✅ Update con rows afectadas
local affected = MySQL.update.await(
    'UPDATE tabla SET estado = ? WHERE id = ? AND estado = ?',
    { 'nuevo', id, 'viejo' }
)
if not affected or affected == 0 then
    -- nadie actualizó — condición de carrera o ID incorrecto
end

-- ✅ Ejecutar sin esperar respuesta (fire & forget)
MySQL.update('UPDATE tabla SET updated_at = NOW() WHERE id = ?', { id })

-- ❌ NUNCA concatenar strings en SQL
MySQL.query('SELECT * FROM tabla WHERE plate = "' .. plate .. '"')  -- INYECCIÓN SQL
```

---

## 11. LOCALIZACIÓN (locales/)

```lua
-- locales/es.lua
Locales = Locales or {}
Locales['es'] = {
    ['sin_permiso']   = 'No tienes permiso para hacer esto.',
    ['error_generico']= 'Ha ocurrido un error.',
    ['exito']         = 'Acción realizada con éxito.',
    ['precio']        = 'Precio: $%s',   -- %s para string.format
    ['press_e']       = '[E] Interactuar',
}

-- locales/en.lua
Locales['en'] = {
    ['sin_permiso']   = 'You do not have permission to do this.',
    ['error_generico']= 'An error occurred.',
    ['exito']         = 'Action completed successfully.',
    ['precio']        = 'Price: $%s',
    ['press_e']       = '[E] Interact',
}
```

---

## 12. SQL (install.sql)

```sql
-- =============================================
-- Recurso: mi-recurso  |  Versión: 1.0.0
-- ADVERTENCIA: Elimina y recrea las tablas
-- =============================================
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `mi_recurso_items`;
DROP TABLE IF EXISTS `mi_recurso_players`;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE `mi_recurso_players` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `nombre`     VARCHAR(100) NOT NULL DEFAULT '',
    `datos`      LONGTEXT     DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_identifier` (`identifier`),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 13. NUI — INTERFAZ HTML (solo si el script lo requiere)

```lua
-- Abrir / cerrar (client/main.lua)
local nuiVisible = false

local function AbrirNUI(datos)
    if nuiVisible then return end
    nuiVisible = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = datos })
end

local function CerrarNUI()
    if not nuiVisible then return end
    nuiVisible = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    CerrarNUI()
    cb('ok')
end)
```

```javascript
// html/script.js
window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        document.getElementById('app').style.display = 'flex';
        // poblar UI con data.data
    }
    if (data.action === 'close') {
        document.getElementById('app').style.display = 'none';
    }
});

function enviarALua(action, payload = {}) {
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    });
}

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') enviarALua('close');
});
```

---

## 14. METODOLOGÍA ANTI-BUGS

Seguir este protocolo sin excepción al corregir cualquier error.

### Paso 1 — ENTENDER antes de tocar

- Reproducir el bug exactamente y leer el error completo en consola/logs.
- Identificar el archivo, la línea y la **función** donde ocurre.
- Leer **toda** la función afectada, no solo la línea del error.
- Trazar el flujo: ¿qué llama a esta función? ¿qué devuelve? ¿qué espera el caller?

### Paso 2 — IMPACTO MÍNIMO

```
✅ Cambiar SOLO lo necesario para corregir el bug
✅ Resolver la causa raíz, no el síntoma
❌ NO refactorizar código mientras se corrige un bug
❌ NO renombrar variables ni reordenar bloques
❌ NO aprovechar el PR del bug para "limpiar" código cercano
❌ NO añadir funcionalidades nuevas en un bugfix
```

> Si la corrección requiere cambios en más de 5 lugares, detente y analiza la arquitectura antes de continuar.

### Paso 3 — VERIFICAR REGRESIONES

Después de cada cambio, revisar manualmente:

```
□ ¿Sigue funcionando el flujo principal?
□ ¿Qué pasa si los datos son nil o vacíos?
□ ¿Qué pasa si el jugador se desconecta en medio del flujo?
□ ¿Qué pasa si el evento se dispara dos veces seguidas?
□ ¿Las funciones que llaman al código modificado siguen recibiendo lo que esperan?
□ ¿El bug podría ocurrir en otro lugar similar del código?
```

### Paso 4 — CASOS COMUNES Y SU CORRECCIÓN CORRECTA

```lua
-- Bug: nil indexing  →  añadir nil check, NO eliminar la llamada
-- ❌ MAL (elimina lógica)
-- if xPlayer then xPlayer.addMoney(100) end  →  borrar línea

-- ✅ BIEN (corrige la causa: el player puede ser nil si acaba de desconectarse)
local xPlayer = Framework.GetPlayerFromId(source)
if not xPlayer then
    LogError('GetPlayerFromId devolvió nil para source %s', source)
    return
end

-- Bug: event spam  →  añadir cooldown, NO deshabilitar el evento
-- ✅ BIEN
if not CheckCooldown(source, 'accion', 3000) then return end

-- Bug: race condition en BD  →  lock optimista, NO simplificar el flujo
-- ✅ BIEN
local updated = MySQL.update.await(
    'UPDATE tabla SET estado = ? WHERE id = ? AND estado = ?',
    { 'nuevo', id, 'previo' }
)
if not updated or updated == 0 then return end  -- otro proceso ya lo cambió
```

### Paso 5 — COMMIT DEL FIX

El mensaje de commit debe explicar el **por qué**, no el qué:

```
✅ "fix: nil check en GetPlayer cuando jugador se desconecta durante la transacción"
✅ "fix: cooldown en buyVehicle evita doble-compra por lag de cliente"
❌ "fix: arreglar bug"
❌ "fix: corregir error en server/main.lua"
```

---

## 15. CÓDIGO LIMPIO

### Convenciones de nombres

```lua
-- Variables locales: camelCase
local playerCoords = GetEntityCoords(PlayerPedId())

-- Constantes / config: PascalCase con Config.
Config.InteractionDistance = 2.5

-- Funciones privadas: camelCase  (local function)
local function checkCooldown(source, action, ms) end

-- Funciones públicas / exports: PascalCase
function GetPlayerData(source) end

-- Eventos: kebab-case con formato  recurso:lado:accion
RegisterNetEvent('mi-recurso:server:guardarDatos')
```

### Tamaño de funciones

- Máximo **30 líneas** por función. Si crece más, extraer sub-funciones.
- Cada función hace **una sola cosa**.
- Evitar anidación de más de 3 niveles de `if`. Usar guard clauses (return temprano).

```lua
-- ❌ MAL: guard clause ausente, anidación profunda
local function procesarAccion(source, datos)
    if source then
        if datos then
            if datos.id then
                -- lógica
            end
        end
    end
end

-- ✅ BIEN: guard clauses (return temprano)
local function procesarAccion(source, datos)
    if not source then return end
    if not datos or not datos.id then return end
    -- lógica aquí, a nivel 1
end
```

### Comentarios: cuándo y cómo

```lua
-- ✅ Comentar el PORQUÉ cuando no es obvio
-- MySQL PADSPACE ignora trailing spaces: 'ABC' = 'ABC   ' en comparaciones
local plate = rawPlate:gsub('%s+', '')

-- ❌ NO comentar el QUÉ (el código ya lo dice)
-- incrementar el contador
count = count + 1

-- ❌ NO dejar código comentado
-- local old = Framework.GetPlayerFromId(source)
```

---

## 16. SEGURIDAD

```lua
-- ✅ Siempre capturar source al inicio del evento (puede cambiar con coroutines)
RegisterNetEvent('mi-recurso:server:accion', function(datos)
    local source = source  -- primera línea siempre

-- ✅ Validar tipos y rangos
local function ValidarPayload(datos)
    if type(datos) ~= 'table'                       then return false end
    if type(datos.cantidad) ~= 'number'             then return false end
    if datos.cantidad < 1 or datos.cantidad > 1000  then return false end
    if type(datos.plate) ~= 'string'                then return false end
    if #datos.plate < 1 or #datos.plate > 8         then return false end
    return true
end

-- ✅ Proteger exports de terceros con pcall
local function CallExportSafe(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return nil end
    local ok, result = pcall(exports[resource][fn], exports[resource], ...)
    if not ok then
        LogError('Export %s:%s falló: %s', resource, fn, result)
        return nil
    end
    return result
end
```

---

## 17. DEBUGGING Y LOGS

```lua
local RESOURCE_NAME = GetCurrentResourceName()

local function DebugPrint(...)
    if not Config.Debug then return end
    print(('[%s]'):format(RESOURCE_NAME), ...)
end

local function LogError(msg, ...)
    print(('[%s][ERROR] ' .. msg):format(RESOURCE_NAME, ...))
end

local function LogWarn(msg, ...)
    print(('[%s][WARN] ' .. msg):format(RESOURCE_NAME, ...))
end

-- Uso
DebugPrint('Jugador conectado:', source)               -- solo con Config.Debug = true
LogWarn('InvSystem no detectado, usando fallback')     -- siempre visible
LogError('MySQL fallo para identifier: %s', id)        -- siempre visible
```

---

## RESUMEN — TABLA DE REGLAS OBLIGATORIAS

| Área | Regla |
|---|---|
| **Estructura** | `client/` `server/` `locales/` `config/` `sql/` siempre presentes |
| **Config** | Todo configurable en `config.lua`; plugins con `'auto'` por defecto |
| **Framework** | Detección automática ESX/QBCore; helpers `GetPlayer`, `GetIdentifier`, `GetBankMoney`, `GetJob` |
| **Plugins** | Wrappers para inventario, target y menú; nunca llamada directa |
| **Optimización** | 3 threads separados; `Wait` dinámico; caché de posición cada 500ms |
| **Distancias** | `#(v1 - v2)` obligatorio; prohibido `GetDistanceBetweenCoords` |
| **Seguridad** | `local source = source` primera línea; validar tipo + rango + cooldown |
| **SQL** | Siempre parametrizado; `DROP + CREATE` en install.sql |
| **Localización** | Cero strings hardcodeados; `_U('clave')` siempre |
| **Bugs** | Entender → cambio mínimo → verificar regresiones → commit descriptivo |
| **Eventos** | Formato `recurso:lado:accion`; cooldown en todos los eventos críticos |
| **Código** | Guard clauses; funciones ≤ 30 líneas; comentar solo el PORQUÉ |
| **Debug** | `DebugPrint` respeta `Config.Debug`; errores siempre con `LogError` |

---

## REFERENCIAS TÉCNICAS

| Recurso | URL |
|---|---|
| FiveM Docs | https://docs.fivem.net/docs/ |
| FiveM Natives | https://docs.fivem.net/natives/ |
| Seguridad de eventos | https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/ |
| ox_lib | https://overextended.dev/ox_lib |
| oxmysql | https://overextended.dev/oxmysql |
| ox_target | https://overextended.dev/ox_target |
| ox_inventory | https://overextended.dev/ox_inventory |
| ESX Legacy | https://github.com/esx-framework/esx_core |
| QBCore | https://github.com/qbcore-framework/qb-core |
| qb-target | https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-target |
