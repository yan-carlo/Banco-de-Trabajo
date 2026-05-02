-- NPC que da el trabajo (visible para todos los jugadores)

local jobNPC = nil

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

local function SpawnJobNPC()
    local cfg  = Config.JobNPC
    local hash = LoadModel(cfg.model)
    if not hash then
        print('[yn-chopshop] ERROR: No se pudo cargar el modelo del NPC contacto:', cfg.model)
        return
    end

    jobNPC = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)
    FreezeEntityPosition(jobNPC, true)
    SetEntityInvincible(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)
    SetModelAsNoLongerNeeded(hash)

    -- IMPORTANTE: ox_target v3+ requiere el campo 'name' en cada opción
    exports.ox_target:addLocalEntity(jobNPC, {
        {
            name     = 'yn_chopshop_request_job',
            label    = _U('npc_interact'),
            icon     = 'fas fa-comment-dollar',
            distance = Config.TargetDistance,
            onSelect = function()
                TriggerServerEvent('yn-chopshop:server:requestJob')
            end,
        }
    })

    print('[yn-chopshop] NPC contacto spawneado. Entity:', jobNPC)
end

CreateThread(function()
    Wait(1000) -- Esperar a que ox_target cargue completamente
    print('[yn-chopshop] Iniciando NPC contacto...')
    SpawnJobNPC()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if jobNPC and DoesEntityExist(jobNPC) then
        exports.ox_target:removeLocalEntity(jobNPC)
        DeleteEntity(jobNPC)
    end
end)
