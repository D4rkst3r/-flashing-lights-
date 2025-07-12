-- ===================================
-- FLASHING LIGHTS MARKER SYSTEM
-- ===================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Marker management system for emergency services

local ActiveMarkers = {}
local MarkerThreadActive = false

-- ===================================
-- MARKER TYPES
-- ===================================

local MarkerTypes = {
    DUTY_POINT = 'duty_point',
    VEHICLE_SPAWN = 'vehicle_spawn',
    EQUIPMENT_ROOM = 'equipment_room',
    GARAGE = 'garage',
    INCIDENT_LOCATION = 'incident_location',
    HYDRANT = 'hydrant',
    HOSPITAL = 'hospital'
}

-- ===================================
-- MARKER CREATION
-- ===================================

-- Add marker to system
function FL.AddMarker(id, data)
    if ActiveMarkers[id] then
        FL.Debug('Marker ' .. id .. ' already exists, updating...')
    end

    ActiveMarkers[id] = {
        id = id,
        type = data.type or MarkerTypes.DUTY_POINT,
        coords = data.coords,
        size = data.size or vector3(1.5, 1.5, 1.0),
        color = data.color or { r = 0, g = 150, b = 255, a = 100 },
        job = data.job,
        drawDistance = data.drawDistance or 10.0,
        interactDistance = data.interactDistance or 2.0,
        text = data.text or 'Press [E] to interact',
        bobUpAndDown = data.bobUpAndDown or false,
        faceCamera = data.faceCamera or false,
        rotate = data.rotate or false,
        visible = data.visible ~= false,
        onInteract = data.onInteract,
        onEnter = data.onEnter,
        onExit = data.onExit,
        data = data.data or {}
    }

    FL.Debug('Added marker: ' .. id .. ' (' .. data.type .. ') with data: ' .. json.encode(data.data or {}))

    -- Start marker thread if not already running
    if not MarkerThreadActive then
        StartMarkerThread()
    end
end

-- Remove marker from system
function FL.RemoveMarker(id)
    if ActiveMarkers[id] then
        ActiveMarkers[id] = nil
        FL.Debug('Removed marker: ' .. id)
    end
end

-- Update marker data
function FL.UpdateMarker(id, data)
    if ActiveMarkers[id] then
        for key, value in pairs(data) do
            ActiveMarkers[id][key] = value
        end
        FL.Debug('Updated marker: ' .. id)
    end
end

-- Toggle marker visibility
function FL.ToggleMarker(id, visible)
    if ActiveMarkers[id] then
        ActiveMarkers[id].visible = visible
    end
end

-- ===================================
-- MARKER INTERACTION SYSTEM
-- ===================================

local NearMarkers = {}
local LastNearMarkers = {}

-- Main marker thread
function StartMarkerThread()
    MarkerThreadActive = true

    CreateThread(function()
        while next(ActiveMarkers) do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            -- Clear near markers
            LastNearMarkers = NearMarkers
            NearMarkers = {}

            -- Check all active markers
            for id, marker in pairs(ActiveMarkers) do
                if marker.visible then
                    local distance = FL.GetDistance(coords, marker.coords)

                    -- Check if marker should be drawn
                    if distance <= marker.drawDistance then
                        sleep = 0

                        -- Draw the marker
                        DrawMarkerWithEffects(marker)

                        -- Check interaction distance
                        if distance <= marker.interactDistance then
                            -- Check if player can interact with this marker
                            if FL.CanInteractWithMarker(marker) then
                                NearMarkers[id] = marker

                                -- Show interaction text
                                if marker.text then
                                    FL.DrawText3D(
                                        vector3(marker.coords.x, marker.coords.y, marker.coords.z + 0.5),
                                        marker.text
                                    )
                                end

                                -- Check for interaction
                                if IsControlJustReleased(0, 38) then -- E key
                                    HandleMarkerInteraction(marker)
                                end

                                -- Handle enter event
                                if not LastNearMarkers[id] and marker.onEnter then
                                    marker.onEnter(marker)
                                end
                            end
                        else
                            -- Handle exit event
                            if LastNearMarkers[id] and marker.onExit then
                                marker.onExit(marker)
                            end
                        end
                    end
                end
            end

            Wait(sleep)
        end

        MarkerThreadActive = false
        FL.Debug('Marker thread stopped - no active markers')
    end)
end

-- Draw marker with visual effects
function DrawMarkerWithEffects(marker)
    local markerType = GetMarkerTypeForCategory(marker.type)

    -- Main marker
    DrawMarker(
        markerType,
        marker.coords.x, marker.coords.y, marker.coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        marker.size.x, marker.size.y, marker.size.z,
        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
        marker.bobUpAndDown,
        marker.faceCamera,
        2,
        marker.rotate,
        nil, nil, false
    )

    -- Add glow effect for certain marker types
    if marker.type == MarkerTypes.DUTY_POINT or marker.type == MarkerTypes.INCIDENT_LOCATION then
        FL.DrawGlowMarker(
            markerType,
            marker.coords,
            vector3(marker.size.x * 1.2, marker.size.y * 1.2, marker.size.z * 0.5),
            { r = marker.color.r, g = marker.color.g, b = marker.color.b, a = math.floor(marker.color.a * 0.3) },
            marker.bobUpAndDown,
            marker.faceCamera,
            marker.rotate
        )
    end
end

-- Get appropriate marker type for category
function GetMarkerTypeForCategory(category)
    local types = {
        [MarkerTypes.DUTY_POINT] = 1,        -- Upside down cone
        [MarkerTypes.VEHICLE_SPAWN] = 36,    -- Vehicle marker
        [MarkerTypes.EQUIPMENT_ROOM] = 20,   -- Cylinder
        [MarkerTypes.GARAGE] = 50,           -- Garage marker
        [MarkerTypes.INCIDENT_LOCATION] = 1, -- Upside down cone
        [MarkerTypes.HYDRANT] = 28,          -- Ring
        [MarkerTypes.HOSPITAL] = 1           -- Upside down cone
    }

    return types[category] or 1
end

-- Handle marker interaction
function HandleMarkerInteraction(marker)
    FL.Debug('Interacting with marker: ' .. marker.id .. ' (' .. marker.type .. ')')

    if marker.onInteract then
        marker.onInteract(marker)
    else
        -- Default interactions based on marker type
        DefaultMarkerInteraction(marker)
    end
end

-- Default marker interactions
function DefaultMarkerInteraction(marker)
    if marker.type == MarkerTypes.DUTY_POINT then
        HandleDutyInteraction(marker)
    elseif marker.type == MarkerTypes.VEHICLE_SPAWN then
        HandleVehicleSpawn(marker)
    elseif marker.type == MarkerTypes.EQUIPMENT_ROOM then
        HandleEquipmentRoom(marker)
    elseif marker.type == MarkerTypes.GARAGE then
        HandleGarage(marker)
    end
end

-- ===================================
-- SPECIFIC MARKER HANDLERS
-- ===================================

-- Handle duty point interaction
function HandleDutyInteraction(marker)
    FL.Debug('HandleDutyInteraction called with marker ID: ' .. (marker.id or 'unknown'))
    FL.Debug('Marker data: ' .. json.encode(marker.data or {}))

    local stationId = marker.data and marker.data.station
    if stationId then
        FL.Debug('Opening modern duty tablet for station: ' .. stationId)

        -- Show the modern tablet UI and give hint about F6
        ShowDutyUI(stationId)
        QBCore.Functions.Notify('TIP: You can press F6 anywhere to open your tablet!', 'primary', 5000)
    else
        local availableKeys = {}
        if marker.data then
            for key, _ in pairs(marker.data) do
                table.insert(availableKeys, key)
            end
        end
        FL.Debug('No station data found in marker. Available data keys: ' .. json.encode(availableKeys))
    end
end

-- Handle vehicle spawn interaction
function HandleVehicleSpawn(marker)
    if marker.data then
        TriggerEvent('fl_core:vehicleSpawnMenu', marker.data)
    end
end

-- Handle equipment room interaction
function HandleEquipmentRoom(marker)
    if marker.data then
        TriggerEvent('fl_core:equipmentMenu', marker.data)
    end
end

-- Handle garage interaction
function HandleGarage(marker)
    if marker.data then
        TriggerEvent('fl_core:garageMenu', marker.data)
    end
end

-- ===================================
-- STATION MARKER SETUP
-- ===================================

-- Setup markers for a specific station
function FL.SetupStationMarkers(stationId, stationData)
    local job = stationData.job

    -- Duty point marker
    if stationData.duty_point then
        FL.AddMarker('duty_' .. stationId, {
            type = MarkerTypes.DUTY_POINT,
            coords = stationData.duty_point,
            job = job,
            text = '~INPUT_CONTEXT~ Clock In/Out',
            color = GetJobColor(job),
            data = {
                station = stationId,
                stationData = stationData
            }
            -- Removed onInteract - using default handler
        })
    end

    -- Vehicle spawn marker
    if stationData.garage then
        FL.AddMarker('garage_' .. stationId, {
            type = MarkerTypes.VEHICLE_SPAWN,
            coords = stationData.garage,
            job = job,
            text = '~INPUT_CONTEXT~ Vehicle Garage',
            color = GetJobColor(job),
            data = {
                station = stationId,
                job = job,
                stationData = stationData
            }
        })
    end

    -- Equipment room marker
    if stationData.equipment_room then
        FL.AddMarker('equipment_' .. stationId, {
            type = MarkerTypes.EQUIPMENT_ROOM,
            coords = stationData.equipment_room,
            job = job,
            text = '~INPUT_CONTEXT~ Equipment Room',
            color = GetJobColor(job),
            data = {
                station = stationId,
                job = job,
                stationData = stationData
            }
        })
    end

    FL.Debug('Setup markers for station: ' .. stationId .. ' with data: ' .. json.encode({ station = stationId }))
end

-- Remove all markers for a station
function FL.RemoveStationMarkers(stationId)
    FL.RemoveMarker('duty_' .. stationId)
    FL.RemoveMarker('garage_' .. stationId)
    FL.RemoveMarker('equipment_' .. stationId)
end

-- ===================================
-- INCIDENT MARKERS
-- ===================================

-- Create incident marker
function FL.CreateIncidentMarker(incidentId, incidentData)
    local color = GetIncidentColor(incidentData.priority)

    FL.AddMarker('incident_' .. incidentId, {
        type = MarkerTypes.INCIDENT_LOCATION,
        coords = incidentData.location,
        size = vector3(2.0, 2.0, 1.5),
        color = color,
        text = '~INPUT_CONTEXT~ ' .. incidentData.title,
        bobUpAndDown = true,
        drawDistance = 50.0,
        data = {
            incident = incidentData
        },
        onInteract = function(marker)
            TriggerEvent('fl_dispatch:viewIncident', incidentData)
        end
    })

    FL.Debug('Created incident marker for: ' .. incidentId)
end

-- Remove incident marker
function FL.RemoveIncidentMarker(incidentId)
    FL.RemoveMarker('incident_' .. incidentId)
end

-- ===================================
-- UTILITY FUNCTIONS
-- ===================================

-- Get job-specific color
function GetJobColor(job)
    local colors = {
        ['fire'] = { r = 220, g = 53, b = 69, a = 150 },    -- Red
        ['ambulance'] = { r = 40, g = 167, b = 69, a = 150 }, -- Green
        ['police'] = { r = 0, g = 123, b = 255, a = 150 }   -- Blue
    }

    return colors[job] or { r = 128, g = 128, b = 128, a = 150 }
end

-- Get incident priority color
function GetIncidentColor(priority)
    local colors = {
        [1] = { r = 255, g = 0, b = 0, a = 200 },  -- Critical - Red
        [2] = { r = 255, g = 165, b = 0, a = 200 }, -- High - Orange
        [3] = { r = 255, g = 255, b = 0, a = 200 }, -- Medium - Yellow
        [4] = { r = 0, g = 255, b = 0, a = 200 },  -- Low - Green
        [5] = { r = 128, g = 128, b = 128, a = 200 } -- Info - Gray
    }

    return colors[priority] or colors[3]
end

-- Check if player can interact with marker
function FL.CanInteractWithMarker(marker)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then return false end

    -- Check job requirement
    if marker.job and marker.job ~= PlayerData.job.name then
        return false
    end

    -- Check if marker type requires being on duty
    local dutyRequiredTypes = {
        MarkerTypes.VEHICLE_SPAWN,
        MarkerTypes.EQUIPMENT_ROOM,
        MarkerTypes.GARAGE
    }

    for _, requiredType in pairs(dutyRequiredTypes) do
        if marker.type == requiredType and not PlayerData.job.onduty then
            return false
        end
    end

    return true
end

-- Get markers near coordinates
function FL.GetMarkersNear(coords, radius)
    local nearMarkers = {}

    for id, marker in pairs(ActiveMarkers) do
        if marker.visible then
            local distance = FL.GetDistance(coords, marker.coords)
            if distance <= radius then
                table.insert(nearMarkers, {
                    id = id,
                    marker = marker,
                    distance = distance
                })
            end
        end
    end

    -- Sort by distance
    table.sort(nearMarkers, function(a, b)
        return a.distance < b.distance
    end)

    return nearMarkers
end

-- Get all active markers
function FL.GetActiveMarkers()
    return ActiveMarkers
end

-- Clear all markers
function FL.ClearAllMarkers()
    ActiveMarkers = {}
    NearMarkers = {}
    LastNearMarkers = {}
    FL.Debug('Cleared all markers')
end

-- ===================================
-- EXPORTS
-- ===================================

-- Export marker functions for other resources
exports('AddMarker', FL.AddMarker)
exports('RemoveMarker', FL.RemoveMarker)
exports('UpdateMarker', FL.UpdateMarker)
exports('ToggleMarker', FL.ToggleMarker)
exports('CreateIncidentMarker', FL.CreateIncidentMarker)
exports('RemoveIncidentMarker', FL.RemoveIncidentMarker)
exports('GetMarkersNear', FL.GetMarkersNear)
exports('GetActiveMarkers', FL.GetActiveMarkers)
exports('ClearAllMarkers', FL.ClearAllMarkers)

FL.Debug('Marker system loaded')
