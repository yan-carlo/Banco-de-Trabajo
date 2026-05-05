Config = {}

-- Framework: 'auto' detecta ESX o QBCore automáticamente
Config.Framework = 'auto'

-- Idioma activo ('es' | 'en')
Config.Locale = 'es'

-- Mostrar logs de depuración en consola (desactivar en producción)
Config.Debug = false

-- ── Job y comando ─────────────────────────────────────────────────────────────
Config.DealerJob     = 'dealer'   -- Nombre del job que puede usar el menú
Config.DealerCommand = 'dealer'   -- Comando sin /  →  /dealer

-- ── Interacción de compradores ────────────────────────────────────────────────
Config.InteractionDist  = 4.0    -- Metros para ver el prompt [E]
Config.PollingInterval  = 2000   -- ms entre ticks cuando el jugador está lejos
Config.ListingsRefresh  = 10000  -- ms entre refresco automático de la lista en cliente

-- ── Límites de venta ──────────────────────────────────────────────────────────
Config.MaxVehiclesOnSale = 10     -- Máximo de coches en venta simultáneos por dealer
Config.SaleCooldown      = 30000  -- ms de espera entre listados consecutivos del mismo dealer

-- ── origen_masterjob ─────────────────────────────────────────────────────────
Config.MasterjobResource = 'origen_masterjob'  -- Nombre exacto del recurso
Config.MasterjobAccount  = 'dealer'            -- Cuenta donde se depositan las ventas
Config.CommissionPct     = 0                   -- % que retiene el local (0 = 100 % al local)

-- ── Blip de vehículos en venta ────────────────────────────────────────────────
Config.Blip = {
    sprite = 326,
    color  = 2,
    scale  = 0.8,
}

-- ── Función de traducción ─────────────────────────────────────────────────────
function _U(key, ...)
    local locale = Locales and (Locales[Config.Locale] or Locales['es'])
    if not locale then return '[' .. key .. ']' end
    local msg = locale[key]
    if not msg then return '[' .. key .. ']' end
    if select('#', ...) > 0 then
        return string.format(msg, ...)
    end
    return msg
end
