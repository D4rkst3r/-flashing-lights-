-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - CLIENT MAIN (KORRIGIERTE VERSION)
-- ALLE KRITISCHEN FIXES IMPLEMENTIERT:
-- ✅ Performance-optimiertes Key Handling
-- ✅ Robuste Entity Validation
-- ✅ UI Update Throttling
-- ✅ Memory Management & Cleanup
-- ✅ Enhanced Error Handling
-- ====================================================================

local QBCore = FL.GetFramework()

-- Client state variables (enhanced with error recovery)
FL.Client = {
    serviceInfo = nil,
    activeCalls = {},
    nearbyMarkers = {},
    showingUI = false,
    playerPed = 0,
    playerSource = GetPlayerServerId(PlayerId()),
    lastUIUpdate = 0,
    uiUpdateThrottle = 100 -- Minimum 100ms between UI updates
}

-- Job to service mapping (same as server)
FL.JobMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ambulance'] = 'ems'
}

-- ====================================================================
-- ENHANCED HELPER FUNCTIONS (ROBUSTE VERSION)
-- ====================================================================

-- Safe PlayerPedId getter with enhanced validation
local function GetSafePlayerPed()
    local ped = PlayerPedId()
    if ped and ped > 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
        return ped
    end
    return 0 -- Return 0 instead of nil for integer compatibility
end

-- Safe integer conversion with better validation
local function SafeInt(value, default)
    if type(value) == "number" and value >= 0 and value < 2147483647 then
        return math.floor(value)
    end
    return default or 0
end

-- Safe entity check with death validation
local function IsValidEntity(entity)
    return entity and entity > 0 and DoesEntityExist(entity) and not IsEntityDead(entity)
end

-- Validate player state for emergency service operations
local function IsPlayerStateValid()
    local ped = GetSafePlayerPed()
    if ped == 0 then
        return false, "Invalid player entity"
    end

    if IsEntityDead(ped) then
        return false, "Player is dead"
    end

    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if not IsValidEntity(vehicle) then
            return false, "Invalid vehicle state"
        end
    end

    return true, "Player state valid"
end

-- Throttled UI update system
local function UpdateMDTSafely(data, eventType)
    local now = GetGameTimer()

    if now - FL.Client.lastUIUpdate < FL.Client.uiUpdateThrottle then
        -- Throttle: Schedule update for later
        CreateThread(function()
            Wait(FL.Client.uiUpdateThrottle)
            FL.Client.lastUIUpdate = GetGameTimer()

            if FL.Client.showingUI then
                SendNUIMessage({
                    type = eventType or 'updateCalls',
                    data = data
                })
                FL.Debug('📱 Throttled UI update sent: ' .. (eventType or 'updateCalls'))
            end
        end)
        return
    end

    -- Immediate update
    FL.Client.lastUIUpdate = now
    if FL.Client.showingUI then
        SendNUIMessage({
            type = eventType or 'updateCalls',
            data = data
        })
        FL.Debug('📱 Immediate UI update sent: ' .. (eventType or 'updateCalls'))
    end
end

-- ====================================================================
-- INITIALIZATION (ENHANCED WITH ERROR RECOVERY)
-- ====================================================================

CreateThread(function()
    local initAttempts = 0
    local maxAttempts = 10

    while QBCore == nil and initAttempts < maxAttempts do
        QBCore = FL.GetFramework()
        initAttempts = initAttempts + 1
        FL.Debug('⏳ Waiting for QBCore... Attempt ' .. initAttempts)
        Wait(1000)
    end

    if QBCore == nil then
        FL.Debug('❌ CRITICAL: Failed to initialize QBCore after ' .. maxAttempts .. ' attempts!')
        return
    end

    FL.Client.playerPed = GetSafePlayerPed()
    FL.Client.playerSource = GetPlayerServerId(PlayerId())

    local pedWaitAttempts = 0
    while FL.Client.playerPed == 0 and pedWaitAttempts < 20 do
        Wait(500)
        FL.Client.playerPed = GetSafePlayerPed()
        pedWaitAttempts = pedWaitAttempts + 1
        FL.Debug('⏳ Waiting for valid player ped... Attempt ' .. pedWaitAttempts)
    end

    if FL.Client.playerPed == 0 then
        FL.Debug('⚠️ Warning: Could not get valid player ped after 20 attempts')
    end

    TriggerServerEvent('fl_core:getServiceInfo')
    CreateStationBlips()

    FL.Debug('✅ Client script initialized with QBCore integration + enhanced error handling')
end)

-- Update player ped regularly with error handling
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds

        local newPed = GetSafePlayerPed()
        if newPed ~= FL.Client.playerPed and newPed > 0 then
            FL.Client.playerPed = newPed
            FL.Debug('👤 Player ped updated: ' .. newPed)
        end
    end
end)

-- ====================================================================
-- NUI CALLBACKS (ENHANCED WITH VALIDATION)
-- ====================================================================

-- NUI: Assign to call (enhanced with validation)
RegisterNUICallback('assignToCall', function(data, cb)
    FL.Debug('📱 NUI Callback: assignToCall - Data: ' .. json.encode(data))

    -- Validate input
    if not data or not data.callId or data.callId == '' then
        FL.Debug('❌ Invalid callId provided in NUI callback')
        cb({ success = false, message = 'Invalid call ID provided' })
        return
    end

    local callId = data.callId

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

    -- Validate player state
    local isValid, errorMsg = IsPlayerStateValid()
    if not isValid then
        FL.Debug('❌ Invalid player state: ' .. errorMsg)
        cb({ success = false, message = 'Invalid player state: ' .. errorMsg })
        return
    end

    FL.Debug('✅ Validation passed, sending server event for assignment')

    -- Send server event
    TriggerServerEvent('fl_core:assignToCallFromUI', callId)

    -- Respond to NUI
    cb({
        success = true,
        message = 'Assignment request sent to server',
        callId = callId
    })
end)

-- NUI: Start work on call (enhanced)
RegisterNUICallback('startWorkOnCall', function(data, cb)
    FL.Debug('📱 NUI Callback: startWorkOnCall - Data: ' .. json.encode(data))

    -- Validate input
    if not data or not data.callId or data.callId == '' then
        FL.Debug('❌ Invalid callId provided in NUI callback')
        cb({ success = false, message = 'Invalid call ID provided' })
        return
    end

    local callId = data.callId

    -- Validate service and duty status
    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        FL.Debug('❌ Player not on duty or no service info')
        cb({ success = false, message = 'You must be on duty' })
        return
    end

    -- Validate player state
    local isValid, errorMsg = IsPlayerStateValid()
    if not isValid then
        FL.Debug('❌ Invalid player state: ' .. errorMsg)
        cb({ success = false, message = 'Invalid player state: ' .. errorMsg })
        return
    end

    FL.Debug('✅ Validation passed, sending server event for start work')

    -- Send server event
    TriggerServerEvent('fl_core:startWorkOnCallFromUI', callId)

    -- Respond to NUI
    cb({
        success = true,
        message = 'Start work request sent to server',
        callId = callId
    })
end)

-- NUI: Complete call (enhanced)
RegisterNUICallback('completeCall', function(data, cb)
    FL.Debug('📱 NUI Callback: completeCall - Data: ' .. json.encode(data))

    -- Validate input
    if not data or not data.callId or data.callId == '' then
        FL.Debug('❌ Invalid callId provided in NUI callback')
        cb({ success = false, message = 'Invalid call ID provided' })
        return
    end

    local callId = data.callId

    -- Validate service and duty status
    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        FL.Debug('❌ Player not on duty or no service info')
        cb({ success = false, message = 'You must be on duty' })
        return
    end

    -- Validate player state
    local isValid, errorMsg = IsPlayerStateValid()
    if not isValid then
        FL.Debug('❌ Invalid player state: ' .. errorMsg)
        cb({ success = false, message = 'Invalid player state: ' .. errorMsg })
        return
    end

    FL.Debug('✅ Validation passed, sending server event for completion')

    -- Send server event
    TriggerServerEvent('fl_core:completeCallFromUI', callId)

    -- Respond to NUI
    cb({
        success = true,
        message = 'Completion request sent to server',
        callId = callId
    })
end)

-- NUI: Close UI (enhanced)
RegisterNUICallback('closeUI', function(data, cb)
    FL.Debug('📱 NUI Callback: closeUI')
    CloseMDT()
    cb('ok')
end)

-- ====================================================================
-- SERVER EVENT HANDLERS (ENHANCED WITH THROTTLING)
-- ====================================================================

-- Handle assignment result from server
RegisterNetEvent('fl_core:assignmentResult', function(result)
    FL.Debug('📱 Assignment result received: ' .. json.encode(result))

    if result and result.success then
        QBCore.Functions.Notify('Successfully assigned to call ' .. (result.callId or 'unknown'), 'success')
    else
        QBCore.Functions.Notify('Assignment failed: ' .. (result.message or 'unknown error'), 'error')
    end
end)

-- Handle start work result from server
RegisterNetEvent('fl_core:startWorkResult', function(result)
    FL.Debug('📱 Start work result received: ' .. json.encode(result))

    if result and result.success then
        QBCore.Functions.Notify('Started working on call ' .. (result.callId or 'unknown'), 'success')
    else
        QBCore.Functions.Notify('Start work failed: ' .. (result.message or 'unknown error'), 'error')
    end
end)

-- Handle completion result from server
RegisterNetEvent('fl_core:completionResult', function(result)
    FL.Debug('📱 Completion result received: ' .. json.encode(result))

    if result and result.success then
        QBCore.Functions.Notify('Successfully completed call ' .. (result.callId or 'unknown'), 'success')
    else
        QBCore.Functions.Notify('Completion failed: ' .. (result.message or 'unknown error'), 'error')
    end
end)

-- ====================================================================
-- EVENT HANDLERS (ENHANCED WITH THROTTLED UPDATES)
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

-- NEW EMERGENCY CALL (enhanced with throttled UI updates)
RegisterNetEvent('fl_core:newEmergencyCall', function(callData)
    if not callData or not callData.id then
        FL.Debug('❌ Invalid call data received')
        return
    end

    FL.Debug('🆕 NEW CALL RECEIVED: ' ..
        callData.id .. ' for service: ' .. callData.service .. ' - Status: ' .. callData.status)

    -- Store call in local storage
    FL.Client.activeCalls[callData.id] = callData

    -- Show notification with enhanced info
    local priorityText = FL.Functions.FormatPriority(callData.priority)
    local maxUnits = callData.max_units or 4
    QBCore.Functions.Notify('New ' .. priorityText .. ' call: ' .. callData.type .. ' (Max Units: ' .. maxUnits .. ')',
        'error')

    -- Play alert sound
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)

    -- Throttled UI update
    UpdateMDTSafely(FL.Client.activeCalls, 'updateCalls')
    UpdateMDTSafely(callData, 'newCall')
end)

-- CALL ASSIGNED (enhanced with throttled updates)
RegisterNetEvent('fl_core:callAssigned', function(callData)
    if not callData or not callData.id then
        FL.Debug('❌ Invalid call data received in callAssigned')
        return
    end

    FL.Debug('📞 CALL ASSIGNED EVENT: ' .. callData.id .. ' - New Status: ' .. callData.status)
    FL.Debug('👥 Assigned Units Count: ' .. #(callData.assigned_units or {}))
    FL.Debug('🏷️ Unit Details Count: ' .. #(callData.unit_details or {}))

    -- Update local storage
    FL.Client.activeCalls[callData.id] = callData

    -- Show waypoint
    if callData.coords and callData.coords.x then
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

    -- Throttled UI updates
    UpdateMDTSafely(FL.Client.activeCalls, 'updateCalls')
    UpdateMDTSafely(callData, 'callAssigned')
end)

-- CALL STATUS UPDATE (enhanced)
RegisterNetEvent('fl_core:callStatusUpdate', function(callId, callData)
    if not callId or not callData then
        FL.Debug('❌ Invalid parameters in callStatusUpdate')
        return
    end

    FL.Debug('📋 CALL STATUS UPDATE EVENT: ' .. callId .. ' - New Status: ' .. callData.status)
    FL.Debug('👥 Updated Units Count: ' .. #(callData.assigned_units or {}))

    -- Update local storage
    FL.Client.activeCalls[callId] = callData

    FL.Debug('💾 Updated local call: ' .. callId .. ' to status: ' .. callData.status)

    -- Throttled UI update
    UpdateMDTSafely(FL.Client.activeCalls, 'updateCalls')
end)

-- CALL COMPLETED (enhanced)
RegisterNetEvent('fl_core:callCompleted', function(callId)
    if not callId then
        FL.Debug('❌ Invalid callId in callCompleted')
        return
    end

    FL.Debug('✅ CALL COMPLETED EVENT: ' .. callId)

    -- Remove from local storage
    FL.Client.activeCalls[callId] = nil

    QBCore.Functions.Notify('Call ' .. callId .. ' completed', 'success')

    -- Throttled UI update
    UpdateMDTSafely(FL.Client.activeCalls, 'updateCalls')
end)

-- ACTIVE CALLS (enhanced with validation)
RegisterNetEvent('fl_core:activeCalls', function(calls)
    if not calls or type(calls) ~= 'table' then
        FL.Debug('❌ Invalid calls data received')
        calls = {}
    end

    FL.Debug('📋 RECEIVED ACTIVE CALLS FROM SERVER: ' .. FL.Functions.TableSize(calls) .. ' calls')

    -- Validate and store calls
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

    -- Send player source and update UI
    if FL.Client.showingUI then
        FL.Debug('📱 SENDING VALIDATED CALLS TO UI: ' .. FL.Functions.TableSize(validCalls) .. ' calls')

        SendNUIMessage({
            type = 'setPlayerSource',
            source = FL.Client.playerSource
        })

        UpdateMDTSafely(FL.Client.activeCalls, 'updateCalls')
    else
        FL.Debug('📱 MDT not open - calls stored but not sent to UI')
    end
end)

-- ====================================================================
-- JOB INTEGRATION (ENHANCED)
-- ====================================================================

-- Handle QBCore job updates
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not job or not job.name then
        FL.Debug('❌ Invalid job data received')
        return
    end

    FL.Debug('Job updated: ' ..
        job.name ..
        ' (Grade: ' .. (job.grade and job.grade.level or 'unknown') .. ', Duty: ' .. tostring(job.onduty) .. ')')

    -- Check if it's an emergency service job
    local service = FL.JobMapping[job.name]
    if service then
        FL.Debug('✅ Emergency service job detected: ' .. service)

        -- Update service info
        FL.Client.serviceInfo = {
            service = service,
            rank = job.grade and job.grade.level or 0,
            rankName = job.grade and job.grade.name or 'Unknown',
            isOnDuty = job.onduty or false,
            qbJob = job.name
        }

        FL.Debug('👤 Updated service info: ' .. json.encode(FL.Client.serviceInfo))

        -- Handle uniform and equipment
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
-- UNIFORM SYSTEM (ENHANCED WITH ERROR HANDLING)
-- ====================================================================

-- Store original outfit before applying uniform
FL.Client.originalOutfit = nil

-- Apply uniform to player (enhanced validation)
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
        FL.Debug('❌ No uniform found for ' .. serviceName)
        return false
    end

    -- Save current outfit before applying uniform
    if not SaveCurrentOutfit() then
        FL.Debug('⚠️ Failed to save current outfit')
    end

    -- Apply each clothing piece with enhanced error handling
    local success = true
    local function SafeSetComponent(component, drawable, texture)
        local safeDrawable = SafeInt(drawable, 15)
        local safeTexture = SafeInt(texture, 0)

        if safeDrawable >= 0 and safeTexture >= 0 then
            SetPedComponentVariation(playerPed, component, safeDrawable, safeTexture, 0)
        else
            FL.Debug('⚠️ Invalid component values: ' .. component .. ', ' .. drawable .. ', ' .. texture)
            success = false
        end
    end

    SafeSetComponent(8, uniform.tshirt_1, uniform.tshirt_2)
    SafeSetComponent(11, uniform.torso_1, uniform.torso_2)
    SafeSetComponent(3, uniform.arms, 0)
    SafeSetComponent(4, uniform.pants_1, uniform.pants_2)
    SafeSetComponent(6, uniform.shoes_1, uniform.shoes_2)

    -- Props with validation
    if uniform.helmet_1 and uniform.helmet_1 ~= -1 then
        local safeHelmet = SafeInt(uniform.helmet_1, 0)
        local safeHelmetTexture = SafeInt(uniform.helmet_2, 0)
        if safeHelmet >= 0 and safeHelmetTexture >= 0 then
            SetPedPropIndex(playerPed, 0, safeHelmet, safeHelmetTexture, false)
        end
    else
        ClearPedProp(playerPed, 0)
    end

    if uniform.chain_1 and uniform.chain_1 ~= -1 then
        SafeSetComponent(7, uniform.chain_1, uniform.chain_2)
    end

    if success then
        FL.Debug('✅ Applied ' .. serviceName .. ' uniform successfully')
    else
        FL.Debug('⚠️ Applied ' .. serviceName .. ' uniform with some errors')
    end

    return success
end

-- Save current outfit (enhanced validation)
function SaveCurrentOutfit()
    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for outfit saving')
        return false
    end

    FL.Client.originalOutfit = {
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
        helmet_1 = SafeInt(GetPedPropIndex(playerPed, 0), -1),
        helmet_2 = SafeInt(GetPedPropTextureIndex(playerPed, 0), 0),
    }

    FL.Debug('✅ Saved original outfit')
    return true
end

-- Remove uniform (enhanced)
function RemoveUniform()
    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for uniform removal')
        return false
    end

    -- Try multiple methods to restore clothing
    if FL.Client.originalOutfit then
        if RestoreOriginalOutfit() then
            FL.Debug('✅ Restored original outfit')
        else
            FL.Debug('⚠️ Failed to restore original outfit, using fallback')
            ResetToBasicClothing()
        end
    else
        FL.Debug('⚠️ No original outfit saved, using basic clothing')
        ResetToBasicClothing()
    end

    FL.Debug('✅ Removed service uniform')
    return true
end

-- Restore original outfit (enhanced validation)
function RestoreOriginalOutfit()
    if not FL.Client.originalOutfit then
        FL.Debug('❌ No original outfit saved')
        return false
    end

    local playerPed = FL.Client.playerPed

    -- Validate player ped
    if not IsValidEntity(playerPed) then
        FL.Debug('❌ Invalid player ped for outfit restoration')
        return false
    end

    local outfit = FL.Client.originalOutfit

    -- Restore with validation
    local function SafeRestoreComponent(component, drawable, texture)
        local safeDrawable = SafeInt(drawable, 15)
        local safeTexture = SafeInt(texture, 0)
        SetPedComponentVariation(playerPed, component, safeDrawable, safeTexture, 0)
    end

    SafeRestoreComponent(8, outfit.tshirt_1, outfit.tshirt_2)
    SafeRestoreComponent(11, outfit.torso_1, outfit.torso_2)
    SafeRestoreComponent(3, outfit.arms, 0)
    SafeRestoreComponent(4, outfit.pants_1, outfit.pants_2)
    SafeRestoreComponent(6, outfit.shoes_1, outfit.shoes_2)
    SafeRestoreComponent(7, outfit.chain_1, outfit.chain_2)

    -- Restore props
    if outfit.helmet_1 and outfit.helmet_1 ~= -1 then
        local safeHelmet = SafeInt(outfit.helmet_1, 0)
        local safeHelmetTexture = SafeInt(outfit.helmet_2, 0)
        SetPedPropIndex(playerPed, 0, safeHelmet, safeHelmetTexture, false)
    else
        ClearPedProp(playerPed, 0)
    end

    FL.Debug('✅ Restored original outfit successfully')
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

    FL.Debug('✅ Reset to basic civilian clothing')
    return true
end

-- ====================================================================
-- EQUIPMENT SYSTEM (ENHANCED)
-- ====================================================================

-- Give service equipment to player
function GiveServiceEquipment(serviceName)
    local equipment = FL.Functions.GetServiceEquipment(serviceName)

    if not equipment or #equipment == 0 then
        FL.Debug('❌ No equipment found for ' .. serviceName)
        return
    end

    -- Use server-side item management
    TriggerServerEvent('fl_core:giveEquipment', serviceName)

    FL.Debug('✅ Requested ' .. serviceName .. ' equipment from server')
end

-- Remove service equipment from player
function RemoveServiceEquipment(serviceName)
    -- Use server-side item management
    TriggerServerEvent('fl_core:removeEquipment', serviceName)

    FL.Debug('✅ Requested removal of ' .. serviceName .. ' equipment from server')
end

-- ====================================================================
-- BLIP MANAGEMENT (ENHANCED)
-- ====================================================================

-- Create blips for stations (enhanced validation)
function CreateStationBlips()
    CreateThread(function()
        local attempts = 0
        local maxAttempts = 30 -- 30 seconds max wait

        while not FL.Client.serviceInfo and attempts < maxAttempts do
            Wait(1000)
            attempts = attempts + 1
        end

        if not FL.Client.serviceInfo then
            FL.Debug('⚠️ No service info available for blip creation after 30 seconds')
            return
        end

        for stationId, stationData in pairs(Config.Stations) do
            -- Only create blip for player's service
            if stationData.service == FL.Client.serviceInfo.service then
                local serviceData = FL.Functions.GetServiceData(stationData.service)
                if serviceData and stationData.coords then
                    local success, blip = pcall(function()
                        local blip = AddBlipForCoord(stationData.coords.x, stationData.coords.y, stationData.coords.z)
                        SetBlipSprite(blip, serviceData.blip or 1)
                        SetBlipDisplay(blip, 4)
                        SetBlipScale(blip, 0.8)
                        SetBlipColour(blip, GetBlipColorFromHex(serviceData.color))
                        SetBlipAsShortRange(blip, true)
                        BeginTextCommandSetBlipName('STRING')
                        AddTextComponentString(stationData.name or 'Emergency Station')
                        EndTextCommandSetBlipName(blip)
                        return blip
                    end)

                    if success and blip then
                        FL.Debug('✅ Created blip for ' .. stationData.name)
                    else
                        FL.Debug('❌ Failed to create blip for ' .. stationData.name)
                    end
                end
            end
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

-- ====================================================================
-- MDT SYSTEM (ENHANCED)
-- ====================================================================

-- Show MDT/Tablet (enhanced error handling)
function ShowMDT()
    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        QBCore.Functions.Notify('You must be on duty to use the MDT', 'error')
        return
    end

    -- Validate player state
    local isValid, errorMsg = IsPlayerStateValid()
    if not isValid then
        QBCore.Functions.Notify('Cannot open MDT: ' .. errorMsg, 'error')
        return
    end

    FL.Debug('📱 Opening MDT - Current calls: ' .. FL.Functions.TableSize(FL.Client.activeCalls))

    -- Request fresh active calls from server
    TriggerServerEvent('fl_core:getActiveCalls')

    -- Wait a moment for server response, then show UI
    CreateThread(function()
        Wait(200) -- Give server time to respond

        -- Prepare MDT data
        local mdtData = {
            service = FL.Client.serviceInfo.service,
            rank = FL.Client.serviceInfo.rank,
            rankName = FL.Client.serviceInfo.rankName,
            activeCalls = FL.Client.activeCalls,
            playerSource = FL.Client.playerSource
        }

        FL.Debug('📱 Opening MDT with data - Calls: ' .. FL.Functions.TableSize(mdtData.activeCalls))
        FL.Debug('👤 Player Source for UI: ' .. mdtData.playerSource)

        -- Play tablet animation
        local playerPed = FL.Client.playerPed
        if IsValidEntity(playerPed) and Config.MDT and Config.MDT.animation then
            local animDict = Config.MDT.animation.dict
            local animName = Config.MDT.animation.name

            if animDict and animName then
                RequestAnimDict(animDict)
                local attempts = 0
                while not HasAnimDictLoaded(animDict) and attempts < 10 do
                    Wait(100)
                    attempts = attempts + 1
                end

                if HasAnimDictLoaded(animDict) then
                    TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, -1, 50, 0, false, false, false)
                else
                    FL.Debug('⚠️ Failed to load animation dictionary: ' .. animDict)
                end
            end
        end

        -- Open MDT UI
        FL.Client.showingUI = true
        SetNuiFocus(true, true)

        -- Start key handling
        StartUIKeyHandling()

        -- Send player source first
        SendNUIMessage({
            type = 'setPlayerSource',
            source = FL.Client.playerSource
        })

        -- Then send MDT data
        SendNUIMessage({
            type = 'showMDT',
            data = mdtData
        })

        FL.Debug('📱 MDT UI opened and data sent')
    end)
end

-- Close MDT properly (enhanced)
function CloseMDT()
    FL.Debug('📱 Closing MDT UI - Starting cleanup')

    -- Stop key handling first
    StopUIKeyHandling()

    -- Force NUI off with multiple attempts
    for i = 1, 10 do
        SetNuiFocus(false, false)
        Wait(10)
    end

    -- Reset client state immediately
    FL.Client.showingUI = false

    -- Stop animations
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

-- Emergency chat fix command (enhanced)
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

    -- Clear any animations
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

-- ====================================================================
-- OPTIMIZED KEYBOARD HANDLING (NO CONTINUOUS THREADS)
-- ====================================================================

-- Register ESC key for closing MDT
RegisterKeyMapping('closefl', 'Close FL Emergency Services UI', 'keyboard', 'ESCAPE')

-- Handle ESC key press
RegisterCommand('closefl', function()
    if FL.Client.showingUI then
        FL.Debug('🔑 ESC key pressed via RegisterKeyMapping - closing UI')
        CloseMDT()
    end
end, false)

-- Emergency close with BACKSPACE
RegisterKeyMapping('emergencyclose', 'Emergency Close FL UI', 'keyboard', 'BACK')

RegisterCommand('emergencyclose', function()
    if FL.Client.showingUI then
        FL.Debug('🚨 Emergency close via BACKSPACE')
        CloseMDT()
    end
end, false)

-- Alternative: Direct key detection only when UI is active
local uiKeyHandler = nil

function StartUIKeyHandling()
    if uiKeyHandler then return end

    uiKeyHandler = CreateThread(function()
        while FL.Client.showingUI do
            Wait(0)

            -- Only check when UI is actually showing
            if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 194) then
                FL.Debug('🔑 Direct key detection - closing UI')
                CloseMDT()
                break
            end
        end
        uiKeyHandler = nil
    end)
end

function StopUIKeyHandling()
    if uiKeyHandler then
        FL.Client.showingUI = false -- This will stop the thread
        uiKeyHandler = nil
    end
end

-- Enhanced debug command
RegisterCommand('debugcalls', function(source, args, rawCommand)
    if FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty then
        local count = FL.Functions.TableSize(FL.Client.activeCalls)
        QBCore.Functions.Notify('Active calls: ' .. count .. ' - Check F8 console for details', 'info')

        -- Print detailed information
        print('^3[FL CLIENT DEBUG]^7 ======================')
        print('^3[FL CLIENT DEBUG]^7 Player Source: ' .. FL.Client.playerSource)
        print('^3[FL CLIENT DEBUG]^7 Service: ' .. (FL.Client.serviceInfo.service or 'none'))
        print('^3[FL CLIENT DEBUG]^7 On Duty: ' .. tostring(FL.Client.serviceInfo.isOnDuty))
        print('^3[FL CLIENT DEBUG]^7 Active Calls: ' .. count)
        print('^3[FL CLIENT DEBUG]^7 UI Showing: ' .. tostring(FL.Client.showingUI))

        for callId, callData in pairs(FL.Client.activeCalls) do
            local unitCount = #(callData.unit_details or {})
            print('^3[FL CLIENT CALL]^7 ID: ' .. callId)
            print('^3[FL CLIENT CALL]^7 Status: ' .. callData.status)
            print('^3[FL CLIENT CALL]^7 Type: ' .. callData.type)
            print('^3[FL CLIENT CALL]^7 Priority: ' .. callData.priority)
            print('^3[FL CLIENT CALL]^7 Service: ' .. callData.service)
            print('^3[FL CLIENT CALL]^7 Unit Details Count: ' .. unitCount)
            print('^3[FL CLIENT CALL]^7 ---')
        end
        print('^3[FL CLIENT DEBUG]^7 ======================')

        -- Request fresh data from server
        TriggerServerEvent('fl_core:getActiveCalls')
    else
        QBCore.Functions.Notify('You must be on duty to check calls', 'error')
    end
end, false)



-- ====================================================================
-- RESOURCE CLEANUP (CRITICAL)
-- ====================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        FL.Debug('🧹 Cleaning up FL Core client resources...')

        -- Close any open UIs
        if FL.Client.showingUI then
            CloseMDT()
        end

        -- Clear all blips
        local blips = GetBlipList()
        for i = 1, #blips do
            local blip = blips[i]
            if DoesBlipExist(blip) then
                -- Check if it's one of our station blips
                local blipLabel = GetBlipInfoIdLabel(blip)
                if blipLabel and (string.find(blipLabel, 'Station') or string.find(blipLabel, 'Emergency')) then
                    RemoveBlip(blip)
                end
            end
        end

        -- Reset client state
        FL.Client = {
            serviceInfo = nil,
            activeCalls = {},
            nearbyMarkers = {},
            showingUI = false,
            playerPed = 0,
            playerSource = GetPlayerServerId(PlayerId()),
            lastUIUpdate = 0,
            uiUpdateThrottle = 100
        }

        FL.Debug('✅ FL Core client cleanup completed')
    end
end)

FL.Debug('🎉 FL Core client loaded with COMPLETE PERFORMANCE & ROBUSTNESS FIXES')
