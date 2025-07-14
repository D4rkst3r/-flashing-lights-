-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - SERVER MAIN (RATE LIMIT FIXED)
-- ====================================================================

local QBCore = FL.GetFramework()

-- Global state variables (enhanced with error recovery)
FL.Server = {
    EmergencyCalls = {},       -- Active emergency calls [callId] = callData
    ActiveStations = {},       -- Track which stations players are using
    UnitCallsigns = {},        -- Store unit callsigns [source] = callsign
    DatabaseAvailable = false, -- Track database connection status
    LastCleanup = 0            -- Track last cleanup time
}

-- ====================================================================
-- RATE LIMITING SYSTEM (MOVED FROM SECURITY.LUA)
-- ====================================================================

FL.Security = FL.Security or {
    rateLimits = {}
}

-- Rate limit middleware for server events
function FL.RateLimitMiddleware(eventName, limit, window)
    limit = limit or 10
    window = window or 60000 -- 1 minute default

    return function(handler)
        return function(...)
            local now = GetGameTimer()
            local key = source .. '_' .. eventName
            local requests = FL.Security.rateLimits[key] or {}

            -- Clean old requests
            local cleanRequests = {}
            for _, timestamp in pairs(requests) do
                if now - timestamp <= window then
                    table.insert(cleanRequests, timestamp)
                end
            end

            if #cleanRequests >= limit then
                FL.Debug('⚠️ Rate limit exceeded for player ' .. source .. ' action: ' .. eventName)
                TriggerClientEvent('QBCore:Notify', source, 'Rate limit exceeded. Please wait before trying again.',
                    'error')
                return
            end

            -- Add current request
            table.insert(cleanRequests, now)
            FL.Security.rateLimits[key] = cleanRequests

            -- Call original handler
            handler(...)
        end
    end
end

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
-- DATABASE CONNECTION & HEALTH MONITORING
-- ====================================================================

-- Check if database is available and working
local function IsDatabaseAvailable()
    if not MySQL or not MySQL.query then
        return false
    end

    -- Simple test query with timeout
    local success = false
    local completed = false

    MySQL.query('SELECT 1 as test', {}, function(result)
        success = result and result[1] and result[1].test == 1
        completed = true
    end)

    -- Wait up to 2 seconds for response
    local attempts = 0
    while not completed and attempts < 20 do
        Wait(100)
        attempts = attempts + 1
    end

    return success and completed
end

-- Database health check and initialization
CreateThread(function()
    FL.Debug('🔄 Initializing FL Emergency Services Database...')

    local attempts = 0
    local maxAttempts = 20
    local waitTime = 1000

    -- Robust MySQL Connection with Retry-Logic
    while GetResourceState('oxmysql') ~= 'started' and attempts < maxAttempts do
        FL.Debug('⏳ Waiting for oxmysql... Attempt ' .. (attempts + 1) .. '/' .. maxAttempts)
        attempts = attempts + 1
        Wait(waitTime)

        -- Exponential backoff
        waitTime = math.min(waitTime * 1.5, 5000)
    end

    if attempts >= maxAttempts then
        FL.Debug('❌ CRITICAL: Failed to connect to MySQL after ' .. maxAttempts .. ' attempts!')
        FL.Debug('❌ Emergency Services will run in MEMORY-ONLY mode')
        FL.Server.DatabaseAvailable = false
        return
    end

    -- Ensure MySQL is properly loaded
    MySQL = MySQL or exports.oxmysql

    if not MySQL then
        FL.Debug('❌ CRITICAL: MySQL exports not available!')
        FL.Server.DatabaseAvailable = false
        return
    end

    Wait(2000) -- Additional safety wait

    -- Test database connection
    FL.Server.DatabaseAvailable = IsDatabaseAvailable()

    if FL.Server.DatabaseAvailable then
        FL.Debug('✅ Database connection test successful')
        InitializeDatabaseStructure()
    else
        FL.Debug('❌ Database connection test failed - running in memory-only mode')
    end
end)

-- Initialize database structure
function InitializeDatabaseStructure()
    FL.Debug('🔨 Initializing database structure...')

    -- Enhanced emergency calls table with multi-unit support
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
            `memory_only` tinyint(1) DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `call_id` (`call_id`),
            KEY `service_status` (`service`, `status`),
            KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]], {}, function(success)
        if success then
            FL.Debug('✅ Enhanced emergency calls table ready')
        else
            FL.Debug('❌ Failed to create emergency calls table')
            FL.Server.DatabaseAvailable = false
        end
    end)
end

-- Database health monitoring (every 5 minutes)
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes

        local wasAvailable = FL.Server.DatabaseAvailable
        FL.Server.DatabaseAvailable = IsDatabaseAvailable()

        if not wasAvailable and FL.Server.DatabaseAvailable then
            FL.Debug('✅ Database connection restored')
        elseif wasAvailable and not FL.Server.DatabaseAvailable then
            FL.Debug('⚠️ Database connection lost - switching to memory-only mode')
        elseif FL.Server.DatabaseAvailable then
            FL.Debug('✅ Database connection healthy')
        end
    end
end)

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

    local charinfo = Player.PlayerData.charinfo
    if charinfo and charinfo.firstname and charinfo.lastname then
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end

    return 'Unknown Player'
end

-- Get unit info for display (enhanced validation)
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

    local jobGrade = Player.PlayerData.job.grade
    local rankName = (jobGrade and jobGrade.name) and jobGrade.name or 'Unknown Rank'

    return {
        source = source,
        callsign = callsign,
        name = GetPlayerDisplayName(source),
        rank = rankName,
        isOnline = true
    }
end

-- ====================================================================
-- EMERGENCY CALLS SYSTEM (ENHANCED WITH DISCORD INTEGRATION)
-- ====================================================================

-- Create new emergency call with comprehensive error handling + DISCORD
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
        assigned_units = {},
        unit_details = {},
        created_at = os.time(),
        max_units = callData.max_units or 4,
        memory_only = not FL.Server.DatabaseAvailable
    }

    -- Store in memory FIRST (critical for fallback)
    FL.Server.EmergencyCalls[callId] = emergencyCall
    FL.Debug('📝 Call stored in memory: ' .. callId .. ' - Status: ' .. emergencyCall.status)

    -- 🔥 DISCORD LOG - NEW CALL
    CreateThread(function()
        Wait(500) -- Small delay to ensure FL.Discord is loaded
        if FL.Discord and FL.Discord.LogEmergencyCall then
            FL.Discord.LogEmergencyCall(emergencyCall, 'call_new')
            FL.Debug('📢 Discord: Logged new emergency call')
        else
            FL.Debug('⚠️ Discord logging not available for new call')
        end
    end)

    -- Store in database with comprehensive error handling
    if FL.Server.DatabaseAvailable and MySQL and MySQL.insert then
        MySQL.insert(
            'INSERT INTO fl_emergency_calls (call_id, service, call_type, coords_x, coords_y, coords_z, priority, description, max_units, memory_only) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {
                callId,
                emergencyCall.service,
                emergencyCall.type,
                emergencyCall.coords.x,
                emergencyCall.coords.y,
                emergencyCall.coords.z,
                emergencyCall.priority,
                emergencyCall.description,
                emergencyCall.max_units,
                0 -- Not memory only if successfully saved
            },
            function(insertId)
                if insertId and insertId > 0 then
                    FL.Debug('💾 Call saved to database with ID: ' .. tostring(insertId))
                    emergencyCall.db_id = insertId
                    emergencyCall.memory_only = false
                else
                    FL.Debug('❌ Failed to save call to database - insertId: ' .. tostring(insertId))
                    FL.Debug('⚠️ Call will remain in memory-only mode')
                    emergencyCall.memory_only = true
                end
            end
        )
    else
        FL.Debug('⚠️ Database not available - call stored in memory-only mode')
        emergencyCall.memory_only = true
    end

    -- Notify all on-duty units of the same service
    local notifiedCount = 0
    local Players = QBCore.Functions.GetPlayers()
    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job and Player.PlayerData.job.onduty then
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

-- Assign unit to emergency call (ENHANCED WITH DISCORD)
function AssignUnitToCall(callId, source)
    FL.Debug('🎯 AssignUnitToCall called - CallID: ' .. tostring(callId) .. ', Source: ' .. tostring(source))

    -- Validate input parameters
    if not callId or callId == '' then
        FL.Debug('❌ Invalid callId provided')
        return false, 'Invalid call ID'
    end

    if not source or source <= 0 then
        FL.Debug('❌ Invalid source provided')
        return false, 'Invalid player source'
    end

    local call = FL.Server.EmergencyCalls[callId]
    local serviceInfo = GetPlayerServiceInfo(source)

    -- Enhanced validation with detailed error messages
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

    -- Validate player permissions and state
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
    else
        FL.Debug('⚠️ Warning: Could not get unit info for source: ' .. source)
    end

    -- Update call status based on assignment count
    if #call.assigned_units == 1 then
        call.status = 'assigned'
    elseif #call.assigned_units > 1 then
        call.status = 'multi_assigned'
    end

    FL.Debug('🔄 Updated call status to: ' .. call.status .. ' - Assigned units: ' .. #call.assigned_units)
    FL.Debug('👥 Unit details: ' .. json.encode(call.unit_details))

    -- 🔥 DISCORD LOG - CALL ASSIGNED
    CreateThread(function()
        Wait(200) -- Small delay
        if FL.Discord and FL.Discord.LogEmergencyCall then
            FL.Discord.LogEmergencyCall(call, 'call_assigned')
            FL.Debug('📢 Discord: Logged call assignment')
        else
            FL.Debug('⚠️ Discord logging not available for call assignment')
        end
    end)

    -- Update database with enhanced error handling
    if FL.Server.DatabaseAvailable and MySQL and MySQL.update and not call.memory_only then
        MySQL.update('UPDATE fl_emergency_calls SET status = ?, assigned_units = ? WHERE call_id = ?', {
            call.status,
            json.encode(call.assigned_units),
            callId
        }, function(affectedRows)
            if affectedRows and affectedRows > 0 then
                FL.Debug('💾 Database updated - Affected rows: ' .. tostring(affectedRows))
            else
                FL.Debug('⚠️ Database update failed or no rows affected - affectedRows: ' .. tostring(affectedRows))
                FL.Debug('📝 Call marked as memory-only')
                call.memory_only = true
            end
        end)
    else
        if call.memory_only then
            FL.Debug('📝 Skipping database update - call is in memory-only mode')
        else
            FL.Debug('⚠️ Database not available for update')
        end
    end

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
        if Player and Player.PlayerData.job and Player.PlayerData.job.onduty then
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

-- Start working on call (enhanced with validation)
function StartWorkingOnCall(callId, source)
    FL.Debug('🚀 StartWorkingOnCall called - CallID: ' .. tostring(callId) .. ', Source: ' .. tostring(source))

    -- Validate input parameters
    if not callId or callId == '' then
        FL.Debug('❌ Invalid callId provided')
        return false, 'Invalid call ID'
    end

    if not source or source <= 0 then
        FL.Debug('❌ Invalid source provided')
        return false, 'Invalid player source'
    end

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

    -- Update database with error handling
    if FL.Server.DatabaseAvailable and MySQL and MySQL.update and not call.memory_only then
        MySQL.update('UPDATE fl_emergency_calls SET status = ?, started_at = FROM_UNIXTIME(?) WHERE call_id = ?', {
            'in_progress',
            call.started_at,
            callId
        }, function(affectedRows)
            if affectedRows and affectedRows > 0 then
                FL.Debug('💾 Database updated for start work - Affected rows: ' .. tostring(affectedRows))
            else
                FL.Debug('⚠️ Database update failed for start work')
                call.memory_only = true
            end
        end)
    end

    -- Notify all assigned units
    for _, assignedSource in pairs(call.assigned_units) do
        TriggerClientEvent('fl_core:callStatusUpdate', assignedSource, callId, call)
        TriggerClientEvent('QBCore:Notify', assignedSource, 'Call ' .. callId .. ' is now in progress', 'info')
    end

    FL.Debug('✅ Call ' .. callId .. ' started successfully')
    return true, 'Call started successfully'
end

-- Complete emergency call (ENHANCED WITH DISCORD)
function CompleteEmergencyCall(callId, source)
    FL.Debug('✅ CompleteEmergencyCall called - CallID: ' .. tostring(callId) .. ', Source: ' .. tostring(source))

    -- Validate input parameters
    if not callId or callId == '' then
        FL.Debug('❌ Invalid callId provided')
        return false, 'Invalid call ID'
    end

    if not source or source <= 0 then
        FL.Debug('❌ Invalid source provided')
        return false, 'Invalid player source'
    end

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
    elseif call.created_at then
        call.response_time = call.completed_at - call.created_at
    end

    -- 🔥 DISCORD LOG - CALL COMPLETED
    CreateThread(function()
        Wait(200) -- Small delay
        if FL.Discord and FL.Discord.LogEmergencyCall then
            FL.Discord.LogEmergencyCall(call, 'call_completed')
            FL.Debug('📢 Discord: Logged call completion')
        else
            FL.Debug('⚠️ Discord logging not available for call completion')
        end
    end)

    -- Update database with comprehensive error handling
    if FL.Server.DatabaseAvailable and MySQL and MySQL.update and not call.memory_only then
        MySQL.update(
            'UPDATE fl_emergency_calls SET status = ?, completed_at = FROM_UNIXTIME(?), response_time = ?, completed_by = ? WHERE call_id = ?',
            {
                'completed',
                call.completed_at,
                call.response_time or 0,
                source,
                callId
            }, function(affectedRows)
                if affectedRows and affectedRows > 0 then
                    FL.Debug('💾 Database updated for completion - Affected rows: ' .. tostring(affectedRows))
                else
                    FL.Debug('⚠️ Database update failed for completion')
                end
            end)
    end

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

    -- Store completed call for a while before removing (for statistics)
    CreateThread(function()
        Wait(300000) -- Keep completed calls for 5 minutes
        if FL.Server.EmergencyCalls[callId] and FL.Server.EmergencyCalls[callId].status == 'completed' then
            FL.Server.EmergencyCalls[callId] = nil
            FL.Debug('🧹 Removed completed call from memory: ' .. callId)
        end
    end)

    FL.Debug('✅ Call ' .. callId .. ' completed successfully')
    return true, 'Completion successful'
end

-- ====================================================================
-- JOB-BASED FUNCTIONS (ENHANCED WITH VALIDATION)
-- ====================================================================

-- Check if player has emergency service job
function IsPlayerEmergencyService(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for source: ' .. tostring(source))
        return false, nil
    end

    local jobData = Player.PlayerData.job
    if not jobData or not jobData.name then
        FL.Debug('❌ No job data for player: ' .. tostring(source))
        return false, nil
    end

    local jobName = jobData.name
    local service = FL.JobMapping[jobName]

    FL.Debug('🔍 Player job check - Job: ' .. tostring(jobName) .. ', Service: ' .. tostring(service))
    return service ~= nil, service
end

-- Get player's emergency service info (enhanced validation)
function GetPlayerServiceInfo(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for service info: ' .. tostring(source))
        return nil
    end

    local jobData = Player.PlayerData.job
    if not jobData or not jobData.name then
        FL.Debug('❌ No job data for service info: ' .. tostring(source))
        return nil
    end

    local jobName = jobData.name
    local service = FL.JobMapping[jobName]

    if not service then
        FL.Debug('❌ No emergency service job for: ' .. tostring(jobName))
        return nil
    end

    local gradeData = jobData.grade or {}
    local serviceInfo = {
        service = service,
        rank = gradeData.level or 0,
        rankName = gradeData.name or 'Unknown',
        isOnDuty = jobData.onduty or false,
        citizenid = Player.PlayerData.citizenid
    }

    FL.Debug('✅ Service info retrieved: ' .. json.encode(serviceInfo))
    return serviceInfo
end

-- ====================================================================
-- SERVER EVENTS (MIT KORREKTEM RATE LIMITING)
-- ====================================================================

-- Enhanced server event for assignment with rate limiting
RegisterServerEvent('fl_core:assignToCallFromUI', FL.RateLimitMiddleware('assignToCall', 5, 30000)(function(callId)
    FL.Debug('📱 Server Event: assignToCallFromUI - CallID: ' .. tostring(callId))

    if not callId or callId == '' then
        FL.Debug('❌ No callId provided in server event')
        TriggerClientEvent('fl_core:assignmentResult', source, {
            success = false,
            message = 'Invalid call ID provided',
            callId = callId
        })
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
end))

-- Enhanced server event for starting work on call
RegisterServerEvent('fl_core:startWorkOnCallFromUI', FL.RateLimitMiddleware('startWork', 5, 30000)(function(callId)
    FL.Debug('📱 Server Event: startWorkOnCallFromUI - CallID: ' .. tostring(callId))

    if not callId or callId == '' then
        FL.Debug('❌ No callId provided in server event')
        TriggerClientEvent('fl_core:startWorkResult', source, {
            success = false,
            message = 'Invalid call ID provided',
            callId = callId
        })
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
end))

-- Enhanced server event for completion
RegisterServerEvent('fl_core:completeCallFromUI', FL.RateLimitMiddleware('completeCall', 3, 60000)(function(callId)
    FL.Debug('📱 Server Event: completeCallFromUI - CallID: ' .. tostring(callId))

    if not callId or callId == '' then
        FL.Debug('❌ No callId provided in server event')
        TriggerClientEvent('fl_core:completionResult', source, {
            success = false,
            message = 'Invalid call ID provided',
            callId = callId
        })
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
end))

-- ====================================================================
-- REGULAR EVENT HANDLERS
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

-- Get all active calls for player's service (enhanced with cleanup)
RegisterServerEvent('fl_core:getActiveCalls', function()
    FL.Debug('📞 getActiveCalls requested by source: ' .. tostring(source))

    local serviceInfo = GetPlayerServiceInfo(source)
    if not serviceInfo then
        FL.Debug('❌ No service info for getActiveCalls')
        TriggerClientEvent('fl_core:activeCalls', source, {})
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
-- DUTY MANAGEMENT (ENHANCED WITH DISCORD + CALLSIGN GENERATION)
-- ====================================================================

-- Handle duty toggle (integrates with QBCore duty system + DISCORD)
function HandleDutyToggle(source, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for duty toggle: ' .. tostring(source))
        return false
    end

    local isEmergency, service = IsPlayerEmergencyService(source)
    if not isEmergency then
        TriggerClientEvent('QBCore:Notify', source, 'You are not employed by an emergency service', 'error')
        return false
    end

    local jobData = Player.PlayerData.job
    local currentDuty = jobData and jobData.onduty or false

    if currentDuty then
        -- End duty
        Player.Functions.SetJobDuty(false)
        FL.Server.ActiveStations[source] = nil
        FL.Server.UnitCallsigns[source] = nil -- Clear callsign

        TriggerClientEvent('QBCore:Notify', source, 'You are now off duty', 'success')
        TriggerClientEvent('fl_core:dutyChanged', source, false, service, 0)

        -- 🔥 DISCORD LOG - DUTY END
        CreateThread(function()
            Wait(500) -- Small delay to ensure FL.Discord is loaded
            if FL.Discord and FL.Discord.LogDutyChange then
                FL.Discord.LogDutyChange(source, service, false, stationId)
                FL.Debug('📢 Discord: Logged duty end for ' .. service)
            else
                FL.Debug('⚠️ Discord logging not available for duty end')
            end
        end)

        FL.Debug(Player.PlayerData.citizenid .. ' ended duty for ' .. service)
    else
        -- Start duty
        Player.Functions.SetJobDuty(true)
        FL.Server.ActiveStations[source] = stationId

        -- Generate callsign
        local callsign = GenerateCallsign(service, source)
        FL.Server.UnitCallsigns[source] = callsign

        TriggerClientEvent('QBCore:Notify', source, 'You are now on duty as Unit ' .. callsign, 'success')

        local gradeLevel = (jobData.grade and jobData.grade.level) and jobData.grade.level or 0
        TriggerClientEvent('fl_core:dutyChanged', source, true, service, gradeLevel)

        -- 🔥 DISCORD LOG - DUTY START
        CreateThread(function()
            Wait(500) -- Small delay to ensure FL.Discord is loaded
            if FL.Discord and FL.Discord.LogDutyChange then
                FL.Discord.LogDutyChange(source, service, true, stationId)
                FL.Debug('📢 Discord: Logged duty start for ' .. service)
            else
                FL.Debug('⚠️ Discord logging not available for duty start')
            end
        end)

        FL.Debug(Player.PlayerData.citizenid ..
            ' started duty for ' .. service .. ' as Unit ' .. callsign .. ' at ' .. (stationId or 'unknown'))
    end

    return true
end

-- ====================================================================
-- EQUIPMENT MANAGEMENT (QBCORE 1.3.0 COMPATIBLE)
-- ====================================================================

-- Give equipment to player (enhanced validation)
RegisterServerEvent('fl_core:giveEquipment', function(serviceName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for equipment: ' .. tostring(source))
        return
    end

    if not serviceName or serviceName == '' then
        FL.Debug('❌ Invalid service name for equipment')
        return
    end

    local equipment = FL.Functions.GetServiceEquipment(serviceName)
    if not equipment or #equipment == 0 then
        FL.Debug('❌ No equipment found for ' .. serviceName)
        return
    end

    -- Give radio first
    if QBCore.Shared.Items['radio'] then
        Player.Functions.AddItem('radio', 1)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['radio'], 'add')
    end

    -- Give service-specific equipment
    local givenCount = 0
    for _, item in pairs(equipment) do
        if QBCore.Shared.Items[item] then
            Player.Functions.AddItem(item, 1)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add')
            givenCount = givenCount + 1
        else
            FL.Debug('⚠️ Item not found in QBCore.Shared.Items: ' .. item)
        end
    end

    FL.Debug('✅ Given ' .. givenCount .. ' equipment items for ' .. serviceName .. ' to ' .. Player.PlayerData.citizenid)
end)

-- Remove equipment from player (enhanced validation)
RegisterServerEvent('fl_core:removeEquipment', function(serviceName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for equipment removal: ' .. tostring(source))
        return
    end

    if not serviceName or serviceName == '' then
        FL.Debug('❌ Invalid service name for equipment removal')
        return
    end

    local equipment = FL.Functions.GetServiceEquipment(serviceName)
    if not equipment or #equipment == 0 then
        FL.Debug('❌ No equipment found for removal: ' .. serviceName)
        return
    end

    -- Remove radio
    local radioItem = Player.Functions.GetItemByName('radio')
    if radioItem then
        Player.Functions.RemoveItem('radio', radioItem.amount or 1)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['radio'], 'remove')
    end

    -- Remove service-specific equipment
    local removedCount = 0
    for _, item in pairs(equipment) do
        local playerItem = Player.Functions.GetItemByName(item)
        if playerItem then
            Player.Functions.RemoveItem(item, playerItem.amount)
            if QBCore.Shared.Items[item] then
                TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove')
            end
            removedCount = removedCount + 1
        end
    end

    FL.Debug('✅ Removed ' ..
        removedCount .. ' equipment items for ' .. serviceName .. ' from ' .. Player.PlayerData.citizenid)
end)

-- ====================================================================
-- ENHANCED ADMIN COMMANDS
-- ====================================================================

-- Create test emergency call with custom max units (enhanced)
RegisterCommand('testcall', function(source, args, rawCommand)
    FL.Debug('🧪 testcall command executed by source: ' .. tostring(source))

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for testcall command')
        return
    end

    -- Enhanced permission check
    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')
    local serviceInfo = GetPlayerServiceInfo(source)

    if not hasPermission and not (serviceInfo and serviceInfo.isOnDuty) then
        TriggerClientEvent('QBCore:Notify', source, 'You need to be an admin or on duty to create test calls', 'error')
        return
    end

    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /testcall [fire/police/ems] [max_units] [priority]', 'error')
        return
    end

    local service = args[1]
    local maxUnits = tonumber(args[2]) or 4
    local priority = tonumber(args[3]) or 2

    if not FL.Functions.ValidateService(service) then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid service. Use: fire, police, or ems', 'error')
        return
    end

    -- Validate parameters
    if maxUnits < 1 or maxUnits > 10 then
        TriggerClientEvent('QBCore:Notify', source, 'Max units must be between 1 and 10', 'error')
        return
    end

    if priority < 1 or priority > 3 then
        TriggerClientEvent('QBCore:Notify', source, 'Priority must be between 1 (high) and 3 (low)', 'error')
        return
    end

    -- Get player coordinates for call location
    local playerPed = GetPlayerPed(source)
    if not playerPed or playerPed <= 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Could not get player location', 'error')
        return
    end

    local playerCoords = GetEntityCoords(playerPed)

    -- Create call data
    local callData = FL.Functions.GenerateEmergencyCall(service)
    if callData then
        callData.coords = vector3(playerCoords.x, playerCoords.y, playerCoords.z)
        callData.max_units = maxUnits
        callData.priority = priority

        local callId = CreateEmergencyCall(callData)
        if callId then
            TriggerClientEvent('QBCore:Notify', source,
                'Created emergency call: ' .. callId .. ' (Max Units: ' .. maxUnits .. ', Priority: ' .. priority .. ')',
                'success')
            FL.Debug('🚨 Test call created: ' ..
                callId ..
                ' for ' ..
                service ..
                ' with max units: ' .. maxUnits .. ' priority: ' .. priority .. ' by ' .. Player.PlayerData.citizenid)
        else
            TriggerClientEvent('QBCore:Notify', source, 'Failed to create emergency call', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'Failed to generate call data', 'error')
    end
end, false)

-- Enhanced debug command to check server calls
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
    local memoryOnlyCount = 0
    TriggerClientEvent('QBCore:Notify', source, 'Check server console for detailed call info', 'info')

    print('^3[FL SERVER CALLS DEBUG]^7 ======================')
    print('^3[FL SERVER DEBUG]^7 Database Available: ' .. tostring(FL.Server.DatabaseAvailable))

    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        count = count + 1
        if callData.memory_only then
            memoryOnlyCount = memoryOnlyCount + 1
        end

        print('^3[FL SERVER CALLS]^7 Call ID: ' .. callId)
        print('^3[FL SERVER CALLS]^7 Service: ' .. callData.service)
        print('^3[FL SERVER CALLS]^7 Type: ' .. callData.type)
        print('^3[FL SERVER CALLS]^7 Status: ' .. callData.status)
        print('^3[FL SERVER CALLS]^7 Priority: ' .. callData.priority)
        print('^3[FL SERVER CALLS]^7 Max Units: ' .. callData.max_units)
        print('^3[FL SERVER CALLS]^7 Memory Only: ' .. tostring(callData.memory_only or false))
        print('^3[FL SERVER CALLS]^7 Assigned Units: ' .. json.encode(callData.assigned_units or {}))
        print('^3[FL SERVER CALLS]^7 Unit Details Count: ' .. #(callData.unit_details or {}))
        print('^3[FL SERVER CALLS]^7 Coords: ' ..
            callData.coords.x .. ', ' .. callData.coords.y .. ', ' .. callData.coords.z)
        print('^3[FL SERVER CALLS]^7 ---')
    end

    print('^3[FL SERVER CALLS DEBUG]^7 Total active calls: ' .. count)
    print('^3[FL SERVER CALLS DEBUG]^7 Memory-only calls: ' .. memoryOnlyCount)
    print('^3[FL SERVER CALLS DEBUG]^7 ======================')

    TriggerClientEvent('QBCore:Notify', source,
        'Found ' .. count .. ' active calls (' .. memoryOnlyCount .. ' memory-only)', 'success')
end, false)

-- ====================================================================
-- DISCORD WEBHOOK TEST COMMANDS
-- ====================================================================

-- Discord webhook test command
RegisterCommand('testwebhooks', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    TriggerClientEvent('QBCore:Notify', source, 'Testing Discord webhooks - check console and Discord', 'info')

    print('^3[FL WEBHOOK TEST]^7 Starting Discord webhook tests...')

    -- Test Discord configuration
    if not FL.Discord then
        print('^1[FL WEBHOOK TEST]^7 ❌ FL.Discord not available')
        return
    end

    if not FL.Discord.enabled then
        print('^1[FL WEBHOOK TEST]^7 ❌ Discord integration disabled')
        return
    end

    -- Check webhook URLs
    print('^3[FL WEBHOOK TEST]^7 Webhook Configuration:')
    for service, url in pairs(FL.Discord.webhooks) do
        local status = (url and url ~= '') and '✅ SET' or '❌ MISSING'
        print('^6[FL WEBHOOK TEST]^7 ' .. string.upper(service) .. ': ' .. status)
        if url and url ~= '' then
            print('^6[FL WEBHOOK TEST]^7 URL: ' .. string.sub(url, 1, 50) .. '...')
        end
    end

    -- Test each webhook with a message
    local testServices = { 'fire', 'police', 'ems', 'admin', 'duty', 'emergency' }

    for _, service in pairs(testServices) do
        if FL.Discord.webhooks[service] and FL.Discord.webhooks[service] ~= '' then
            print('^2[FL WEBHOOK TEST]^7 Testing ' .. service .. ' webhook...')

            local embed = FL.Discord.CreateEmbed(
                '🧪 WEBHOOK TEST - ' .. string.upper(service),
                'This is a test message for the ' .. service .. ' webhook.',
                FL.Discord.colors[service] or FL.Discord.colors.info,
                {
                    {
                        name = '📋 Test Information',
                        value = '**Service:** ' .. string.upper(service) .. '\n' ..
                            '**Time:** <t:' .. os.time() .. ':F>\n' ..
                            '**Tester:** ' ..
                            (Player.PlayerData.charinfo.firstname or 'Unknown') ..
                            ' ' .. (Player.PlayerData.charinfo.lastname or 'Player'),
                        inline = false
                    }
                }
            )

            if FL.Discord.SendWebhook then
                FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed, nil, 'high')
            else
                print('^1[FL WEBHOOK TEST]^7 ❌ FL.Discord.SendWebhook function not available')
            end
        else
            print('^1[FL WEBHOOK TEST]^7 ❌ No webhook URL for: ' .. service)
        end

        Wait(1000) -- Wait 1 second between tests to avoid rate limiting
    end

    print('^3[FL WEBHOOK TEST]^7 Webhook tests completed!')
end, false)

-- Test Discord for duty changes
RegisterCommand('testduty', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    local testService = args[1] or 'fire'

    if not FL.Functions.ValidateService(testService) then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid service. Use: fire, police, or ems', 'error')
        return
    end

    TriggerClientEvent('QBCore:Notify', source, 'Testing duty change Discord log for ' .. testService, 'info')

    -- Test duty start
    if FL.Discord and FL.Discord.LogDutyChange then
        FL.Discord.LogDutyChange(source, testService, true, 'test_station')
        print('^2[FL DUTY TEST]^7 Sent duty START test for ' .. testService)

        -- Test duty end after 5 seconds
        CreateThread(function()
            Wait(5000)
            FL.Discord.LogDutyChange(source, testService, false, 'test_station')
            print('^2[FL DUTY TEST]^7 Sent duty END test for ' .. testService)
        end)
    else
        print('^1[FL DUTY TEST]^7 ❌ FL.Discord.LogDutyChange not available')
    end
end, false)

-- Test Discord for emergency calls
RegisterCommand('testcalldiscord', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    local testService = args[1] or 'fire'

    if not FL.Functions.ValidateService(testService) then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid service. Use: fire, police, or ems', 'error')
        return
    end

    -- Create test call data
    local testCall = {
        id = 'FLTEST' .. os.time(),
        service = testService,
        type = 'test_emergency',
        coords = { x = 0, y = 0, z = 0 },
        priority = 1,
        description = 'This is a test emergency call for Discord webhook testing',
        status = 'pending',
        assigned_units = {},
        unit_details = {},
        created_at = os.time(),
        max_units = 4
    }

    TriggerClientEvent('QBCore:Notify', source, 'Testing emergency call Discord logs for ' .. testService, 'info')

    if FL.Discord and FL.Discord.LogEmergencyCall then
        -- Test new call
        FL.Discord.LogEmergencyCall(testCall, 'call_new')
        print('^2[FL CALL TEST]^7 Sent NEW CALL test for ' .. testService)

        -- Test assigned call after 3 seconds
        CreateThread(function()
            Wait(3000)
            testCall.status = 'assigned'
            testCall.assigned_units = { source }
            testCall.unit_details = { {
                source = source,
                callsign = 'TEST01',
                name = (Player.PlayerData.charinfo.firstname or 'Test') ..
                ' ' .. (Player.PlayerData.charinfo.lastname or 'Officer'),
                rank = 'Test Rank'
            } }
            FL.Discord.LogEmergencyCall(testCall, 'call_assigned')
            print('^2[FL CALL TEST]^7 Sent ASSIGNED CALL test for ' .. testService)

            -- Test completed call after 3 more seconds
            Wait(3000)
            testCall.status = 'completed'
            testCall.completed_at = os.time()
            testCall.response_time = 120 -- 2 minutes
            FL.Discord.LogEmergencyCall(testCall, 'call_completed')
            print('^2[FL CALL TEST]^7 Sent COMPLETED CALL test for ' .. testService)
        end)
    else
        print('^1[FL CALL TEST]^7 ❌ FL.Discord.LogEmergencyCall not available')
    end
end, false)

-- ====================================================================
-- RATE LIMIT CLEANUP THREAD
-- ====================================================================

CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes

        -- Clean old rate limit data
        local now = GetGameTimer()
        local cleaned = 0

        for key, requests in pairs(FL.Security.rateLimits) do
            local cleanRequests = {}
            for _, timestamp in pairs(requests) do
                if now - timestamp <= 300000 then -- Keep 5 minutes of data
                    table.insert(cleanRequests, timestamp)
                end
            end

            if #cleanRequests == 0 then
                FL.Security.rateLimits[key] = nil
                cleaned = cleaned + 1
            else
                FL.Security.rateLimits[key] = cleanRequests
            end
        end

        if cleaned > 0 then
            FL.Debug('🧹 Cleaned ' .. cleaned .. ' old rate limit entries')
        end
    end
end)

-- ====================================================================
-- PERFORMANCE MONITORING & CLEANUP
-- ====================================================================

CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes

        local activeCalls = FL.Functions.TableSize(FL.Server.EmergencyCalls)
        local activeStations = FL.Functions.TableSize(FL.Server.ActiveStations)
        local memoryUsage = collectgarbage('count')

        FL.Debug('📊 FL Performance Stats:')
        FL.Debug('📞 Active Calls: ' .. activeCalls)
        FL.Debug('🏢 Active Stations: ' .. activeStations)
        FL.Debug('📻 Active Callsigns: ' .. FL.Functions.TableSize(FL.Server.UnitCallsigns))
        FL.Debug('🗄️ Database Available: ' .. tostring(FL.Server.DatabaseAvailable))
        FL.Debug('💾 Memory Usage: ' .. string.format('%.2f', memoryUsage) .. ' KB')

        -- Cleanup old completed calls (older than 1 hour)
        local cutoffTime = os.time() - 3600
        local cleanedCount = 0

        for callId, callData in pairs(FL.Server.EmergencyCalls) do
            if callData.status == 'completed' and callData.completed_at and callData.completed_at < cutoffTime then
                FL.Server.EmergencyCalls[callId] = nil
                cleanedCount = cleanedCount + 1
            end
        end

        if cleanedCount > 0 then
            FL.Debug('🧹 Cleaned up ' .. cleanedCount .. ' old completed calls')
        end

        -- Force garbage collection if memory usage is high
        if memoryUsage > 50000 then -- 50MB
            collectgarbage('collect')
            FL.Debug('🧹 Garbage collection performed (was ' .. string.format('%.2f', memoryUsage) .. ' KB)')
        end
    end
end)

-- ====================================================================
-- CLEANUP ON PLAYER DISCONNECT (ENHANCED)
-- ====================================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    FL.Debug('🚪 Player ' .. source .. ' disconnected: ' .. (reason or 'unknown'))

    -- Clean up station tracking
    if FL.Server.ActiveStations[source] then
        FL.Server.ActiveStations[source] = nil
    end

    -- Clean up callsign
    if FL.Server.UnitCallsigns[source] then
        FL.Server.UnitCallsigns[source] = nil
    end

    -- Remove from any assigned calls and update unit details
    local cleanedCalls = 0
    for callId, callData in pairs(FL.Server.EmergencyCalls) do
        local originalUnitCount = #callData.assigned_units

        -- Remove from assigned units
        for i = #callData.assigned_units, 1, -1 do
            if callData.assigned_units[i] == source then
                table.remove(callData.assigned_units, i)
                FL.Debug('🚪 Removed disconnected player ' .. source .. ' from call ' .. callId)
                break
            end
        end

        -- Remove from unit details
        for i = #callData.unit_details, 1, -1 do
            if callData.unit_details[i].source == source then
                table.remove(callData.unit_details, i)
                FL.Debug('🚪 Removed unit detail for player ' .. source .. ' from call ' .. callId)
                break
            end
        end

        -- Update call status if units were removed
        if originalUnitCount ~= #callData.assigned_units then
            cleanedCalls = cleanedCalls + 1

            if #callData.assigned_units == 0 then
                callData.status = 'pending'
                FL.Debug('🔄 Call ' .. callId .. ' reset to pending - no units assigned')
            elseif #callData.assigned_units == 1 then
                callData.status = 'assigned'
                FL.Debug('🔄 Call ' .. callId .. ' status changed to assigned - 1 unit remaining')
            else
                callData.status = 'multi_assigned'
                FL.Debug('🔄 Call ' ..
                    callId .. ' status remains multi_assigned - ' .. #callData.assigned_units .. ' units remaining')
            end

            -- Update database if available
            if FL.Server.DatabaseAvailable and MySQL and MySQL.update and not callData.memory_only then
                MySQL.update('UPDATE fl_emergency_calls SET status = ?, assigned_units = ? WHERE call_id = ?', {
                    callData.status,
                    json.encode(callData.assigned_units),
                    callId
                })
            end
        end
    end

    if cleanedCalls > 0 then
        FL.Debug('🧹 Cleaned up ' .. cleanedCalls .. ' calls after player ' .. source .. ' disconnect')
    end
end)

-- ====================================================================
-- HELPER FUNCTIONS FOR DISCORD (REFERENCED IN DISCORD.LUA)
-- ====================================================================

function GetOnDutyCount(service)
    local count = 0
    local Players = QBCore.Functions.GetPlayers()

    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job and Player.PlayerData.job.onduty then
            local playerService = FL.JobMapping[Player.PlayerData.job.name]
            if playerService == service then
                count = count + 1
            end
        end
    end

    return count
end

function GetActiveCallsCount(service)
    local count = 0
    if FL.Server and FL.Server.EmergencyCalls then
        for _, callData in pairs(FL.Server.EmergencyCalls) do
            if callData.service == service and callData.status ~= 'completed' then
                count = count + 1
            end
        end
    end
    return count
end

FL.Debug('🎉 FL Core server loaded with COMPLETE DISCORD INTEGRATION & RATE LIMITING FIXES')

-- ====================================================================
-- DEBUG COMMANDS LOADED NOTIFICATION
-- ====================================================================

FL.Debug('🧪 Available Commands:')
FL.Debug('📋 /testcall [service] [max_units] [priority] - Create test emergency call')
FL.Debug('📊 /servercalls - Show server call debug info')
FL.Debug('🔗 /testwebhooks - Test all Discord webhooks')
FL.Debug('👮 /testduty [service] - Test duty change Discord logs')
FL.Debug('🚨 /testcalldiscord [service] - Test emergency call Discord logs')
FL.Debug('📈 /flstatus - System status')
FL.Debug('🗄️ /dbstatus - Database status')
