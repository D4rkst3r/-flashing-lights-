-- ====================================================================
-- CLIENT-SIDE VEHICLE MANAGEMENT (FIXED QBCORE LOADING)
-- ====================================================================

-- ERSETZE DIE ERSTEN ZEILEN in client/vehicles.lua:

local QBCore = FL.GetFramework()

-- Wait for QBCore to be ready
CreateThread(function()
    local attempts = 0
    while not QBCore and attempts < 10 do
        QBCore = FL.GetFramework()
        if not QBCore then
            Wait(1000)
            attempts = attempts + 1
            FL.Debug('⏳ Waiting for QBCore in vehicles.lua... Attempt ' .. attempts)
        end
    end

    if not QBCore then
        FL.Debug('❌ CRITICAL: QBCore not available in vehicles.lua after 10 attempts')
        return
    end

    FL.Debug('✅ QBCore loaded successfully in vehicles.lua')
end)

-- Client state for vehicles (SAFE INITIALIZATION)
FL.Client = FL.Client or {}
FL.Client.Vehicles = FL.Client.Vehicles or {
    currentVehicle = nil,
    spawnedVehicles = {},
    vehicleBlips = {},
    isInEmergencyVehicle = false
}

-- ====================================================================
-- VEHICLE SPAWNING SYSTEM (SAFE QBCORE CALLS)
-- ====================================================================

-- Show vehicle menu (called from qtarget) - SAFE VERSION
function ShowVehicleMenu(stationId, service)
    if not QBCore then
        FL.Debug('❌ QBCore not available in ShowVehicleMenu')
        return
    end

    local vehicles = Config.EmergencyVehicles and Config.EmergencyVehicles[service]
    if not vehicles then
        QBCore.Functions.Notify('No vehicles available for your service', 'error')
        return
    end

    local availableVehicles = {}
    local playerRank = FL.Client.serviceInfo and FL.Client.serviceInfo.rank or 0

    -- Filter vehicles by rank
    for vehicleKey, vehicleData in pairs(vehicles) do
        if playerRank >= (vehicleData.required_rank or 0) then
            -- Check if vehicle can spawn at this station
            if not vehicleData.spawn_locations or
                table.contains(vehicleData.spawn_locations, stationId) then
                availableVehicles[vehicleKey] = vehicleData
            end
        end
    end

    if next(availableVehicles) == nil then
        QBCore.Functions.Notify('No vehicles available for your rank at this station', 'error')
        return
    end

    -- Send vehicle menu data to UI
    SendNUIMessage({
        type = 'showVehicleMenu',
        data = {
            stationId = stationId,
            service = service,
            vehicles = availableVehicles,
            currentVehicles = FL.Client.Vehicles.spawnedVehicles
        }
    })

    SetNuiFocus(true, true)
end

-- Spawn emergency vehicle - SAFE VERSION
function SpawnEmergencyVehicle(stationId, vehicleKey, spawnIndex)
    if not QBCore then
        FL.Debug('❌ QBCore not available in SpawnEmergencyVehicle')
        return
    end

    -- Check with vehicle manager first
    if FL.VehicleManager then
        local currentCount = FL.VehicleManager.getPlayerVehicleCount()
        if currentCount >= FL.VehicleManager.maxVehiclesPerPlayer then
            QBCore.Functions.Notify(
                'Maximum vehicles spawned (' .. FL.VehicleManager.maxVehiclesPerPlayer .. '). Removing oldest vehicle.',
                'warning')
            FL.VehicleManager.cleanupOldestVehicle()
        end
    end

    local stationData = Config.Stations and Config.Stations[stationId]
    local serviceVehicles = Config.EmergencyVehicles and Config.EmergencyVehicles[FL.Client.serviceInfo.service]
    local vehicleData = serviceVehicles and serviceVehicles[vehicleKey]

    if not stationData or not vehicleData then
        QBCore.Functions.Notify('Invalid vehicle or station', 'error')
        return
    end

    -- Get spawn point
    local spawnPoints = stationData.vehicle_spawns
    if not spawnPoints or not spawnPoints[spawnIndex] then
        QBCore.Functions.Notify('No spawn point available', 'error')
        return
    end

    local spawnCoords = spawnPoints[spawnIndex]

    -- Check if spawn point is clear
    if IsSpawnPointOccupied(spawnCoords) then
        QBCore.Functions.Notify('Spawn point is blocked', 'error')
        return
    end

    -- Request vehicle model
    local modelHash = GetHashKey(vehicleData.model)

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        QBCore.Functions.Notify('Vehicle model not found', 'error')
        return
    end

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end

    -- Spawn vehicle
    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)

    if not DoesEntityExist(vehicle) then
        QBCore.Functions.Notify('Failed to spawn vehicle', 'error')
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    -- Setup vehicle
    SetupEmergencyVehicle(vehicle, vehicleKey, vehicleData)

    -- Store vehicle info
    FL.Client.Vehicles.spawnedVehicles[vehicle] = {
        key = vehicleKey,
        station = stationId,
        spawnTime = GetGameTimer(),
        data = vehicleData
    }

    -- Create vehicle blip
    CreateVehicleBlip(vehicle, vehicleData)

    -- Give player keys (SAFE QBCORE CALL)
    if QBCore.Functions and QBCore.Functions.GetPlate then
        local plate = QBCore.Functions.GetPlate(vehicle)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    else
        FL.Debug('⚠️ Could not set vehicle keys - QBCore.Functions.GetPlate not available')
    end

    QBCore.Functions.Notify('Vehicle spawned: ' .. vehicleData.label, 'success')
    SetModelAsNoLongerNeeded(modelHash)

    FL.Debug('🚗 Spawned emergency vehicle: ' .. vehicleKey .. ' at ' .. stationId)
end

-- Continue with rest of the vehicles.lua file...
-- The remaining functions stay the same but ensure they check for QBCore availability

-- Helper function to check if array contains value
function table.contains(table, element)
    if not table or type(table) ~= 'table' then
        return false
    end

    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- MAKE FUNCTION GLOBAL so vehicle_manager can access it
_G.SpawnEmergencyVehicle = SpawnEmergencyVehicle

FL.Debug('🚗 FL Emergency Vehicle System loaded with SAFE QBCORE INTEGRATION')
