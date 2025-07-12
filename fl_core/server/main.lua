-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - REFACTORED FOR QBCORE JOBS
-- Diese Version nutzt das native QBCore Job-System
-- ====================================================================

local QBCore = FL.GetFramework()

-- Global state variables (vereinfacht)
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
-- DATABASE INITIALIZATION (unchanged)
-- ====================================================================

-- Initialize database automatically
CreateThread(function()
    FL.Debug('🔄 Initializing FL Emergency Services Database...')

    -- Wait for MySQL connection
    while GetResourceState('oxmysql') ~= 'started' do
        FL.Debug('⏳ Waiting for oxmysql to start...')
        Wait(1000)
    end

    Wait(2000)

    if not FL.Database then
        FL.Debug('❌ FL.Database module not loaded! Falling back to basic table creation...')
        CreateBasicTables()
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
        FL.Debug('❌ Database setup failed! Falling back to basic table creation...')
        CreateBasicTables()
    end
end)

-- Fallback function for basic table creation
function CreateBasicTables()
    FL.Debug('🔨 Creating basic database tables (fallback mode)...')

    -- Only create essential tables
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
    ]])

    FL.Debug('✅ Basic database tables created successfully')
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
-- EMERGENCY CALLS SYSTEM (unchanged but simplified)
-- ====================================================================

-- Create new emergency call
function CreateEmergencyCall(callData)
    if not callData or not callData.service or not callData.coords then
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

    -- Store in memory
    FL.Server.EmergencyCalls[callId] = emergencyCall

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
        })

    -- Notify all on-duty units of the same service
    local Players = QBCore.Functions.GetPlayers()
    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.onduty then
            local playerService = FL.JobMapping[Player.PlayerData.job.name]
            if playerService == emergencyCall.service then
                TriggerClientEvent('fl_core:newEmergencyCall', playerId, emergencyCall)
            end
        end
    end

    FL.Debug('Created emergency call: ' .. callId .. ' for ' .. emergencyCall.service)
    return callId
end

-- Assign unit to emergency call (Fixed)
function AssignUnitToCall(callId, source)
    local call = FL.Server.EmergencyCalls[callId]
    local serviceInfo = GetPlayerServiceInfo(source)

    if not call or not serviceInfo then
        FL.Debug('Call or service info not found for assignment')
        return false
    end

    -- Check if unit is on duty and the right service
    if not serviceInfo.isOnDuty then
        TriggerClientEvent('QBCore:Notify', source, 'You must be on duty to respond to calls', 'error')
        return false
    end

    if call.service ~= serviceInfo.service then
        TriggerClientEvent('QBCore:Notify', source, 'This call is not for your service', 'error')
        return false
    end

    -- Check if already assigned
    for _, assignedSource in pairs(call.assigned_units) do
        if assignedSource == source then
            TriggerClientEvent('QBCore:Notify', source, 'You are already assigned to this call', 'error')
            return false
        end
    end

    -- Add unit to assigned units
    table.insert(call.assigned_units, source)
    call.status = 'assigned'

    -- Update database
    MySQL.update('UPDATE fl_emergency_calls SET status = ?, assigned_units = ? WHERE call_id = ?', {
        'assigned',
        json.encode(call.assigned_units),
        callId
    })

    -- Notify the assigned unit
    TriggerClientEvent('fl_core:callAssigned', source, call)
    TriggerClientEvent('QBCore:Notify', source, 'Call ' .. callId .. ' assigned to you', 'success')

    -- Update ALL units of this service with the new call status
    local Players = QBCore.Functions.GetPlayers()
    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.onduty then
            local playerService = FL.JobMapping[Player.PlayerData.job.name]
            if playerService == call.service then
                TriggerClientEvent('fl_core:callStatusUpdate', playerId, callId, call)
            end
        end
    end

    FL.Debug('Assigned unit ' .. source .. ' to call ' .. callId .. ' - Status: ' .. call.status)
    return true
end

-- Complete emergency call
function CompleteEmergencyCall(callId, source)
    local call = FL.Server.EmergencyCalls[callId]

    if not call then
        return false
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
        TriggerClientEvent('QBCore:Notify', source, 'You are not assigned to this call', 'error')
        return false
    end

    -- Mark call as completed
    call.status = 'completed'
    call.completed_at = os.time()

    -- Update database
    MySQL.update('UPDATE fl_emergency_calls SET status = ?, completed_at = NOW() WHERE call_id = ?', {
        'completed',
        callId
    })

    -- Remove from active calls
    FL.Server.EmergencyCalls[callId] = nil

    -- Notify all assigned units
    for _, assignedSource in pairs(call.assigned_units) do
        TriggerClientEvent('fl_core:callCompleted', assignedSource, callId)
        TriggerClientEvent('QBCore:Notify', assignedSource, 'Call ' .. callId .. ' completed', 'success')
    end

    FL.Debug('Call ' .. callId .. ' completed by unit ' .. source)
    return true
end

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
-- EVENT HANDLERS (Simplified)
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

-- Get all active calls for player's service
RegisterServerEvent('fl_core:getActiveCalls', function()
    local serviceInfo = GetPlayerServiceInfo(source)
    if not serviceInfo then return end

    local calls = {}
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        if callData.service == serviceInfo.service then
            calls[callId] = callData
        end
    end
    TriggerClientEvent('fl_core:activeCalls', source, calls)
end)

-- Assign to emergency call
RegisterServerEvent('fl_core:assignToCall', function(callId)
    AssignUnitToCall(callId, source)
end)

-- Complete emergency call
RegisterServerEvent('fl_core:completeCall', function(callId)
    CompleteEmergencyCall(callId, source)
end)

-- ====================================================================
-- SIMPLIFIED ADMIN COMMANDS
-- ====================================================================

-- Create test emergency call (fixed)
RegisterCommand('testcall', function(source, args, rawCommand)
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
            FL.Debug('Test call created: ' .. callId .. ' for ' .. service)
        else
            TriggerClientEvent('QBCore:Notify', source, 'Failed to create emergency call', 'error')
        end
    end
end, false)

-- Debug command to check active calls
RegisterCommand('checkcalls', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local serviceInfo = GetPlayerServiceInfo(source)
    if not serviceInfo then
        TriggerClientEvent('QBCore:Notify', source, 'You are not in an emergency service', 'error')
        return
    end

    local count = 0
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        if callData.service == serviceInfo.service then
            count = count + 1
            FL.Debug('Active call: ' .. callId .. ' (' .. callData.type .. ') - Status: ' .. callData.status)
        end
    end

    TriggerClientEvent('QBCore:Notify', source, 'Active calls for ' .. serviceInfo.service .. ': ' .. count, 'info')
    FL.Debug('Player ' .. source .. ' checked calls for ' .. serviceInfo.service .. ' - Found: ' .. count)
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
end)

FL.Debug('FL Core server loaded with QBCore job integration')
