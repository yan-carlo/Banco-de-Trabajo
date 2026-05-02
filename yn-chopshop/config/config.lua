Config = {}

-- Framework: 'auto', 'esx', 'qbcore'
Config.Framework = 'auto'

-- Idioma: 'es', 'en'
Config.Locale = 'es'

Config.Debug = false

-- ─── NPC que da el trabajo ────────────────────────────────────────────────────
Config.JobNPC = {
    model  = 'a_m_m_mexlabor_01',
    coords = vector4(1058.34, -3196.21, 5.90, 91.54),
    label  = 'Contacto',
}

-- ─── Zonas de aparición del vehículo ─────────────────────────────────────────
-- Al iniciar la misión se escoge una zona aleatoriamente.
-- Dentro de la zona elegida se elige un punto de spawn al azar.
--
-- Campos por zona:
--   label    → nombre identificativo (solo para debug/logs)
--   center   → vector3 centro del círculo que se pinta en el mapa
--   radius   → radio del círculo del mapa (no afecta al spawn)
--   vehicles → lista de modelos posibles en esta zona
--   spawns   → array de vector4(x, y, z, heading): coordenadas exactas de spawn
Config.SpawnZones = {
    {
        label    = 'Zona Centro',
        center   = vector3(200.0, -800.0, 31.0),
        radius   = 250.0,
        vehicles = { 'sultan', 'kuruma', 'tailgater', 'schafter2' },
        spawns   = {
            vector4(185.0, -780.0, 31.0, 180.0),
            vector4(210.0, -810.0, 31.0,  90.0),
            vector4(195.0, -830.0, 31.0, 270.0),
            vector4(220.0, -795.0, 31.0,   0.0),
        },
    },
    {
        label    = 'Zona Puerto',
        center   = vector3(-680.0, -1270.0, 5.0),
        radius   = 200.0,
        vehicles = { 'fugitive', 'oracle2', 'jackal', 'sentinel' },
        spawns   = {
            vector4(-660.0, -1260.0, 5.0,   0.0),
            vector4(-695.0, -1285.0, 5.0,  90.0),
            vector4(-670.0, -1300.0, 5.0, 180.0),
            vector4(-650.0, -1275.0, 5.0, 270.0),
        },
    },
    {
        label    = 'Zona Vinewood',
        center   = vector3(-150.0, -1250.0, 35.0),
        radius   = 180.0,
        vehicles = { 'tailgater', 'schafter2', 'oracle2', 'sentinel' },
        spawns   = {
            vector4(-140.0, -1240.0, 35.0,  90.0),
            vector4(-160.0, -1260.0, 35.0, 270.0),
            vector4(-130.0, -1270.0, 35.0, 180.0),
        },
    },
}

-- ─── Zona de entrega (desguace) ──────────────────────────────────────────────
Config.ChopShop = {
    coords = vector4(1062.0, -3200.0, 5.80, 0.0),
    radius = 10.0,
}

-- ─── NPC comprador en el desguace ────────────────────────────────────────────
Config.BuyerNPC = {
    model  = 'csb_murch',
    offset = vector3(3.0, 0.0, 0.0), -- Desplazamiento relativo al centro del desguace
}

-- ─── Piezas a extraer ────────────────────────────────────────────────────────
-- type: 'door' | 'wheel'
-- index: índice de la pieza en el vehículo (ver FiveM natives)
-- item: nombre del ítem en ox_inventory (debe existir en items.lua de ox_inventory)
Config.Parts = {
    {
        id       = 'door_fl',
        label    = 'Puerta Delantera Izquierda',
        type     = 'door',
        index    = 0,
        reward   = 800,
        time     = 8000,
        prop     = 'prop_rub_boxpile_02',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_door',
    },
    {
        id       = 'door_fr',
        label    = 'Puerta Delantera Derecha',
        type     = 'door',
        index    = 1,
        reward   = 800,
        time     = 8000,
        prop     = 'prop_rub_boxpile_02',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_door',
    },
    {
        id       = 'door_rl',
        label    = 'Puerta Trasera Izquierda',
        type     = 'door',
        index    = 2,
        reward   = 600,
        time     = 8000,
        prop     = 'prop_rub_boxpile_02',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_door',
    },
    {
        id       = 'door_rr',
        label    = 'Puerta Trasera Derecha',
        type     = 'door',
        index    = 3,
        reward   = 600,
        time     = 8000,
        prop     = 'prop_rub_boxpile_02',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_door',
    },
    {
        id       = 'wheel_fl',
        label    = 'Rueda Delantera Izquierda',
        type     = 'wheel',
        index    = 0,
        reward   = 500,
        time     = 10000,
        prop     = 'prop_wheel_01',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_wheel',
    },
    {
        id       = 'wheel_fr',
        label    = 'Rueda Delantera Derecha',
        type     = 'wheel',
        index    = 1,
        reward   = 500,
        time     = 10000,
        prop     = 'prop_wheel_01',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_wheel',
    },
    {
        id       = 'wheel_rl',
        label    = 'Rueda Trasera Izquierda',
        type     = 'wheel',
        index    = 4,
        reward   = 500,
        time     = 10000,
        prop     = 'prop_wheel_01',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_wheel',
    },
    {
        id       = 'wheel_rr',
        label    = 'Rueda Trasera Derecha',
        type     = 'wheel',
        index    = 5,
        reward   = 500,
        time     = 10000,
        prop     = 'prop_wheel_01',
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        animClip = 'machinic_loop_mechandplayer',
        item     = 'chop_wheel',
    },
}

-- ─── Cooldown entre trabajos (ms) ────────────────────────────────────────────
Config.Cooldown = 300000 -- 5 minutos

-- ─── Distancia de interacción con ox_target ──────────────────────────────────
Config.TargetDistance = 2.5

-- ─── Blips ───────────────────────────────────────────────────────────────────
Config.Blips = {
    searchZone = { color = 5,  scale = 1.0 },
    vehicle    = { sprite = 225, color = 3, scale = 0.8 },
    chopShop   = { sprite = 50,  color = 1, scale = 0.8 },
}

-- ─── Función de localización ─────────────────────────────────────────────────
function _U(str, ...)
    local locale = Locales[Config.Locale] or Locales['es']
    local msg    = locale and locale[str]
    if msg then return string.format(msg, ...) end
    return '[' .. str .. ']'
end
