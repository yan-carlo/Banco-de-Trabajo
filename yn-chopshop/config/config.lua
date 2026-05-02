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

-- ─── Zona de búsqueda del vehículo ───────────────────────────────────────────
Config.SearchZone = {
    center = vector3(400.0, -1600.0, 29.0),
    radius = 250.0,
}

-- Mostrar blip específico del vehículo (false = solo se muestra el radio de búsqueda)
Config.ShowVehicleBlip = true

-- Lista de vehículos que pueden aparecer
Config.Vehicles = {
    'sultan', 'kuruma', 'tailgater', 'schafter2',
    'fugitive', 'oracle2', 'jackal', 'sentinel',
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
