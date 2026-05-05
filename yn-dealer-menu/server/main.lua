-- ─────────────────────────────────────────────────────────────────────────────
-- server/main.lua  —  yn-dealer-menu
-- ─────────────────────────────────────────────────────────────────────────────

local Framework     = nil
local FrameworkName = nil

local cooldowns        = {}  -- [source_action] = GetGameTimer()
local transferRequests = {}  -- [targetSource]  = { dealer, plate, model, expireAt }

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

        AddEventHandler('esx:playerLoaded', function(playerId)
            SetTimeout(3000, function()
                if GetPlayerName(playerId) then
                    YND_SyncListingsToPlayer(playerId)
                end
            end)
        end)

    elseif FrameworkName == 'qbcore' then
        Framework = exports['qb-core']:GetCoreObject()

        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
            local src = Player.PlayerData.source
            SetTimeout(3000, function()
                if GetPlayerName(src) then
                    YND_SyncListingsToPlayer(src)
                end
            end)
        end)
    end

    if not FrameworkName then
        print('[yn-dealer][WARN] No se detectó ningún framework. Comprueba Config.Framework.')
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers — expuestos con prefijo YND_ para que callbacks.lua los use
-- ─────────────────────────────────────────────────────────────────────────────
function YND_GetIdentifier(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
end

local function GetCharacterName(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.getName and xPlayer.getName() or xPlayer.name or GetPlayerName(source)
        end
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then
            local ci = Player.PlayerData.charinfo
            if ci then return ci.firstname .. ' ' .. ci.lastname end
        end
    end
    return GetPlayerName(source)
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

local function IsDealer(source)
    return GetJob(source) == Config.DealerJob
end

local function GetBankMoney(source)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        local acc = xPlayer.getAccount('bank')
        return acc and acc.money or 0
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if not Player then return 0 end
        return Player.PlayerData.money['bank'] or 0
    end
    return 0
end

local function RemoveBankMoney(source, amount)
    if FrameworkName == 'esx' then
        local xPlayer = Framework.GetPlayerFromId(source)
        if xPlayer then xPlayer.removeAccountMoney('bank', amount) end
    elseif FrameworkName == 'qbcore' then
        local Player = Framework.Functions.GetPlayer(source)
        if Player then Player.Functions.RemoveMoney('bank', amount, 'yn-dealer-buy') end
    end
end

-- Busca el source de un jugador por su identifier
local function FindSourceByIdentifier(identifier)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if YND_GetIdentifier(src) == identifier then return src end
    end
    return nil
end

local function CheckCooldown(source, action, ms)
    local key = source .. '_' .. action
    local now = GetGameTimer()
    if cooldowns[key] and (now - cooldowns[key]) < ms then return false end
    cooldowns[key] = now
    return true
end

local function NotifyClient(source, msg, msgType)
    TriggerClientEvent('yn-dealer:client:notify', source, msg, msgType or 'info')
end

local function DebugPrint(...)
    if Config.Debug then print('[yn-dealer]', ...) end
end

local function LogError(msg, ...)
    print(('[yn-dealer][ERROR] ' .. msg):format(...))
end

local function FmtMoney(n)
    n = math.floor(tonumber(n) or 0)
    local s, result, count = tostring(n), '', 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then result = ',' .. result end
        result = s:sub(i, i) .. result
        count  = count + 1
    end
    return result
end

local function DepositToLocal(amount, plate)
    local ok, err = pcall(function()
        exports[Config.MasterjobResource]:depositMoney(
            Config.MasterjobAccount,
            amount,
            'Venta vehiculo: ' .. plate
        )
    end)
    if not ok then
        LogError('Error al depositar en masterjob: %s', tostring(err))
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Sincronización de listings
-- ─────────────────────────────────────────────────────────────────────────────
function YND_SyncListingsToPlayer(source)
    local listings = MySQL.query.await(
        'SELECT id, seller_name, model_hash, price, description, pos_x, pos_y, pos_z, pos_h, network_id, vehicle_data FROM dealer_vehicles WHERE status = ?',
        { 'sale' }
    )
    TriggerClientEvent('yn-dealer:client:syncListings', source, listings or {})
end

local function SyncListingsToAll()
    local listings = MySQL.query.await(
        'SELECT id, seller_name, model_hash, price, description, pos_x, pos_y, pos_z, pos_h, network_id, vehicle_data FROM dealer_vehicles WHERE status = ?',
        { 'sale' }
    )
    TriggerClientEvent('yn-dealer:client:syncListings', -1, listings or {})
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Validación de ownership en BD
-- ─────────────────────────────────────────────────────────────────────────────
local function VehicleBelongsTo(identifier, plate)
    local result
    if FrameworkName == 'esx' then
        result = MySQL.query.await(
            'SELECT plate FROM owned_vehicles WHERE owner = ? AND plate = ?',
            { identifier, plate }
        )
    elseif FrameworkName == 'qbcore' then
        result = MySQL.query.await(
            'SELECT plate FROM player_vehicles WHERE citizenid = ? AND plate = ?',
            { identifier, plate }
        )
    end
    return result and #result > 0
end

local function TransferVehicleOwnership(plate, newIdentifier)
    if FrameworkName == 'esx' then
        MySQL.update(
            'UPDATE owned_vehicles SET owner = ? WHERE plate = ?',
            { newIdentifier, plate }
        )
    elseif FrameworkName == 'qbcore' then
        MySQL.update(
            'UPDATE player_vehicles SET citizenid = ? WHERE plate = ?',
            { newIdentifier, plate }
        )
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Evento: poner vehículo en venta
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('yn-dealer:server:listVehicle', function(data)
    local source = source

    if not IsDealer(source) then
        NotifyClient(source, _U('no_job'), 'error')
        return
    end

    -- Validar estructura básica
    if type(data) ~= 'table' then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    local price = tonumber(data.price)
    if not price or price < 1 or price > 99999999 then
        NotifyClient(source, _U('invalid_price'), 'error')
        return
    end

    if type(data.plate) ~= 'string' or #data.plate < 1 or #data.plate > 8 then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    if type(data.model) ~= 'string' or #data.model < 1 or #data.model > 50 then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    if type(data.vehicle_data) ~= 'string' or #data.vehicle_data > 16000 then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    -- Validar que vehicle_data es JSON válido
    local ok = pcall(json.decode, data.vehicle_data)
    if not ok then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    -- Cooldown
    if not CheckCooldown(source, 'listVehicle', Config.SaleCooldown) then
        NotifyClient(source, _U('cooldown'), 'error')
        return
    end

    local identifier = YND_GetIdentifier(source)
    if not identifier then
        NotifyClient(source, _U('error_generic'), 'error')
        return
    end

    -- Verificar ownership
    if not VehicleBelongsTo(identifier, data.plate) then
        NotifyClient(source, _U('vehicle_not_owned'), 'error')
        return
    end

    -- Verificar que no está ya en venta
    local saleCheck = MySQL.query.await(
        'SELECT id FROM dealer_vehicles WHERE plate = ? AND status = ?',
        { data.plate, 'sale' }
    )
    if saleCheck and #saleCheck > 0 then
        NotifyClient(source, _U('vehicle_already_sale'), 'error')
        return
    end

    -- Verificar límite de vehículos en venta
    local countRow = MySQL.query.await(
        'SELECT COUNT(*) AS total FROM dealer_vehicles WHERE seller_id = ? AND status = ?',
        { identifier, 'sale' }
    )
    local total = countRow and countRow[1] and countRow[1].total or 0
    if total >= Config.MaxVehiclesOnSale then
        NotifyClient(source, _U('max_vehicles', Config.MaxVehiclesOnSale), 'error')
        return
    end

    local description = type(data.description) == 'string' and data.description:sub(1, 200) or ''
    local sellerName  = GetCharacterName(source)

    local insertId = MySQL.insert.await(
        'INSERT INTO dealer_vehicles (seller_id, seller_name, plate, model_hash, vehicle_data, description, price, pos_x, pos_y, pos_z, pos_h, network_id, status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
        {
            identifier, sellerName,
            data.plate, data.model, data.vehicle_data, description,
            price,
            data.pos_x, data.pos_y, data.pos_z, data.pos_h,
            data.network_id,
            'sale',
        }
    )

    if not insertId then
        NotifyClient(source, _U('error_generic'), 'error')
        return
    end

    DebugPrint('Listado:', data.plate, 'por', identifier, '- $' .. price)

    -- Congelar vehículo en el cliente del vendedor
    TriggerClientEvent('yn-dealer:client:freezeVehicle', source, data.network_id, insertId, data.model, price)

    -- Sincronizar con todos
    SyncListingsToAll()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Evento: comprar vehículo
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('yn-dealer:server:buyVehicle', function(recordId)
    local source = source

    if type(recordId) ~= 'number' then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    -- Anti-spam corto para evitar doble-click
    if not CheckCooldown(source, 'buyVehicle', 3000) then return end

    local buyerIdentifier = YND_GetIdentifier(source)
    if not buyerIdentifier then
        NotifyClient(source, _U('error_generic'), 'error')
        return
    end

    -- Obtener listing con lock optimista
    local rows = MySQL.query.await(
        'SELECT * FROM dealer_vehicles WHERE id = ? AND status = ?',
        { recordId, 'sale' }
    )
    if not rows or #rows == 0 then
        NotifyClient(source, _U('vehicle_not_found'), 'error')
        return
    end
    local listing = rows[1]

    -- El comprador no puede ser el mismo que el vendedor
    if listing.seller_id == buyerIdentifier then
        NotifyClient(source, _U('own_vehicle_buy'), 'error')
        return
    end

    -- Verificar fondos
    local money = GetBankMoney(source)
    if money < listing.price then
        NotifyClient(source, _U('no_funds'), 'error')
        return
    end

    -- Lock optimista: intentar actualizar solo si sigue en 'sale'
    local updated = MySQL.update.await(
        'UPDATE dealer_vehicles SET status = ? WHERE id = ? AND status = ?',
        { 'sold', recordId, 'sale' }
    )
    if not updated or updated == 0 then
        NotifyClient(source, _U('vehicle_not_found'), 'error')
        return
    end

    -- Descontar dinero al comprador
    RemoveBankMoney(source, listing.price)

    -- Transferir propiedad en BD
    TransferVehicleOwnership(listing.plate, buyerIdentifier)

    -- Calcular importe neto y depositar en el local
    local netAmount = listing.price
    if Config.CommissionPct and Config.CommissionPct > 0 then
        netAmount = math.floor(listing.price * (1 - Config.CommissionPct / 100))
    end
    DepositToLocal(netAmount, listing.plate)

    DebugPrint('Venta:', listing.plate, 'a', buyerIdentifier, '- $' .. listing.price)

    -- Descongelar entidad en todos los clientes y limpiar blip
    TriggerClientEvent('yn-dealer:client:vehicleSoldSync', -1, listing.network_id, recordId)

    -- Notificar al comprador
    NotifyClient(source, _U('vehicle_sold_buyer', listing.model_hash, FmtMoney(listing.price)), 'success')

    -- Notificar al vendedor si está conectado
    local sellerSource = FindSourceByIdentifier(listing.seller_id)
    if sellerSource then
        NotifyClient(sellerSource, _U('vehicle_sold_seller', listing.model_hash, FmtMoney(listing.price)), 'success')
    end

    -- Sincronizar listings actualizados
    SyncListingsToAll()
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Evento: retirar vehículo de venta
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('yn-dealer:server:cancelListing', function(recordId)
    local source = source

    if type(recordId) ~= 'number' then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    local identifier = YND_GetIdentifier(source)
    if not identifier then
        NotifyClient(source, _U('error_generic'), 'error')
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM dealer_vehicles WHERE id = ? AND seller_id = ? AND status = ?',
        { recordId, identifier, 'sale' }
    )
    if not rows or #rows == 0 then
        NotifyClient(source, _U('vehicle_not_found'), 'error')
        return
    end
    local listing = rows[1]

    MySQL.update(
        'UPDATE dealer_vehicles SET status = ? WHERE id = ?',
        { 'cancelled', recordId }
    )

    -- Descongelar entidad (solo importa en el cliente del vendedor)
    TriggerClientEvent('yn-dealer:client:vehicleSoldSync', source, listing.network_id, recordId)
    NotifyClient(source, _U('vehicle_cancelled'), 'info')

    SyncListingsToAll()
    DebugPrint('Cancelado:', listing.plate, 'por', identifier)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Evento: iniciar traspaso de vehículo
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('yn-dealer:server:initiateTransfer', function(targetServerId, plate)
    local source = source

    if not IsDealer(source) then
        NotifyClient(source, _U('no_job'), 'error')
        return
    end

    if not CheckCooldown(source, 'initiateTransfer', 5000) then return end

    if type(targetServerId) ~= 'number' or type(plate) ~= 'string' then
        NotifyClient(source, _U('invalid_data'), 'error')
        return
    end

    if targetServerId == source then
        NotifyClient(source, _U('self_transfer'), 'error')
        return
    end

    -- Comprobar que el target existe
    if not GetPlayerName(targetServerId) then
        NotifyClient(source, _U('player_not_found'), 'error')
        return
    end

    local identifier = YND_GetIdentifier(source)
    if not identifier then
        NotifyClient(source, _U('error_generic'), 'error')
        return
    end

    -- Verificar ownership
    if not VehicleBelongsTo(identifier, plate) then
        NotifyClient(source, _U('vehicle_not_owned'), 'error')
        return
    end

    -- Comprobar solicitud pendiente para ese target
    if transferRequests[targetServerId] then
        NotifyClient(source, _U('transfer_pending'), 'error')
        return
    end

    -- Intentar obtener nombre del modelo desde la BD
    local modelName = plate
    local vRow
    if FrameworkName == 'esx' then
        vRow = MySQL.query.await(
            'SELECT vehicle FROM owned_vehicles WHERE owner = ? AND plate = ?',
            { identifier, plate }
        )
    elseif FrameworkName == 'qbcore' then
        vRow = MySQL.query.await(
            'SELECT vehicle FROM player_vehicles WHERE citizenid = ? AND plate = ?',
            { identifier, plate }
        )
    end
    if vRow and vRow[1] and vRow[1].vehicle then
        local ok2, decoded = pcall(json.decode, vRow[1].vehicle)
        if ok2 and type(decoded) == 'table' and decoded.model then
            modelName = tostring(decoded.model):upper()
        end
    end

    local dealerName = GetCharacterName(source)

    transferRequests[targetServerId] = {
        dealer   = source,
        plate    = plate,
        model    = modelName,
        expireAt = GetGameTimer() + 60000,
    }

    -- Notificar al receptor
    TriggerClientEvent('yn-dealer:client:transferRequest', targetServerId, {
        dealerName    = dealerName,
        plate         = plate,
        model         = modelName,
        expireSeconds = 60,
    })

    local targetName = GetCharacterName(targetServerId)
    NotifyClient(source, _U('transfer_sent', targetName), 'info')
    DebugPrint('Traspaso iniciado:', plate, 'de', identifier, 'a', targetServerId)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Evento: respuesta al traspaso
-- ─────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('yn-dealer:server:respondTransfer', function(accepted)
    local source = source

    local request = transferRequests[source]
    if not request then
        NotifyClient(source, _U('transfer_no_request'), 'error')
        return
    end

    -- Comprobar expiración
    if GetGameTimer() > request.expireAt then
        transferRequests[source] = nil
        NotifyClient(source, _U('transfer_expired'), 'error')
        if GetPlayerName(request.dealer) then
            NotifyClient(request.dealer, _U('transfer_expired'), 'error')
        end
        return
    end

    local dealerIdentifier = YND_GetIdentifier(request.dealer)
    local buyerIdentifier  = YND_GetIdentifier(source)

    transferRequests[source] = nil

    if not accepted then
        NotifyClient(source, _U('transfer_reject_notify', request.model), 'info')
        if GetPlayerName(request.dealer) then
            NotifyClient(request.dealer, _U('transfer_rejected'), 'error')
        end
        return
    end

    if not dealerIdentifier or not buyerIdentifier then
        NotifyClient(source, _U('error_generic'), 'error')
        return
    end

    -- Verificar que el dealer sigue siendo propietario
    if not VehicleBelongsTo(dealerIdentifier, request.plate) then
        NotifyClient(source, _U('error_generic'), 'error')
        if GetPlayerName(request.dealer) then
            NotifyClient(request.dealer, _U('vehicle_not_owned'), 'error')
        end
        return
    end

    -- Ejecutar traspaso
    TransferVehicleOwnership(request.plate, buyerIdentifier)

    NotifyClient(source, _U('transfer_accepted', request.model, request.plate), 'success')
    if GetPlayerName(request.dealer) then
        NotifyClient(request.dealer, _U('transfer_received', request.model), 'success')
    end

    DebugPrint('Traspaso completado:', request.plate, 'a', buyerIdentifier)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Limpieza periódica de solicitudes de traspaso expiradas
-- ─────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        for targetSrc, req in pairs(transferRequests) do
            if now > req.expireAt then
                transferRequests[targetSrc] = nil
                if GetPlayerName(req.dealer) then
                    NotifyClient(req.dealer, _U('transfer_expired'), 'error')
                end
                DebugPrint('Traspaso expirado para target:', targetSrc)
            end
        end
    end
end)
