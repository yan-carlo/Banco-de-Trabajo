# CLAUDE.md — Guía Oficial para Desarrollo de Scripts FiveM

Este archivo define las reglas, estructura y buenas prácticas que la IA **debe seguir obligatoriamente** al crear o modificar cualquier script de FiveM en este repositorio.

---

## 1. ESTRUCTURA DE CARPETAS

Todo recurso debe seguir esta estructura estricta:

```
mi-recurso/
├── client/
│   ├── main.lua          # Lógica principal del cliente
│   └── ...               # Archivos adicionales del cliente
├── server/
│   ├── main.lua          # Lógica principal del servidor
│   └── ...               # Archivos adicionales del servidor
├── locales/
│   ├── es.lua            # Español (idioma base obligatorio)
│   ├── en.lua            # Inglés
│   └── ...               # Otros idiomas
├── html/                 # Solo si el script usa NUI/interfaz
│   ├── index.html
│   ├── style.css
│   └── script.js
├── config/
│   ├── config.lua        # Configuración principal
│   └── ...               # Configs adicionales si aplica
├── sql/
│   └── install.sql       # Script SQL (borra y recrea tablas)
├── fxmanifest.lua        # Manifiesto del recurso (OBLIGATORIO)
└── README.md             # Documentación básica del recurso
```

---

## 2. FXMANIFEST.LUA

Siempre usar `fx_version 'cerulean'` y `game 'gta5'`. Registrar todos los archivos en el orden correcto.

```lua
fx_version 'cerulean'
game 'gta5'

name        'mi-recurso'
description 'Descripción del recurso'
version     '1.0.0'
author      'Autor'

-- Shared (cargado en cliente y servidor)
shared_scripts {
    '@es_extended/imports.lua',   -- Solo si usa ESX
    'config/config.lua',
    'locales/*.lua',
}

-- Solo cliente
client_scripts {
    'client/*.lua',
}

-- Solo servidor
server_scripts {
    '@oxmysql/lib/MySQL.lua',     -- O el driver MySQL que uses
    'server/*.lua',
}

-- NUI (solo si usa interfaz HTML)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

-- Dependencias
dependencies {
    'es_extended',  -- O 'qb-core', según el framework
    'oxmysql',
}
```

---

## 3. COMPATIBILIDAD ESX Y QBCORE

El script **debe funcionar en ambos frameworks** sin modificar el código. Usar un sistema de detección automática.

### Patrón de detección en `config/config.lua`:

```lua
Config = {}
Config.Framework = 'auto' -- 'auto', 'esx' o 'qbcore'
```

### Patrón de inicialización en `client/main.lua`:

```lua
local Framework = nil
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

### Patrón de inicialización en `server/main.lua`:

```lua
local Framework = nil
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

### Funciones helper para compatibilidad:

```lua
-- Obtener datos del jugador (servidor)
local function GetPlayer(source)
    if FrameworkName == 'esx' then
        return Framework.GetPlayerFromId(source)
    elseif FrameworkName == 'qbcore' then
        return Framework.Functions.GetPlayer(source)
    end
end

-- Obtener identifier del jugador (servidor)
local function GetIdentifier(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
end

-- Notificación al cliente
local function Notify(message, notifyType, duration)
    duration = duration or 5000
    if FrameworkName == 'esx' then
        Framework.ShowNotification(message, notifyType, duration)
    elseif FrameworkName == 'qbcore' then
        Framework.Functions.Notify(message, notifyType, duration)
    end
end
```

---

## 4. ARCHIVO SQL (install.sql)

El archivo SQL **siempre debe borrar y recrear las tablas desde cero** para evitar errores de migración.

```sql
-- =============================================
-- Recurso: mi-recurso
-- Descripción: Script de instalación de base de datos
-- ADVERTENCIA: Este script elimina y recrea las tablas
-- =============================================

SET FOREIGN_KEY_CHECKS = 0;

-- Borrar tablas existentes (orden inverso a las dependencias)
DROP TABLE IF EXISTS `mi_recurso_datos`;
DROP TABLE IF EXISTS `mi_recurso_jugadores`;

SET FOREIGN_KEY_CHECKS = 1;

-- Crear tablas desde cero
CREATE TABLE IF NOT EXISTS `mi_recurso_jugadores` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `nombre`     VARCHAR(100) NOT NULL DEFAULT '',
    `datos`      LONGTEXT     DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mi_recurso_datos` (
    `id`          INT(11)     NOT NULL AUTO_INCREMENT,
    `jugador_id`  INT(11)     NOT NULL,
    `tipo`        VARCHAR(50) NOT NULL,
    `valor`       LONGTEXT    DEFAULT NULL,
    `created_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `jugador_id` (`jugador_id`),
    CONSTRAINT `fk_mi_recurso_jugador`
        FOREIGN KEY (`jugador_id`)
        REFERENCES `mi_recurso_jugadores` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 5. LOCALIZACIÓN (locales/)

Todos los textos visibles al usuario deben estar en los archivos de idioma. **Nunca hardcodear strings** en el código.

### Estructura de `locales/es.lua` (base):

```lua
Locales = {}

Locales['es'] = {
    -- General
    ['error_generico']    = 'Ha ocurrido un error.',
    ['accion_exitosa']    = 'Acción realizada con éxito.',
    ['no_autorizado']     = 'No tienes permiso para hacer esto.',
    ['jugador_no_existe'] = 'El jugador no existe.',

    -- Específicas del recurso
    ['ejemplo_mensaje']   = 'Este es un mensaje de ejemplo.',
}
```

### Función de traducción en `config/config.lua`:

```lua
Config.Locale = 'es'

function _U(str, ...)
    local locale = Locales[Config.Locale]
    if not locale then
        locale = Locales['es'] -- fallback al español
    end
    local msg = locale[str]
    if msg then
        return string.format(msg, ...)
    end
    return '[' .. str .. ']' -- devuelve la clave si no se encuentra
end
```

---

## 6. CONFIGURACIÓN (config/config.lua)

```lua
Config = {}

-- Framework: 'auto', 'esx', 'qbcore'
Config.Framework = 'auto'

-- Idioma del recurso
Config.Locale = 'es'

-- Debug: activar solo en desarrollo
Config.Debug = false

-- Distancias de interacción
Config.InteractionDistance = 2.0

-- Permisos (grupos de jugadores con acceso)
Config.Permissions = {
    admin  = true,
    police = false,
}

-- Ejemplo de ubicaciones
Config.Locations = {
    {
        label  = 'Punto de ejemplo',
        coords = vector4(0.0, 0.0, 0.0, 0.0),
        blip   = {
            sprite = 1,
            color  = 2,
            scale  = 0.8,
            label  = 'Ejemplo',
        },
    },
}
```

---

## 7. OPTIMIZACIÓN Y RENDIMIENTO

### Reglas de threads (CreateThread):

```lua
-- MAL: Thread siempre activo con Wait(0) innecesario
CreateThread(function()
    while true do
        Wait(0)
        -- lógica que no necesita ejecutarse cada frame
    end
end)

-- BIEN: Espera larga cuando el jugador está lejos, corta cuando está cerca
CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distancia    = #(playerCoords - Config.Locations[1].coords.xyz)

        if distancia < Config.InteractionDistance then
            Wait(0) -- Cercano: revisar cada frame
            -- lógica de interacción
        else
            Wait(1000) -- Lejos: revisar cada segundo
        end
    end
end)
```

### Reglas de eventos:

```lua
-- SIEMPRE validar en el servidor, nunca confiar en el cliente
RegisterNetEvent('mi-recurso:servidor:accion', function(datos)
    local source = source

    -- 1. Validar que el jugador existe
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end

    -- 2. Validar los datos recibidos
    if type(datos) ~= 'table' then return end
    if not datos.id or type(datos.id) ~= 'number' then return end

    -- 3. Validar permisos si aplica
    -- ...

    -- 4. Ejecutar la lógica
end)
```

### Caché de valores costosos:

```lua
-- MAL: Llamar GetEntityCoords cada frame sin necesidad
CreateThread(function()
    while true do
        Wait(0)
        local coords = GetEntityCoords(PlayerPedId())
        -- ...
    end
end)

-- BIEN: Actualizar caché cada 500ms y usar el valor cacheado
local cachedCoords = vector3(0, 0, 0)

CreateThread(function()
    while true do
        Wait(500)
        cachedCoords = GetEntityCoords(PlayerPedId())
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        -- Usar cachedCoords en lugar de llamar GetEntityCoords cada frame
    end
end)
```

---

## 8. EXPORTS — BUENAS PRÁCTICAS

Los exports permiten que otros recursos interactúen con este script.

### Definir exports en `server/main.lua` o `client/main.lua`:

```lua
-- Exportar funciones públicas del recurso
exports('GetDatosJugador', function(source)
    -- Validar que quien llama tiene autorización
    return ObtenerDatosJugador(source)
end)

exports('EsJugadorActivo', function(source)
    return jugadoresActivos[source] ~= nil
end)
```

### Registrar exports en `fxmanifest.lua`:

```lua
-- Los exports del servidor se registran automáticamente,
-- pero documéntalos en el README y aquí:
--
-- SERVER EXPORTS:
--   exports['mi-recurso']:GetDatosJugador(source) -> table|nil
--   exports['mi-recurso']:EsJugadorActivo(source) -> boolean
--
-- CLIENT EXPORTS:
--   exports['mi-recurso']:GetEstadoLocal() -> table
```

### Consumir exports de otros recursos con protección:

```lua
-- MAL: Llamar export sin verificar si el recurso existe
local datos = exports['otro-recurso']:GetDatos()

-- BIEN: Verificar que el recurso esté activo antes de usar su export
local function CallExportSafe(recurso, funcion, ...)
    if GetResourceState(recurso) ~= 'started' then
        if Config.Debug then
            print(('[mi-recurso] El recurso "%s" no está activo.'):format(recurso))
        end
        return nil
    end
    local ok, resultado = pcall(exports[recurso][funcion], exports[recurso], ...)
    if not ok then
        if Config.Debug then
            print(('[mi-recurso] Error al llamar export %s:%s - %s'):format(recurso, funcion, resultado))
        end
        return nil
    end
    return resultado
end

-- Uso:
local datos = CallExportSafe('otro-recurso', 'GetDatos', source)
```

---

## 9. BASE DE DATOS — OXMYSQL

Usar siempre `oxmysql` con consultas asíncronas o awaits.

```lua
-- BIEN: Consulta asíncrona con callback
MySQL.query('SELECT * FROM mi_recurso_jugadores WHERE identifier = ?', {identifier}, function(result)
    if result and #result > 0 then
        -- procesar resultado
    end
end)

-- BIEN: Usando async/await con Citizen.Await
local result = MySQL.query.await('SELECT * FROM mi_recurso_jugadores WHERE identifier = ?', {identifier})
if result and #result > 0 then
    -- procesar resultado
end

-- Para inserciones/actualizaciones:
MySQL.update('UPDATE mi_recurso_jugadores SET datos = ? WHERE identifier = ?', {
    json.encode(datos),
    identifier
})

-- Para insertar y obtener el ID:
local insertId = MySQL.insert.await('INSERT INTO mi_recurso_jugadores (identifier, nombre) VALUES (?, ?)', {
    identifier,
    nombre
})
```

---

## 10. NUI — INTERFAZ HTML

### Estructura de `html/index.html`:

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mi Recurso</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="app" style="display: none;">
        <!-- Contenido de la interfaz -->
    </div>
    <script src="script.js"></script>
</body>
</html>
```

### Comunicación NUI en `html/script.js`:

```javascript
// Recibir mensajes desde Lua
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'abrirMenu') {
        document.getElementById('app').style.display = 'block';
        // Actualizar datos en la UI
    }

    if (data.action === 'cerrarMenu') {
        document.getElementById('app').style.display = 'none';
    }
});

// Enviar datos de vuelta a Lua
function enviarALua(accion, datos) {
    fetch(`https://${GetParentResourceName()}/${accion}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(datos),
    });
}

// Cerrar con ESC
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        enviarALua('cerrarMenu', {});
    }
});
```

### Control de NUI en `client/main.lua`:

```lua
-- Abrir interfaz
local function AbrirMenu(datos)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'abrirMenu',
        datos  = datos,
    })
end

-- Cerrar interfaz
local function CerrarMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'cerrarMenu',
    })
end

-- Callback desde NUI
RegisterNUICallback('cerrarMenu', function(data, cb)
    CerrarMenu()
    cb('ok')
end)
```

---

## 11. SINCRONIZACIÓN ENTRE JUGADORES

Usar `TriggerClientEvent` para sincronizar estados entre jugadores.

```lua
-- Sincronizar a todos los jugadores
TriggerClientEvent('mi-recurso:cliente:sincronizar', -1, datos)

-- Sincronizar solo a un jugador
TriggerClientEvent('mi-recurso:cliente:sincronizar', source, datos)

-- Sincronizar a jugadores en un radio (servidor)
local function SyncEnRadio(coords, radio, evento, datos)
    for _, playerId in ipairs(GetPlayers()) do
        local ped    = GetPlayerPed(playerId)
        local pCoords = GetEntityCoords(ped)
        if #(coords - pCoords) <= radio then
            TriggerClientEvent(evento, playerId, datos)
        end
    end
end
```

### Nomenclatura de eventos:

```
-- Formato: 'nombre-recurso:lado:accion'
'mi-recurso:cliente:actualizarDatos'
'mi-recurso:servidor:guardarDatos'
'mi-recurso:cliente:abrirMenu'
```

---

## 12. SEGURIDAD

```lua
-- 1. NUNCA ejecutar lógica de negocio en el cliente
-- 2. SIEMPRE validar source en el servidor
-- 3. NUNCA confiar en datos enviados desde el cliente sin validar

-- Validación de tipos
local function ValidarDatos(datos)
    if type(datos) ~= 'table' then return false end
    if type(datos.cantidad) ~= 'number' then return false end
    if datos.cantidad <= 0 or datos.cantidad > 1000 then return false end
    return true
end

-- Rate limiting básico
local cooldowns = {}

local function CheckCooldown(source, accion, tiempo)
    local key = source .. '_' .. accion
    if cooldowns[key] and (GetGameTimer() - cooldowns[key]) < tiempo then
        return false -- En cooldown
    end
    cooldowns[key] = GetGameTimer()
    return true
end

-- Uso:
RegisterNetEvent('mi-recurso:servidor:accion', function(datos)
    local source = source
    if not CheckCooldown(source, 'accion', 3000) then return end -- 3 segundos de cooldown
    if not ValidarDatos(datos) then return end
    -- procesar...
end)
```

---

## 13. DEBUGGING Y LOGS

```lua
-- Helper de debug que respeta Config.Debug
local function DebugPrint(...)
    if Config.Debug then
        print('[mi-recurso]', ...)
    end
end

-- Log de errores siempre activo
local function LogError(mensaje, ...)
    print(('[mi-recurso][ERROR] ' .. mensaje):format(...))
end

-- Uso:
DebugPrint('Jugador conectado:', source)
LogError('No se pudo guardar datos para: %s', identifier)
```

---

## 14. EVENTOS DEL FRAMEWORK

### ESX:

```lua
-- Cliente: jugador cargado
AddEventHandler('esx:playerLoaded', function(xPlayer)
    -- inicializar datos del jugador en cliente
end)

-- Servidor: jugador completamente cargado
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    -- inicializar datos del jugador en servidor
end)

-- Servidor: jugador desconectado
AddEventHandler('esx:playerDropped', function(playerId, reason)
    -- limpiar datos del jugador
end)
```

### QBCore:

```lua
-- Cliente: jugador cargado
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    -- inicializar datos del jugador en cliente
end)

-- Servidor: jugador completamente cargado
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    -- inicializar datos del jugador en servidor
end)

-- Servidor: jugador desconectado
AddEventHandler('QBCore:Server:PlayerUnload', function(source)
    -- limpiar datos del jugador
end)
```

### Patrón compatible con ambos frameworks:

```lua
-- Cliente
if FrameworkName == 'esx' then
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        InicializarCliente()
    end)
elseif FrameworkName == 'qbcore' then
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        InicializarCliente()
    end)
end
```

---

## 15. REFERENCIAS Y DOCUMENTACIÓN OFICIAL

- **Documentación FiveM**: https://docs.fivem.net/docs/
- **Referencia de Natives**: https://docs.fivem.net/natives/
- **fxmanifest**: https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/
- **NUI**: https://docs.fivem.net/docs/scripting-manual/nui-development/
- **oxmysql**: https://overextended.dev/oxmysql
- **ESX Legacy**: https://github.com/esx-framework/esx_core
- **QBCore**: https://github.com/qbcore-framework/qb-core

---

## RESUMEN DE REGLAS OBLIGATORIAS

| Regla | Descripción |
|---|---|
| Estructura de carpetas | Seguir siempre `client/`, `server/`, `locales/`, `html/`, `config/`, `sql/` |
| Compatibilidad | El script debe funcionar en ESX **y** QBCore con detección automática |
| SQL | El `install.sql` siempre borra y recrea las tablas desde cero |
| Localización | Cero strings hardcodeados; todo en `locales/` |
| Optimización | Threads con `Wait` dinámico según distancia; no `Wait(0)` innecesarios |
| Seguridad | Toda validación en el servidor; nunca confiar en el cliente |
| Exports | Usar `pcall` y verificar `GetResourceState` antes de consumir exports |
| Base de datos | Usar `oxmysql` con consultas parametrizadas; nunca concatenar strings SQL |
| Debug | Usar `Config.Debug` para logs de desarrollo; errores siempre logueados |
| Nomenclatura | Eventos con formato `recurso:lado:accion` |
