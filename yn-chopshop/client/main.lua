print('[yn-chopshop] Cliente cargando...')

-- ─── Estado del trabajo ───────────────────────────────────────────────────────

local job = {
    active        = false,
    vehicle       = nil,
    netId         = nil,
    atChopShop    = false,
    removed       = {},
    sold          = {},
    heldPartId    = nil,
    heldPropEnt   = nil,
    policeAlerted = false,
    totalEarned   = 0,
    removing      = false,
}

local blips              = { vehicle = nil, zone = nil, shop = nil }
local buyerPed           = nil
local showingDelivUI     = false  -- estado del TextUI de entrega
local playerInTargetVeh  = false  -- true cuando el jugador está dentro del vehículo objetivo

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

-- ─── NPC comprador del desguace ───────────────────────────────────────────────

local function SpawnBuyer()
    local c   = Config.ChopShop.coords
    local off = Config.BuyerNPC.offset
    local x, y, z = c.x + off.x, c.y + off.y, c.z + off.z

    print('[yn-chopshop] Spawneando NPC comprador en:', x, y, z)

    local hash = LoadModel(Config.BuyerNPC.model)
    if not hash then
        print('[yn-chopshop] ERROR: No se pudo cargar modelo del comprador:', Config.BuyerNPC.model)
        return
    end

    buyerPed = CreatePed(4, hash, x, y, z, c.w, false, true)

    -- Esperar a que el juego registre la entidad antes de configurarla
    local deadline = GetGameTimer() + 3000
    while not DoesEntityExist(buyerPed) and GetGameTimer() < deadline do
        Wait(50)
    end

    if not DoesEntityExist(buyerPed) then
        print('[yn-chopshop] ERROR: CreatePed falló para el NPC comprador')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    FreezeEntityPosition(buyerPed, true)
    SetEntityInvincible(buyerPed, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(buyerPed, {
        {
            name     = 'yn_chopshop_sell_part',
            label    = _U('sell_part'),
            icon     = 'fas fa-hand-holding-usd',
            distance = Config.TargetDistance,
            onSelect = function()
                SellCurrentPart()
            end,
            canInteract = function()
                return job.heldPartId ~= nil and not job.removing
            end,
        }
    })

    print('[yn-chopshop] NPC comprador listo. Entity:', buyerPed)
end

local function DespawnBuyer()
    if buyerPed and DoesEntityExist(buyerPed) then
        exports.ox_target:removeLocalEntity(buyerPed)
        DeleteEntity(buyerPed)
    end
    buyerPed = nil
end

-- ─── Targets de desmontaje en el vehículo ────────────────────────────────────

local function AddVehicleTargets(vehicle)
    local options = {}
    for _, part in ipairs(Config.Parts) do
        local p = part
        table.insert(options, {
            -- IMPORTANTE: 'name' único por pieza, requerido en ox_target v3+
            name     = 'yn_chopshop_remove_' .. p.id,
            label    = _U('remove_part', p.label),
            icon     = 'fas fa-tools',
            distance = Config.TargetDistance,
            onSelect = function()
                -- ox_target callback: crear thread propio para permitir Wait/progressBar
                CreateThread(function()
                    StartRemovePart(vehicle, p)
                end)
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
    Log('Targets de desmontaje añadidos al vehículo')
end

local function RemoveVehicleTargets(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        exports.ox_target:removeLocalEntity(vehicle)
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

    -- Efecto visual en el vehículo
    if partCfg.type == 'door' then
        SetVehicleDoorBroken(vehicle, partCfg.index, true)
    elseif partCfg.type == 'wheel' then
        SetVehicleTyreBurst(vehicle, partCfg.index, true, 1000.0)
        pcall(function() SetVehicleWheelBroken(vehicle, partCfg.index, true) end)
    end

    job.removed[partCfg.id] = true
    job.heldPartId           = partCfg.id
    AttachProp(partCfg)

    -- Primera pieza → alerta policial
    if not job.policeAlerted then
        job.policeAlerted = true
        TriggerServerEvent('yn-chopshop:server:policeAlert', GetEntityCoords(vehicle))
    end

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
-- Llamada desde un CreateThread para poder usar Wait() sin bloquear callbacks

local function DeliverVehicle()
    if not job.active or job.atChopShop then return end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= job.vehicle then
        lib.notify({ title = _U('must_be_in_vehicle'), type = 'error' })
        return
    end

    print('[yn-chopshop] DeliverVehicle iniciado. Sacando al jugador del vehículo...')

    TaskLeaveVehicle(ped, job.vehicle, 0)
    Wait(1500)

    SetVehicleDoorsLocked(job.vehicle, 10)
    SetVehicleEngineOn(job.vehicle, false, true, false)

    job.atChopShop = true

    blips.vehicle = ClearBlip(blips.vehicle)
    blips.zone    = ClearBlip(blips.zone)

    AddVehicleTargets(job.vehicle)
    SpawnBuyer()

    lib.notify({ title = _U('vehicle_delivered'), type = 'success', duration = 8000 })
    Log('Vehículo entregado al desguace')
end

-- ─── Finalizar trabajo ────────────────────────────────────────────────────────

local function FinishJob()
    lib.notify({ title = _U('all_parts_sold'), type = 'success', duration = 6000 })
    Wait(1000)
    lib.notify({ title = _U('job_complete', tostring(job.totalEarned)), type = 'success', duration = 8000 })

    if job.vehicle and DoesEntityExist(job.vehicle) then
        RemoveVehicleTargets(job.vehicle)
        DeleteEntity(job.vehicle)
    end

    DespawnBuyer()
    DetachProp()

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

    playerInTargetVeh = false

    Log('Trabajo finalizado')
end

-- ─── Thread: Entrega del vehículo (TextUI + tecla E) ─────────────────────────
-- Usando TextUI en lugar de ox_target zone porque ox_target no funciona
-- de forma fiable cuando el jugador está dentro de un vehículo.

CreateThread(function()
    while true do
        if job.active and not job.atChopShop then
            local ped      = PlayerPedId()
            local c        = Config.ChopShop.coords
            local dist     = #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z))
            local inTarget = IsPedInAnyVehicle(ped, false)
                             and GetVehiclePedIsIn(ped, false) == job.vehicle

            if dist < Config.ChopShop.radius and inTarget then
                if not showingDelivUI then
                    lib.showTextUI(_U('deliver_vehicle'))
                    showingDelivUI = true
                end
                -- Tecla E = INPUT_CONTEXT (51) para confirmar entrega
                if IsControlJustReleased(0, 51) then
                    lib.hideTextUI()
                    showingDelivUI = false
                    CreateThread(DeliverVehicle)
                end
                Wait(0)
            else
                if showingDelivUI then
                    lib.hideTextUI()
                    showingDelivUI = false
                end
                -- Espera más corta cuando se está aproximando
                Wait(dist < Config.ChopShop.radius * 4 and 200 or 1000)
            end
        else
            if showingDelivUI then
                lib.hideTextUI()
                showingDelivUI = false
            end
            Wait(1000)
        end
    end
end)

-- ─── Thread: Detección de entrada al vehículo objetivo ───────────────────────
-- Cuando el jugador se monta en el vehículo robado por primera vez:
--   · Elimina el blip del coche y el radio de búsqueda del mapa
--   · Muestra el blip del desguace y activa la ruta GPS hacia él

CreateThread(function()
    while true do
        if job.active and not job.atChopShop and job.vehicle then
            local ped      = PlayerPedId()
            local inTarget = IsPedInAnyVehicle(ped, false)
                             and GetVehiclePedIsIn(ped, false) == job.vehicle

            if inTarget and not playerInTargetVeh then
                playerInTargetVeh = true

                -- Eliminar blips de búsqueda
                blips.vehicle = ClearBlip(blips.vehicle)
                blips.zone    = ClearBlip(blips.zone)

                -- Mostrar blip del desguace y marcar ruta GPS
                if not blips.shop then
                    blips.shop = MakeShopBlip()
                end
                SetNewWaypoint(Config.ChopShop.coords.x, Config.ChopShop.coords.y)

                Log('Jugador montado en vehículo objetivo → blips actualizados')

            elseif not inTarget and playerInTargetVeh then
                -- Jugador salió del vehículo antes de entregarlo (blips ya actualizados)
                playerInTargetVeh = false
            end

            Wait(500)
        else
            playerInTargetVeh = false
            Wait(1000)
        end
    end
end)

-- ─── Thread: Marcador visual del desguace ────────────────────────────────────

CreateThread(function()
    while true do
        if job.active and not job.atChopShop then
            local c = Config.ChopShop.coords
            DrawMarker(
                1,
                c.x, c.y, c.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                Config.ChopShop.radius * 2.0,
                Config.ChopShop.radius * 2.0,
                0.8,
                255, 140, 0, 80,
                false, false, 2, false, nil, nil, false
            )
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- ─── Spawn del vehículo (orden del servidor) ──────────────────────────────────

RegisterNetEvent('yn-chopshop:client:spawnVehicle', function(data)
    Log('Spawneando vehículo:', data.model, 'en', data.x, data.y, data.z)

    local hash = LoadModel(data.model)
    if not hash then
        print('[yn-chopshop] ERROR: No se pudo cargar el modelo del vehículo:', data.model)
        TriggerServerEvent('yn-chopshop:server:spawnFailed')
        return
    end

    local vehicle = CreateVehicle(hash, data.x, data.y, data.z, data.heading, true, false)
    SetVehicleEngineOn(vehicle, false, true, false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetModelAsNoLongerNeeded(hash)

    local netId    = 0
    local deadline = GetGameTimer() + 6000
    while (not netId or netId == 0) and GetGameTimer() < deadline do
        Wait(100)
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    end

    if not netId or netId == 0 then
        print('[yn-chopshop] ERROR: No se pudo obtener netId del vehículo')
        DeleteEntity(vehicle)
        TriggerServerEvent('yn-chopshop:server:spawnFailed')
        return
    end

    TriggerServerEvent('yn-chopshop:server:vehicleSpawned', netId, data.x, data.y, data.z)
    Log('Vehículo spawneado. NetId:', netId)
end)

-- ─── Inicio del trabajo ───────────────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:client:startJob', function(netId, spawnX, spawnY, spawnZ, zoneCx, zoneCy, zoneCz, zoneRadius)
    if job.active then return end

    Log('Iniciando trabajo. NetId:', netId)

    job.active        = true
    job.netId         = netId
    job.removed       = {}
    job.sold          = {}
    job.policeAlerted = false
    job.totalEarned   = 0
    job.atChopShop    = false

    local vehicle  = nil
    local deadline = GetGameTimer() + 10000
    while (not vehicle or not DoesEntityExist(vehicle)) and GetGameTimer() < deadline do
        vehicle = NetToVeh(netId)
        Wait(200)
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        print('[yn-chopshop] ERROR: No se pudo obtener el vehículo con netId:', netId)
        job.active = false
        lib.notify({ title = _U('no_active_job'), type = 'error' })
        return
    end

    job.vehicle = vehicle

    -- Solo mostrar blips de búsqueda al inicio.
    -- El blip del desguace + GPS aparecerán cuando el jugador se monte en el vehículo.
    blips.zone    = MakeZoneBlip(zoneCx, zoneCy, zoneCz, zoneRadius)
    blips.vehicle = MakeVehicleBlip(vec3(spawnX, spawnY, spawnZ))

    lib.notify({ title = _U('job_accepted'), type = 'success', duration = 8000 })
    Log('Trabajo iniciado correctamente. Vehículo entity:', vehicle)
end)

-- ─── Pieza vendida (confirmación del servidor) ────────────────────────────────

RegisterNetEvent('yn-chopshop:client:partSold', function(partId, reward, allSold)
    job.sold[partId] = true
    job.totalEarned  = job.totalEarned + reward

    DetachProp()

    lib.notify({ title = _U('part_sold', reward), type = 'success' })
    Log('Pieza vendida:', partId, '| Recompensa:', reward, '| Todas vendidas:', allSold)

    if allSold then
        CreateThread(FinishJob)
    end
end)

-- ─── Respuestas del servidor ──────────────────────────────────────────────────

RegisterNetEvent('yn-chopshop:client:jobUnavailable', function()
    lib.notify({ title = _U('job_unavailable'), type = 'error' })
end)

RegisterNetEvent('yn-chopshop:client:cooldown', function()
    lib.notify({ title = _U('job_cooldown'), type = 'warning' })
end)

RegisterNetEvent('yn-chopshop:client:alreadyInJob', function()
    lib.notify({ title = _U('job_already_active'), type = 'warning' })
end)

-- ─── Limpieza al detener el recurso ──────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if showingDelivUI then lib.hideTextUI() end
    DetachProp()
    DespawnBuyer()
    if job.vehicle and DoesEntityExist(job.vehicle) then
        RemoveVehicleTargets(job.vehicle)
    end
end)

print('[yn-chopshop] Cliente cargado correctamente.')
