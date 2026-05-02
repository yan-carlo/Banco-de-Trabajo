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
    if not hash then return end

    jobNPC = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)
    FreezeEntityPosition(jobNPC, true)
    SetEntityInvincible(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(jobNPC, {
        {
            label    = _U('npc_interact'),
            icon     = 'fas fa-comment-dollar',
            distance = Config.TargetDistance,
            onSelect = function()
                TriggerServerEvent('yn-chopshop:server:requestJob')
            end,
        }
    })
end

CreateThread(function()
    Wait(500)
    SpawnJobNPC()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if jobNPC and DoesEntityExist(jobNPC) then
        exports.ox_target:removeLocalEntity(jobNPC)
        DeleteEntity(jobNPC)
    end
end)
