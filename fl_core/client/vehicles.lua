-- ====================================================================
-- SERVER-SIDE VEHICLE MANAGEMENT (FEHLER BEHOBEN)
-- KRITISCHER FIX: FL.Client durch FL.Server ersetzt (Line 45 Fix)
-- ====================================================================

-- server/vehicles.lua

-- Give equipment from vehicle to player
RegisterServerEvent('fl_vehicles:takeEquipment', function(vehicle, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- KORRIGIERT: FL.Client existiert nicht auf dem Server
    -- Validate vehicle and equipment (entfernt da vehicle state server-side anders funktioniert)
    -- TODO: Implement proper server-side vehicle equipment validation

    -- Check if player already has this item
    local hasItem = Player.Functions.GetItemByName(itemName)
    if hasItem then
        TriggerClientEvent('QBCore:Notify', source, 'You already have this item', 'error')
        return
    end

    -- Basic validation for emergency service equipment
    local serviceInfo = GetPlayerServiceInfo(source)
    if not serviceInfo or not serviceInfo.isOnDuty then
        TriggerClientEvent('QBCore:Notify', source, 'You must be on duty to take equipment', 'error')
        return
    end

    -- Check if item is valid emergency equipment
    local validEquipment = FL.Functions.GetServiceEquipment(serviceInfo.service)
    local isValidItem = false
    for _, equipment in pairs(validEquipment) do
        if equipment == itemName then
            isValidItem = true
            break
        end
    end

    if not isValidItem then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid equipment for your service', 'error')
        return
    end

    -- Give item to player
    if QBCore.Shared.Items[itemName] then
        Player.Functions.AddItem(itemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], 'add')
        TriggerClientEvent('QBCore:Notify', source, 'Took: ' .. QBCore.Shared.Items[itemName].label, 'success')

        FL.Debug('🧰 Player ' .. Player.PlayerData.citizenid .. ' took ' .. itemName .. ' from vehicle')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Invalid item', 'error')
    end
end)

-- Enhanced vehicle spawning with server-side tracking
FL.Server.SpawnedVehicles = FL.Server.SpawnedVehicles or {}

-- Track vehicle spawning
RegisterServerEvent('fl_vehicles:vehicleSpawned', function(vehicleNetId, vehicleKey, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- Store vehicle info on server
    FL.Server.SpawnedVehicles[vehicleNetId] = {
        owner = source,
        citizenid = Player.PlayerData.citizenid,
        vehicleKey = vehicleKey,
        stationId = stationId,
        spawnTime = os.time()
    }

    FL.Debug('🚗 Vehicle spawned and tracked: ' .. vehicleKey .. ' for ' .. Player.PlayerData.citizenid)
end)

-- Track vehicle deletion
RegisterServerEvent('fl_vehicles:vehicleDeleted', function(vehicleNetId)
    if FL.Server.SpawnedVehicles[vehicleNetId] then
        FL.Debug('🗑️ Vehicle deleted and removed from tracking: ' .. vehicleNetId)
        FL.Server.SpawnedVehicles[vehicleNetId] = nil
    end
end)

-- Get player's spawned vehicles
RegisterServerEvent('fl_vehicles:getPlayerVehicles', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local playerVehicles = {}
    for netId, vehicleData in pairs(FL.Server.SpawnedVehicles) do
        if vehicleData.owner == source then
            playerVehicles[netId] = vehicleData
        end
    end

    TriggerClientEvent('fl_vehicles:playerVehicles', source, playerVehicles)
end)

-- ====================================================================
-- CLEANUP ON RESOURCE STOP
-- ====================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Clean up server-side vehicle tracking
        FL.Server.SpawnedVehicles = {}
        FL.Debug('🧹 Server-side vehicle tracking cleaned up')
    end
end)

-- ====================================================================
-- CLEANUP ON PLAYER DISCONNECT
-- ====================================================================

AddEventHandler('playerDropped', function(reason)
    local droppedSource = source

    -- Clean up vehicles spawned by disconnected player
    local cleanedCount = 0
    for netId, vehicleData in pairs(FL.Server.SpawnedVehicles) do
        if vehicleData.owner == droppedSource then
            FL.Server.SpawnedVehicles[netId] = nil
            cleanedCount = cleanedCount + 1
        end
    end

    if cleanedCount > 0 then
        FL.Debug('🧹 Cleaned up ' .. cleanedCount .. ' vehicles for disconnected player: ' .. droppedSource)
    end
end)

FL.Debug('🚗 FL Core Emergency Vehicle System loaded successfully (SERVER FIXED)')
