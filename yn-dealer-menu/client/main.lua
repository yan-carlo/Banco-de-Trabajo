-- ─────────────────────────────────────────────────────────────────────────────
-- client/main.lua  —  yn-dealer-menu
-- ─────────────────────────────────────────────────────────────────────────────

local Framework     = nil
local FrameworkName = nil

-- Cache local de listings activos  { id, seller_name, model_hash, price, pos_x … }
local activeListings   = {}
local lastRefresh      = 0

-- Blips asociados a listings  [recordId] = blipHandle
local saleBlips = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Inicialización del framework
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers locales
-- ─────────────────────────────────────────────────────────────────────────────
local function Notify(msg, nType, duration)
    lib.notify({ title = 'Dealer', description = msg, type = nType or 'info', duration = duration or 5000 })
end

local function IsDealer()
    if not Framework then return false end
    local job
    if FrameworkName == 'esx' then
        local pd = Framework.GetPlayerData()
        job = pd and pd.job and pd.job.name
    elseif FrameworkName == 'qbcore' then
        local pd = Framework.Functions.GetPlayerData()
        job = pd and pd.job and pd.job.name
    end
    return job == Config.DealerJob
end

-- Devuelve el vehículo si el jugador local es el conductor; nil si no
local function GetDrivenVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Gestión de blips
-- ─────────────────────────────────────────────────────────────────────────────
local function AddSaleBlip(listing)
    local blip = AddBlipForCoord(listing.pos_x, listing.pos_y, listing.pos_z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(listing.model_hash .. '  $' .. YND_FormatMoney(listing.price))
    EndTextCommandSetBlipName(blip)
    return blip
end

local function RemoveSaleBlip(recordId)
    if saleBlips[recordId] then
        RemoveBlip(saleBlips[recordId])
        saleBlips[recordId] = nil
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Sincronización de listings
-- ─────────────────────────────────────────────────────────────────────────────
local function ApplyListings(listings)
    -- Eliminar blips de listings que ya no existen
    local newIds = {}
    for _, l in ipairs(listings) do newIds[l.id] = true end
    for id in pairs(saleBlips) do
        if not newIds[id] then RemoveSaleBlip(id) end
    end
    -- Añadir blips nuevos
    for _, listing in ipairs(listings) do
        if not saleBlips[listing.id] then
            saleBlips[listing.id] = AddSaleBlip(listing)
        end
    end
    activeListings = listings
end

local function RefreshListings()
    -- Marcar refresh inmediatamente para evitar llamadas duplicadas mientras el callback está en vuelo
    lastRefresh = GetGameTimer()
    lib.callback('yn-dealer:cb:getListings', false, function(listings)
        if listings then ApplyListings(listings) end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Construcción de submenús del vehículo en venta
-- ─────────────────────────────────────────────────────────────────────────────
local function BuildPerfOptions(vd)
    local p = type(vd.performance) == 'table' and vd.performance or {}
    return {
        { title = _U('perf_engine'),       description = YND_ModLevel(p.engine),       disabled = true },
        { title = _U('perf_brakes'),       description = YND_ModLevel(p.brakes),       disabled = true },
        { title = _U('perf_transmission'), description = YND_ModLevel(p.transmission), disabled = true },
        { title = _U('perf_suspension'),   description = YND_ModLevel(p.suspension),   disabled = true },
        { title = _U('perf_armor'),        description = YND_ModLevel(p.armor),        disabled = true },
        { title = _U('perf_turbo'),        description = p.turbo and _U('yes') or _U('no'), disabled = true },
    }
end

local function BuildCosOptions(vd)
    local c = type(vd.colors)    == 'table' and vd.colors    or {}
    local a = type(vd.aesthetic) == 'table' and vd.aesthetic or {}
    local n = type(vd.neon)      == 'table' and vd.neon      or {}

    -- Color primario
    local primStr
    if c.prim_custom then
        primStr = _U('custom_rgb', c.prim_r, c.prim_g, c.prim_b)
    else
        primStr = _U('color_index', c.prim_index)
    end

    -- Color secundario
    local secStr
    if c.sec_custom then
        secStr = _U('custom_rgb', c.sec_r, c.sec_g, c.sec_b)
    else
        secStr = _U('color_index', c.sec_index)
    end

    -- Neones
    local neonActive = n.left or n.right or n.front or n.back
    local neonStr = neonActive
        and ('RGB(' .. n.r .. ',' .. n.g .. ',' .. n.b .. ')')
        or _U('none')

    -- Extras
    local extraList = {}
    if vd.extras then
        for k, v in pairs(vd.extras) do
            if v then extraList[#extraList + 1] = k end
        end
        table.sort(extraList, function(a, b) return tonumber(a) < tonumber(b) end)
    end
    local extraStr = #extraList > 0 and table.concat(extraList, ', ') or _U('none')

    return {
        { title = _U('cos_primary'),   description = primStr,                                                              disabled = true },
        { title = _U('cos_secondary'), description = secStr,                                                               disabled = true },
        { title = _U('cos_pearl'),     description = c.pearl  ~= nil and _U('color_index', c.pearl)  or _U('none'),       disabled = true },
        { title = _U('cos_wheel'),     description = c.wheel  ~= nil and _U('color_index', c.wheel)  or _U('none'),       disabled = true },
        { title = _U('cos_tint'),      description = a.tint   ~= nil and tostring(a.tint)            or _U('none'),       disabled = true },
        { title = _U('cos_xenon'),     description = a.xenon  and _U('yes') or _U('no'),                                  disabled = true },
        { title = _U('cos_neon'),      description = neonStr,                                                              disabled = true },
        { title = _U('cos_livery'),    description = (a.livery and a.livery >= 0) and tostring(a.livery) or _U('none'),   disabled = true },
        { title = _U('cos_extras'),    description = extraStr,                                                             disabled = true },
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Menú de detalle para el comprador
-- ─────────────────────────────────────────────────────────────────────────────
local function OpenVehicleMenu(listing)
    local ok, vd = pcall(json.decode, listing.vehicle_data)
    if not ok or type(vd) ~= 'table' then
        Notify(_U('error_generic'), 'error')
        return
    end

    local priceStr = YND_FormatMoney(listing.price)

    -- Registrar submenú de rendimiento
    lib.registerContext({
        id    = 'ynd_perf',
        title = _U('menu_performance'),
        menu  = 'ynd_vehicle',
        options = BuildPerfOptions(vd),
    })

    -- Registrar submenú de personalización
    lib.registerContext({
        id    = 'ynd_cos',
        title = _U('menu_cosmetics'),
        menu  = 'ynd_vehicle',
        options = BuildCosOptions(vd),
    })

    -- Opciones del menú principal del vehículo
    local options = {
        { title = _U('menu_seller'),      description = listing.seller_name, disabled = true },
        { title = _U('menu_price_label'), description = '$' .. priceStr,     disabled = true },
    }

    -- Descripción opcional
    if listing.description and listing.description ~= '' then
        options[#options + 1] = {
            title       = _U('menu_description'),
            description = listing.description,
            disabled    = true,
        }
    end

    options[#options + 1] = {
        title    = _U('menu_performance'),
        arrow    = true,
        onSelect = function() lib.showContext('ynd_perf') end,
    }
    options[#options + 1] = {
        title    = _U('menu_cosmetics'),
        arrow    = true,
        onSelect = function() lib.showContext('ynd_cos') end,
    }
    options[#options + 1] = {
        title    = _U('menu_buy', priceStr),
        onSelect = function()
            local confirm = lib.alertDialog({
                header   = _U('menu_vehicle_title'),
                content  = _U('confirm_buy', listing.model_hash, priceStr),
                centered = true,
                cancel   = true,
            })
            if confirm == 'confirm' then
                TriggerServerEvent('yn-dealer:server:buyVehicle', listing.id)
            end
        end,
    }
    options[#options + 1] = { title = _U('menu_close') }

    lib.registerContext({
        id      = 'ynd_vehicle',
        title   = listing.model_hash .. '  —  $' .. priceStr,
        options = options,
    })
    lib.showContext('ynd_vehicle')
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Flujo: poner vehículo en venta
-- ─────────────────────────────────────────────────────────────────────────────
local function ListVehicleFlow()
    local veh = GetDrivenVehicle()
    if not veh then
        Notify(_U('not_driver'), 'error')
        return
    end

    local input = lib.inputDialog(_U('menu_list_vehicle'), {
        { type = 'number', label = _U('input_price'),   placeholder = _U('input_price_ph'), required = true, min = 1 },
        { type = 'input',  label = _U('input_desc'),    placeholder = _U('input_desc_ph'),  required = false, max = 200 },
    })

    if not input then
        Notify(_U('input_cancelled'), 'info')
        return
    end

    local price = tonumber(input[1])
    if not price or price <= 0 then
        Notify(_U('invalid_price'), 'error')
        return
    end

    local plate   = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    local model   = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local coords  = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local netId   = NetworkGetNetworkIdFromEntity(veh)
    local vData   = YND_GetVehicleData(veh)

    TriggerServerEvent('yn-dealer:server:listVehicle', {
        plate        = plate,
        model        = model,
        price        = price,
        description  = input[2] or '',
        pos_x        = coords.x,
        pos_y        = coords.y,
        pos_z        = coords.z,
        pos_h        = heading,
        network_id   = netId,
        vehicle_data = json.encode(vData),
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Flujo: traspaso de vehículo
-- ─────────────────────────────────────────────────────────────────────────────
local function TransferVehicleFlow()
    local veh = GetDrivenVehicle()
    if not veh then
        Notify(_U('not_driver'), 'error')
        return
    end

    local input = lib.inputDialog(_U('menu_transfer'), {
        { type = 'number', label = _U('input_target_id'), placeholder = _U('input_target_ph'), required = true, min = 1 },
    })

    if not input then
        Notify(_U('input_cancelled'), 'info')
        return
    end

    local targetId = tonumber(input[1])
    if not targetId or targetId < 1 then
        Notify(_U('invalid_target'), 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    TriggerServerEvent('yn-dealer:server:initiateTransfer', targetId, plate)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Flujo: mis vehículos en venta
-- ─────────────────────────────────────────────────────────────────────────────
local function OpenMyVehiclesMenu()
    lib.callback('yn-dealer:cb:getMyListings', false, function(listings)
        if not listings or #listings == 0 then
            Notify(_U('menu_no_vehicles'), 'info')
            return
        end

        local options = {}
        for _, listing in ipairs(listings) do
            local l = listing -- captura local para el closure
            options[#options + 1] = {
                title       = l.model_hash .. '  —  $' .. YND_FormatMoney(l.price),
                description = _U('menu_cancel_desc'),
                onSelect    = function()
                    local confirm = lib.alertDialog({
                        header   = _U('menu_cancel_listing'),
                        content  = _U('confirm_cancel'),
                        centered = true,
                        cancel   = true,
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('yn-dealer:server:cancelListing', l.id)
                    end
                end,
            }
        end

        lib.registerContext({
            id      = 'ynd_my_vehicles',
            title   = _U('menu_my_vehicles'),
            menu    = 'ynd_dealer',
            options = options,
        })
        lib.showContext('ynd_my_vehicles')
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Menú principal del dealer
-- ─────────────────────────────────────────────────────────────────────────────
local function OpenDealerMenu()
    local isDriver = GetDrivenVehicle() ~= nil

    lib.registerContext({
        id      = 'ynd_dealer',
        title   = _U('menu_dealer_title'),
        options = {
            {
                title       = _U('menu_list_vehicle'),
                description = isDriver and _U('menu_list_desc') or _U('menu_disabled_no_veh'),
                disabled    = not isDriver,
                onSelect    = function() ListVehicleFlow() end,
            },
            {
                title       = _U('menu_transfer'),
                description = isDriver and _U('menu_transfer_desc') or _U('menu_disabled_no_veh'),
                disabled    = not isDriver,
                onSelect    = function() TransferVehicleFlow() end,
            },
            {
                title       = _U('menu_my_vehicles'),
                description = _U('menu_my_vehicles_desc'),
                onSelect    = function() OpenMyVehiclesMenu() end,
            },
        },
    })
    lib.showContext('ynd_dealer')
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Comando /dealer
-- ─────────────────────────────────────────────────────────────────────────────
RegisterCommand(Config.DealerCommand, function()
    if not IsDealer() then
        Notify(_U('no_job'), 'error')
        return
    end
    OpenDealerMenu()
end, false)

-- ─────────────────────────────────────────────────────────────────────────────
-- Hilo de proximidad — detección de vehículos en venta
-- ─────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    Wait(3000) -- espera a que el framework y el servidor inicialicen
    RefreshListings()

    while true do
        local now          = GetGameTimer()
        local playerCoords = GetEntityCoords(PlayerPedId())

        -- Refresco periódico de la lista
        if (now - lastRefresh) > Config.ListingsRefresh then
            RefreshListings()
        end

        -- Buscar el listing más cercano dentro del rango
        local closestListing = nil
        local closestDist    = Config.InteractionDist + 1

        for _, listing in ipairs(activeListings) do
            local lCoords = vector3(listing.pos_x, listing.pos_y, listing.pos_z)
            local dist    = #(playerCoords - lCoords)
            if dist < closestDist then
                closestDist    = dist
                closestListing = listing
            end
        end

        if closestListing then
            -- Mostrar hint y esperar interacción
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(_U('press_e'))
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, 38) then -- E
                OpenVehicleMenu(closestListing)
            end
            Wait(0)
        else
            Wait(Config.PollingInterval)
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Eventos del servidor → cliente
-- ─────────────────────────────────────────────────────────────────────────────

-- Sincronizar lista completa de listings (se envía al conectar y en cada cambio)
RegisterNetEvent('yn-dealer:client:syncListings', function(listings)
    ApplyListings(listings or {})
end)

-- El vendedor congela su vehículo tras confirmación del servidor
RegisterNetEvent('yn-dealer:client:freezeVehicle', function(networkId, recordId, model, price)
    local veh = NetworkDoesNetworkIdExist(networkId) and NetToVeh(networkId) or 0
    if veh ~= 0 then
        FreezeEntityPosition(veh, true)
        SetEntityInvincible(veh, true)
    end
    Notify(_U('vehicle_listed', YND_FormatMoney(price)), 'success')
    RefreshListings()
end)

-- Vehículo vendido o cancelado: descongelar entidad y limpiar blip en todos los clientes
RegisterNetEvent('yn-dealer:client:vehicleSoldSync', function(networkId, recordId)
    local veh = NetworkDoesNetworkIdExist(networkId) and NetToVeh(networkId) or 0
    if veh ~= 0 then
        FreezeEntityPosition(veh, false)
        SetEntityInvincible(veh, false)
    end
    RemoveSaleBlip(recordId)
    for i, l in ipairs(activeListings) do
        if l.id == recordId then
            table.remove(activeListings, i)
            break
        end
    end
end)

-- Solicitud de traspaso recibida por el target
RegisterNetEvent('yn-dealer:client:transferRequest', function(data)
    -- data = { dealerName, plate, model, expireSeconds }
    CreateThread(function()
        local confirm = lib.alertDialog({
            header   = _U('menu_transfer'),
            content  = _U('transfer_request', data.dealerName, data.model, data.plate),
            centered = true,
            cancel   = true,
        })
        TriggerServerEvent('yn-dealer:server:respondTransfer', confirm == 'confirm')
    end)
end)

-- Notificación genérica desde el servidor
RegisterNetEvent('yn-dealer:client:notify', function(msg, msgType)
    Notify(msg, msgType or 'info')
end)

-- Sincronizar al arrancar el recurso
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(3000)
    RefreshListings()
end)
