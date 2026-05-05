-- ─────────────────────────────────────────────────────────────────────────────
-- server/callbacks.lua  —  Callbacks ox_lib para yn-dealer-menu
-- ─────────────────────────────────────────────────────────────────────────────

-- Lista de todos los vehículos en venta (para hilo de proximidad del cliente)
lib.callback.register('yn-dealer:cb:getListings', function(source)
    local result = MySQL.query.await(
        'SELECT id, seller_name, model_hash, price, description, pos_x, pos_y, pos_z, pos_h, network_id, vehicle_data FROM dealer_vehicles WHERE status = ?',
        { 'sale' }
    )
    return result or {}
end)

-- Listings propios del dealer (para gestionar / retirar)
lib.callback.register('yn-dealer:cb:getMyListings', function(source)
    local identifier = YND_GetIdentifier(source)
    if not identifier then return {} end

    local result = MySQL.query.await(
        'SELECT id, model_hash, price, network_id FROM dealer_vehicles WHERE seller_id = ? AND status = ?',
        { identifier, 'sale' }
    )
    return result or {}
end)
