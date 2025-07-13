-- ====================================================================
-- SERVER-SIDE VEHICLE MANAGEMENT
-- ====================================================================

-- server/vehicles.lua - Neue Datei erstellen

-- Give equipment from vehicle to player
RegisterServerEvent('fl_vehicles:takeEquipment', function(vehicle, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- Validate vehicle and equipment
    local vehicleEquipment = Entity(vehicle).state.equipment
    if not vehicleEquipment or not table.contains(vehicleEquipment, itemName) then
        TriggerClientEvent('QBCore:Notify', source, 'Item not available in this vehicle', 'error')
        return
    end

    -- Check if player already has this item
    local hasItem = Player.Functions.GetItemByName(itemName)
    if hasItem then
        TriggerClientEvent('QBCore:Notify', source, 'You already have this item', 'error')
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

-- ====================================================================
-- CLEANUP ON RESOURCE STOP
-- ====================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Clean up spawned vehicles
        for vehicle, _ in pairs(FL.Client.spawnedVehicles) do
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
        end

        -- Clean up blips
        for vehicle, blip in pairs(FL.Client.vehicleBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
    end
end)

FL.Debug('🚗 FL Core Emergency Vehicle System loaded successfully')
