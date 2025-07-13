-- ====================================================================
-- FL CORE - QTARGET/OX_TARGET INTEGRATION (PERFORMANCE OPTIMIERT)
-- Ersetzt die MainLoop Marker-Detection komplett
-- ====================================================================

-- client/qtarget.lua - Neue Datei erstellen

local QBCore = FL.GetFramework()

-- Target-System Detection
local targetSystem = nil
local targetResource = nil

-- Detect available target system
CreateThread(function()
    Wait(1000) -- Wait for resources to load

    if GetResourceState('qtarget') == 'started' then
        targetSystem = 'qtarget'
        targetResource = exports.qtarget
        FL.Debug('✅ qtarget detected and loaded')
    elseif GetResourceState('ox_target') == 'started' then
        targetSystem = 'ox_target'
        targetResource = exports.ox_target
        FL.Debug('✅ ox_target detected and loaded')
    elseif GetResourceState('qb-target') == 'started' then
        targetSystem = 'qb-target'
        targetResource = exports['qb-target']
        FL.Debug('✅ qb-target detected and loaded')
    else
        FL.Debug('❌ No target system found - falling back to marker system')
        return
    end

    -- Initialize duty stations after target system is ready
    CreateThread(function()
        Wait(2000)
        SetupDutyStations()
    end)
end)

-- ====================================================================
-- DUTY STATION SETUP (QTARGET VERSION)
-- ====================================================================

function SetupDutyStations()
    if not targetSystem then
        FL.Debug('❌ No target system available for duty stations')
        return
    end

    FL.Debug('🎯 Setting up duty stations with ' .. targetSystem)

    for stationId, stationData in pairs(Config.Stations) do
        CreateDutyStation(stationId, stationData)
    end
end

function CreateDutyStation(stationId, stationData)
    if not stationData.duty_marker then
        FL.Debug('⚠️ No duty marker for station: ' .. stationId)
        return
    end

    local coords = stationData.duty_marker.coords
    local serviceName = stationData.service
    local serviceData = FL.Functions.GetServiceData(serviceName)

    if not serviceData then
        FL.Debug('❌ Invalid service for station: ' .. stationId)
        return
    end

    -- Target options based on system
    local options = {
        {
            type = "client",
            event = "fl_core:openDutyMenu",
            icon = serviceData.icon or "fas fa-id-badge",
            label = "Emergency Services",
            stationId = stationId,
            service = serviceName
        }
    }

    -- System-specific implementation
    if targetSystem == 'qtarget' then
        targetResource:AddBoxZone(stationId .. "_duty", coords, 3.0, 3.0, {
            name = stationId .. "_duty",
            heading = 0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.5,
            maxZ = coords.z + 2.5,
        }, {
            options = options,
            distance = 2.5
        })
    elseif targetSystem == 'ox_target' then
        targetResource:addBoxZone({
            coords = coords,
            size = vec3(3.0, 3.0, 4.0),
            rotation = 0,
            debug = Config.Debug,
            options = {
                {
                    name = stationId .. "_duty",
                    event = "fl_core:openDutyMenu",
                    icon = serviceData.icon or "fas fa-id-badge",
                    label = "Emergency Services",
                    stationId = stationId,
                    service = serviceName
                }
            }
        })
    elseif targetSystem == 'qb-target' then
        targetResource:AddBoxZone(stationId .. "_duty", coords, 3.0, 3.0, {
            name = stationId .. "_duty",
            heading = 0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.5,
            maxZ = coords.z + 2.5,
        }, {
            options = options,
            distance = 2.5
        })
    end

    FL.Debug('🎯 Created duty station: ' .. stationId .. ' for ' .. serviceName .. ' at ' ..
        coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
end

-- ====================================================================
-- EQUIPMENT LOCKERS (QTARGET VERSION)
-- ====================================================================

function CreateEquipmentLocker(stationId, stationData)
    if not stationData.equipment_coords then return end

    local coords = stationData.equipment_coords
    local serviceName = stationData.service
    local serviceData = FL.Functions.GetServiceData(serviceName)

    local options = {
        {
            type = "client",
            event = "fl_core:openEquipmentMenu",
            icon = "fas fa-toolbox",
            label = "Equipment Locker",
            stationId = stationId,
            service = serviceName
        }
    }

    if targetSystem == 'qtarget' then
        targetResource:AddBoxZone(stationId .. "_equipment", coords, 2.0, 2.0, {
            name = stationId .. "_equipment",
            heading = 0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 2.0,
        }, {
            options = options,
            distance = 2.0
        })
    elseif targetSystem == 'ox_target' then
        targetResource:addBoxZone({
            coords = coords,
            size = vec3(2.0, 2.0, 3.0),
            rotation = 0,
            debug = Config.Debug,
            options = {
                {
                    name = stationId .. "_equipment",
                    event = "fl_core:openEquipmentMenu",
                    icon = "fas fa-toolbox",
                    label = "Equipment Locker",
                    stationId = stationId,
                    service = serviceName
                }
            }
        })
    elseif targetSystem == 'qb-target' then
        targetResource:AddBoxZone(stationId .. "_equipment", coords, 2.0, 2.0, {
            name = stationId .. "_equipment",
            heading = 0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 2.0,
        }, {
            options = options,
            distance = 2.0
        })
    end

    FL.Debug('🧰 Created equipment locker: ' .. stationId)
end

-- ====================================================================
-- VEHICLE SPAWN POINTS (QTARGET VERSION)
-- ====================================================================

function CreateVehicleSpawnPoints(stationId, stationData)
    if not stationData.garage_coords then return end

    local coords = stationData.garage_coords
    local serviceName = stationData.service

    local options = {
        {
            type = "client",
            event = "fl_core:openVehicleMenu",
            icon = "fas fa-car",
            label = "Vehicle Garage",
            stationId = stationId,
            service = serviceName
        }
    }

    if targetSystem == 'qtarget' then
        targetResource:AddBoxZone(stationId .. "_garage", coords, 4.0, 4.0, {
            name = stationId .. "_garage",
            heading = 0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 3.0,
        }, {
            options = options,
            distance = 3.0
        })
    elseif targetSystem == 'ox_target' then
        targetResource:addBoxZone({
            coords = coords,
            size = vec3(4.0, 4.0, 4.0),
            rotation = 0,
            debug = Config.Debug,
            options = {
                {
                    name = stationId .. "_garage",
                    event = "fl_core:openVehicleMenu",
                    icon = "fas fa-car",
                    label = "Vehicle Garage",
                    stationId = stationId,
                    service = serviceName
                }
            }
        })
    elseif targetSystem == 'qb-target' then
        targetResource:AddBoxZone(stationId .. "_garage", coords, 4.0, 4.0, {
            name = stationId .. "_garage",
            heading = 0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 3.0,
        }, {
            options = options,
            distance = 3.0
        })
    end

    FL.Debug('🚗 Created vehicle spawn point: ' .. stationId)
end

-- ====================================================================
-- EVENT HANDLERS (NEUE QTARGET EVENTS)
-- ====================================================================

-- Open duty menu (replaces old marker interaction)
RegisterNetEvent('fl_core:openDutyMenu', function(data)
    local stationId = data.stationId
    local service = data.service

    FL.Debug('🎯 Opening duty menu for station: ' .. stationId .. ', service: ' .. service)

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

-- Open equipment menu
RegisterNetEvent('fl_core:openEquipmentMenu', function(data)
    local stationId = data.stationId
    local service = data.service

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

-- Open vehicle menu
RegisterNetEvent('fl_core:openVehicleMenu', function(data)
    local stationId = data.stationId
    local service = data.service

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
-- UI FUNCTIONS (VERBESSERTE VERSIONEN)
-- ====================================================================

function ShowDutyUI(stationId, service)
    FL.Debug('📱 Showing duty UI for: ' .. service)

    local stationData = Config.Stations[stationId]
    local serviceData = FL.Functions.GetServiceData(service)

    if not stationData or not serviceData then
        FL.Debug('❌ Invalid station or service data')
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
            isOnDuty = FL.Client.serviceInfo.isOnDuty,
            rank = FL.Client.serviceInfo.rankName
        }
    })

    SetNuiFocus(true, true)
end

function ShowEquipmentMenu(service)
    local equipment = FL.Functions.GetServiceEquipment(service)

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

    if not serviceData or not serviceData.vehicles then
        QBCore.Functions.Notify('No vehicles available for your service', 'error')
        return
    end

    SendNUIMessage({
        type = 'showVehicleMenu',
        data = {
            stationId = stationId,
            service = service,
            vehicles = serviceData.vehicles,
            spawnPoints = stationData.vehicle_spawns or {}
        }
    })

    SetNuiFocus(true, true)
end

-- ====================================================================
-- CLEANUP FUNCTIONS
-- ====================================================================

function RemoveDutyStations()
    if not targetSystem or not targetResource then return end

    for stationId, stationData in pairs(Config.Stations) do
        if targetSystem == 'qtarget' or targetSystem == 'qb-target' then
            targetResource:RemoveZone(stationId .. "_duty")
            targetResource:RemoveZone(stationId .. "_equipment")
            targetResource:RemoveZone(stationId .. "_garage")
        elseif targetSystem == 'ox_target' then
            targetResource:removeZone(stationId .. "_duty")
            targetResource:removeZone(stationId .. "_equipment")
            targetResource:removeZone(stationId .. "_garage")
        end
    end

    FL.Debug('🧹 Removed all duty stations')
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        RemoveDutyStations()
    end
end)

-- ====================================================================
-- INITIALIZATION (UPDATED)
-- ====================================================================

CreateThread(function()
    -- Wait for FL system to be ready
    while not FL.Client.serviceInfo do
        Wait(1000)
    end

    -- Create equipment lockers and vehicle spawn points
    for stationId, stationData in pairs(Config.Stations) do
        if stationData.service == FL.Client.serviceInfo.service then
            CreateEquipmentLocker(stationId, stationData)
            CreateVehicleSpawnPoints(stationId, stationData)
        end
    end
end)

FL.Debug('🎯 FL Core qtarget integration loaded successfully')

-- ====================================================================
-- CONFIG UPDATES NEEDED
-- ====================================================================

--[[
Add to config.lua:

Config.UseAdvancedUI = true  -- Use UI menus instead of direct toggle
Config.TargetSystem = 'auto' -- 'qtarget', 'ox_target', 'qb-target', or 'auto'

-- Add icons to service config:
Config.EmergencyServices = {
    ['fire'] = {
        label = 'Fire Department',
        icon = 'fas fa-fire',
        -- ... rest of config
    }
}
]]
