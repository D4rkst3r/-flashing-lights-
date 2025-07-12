-- ===================================
-- FLASHING LIGHTS CLIENT UTILITIES
-- ===================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Client-side utility functions for FL system

-- ===================================
-- DRAWING UTILITIES
-- ===================================

-- Draw 3D text at location
function FL.DrawText3D(coords, text, scale, font)
    scale = scale or 0.35
    font = font or 4

    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local pX, pY, pZ = table.unpack(GetGameplayCamCoords())
    local dist = #(vector3(pX, pY, pZ) - coords)

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(font)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Draw marker with glow effect
function FL.DrawGlowMarker(type, coords, size, color, bobUpAndDown, faceCamera, rotate)
    bobUpAndDown = bobUpAndDown or false
    faceCamera = faceCamera or false
    rotate = rotate or false

    -- Main marker
    DrawMarker(
        type,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        size.x, size.y, size.z,
        color.r, color.g, color.b, color.a,
        bobUpAndDown,
        faceCamera,
        2,
        rotate,
        nil, nil, false
    )

    -- Glow effect (larger, more transparent marker)
    DrawMarker(
        type,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        size.x * 1.5, size.y * 1.5, size.z * 0.5,
        color.r, color.g, color.b, math.floor(color.a * 0.3),
        bobUpAndDown,
        faceCamera,
        2,
        rotate,
        nil, nil, false
    )
end

-- ===================================
-- VEHICLE UTILITIES
-- ===================================

-- Check if player is in emergency vehicle
function FL.IsInEmergencyVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end

    local vehicle = GetVehiclePedIsIn(ped, false)
    local vehicleClass = GetVehicleClass(vehicle)

    -- Emergency vehicle classes: 18 = Emergency
    return vehicleClass == 18
end

-- Get vehicle emergency type (fire, ambulance, police)
function FL.GetVehicleEmergencyType(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end

    local model = GetEntityModel(vehicle)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

    -- Fire vehicles
    local fireVehicles = {
        'firetruk', 'firetruck', 'fire', 'ladder', 'rescue', 'pumper'
    }

    -- EMS vehicles
    local emsVehicles = {
        'ambulan', 'ambulance', 'ems', 'paramedic', 'rescue'
    }

    -- Police vehicles
    local policeVehicles = {
        'police', 'sheriff', 'cop', 'patrol', 'cruiser'
    }

    for _, name in pairs(fireVehicles) do
        if string.find(modelName, name) then
            return 'fire'
        end
    end

    for _, name in pairs(emsVehicles) do
        if string.find(modelName, name) then
            return 'ambulance'
        end
    end

    for _, name in pairs(policeVehicles) do
        if string.find(modelName, name) then
            return 'police'
        end
    end

    return nil
end

-- ===================================
-- BLIP UTILITIES
-- ===================================

-- Create emergency blip
function FL.CreateEmergencyBlip(coords, sprite, color, text, scale)
    scale = scale or 0.8

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blip)

    return blip
end

-- Remove blip safely
function FL.RemoveBlip(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
        return true
    end
    return false
end

-- ===================================
-- AUDIO UTILITIES
-- ===================================

-- Play emergency sound
function FL.PlayEmergencySound(soundName, soundSet, volume)
    volume = volume or 0.5

    if soundName and soundSet then
        PlaySoundFromEntity(-1, soundName, PlayerPedId(), soundSet, false, 0)
    end
end

-- Play siren sound for vehicle
function FL.PlaySirenSound(vehicle, sirenType)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    sirenType = sirenType or 1

    -- Enable siren
    SetVehicleHasMutedSirens(vehicle, false)
    SetVehicleSiren(vehicle, true)

    -- Set siren tone
    if sirenType == 1 then
        -- Wail
        TriggerEvent('InteractSound_CL:PlayOnOne', 'siren_wail', 0.5)
    elseif sirenType == 2 then
        -- Yelp
        TriggerEvent('InteractSound_CL:PlayOnOne', 'siren_yelp', 0.5)
    elseif sirenType == 3 then
        -- Priority
        TriggerEvent('InteractSound_CL:PlayOnOne', 'siren_priority', 0.5)
    end
end

-- ===================================
-- PARTICLE UTILITIES
-- ===================================

-- Create particle effect
function FL.CreateParticleEffect(dict, name, coords, scale, duration)
    scale = scale or 1.0
    duration = duration or 5000

    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        while not HasNamedPtfxAssetLoaded(dict) do
            Wait(1)
        end
    end

    UseParticleFxAssetNextCall(dict)
    local particle = StartParticleFxLoopedAtCoord(
        name,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        scale,
        false, false, false, false
    )

    -- Auto-remove after duration
    if duration > 0 then
        SetTimeout(duration, function()
            if DoesParticleFxLoopedExist(particle) then
                StopParticleFxLooped(particle, false)
            end
        end)
    end

    return particle
end

-- Stop particle effect
function FL.StopParticleEffect(particle)
    if particle and DoesParticleFxLoopedExist(particle) then
        StopParticleFxLooped(particle, false)
        return true
    end
    return false
end

-- ===================================
-- ENTITY UTILITIES
-- ===================================

-- Get entities in radius
function FL.GetEntitiesInRadius(coords, radius, entityType)
    entityType = entityType or 'all' -- 'vehicles', 'peds', 'objects', 'all'

    local entities = {}

    if entityType == 'vehicles' or entityType == 'all' then
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in pairs(vehicles) do
            local vehicleCoords = GetEntityCoords(vehicle)
            if FL.GetDistance(coords, vehicleCoords) <= radius then
                table.insert(entities, { type = 'vehicle', entity = vehicle, coords = vehicleCoords })
            end
        end
    end

    if entityType == 'peds' or entityType == 'all' then
        local peds = GetGamePool('CPed')
        for _, ped in pairs(peds) do
            if ped ~= PlayerPedId() then
                local pedCoords = GetEntityCoords(ped)
                if FL.GetDistance(coords, pedCoords) <= radius then
                    table.insert(entities, { type = 'ped', entity = ped, coords = pedCoords })
                end
            end
        end
    end

    if entityType == 'objects' or entityType == 'all' then
        local objects = GetGamePool('CObject')
        for _, object in pairs(objects) do
            local objectCoords = GetEntityCoords(object)
            if FL.GetDistance(coords, objectCoords) <= radius then
                table.insert(entities, { type = 'object', entity = object, coords = objectCoords })
            end
        end
    end

    return entities
end

-- ===================================
-- UI UTILITIES
-- ===================================

-- Show notification with custom styling
function FL.ShowNotification(message, type, duration)
    type = type or 'info'
    duration = duration or 5000

    -- Send to NUI for custom notification
    SendNUIMessage({
        action = 'showNotification',
        data = {
            message = message,
            type = type,
            duration = duration
        }
    })
end

-- Show progress bar
function FL.ShowProgressBar(text, duration, canCancel, onComplete, onCancel)
    canCancel = canCancel or false
    duration = duration or 5000

    -- This would integrate with your progress bar system
    -- For now, we'll use a simple implementation

    if exports['progressbar'] then
        exports['progressbar']:Progress({
            name = "fl_progress",
            duration = duration,
            label = text,
            useWhileDead = false,
            canCancel = canCancel,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }
        }, function(cancelled)
            if cancelled and onCancel then
                onCancel()
            elseif not cancelled and onComplete then
                onComplete()
            end
        end)
    else
        -- Fallback to simple timer
        QBCore.Functions.Notify(text, 'primary', duration)
        SetTimeout(duration, function()
            if onComplete then onComplete() end
        end)
    end
end

-- ===================================
-- ANIMATION UTILITIES
-- ===================================

-- Play animation
function FL.PlayAnimation(ped, dict, anim, duration, flag)
    flag = flag or 49
    duration = duration or -1

    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(1)
        end
    end

    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)

    if duration > 0 then
        SetTimeout(duration, function()
            ClearPedTasks(ped)
        end)
    end
end

-- Stop animation
function FL.StopAnimation(ped, dict, anim)
    if dict and anim then
        StopAnimTask(ped, dict, anim, 1.0)
    else
        ClearPedTasks(ped)
    end
end

-- ===================================
-- RAYCAST UTILITIES
-- ===================================

-- Perform raycast from camera
function FL.RaycastFromCamera(maxDistance)
    maxDistance = maxDistance or 100.0

    local cam = GetRenderingCam()
    local camCoords = GetCamCoord(cam)
    local camRot = GetCamRot(cam, 2)

    local direction = FL.RotationToDirection(camRot)
    local destination = vector3(
        camCoords.x + direction.x * maxDistance,
        camCoords.y + direction.y * maxDistance,
        camCoords.z + direction.z * maxDistance
    )

    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        destination.x, destination.y, destination.z,
        -1, 0, 4, 4, 0
    )

    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    return hit == 1, endCoords, entityHit, surfaceNormal
end

-- Convert rotation to direction vector
function FL.RotationToDirection(rotation)
    local adjustedRotation = vector3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )

    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )

    return direction
end

FL.Debug('Client utilities loaded')
