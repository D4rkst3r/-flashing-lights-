-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - SERVER MAIN (MULTI-UNIT ASSIGNMENT)
-- NEUE FEATURES:
-- 1. Mehrere Units können sich zu einem Call zuweisen
-- 2. Assigned Units werden mit Namen/Callsigns angezeigt
-- 3. Verbessertes Status-System (pending -> assigned -> in_progress -> completed)
-- 4. Unit-Details werden an alle Clients gesendet
-- ====================================================================

local QBCore = FL.GetFramework()

-- Global state variables (enhanced)
FL.Server = {
    EmergencyCalls = {}, -- Active emergency calls [callId] = callData
    ActiveStations = {}, -- Track which stations players are using
    UnitCallsigns = {}   -- Store unit callsigns [source] = callsign
}

-- Mapping between QBCore jobs and FL services
FL.JobMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ambulance'] = 'ems' -- QBCore uses 'ambulance' for EMS
}

-- Reverse mapping
FL.ServiceMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ems'] = 'ambulance'
}

-- ====================================================================
-- ENHANCED UNIT MANAGEMENT
-- ====================================================================

-- Generate callsign for player
local function GenerateCallsign(service, source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 'UNKNOWN' end

    local serviceMap = {
        ['fire'] = 'E',   -- Engine
        ['police'] = 'A', -- Adam (Police)
        ['ems'] = 'M'     -- Medic
    }

    local prefix = serviceMap[service] or 'U'
    local unitNumber = math.random(100, 999)

    return prefix .. unitNumber
end

-- Get player name for display
local function GetPlayerDisplayName(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 'Unknown Player' end

    return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
end

-- Get unit info for display
local function GetUnitInfo(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end

    local callsign = FL.Server.UnitCallsigns[source]
    if not callsign then
        local service = FL.JobMapping[Player.PlayerData.job.name]
        if service then
            callsign = GenerateCallsign(service, source)
            FL.Server.UnitCallsigns[source] = callsign
        else
            callsign = 'UNKNOWN'
        end
    end

    return {
        source = source,
        callsign = callsign,
        name = GetPlayerDisplayName(source),
        rank = Player.PlayerData.job.grade.name,
        isOnline = true
    }
end

-- ====================================================================
-- EMERGENCY CALLS SYSTEM (ENHANCED FOR MULTI-UNIT)
-- ====================================================================

-- Create new emergency call (enhanced with unit tracking)
function CreateEmergencyCall(callData)
    if not callData or not callData.service or not callData.coords then
        FL.Debug('❌ CreateEmergencyCall: Invalid callData provided')
        return false
    end

    local callId = 'FL' .. string.upper(callData.service) .. os.time() .. math.random(100, 999)

    -- Prepare call data with enhanced unit tracking
    local emergencyCall = {
        id = callId,
        service = callData.service,
        type = callData.type or 'unknown',
        coords = callData.coords,
        priority = callData.priority or 2,
        description = callData.description or 'Emergency assistance required',
        status = 'pending',
        assigned_units = {},                -- Array of source IDs
        unit_details = {},                  -- Array of unit info objects
        created_at = os.time(),
        max_units = callData.max_units or 4 -- Maximum units that can respond
    }

    -- Store in memory FIRST
    FL.Server.EmergencyCalls[callId] = emergencyCall
    FL.Debug('📝 Call stored in memory: ' .. callId .. ' - Status: ' .. emergencyCall.status)

    -- Store in database
    MySQL.insert(
        'INSERT INTO fl_emergency_calls (call_id, service, call_type, coords_x, coords_y, coords_z, priority, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {
            callId,
            emergencyCall.service,
            emergencyCall.type,
            emergencyCall.coords.x,
            emergencyCall.coords.y,
            emergencyCall.coords.z,
            emergencyCall.priority,
            emergencyCall.description
        },
        function(insertId)
            FL.Debug('💾 Call saved to database with ID: ' .. tostring(insertId))
        end
    )

    -- Notify all on-duty units of the same service
    local notifiedCount = 0
    local Players = QBCore.Functions.GetPlayers()
    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.onduty then
            local playerService = FL.JobMapping[Player.PlayerData.job.name]
            if playerService == emergencyCall.service then
                TriggerClientEvent('fl_core:newEmergencyCall', playerId, emergencyCall)
                notifiedCount = notifiedCount + 1
            end
        end
    end

    FL.Debug('🚨 Created emergency call: ' ..
        callId .. ' for ' .. emergencyCall.service .. ' - Notified ' .. notifiedCount .. ' units')
    return callId
end

-- Assign unit to emergency call (COMPLETELY REWRITTEN FOR MULTI-UNIT)
function AssignUnitToCall(callId, source)
    FL.Debug('🎯 AssignUnitToCall called - CallID: ' .. tostring(callId) .. ', Source: ' .. tostring(source))

    local call = FL.Server.EmergencyCalls[callId]
    local serviceInfo = GetPlayerServiceInfo(source)

    -- DETAILED DEBUG OUTPUT
    if not call then
        FL.Debug('❌ Call not found in memory: ' .. tostring(callId))
        FL.Debug('Available calls: ' .. json.encode(FL.Server.EmergencyCalls))
        return false, 'Call not found'
    end

    if not serviceInfo then
        FL.Debug('❌ Service info not found for source: ' .. tostring(source))
        return false, 'Service info not found'
    end

    FL.Debug('✅ Call found: ' .. callId .. ' - Current status: ' .. call.status)
    FL.Debug('✅ Service info: ' .. json.encode(serviceInfo))

    -- Check if unit is on duty and the right service
    if not serviceInfo.isOnDuty then
        FL.Debug('❌ Player not on duty')
        TriggerClientEvent('QBCore:Notify', source, 'You must be on duty to respond to calls', 'error')
        return false, 'Not on duty'
    end

    if call.service ~= serviceInfo.service then
        FL.Debug('❌ Service mismatch - Call: ' .. call.service .. ', Player: ' .. serviceInfo.service)
        TriggerClientEvent('QBCore:Notify', source, 'This call is not for your service', 'error')
        return false, 'Service mismatch'
    end

    -- Check if already assigned
    for _, assignedSource in pairs(call.assigned_units) do
        if assignedSource == source then
            FL.Debug('❌ Unit already assigned to call')
            TriggerClientEvent('QBCore:Notify', source, 'You are already assigned to this call', 'error')
            return false, 'Already assigned'
        end
    end

    -- Check if maximum units reached
    if #call.assigned_units >= call.max_units then
        FL.Debug('❌ Maximum units reached for call')
        TriggerClientEvent('QBCore:Notify', source, 'Maximum units already assigned to this call', 'error')
        return false, 'Maximum units reached'
    end

    -- Add unit to assigned units
    table.insert(call.assigned_units, source)

    -- Get unit info and add to details
    local unitInfo = GetUnitInfo(source)
    if unitInfo then
        table.insert(call.unit_details, unitInfo)
    end

    -- Update call status based on assignment count
    if #call.assigned_units == 1 then
        call.status = 'assigned'
    elseif #call.assigned_units > 1 then
        call.status = 'multi_assigned'
    end

    FL.Debug('🔄 Updated call status to: ' .. call.status .. ' - Assigned units: ' .. #call.assigned_units)
    FL.Debug('👥 Unit details: ' .. json.encode(call.unit_details))

    -- Update database
    MySQL.update('UPDATE fl_emergency_calls SET status = ?, assigned_units = ? WHERE call_id = ?', {
        call.status,
        json.encode(call.assigned_units),
        callId
    }, function(affectedRows)
        FL.Debug('💾 Database updated - Affected rows: ' .. tostring(affectedRows))
    end)

    -- Generate assignment message
    local unitCallsign = unitInfo and unitInfo.callsign or 'Unknown Unit'
    local assignmentMsg = 'Unit ' .. unitCallsign .. ' assigned to call ' .. callId
    if #call.assigned_units > 1 then
        assignmentMsg = assignmentMsg .. ' (' .. #call.assigned_units .. ' units total)'
    end

    -- Notify the assigned unit FIRST
    TriggerClientEvent('fl_core:callAssigned', source, call)
    TriggerClientEvent('QBCore:Notify', source, assignmentMsg, 'success')

    FL.Debug('📞 Sent callAssigned event to source: ' .. source)

    -- Update ALL units of this service with the new call status
    local Players = QBCore.Functions.GetPlayers()
    local updateCount = 0
    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.onduty then
            local playerService = FL.JobMapping[Player.PlayerData.job.name]
            if playerService == call.service then
                TriggerClientEvent('fl_core:callStatusUpdate', playerId, callId, call)
                updateCount = updateCount + 1
                FL.Debug('📱 Sent status update to player: ' .. playerId)
            end
        end
    end

    FL.Debug('✅ Assignment completed - Updated ' .. updateCount .. ' units')
    FL.Debug('📊 Final call state: ' .. json.encode(call))

    return true, 'Assignment successful'
end

-- Start working on call (NEW FUNCTION)
function StartWorkingOnCall(callId, source)
    FL.Debug('🚀 StartWorkingOnCall called - CallID: ' .. tostring(callId) .. ', Source: ' .. tostring(source))

    local call = FL.Server.EmergencyCalls[callId]

    if not call then
        FL.Debug('❌ Call not found for start work: ' .. tostring(callId))
        return false, 'Call not found'
    end

    -- Check if unit is assigned to this call
    local isAssigned = false
    for _, assignedSource in pairs(call.assigned_units) do
        if assignedSource == source then
            isAssigned = true
            break
        end
    end

    if not isAssigned then
        FL.Debug('❌ Unit not assigned to call for start work')
        TriggerClientEvent('QBCore:Notify', source, 'You are not assigned to this call', 'error')
        return false, 'Not assigned'
    end

    -- Update call status to in progress
    call.status = 'in_progress'
    call.started_at = os.time()

    FL.Debug('🔄 Updated call status to: ' .. call.status)

    -- Update database
    MySQL.update('UPDATE fl_emergency_calls SET status = ? WHERE call_id = ?', {
        'in_progress',
        callId
    }, function(affectedRows)
        FL.Debug('💾 Database updated for start work - Affected rows: ' .. tostring(affectedRows))
    end)

    -- Notify all assigned units
    for _, assignedSource in pairs(call.assigned_units) do
        TriggerClientEvent('fl_core:callStatusUpdate', assignedSource, callId, call)
        TriggerClientEvent('QBCore:Notify', assignedSource, 'Call ' .. callId .. ' is now in progress', 'info')
    end

    FL.Debug('✅ Call ' .. callId .. ' started successfully')
    return true, 'Call started successfully'
end

-- Complete emergency call (enhanced for multi-unit)
function CompleteEmergencyCall(callId, source)
    FL.Debug('✅ CompleteEmergencyCall called - CallID: ' .. tostring(callId) .. ', Source: ' .. tostring(source))

    local call = FL.Server.EmergencyCalls[callId]

    if not call then
        FL.Debug('❌ Call not found for completion: ' .. tostring(callId))
        return false, 'Call not found'
    end

    -- Check if unit is assigned to this call
    local isAssigned = false
    for _, assignedSource in pairs(call.assigned_units) do
        if assignedSource == source then
            isAssigned = true
            break
        end
    end

    if not isAssigned then
        FL.Debug('❌ Unit not assigned to call for completion')
        TriggerClientEvent('QBCore:Notify', source, 'You are not assigned to this call', 'error')
        return false, 'Not assigned'
    end

    -- Mark call as completed
    call.status = 'completed'
    call.completed_at = os.time()
    call.completed_by = source

    FL.Debug('🔄 Updated call status to: ' .. call.status)

    -- Calculate response time
    if call.started_at then
        call.response_time = call.completed_at - call.started_at
    end

    -- Update database
    MySQL.update('UPDATE fl_emergency_calls SET status = ?, completed_at = NOW(), response_time = ? WHERE call_id = ?', {
        'completed',
        call.response_time or 0,
        callId
    }, function(affectedRows)
        FL.Debug('💾 Database updated for completion - Affected rows: ' .. tostring(affectedRows))
    end)

    -- Notify all assigned units
    local completedByUnit = GetUnitInfo(source)
    local completionMsg = 'Call ' .. callId .. ' completed'
    if completedByUnit then
        completionMsg = completionMsg .. ' by Unit ' .. completedByUnit.callsign
    end

    for _, assignedSource in pairs(call.assigned_units) do
        TriggerClientEvent('fl_core:callCompleted', assignedSource, callId)
        TriggerClientEvent('QBCore:Notify', assignedSource, completionMsg, 'success')
    end

    -- Remove from active calls
    FL.Server.EmergencyCalls[callId] = nil

    FL.Debug('✅ Call ' .. callId .. ' completed and removed from active calls')
    return true, 'Completion successful'
end

-- ====================================================================
-- JOB-BASED FUNCTIONS (enhanced with unit tracking)
-- ====================================================================

-- Check if player has emergency service job
function IsPlayerEmergencyService(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for source: ' .. tostring(source))
        return false, nil
    end

    local jobName = Player.PlayerData.job.name
    local service = FL.JobMapping[jobName]

    FL.Debug('🔍 Player job check - Job: ' .. tostring(jobName) .. ', Service: ' .. tostring(service))
    return service ~= nil, service
end

-- Get player's emergency service info
function GetPlayerServiceInfo(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for service info: ' .. tostring(source))
        return nil
    end

    local jobName = Player.PlayerData.job.name
    local service = FL.JobMapping[jobName]

    if not service then
        FL.Debug('❌ No emergency service job for: ' .. tostring(jobName))
        return nil
    end

    local serviceInfo = {
        service = service,
        rank = Player.PlayerData.job.grade.level,
        rankName = Player.PlayerData.job.grade.name,
        isOnDuty = Player.PlayerData.job.onduty,
        citizenid = Player.PlayerData.citizenid
    }

    FL.Debug('✅ Service info retrieved: ' .. json.encode(serviceInfo))
    return serviceInfo
end

-- ====================================================================
-- SERVER EVENTS (ENHANCED FOR MULTI-UNIT)
-- ====================================================================

-- ENHANCED: Server Event for Assignment
RegisterServerEvent('fl_core:assignToCallFromUI', function(callId)
    FL.Debug('📱 Server Event: assignToCallFromUI - CallID: ' .. tostring(callId))

    if not callId then
        FL.Debug('❌ No callId provided in server event')
        return
    end

    local success, message = AssignUnitToCall(callId, source)

    FL.Debug('📱 Assignment result - Success: ' .. tostring(success) .. ', Message: ' .. tostring(message))

    -- Send result back to client
    TriggerClientEvent('fl_core:assignmentResult', source, {
        success = success,
        message = message,
        callId = callId
    })
end)

-- NEW: Server Event for starting work on call
RegisterServerEvent('fl_core:startWorkOnCallFromUI', function(callId)
    FL.Debug('📱 Server Event: startWorkOnCallFromUI - CallID: ' .. tostring(callId))

    if not callId then
        FL.Debug('❌ No callId provided in server event')
        return
    end

    local success, message = StartWorkingOnCall(callId, source)

    FL.Debug('📱 Start work result - Success: ' .. tostring(success) .. ', Message: ' .. tostring(message))

    -- Send result back to client
    TriggerClientEvent('fl_core:startWorkResult', source, {
        success = success,
        message = message,
        callId = callId
    })
end)

-- ENHANCED: Server Event for Completion
RegisterServerEvent('fl_core:completeCallFromUI', function(callId)
    FL.Debug('📱 Server Event: completeCallFromUI - CallID: ' .. tostring(callId))

    if not callId then
        FL.Debug('❌ No callId provided in server event')
        return
    end

    local success, message = CompleteEmergencyCall(callId, source)

    FL.Debug('📱 Completion result - Success: ' .. tostring(success) .. ', Message: ' .. tostring(message))

    -- Send result back to client
    TriggerClientEvent('fl_core:completionResult', source, {
        success = success,
        message = message,
        callId = callId
    })
end)

-- ====================================================================
-- REGULAR EVENT HANDLERS (unchanged)
-- ====================================================================

-- Player wants to toggle duty at station
RegisterServerEvent('fl_core:toggleDuty', function(stationId)
    HandleDutyToggle(source, stationId)
end)

-- Get player's current service info
RegisterServerEvent('fl_core:getServiceInfo', function()
    local serviceInfo = GetPlayerServiceInfo(source)
    TriggerClientEvent('fl_core:serviceInfo', source, serviceInfo)
end)

-- Get all active calls for player's service (ENHANCED with unit details)
RegisterServerEvent('fl_core:getActiveCalls', function()
    FL.Debug('📞 getActiveCalls requested by source: ' .. tostring(source))

    local serviceInfo = GetPlayerServiceInfo(source)
    if not serviceInfo then
        FL.Debug('❌ No service info for getActiveCalls')
        return
    end

    local calls = {}
    local callCount = 0
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        if callData.service == serviceInfo.service then
            -- Clean up unit details (remove offline players)
            local activeUnitDetails = {}
            for _, unitDetail in pairs(callData.unit_details) do
                local Player = QBCore.Functions.GetPlayer(unitDetail.source)
                if Player then
                    activeUnitDetails[#activeUnitDetails + 1] = unitDetail
                end
            end
            callData.unit_details = activeUnitDetails

            calls[callId] = callData
            callCount = callCount + 1
            FL.Debug('📋 Including call: ' ..
            callId .. ' - Status: ' .. callData.status .. ' - Units: ' .. #callData.unit_details)
        end
    end

    FL.Debug('📤 Sending ' .. callCount .. ' calls to client for service: ' .. serviceInfo.service)
    TriggerClientEvent('fl_core:activeCalls', source, calls)
end)

-- ====================================================================
-- DUTY MANAGEMENT (unchanged but enhanced with callsign generation)
-- ====================================================================

-- Handle duty toggle (integrates with QBCore duty system)
function HandleDutyToggle(source, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local isEmergency, service = IsPlayerEmergencyService(source)
    if not isEmergency then
        TriggerClientEvent('QBCore:Notify', source, 'You are not employed by an emergency service', 'error')
        return false
    end

    local currentDuty = Player.PlayerData.job.onduty

    if currentDuty then
        -- End duty
        Player.Functions.SetJobDuty(false)
        FL.Server.ActiveStations[source] = nil
        FL.Server.UnitCallsigns[source] = nil -- Clear callsign

        TriggerClientEvent('QBCore:Notify', source, 'You are now off duty', 'success')
        TriggerClientEvent('fl_core:dutyChanged', source, false, service, 0)

        FL.Debug(Player.PlayerData.citizenid .. ' ended duty for ' .. service)
    else
        -- Start duty
        Player.Functions.SetJobDuty(true)
        FL.Server.ActiveStations[source] = stationId

        -- Generate callsign
        local callsign = GenerateCallsign(service, source)
        FL.Server.UnitCallsigns[source] = callsign

        TriggerClientEvent('QBCore:Notify', source, 'You are now on duty as Unit ' .. callsign, 'success')
        TriggerClientEvent('fl_core:dutyChanged', source, true, service, Player.PlayerData.job.grade.level)

        FL.Debug(Player.PlayerData.citizenid ..
        ' started duty for ' .. service .. ' as Unit ' .. callsign .. ' at ' .. stationId)
    end

    return true
end

-- ====================================================================
-- CLEANUP ON PLAYER DISCONNECT (enhanced)
-- ====================================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Clean up station tracking
    if FL.Server.ActiveStations[source] then
        FL.Server.ActiveStations[source] = nil
    end

    -- Clean up callsign
    if FL.Server.UnitCallsigns[source] then
        FL.Server.UnitCallsigns[source] = nil
    end

    -- Remove from any assigned calls and update unit details
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        -- Remove from assigned units
        for i, assignedSource in pairs(callData.assigned_units) do
            if assignedSource == source then
                table.remove(callData.assigned_units, i)
                FL.Debug('🚪 Removed disconnected player ' .. source .. ' from call ' .. callId)
                break
            end
        end

        -- Remove from unit details
        for i, unitDetail in pairs(callData.unit_details) do
            if unitDetail.source == source then
                table.remove(callData.unit_details, i)
                FL.Debug('🚪 Removed unit detail for player ' .. source .. ' from call ' .. callId)
                break
            end
        end

        -- Update call status if no units left assigned
        if #callData.assigned_units == 0 then
            callData.status = 'pending'
            FL.Debug('🔄 Call ' .. callId .. ' reset to pending - no units assigned')
        elseif #callData.assigned_units == 1 then
            callData.status = 'assigned'
        end
    end
end)

-- ====================================================================
-- ENHANCED ADMIN COMMANDS
-- ====================================================================

-- Create test emergency call with custom max units
RegisterCommand('testcall', function(source, args, rawCommand)
    FL.Debug('🧪 testcall command executed by source: ' .. tostring(source))

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- Allow admins or on-duty emergency services to create test calls
    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')
    local serviceInfo = GetPlayerServiceInfo(source)

    if not hasPermission and not (serviceInfo and serviceInfo.isOnDuty) then
        TriggerClientEvent('QBCore:Notify', source, 'You need to be an admin or on duty to create test calls', 'error')
        return
    end

    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /testcall [fire/police/ems] [max_units]', 'error')
        return
    end

    local service = args[1]
    local maxUnits = tonumber(args[2]) or 4

    if not FL.Functions.ValidateService(service) then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid service. Use: fire, police, or ems', 'error')
        return
    end

    -- Get player coordinates for call location
    local playerCoords = GetEntityCoords(GetPlayerPed(source))

    -- Create call data
    local callData = FL.Functions.GenerateEmergencyCall(service)
    if callData then
        callData.coords = vector3(playerCoords.x, playerCoords.y, playerCoords.z)
        callData.max_units = maxUnits

        local callId = CreateEmergencyCall(callData)
        if callId then
            TriggerClientEvent('QBCore:Notify', source,
                'Created emergency call: ' .. callId .. ' (Max Units: ' .. maxUnits .. ')', 'success')
            FL.Debug('🚨 Test call created: ' ..
            callId .. ' for ' .. service .. ' with max units: ' .. maxUnits .. ' by ' .. Player.PlayerData.citizenid)
        else
            TriggerClientEvent('QBCore:Notify', source, 'Failed to create emergency call', 'error')
        end
    end
end, false)

-- ====================================================================
-- DATABASE INITIALIZATION (minimal version)
-- ====================================================================

CreateThread(function()
    FL.Debug('🔄 Initializing FL Emergency Services Database...')

    -- Wait for MySQL connection
    while GetResourceState('oxmysql') ~= 'started' do
        FL.Debug('⏳ Waiting for oxmysql to start...')
        Wait(1000)
    end

    Wait(2000)

    -- Create enhanced tables for multi-unit support
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `fl_emergency_calls` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `call_id` varchar(20) NOT NULL,
            `service` varchar(20) NOT NULL,
            `call_type` varchar(50) NOT NULL,
            `coords_x` float NOT NULL,
            `coords_y` float NOT NULL,
            `coords_z` float NOT NULL,
            `priority` int(1) DEFAULT 2,
            `description` text,
            `status` varchar(20) DEFAULT 'pending',
            `assigned_units` text,
            `max_units` int(2) DEFAULT 4,
            `response_time` int(11) DEFAULT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `started_at` timestamp NULL,
            `completed_at` timestamp NULL,
            `completed_by` int(11) DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `call_id` (`call_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        FL.Debug('✅ Enhanced emergency calls table ready')
    end)
end)

FL.Debug('🎉 FL Core server loaded with MULTI-UNIT Assignment Support')
