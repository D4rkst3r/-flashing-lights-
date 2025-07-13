-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - VSCODE WARNINGS FIXED
-- MySQL global warnings behoben durch bessere Initialisierung
-- Alle kritischen Parameter-Mismatches behoben
-- ====================================================================

local QBCore = FL.GetFramework()

-- MySQL namespace fix (for VSCode diagnostics)
MySQL = MySQL or exports.oxmysql

-- Global state variables (simplified)
FL.Server = {
    EmergencyCalls = {}, -- Active emergency calls [callId] = callData
    ActiveStations = {}  -- Track which stations players are using
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
-- DATABASE INITIALIZATION (IMPROVED)
-- ====================================================================

-- Initialize database automatically
CreateThread(function()
    FL.Debug('🔄 Initializing FL Emergency Services Database...')

    -- Wait for MySQL connection
    while GetResourceState('oxmysql') ~= 'started' do
        FL.Debug('⏳ Waiting for oxmysql to start...')
        Wait(1000)
    end

    -- Ensure MySQL is properly loaded
    MySQL = MySQL or exports.oxmysql

    Wait(2000)

    if not FL.Database then
        FL.Debug('❌ FL.Database module not loaded! Creating basic table...')
        CreateBasicTable()
        return
    end

    if FL.Database.IsInitialized() then
        FL.Debug('✅ Database already initialized')
        return
    end

    local success = FL.Database.Initialize()

    if success then
        FL.Debug('🎉 Database setup completed successfully!')
    else
        FL.Debug('❌ Database setup failed! Creating basic table...')
        CreateBasicTable()
    end
end)

-- Fallback function for basic table creation (FIXED: MySQL reference)
function CreateBasicTable()
    FL.Debug('🔨 Creating basic database table (fallback mode)...')

    -- Only create essential table
    if MySQL and MySQL.query then
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
                `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
                `completed_at` timestamp NULL,
                PRIMARY KEY (`id`),
                UNIQUE KEY `call_id` (`call_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {}, function()
            FL.Debug('✅ Basic emergency calls table created')
        end)
    else
        FL.Debug('❌ MySQL not available for table creation')
    end
end

-- ====================================================================
-- JOB-BASED FUNCTIONS (Simplified)
-- ====================================================================

-- Check if player has emergency service job
function IsPlayerEmergencyService(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, nil end

    local jobName = Player.PlayerData.job.name
    local service = FL.JobMapping[jobName]

    return service ~= nil, service
end

-- Get player's emergency service info
function GetPlayerServiceInfo(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end

    local jobName = Player.PlayerData.job.name
    local service = FL.JobMapping[jobName]

    if not service then return nil end

    return {
        service = service,
        rank = Player.PlayerData.job.grade.level,
        rankName = Player.PlayerData.job.grade.name,
        isOnDuty = Player.PlayerData.job.onduty,
        citizenid = Player.PlayerData.citizenid
    }
end

-- ====================================================================
-- EMERGENCY CALLS SYSTEM (FIXED)
-- ====================================================================

-- Create new emergency call (IMPROVED with better MySQL handling)
function CreateEmergencyCall(callData)
    if not callData or not callData.service or not callData.coords then
        FL.Debug('❌ CreateEmergencyCall: Invalid callData provided')
        return false
    end

    local callId = 'FL' .. string.upper(callData.service) .. os.time() .. math.random(100, 999)

    -- Prepare call data
    local emergencyCall = {
        id = callId,
        service = callData.service,
        type = callData.type or 'unknown',
        coords = callData.coords,
        priority = callData.priority or 2,
        description = callData.description or 'Emergency assistance required',
        status = 'pending',
        assigned_units = {},
        created_at = os.time()
    }

    -- Store in memory FIRST
    FL.Server.EmergencyCalls[callId] = emergencyCall
    FL.Debug('📝 Call stored in memory: ' .. callId .. ' - Status: ' .. emergencyCall.status)

    -- Store in database (FIXED: Better MySQL error handling)
    if MySQL and MySQL.insert then
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
    else
        FL.Debug('⚠️ MySQL not available for database insert')
    end

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

-- Assign unit to emergency call (COMPLETELY FIXED)
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

    -- Add unit to assigned units
    table.insert(call.assigned_units, source)
    call.status = 'assigned'

    FL.Debug('🔄 Updated call status to: ' .. call.status .. ' - Assigned units: ' .. json.encode(call.assigned_units))

    -- Update database (FIXED: Better MySQL error handling)
    if MySQL and MySQL.update then
        MySQL.update('UPDATE fl_emergency_calls SET status = ?, assigned_units = ? WHERE call_id = ?', {
            'assigned',
            json.encode(call.assigned_units),
            callId
        }, function(affectedRows)
            FL.Debug('💾 Database updated - Affected rows: ' .. tostring(affectedRows))
        end)
    else
        FL.Debug('⚠️ MySQL not available for database update')
    end

    -- Notify the assigned unit FIRST
    TriggerClientEvent('fl_core:callAssigned', source, call)
    TriggerClientEvent('QBCore:Notify', source, 'Call ' .. callId .. ' assigned to you', 'success')

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

-- Complete emergency call (also improved)
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

    FL.Debug('🔄 Updated call status to: ' .. call.status)

    -- Update database (FIXED: Better MySQL error handling)
    if MySQL and MySQL.update then
        MySQL.update('UPDATE fl_emergency_calls SET status = ?, completed_at = NOW() WHERE call_id = ?', {
            'completed',
            callId
        }, function(affectedRows)
            FL.Debug('💾 Database updated for completion - Affected rows: ' .. tostring(affectedRows))
        end)
    else
        FL.Debug('⚠️ MySQL not available for database update')
    end

    -- Notify all assigned units
    for _, assignedSource in pairs(call.assigned_units) do
        TriggerClientEvent('fl_core:callCompleted', assignedSource, callId)
        TriggerClientEvent('QBCore:Notify', assignedSource, 'Call ' .. callId .. ' completed', 'success')
    end

    -- Remove from active calls
    FL.Server.EmergencyCalls[callId] = nil

    FL.Debug('✅ Call ' .. callId .. ' completed and removed from active calls')
    return true, 'Completion successful'
end

-- ====================================================================
-- DUTY MANAGEMENT (QBCore Integration)
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

        TriggerClientEvent('QBCore:Notify', source, 'You are now off duty', 'success')
        TriggerClientEvent('fl_core:dutyChanged', source, false, service, 0)

        FL.Debug(Player.PlayerData.citizenid .. ' ended duty for ' .. service)
    else
        -- Start duty
        Player.Functions.SetJobDuty(true)
        FL.Server.ActiveStations[source] = stationId

        TriggerClientEvent('QBCore:Notify', source, 'You are now on duty', 'success')
        TriggerClientEvent('fl_core:dutyChanged', source, true, service, Player.PlayerData.job.grade.level)

        FL.Debug(Player.PlayerData.citizenid .. ' started duty for ' .. service .. ' at ' .. stationId)
    end

    return true
end

-- ====================================================================
-- NUI CALLBACKS (FIXED - Missing responses)
-- ====================================================================

-- NUI: Assign to call (FIXED with proper response)
RegisterNUICallback('assignToCall', function(data, cb)
    FL.Debug('📱 NUI Callback: assignToCall - Data: ' .. json.encode(data))

    local callId = data.callId
    if not callId then
        FL.Debug('❌ No callId provided in NUI callback')
        cb({ success = false, message = 'No call ID provided' })
        return
    end

    local success, message = AssignUnitToCall(callId, source)

    FL.Debug('📱 Assignment result - Success: ' .. tostring(success) .. ', Message: ' .. tostring(message))

    -- WICHTIG: Proper response to NUI
    cb({
        success = success,
        message = message,
        callId = callId,
        timestamp = os.time()
    })
end)

-- NUI: Complete call (FIXED with proper response)
RegisterNUICallback('completeCall', function(data, cb)
    FL.Debug('📱 NUI Callback: completeCall - Data: ' .. json.encode(data))

    local callId = data.callId
    if not callId then
        FL.Debug('❌ No callId provided in NUI callback')
        cb({ success = false, message = 'No call ID provided' })
        return
    end

    local success, message = CompleteEmergencyCall(callId, source)

    FL.Debug('📱 Completion result - Success: ' .. tostring(success) .. ', Message: ' .. tostring(message))

    -- WICHTIG: Proper response to NUI
    cb({
        success = success,
        message = message,
        callId = callId,
        timestamp = os.time()
    })
end)

-- NUI: Close UI (unchanged)
RegisterNUICallback('closeUI', function(data, cb)
    FL.Debug('📱 NUI Callback: closeUI')
    cb('ok')
end)

-- ====================================================================
-- EVENT HANDLERS
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

-- Get all active calls for player's service (IMPROVED)
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
            calls[callId] = callData
            callCount = callCount + 1
            FL.Debug('📋 Including call: ' .. callId .. ' - Status: ' .. callData.status)
        end
    end

    FL.Debug('📤 Sending ' .. callCount .. ' calls to client for service: ' .. serviceInfo.service)
    TriggerClientEvent('fl_core:activeCalls', source, calls)
end)

-- Assign to emergency call (SERVER EVENT - for backwards compatibility)
RegisterServerEvent('fl_core:assignToCall', function(callId)
    FL.Debug('📞 Server Event: assignToCall - CallID: ' .. tostring(callId))
    AssignUnitToCall(callId, source)
end)

-- Complete emergency call (SERVER EVENT - for backwards compatibility)
RegisterServerEvent('fl_core:completeCall', function(callId)
    FL.Debug('📞 Server Event: completeCall - CallID: ' .. tostring(callId))
    CompleteEmergencyCall(callId, source)
end)

-- ====================================================================
-- EQUIPMENT MANAGEMENT (QBCore 1.3.0 Compatible)
-- ====================================================================

-- Give equipment to player (server-side)
RegisterServerEvent('fl_core:giveEquipment', function(serviceName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local equipment = FL.Functions.GetServiceEquipment(serviceName)
    if not equipment or #equipment == 0 then
        FL.Debug('No equipment found for ' .. serviceName)
        return
    end

    -- Give radio first
    Player.Functions.AddItem('radio', 1)
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['radio'], 'add')

    -- Give service-specific equipment
    for _, item in pairs(equipment) do
        if QBCore.Shared.Items[item] then
            Player.Functions.AddItem(item, 1)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add')
        end
    end

    FL.Debug('Given ' .. serviceName .. ' equipment to ' .. Player.PlayerData.citizenid)
end)

-- Remove equipment from player (server-side)
RegisterServerEvent('fl_core:removeEquipment', function(serviceName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local equipment = FL.Functions.GetServiceEquipment(serviceName)
    if not equipment or #equipment == 0 then
        FL.Debug('No equipment found for ' .. serviceName)
        return
    end

    -- Remove radio
    local radioItem = Player.Functions.GetItemByName('radio')
    if radioItem then
        Player.Functions.RemoveItem('radio', radioItem.amount or 1)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['radio'], 'remove')
    end

    -- Remove service-specific equipment
    for _, item in pairs(equipment) do
        local playerItem = Player.Functions.GetItemByName(item)
        if playerItem then
            Player.Functions.RemoveItem(item, playerItem.amount)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove')
        end
    end

    FL.Debug('Removed ' .. serviceName .. ' equipment from ' .. Player.PlayerData.citizenid)
end)

-- ====================================================================
-- SIMPLIFIED ADMIN COMMANDS
-- ====================================================================

-- Create test emergency call
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
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /testcall [fire/police/ems]', 'error')
        return
    end

    local service = args[1]
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

        local callId = CreateEmergencyCall(callData)
        if callId then
            TriggerClientEvent('QBCore:Notify', source, 'Created emergency call: ' .. callId, 'success')
            FL.Debug('🚨 Test call created: ' .. callId .. ' for ' .. service .. ' by ' .. Player.PlayerData.citizenid)
        else
            TriggerClientEvent('QBCore:Notify', source, 'Failed to create emergency call', 'error')
        end
    end
end, false)

-- Debug command to check active calls (server-side)
RegisterCommand('servercalls', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    local count = 0
    TriggerClientEvent('QBCore:Notify', source, 'Check server console for detailed call info', 'info')

    print('^3[FL SERVER CALLS DEBUG]^7 ======================')
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        count = count + 1
        print('^3[FL SERVER CALLS]^7 Call ID: ' .. callId)
        print('^3[FL SERVER CALLS]^7 Service: ' .. callData.service)
        print('^3[FL SERVER CALLS]^7 Type: ' .. callData.type)
        print('^3[FL SERVER CALLS]^7 Status: ' .. callData.status)
        print('^3[FL SERVER CALLS]^7 Priority: ' .. callData.priority)
        print('^3[FL SERVER CALLS]^7 Assigned Units: ' .. json.encode(callData.assigned_units or {}))
        print('^3[FL SERVER CALLS]^7 Coords: ' ..
        callData.coords.x .. ', ' .. callData.coords.y .. ', ' .. callData.coords.z)
        print('^3[FL SERVER CALLS]^7 ---')
    end
    print('^3[FL SERVER CALLS DEBUG]^7 Total active calls: ' .. count)
    print('^3[FL SERVER CALLS DEBUG]^7 ======================')

    TriggerClientEvent('QBCore:Notify', source, 'Found ' .. count .. ' active calls on server', 'success')
end, false)

-- ====================================================================
-- CLEANUP ON PLAYER DISCONNECT
-- ====================================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Clean up station tracking
    if FL.Server.ActiveStations[source] then
        FL.Server.ActiveStations[source] = nil
    end

    -- Remove from any assigned calls
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        for i, assignedSource in pairs(callData.assigned_units) do
            if assignedSource == source then
                table.remove(callData.assigned_units, i)
                FL.Debug('🚪 Removed disconnected player ' .. source .. ' from call ' .. callId)

                -- If no units left assigned, reset to pending
                if #callData.assigned_units == 0 then
                    callData.status = 'pending'
                    FL.Debug('🔄 Call ' .. callId .. ' reset to pending - no units assigned')
                end
                break
            end
        end
    end
end)

FL.Debug('🎉 FL Core server loaded with ALL VSCode warnings fixed')
