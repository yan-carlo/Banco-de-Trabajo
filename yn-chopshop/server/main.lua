print('[yn-chopshop] Servidor cargando...')

-- ─── Framework ───────────────────────────────────────────────────────────────

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

    print('[yn-chopshop] Framework detectado:', FrameworkName or 'ninguno')
    print('[yn-chopshop] Servidor listo. Zonas configuradas:', #Config.SpawnZones)
end)

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function Log(...)
    if Config.Debug then print('[yn-chopshop][SV]', ...) end
end

local function GetIdentifier(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
    return tostring(GetPlayerIdentifier(source, 0) or source)
end

local function GiveMoney(source, amount)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer then xPlayer.addAccountMoney('money', amount) end
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then Player.Functions.AddMoney('cash', amount) end
    end
end

local function GetPlayerCoords(source)
    local ped = GetPlayerPed(source)
    return GetEntityCoords(ped)
end

local function IsNearChopShop(source)
    local c     = Config.ChopShop.coords
    local shop  = vec3(c.x, c.y, c.z)
    local dist  = #(GetPlayerCoords(source) - shop)
    return dist <= (Config.ChopShop.radius + 8.0)
end

-- ─── Estado global ────────────────────────────────────────────────────────────
-- Solo se permite UN trabajo activo a la vez en el servidor.

local activeJob = nil
--[[
activeJob = {
    source       = number,
    identifier   = string,
    netId        = number,
    removedParts = { [partId] = true },
    soldParts    = { [partId] = true },
    totalEarned  = number,
    -- Datos de la zona seleccionada (para enviar al cliente en startJob)
    zoneCenterX  = number,
    zoneCenterY  = number,
    zoneCenterZ  = number,
    zoneRadius   = number,
}
]]

local playerCooldowns = {} -- [identifier] = timestamp (GetGameTimer)

-- ─── Solicitar trabajo ────────────────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:server:requestJob', function()
    local source     = source
    local identifier = GetIdentifier(source)
    if not identifier then return end

    -- Ya tiene trabajo activo
    if activeJob and activeJob.source == source then
        TriggerClientEvent('yn-chopshop:client:alreadyInJob', source)
        return
    end

    -- Trabajo ocupado por otro jugador
    if activeJob then
        TriggerClientEvent('yn-chopshop:client:jobUnavailable', source)
        return
    end

    -- Cooldown
    local now = GetGameTimer()
    if playerCooldowns[identifier] and (now - playerCooldowns[identifier]) < Config.Cooldown then
        TriggerClientEvent('yn-chopshop:client:cooldown', source)
        return
    end

    -- Seleccionar zona aleatoria y dentro de ella un punto de spawn aleatorio
    local zone       = Config.SpawnZones[math.random(#Config.SpawnZones)]
    local spawnPoint = zone.spawns[math.random(#zone.spawns)]
    local model      = Config.Vehicles[math.random(#Config.Vehicles)]

    -- Marcar trabajo como pendiente de spawn
    activeJob = {
        source       = source,
        identifier   = identifier,
        netId        = nil,
        removedParts = {},
        soldParts    = {},
        totalEarned  = 0,
        zoneCenterX  = zone.center.x,
        zoneCenterY  = zone.center.y,
        zoneCenterZ  = zone.center.z,
        zoneRadius   = zone.radius,
    }

    TriggerClientEvent('yn-chopshop:client:spawnVehicle', source, {
        model   = model,
        x       = spawnPoint.x,
        y       = spawnPoint.y,
        z       = spawnPoint.z,
        heading = spawnPoint.w,
    })

    Log('Spawn solicitado para', source, '| zona:', zone.label, '| modelo:', model)
end)

-- ─── Vehículo spawneado ───────────────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:server:vehicleSpawned', function(netId, spawnX, spawnY, spawnZ)
    local source = source
    if not activeJob or activeJob.source ~= source then return end
    if not netId or netId == 0 then
        activeJob = nil
        return
    end

    activeJob.netId = netId

    TriggerClientEvent('yn-chopshop:client:startJob', source,
        netId, spawnX, spawnY, spawnZ,
        activeJob.zoneCenterX, activeJob.zoneCenterY, activeJob.zoneCenterZ, activeJob.zoneRadius)
    Log('Trabajo iniciado para', source, 'netId:', netId)
end)

RegisterNetEvent('yn-chopshop:server:spawnFailed', function()
    local source = source
    if not activeJob or activeJob.source ~= source then return end
    activeJob = nil
    Log('Spawn fallido para', source)
end)

-- ─── Pieza quitada del vehículo ──────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:server:partRemoved', function(partId, netId)
    local source = source
    if not activeJob or activeJob.source ~= source then return end
    if activeJob.netId ~= netId then return end
    if activeJob.removedParts[partId] then return end

    -- Validar que la pieza existe en config
    local partCfg = nil
    for _, p in ipairs(Config.Parts) do
        if p.id == partId then partCfg = p; break end
    end
    if not partCfg then
        Log('WARN: pieza inválida recibida:', partId, 'de', source)
        return
    end

    -- Validar proximidad al desguace
    if not IsNearChopShop(source) then
        Log('WARN: partRemoved rechazado - jugador lejos del desguace. Source:', source)
        return
    end

    activeJob.removedParts[partId] = true

    -- Añadir ítem a ox_inventory (ítem visual en inventario)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(source, partCfg.item, 1)
    end

    Log('Pieza registrada:', partId, 'para', source)
end)

-- ─── Venta de pieza al comprador ─────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:server:sellPart', function(partId)
    local source = source
    if not activeJob or activeJob.source ~= source then return end
    if not activeJob.removedParts[partId] then
        Log('WARN: sellPart sin partRemoved previo:', partId, 'source:', source)
        return
    end
    if activeJob.soldParts[partId] then return end

    -- Validar que la pieza existe en config
    local partCfg = nil
    for _, p in ipairs(Config.Parts) do
        if p.id == partId then partCfg = p; break end
    end
    if not partCfg then return end

    -- Validar proximidad al desguace
    if not IsNearChopShop(source) then
        Log('WARN: sellPart rechazado - jugador lejos del desguace. Source:', source)
        return
    end

    -- Quitar ítem del inventario
    if GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(source, partCfg.item)
        if count and count > 0 then
            exports.ox_inventory:RemoveItem(source, partCfg.item, 1)
        end
    end

    -- Dar dinero
    GiveMoney(source, partCfg.reward)

    activeJob.soldParts[partId] = true
    activeJob.totalEarned       = activeJob.totalEarned + partCfg.reward

    -- Comprobar si todas las piezas están vendidas
    local allSold = true
    for _, p in ipairs(Config.Parts) do
        if not activeJob.soldParts[p.id] then
            allSold = false
            break
        end
    end

    TriggerClientEvent('yn-chopshop:client:partSold', source, partId, partCfg.reward, allSold)
    Log('Pieza vendida:', partId, 'Recompensa:', partCfg.reward, 'Todas vendidas:', allSold)

    if allSold then
        -- Aplicar cooldown y limpiar trabajo
        playerCooldowns[activeJob.identifier] = GetGameTimer()
        Log('Trabajo completado para', source, '- Total:', activeJob.totalEarned)
        activeJob = nil
    end
end)

-- ─── Alerta policial ─────────────────────────────────────────────────────────
-- Export correcto de origen_police: SendAlert
-- Docs: https://docs.origennetwork.store/origen-police/exports/server-exports

RegisterNetEvent('yn-chopshop:server:policeAlert', function(coords)
    local source = source
    if not activeJob or activeJob.source ~= source then return end

    if GetResourceState('origen_police') ~= 'started' then
        Log('origen_police no está activo, alerta omitida')
        return
    end

    local ok, err = pcall(function()
        exports['origen_police']:SendAlert({
            coords  = vector3(coords.x, coords.y, coords.z),
            title   = _U('police_alert_title'),
            type    = 'GENERAL',
            message = _U('police_alert_message'),
            job     = 'police',
        })
    end)

    if not ok then
        print('[yn-chopshop] ERROR al enviar alerta policial:', tostring(err))
    else
        Log('Alerta policial enviada desde', source)
    end
end)

-- ─── Desconexión del jugador ──────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local source = source
    if activeJob and activeJob.source == source then
        Log('Jugador con trabajo activo desconectado. Limpiando trabajo.')
        activeJob = nil
    end
end)
