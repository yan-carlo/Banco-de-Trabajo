-- ─────────────────────────────────────────────────────────────────────────────
-- vehicle_utils.lua  —  Helpers para leer datos del vehículo
-- ─────────────────────────────────────────────────────────────────────────────

-- Devuelve todos los datos relevantes del vehículo listos para json.encode
function YND_GetVehicleData(vehicle)
    -- Colores estándar
    local p1, p2     = GetVehicleColours(vehicle)
    local pearl, whl = GetVehicleExtraColours(vehicle)

    -- Colores personalizados (custom RGB)
    local primCustom = GetIsVehiclePrimaryColourCustom(vehicle)
    local secCustom  = GetIsVehicleSecondaryColourCustom(vehicle)
    local pr, pg, pb = GetVehicleCustomPrimaryColour(vehicle)
    local sr, sg, sb = GetVehicleCustomSecondaryColour(vehicle)

    -- Tyresomke y neones
    local tr, tg, tb = GetVehicleTyreSmokeColor(vehicle)
    local nr, ng, nb = GetVehicleNeonLightsColour(vehicle)

    -- Mods de rendimiento (índices GTA)
    local performance = {
        engine       = GetVehicleMod(vehicle, 11),  -- -1 stock, 0-3 Nv1-4
        brakes       = GetVehicleMod(vehicle, 12),
        transmission = GetVehicleMod(vehicle, 13),
        suspension   = GetVehicleMod(vehicle, 15),
        armor        = GetVehicleMod(vehicle, 16),
        turbo        = IsToggleModOn(vehicle, 18),
    }

    -- Mods estéticos relevantes
    local aesthetic = {
        spoiler    = GetVehicleMod(vehicle, 0),
        bumper_f   = GetVehicleMod(vehicle, 1),
        bumper_r   = GetVehicleMod(vehicle, 2),
        skirt      = GetVehicleMod(vehicle, 3),
        exhaust    = GetVehicleMod(vehicle, 4),
        frame      = GetVehicleMod(vehicle, 5),
        grille     = GetVehicleMod(vehicle, 6),
        hood       = GetVehicleMod(vehicle, 7),
        fender     = GetVehicleMod(vehicle, 8),
        fender_r   = GetVehicleMod(vehicle, 9),
        roof       = GetVehicleMod(vehicle, 10),
        horn       = GetVehicleMod(vehicle, 14),
        wheels_type = GetVehicleWheelType(vehicle),
        wheels_mod  = GetVehicleMod(vehicle, 23),
        livery     = GetVehicleLivery(vehicle),
        tint       = GetVehicleWindowTint(vehicle),
        xenon      = IsToggleModOn(vehicle, 22),
        plate_style = GetVehicleNumberPlateTextIndex(vehicle),
    }

    -- Extras activos (solo los que existen en el modelo)
    local extras = {}
    for i = 1, 12 do
        if DoesExtraExist(vehicle, i) then
            extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    return {
        colors = {
            prim_custom = primCustom,
            prim_index  = p1,
            prim_r = pr, prim_g = pg, prim_b = pb,
            sec_custom  = secCustom,
            sec_index   = p2,
            sec_r = sr, sec_g = sg, sec_b = sb,
            pearl   = pearl,
            wheel   = whl,
            smoke_r = tr, smoke_g = tg, smoke_b = tb,
        },
        neon = {
            left  = IsVehicleNeonLightEnabled(vehicle, 0),
            right = IsVehicleNeonLightEnabled(vehicle, 1),
            front = IsVehicleNeonLightEnabled(vehicle, 2),
            back  = IsVehicleNeonLightEnabled(vehicle, 3),
            r = nr, g = ng, b = nb,
        },
        performance = performance,
        aesthetic   = aesthetic,
        extras      = extras,
    }
end

-- Formatea un número con separadores de miles  →  1234567  →  "1,234,567"
function YND_FormatMoney(amount)
    amount = math.floor(tonumber(amount) or 0)
    local s = tostring(amount)
    local result, count = '', 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then result = ',' .. result end
        result = s:sub(i, i) .. result
        count  = count + 1
    end
    return result
end

-- Convierte el nivel raw de un mod en string legible
--   -1  → _U('stock')
--    0+ → _U('level', rawLevel + 1)
function YND_ModLevel(rawLevel)
    if not rawLevel or rawLevel < 0 then return _U('stock') end
    return _U('level', rawLevel + 1)
end
