-- ─── Estado del trabajo ───────────────────────────────────────────────────────

local job = {
    active        = false,
    vehicle       = nil,   -- entidad del vehículo robado
    netId         = nil,
    atChopShop    = false, -- true cuando ya entregó el vehículo
    removed       = {},    -- [partId] = true: pieza quitada del vehículo
    sold          = {},    -- [partId] = true: pieza vendida al comprador
    heldPartId    = nil,   -- pieza que lleva en la mano ahora mismo
    heldPropEnt   = nil,   -- entidad del prop adjunto
    policeAlerted = false,
    totalEarned   = 0,
    removing      = false, -- animación de desmontaje activa
}

local blips        = { vehicle = nil, zone = nil, shop = nil }
local buyerPed     = nil
local deliveryZone = nil

-- ─── Debug ────────────────────────────────────────────────────────────────────

local function Log(...)
    if Config.Debug then print('[yn-chopshop][CL]', ...) end
end

-- ─── Modelos y animaciones ────────────────────────────────────────────────────

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > deadline then return nil end
    end
    return hash
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > deadline then return false end
    end
    return true
end

-- ─── Blips ────────────────────────────────────────────────────────────────────

local function ClearBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    return nil
end

local function MakeVehicleBlip(coords)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, Config.Blips.vehicle.sprite)
    SetBlipColour(b, Config.Blips.vehicle.color)
    SetBlipScale(b, Config.Blips.vehicle.scale)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(_U('vehicle_blip'))
    EndTextCommandSetBlipName(b)
    return b
end

local function MakeZoneBlip(cx, cy, cz, radius)
    local b = AddBlipForRadius(cx, cy, cz, radius)
    SetBlipColour(b, Config.Blips.searchZone.color)
    SetBlipAlpha(b, 80)
    return b
end

local function MakeShopBlip()
    local c = Config.ChopShop.coords
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, Config.Blips.chopShop.sprite)
    SetBlipColour(b, Config.Blips.chopShop.color)
    SetBlipScale(b, Config.Blips.chopShop.scale)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(_U('chopshop_blip'))
    EndTextCommandSetBlipName(b)
    return b
end

-- ─── Prop en mano ─────────────────────────────────────────────────────────────

local function AttachProp(partCfg)
    local hash = LoadModel(partCfg.prop)
    if not hash then return end

    local ped  = PlayerPedId()
    local prop = CreateObject(hash, 0.0, 0.0, 0.0, true, true, true)
    local bone = GetPedBoneIndex(ped, 57005) -- PH_R_Hand

    AttachEntityToEntity(prop, ped, bone,
        0.12, 0.02, 0.0,
        0.0,  0.0,  0.0,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(hash)
    job.heldPropEnt = prop
end

local function DetachProp()
    if job.heldPropEnt and DoesEntityExist(job.heldPropEnt) then
        DetachEntity(job.heldPropEnt, true, false)
        DeleteEntity(job.heldPropEnt)
    end
    job.heldPropEnt = nil
    job.heldPartId  = nil
end

-- ─── NPC comprador ────────────────────────────────────────────────────────────

local function SpawnBuyer()
    local c   = Config.ChopShop.coords
    local off = Config.BuyerNPC.offset
    local x, y, z = c.x + off.x, c.y + off.y, c.z + off.z

    local hash = LoadModel(Config.BuyerNPC.model)
    if not hash then return end

    buyerPed = CreatePed(4, hash, x, y, z, c.w, false, true)
    FreezeEntityPosition(buyerPed, true)
    SetEntityInvincible(buyerPed, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(buyerPed, {
        {
            label    = _U('sell_part'),
            icon     = 'fas fa-hand-holding-usd',
            distance = Config.TargetDistance,
            onSelect = SellCurrentPart,
            canInteract = function()
                return job.heldPartId ~= nil and not job.removing
            end,
        }
    })

    Log('Comprador spawneado')
end

local function DespawnBuyer()
    if buyerPed and DoesEntityExist(buyerPed) then
        exports.ox_target:removeLocalEntity(buyerPed)
        DeleteEntity(buyerPed)
    end
    buyerPed = nil
end

-- ─── Targets del vehículo ────────────────────────────────────────────────────

local function AddVehicleTargets(vehicle)
    local options = {}
    for _, part in ipairs(Config.Parts) do
        local p = part
        table.insert(options, {
            label    = _U('remove_part', p.label),
            icon     = 'fas fa-tools',
            distance = Config.TargetDistance,
            onSelect = function()
                StartRemovePart(vehicle, p)
            end,
            canInteract = function()
                return not job.removing
                    and not job.removed[p.id]
                    and job.heldPartId == nil
                    and not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
        })
    end
    exports.ox_target:addLocalEntity(vehicle, options)
end

local function RemoveVehicleTargets(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        exports.ox_target:removeLocalEntity(vehicle)
    end
end

-- ─── Zona de entrega ─────────────────────────────────────────────────────────

local function AddDeliveryZone()
    local c = Config.ChopShop.coords
    deliveryZone = exports.ox_target:addSphereZone({
        name    = 'yn_chopshop_delivery',
        coords  = vec3(c.x, c.y, c.z),
        radius  = Config.ChopShop.radius,
        debug   = Config.Debug,
        options = {
            {
                label    = _U('deliver_vehicle'),
                icon     = 'fas fa-car',
                distance = Config.ChopShop.radius,
                onSelect = DeliverVehicle,
                canInteract = function()
                    return job.active
                        and not job.atChopShop
                        and IsPedInAnyVehicle(PlayerPedId(), false)
                        and GetVehiclePedIsIn(PlayerPedId(), false) == job.vehicle
                end,
            }
        },
    })
end

local function RemoveDeliveryZone()
    if deliveryZone then
        exports.ox_target:removeZone(deliveryZone)
        deliveryZone = nil
    end
end

-- ─── Desmontaje de pieza ──────────────────────────────────────────────────────

function StartRemovePart(vehicle, partCfg)
    if job.removing then return end
    if job.removed[partCfg.id] then
        lib.notify({ title = _U('part_already_removed'), type = 'error' })
        return
    end
    if job.heldPartId then
        lib.notify({ title = _U('already_holding'), type = 'warning' })
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        lib.notify({ title = _U('must_exit_vehicle'), type = 'error' })
        return
    end

    if not LoadAnimDict(partCfg.animDict) then return end

    job.removing = true
    local ped = PlayerPedId()

    TaskPlayAnim(ped, partCfg.animDict, partCfg.animClip,
        8.0, -8.0, -1, 49, 0.0, false, false, false)

    local ok = lib.progressBar({
        duration     = partCfg.time,
        label        = _U('removing_part', partCfg.label),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
    })

    ClearPedTasks(ped)
    job.removing = false

    if not ok then return end

    -- Aplicar efecto visual en el vehículo
    if partCfg.type == 'door' then
        SetVehicleDoorBroken(vehicle, partCfg.index, true)
    elseif partCfg.type == 'wheel' then
        SetVehicleTyreBurst(vehicle, partCfg.index, true, 1000.0)
        -- Intenta hacer la rueda invisible (nativo disponible en builds recientes)
        pcall(function() SetVehicleWheelBroken(vehicle, partCfg.index, true) end)
    end

    job.removed[partCfg.id] = true
    job.heldPartId           = partCfg.id
    AttachProp(partCfg)

    -- Alertar a la policía la primera vez
    if not job.policeAlerted then
        job.policeAlerted = true
        TriggerServerEvent('yn-chopshop:server:policeAlert', GetEntityCoords(vehicle))
    end

    -- Notificar al servidor para validar y registrar
    TriggerServerEvent('yn-chopshop:server:partRemoved', partCfg.id, job.netId)

    lib.notify({ title = _U('part_removed', partCfg.label), type = 'success' })
    Log('Pieza quitada:', partCfg.id)
end

-- ─── Venta de pieza ──────────────────────────────────────────────────────────

function SellCurrentPart()
    if not job.heldPartId then
        lib.notify({ title = _U('nothing_to_sell'), type = 'error' })
        return
    end
    if job.removing then return end

    TriggerServerEvent('yn-chopshop:server:sellPart', job.heldPartId)
end

-- ─── Entrega del vehículo al desguace ────────────────────────────────────────

function DeliverVehicle()
    if not job.active or job.atChopShop then return end

    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= job.vehicle then
        lib.notify({ title = _U('must_be_in_vehicle'), type = 'error' })
        return
    end

    -- Sacar al jugador del vehículo
    TaskLeaveVehicle(ped, job.vehicle, 0)
    Wait(1500)

    -- Bloquear el vehículo para que nadie pueda montarse
    SetVehicleDoorsLocked(job.vehicle, 10)
    SetVehicleEngineOn(job.vehicle, false, true, false)

    job.atChopShop = true

    -- Limpiar blips de búsqueda
    blips.vehicle = ClearBlip(blips.vehicle)
    blips.zone    = ClearBlip(blips.zone)

    -- Eliminar zona de entrega y añadir targets al vehículo
    RemoveDeliveryZone()
    AddVehicleTargets(job.vehicle)

    -- Spawnar NPC comprador
    SpawnBuyer()

    lib.notify({ title = _U('vehicle_delivered'), type = 'success', duration = 8000 })
    Log('Vehículo entregado al desguace')
end

-- ─── Finalizar trabajo ────────────────────────────────────────────────────────

local function FinishJob()
    lib.notify({
        title    = _U('all_parts_sold'),
        type     = 'success',
        duration = 6000,
    })

    Wait(1000)

    lib.notify({
        title    = _U('job_complete', job.totalEarned),
        type     = 'success',
        duration = 8000,
    })

    -- Eliminar vehículo y limpiar
    if job.vehicle and DoesEntityExist(job.vehicle) then
        RemoveVehicleTargets(job.vehicle)
        DeleteEntity(job.vehicle)
    end

    DespawnBuyer()

    -- Resetear estado
    blips.shop = ClearBlip(blips.shop)

    job.active        = false
    job.vehicle       = nil
    job.netId         = nil
    job.atChopShop    = false
    job.removed       = {}
    job.sold          = {}
    job.heldPartId    = nil
    job.policeAlerted = false
    job.totalEarned   = 0
    job.removing      = false

    DetachProp()
    Log('Trabajo finalizado')
end

-- ─── Spawn del vehículo (orden del servidor) ──────────────────────────────────

RegisterNetEvent('yn-chopshop:client:spawnVehicle', function(data)
    local hash = LoadModel(data.model)
    if not hash then
        TriggerServerEvent('yn-chopshop:server:spawnFailed')
        return
    end

    -- Spawn en la coordenada exacta configurada en Config.SpawnZones
    local vehicle = CreateVehicle(hash, data.x, data.y, data.z, data.heading, true, false)
    SetVehicleEngineOn(vehicle, false, true, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetModelAsNoLongerNeeded(hash)

    -- Esperar que el vehículo sea registrado en la red
    local netId    = 0
    local deadline = GetGameTimer() + 6000
    while (not netId or netId == 0) and GetGameTimer() < deadline do
        Wait(100)
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    end

    if not netId or netId == 0 then
        DeleteEntity(vehicle)
        TriggerServerEvent('yn-chopshop:server:spawnFailed')
        return
    end

    TriggerServerEvent('yn-chopshop:server:vehicleSpawned', netId, data.x, data.y, data.z)
    Log('Vehículo spawneado. NetId:', netId)
end)

-- ─── Inicio del trabajo ───────────────────────────────────────────────────────

-- zoneCx/Cy/Cz/zoneRadius: datos de la zona seleccionada, enviados por el servidor
RegisterNetEvent('yn-chopshop:client:startJob', function(netId, spawnX, spawnY, spawnZ, zoneCx, zoneCy, zoneCz, zoneRadius)
    if job.active then return end

    job.active        = true
    job.netId         = netId
    job.removed       = {}
    job.sold          = {}
    job.policeAlerted = false
    job.totalEarned   = 0
    job.atChopShop    = false

    -- Esperar que la entidad del vehículo exista localmente
    local vehicle  = nil
    local deadline = GetGameTimer() + 10000
    while (not vehicle or not DoesEntityExist(vehicle)) and GetGameTimer() < deadline do
        vehicle = NetToVeh(netId)
        Wait(200)
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        job.active = false
        lib.notify({ title = _U('no_active_job'), type = 'error' })
        return
    end

    job.vehicle = vehicle

    -- Blip del radio de la zona seleccionada + blip exacto del vehículo
    blips.zone    = MakeZoneBlip(zoneCx, zoneCy, zoneCz, zoneRadius)
    blips.vehicle = MakeVehicleBlip(vec3(spawnX, spawnY, spawnZ))
    blips.shop    = MakeShopBlip()

    -- Añadir zona de entrega en el desguace
    AddDeliveryZone()

    lib.notify({ title = _U('job_accepted'), type = 'success', duration = 8000 })
    Log('Trabajo iniciado. NetId:', netId)
end)

-- ─── Pieza vendida (confirmación del servidor) ────────────────────────────────

RegisterNetEvent('yn-chopshop:client:partSold', function(partId, reward, allSold)
    job.sold[partId]  = true
    job.totalEarned   = job.totalEarned + reward

    DetachProp()

    lib.notify({ title = _U('part_sold', reward), type = 'success' })
    Log('Pieza vendida:', partId, 'Recompensa:', reward)

    if allSold then
        FinishJob()
    end
end)

-- ─── Trabajo no disponible ────────────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:client:jobUnavailable', function()
    lib.notify({ title = _U('job_unavailable'), type = 'error' })
end)

RegisterNetEvent('yn-chopshop:client:cooldown', function()
    lib.notify({ title = _U('job_cooldown'), type = 'warning' })
end)

RegisterNetEvent('yn-chopshop:client:alreadyInJob', function()
    lib.notify({ title = _U('job_already_active'), type = 'warning' })
end)

-- ─── Thread: Marcador visual en el desguace ───────────────────────────────────
-- Dibuja un cilindro en el suelo solo cuando el jugador tiene trabajo activo
-- y aún no ha entregado el vehículo.

CreateThread(function()
    while true do
        if job.active and not job.atChopShop then
            local c = Config.ChopShop.coords
            DrawMarker(
                1,                  -- tipo: cilindro
                c.x, c.y, c.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                Config.ChopShop.radius * 2.0,
                Config.ChopShop.radius * 2.0,
                0.8,
                255, 140, 0, 80,    -- color naranja semitransparente
                false, false, 2, false, nil, nil, false
            )
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- ─── Limpieza al detener el recurso ──────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DetachProp()
    DespawnBuyer()
    RemoveDeliveryZone()
    if job.vehicle and DoesEntityExist(job.vehicle) then
        RemoveVehicleTargets(job.vehicle)
    end
end)
