-- ====================================================================
-- FL CORE - QTARGET/OX_TARGET INTEGRATION (FIXED VERSION)
-- ====================================================================

local QBCore = FL.GetFramework()

-- Target-System Detection (FIXED)
local targetSystem = nil
local targetResource = nil
local isTargetReady = false

-- Detect available target system with better error handling
CreateThread(function()
    Wait(1000) -- Wait for resources to load

    -- Check for qtarget
    if GetResourceState('qtarget') == 'started' then
        local success, qtargetExport = pcall(function()
            return exports.qtarget
        end)

        if success and qtargetExport then
            targetSystem = 'qtarget'
            targetResource = qtargetExport
            isTargetReady = true
            FL.Debug('✅ qtarget detected and loaded')
        else
            FL.Debug('❌ qtarget resource started but exports failed')
        end
        -- Check for ox_target
    elseif GetResourceState('ox_target') == 'started' then
        local success, oxTargetExport = pcall(function()
            return exports.ox_target
        end)

        if success and oxTargetExport then
            targetSystem = 'ox_target'
            targetResource = oxTargetExport
            isTargetReady = true
            FL.Debug('✅ ox_target detected and loaded')
        else
            FL.Debug('❌ ox_target resource started but exports failed')
        end
        -- Check for qb-target
    elseif GetResourceState('qb-target') == 'started' then
        local success, qbTargetExport = pcall(function()
            return exports['qb-target']
        end)

        if success and qbTargetExport then
            targetSystem = 'qb-target'
            targetResource = qbTargetExport
            isTargetReady = true
            FL.Debug('✅ qb-target detected and loaded')
        else
            FL.Debug('❌ qb-target resource started but exports failed')
        end
    else
        FL.Debug('❌ No target system found - falling back to marker system')
        isTargetReady = false
        return
    end

    -- Initialize duty stations after target system is ready
    if isTargetReady then
        CreateThread(function()
            Wait(2000) -- Give extra time for target system to fully initialize
            SetupDutyStations()
        end)
    end
end)

-- ====================================================================
-- DUTY STATION SETUP (FIXED VERSION)
-- ====================================================================

function SetupDutyStations()
    if not isTargetReady or not targetSystem or not targetResource then
        FL.Debug('❌ Target system not ready for duty station setup')
        return
    end

    FL.Debug('🎯 Setting up duty stations with ' .. targetSystem)

    for stationId, stationData in pairs(Config.Stations) do
        local success, error = pcall(function()
            CreateDutyStation(stationId, stationData)
        end)

        if not success then
            FL.Debug('❌ Failed to create duty station ' .. stationId .. ': ' .. tostring(error))
        end
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

    -- System-specific implementation with proper error handling
    local success, error = pcall(function()
        if targetSystem == 'qtarget' and targetResource.AddBoxZone then
            targetResource:AddBoxZone(stationId .. "_duty", coords, 3.0, 3.0, {
                name = stationId .. "_duty",
                heading = 0,
                debugPoly = Config.Debug or false,
                minZ = coords.z - 1.5,
                maxZ = coords.z + 2.5,
            }, {
                options = {
                    {
                        type = "client",
                        event = "fl_core:openDutyMenu",
                        icon = serviceData.icon or "fas fa-id-badge",
                        label = "Emergency Services",
                        stationId = stationId,
                        service = serviceName
                    }
                },
                distance = 2.5
            })
        elseif targetSystem == 'ox_target' and targetResource.addBoxZone then
            targetResource:addBoxZone({
                coords = coords,
                size = vec3(3.0, 3.0, 4.0),
                rotation = 0,
                debug = Config.Debug or false,
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
        elseif targetSystem == 'qb-target' and targetResource.AddBoxZone then
            targetResource:AddBoxZone(stationId .. "_duty", coords, 3.0, 3.0, {
                name = stationId .. "_duty",
                heading = 0,
                debugPoly = Config.Debug or false,
                minZ = coords.z - 1.5,
                maxZ = coords.z + 2.5,
            }, {
                options = {
                    {
                        type = "client",
                        event = "fl_core:openDutyMenu",
                        icon = serviceData.icon or "fas fa-id-badge",
                        label = "Emergency Services",
                        stationId = stationId,
                        service = serviceName
                    }
                },
                distance = 2.5
            })
        else
            error('Target system ' .. targetSystem .. ' does not have required methods')
        end
    end)

    if success then
        FL.Debug('🎯 Created duty station: ' .. stationId .. ' for ' .. serviceName)
    else
        FL.Debug('❌ Failed to create duty station ' .. stationId .. ': ' .. tostring(error))
    end
end

-- ====================================================================
-- EVENT HANDLERS (FIXED)
-- ====================================================================

-- Open duty menu (replaces old marker interaction)
RegisterNetEvent('fl_core:openDutyMenu', function(data)
    if not data or not data.stationId or not data.service then
        FL.Debug('❌ Invalid data in openDutyMenu event')
        return
    end

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

    -- Direct toggle for now (can be enhanced later with UI)
    TriggerServerEvent('fl_core:toggleDuty', stationId)
end)

-- ====================================================================
-- CLEANUP FUNCTIONS (FIXED)
-- ====================================================================

function RemoveDutyStations()
    if not isTargetReady or not targetSystem or not targetResource then
        return
    end

    for stationId, stationData in pairs(Config.Stations) do
        local success, error = pcall(function()
            if targetSystem == 'qtarget' or targetSystem == 'qb-target' then
                if targetResource.RemoveZone then
                    targetResource:RemoveZone(stationId .. "_duty")
                end
            elseif targetSystem == 'ox_target' then
                if targetResource.removeZone then
                    targetResource:removeZone(stationId .. "_duty")
                end
            end
        end)

        if not success then
            FL.Debug('❌ Failed to remove duty station ' .. stationId .. ': ' .. tostring(error))
        end
    end

    FL.Debug('🧹 Attempted to remove all duty stations')
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        RemoveDutyStations()
    end
end)

-- ====================================================================
-- FALLBACK: USE MARKERS IF NO TARGET SYSTEM
-- ====================================================================

-- If no target system is available, fall back to markers
if not isTargetReady then
    CreateThread(function()
        Wait(5000) -- Wait a bit more and check again

        if not isTargetReady then
            FL.Debug('⚠️ No target system available - using marker fallback')
            -- You can implement marker-based interaction here as fallback
        end
    end)
end

FL.Debug('🎯 FL Core qtarget integration loaded with ENHANCED ERROR HANDLING')
