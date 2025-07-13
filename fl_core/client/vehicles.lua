-- ====================================================================
-- CLIENT-SIDE VEHICLE MANAGEMENT
-- ====================================================================

-- client/vehicles.lua - Neue Datei erstellen

local QBCore = FL.GetFramework()

-- Client state for vehicles
FL.Client.Vehicles = {
    currentVehicle = nil,
    spawnedVehicles = {},
    vehicleBlips = {},
    isInEmergencyVehicle = false
}

-- ====================================================================
-- VEHICLE SPAWNING SYSTEM
-- ====================================================================

-- Show vehicle menu (called from qtarget)
function ShowVehicleMenu(stationId, service)
    local vehicles = Config.EmergencyVehicles[service]
    if not vehicles then
        QBCore.Functions.Notify('No vehicles available for your service', 'error')
        return
    end

    local availableVehicles = {}
    local playerRank = FL.Client.serviceInfo.rank

    -- Filter vehicles by rank
    for vehicleKey, vehicleData in pairs(vehicles) do
        if playerRank >= vehicleData.required_rank then
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
            currentVehicles = FL.Client.spawnedVehicles
        }
    })

    SetNuiFocus(true, true)
end

-- Spawn emergency vehicle
function SpawnEmergencyVehicle(stationId, vehicleKey, spawnIndex)
    local stationData = Config.Stations[stationId]
    local vehicleData = Config.EmergencyVehicles[FL.Client.serviceInfo.service][vehicleKey]

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
    FL.Client.spawnedVehicles[vehicle] = {
        key = vehicleKey,
        station = stationId,
        spawnTime = GetGameTimer(),
        data = vehicleData
    }

    -- Create vehicle blip
    CreateVehicleBlip(vehicle, vehicleData)

    -- Give player keys
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))

    QBCore.Functions.Notify('Vehicle spawned: ' .. vehicleData.label, 'success')
    SetModelAsNoLongerNeeded(modelHash)

    FL.Debug('🚗 Spawned emergency vehicle: ' .. vehicleKey .. ' at ' .. stationId)
end

-- Setup emergency vehicle properties
function SetupEmergencyVehicle(vehicle, vehicleKey, vehicleData)
    -- Set vehicle properties
    SetVehicleEngineOn(vehicle, false, false, false)
    SetVehicleFuelLevel(vehicle, vehicleData.fuel_capacity)
    SetVehicleNumberPlateText(vehicle, 'FL' .. string.upper(string.sub(vehicleKey, 1, 4)))

    -- Set vehicle mods (emergency lighting, sirens, etc.)
    SetVehicleExtra(vehicle, 1, 0) -- Emergency lights
    SetVehicleExtra(vehicle, 2, 0) -- Secondary lights
    SetVehicleExtra(vehicle, 3, 1) -- Optional equipment (off by default)

    -- Setup siren
    if vehicleData.features.sirens then
        SetVehicleHasMutedSirens(vehicle, false)
    end

    -- Set vehicle as mission entity
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)

    -- Network setup
    if NetworkGetEntityIsNetworked(vehicle) then
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(vehicle), true)
    end

    -- Store equipment in vehicle
    StoreVehicleEquipment(vehicle, vehicleKey)

    -- Custom properties based on vehicle type
    if vehicleData.category == 'fire' then
        SetupFireVehicle(vehicle, vehicleData)
    elseif vehicleData.category == 'police' then
        SetupPoliceVehicle(vehicle, vehicleData)
    elseif vehicleData.category == 'medical' then
        SetupMedicalVehicle(vehicle, vehicleData)
    end
end

-- ====================================================================
-- VEHICLE-SPECIFIC SETUPS
-- ====================================================================

function SetupFireVehicle(vehicle, vehicleData)
    -- Set fire truck specific properties
    if vehicleData.water_capacity then
        SetVehicleExtra(vehicle, 5, 0) -- Water tank visible
        Entity(vehicle).state.waterLevel = vehicleData.water_capacity
    end

    if vehicleData.features.ladder then
        SetVehicleExtra(vehicle, 6, 0) -- Ladder visible
    end
end

function SetupPoliceVehicle(vehicle, vehicleData)
    -- Set police vehicle specific properties
    if vehicleData.features.computer then
        SetVehicleExtra(vehicle, 4, 0) -- Computer visible
    end

    if vehicleData.features.prisoner_transport then
        SetVehicleExtra(vehicle, 7, 0) -- Cage visible
    end
end

function SetupMedicalVehicle(vehicle, vehicleData)
    -- Set medical vehicle specific properties
    if vehicleData.features.stretcher then
        SetVehicleExtra(vehicle, 3, 0) -- Stretcher visible
    end

    if vehicleData.patient_capacity then
        Entity(vehicle).state.patientCapacity = vehicleData.patient_capacity
        Entity(vehicle).state.currentPatients = 0
    end
end

-- ====================================================================
-- VEHICLE EQUIPMENT SYSTEM
-- ====================================================================

function StoreVehicleEquipment(vehicle, vehicleKey)
    local service = FL.Client.serviceInfo.service
    local equipment = Config.VehicleEquipment[service] and Config.VehicleEquipment[service][vehicleKey]

    if not equipment then return end

    -- Store equipment in vehicle state
    Entity(vehicle).state.equipment = equipment
    Entity(vehicle).state.equipmentCapacity = Config.EmergencyVehicles[service][vehicleKey].equipment_storage

    FL.Debug('🧰 Stored equipment in vehicle: ' .. json.encode(equipment))
end

function AccessVehicleEquipment(vehicle)
    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        QBCore.Functions.Notify('You must be on duty to access vehicle equipment', 'error')
        return
    end

    local equipment = Entity(vehicle).state.equipment
    if not equipment then
        QBCore.Functions.Notify('This vehicle has no equipment storage', 'error')
        return
    end

    -- Show equipment menu
    SendNUIMessage({
        type = 'showVehicleEquipment',
        data = {
            vehicle = vehicle,
            equipment = equipment,
            capacity = Entity(vehicle).state.equipmentCapacity
        }
    })

    SetNuiFocus(true, true)
end

-- ====================================================================
-- VEHICLE BLIPS AND TRACKING
-- ====================================================================

function CreateVehicleBlip(vehicle, vehicleData)
    local blip = AddBlipForEntity(vehicle)

    -- Set blip properties based on service
    local service = FL.Client.serviceInfo.service
    local serviceData = FL.Functions.GetServiceData(service)

    if serviceData then
        SetBlipSprite(blip, serviceData.blip)
        SetBlipColour(blip, GetBlipColorFromHex(serviceData.color))
    else
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 0)
    end

    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(vehicleData.label)
    EndTextCommandSetBlipName(blip)

    FL.Client.vehicleBlips[vehicle] = blip

    FL.Debug('📍 Created blip for vehicle: ' .. vehicleData.label)
end

function RemoveVehicleBlip(vehicle)
    local blip = FL.Client.vehicleBlips[vehicle]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
        FL.Client.vehicleBlips[vehicle] = nil
    end
end

-- ====================================================================
-- VEHICLE INTERACTION SYSTEM
-- ====================================================================

-- Setup vehicle interactions using qtarget
function SetupVehicleInteractions(vehicle, vehicleData)
    local options = {}

    -- Equipment access
    if vehicleData.equipment_storage and vehicleData.equipment_storage > 0 then
        table.insert(options, {
            type = "client",
            event = "fl_vehicles:accessEquipment",
            icon = "fas fa-toolbox",
            label = "Access Equipment",
            vehicle = vehicle
        })
    end

    -- Service-specific interactions
    if vehicleData.features.water_cannon then
        table.insert(options, {
            type = "client",
            event = "fl_vehicles:useWaterCannon",
            icon = "fas fa-tint",
            label = "Use Water Cannon",
            vehicle = vehicle
        })
    end

    if vehicleData.features.stretcher then
        table.insert(options, {
            type = "client",
            event = "fl_vehicles:useStretcher",
            icon = "fas fa-procedures",
            label = "Deploy Stretcher",
            vehicle = vehicle
        })
    end

    if vehicleData.features.radar then
        table.insert(options, {
            type = "client",
            event = "fl_vehicles:useRadar",
            icon = "fas fa-satellite-dish",
            label = "Speed Radar",
            vehicle = vehicle
        })
    end

    -- Delete vehicle option
    table.insert(options, {
        type = "client",
        event = "fl_vehicles:deleteVehicle",
        icon = "fas fa-trash",
        label = "Return Vehicle",
        vehicle = vehicle
    })

    -- Add interactions to vehicle
    if targetSystem == 'qtarget' then
        targetResource:AddTargetEntity(vehicle, {
            options = options,
            distance = 3.0
        })
    elseif targetSystem == 'ox_target' then
        targetResource:addLocalEntity(vehicle, options)
    end
end

-- ====================================================================
-- VEHICLE EVENT HANDLERS
-- ====================================================================

-- Access vehicle equipment
RegisterNetEvent('fl_vehicles:accessEquipment', function(data)
    AccessVehicleEquipment(data.vehicle)
end)

-- Use water cannon (fire trucks)
RegisterNetEvent('fl_vehicles:useWaterCannon', function(data)
    local vehicle = data.vehicle
    local waterLevel = Entity(vehicle).state.waterLevel or 0

    if waterLevel <= 0 then
        QBCore.Functions.Notify('Water tank is empty', 'error')
        return
    end

    -- Start water cannon effect
    TriggerEvent('fl_effects:waterCannon', vehicle)
    QBCore.Functions.Notify('Water cannon activated', 'success')
end)

-- Use stretcher (ambulances)
RegisterNetEvent('fl_vehicles:useStretcher', function(data)
    local vehicle = data.vehicle

    -- Deploy stretcher logic
    TriggerEvent('fl_medical:deployStretcher', vehicle)
    QBCore.Functions.Notify('Stretcher deployed', 'success')
end)

-- Use radar (police vehicles)
RegisterNetEvent('fl_vehicles:useRadar', function(data)
    local vehicle = data.vehicle

    -- Start radar gun
    TriggerEvent('fl_police:startRadar', vehicle)
    QBCore.Functions.Notify('Speed radar activated', 'success')
end)

-- Delete vehicle
RegisterNetEvent('fl_vehicles:deleteVehicle', function(data)
    local vehicle = data.vehicle

    if not FL.Client.spawnedVehicles[vehicle] then
        QBCore.Functions.Notify('You can only return vehicles you spawned', 'error')
        return
    end

    -- Remove from tracking
    FL.Client.spawnedVehicles[vehicle] = nil
    RemoveVehicleBlip(vehicle)

    -- Delete vehicle
    DeleteEntity(vehicle)
    QBCore.Functions.Notify('Vehicle returned successfully', 'success')
end)

-- ====================================================================
-- VEHICLE MONITORING SYSTEM
-- ====================================================================

CreateThread(function()
    while true do
        Wait(1000)

        local playerPed = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(playerPed, false)

        -- Check if player entered/exited emergency vehicle
        if currentVehicle ~= FL.Client.currentVehicle then
            if currentVehicle ~= 0 and FL.Client.spawnedVehicles[currentVehicle] then
                -- Entered emergency vehicle
                FL.Client.currentVehicle = currentVehicle
                FL.Client.isInEmergencyVehicle = true
                OnEnterEmergencyVehicle(currentVehicle)
            elseif FL.Client.currentVehicle ~= 0 then
                -- Exited emergency vehicle
                OnExitEmergencyVehicle(FL.Client.currentVehicle)
                FL.Client.currentVehicle = nil
                FL.Client.isInEmergencyVehicle = false
            end
        end

        -- Update vehicle data if in emergency vehicle
        if FL.Client.isInEmergencyVehicle and currentVehicle ~= 0 then
            UpdateVehicleData(currentVehicle)
        end
    end
end)

function OnEnterEmergencyVehicle(vehicle)
    local vehicleInfo = FL.Client.spawnedVehicles[vehicle]
    if vehicleInfo then
        QBCore.Functions.Notify('Entered: ' .. vehicleInfo.data.label, 'info')

        -- Setup vehicle interactions
        SetupVehicleInteractions(vehicle, vehicleInfo.data)

        -- Enable emergency features
        if vehicleInfo.data.features.sirens then
            EnableSirenControls(vehicle)
        end
    end
end

function OnExitEmergencyVehicle(vehicle)
    -- Disable emergency features if needed
    DisableSirenControls(vehicle)
end

function UpdateVehicleData(vehicle)
    -- Update fuel level, water level, etc.
    local fuelLevel = GetVehicleFuelLevel(vehicle)

    -- Update water level for fire trucks
    if Entity(vehicle).state.waterLevel then
        -- Water consumption logic here
    end

    -- Update patient count for ambulances
    if Entity(vehicle).state.currentPatients then
        -- Patient management logic here
    end
end

-- ====================================================================
-- SIREN AND EMERGENCY LIGHT CONTROLS
-- ====================================================================

function EnableSirenControls(vehicle)
    CreateThread(function()
        while FL.Client.isInEmergencyVehicle and GetVehiclePedIsIn(PlayerPedId(), false) == vehicle do
            Wait(0)

            -- Horn + Q = Cycle sirens
            if IsControlPressed(0, 86) and IsControlJustPressed(0, 44) then -- Q key
                CycleSirenTone(vehicle)
            end

            -- Horn + E = Toggle emergency lights
            if IsControlPressed(0, 86) and IsControlJustPressed(0, 38) then -- E key
                ToggleEmergencyLights(vehicle)
            end
        end
    end)
end

function DisableSirenControls(vehicle)
    -- Turn off sirens and lights when exiting
    SetVehicleSiren(vehicle, false)
    SetVehicleHasMutedSirens(vehicle, true)
end

function CycleSirenTone(vehicle)
    local currentSiren = GetVehicleSirenTone(vehicle)
    local maxSirens = 4 -- Most emergency vehicles have 4 siren tones

    local newSiren = (currentSiren + 1) % maxSirens
    SetVehicleSirenTone(vehicle, newSiren)

    QBCore.Functions.Notify('Siren tone: ' .. (newSiren + 1), 'info')
end

function ToggleEmergencyLights(vehicle)
    local lightsOn = IsVehicleSirenOn(vehicle)
    SetVehicleSiren(vehicle, not lightsOn)

    QBCore.Functions.Notify('Emergency lights: ' .. (not lightsOn and 'ON' or 'OFF'), 'info')
end

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================

function IsSpawnPointOccupied(coords)
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in pairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(vehicleCoords - vector3(coords.x, coords.y, coords.z))

        if distance < 3.0 then
            return true
        end
    end

    return false
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- ====================================================================
-- NUI CALLBACKS FOR VEHICLE MENU
-- ====================================================================

-- Spawn vehicle from UI
RegisterNUICallback('spawnVehicle', function(data, cb)
    local stationId = data.stationId
    local vehicleKey = data.vehicleKey
    local spawnIndex = data.spawnIndex or 1

    SpawnEmergencyVehicle(stationId, vehicleKey, spawnIndex)

    cb('ok')
end)

-- Take equipment from vehicle
RegisterNUICallback('takeEquipment', function(data, cb)
    local vehicle = data.vehicle
    local itemName = data.itemName

    -- Server-side equipment handling
    TriggerServerEvent('fl_vehicles:takeEquipment', vehicle, itemName)

    cb('ok')
end)
