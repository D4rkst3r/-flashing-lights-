-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - CLIENT MAIN (MULTI-UNIT + VOLLSTÄNDIGE DEBUG VERSION)
-- BASIERT AUF DEINER DEBUG VERSION + MULTI-UNIT FEATURES
-- ====================================================================

local QBCore = FL.GetFramework()

-- Client state variables (nil-safe initialized + Multi-Unit Support)
FL.Client = {
    serviceInfo = nil,                           -- Current service info from server
    activeCalls = {},                            -- Active emergency calls
    nearbyMarkers = {},                          -- Nearby station markers
    showingUI = false,                           -- UI state
    playerPed = 0,                               -- Initialize as 0 instead of nil
    playerSource = GetPlayerServerId(PlayerId()) -- Player's server ID for Multi-Unit
}

-- Job to service mapping (same as server)
FL.JobMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ambulance'] = 'ems'
}

-- ====================================================================
-- NULL-SAFE HELPER FUNCTIONS
-- ====================================================================

-- Safe PlayerPedId getter with validation
local function GetSafePlayerPed()
    local ped = PlayerPedId()
    if ped and ped > 0 and DoesEntityExist(ped) then
        return ped
    end
    return 0 -- Return 0 instead of nil for integer compatibility
end

-- Safe integer conversion
local function SafeInt(value, default)
    if type(value) == "number" and value >= 0 then
        return math.floor(value)
    end
    return default or 0
end

-- Safe entity check
local function IsValidEntity(entity)
    return entity and entity > 0 and DoesEntityExist(entity)
end

-- ====================================================================
-- INITIALIZATION (ENHANCED)
-- ====================================================================

CreateThread(function()
    while QBCore == nil do
        QBCore = FL.GetFramework()
        Wait(200)
    end

    -- Initialize player data with validation
    FL.Client.playerPed = GetSafePlayerPed()
    FL.Client.playerSource = GetPlayerServerId(PlayerId())

    FL.Debug('🆔 Player Source ID: ' .. FL.Client.playerSource)

    -- Wait for valid player ped
    while FL.Client.playerPed == 0 do
        Wait(500)
        FL.Client.playerPed = GetSafePlayerPed()
    end

    -- Request service info from server
    TriggerServerEvent('fl_core:getServiceInfo')

    -- Create station blips
    CreateStationBlips()

    -- Start main loop
    MainLoop()

    FL.Debug('Client script initialized with QBCore integration + Multi-Unit Support')
end)

-- Update player ped regularly to handle respawns
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        local newPed = GetSafePlayerPed()
        if newPed ~= FL.Client.playerPed and newPed > 0 then
            FL.Client.playerPed = newPed
            FL.Debug('Player ped updated: ' .. newPed)
        end
    end
end)

-- ====================================================================
-- NUI CALLBACKS (ENHANCED WITH MULTI-UNIT SUPPORT)
-- ====================================================================

-- NUI: Assign to call (ENHANCED)
RegisterNUICallback('assignToCall', function(data, cb)
    FL.Debug('📱 NUI Callback: assignToCall - Data: ' .. json.encode(data))

    local callId = data.callId
    if not callId then
        FL.Debug('❌ No callId provided in NUI callback')
        cb({ success = false, message = 'No call ID provided' })
        return
    end

    -- Validate service and duty status
    if not FL.Client.serviceInfo then
        FL.Debug('❌ No service info available')
        cb({ success = false, message = 'Service info not available' })
        return
    end

    if not FL.Client.serviceInfo.isOnDuty then
        FL.Debug('❌ Player not on duty')
        cb({ success = false, message = 'You must be on duty' })
        return
    end

    FL.Debug('✅ Validation passed, sending server event for assignment')

    -- Send server event instead of handling directly
    TriggerServerEvent('fl_core:assignToCallFromUI', callId)

    -- Respond to NUI immediately (server will handle the logic)
    cb({
        success = true,
        message = 'Assignment request sent to server',
        callId = callId
    })
end)

-- NEW: NUI Callback for starting work on call (MULTI-UNIT FEATURE)
RegisterNUICallback('startWorkOnCall', function(data, cb)
    FL.Debug('📱 NUI Callback: startWorkOnCall - Data: ' .. json.encode(data))

    local callId = data.callId
    if not callId then
        FL.Debug('❌ No callId provided in NUI callback')
        cb({ success = false, message = 'No call ID provided' })
        return
    end

    -- Validate service and duty status
    if not FL.Client.serviceInfo then
        FL.Debug('❌ No service info available')
        cb({ success = false, message = 'Service info not available' })
        return
    end

    if not FL.Client.serviceInfo.isOnDuty then
        FL.Debug('❌ Player not on duty')
        cb({ success = false, message = 'You must be on duty' })
        return
    end

    FL.Debug('✅ Validation passed, sending server event for start work')

    -- Send server event
    TriggerServerEvent('fl_core:startWorkOnCallFromUI', callId)

    -- Respond to NUI immediately
    cb({
        success = true,
        message = 'Start work request sent to server',
        callId = callId
    })
end)

-- NUI: Complete call (ENHANCED)
RegisterNUICallback('completeCall', function(data, cb)
    FL.Debug('📱 NUI Callback: completeCall - Data: ' .. json.encode(data))

    local callId = data.callId
    if not callId then
        FL.Debug('❌ No callId provided in NUI callback')
        cb({ success = false, message = 'No call ID provided' })
        return
    end

    -- Validate service and duty status
    if not FL.Client.serviceInfo then
        FL.Debug('❌ No service info available')
        cb({ success = false, message = 'Service info not available' })
        return
    end

    if not FL.Client.serviceInfo.isOnDuty then
        FL.Debug('❌ Player not on duty')
        cb({ success = false, message = 'You must be on duty' })
        return
    end

    FL.Debug('✅ Validation passed, sending server event for completion')

    -- Send server event instead of handling directly
    TriggerServerEvent('fl_core:completeCallFromUI', callId)

    -- Respond to NUI immediately (server will handle the logic)
    cb({
        success = true,
        message = 'Completion request sent to server',
        callId = callId
    })
end)

-- NUI: Close UI (unchanged)
RegisterNUICallback('closeUI', function(data, cb)
    FL.Debug('📱 NUI Callback: closeUI')
    CloseMDT()
    cb('ok')
end)

-- ====================================================================
-- SERVER EVENT HANDLERS (ENHANCED FOR MULTI-UNIT)
-- ====================================================================

-- Handle assignment result from server
RegisterNetEvent('fl_core:assignmentResult', function(result)
    FL.Debug('📱 Assignment result received: ' .. json.encode(result))

    if result.success then
        QBCore.Functions.Notify('Successfully assigned to call ' .. result.callId, 'success')
    else
        QBCore.Functions.Notify('Assignment failed: ' .. result.message, 'error')
    end
end)

-- NEW: Handle start work result from server (MULTI-UNIT FEATURE)
RegisterNetEvent('fl_core:startWorkResult', function(result)
    FL.Debug('📱 Start work result received: ' .. json.encode(result))

    if result.success then
        QBCore.Functions.Notify('Started working on call ' .. result.callId, 'success')
    else
        QBCore.Functions.Notify('Start work failed: ' .. result.message, 'error')
    end
end)

-- Handle completion result from server
RegisterNetEvent('fl_core:completionResult', function(result)
    FL.Debug('📱 Completion result received: ' .. json.encode(result))

    if result.success then
        QBCore.Functions.Notify('Successfully completed call ' .. result.callId, 'success')
    else
        QBCore.Functions.Notify('Completion failed: ' .. result.message, 'error')
    end
end)

-- ====================================================================
-- EVENT HANDLERS (ENHANCED WITH MULTI-UNIT LOGGING)
-- ====================================================================

-- Server events
RegisterNetEvent('fl_core:serviceInfo', function(serviceInfo)
    FL.Client.serviceInfo = serviceInfo
    FL.Debug('✅ Received service info: ' .. (serviceInfo and serviceInfo.service or 'none'))
    if serviceInfo then
        FL.Debug('👤 Service details: ' .. json.encode(serviceInfo))
    end
end)

RegisterNetEvent('fl_core:dutyChanged', function(onDuty, service, rank)
    FL.Debug('🔄 Duty changed: ' .. tostring(onDuty) .. ' for ' .. tostring(service))
    -- This is handled by QBCore job events now
end)

-- NEW EMERGENCY CALL (ENHANCED FOR MULTI-UNIT)
RegisterNetEvent('fl_core:newEmergencyCall', function(callData)
    FL.Debug('🆕 NEW CALL RECEIVED: ' ..
        callData.id .. ' for service: ' .. callData.service .. ' - Status: ' .. callData.status)

    -- Store call in local storage
    FL.Client.activeCalls[callData.id] = callData

    -- Show notification with enhanced info
    local priorityText = FL.Functions.FormatPriority(callData.priority)
    local maxUnits = callData.max_units or 4
    QBCore.Functions.Notify('New ' .. priorityText .. ' call: ' .. callData.type .. ' (Max Units: ' .. maxUnits .. ')',
        'error')

    -- Play alert sound (FIXED: boolean instead of integer)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)

    -- Force update MDT if it's open
    if FL.Client.showingUI then
        FL.Debug('📱 MDT is open - FORCING immediate UI update')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })

        -- Also send specific new call event
        SendNUIMessage({
            type = 'newCall',
            callData = callData
        })
    else
        FL.Debug('📱 MDT is closed - no UI update needed')
    end
end)

-- CALL ASSIGNED (ENHANCED FOR MULTI-UNIT)
RegisterNetEvent('fl_core:callAssigned', function(callData)
    FL.Debug('📞 CALL ASSIGNED EVENT: ' .. callData.id .. ' - New Status: ' .. callData.status)
    FL.Debug('👥 Assigned Units Count: ' .. #(callData.assigned_units or {}))
    FL.Debug('🏷️ Unit Details Count: ' .. #(callData.unit_details or {}))

    -- Critical: Update local storage IMMEDIATELY
    FL.Client.activeCalls[callData.id] = callData

    -- Show waypoint
    if callData.coords then
        SetNewWaypoint(callData.coords.x, callData.coords.y)
        FL.Debug('🗺️ Waypoint set to: ' .. callData.coords.x .. ', ' .. callData.coords.y)
    end

    -- Enhanced notification with unit count
    local unitCount = #(callData.unit_details or {})
    local notificationText = 'You have been assigned to call ' .. callData.id
    if unitCount > 1 then
        notificationText = notificationText .. ' (' .. unitCount .. ' units total)'
    end
    QBCore.Functions.Notify(notificationText, 'success')

    -- FORCE MDT update with detailed logging
    if FL.Client.showingUI then
        FL.Debug('📱 MDT IS OPEN - Sending multiple UI updates')

        -- Send general update
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })

        -- Send specific assignment event
        SendNUIMessage({
            type = 'callAssigned',
            callId = callData.id,
            callData = callData
        })

        -- Force refresh with timeout to ensure UI updates
        CreateThread(function()
            Wait(100)
            SendNUIMessage({
                type = 'forceRefresh',
                data = FL.Client.activeCalls
            })
            FL.Debug('📱 Sent force refresh to UI')
        end)
    else
        FL.Debug('📱 MDT is closed - assignment noted but no UI update needed')
    end

    FL.Debug('✅ Call assignment processing completed')
end)

-- CALL STATUS UPDATE (ENHANCED FOR MULTI-UNIT)
RegisterNetEvent('fl_core:callStatusUpdate', function(callId, callData)
    FL.Debug('📋 CALL STATUS UPDATE EVENT: ' .. callId .. ' - New Status: ' .. callData.status)
    FL.Debug('👥 Updated Units Count: ' .. #(callData.assigned_units or {}))

    -- Update local storage
    FL.Client.activeCalls[callId] = callData

    FL.Debug('💾 Updated local call: ' .. callId .. ' to status: ' .. callData.status)

    -- IMMEDIATE UI update if MDT is open
    if FL.Client.showingUI then
        FL.Debug('📱 FORCING UI UPDATE for status change')

        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })

        SendNUIMessage({
            type = 'callStatusChanged',
            callId = callId,
            newStatus = callData.status,
            callData = callData
        })
    end
end)

-- CALL COMPLETED (ENHANCED)
RegisterNetEvent('fl_core:callCompleted', function(callId)
    FL.Debug('✅ CALL COMPLETED EVENT: ' .. callId)

    -- Remove from local storage
    FL.Client.activeCalls[callId] = nil

    QBCore.Functions.Notify('Call ' .. callId .. ' completed', 'success')

    -- Update MDT if open
    if FL.Client.showingUI then
        FL.Debug('📱 FORCING UI UPDATE after completion')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })

        SendNUIMessage({
            type = 'callCompleted',
            callId = callId
        })
    end
end)

-- ACTIVE CALLS (ENHANCED FOR MULTI-UNIT)
RegisterNetEvent('fl_core:activeCalls', function(calls)
    FL.Debug('📋 RECEIVED ACTIVE CALLS FROM SERVER: ' .. FL.Functions.TableSize(calls) .. ' calls')

    -- Validate and store calls with unit details logging
    local validCalls = {}
    for callId, callData in pairs(calls) do
        if callData and callData.id and callData.status then
            validCalls[callId] = callData
            local unitCount = #(callData.unit_details or {})
            FL.Debug('📞 Valid call: ' ..
                callId ..
                ' - Status: ' ..
                callData.status .. ' - Type: ' .. (callData.type or 'unknown') .. ' - Units: ' .. unitCount)
        else
            FL.Debug('❌ Invalid call data for: ' .. tostring(callId))
        end
    end

    FL.Client.activeCalls = validCalls

    -- Update MDT if open with detailed logging
    if FL.Client.showingUI then
        FL.Debug('📱 SENDING VALIDATED CALLS TO UI: ' .. FL.Functions.TableSize(validCalls) .. ' calls')

        -- Send player source to UI for assignment checking (MULTI-UNIT FEATURE)
        SendNUIMessage({
            type = 'setPlayerSource',
            source = FL.Client.playerSource
        })

        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })

        -- Debug output each call for UI
        for callId, callData in pairs(FL.Client.activeCalls) do
            local unitCount = #(callData.unit_details or {})
            FL.Debug('📤 Sending to UI - Call: ' .. callId .. ' Status: ' .. callData.status .. ' Units: ' .. unitCount)
        end
    else
        FL.Debug('📱 MDT not open - calls stored but not sent to UI')
    end
end)

-- ====================================================================
-- JOB INTEGRATION (ENHANCED)
-- ====================================================================

-- Handle QBCore job updates
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    FL.Debug('Job updated: ' .. job.name .. ' (Grade: ' .. job.grade.level .. ', Duty: ' .. tostring(job.onduty) .. ')')

    -- Check if it's an emergency service job
    local service = FL.JobMapping[job.name]
    if service then
        FL.Debug('✅ Emergency service job detected: ' .. service)

        -- Update service info
        FL.Client.serviceInfo = {
            service = service,
            rank = job.grade.level,
            rankName = job.grade.name,
            isOnDuty = job.onduty,
            qbJob = job.name
        }

        FL.Debug('👤 Updated service info: ' .. json.encode(FL.Client.serviceInfo))

        -- Handle uniform and equipment (NULL-SAFE)
        if job.onduty then
            FL.Debug('👕 Going on duty - applying uniform and equipment')
            ApplyUniform(service)
            GiveServiceEquipment(service)
        else
            FL.Debug('👔 Going off duty - removing uniform and equipment')
            RemoveUniform()
            if FL.Client.serviceInfo and FL.Client.serviceInfo.service then
                RemoveServiceEquipment(FL.Client.serviceInfo.service)
            end
        end

        -- Update active calls
        if job.onduty then
            FL.Debug('📞 Requesting active calls from server')
            TriggerServerEvent('fl_core:getActiveCalls')
        else
            FL.Debug('📞 Clearing active calls (off duty)')
            FL.Client.activeCalls = {}
        end
    else
        FL.Debug('❌ Not an emergency service job: ' .. job.name)
        -- Not an emergency service job
        FL.Client.serviceInfo = nil
        FL.Client.activeCalls = {}
    end
end)

-- Handle duty status updates
RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    FL.Debug('🔄 Duty status update: ' .. tostring(duty))

    if FL.Client.serviceInfo then
        FL.Client.serviceInfo.isOnDuty = duty

        if duty then
            FL.Debug('✅ Starting duty procedures')
            ApplyUniform(FL.Client.serviceInfo.service)
            GiveServiceEquipment(FL.Client.serviceInfo.service)
            TriggerServerEvent('fl_core:getActiveCalls')
        else
            FL.Debug('❌ Ending duty procedures')
            RemoveUniform()
            RemoveServiceEquipment(FL.Client.serviceInfo.service)
            FL.Client.activeCalls = {}
        end
    else
        FL.Debug('⚠️ No service info during duty toggle')
    end
end)

-- ====================================================================
-- MARKER SYSTEM (DEINE VOLLSTÄNDIGE DEBUG VERSION)
-- ====================================================================

-- Main loop for marker detection and drawing (KOMPLETT NEUE DEBUG VERSION)
function MainLoop()
    CreateThread(function()
        while true do
            local sleep = 1000

            FL.Debug('🔄 MainLoop iteration starting...')

            -- Step 1: Validate player ped first
            if not IsValidEntity(FL.Client.playerPed) then
                FL.Debug('❌ Invalid player ped, attempting to get new one...')
                FL.Client.playerPed = GetSafePlayerPed()
                Wait(500)
            else
                -- Step 2: Get player coordinates
                local playerCoords = GetEntityCoords(FL.Client.playerPed)
                FL.Debug('🏃 Player coords: ' ..
                    string.format("%.2f, %.2f, %.2f", playerCoords.x, playerCoords.y, playerCoords.z))

                -- NOTFALL-TEST: Zeichne immer einen orangenen Marker über dem Spieler
                FL.Debug('🧪 Drawing test marker above player...')
                DrawMarker(2, playerCoords.x, playerCoords.y, playerCoords.z + 2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 2.0,
                    2.0, 2.0, 255, 128, 0, 50, false, true, 2, nil, nil, false)

                -- Step 3: Check if player has service
                if FL.Client.serviceInfo then
                    FL.Debug('👤 Service: ' ..
                        FL.Client.serviceInfo.service .. ', OnDuty: ' .. tostring(FL.Client.serviceInfo.isOnDuty))

                    -- Step 4: Loop through stations
                    for stationId, stationData in pairs(Config.Stations) do
                        FL.Debug('🏢 Checking station: ' .. stationId .. ', Service: ' .. stationData.service)

                        -- Only show markers for player's service
                        if stationData.service == FL.Client.serviceInfo.service then
                            FL.Debug('✅ Service match for: ' .. stationId)

                            -- Step 5: Calculate distance
                            local distance = FL.Functions.GetDistance(playerCoords, stationData.coords)
                            FL.Debug('📏 Distance to station: ' .. string.format("%.2f", distance))

                            if distance < 50.0 then
                                sleep = 5
                                FL.Debug('📍 Within 50m range of station')

                                -- Step 6: Check duty marker
                                if stationData.duty_marker then
                                    FL.Debug('🎯 Duty marker exists at: ' .. string.format("%.2f, %.2f, %.2f",
                                        stationData.duty_marker.coords.x,
                                        stationData.duty_marker.coords.y,
                                        stationData.duty_marker.coords.z))

                                    local markerDistance = FL.Functions.GetDistance(playerCoords,
                                        stationData.duty_marker.coords)
                                    FL.Debug('📏 Distance to marker: ' .. string.format("%.2f", markerDistance))

                                    if markerDistance < 20.0 then
                                        FL.Debug('🔥 About to draw station marker...')

                                        -- Station Marker (roter Zylinder)
                                        DrawMarker(
                                            1,                                -- type (cylinder)
                                            stationData.duty_marker.coords.x, -- posX
                                            stationData.duty_marker.coords.y, -- posY
                                            stationData.duty_marker.coords.z, -- posZ
                                            0.0, 0.0, 0.0,                    -- dirX, dirY, dirZ
                                            0.0, 0.0, 0.0,                    -- rotX, rotY, rotZ
                                            2.0, 2.0, 1.0,                    -- scaleX, scaleY, scaleZ
                                            255, 0, 0, 200,                   -- red, green, blue, alpha (bright red)
                                            false,                            -- bobUpAndDown
                                            true,                             -- faceCamera
                                            2,                                -- rotationOrder
                                            nil,                              -- rotate
                                            nil,                              -- textureDict
                                            nil,                              -- textureName
                                            false                             -- drawOnEnts
                                        )

                                        FL.Debug('✅ Station marker drawn successfully')

                                        if markerDistance < 2.0 then
                                            -- Show interaction text based on duty status
                                            local text = FL.Client.serviceInfo.isOnDuty and '~r~[E]~w~ End Duty' or
                                                '~g~[E]~w~ Start Duty'
                                            ShowHelpText(text)

                                            -- Handle interaction - now uses QBCore duty system
                                            if IsControlJustPressed(0, 38) then -- E key
                                                FL.Debug('🔑 E key pressed - toggling duty')
                                                TriggerServerEvent('fl_core:toggleDuty', stationId)
                                            end
                                        end
                                    else
                                        FL.Debug('❌ Too far from marker: ' .. string.format("%.2f", markerDistance))
                                    end
                                else
                                    FL.Debug('❌ No duty marker defined for station: ' .. stationId)
                                end
                            else
                                FL.Debug('❌ Too far from station: ' .. string.format("%.2f", distance))
                            end
                        else
                            FL.Debug('❌ Service mismatch: ' ..
                                stationData.service .. ' != ' .. FL.Client.serviceInfo.service)
                        end
                    end
                else
                    FL.Debug('❌ No service info available')
                end
            end

            FL.Debug('🔄 MainLoop iteration finished, sleeping: ' .. sleep .. 'ms')
            Wait(sleep)
        end
    end)
end

-- ====================================================================
-- UNIFORM SYSTEM (NUCLEAR NULL-SAFETY - ALL FIXED)
-- ====================================================================

-- Store original outfit before applying uniform
FL.Client.originalOutfit = nil

-- Apply uniform to player (NULL-SAFE FIXED)
function ApplyUniform(serviceName)
    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for uniform application')
        return false
    end

    local gender = GetEntityModel(playerPed) == GetHashKey('mp_f_freemode_01') and 0 or 1
    local uniform = FL.Functions.GetUniform(serviceName, gender)

    if not uniform then
        FL.Debug('No uniform found for ' .. serviceName)
        return false
    end

    -- Save current outfit before applying uniform
    SaveCurrentOutfit()

    -- Apply each clothing piece (NULL-SAFE: All SetPed functions with validation)
    SetPedComponentVariation(playerPed, 8, SafeInt(uniform.tshirt_1, 15), SafeInt(uniform.tshirt_2, 0), 0)
    SetPedComponentVariation(playerPed, 11, SafeInt(uniform.torso_1, 15), SafeInt(uniform.torso_2, 0), 0)
    SetPedComponentVariation(playerPed, 3, SafeInt(uniform.arms, 15), 0, 0)
    SetPedComponentVariation(playerPed, 4, SafeInt(uniform.pants_1, 14), SafeInt(uniform.pants_2, 0), 0)
    SetPedComponentVariation(playerPed, 6, SafeInt(uniform.shoes_1, 34), SafeInt(uniform.shoes_2, 0), 0)

    -- Props (NULL-SAFE: Props with validation)
    if uniform.helmet_1 and uniform.helmet_1 ~= -1 then
        SetPedPropIndex(playerPed, 0, SafeInt(uniform.helmet_1, 0), SafeInt(uniform.helmet_2, 0), false)
    else
        ClearPedProp(playerPed, 0)
    end

    if uniform.chain_1 and uniform.chain_1 ~= -1 then
        SetPedComponentVariation(playerPed, 7, SafeInt(uniform.chain_1, 0), SafeInt(uniform.chain_2, 0), 0)
    end

    FL.Debug('Applied ' .. serviceName .. ' uniform')
    return true
end

-- Save current outfit (NULL-SAFE FIXED)
function SaveCurrentOutfit()
    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for outfit saving')
        return false
    end

    FL.Client.originalOutfit = {
        -- NULL-SAFE: All GetPed functions with SafeInt wrapper
        tshirt_1 = SafeInt(GetPedDrawableVariation(playerPed, 8), 15),
        tshirt_2 = SafeInt(GetPedTextureVariation(playerPed, 8), 0),
        torso_1 = SafeInt(GetPedDrawableVariation(playerPed, 11), 15),
        torso_2 = SafeInt(GetPedTextureVariation(playerPed, 11), 0),
        arms = SafeInt(GetPedDrawableVariation(playerPed, 3), 15),
        pants_1 = SafeInt(GetPedDrawableVariation(playerPed, 4), 14),
        pants_2 = SafeInt(GetPedTextureVariation(playerPed, 4), 0),
        shoes_1 = SafeInt(GetPedDrawableVariation(playerPed, 6), 34),
        shoes_2 = SafeInt(GetPedTextureVariation(playerPed, 6), 0),
        chain_1 = SafeInt(GetPedDrawableVariation(playerPed, 7), 0),
        chain_2 = SafeInt(GetPedTextureVariation(playerPed, 7), 0),
        -- Props with SafeInt wrapper
        helmet_1 = SafeInt(GetPedPropIndex(playerPed, 0), -1),
        helmet_2 = SafeInt(GetPedPropTextureIndex(playerPed, 0), 0),
    }

    FL.Debug('Saved original outfit')
    return true
end

-- Remove uniform
function RemoveUniform()
    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for uniform removal')
        return false
    end

    -- Try multiple methods to restore clothing
    if FL.Client.originalOutfit then
        RestoreOriginalOutfit()
    else
        ResetToBasicClothing()
    end

    FL.Debug('Removed service uniform')
    return true
end

-- Restore original outfit (NULL-SAFE FIXED)
function RestoreOriginalOutfit()
    if not FL.Client.originalOutfit then
        FL.Debug('No original outfit saved')
        return false
    end

    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for outfit restoration')
        return false
    end

    local outfit = FL.Client.originalOutfit

    -- NULL-SAFE: All outfit values with SafeInt wrapper
    SetPedComponentVariation(playerPed, 8, SafeInt(outfit.tshirt_1, 15), SafeInt(outfit.tshirt_2, 0), 0)
    SetPedComponentVariation(playerPed, 11, SafeInt(outfit.torso_1, 15), SafeInt(outfit.torso_2, 0), 0)
    SetPedComponentVariation(playerPed, 3, SafeInt(outfit.arms, 15), 0, 0)
    SetPedComponentVariation(playerPed, 4, SafeInt(outfit.pants_1, 14), SafeInt(outfit.pants_2, 0), 0)
    SetPedComponentVariation(playerPed, 6, SafeInt(outfit.shoes_1, 34), SafeInt(outfit.shoes_2, 0), 0)
    SetPedComponentVariation(playerPed, 7, SafeInt(outfit.chain_1, 0), SafeInt(outfit.chain_2, 0), 0)

    -- Restore props (NULL-SAFE: Props with validation)
    if outfit.helmet_1 and outfit.helmet_1 ~= -1 then
        SetPedPropIndex(playerPed, 0, SafeInt(outfit.helmet_1, 0), SafeInt(outfit.helmet_2, 0), false)
    else
        ClearPedProp(playerPed, 0)
    end

    FL.Debug('Restored original outfit')
    return true
end

-- Fallback: Reset to basic civilian clothing
function ResetToBasicClothing()
    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for basic clothing reset')
        return false
    end

    local gender = GetEntityModel(playerPed) == GetHashKey('mp_f_freemode_01') and 0 or 1

    if gender == 1 then                                   -- Male
        SetPedComponentVariation(playerPed, 8, 15, 0, 0)  -- Undershirt
        SetPedComponentVariation(playerPed, 11, 15, 0, 0) -- Torso
        SetPedComponentVariation(playerPed, 3, 15, 0, 0)  -- Arms
        SetPedComponentVariation(playerPed, 4, 14, 0, 0)  -- Pants
        SetPedComponentVariation(playerPed, 6, 34, 0, 0)  -- Shoes
        SetPedComponentVariation(playerPed, 7, 0, 0, 0)   -- Chain
    else                                                  -- Female
        SetPedComponentVariation(playerPed, 8, 14, 0, 0)  -- Undershirt
        SetPedComponentVariation(playerPed, 11, 14, 0, 0) -- Torso
        SetPedComponentVariation(playerPed, 3, 14, 0, 0)  -- Arms
        SetPedComponentVariation(playerPed, 4, 14, 0, 0)  -- Pants
        SetPedComponentVariation(playerPed, 6, 35, 0, 0)  -- Shoes
        SetPedComponentVariation(playerPed, 7, 0, 0, 0)   -- Chain
    end

    -- Clear props
    ClearPedProp(playerPed, 0) -- Helmet

    FL.Debug('Reset to basic civilian clothing')
    return true
end

-- ====================================================================
-- EQUIPMENT SYSTEM (unchanged)
-- ====================================================================

-- Give service equipment to player
function GiveServiceEquipment(serviceName)
    local equipment = FL.Functions.GetServiceEquipment(serviceName)

    if #equipment == 0 then
        FL.Debug('No equipment found for ' .. serviceName)
        return
    end

    -- Use server-side item management (QBCore 1.3.0+)
    TriggerServerEvent('fl_core:giveEquipment', serviceName)

    FL.Debug('Requested ' .. serviceName .. ' equipment from server')
end

-- Remove service equipment from player
function RemoveServiceEquipment(serviceName)
    -- Use server-side item management (QBCore 1.3.0+)
    TriggerServerEvent('fl_core:removeEquipment', serviceName)

    FL.Debug('Requested removal of ' .. serviceName .. ' equipment from server')
end

-- Create blips for stations (NULL-SAFE FIXED)
function CreateStationBlips()
    CreateThread(function()
        while true do
            -- Wait for service info
            if FL.Client.serviceInfo then
                for stationId, stationData in pairs(Config.Stations) do
                    -- Only create blip for player's service
                    if stationData.service == FL.Client.serviceInfo.service then
                        local serviceData = FL.Functions.GetServiceData(stationData.service)
                        if serviceData then
                            local blip = AddBlipForCoord(stationData.coords.x, stationData.coords.y, stationData.coords
                                .z)

                            SetBlipSprite(blip, serviceData.blip)
                            SetBlipDisplay(blip, 4)
                            -- NULL-SAFE: Proper float conversion
                            SetBlipScale(blip, 0.8)
                            SetBlipColour(blip, GetBlipColorFromHex(serviceData.color))
                            SetBlipAsShortRange(blip, true)

                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentString(stationData.name)
                            EndTextCommandSetBlipName(blip)

                            FL.Debug('Created blip for ' .. stationData.name)
                        end
                    end
                end
                break
            end
            Wait(1000)
        end
    end)
end

-- Convert hex color to blip color
function GetBlipColorFromHex(hexColor)
    local colorMap = {
        ['#e74c3c'] = 1, -- Red (Fire)
        ['#3498db'] = 3, -- Blue (Police)
        ['#2ecc71'] = 2  -- Green (EMS)
    }
    return colorMap[hexColor] or 0
end

-- Show help text (NULL-SAFE FIXED - Using proper method)
function ShowHelpText(text)
    if text == nil then text = "" end -- Nil-safety
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ====================================================================
-- MDT SYSTEM (ENHANCED FOR MULTI-UNIT)
-- ====================================================================

-- Show MDT/Tablet (ENHANCED with player source)
function ShowMDT()
    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        QBCore.Functions.Notify('You must be on duty to use the MDT', 'error')
        return
    end

    FL.Debug('📱 Opening MDT - Current calls: ' .. FL.Functions.TableSize(FL.Client.activeCalls))

    -- Request fresh active calls from server
    TriggerServerEvent('fl_core:getActiveCalls')

    -- Wait a moment for server response, then show UI
    CreateThread(function()
        Wait(200) -- Give server time to respond

        -- Prepare MDT data with Multi-Unit support
        local mdtData = {
            service = FL.Client.serviceInfo.service,
            rank = FL.Client.serviceInfo.rank,
            rankName = FL.Client.serviceInfo.rankName,
            activeCalls = FL.Client.activeCalls,
            playerSource = FL.Client.playerSource -- Include player source
        }

        FL.Debug('📱 Opening MDT with data - Calls: ' .. FL.Functions.TableSize(mdtData.activeCalls))
        FL.Debug('👤 Player Source for UI: ' .. mdtData.playerSource)

        -- Play tablet animation (NULL-SAFE)
        local playerPed = FL.Client.playerPed
        if IsValidEntity(playerPed) then
            RequestAnimDict(Config.MDT.animation.dict)
            while not HasAnimDictLoaded(Config.MDT.animation.dict) do
                Wait(100)
            end

            TaskPlayAnim(playerPed, Config.MDT.animation.dict, Config.MDT.animation.name, 8.0, 8.0, -1, 50, 0, false,
                false, false)
        end

        -- Open MDT UI with proper focus
        FL.Client.showingUI = true
        SetNuiFocus(true, true)

        -- Send player source first (MULTI-UNIT FEATURE)
        SendNUIMessage({
            type = 'setPlayerSource',
            source = FL.Client.playerSource
        })

        -- Then send MDT data
        SendNUIMessage({
            type = 'showMDT',
            data = mdtData
        })

        FL.Debug('📱 MDT UI opened and data sent with player source')
    end)
end

-- Close MDT properly
function CloseMDT()
    FL.Debug('📱 Closing MDT UI - Starting cleanup')

    -- Force NUI off
    for i = 1, 10 do
        SetNuiFocus(false, false)
        Wait(10)
    end

    -- Reset client state immediately
    FL.Client.showingUI = false

    -- Stop animations (NULL-SAFE)
    local playerPed = GetSafePlayerPed()
    if IsValidEntity(playerPed) then
        ClearPedTasks(playerPed)
        ClearPedTasksImmediately(playerPed)
    end

    -- Send close message to UI
    for i = 1, 3 do
        SendNUIMessage({ type = 'hideUI' })
        Wait(10)
    end

    FL.Debug('📱 MDT closed successfully')
end

-- ====================================================================
-- COMMANDS (ENHANCED)
-- ====================================================================

-- Open MDT command
RegisterCommand('mdt', function(source, args, rawCommand)
    if FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty then
        ShowMDT()
    else
        QBCore.Functions.Notify('You must be on duty to use this command', 'error')
    end
end, false)

-- Emergency close MDT command
RegisterCommand('closemdt', function(source, args, rawCommand)
    CloseMDT()
    QBCore.Functions.Notify('MDT force closed', 'success')
end, false)

-- Emergency chat fix command
RegisterCommand('fixchat', function(source, args, rawCommand)
    FL.Debug('🚨 EMERGENCY CHAT FIX ACTIVATED')

    -- Nuclear NUI reset
    for i = 1, 50 do
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        Wait(10)
    end

    -- Reset client state
    FL.Client.showingUI = false

    -- Clear any animations (NULL-SAFE)
    local playerPed = GetSafePlayerPed()
    if IsValidEntity(playerPed) then
        ClearPedTasks(playerPed)
        ClearPedTasksImmediately(playerPed)
    end

    -- Send emergency close to UI
    for i = 1, 10 do
        SendNUIMessage({ type = 'hideUI' })
        Wait(10)
    end

    FL.Debug('🚨 EMERGENCY CHAT FIX COMPLETED')
    QBCore.Functions.Notify('Chat should be fixed now - try T or Y', 'success')
end, false)

-- Enhanced debug command for checking calls with Multi-Unit info
RegisterCommand('debugcalls', function(source, args, rawCommand)
    if FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty then
        local count = FL.Functions.TableSize(FL.Client.activeCalls)
        QBCore.Functions.Notify('Active calls: ' .. count .. ' - Check F8 console for details', 'info')

        -- Print detailed call information to console
        print('^3[FL CLIENT DEBUG]^7 ======================')
        print('^3[FL CLIENT DEBUG]^7 Player Source: ' .. FL.Client.playerSource)
        print('^3[FL CLIENT DEBUG]^7 Service: ' .. FL.Client.serviceInfo.service)
        print('^3[FL CLIENT DEBUG]^7 On Duty: ' .. tostring(FL.Client.serviceInfo.isOnDuty))
        print('^3[FL CLIENT DEBUG]^7 Active Calls: ' .. count)
        for callId, callData in pairs(FL.Client.activeCalls) do
            local unitCount = #(callData.unit_details or {})
            print('^3[FL CLIENT CALL]^7 ID: ' .. callId)
            print('^3[FL CLIENT CALL]^7 Status: ' .. callData.status)
            print('^3[FL CLIENT CALL]^7 Type: ' .. callData.type)
            print('^3[FL CLIENT CALL]^7 Priority: ' .. callData.priority)
            print('^3[FL CLIENT CALL]^7 Service: ' .. callData.service)
            print('^3[FL CLIENT CALL]^7 Assigned Units: ' .. json.encode(callData.assigned_units or {}))
            print('^3[FL CLIENT CALL]^7 Unit Details Count: ' .. unitCount)
            if unitCount > 0 then
                for i, unit in pairs(callData.unit_details) do
                    print('^3[FL CLIENT UNIT]^7   Unit ' .. i .. ': ' .. unit.callsign .. ' (' .. unit.name .. ')')
                end
            end
            print('^3[FL CLIENT CALL]^7 ---')
        end
        print('^3[FL CLIENT DEBUG]^7 ======================')

        -- Request fresh data from server
        TriggerServerEvent('fl_core:getActiveCalls')
    else
        QBCore.Functions.Notify('You must be on duty to check calls', 'error')
    end
end, false)

-- ESC key handler for closing MDT
CreateThread(function()
    while true do
        Wait(0)
        if FL.Client.showingUI then
            -- ESC key
            if IsControlJustPressed(0, 322) then -- ESC
                FL.Debug('ESC key pressed - closing MDT')
                CloseMDT()
            end

            -- Emergency keys
            if IsControlJustPressed(0, 194) then -- BACKSPACE
                FL.Debug('BACKSPACE pressed - emergency close')
                CloseMDT()
            end
        else
            Wait(500) -- Sleep when UI is not showing
        end
    end
end)

FL.Debug('🎉 FL Core client loaded with Multi-Unit Assignment Support + VOLLSTÄNDIGE DEBUG VERSION')
