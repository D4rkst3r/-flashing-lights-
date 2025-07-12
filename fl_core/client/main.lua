-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - CLIENT REFACTORED FOR QBCORE
-- Diese Version nutzt das native QBCore Job-System
-- ====================================================================

local QBCore = FL.GetFramework()

-- Client state variables (simplified)
FL.Client = {
    serviceInfo = nil,  -- Current service info from server
    activeCalls = {},   -- Active emergency calls
    nearbyMarkers = {}, -- Nearby station markers
    showingUI = false,  -- UI state
    playerPed = nil
}

-- Job to service mapping (same as server)
FL.JobMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ambulance'] = 'ems'
}

-- ====================================================================
-- INITIALIZATION
-- ====================================================================

CreateThread(function()
    while QBCore == nil do
        QBCore = FL.GetFramework()
        Wait(200)
    end

    -- Initialize player data
    FL.Client.playerPed = PlayerPedId()

    -- Request service info from server
    TriggerServerEvent('fl_core:getServiceInfo')

    -- Create station blips
    CreateStationBlips()

    -- Start main loop
    MainLoop()

    FL.Debug('Client script initialized with QBCore integration')
end)

-- ====================================================================
-- JOB INTEGRATION
-- ====================================================================

-- Handle QBCore job updates
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    FL.Debug('Job updated: ' .. job.name .. ' (Grade: ' .. job.grade.level .. ', Duty: ' .. tostring(job.onduty) .. ')')

    -- Check if it's an emergency service job
    local service = FL.JobMapping[job.name]
    if service then
        -- Update service info
        FL.Client.serviceInfo = {
            service = service,
            rank = job.grade.level,
            rankName = job.grade.name,
            isOnDuty = job.onduty,
            qbJob = job.name
        }

        -- Handle uniform and equipment
        if job.onduty then
            ApplyUniform(service)
            GiveServiceEquipment(service)
        else
            RemoveUniform()
            if FL.Client.serviceInfo and FL.Client.serviceInfo.service then
                RemoveServiceEquipment(FL.Client.serviceInfo.service)
            end
        end

        -- Update active calls
        if job.onduty then
            TriggerServerEvent('fl_core:getActiveCalls')
        else
            FL.Client.activeCalls = {}
        end
    else
        -- Not an emergency service job
        FL.Client.serviceInfo = nil
        FL.Client.activeCalls = {}
    end
end)

-- Handle duty status updates
RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if FL.Client.serviceInfo then
        FL.Client.serviceInfo.isOnDuty = duty

        if duty then
            ApplyUniform(FL.Client.serviceInfo.service)
            GiveServiceEquipment(FL.Client.serviceInfo.service)
            TriggerServerEvent('fl_core:getActiveCalls')
        else
            RemoveUniform()
            RemoveServiceEquipment(FL.Client.serviceInfo.service)
            FL.Client.activeCalls = {}
        end
    end
end)

-- ====================================================================
-- MARKER SYSTEM (Simplified)
-- ====================================================================

-- Main loop for marker detection and drawing
function MainLoop()
    CreateThread(function()
        while true do
            local playerCoords = GetEntityCoords(FL.Client.playerPed)
            local sleep = 1000

            -- Only show markers if player has emergency service job
            if FL.Client.serviceInfo then
                -- Check for nearby stations
                for stationId, stationData in pairs(Config.Stations) do
                    -- Only show markers for player's service
                    if stationData.service == FL.Client.serviceInfo.service then
                        local distance = FL.Functions.GetDistance(playerCoords, stationData.coords)

                        if distance < 50.0 then
                            sleep = 5

                            -- Draw duty marker
                            if stationData.duty_marker then
                                local markerDistance = FL.Functions.GetDistance(playerCoords,
                                    stationData.duty_marker.coords)

                                if markerDistance < 20.0 then
                                    -- Draw marker
                                    DrawMarker(
                                        1, -- Cylinder marker
                                        stationData.duty_marker.coords.x,
                                        stationData.duty_marker.coords.y,
                                        stationData.duty_marker.coords.z - 1.0,
                                        0.0, 0.0, 0.0, -- Direction
                                        0.0, 0.0, 0.0, -- Rotation
                                        stationData.duty_marker.size.x,
                                        stationData.duty_marker.size.y,
                                        stationData.duty_marker.size.z,
                                        stationData.duty_marker.color.r,
                                        stationData.duty_marker.color.g,
                                        stationData.duty_marker.color.b,
                                        stationData.duty_marker.color.a,
                                        false, true, 2, false, nil, false
                                    )

                                    if markerDistance < 2.0 then
                                        -- Show interaction text based on duty status
                                        local text = FL.Client.serviceInfo.isOnDuty and '~r~[E]~w~ End Duty' or
                                        '~g~[E]~w~ Start Duty'
                                        ShowHelpText(text)

                                        -- Handle interaction - now uses QBCore duty system
                                        if IsControlJustPressed(0, 38) then -- E key
                                            TriggerServerEvent('fl_core:toggleDuty', stationId)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- Create blips for stations (only for player's service)
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

-- Convert hex color to blip color (simplified)
function GetBlipColorFromHex(hexColor)
    local colorMap = {
        ['#e74c3c'] = 1, -- Red (Fire)
        ['#3498db'] = 3, -- Blue (Police)
        ['#2ecc71'] = 2  -- Green (EMS)
    }
    return colorMap[hexColor] or 0
end

-- ====================================================================
-- UNIFORM SYSTEM (Fixed for qb-clothing compatibility)
-- ====================================================================

-- Store original outfit before applying uniform
FL.Client.originalOutfit = nil

-- Apply uniform to player
function ApplyUniform(serviceName)
    local playerPed = FL.Client.playerPed
    local gender = GetEntityModel(playerPed) == GetHashKey('mp_f_freemode_01') and 0 or 1
    local uniform = FL.Functions.GetUniform(serviceName, gender)

    if not uniform then
        FL.Debug('No uniform found for ' .. serviceName)
        return false
    end

    -- Save current outfit before applying uniform
    SaveCurrentOutfit()

    -- Apply each clothing piece
    SetPedComponentVariation(playerPed, 8, uniform.tshirt_1, uniform.tshirt_2, 0)
    SetPedComponentVariation(playerPed, 11, uniform.torso_1, uniform.torso_2, 0)
    SetPedComponentVariation(playerPed, 3, uniform.arms, 0, 0)
    SetPedComponentVariation(playerPed, 4, uniform.pants_1, uniform.pants_2, 0)
    SetPedComponentVariation(playerPed, 6, uniform.shoes_1, uniform.shoes_2, 0)

    -- Props
    if uniform.helmet_1 and uniform.helmet_1 ~= -1 then
        SetPedPropIndex(playerPed, 0, uniform.helmet_1, uniform.helmet_2, true)
    else
        ClearPedProp(playerPed, 0)
    end

    if uniform.chain_1 and uniform.chain_1 ~= -1 then
        SetPedComponentVariation(playerPed, 7, uniform.chain_1, uniform.chain_2, 0)
    end

    FL.Debug('Applied ' .. serviceName .. ' uniform')
    return true
end

-- Save current outfit
function SaveCurrentOutfit()
    local playerPed = FL.Client.playerPed

    FL.Client.originalOutfit = {
        -- Components
        tshirt_1 = GetPedDrawableVariation(playerPed, 8),
        tshirt_2 = GetPedTextureVariation(playerPed, 8),
        torso_1 = GetPedDrawableVariation(playerPed, 11),
        torso_2 = GetPedTextureVariation(playerPed, 11),
        arms = GetPedDrawableVariation(playerPed, 3),
        pants_1 = GetPedDrawableVariation(playerPed, 4),
        pants_2 = GetPedTextureVariation(playerPed, 4),
        shoes_1 = GetPedDrawableVariation(playerPed, 6),
        shoes_2 = GetPedTextureVariation(playerPed, 6),
        chain_1 = GetPedDrawableVariation(playerPed, 7),
        chain_2 = GetPedTextureVariation(playerPed, 7),

        -- Props
        helmet_1 = GetPedPropIndex(playerPed, 0),
        helmet_2 = GetPedPropTextureIndex(playerPed, 0),
    }

    FL.Debug('Saved original outfit')
end

-- Remove uniform (fixed for qb-clothing compatibility)
function RemoveUniform()
    local playerPed = FL.Client.playerPed

    -- Try multiple methods to restore clothing
    if FL.Client.originalOutfit then
        -- Method 1: Restore saved outfit
        RestoreOriginalOutfit()
    else
        -- Method 2: Try qb-clothing events (with error handling)
        local success = false

        -- Try different qb-clothing event names
        local clothingEvents = {
            'qb-clothing:client:loadOutfit',
            'qb-clothes:loadPlayerSkin',
            'skinchanger:loadClothes',
            'esx_skin:getPlayerSkin'
        }

        for _, eventName in pairs(clothingEvents) do
            if GetResourceState('qb-clothing') == 'started' then
                TriggerEvent(eventName)
                success = true
                break
            end
        end

        -- Method 3: Fallback - reset to basic clothing
        if not success then
            ResetToBasicClothing()
        end
    end

    FL.Debug('Removed service uniform')
end

-- Restore original outfit
function RestoreOriginalOutfit()
    if not FL.Client.originalOutfit then
        FL.Debug('No original outfit saved')
        return false
    end

    local playerPed = FL.Client.playerPed
    local outfit = FL.Client.originalOutfit

    -- Restore components
    SetPedComponentVariation(playerPed, 8, outfit.tshirt_1, outfit.tshirt_2, 0)
    SetPedComponentVariation(playerPed, 11, outfit.torso_1, outfit.torso_2, 0)
    SetPedComponentVariation(playerPed, 3, outfit.arms, 0, 0)
    SetPedComponentVariation(playerPed, 4, outfit.pants_1, outfit.pants_2, 0)
    SetPedComponentVariation(playerPed, 6, outfit.shoes_1, outfit.shoes_2, 0)
    SetPedComponentVariation(playerPed, 7, outfit.chain_1, outfit.chain_2, 0)

    -- Restore props
    if outfit.helmet_1 and outfit.helmet_1 ~= -1 then
        SetPedPropIndex(playerPed, 0, outfit.helmet_1, outfit.helmet_2, true)
    else
        ClearPedProp(playerPed, 0)
    end

    FL.Debug('Restored original outfit')
    return true
end

-- Fallback: Reset to basic civilian clothing
function ResetToBasicClothing()
    local playerPed = FL.Client.playerPed
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
end

-- ====================================================================
-- EQUIPMENT SYSTEM (Updated for QBCore 1.3.0)
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

-- ====================================================================
-- MDT SYSTEM (Fixed UI Focus Issues)
-- ====================================================================

-- Show MDT/Tablet
function ShowMDT()
    if not FL.Client.serviceInfo or not FL.Client.serviceInfo.isOnDuty then
        QBCore.Functions.Notify('You must be on duty to use the MDT', 'error')
        return
    end

    -- Request fresh active calls from server
    TriggerServerEvent('fl_core:getActiveCalls')

    -- Wait a moment for server response, then show UI
    Wait(100)

    -- Prepare MDT data
    local mdtData = {
        service = FL.Client.serviceInfo.service,
        rank = FL.Client.serviceInfo.rank,
        rankName = FL.Client.serviceInfo.rankName,
        activeCalls = FL.Client.activeCalls
    }

    FL.Debug('Opening MDT with data: ' .. json.encode(mdtData))

    -- Play tablet animation
    local playerPed = FL.Client.playerPed
    RequestAnimDict(Config.MDT.animation.dict)
    while not HasAnimDictLoaded(Config.MDT.animation.dict) do
        Wait(100)
    end

    TaskPlayAnim(playerPed, Config.MDT.animation.dict, Config.MDT.animation.name, 8.0, 8.0, -1, 50, 0, false, false,
        false)

    -- Open MDT UI with proper focus
    FL.Client.showingUI = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showMDT',
        data = mdtData
    })
end

-- Close MDT properly (FIXED - Nuclear Option)
function CloseMDT()
    FL.Debug('Closing MDT UI - Starting aggressive cleanup')

    -- NUCLEAR OPTION: Force everything off immediately
    local playerPed = PlayerPedId()

    -- 1. Force NUI off with multiple attempts
    for i = 1, 10 do
        SetNuiFocus(false, false)
        Wait(10)
    end

    -- 2. Additional NUI disable methods
    SetNuiFocusKeepInput(false)

    -- 3. Force cursor reset
    SetCursorLocation(0.5, 0.5)

    -- 4. Reset client state immediately
    FL.Client.showingUI = false

    -- 5. Stop all animations aggressively
    if DoesEntityExist(playerPed) then
        ClearPedTasks(playerPed)
        ClearPedTasksImmediately(playerPed)

        -- Force stop specific animation if still playing
        if IsEntityPlayingAnim(playerPed, Config.MDT.animation.dict, Config.MDT.animation.name, 3) then
            StopAnimTask(playerPed, Config.MDT.animation.dict, Config.MDT.animation.name, 3.0)
            Wait(100)
            ClearPedTasks(playerPed)
        end
    end

    -- 6. Send multiple close messages to UI
    for i = 1, 5 do
        SendNUIMessage({ type = 'hideUI' })
        Wait(10)
    end

    -- 7. Final verification in separate thread
    CreateThread(function()
        Wait(200)
        -- Final safety checks
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)

        -- Test if chat can be opened
        if IsNuiFocused() then
            FL.Debug('⚠️ NUI still focused after close - this is the problem!')
            for i = 1, 20 do
                SetNuiFocus(false, false)
                Wait(50)
            end
        else
            FL.Debug('✅ NUI focus successfully cleared')
        end
    end)

    FL.Debug('MDT aggressive close completed')
end

-- Emergency close function (for when things go wrong)
function EmergencyCloseMDT()
    FL.Debug('Emergency MDT close initiated')

    -- Nuclear option: force everything off
    local playerPed = PlayerPedId()

    -- Stop all animations
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)

    -- Force NUI off
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    -- Reset state
    FL.Client.showingUI = false

    -- Send multiple close messages
    for i = 1, 3 do
        SendNUIMessage({ type = 'hideUI' })
        Wait(10)
    end

    FL.Debug('Emergency MDT close completed')
end

-- ====================================================================
-- NOTIFICATION SYSTEM
-- ====================================================================

-- Show help text
function ShowHelpText(text)
    SetTextComponentFormat('STRING')
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

-- ====================================================================
-- EVENT HANDLERS (Fixed for Emergency Calls - DETAILED DEBUGGING)
-- ====================================================================

-- Server events
RegisterNetEvent('fl_core:serviceInfo', function(serviceInfo)
    FL.Client.serviceInfo = serviceInfo
    FL.Debug('Received service info: ' .. (serviceInfo and serviceInfo.service or 'none'))
end)

RegisterNetEvent('fl_core:dutyChanged', function(onDuty, service, rank)
    FL.Debug('Duty changed: ' .. tostring(onDuty) .. ' for ' .. tostring(service))
    -- This is handled by QBCore job events now
end)

RegisterNetEvent('fl_core:newEmergencyCall', function(callData)
    FL.Client.activeCalls[callData.id] = callData

    FL.Debug('🆕 NEW CALL: ' .. callData.id .. ' for service: ' .. callData.service .. ' - Status: ' .. callData.status)

    -- Show notification
    local priorityText = FL.Functions.FormatPriority(callData.priority)
    QBCore.Functions.Notify('New ' .. priorityText .. ' call: ' .. callData.type, 'error')

    -- Play alert sound
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', 1)

    -- Update MDT if it's open
    if FL.Client.showingUI then
        FL.Debug('📱 MDT is open - sending update to UI')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })
    else
        FL.Debug('📱 MDT is closed - no UI update sent')
    end
end)

RegisterNetEvent('fl_core:callAssigned', function(callData)
    FL.Debug('📞 CALL ASSIGNED: ' .. callData.id .. ' - Status: ' .. callData.status)

    QBCore.Functions.Notify('You have been assigned to call ' .. callData.id, 'success')
    SetNewWaypoint(callData.coords.x, callData.coords.y)

    -- Update call in local storage
    FL.Client.activeCalls[callData.id] = callData

    FL.Debug('📱 Updated local call storage - Call ' .. callData.id .. ' status: ' .. callData.status)

    -- FORCE MDT update if open
    if FL.Client.showingUI then
        FL.Debug('📱 FORCING MDT UPDATE after assignment')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })

        -- Also send direct call update
        SendNUIMessage({
            type = 'callAssigned',
            callId = callData.id,
            callData = callData
        })
    end
end)

-- New event for call status updates
RegisterNetEvent('fl_core:callStatusUpdate', function(callId, callData)
    FL.Debug('📋 CALL STATUS UPDATE: ' .. callId .. ' - New Status: ' .. callData.status)

    -- Update call in local storage
    FL.Client.activeCalls[callId] = callData

    -- FORCE MDT update if open
    if FL.Client.showingUI then
        FL.Debug('📱 FORCING MDT UPDATE after status change')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })
    end
end)

RegisterNetEvent('fl_core:callCompleted', function(callId)
    FL.Client.activeCalls[callId] = nil
    QBCore.Functions.Notify('Call ' .. callId .. ' completed', 'success')

    FL.Debug('✅ CALL COMPLETED: ' .. callId)

    -- Update MDT if open
    if FL.Client.showingUI then
        FL.Debug('📱 FORCING MDT UPDATE after completion')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })
    end
end)

RegisterNetEvent('fl_core:activeCalls', function(calls)
    FL.Client.activeCalls = calls
    FL.Debug('📋 RECEIVED ACTIVE CALLS: ' .. FL.Functions.TableSize(calls) .. ' calls')

    -- Print all calls for debugging
    for callId, callData in pairs(calls) do
        FL.Debug('📞 Call: ' .. callId .. ' - Status: ' .. callData.status .. ' - Type: ' .. callData.type)
    end

    -- Update MDT if open
    if FL.Client.showingUI then
        FL.Debug('📱 SENDING CALLS TO MDT UI')
        SendNUIMessage({
            type = 'updateCalls',
            data = FL.Client.activeCalls
        })
    end
end)

-- ====================================================================
-- NUI CALLBACKS (Fixed)
-- ====================================================================

-- NUI: Close UI
RegisterNUICallback('closeUI', function(data, cb)
    FL.Debug('NUI close callback triggered')
    CloseMDT()
    cb('ok')
end)

-- NUI: Assign to call
RegisterNUICallback('assignToCall', function(data, cb)
    FL.Debug('Assigning to call: ' .. tostring(data.callId))
    TriggerServerEvent('fl_core:assignToCall', data.callId)
    cb('ok')
end)

-- NUI: Complete call
RegisterNUICallback('completeCall', function(data, cb)
    FL.Debug('Completing call: ' .. tostring(data.callId))
    TriggerServerEvent('fl_core:completeCall', data.callId)
    cb('ok')
end)

-- ====================================================================
-- COMMANDS (Fixed)
-- ====================================================================

-- Open MDT command
RegisterCommand('mdt', function()
    if FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty then
        ShowMDT()
    else
        QBCore.Functions.Notify('You must be on duty to use this command', 'error')
    end
end)

-- Emergency close MDT command (for when it gets stuck)
RegisterCommand('closemdt', function()
    EmergencyCloseMDT()
    QBCore.Functions.Notify('MDT force closed', 'success')
end)

-- Emergency chat fix command (wenn chat nicht geht)
RegisterCommand('fixchat', function()
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
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)

    -- Send emergency close to UI
    for i = 1, 10 do
        SendNUIMessage({ type = 'hideUI' })
        Wait(10)
    end

    FL.Debug('🚨 EMERGENCY CHAT FIX COMPLETED')
    QBCore.Functions.Notify('Chat should be fixed now - try T or Y', 'success')
end)

-- Debug command for checking calls (detailed)
RegisterCommand('debugcalls', function()
    if FL.Client.serviceInfo and FL.Client.serviceInfo.isOnDuty then
        TriggerServerEvent('fl_core:getActiveCalls')
        Wait(500)

        local count = FL.Functions.TableSize(FL.Client.activeCalls)
        QBCore.Functions.Notify('You have ' .. count .. ' active calls - Check F8 console for details', 'info')

        -- Print detailed call information to console
        print('^3[FL CLIENT DEBUG]^7 ======================')
        for callId, callData in pairs(FL.Client.activeCalls) do
            print('^3[FL CLIENT CALL]^7 ID: ' .. callId)
            print('^3[FL CLIENT CALL]^7 Status: ' .. callData.status)
            print('^3[FL CLIENT CALL]^7 Type: ' .. callData.type)
            print('^3[FL CLIENT CALL]^7 Priority: ' .. callData.priority)
            print('^3[FL CLIENT CALL]^7 Assigned Units: ' .. json.encode(callData.assigned_units or {}))
            print('^3[FL CLIENT CALL]^7 ---')
        end
        print('^3[FL CLIENT DEBUG]^7 ======================')
    else
        QBCore.Functions.Notify('You must be on duty to check calls', 'error')
    end
end)

-- ESC key handler for closing MDT (IMPROVED)
CreateThread(function()
    while true do
        Wait(0)
        if FL.Client.showingUI then
            -- ESC key
            if IsControlJustPressed(0, 322) then -- ESC
                FL.Debug('ESC key pressed - closing MDT')
                CloseMDT()
            end

            -- Additional emergency keys (BACKSPACE + TAB)
            if IsControlJustPressed(0, 194) then -- BACKSPACE
                FL.Debug('BACKSPACE pressed - emergency close')
                EmergencyCloseMDT()
            end

            -- Check if we're somehow stuck in UI mode
            if not HasStreamedTextureDictLoaded("helicopterhud") then
                -- Force check every few seconds
                Wait(100)
            end
        else
            Wait(500) -- Sleep when UI is not showing
        end
    end
end)

-- Additional safety thread to detect stuck UI
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds

        if FL.Client.showingUI then
            -- Check if NUI is actually focused
            if not IsNuiFocused() then
                FL.Debug('Detected stuck UI state - auto-fixing')
                EmergencyCloseMDT()
            end
        end
    end
end)

FL.Debug('Client refactored script loaded with QBCore integration')
