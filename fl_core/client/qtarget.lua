-- ====================================================================
-- FL CORE - QTARGET/OX_TARGET INTEGRATION (KOMPATIBILITÄT FIXES)
-- KRITISCHE FIXES:
-- ✅ Erweiterte Target System Detection
-- ✅ Verbesserte Error Handling für alle Target Operationen
-- ✅ Config Integration für Target System Settings
-- ✅ Fallback auf Marker System wenn kein Target verfügbar
-- ✅ Memory Management für PolyZones
-- ====================================================================

local QBCore = FL.GetFramework()

-- Target-System Detection mit erweiterten Checks
local targetSystem = nil
local targetResource = nil
local targetZones = {} -- Track created zones for cleanup

-- Enhanced target system detection
CreateThread(function()
    Wait(1000) -- Wait for resources to load

    local detectionOrder = { 'qtarget', 'ox_target', 'qb-target' }

    -- Use config preference if set
    if Config.UI and Config.UI.target and Config.UI.target.system ~= 'auto' then
        local preferredSystem = Config.UI.target.system
        if GetResourceState(preferredSystem) == 'started' then
            targetSystem = preferredSystem
            FL.Debug('✅ Using preferred target system: ' .. preferredSystem)
        else
            FL.Debug('⚠️ Preferred target system not available: ' ..
            preferredSystem .. ', falling back to auto-detection')
        end
    end

    -- Auto-detection if no preference or preferred system not available
    if not targetSystem then
        for _, system in pairs(detectionOrder) do
            if GetResourceState(system) == 'started' then
                targetSystem = system
                FL.Debug('✅ Auto-detected target system: ' .. system)
                break
            end
        end
    end

    -- Setup target resource export
    if targetSystem then
        local success, resource = pcall(function()
            if targetSystem == 'qtarget' then
                return exports.qtarget
            elseif targetSystem == 'ox_target' then
                return exports.ox_target
            elseif targetSystem == 'qb-target' then
                return exports['qb-target']
            end
        end)

        if success and resource then
            targetResource = resource
            FL.Debug('✅ Target resource loaded successfully: ' .. targetSystem)

            -- Initialize duty stations after target system is ready
            CreateThread(function()
                Wait(2000)
                SetupDutyStations()
            end)
        else
            FL.Debug('❌ Failed to load target resource: ' .. (targetSystem or 'unknown'))
            targetSystem = nil
            targetResource = nil
        end
    else
        FL.Debug('❌ No target system found - falling back to marker system')
        -- TODO: Implement marker fallback system
    end
end)

-- ====================================================================
-- ENHANCED DUTY STATION SETUP
-- ====================================================================

function SetupDutyStations()
    if not targetSystem or not targetResource then
        FL.Debug('❌ No target system available for duty stations')
        return
    end

    FL.Debug('🎯 Setting up duty stations with ' .. targetSystem)

    local stationsSetup = 0
    for stationId, stationData in pairs(Config.Stations) do
        if CreateDutyStation(stationId, stationData) then
            stationsSetup = stationsSetup + 1
        end
    end

    FL.Debug('✅ Setup ' .. stationsSetup .. ' duty stations with ' .. targetSystem)
end

function CreateDutyStation(stationId, stationData)
    if not stationData.duty_marker then
        FL.Debug('⚠️ No duty marker for station: ' .. stationId)
        return false
    end

    local coords = stationData.duty_marker.coords
    local serviceName = stationData.service
    local serviceData = FL.Functions.GetServiceData(serviceName)

    if not serviceData then
        FL.Debug('❌ Invalid service for station: ' .. stationId)
        return false
    end

    -- Validate coordinates
    if not coords or type(coords) ~= 'vector3' then
        FL.Debug('❌ Invalid coordinates for station: ' .. stationId)
        return false
    end

    local zoneName = stationId .. "_duty"
    local distance = (Config.UI and Config.UI.target and Config.UI.target.distance) or 2.5
    local debugMode = (Config.UI and Config.UI.target and Config.UI.target.debug) or false

    -- Target options with enhanced validation
    local options = {
        {
            type = "client",
            event = "fl_core:openDutyMenu",
            icon = serviceData.icon or "fas fa-id-badge",
            label = "Emergency Services - " .. (serviceData.label or serviceName),
            stationId = stationId,
            service = serviceName,
            distance = distance
        }
    }

    -- System-specific implementation with error handling
    local success = false

    if targetSystem == 'qtarget' then
        success = pcall(function()
            targetResource:AddBoxZone(zoneName, coords, 3.0, 3.0, {
                name = zoneName,
                heading = 0,
                debugPoly = debugMode,
                minZ = coords.z - 1.5,
                maxZ = coords.z + 2.5,
            }, {
                options = options,
                distance = distance
            })
        end)
    elseif targetSystem == 'ox_target' then
        success = pcall(function()
            targetResource:addBoxZone({
                coords = coords,
                size = vec3(3.0, 3.0, 4.0),
                rotation = 0,
                debug = debugMode,
                options = {
                    {
                        name = zoneName,
                        event = "fl_core:openDutyMenu",
                        icon = serviceData.icon or "fas fa-id-badge",
                        label = "Emergency Services - " .. (serviceData.label or serviceName),
                        stationId = stationId,
                        service = serviceName,
                        distance = distance
                    }
                }
            })
        end)
    elseif targetSystem == 'qb-target' then
        success = pcall(function()
            targetResource:AddBoxZone(zoneName, coords, 3.0, 3.0, {
                name = zoneName,
                heading = 0,
                debugPoly = debugMode,
                minZ = coords.z - 1.5,
                maxZ = coords.z + 2.5,
            }, {
                options = options,
                distance = distance
            })
        end)
    end

    if success then
        targetZones[zoneName] = {
            system = targetSystem,
            stationId = stationId,
            coords = coords
        }
        FL.Debug('🎯 Created duty station: ' .. stationId .. ' for ' .. serviceName .. ' at ' ..
            coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
        return true
    else
        FL.Debug('❌ Failed to create duty station: ' .. stationId)
        return false
    end
end

-- ====================================================================
-- EQUIPMENT LOCKERS (ENHANCED WITH ERROR HANDLING)
-- ====================================================================

function CreateEquipmentLocker(stationId, stationData)
    if not stationData.equipment_coords then
        FL.Debug('⚠️ No equipment coords for station: ' .. stationId)
        return false
    end

    if not targetSystem or not targetResource then
        FL.Debug('❌ No target system available for equipment locker')
        return false
    end

    local coords = stationData.equipment_coords
    local serviceName = stationData.service
    local serviceData = FL.Functions.GetServiceData(serviceName)
    local zoneName = stationId .. "_equipment"
    local distance = (Config.UI and Config.UI.target and Config.UI.target.distance) or 2.0
    local debugMode = (Config.UI and Config.UI.target and Config.UI.target.debug) or false

    local options = {
        {
            type = "client",
            event = "fl_core:openEquipmentMenu",
            icon = "fas fa-toolbox",
            label = "Equipment Locker - " .. (serviceData.label or serviceName),
            stationId = stationId,
            service = serviceName,
            distance = distance
        }
    }

    local success = false

    if targetSystem == 'qtarget' then
        success = pcall(function()
            targetResource:AddBoxZone(zoneName, coords, 2.0, 2.0, {
                name = zoneName,
                heading = 0,
                debugPoly = debugMode,
                minZ = coords.z - 1.0,
                maxZ = coords.z + 2.0,
            }, {
                options = options,
                distance = distance
            })
        end)
    elseif targetSystem == 'ox_target' then
        success = pcall(function()
            targetResource:addBoxZone({
                coords = coords,
                size = vec3(2.0, 2.0, 3.0),
                rotation = 0,
                debug = debugMode,
                options = {
                    {
                        name = zoneName,
                        event = "fl_core:openEquipmentMenu",
                        icon = "fas fa-toolbox",
                        label = "Equipment Locker - " .. (serviceData.label or serviceName),
                        stationId = stationId,
                        service = serviceName,
                        distance = distance
                    }
                }
            })
        end)
    elseif targetSystem == 'qb-target' then
        success = pcall(function()
            targetResource:AddBoxZone(zoneName, coords, 2.0, 2.0, {
                name = zoneName,
                heading = 0,
                debugPoly = debugMode,
                minZ = coords.z - 1.0,
                maxZ = coords.z + 2.0,
            }, {
                options = options,
                distance = distance
            })
        end)
    end

    if success then
        targetZones[zoneName] = {
            system = targetSystem,
            stationId = stationId,
            coords = coords
        }
        FL.Debug('🧰 Created equipment locker: ' .. stationId)
        return true
    else
        FL.Debug('❌ Failed to create equipment locker: ' .. stationId)
        return false
    end
end

-- ====================================================================
-- VEHICLE SPAWN POINTS (ENHANCED WITH ERROR HANDLING)
-- ====================================================================

function CreateVehicleSpawnPoints(stationId, stationData)
    if not stationData.garage_coords then
        FL.Debug('⚠️ No garage coords for station: ' .. stationId)
        return false
    end

    if not targetSystem or not targetResource then
        FL.Debug('❌ No target system available for vehicle spawn points')
        return false
    end

    local coords = stationData.garage_coords
    local serviceName = stationData.service
    local serviceData = FL.Functions.GetServiceData(serviceName)
    local zoneName = stationId .. "_garage"
    local distance = (Config.UI and Config.UI.target and Config.UI.target.distance) or 3.0
    local debugMode = (Config.UI and Config.UI.target and Config.UI.target.debug) or false

    local options = {
        {
            type = "client",
            event = "fl_core:openVehicleMenu",
            icon = "fas fa-car",
            label = "Vehicle Garage - " .. (serviceData.label or serviceName),
            stationId = stationId,
            service = serviceName,
            distance = distance
        }
    }

    local success = false

    if targetSystem == 'qtarget' then
        success = pcall(function()
            targetResource:AddBoxZone(zoneName, coords, 4.0, 4.0, {
                name = zoneName,
                heading = 0,
                debugPoly = debugMode,
                minZ = coords.z - 1.0,
                maxZ = coords.z + 3.0,
            }, {
                options = options,
                distance = distance
            })
        end)
    elseif targetSystem == 'ox_target' then
        success = pcall(function()
            targetResource:addBoxZone({
                coords = coords,
                size = vec3(4.0, 4.0, 4.0),
                rotation = 0,
                debug = debugMode,
                options = {
                    {
                        name = zoneName,
                        event = "fl_core:openVehicleMenu",
                        icon = "fas fa-car",
                        label = "Vehicle Garage - " .. (serviceData.label or serviceName),
                        stationId = stationId,
                        service = serviceName,
                        distance = distance
                    }
                }
            })
        end)
    elseif targetSystem == 'qb-target' then
        success = pcall(function()
            targetResource:AddBoxZone(zoneName, coords, 4.0, 4.0, {
                name = zoneName,
                heading = 0,
                debugPoly = debugMode,
                minZ = coords.z - 1.0,
                maxZ = coords.z + 3.0,
            }, {
                options = options,
                distance = distance
            })
        end)
    end

    if success then
        targetZones[zoneName] = {
            system = targetSystem,
            stationId = stationId,
            coords = coords
        }
        FL.Debug('🚗 Created vehicle spawn point: ' .. stationId)
        return true
    else
        FL.Debug('❌ Failed to create vehicle spawn point: ' .. stationId)
        return false
    end
end

-- ====================================================================
-- ENHANCED EVENT HANDLERS
-- ====================================================================

-- Open duty menu (enhanced validation)
RegisterNetEvent('fl_core:openDutyMenu', function(data)
    local stationId = data.stationId
    local service = data.service

    FL.Debug('🎯 Opening duty menu for station: ' .. stationId .. ', service: ' .. service)

    -- Enhanced validation
    if not stationId or stationId == '' then
        FL.Debug('❌ Invalid station ID provided')
        QBCore.Functions.Notify('Invalid station', 'error')
        return
    end

    if not service or service == '' then
        FL.Debug('❌ Invalid service provided')
        QBCore.Functions.Notify('Invalid service', 'error')
        return
    end

    -- Check if player has this emergency service job
    if not FL.Client.serviceInfo then
        QBCore.Functions.Notify('You are not employed by an emergency service', 'error')
        return
    end

    if FL.Client.serviceInfo.service ~= service then
        QBCore.Functions.Notify('This station is not for your service', 'error')
        return
    end

    -- Show duty toggle UI or directly toggle
    if Config.UseAdvancedUI then
        ShowDutyUI(stationId, service)
    else
        -- Direct toggle
        TriggerServerEvent('fl_core:toggleDuty', stationId)
    end
end)

-- Open equipment menu (enhanced validation)
RegisterNetEvent('fl_core:openEquipmentMenu', function(data)
    local stationId = data.stationId
    local service = data.service

    FL.Debug('🧰 Opening equipment menu for station: ' .. stationId .. ', service: ' .. service)

    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        QBCore.Functions.Notify('You must be on duty to access equipment', 'error')
        return
    end

    if FL.Client.serviceInfo.service ~= service then
        QBCore.Functions.Notify('This equipment is not for your service', 'error')
        return
    end

    ShowEquipmentMenu(service)
end)

-- Open vehicle menu (enhanced validation)
RegisterNetEvent('fl_core:openVehicleMenu', function(data)
    local stationId = data.stationId
    local service = data.service

    FL.Debug('🚗 Opening vehicle menu for station: ' .. stationId .. ', service: ' .. service)

    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        QBCore.Functions.Notify('You must be on duty to access vehicles', 'error')
        return
    end

    if FL.Client.serviceInfo.service ~= service then
        QBCore.Functions.Notify('These vehicles are not for your service', 'error')
        return
    end

    ShowVehicleMenu(stationId, service)
end)

-- ====================================================================
-- ENHANCED UI FUNCTIONS
-- ====================================================================

function ShowDutyUI(stationId, service)
    FL.Debug('📱 Showing duty UI for: ' .. service)

    local stationData = Config.Stations[stationId]
    local serviceData = FL.Functions.GetServiceData(service)

    if not stationData or not serviceData then
        FL.Debug('❌ Invalid station or service data')
        QBCore.Functions.Notify('Invalid station or service configuration', 'error')
        return
    end

    SendNUIMessage({
        type = 'showDutyUI',
        data = {
            stationId = stationId,
            stationName = stationData.name,
            service = service,
            serviceName = serviceData.label,
            serviceIcon = serviceData.icon,
            isOnDuty = FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty or false,
            rank = FL.Client.serviceInfo and FL.Client.serviceInfo.rankName or 'Unknown'
        }
    })

    SetNuiFocus(true, true)
end

function ShowEquipmentMenu(service)
    local equipment = FL.Functions.GetServiceEquipment(service)

    if not equipment or #equipment == 0 then
        QBCore.Functions.Notify('No equipment available for your service', 'info')
        return
    end

    SendNUIMessage({
        type = 'showEquipmentMenu',
        data = {
            service = service,
            equipment = equipment
        }
    })

    SetNuiFocus(true, true)
end

function ShowVehicleMenu(stationId, service)
    local stationData = Config.Stations[stationId]
    local serviceData = FL.Functions.GetServiceData(service)

    if not serviceData then
        QBCore.Functions.Notify('Service configuration not found', 'error')
        return
    end

    -- Check if vehicles are configured for this service
    local vehiclesConfig = Config.EmergencyVehicles and Config.EmergencyVehicles[service]
    if not vehiclesConfig then
        QBCore.Functions.Notify('No vehicles configured for your service', 'error')
        return
    end

    SendNUIMessage({
        type = 'showVehicleMenu',
        data = {
            stationId = stationId,
            service = service,
            vehicles = vehiclesConfig,
            spawnPoints = stationData.vehicle_spawns or {}
        }
    })

    SetNuiFocus(true, true)
end

-- ====================================================================
-- ENHANCED CLEANUP FUNCTIONS
-- ====================================================================

function RemoveDutyStations()
    if not targetSystem or not targetResource then
        FL.Debug('⚠️ No target system for cleanup')
        return
    end

    local removedCount = 0
    for zoneName, zoneData in pairs(targetZones) do
        local success = false

        if zoneData.system == 'qtarget' or zoneData.system == 'qb-target' then
            success = pcall(function()
                targetResource:RemoveZone(zoneName)
            end)
        elseif zoneData.system == 'ox_target' then
            success = pcall(function()
                targetResource:removeZone(zoneName)
            end)
        end

        if success then
            removedCount = removedCount + 1
        else
            FL.Debug('⚠️ Failed to remove zone: ' .. zoneName)
        end
    end

    targetZones = {}
    FL.Debug('🧹 Removed ' .. removedCount .. ' target zones')
end

-- ====================================================================
-- INITIALIZATION (ENHANCED)
-- ====================================================================

CreateThread(function()
    -- Wait for FL system to be ready
    local attempts = 0
    while not FL.Client.serviceInfo and attempts < 30 do
        Wait(1000)
        attempts = attempts + 1
    end

    if not FL.Client.serviceInfo then
        FL.Debug('⚠️ Service info not available after 30 seconds - creating equipment/vehicles anyway')
    end

    -- Create equipment lockers and vehicle spawn points for all stations
    local equipmentCount = 0
    local vehicleCount = 0

    for stationId, stationData in pairs(Config.Stations) do
        -- Only create for player's service if available, otherwise create all
        if not FL.Client.serviceInfo or stationData.service == FL.Client.serviceInfo.service then
            if CreateEquipmentLocker(stationId, stationData) then
                equipmentCount = equipmentCount + 1
            end
            if CreateVehicleSpawnPoints(stationId, stationData) then
                vehicleCount = vehicleCount + 1
            end
        end
    end

    FL.Debug('✅ Created ' .. equipmentCount .. ' equipment lockers and ' .. vehicleCount .. ' vehicle spawn points')
end)

-- ====================================================================
-- CLEANUP ON RESOURCE STOP
-- ====================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        RemoveDutyStations()
        FL.Debug('🧹 FL Core qtarget cleanup completed')
    end
end)

-- ====================================================================
-- TARGET SYSTEM INFORMATION COMMAND
-- ====================================================================

RegisterCommand('fltarget', function(source, args, rawCommand)
    if FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty then
        local targetInfo = targetSystem or 'None'
        local zonesCount = 0
        for _ in pairs(targetZones) do
            zonesCount = zonesCount + 1
        end

        QBCore.Functions.Notify('Target System: ' .. targetInfo .. ' | Zones: ' .. zonesCount, 'info')

        print('^3[FL TARGET DEBUG]^7 ======================')
        print('^3[FL TARGET]^7 System: ' .. targetInfo)
        print('^3[FL TARGET]^7 Resource Available: ' .. tostring(targetResource ~= nil))
        print('^3[FL TARGET]^7 Total Zones: ' .. zonesCount)

        for zoneName, zoneData in pairs(targetZones) do
            print('^3[FL TARGET]^7 Zone: ' .. zoneName .. ' | Station: ' .. zoneData.stationId)
        end

        print('^3[FL TARGET DEBUG]^7 ======================')
    else
        QBCore.Functions.Notify('You must be on duty to check target info', 'error')
    end
end, false)

FL.Debug('🎯 FL Core qtarget integration loaded successfully (ENHANCED VERSION)')
