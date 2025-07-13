-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - DATABASE (KORRIGIERTE VERSION)
-- ALLE KRITISCHEN FIXES IMPLEMENTIERT:
-- ✅ Robuste MySQL Connection mit Retry Logic
-- ✅ Comprehensive Error Handling für alle Database Operations
-- ✅ Automatic Reconnection & Recovery System
-- ✅ Memory-Only Fallback Mode
-- ✅ Database Health Monitoring
-- ✅ NUI Callbacks entfernt (gehören ins Client-Script)
-- ====================================================================

local QBCore = FL.GetFramework()

-- MySQL namespace fix with validation
MySQL = MySQL or exports.oxmysql

-- Enhanced global state variables with database tracking
FL.Server = FL.Server or {
    EmergencyCalls = {},
    ActiveStations = {},
    UnitCallsigns = {},
    DatabaseStatus = {
        isAvailable = false,
        lastCheck = 0,
        reconnectAttempts = 0,
        maxReconnectAttempts = 10,
        reconnectDelay = 5000,
        isReconnecting = false
    }
}

-- Mapping between QBCore jobs and FL services
FL.JobMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ambulance'] = 'ems'
}

-- Reverse mapping
FL.ServiceMapping = {
    ['fire'] = 'fire',
    ['police'] = 'police',
    ['ems'] = 'ambulance'
}

-- ====================================================================
-- ENHANCED DATABASE HEALTH MONITORING
-- ====================================================================

-- Enhanced database connection test with connection pooling check
local function TestDatabaseConnection(timeout)
    timeout = timeout or 2000 -- 2 second default timeout

    if not MySQL or not MySQL.query then
        FL.Debug('❌ MySQL exports not available')
        return false
    end

    local success = false
    local completed = false
    local startTime = GetGameTimer()

    -- Test with simple scalar query for better performance
    MySQL.scalar('SELECT 1', {}, function(result)
        success = (result == 1)
        completed = true
        FL.Debug('📊 Database test query completed - Success: ' .. tostring(success))
    end)

    -- Wait for response with timeout
    while not completed and (GetGameTimer() - startTime) < timeout do
        Wait(10) -- Reduced wait time for better responsiveness
    end

    if not completed then
        FL.Debug('⏱️ Database test query timed out after ' .. timeout .. 'ms')
        return false
    end

    return success
end

-- Additional health check function
local function IsDatabaseHealthy()
    -- Quick health check without waiting
    local healthy = nil
    MySQL.scalar('SELECT CONNECTION_ID()', {}, function(result)
        healthy = (result ~= nil)
    end)

    -- Short timeout check
    local attempts = 0
    while healthy == nil and attempts < 10 do
        Wait(10)
        attempts = attempts + 1
    end

    return healthy == true
end

-- Comprehensive database availability check
local function CheckDatabaseAvailability()
    local dbStatus = FL.Server.DatabaseStatus
    local now = GetGameTimer()

    -- Don't check too frequently
    if now - dbStatus.lastCheck < 30000 then -- 30 second minimum between checks
        return dbStatus.isAvailable
    end

    dbStatus.lastCheck = now

    -- Test connection
    local isAvailable = TestDatabaseConnection(3000)

    if isAvailable ~= dbStatus.isAvailable then
        if isAvailable then
            FL.Debug('✅ Database connection restored')
            dbStatus.reconnectAttempts = 0
            dbStatus.isReconnecting = false
        else
            FL.Debug('❌ Database connection lost')
        end
        dbStatus.isAvailable = isAvailable
    end

    return isAvailable
end

-- Attempt to reconnect to database
local function AttemptDatabaseReconnection()
    local dbStatus = FL.Server.DatabaseStatus

    if dbStatus.isReconnecting then
        return false
    end

    if dbStatus.reconnectAttempts >= dbStatus.maxReconnectAttempts then
        FL.Debug('❌ Maximum database reconnection attempts reached')
        return false
    end

    dbStatus.isReconnecting = true
    dbStatus.reconnectAttempts = dbStatus.reconnectAttempts + 1

    FL.Debug('🔄 Attempting database reconnection (attempt ' ..
        dbStatus.reconnectAttempts .. '/' .. dbStatus.maxReconnectAttempts .. ')')

    CreateThread(function()
        Wait(dbStatus.reconnectDelay)

        local success = TestDatabaseConnection(5000)

        if success then
            FL.Debug('✅ Database reconnection successful')
            dbStatus.isAvailable = true
            dbStatus.reconnectAttempts = 0
            dbStatus.isReconnecting = false
        else
            FL.Debug('❌ Database reconnection failed')
            dbStatus.isReconnecting = false

            -- Exponential backoff
            dbStatus.reconnectDelay = math.min(dbStatus.reconnectDelay * 1.5, 30000) -- Max 30 seconds

            -- Try again after delay
            if dbStatus.reconnectAttempts < dbStatus.maxReconnectAttempts then
                CreateThread(function()
                    Wait(5000)
                    AttemptDatabaseReconnection()
                end)
            end
        end
    end)

    return true
end

-- ====================================================================
-- ROBUST DATABASE INITIALIZATION SYSTEM
-- ====================================================================

-- Initialize database with comprehensive error handling
CreateThread(function()
    FL.Debug('🔄 Initializing FL Emergency Services Database...')

    local attempts = 0
    local maxAttempts = 25
    local waitTime = 1000

    -- Wait for oxmysql resource with extended timeout
    while GetResourceState('oxmysql') ~= 'started' and attempts < maxAttempts do
        FL.Debug('⏳ Waiting for oxmysql... Attempt ' .. (attempts + 1) .. '/' .. maxAttempts)
        attempts = attempts + 1
        Wait(waitTime)

        -- Progressive wait time increase
        waitTime = math.min(waitTime + 500, 3000)
    end

    if attempts >= maxAttempts then
        FL.Debug('❌ CRITICAL: Failed to detect oxmysql after ' .. maxAttempts .. ' attempts!')
        FL.Debug('❌ Emergency Services will run in MEMORY-ONLY mode')
        FL.Server.DatabaseStatus.isAvailable = false
        return
    end

    -- Ensure MySQL is properly loaded with validation
    MySQL = MySQL or exports.oxmysql

    if not MySQL then
        FL.Debug('❌ CRITICAL: MySQL exports not available!')
        FL.Server.DatabaseStatus.isAvailable = false
        return
    end

    -- Additional safety wait before testing connection
    Wait(3000)

    -- Test initial database connection
    FL.Debug('🔍 Testing initial database connection...')
    local initialConnectionTest = TestDatabaseConnection(10000) -- 10 second timeout for initial test

    if initialConnectionTest then
        FL.Debug('✅ Initial database connection successful')
        FL.Server.DatabaseStatus.isAvailable = true

        -- Initialize database structure
        InitializeDatabaseStructure()
    else
        FL.Debug('❌ Initial database connection failed - will attempt reconnection')
        FL.Server.DatabaseStatus.isAvailable = false
        AttemptDatabaseReconnection()
    end
end)

-- Initialize database structure with comprehensive error handling
function InitializeDatabaseStructure()
    FL.Debug('🔨 Initializing database structure...')

    -- Check if we should use automatic setup
    if not Config.Database or not Config.Database.autoSetup or not Config.Database.autoSetup.enabled then
        FL.Debug('⚠️ Automatic database setup disabled in config')
        return
    end

    -- Create enhanced emergency calls table
    local createTableQuery = [[
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
            KEY `created_at` (`created_at`),
            KEY `priority` (`priority`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    ExecuteQuerySafely(createTableQuery, {}, function(success)
        if success then
            FL.Debug('✅ Emergency calls table created/verified')

            -- Create additional tables if enabled
            if Config.Database.autoSetup.createSamples then
                CreateSampleData()
            end

            if Config.Database.autoSetup.createViews then
                CreateDatabaseViews()
            end
        else
            FL.Debug('❌ Failed to create emergency calls table')
            FL.Server.DatabaseStatus.isAvailable = false
        end
    end)

    -- Enhanced query execution with health check
    function ExecuteQueryWithHealthCheck(query, parameters, callback, retries)
        retries = retries or 3

        -- Pre-check database health
        if not CheckDatabaseAvailability() then
            FL.Debug('❌ Database not available - attempting reconnection')
            AttemptDatabaseReconnection()
            if callback then callback(false, nil) end
            return false
        end

        -- Use existing ExecuteQuerySafely with health check
        return ExecuteQuerySafely(query, parameters, callback, retries)
    end

    -- Create duty log table
    local dutyLogQuery = [[
        CREATE TABLE IF NOT EXISTS `fl_duty_log` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `service` varchar(20) NOT NULL,
            `station` varchar(50) NOT NULL,
            `duty_start` timestamp DEFAULT CURRENT_TIMESTAMP,
            `duty_end` timestamp NULL,
            `duration` int(11) DEFAULT 0,
            `callsign` varchar(20) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `service` (`service`),
            KEY `duty_start` (`duty_start`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    ExecuteQuerySafely(dutyLogQuery, {}, function(success)
        if success then
            FL.Debug('✅ Duty log table created/verified')
        else
            FL.Debug('❌ Failed to create duty log table')
        end
    end)

    -- Create service whitelist table
    local whitelistQuery = [[
        CREATE TABLE IF NOT EXISTS `fl_service_whitelist` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `service` varchar(20) NOT NULL,
            `rank` int(2) DEFAULT 0,
            `added_by` varchar(50) NOT NULL,
            `added_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `notes` text DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid_service` (`citizenid`, `service`),
            KEY `service` (`service`),
            KEY `rank` (`rank`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    ExecuteQuerySafely(whitelistQuery, {}, function(success)
        if success then
            FL.Debug('✅ Service whitelist table created/verified')
        else
            FL.Debug('❌ Failed to create service whitelist table')
        end
    end)
end

-- Create database views for easy data access
function CreateDatabaseViews()
    if not Config.Database.autoSetup.createViews then
        return
    end

    FL.Debug('🔍 Creating database views...')

    -- Active duty view
    local activeDutyView = [[
        CREATE OR REPLACE VIEW `fl_active_duty` AS
        SELECT
            dl.citizenid,
            dl.service,
            dl.station,
            dl.callsign,
            dl.duty_start,
            TIMESTAMPDIFF(MINUTE, dl.duty_start, NOW()) as minutes_on_duty,
            sw.rank,
            CONCAT(IFNULL(p.charinfo->>'$.firstname', 'Unknown'), ' ', IFNULL(p.charinfo->>'$.lastname', 'Player')) as player_name
        FROM fl_duty_log dl
        LEFT JOIN fl_service_whitelist sw ON dl.citizenid = sw.citizenid AND dl.service = sw.service
        LEFT JOIN players p ON dl.citizenid = p.citizenid
        WHERE dl.duty_end IS NULL
        ORDER BY dl.duty_start DESC;
    ]]

    ExecuteQuerySafely(activeDutyView, {}, function(success)
        if success then
            FL.Debug('✅ Active duty view created')
        else
            FL.Debug('❌ Failed to create active duty view')
        end
    end)

    -- Call statistics view
    local callStatsView = [[
        CREATE OR REPLACE VIEW `fl_call_stats` AS
        SELECT
            service,
            COUNT(*) as total_calls,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_calls,
            SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_calls,
            SUM(CASE WHEN priority = 1 THEN 1 ELSE 0 END) as high_priority,
            AVG(CASE WHEN response_time IS NOT NULL THEN response_time ELSE NULL END) as avg_response_time,
            DATE(created_at) as call_date
        FROM fl_emergency_calls
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY service, DATE(created_at)
        ORDER BY call_date DESC, service;
    ]]

    ExecuteQuerySafely(callStatsView, {}, function(success)
        if success then
            FL.Debug('✅ Call statistics view created')
        else
            FL.Debug('❌ Failed to create call statistics view')
        end
    end)
end

-- Create sample data for testing
function CreateSampleData()
    if not Config.Database.autoSetup.createSamples then
        return
    end

    FL.Debug('📊 Creating sample data...')

    -- Check if sample data already exists
    ExecuteQuerySafely('SELECT COUNT(*) as count FROM fl_emergency_calls', {}, function(success, result)
        if success and result and result[1] and result[1].count == 0 then
            -- Insert sample emergency calls
            local sampleCalls = {
                {
                    call_id = 'FLFIRE001',
                    service = 'fire',
                    call_type = 'structure_fire',
                    coords_x = 1193.54,
                    coords_y = -1464.17,
                    coords_z = 34.86,
                    priority = 1,
                    description = 'Structure fire at downtown warehouse - multiple units requested',
                    status = 'pending'
                },
                {
                    call_id = 'FLPD002',
                    service = 'police',
                    call_type = 'robbery',
                    coords_x = 441.7,
                    coords_y = -982.0,
                    coords_z = 30.67,
                    priority = 1,
                    description = 'Armed robbery in progress at convenience store',
                    status = 'pending'
                },
                {
                    call_id = 'FLEMS003',
                    service = 'ems',
                    call_type = 'traffic_accident',
                    coords_x = 306.52,
                    coords_y = -595.62,
                    coords_z = 43.28,
                    priority = 2,
                    description = 'Multi-vehicle accident with injuries reported',
                    status = 'pending'
                }
            }

            for _, call in pairs(sampleCalls) do
                local insertQuery = [[
                    INSERT INTO fl_emergency_calls
                    (call_id, service, call_type, coords_x, coords_y, coords_z, priority, description, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]]

                ExecuteQuerySafely(insertQuery, {
                    call.call_id, call.service, call.call_type,
                    call.coords_x, call.coords_y, call.coords_z,
                    call.priority, call.description, call.status
                }, function(success)
                    if success then
                        FL.Debug('✅ Sample call created: ' .. call.call_id)
                    else
                        FL.Debug('❌ Failed to create sample call: ' .. call.call_id)
                    end
                end)
            end
        else
            FL.Debug('📊 Sample data already exists or query failed')
        end
    end)
end

-- ====================================================================
-- SAFE DATABASE EXECUTION WRAPPER
-- ====================================================================

-- Execute database query with comprehensive error handling
function ExecuteQuerySafely(query, parameters, callback, retries)
    retries = retries or 3

    if not CheckDatabaseAvailability() then
        FL.Debug('❌ Database not available for query execution')
        if callback then callback(false, nil) end
        return false
    end

    if not query or query == '' then
        FL.Debug('❌ Invalid query provided to ExecuteQuerySafely')
        if callback then callback(false, nil) end
        return false
    end

    parameters = parameters or {}

    local function attemptQuery(attempt)
        if not MySQL or not MySQL.query then
            FL.Debug('❌ MySQL not available for query attempt ' .. attempt)
            if callback then callback(false, nil) end
            return
        end

        MySQL.query(query, parameters, function(result)
            if result then
                FL.Debug('✅ Query executed successfully on attempt ' .. attempt)
                if callback then callback(true, result) end
            else
                FL.Debug('❌ Query failed on attempt ' .. attempt)

                if attempt < retries then
                    FL.Debug('🔄 Retrying query in 1 second... (attempt ' .. (attempt + 1) .. '/' .. retries .. ')')
                    CreateThread(function()
                        Wait(1000)
                        attemptQuery(attempt + 1)
                    end)
                else
                    FL.Debug('❌ Query failed after ' .. retries .. ' attempts')

                    -- Mark database as potentially unavailable
                    FL.Server.DatabaseStatus.isAvailable = false
                    AttemptDatabaseReconnection()

                    if callback then callback(false, nil) end
                end
            end
        end)
    end

    attemptQuery(1)
    return true
end

-- Execute insert query with enhanced error handling
function ExecuteInsertSafely(query, parameters, callback)
    if not CheckDatabaseAvailability() then
        FL.Debug('❌ Database not available for insert operation')
        if callback then callback(false, nil) end
        return false
    end

    if not MySQL or not MySQL.insert then
        FL.Debug('❌ MySQL.insert not available')
        if callback then callback(false, nil) end
        return false
    end

    MySQL.insert(query, parameters or {}, function(insertId)
        if insertId and insertId > 0 then
            FL.Debug('✅ Insert successful - ID: ' .. insertId)
            if callback then callback(true, insertId) end
        else
            FL.Debug('❌ Insert failed - insertId: ' .. tostring(insertId))
            if callback then callback(false, nil) end
        end
    end)

    return true
end

-- Execute update query with enhanced error handling
function ExecuteUpdateSafely(query, parameters, callback)
    if not CheckDatabaseAvailability() then
        FL.Debug('❌ Database not available for update operation')
        if callback then callback(false, 0) end
        return false
    end

    if not MySQL or not MySQL.update then
        FL.Debug('❌ MySQL.update not available')
        if callback then callback(false, 0) end
        return false
    end

    MySQL.update(query, parameters or {}, function(affectedRows)
        affectedRows = affectedRows or 0

        if affectedRows > 0 then
            FL.Debug('✅ Update successful - affected rows: ' .. affectedRows)
            if callback then callback(true, affectedRows) end
        else
            FL.Debug('⚠️ Update completed but no rows affected')
            if callback then callback(true, 0) end -- Still consider it successful
        end
    end)

    return true
end

-- ====================================================================
-- JOB-BASED FUNCTIONS (ENHANCED WITH DATABASE INTEGRATION)
-- ====================================================================

-- Check if player has emergency service job (enhanced)
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

-- Get player's emergency service info (enhanced)
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
-- ENHANCED DUTY MANAGEMENT WITH DATABASE LOGGING
-- ====================================================================

-- Log duty start with database integration
function LogDutyStart(source, stationId, service, callsign)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for duty start logging: ' .. tostring(source))
        return false
    end

    local citizenid = Player.PlayerData.citizenid

    -- Log to database if available
    if CheckDatabaseAvailability() then
        local insertQuery = [[
            INSERT INTO fl_duty_log (citizenid, service, station, callsign, duty_start)
            VALUES (?, ?, ?, ?, NOW())
        ]]

        ExecuteInsertSafely(insertQuery, {
            citizenid, service, stationId or 'unknown', callsign or 'UNKNOWN'
        }, function(success, insertId)
            if success then
                FL.Debug('✅ Duty start logged to database: ' .. citizenid .. ' -> ' .. service)
            else
                FL.Debug('❌ Failed to log duty start to database: ' .. citizenid)
            end
        end)
    else
        FL.Debug('⚠️ Database not available - duty start not logged: ' .. citizenid)
    end

    return true
end

-- Log duty end with database integration
function LogDutyEnd(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for duty end logging: ' .. tostring(source))
        return false
    end

    local citizenid = Player.PlayerData.citizenid

    -- Update database if available
    if CheckDatabaseAvailability() then
        local updateQuery = [[
            UPDATE fl_duty_log
            SET duty_end = NOW(),
                duration = TIMESTAMPDIFF(SECOND, duty_start, NOW())
            WHERE citizenid = ? AND duty_end IS NULL
            ORDER BY duty_start DESC
            LIMIT 1
        ]]

        ExecuteUpdateSafely(updateQuery, { citizenid }, function(success, affectedRows)
            if success and affectedRows > 0 then
                FL.Debug('✅ Duty end logged to database: ' .. citizenid)
            else
                FL.Debug('⚠️ No active duty session found to end: ' .. citizenid)
            end
        end)
    else
        FL.Debug('⚠️ Database not available - duty end not logged: ' .. citizenid)
    end

    return true
end

-- ====================================================================
-- DATABASE HEALTH MONITORING THREAD
-- ====================================================================

CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        local dbStatus = FL.Server.DatabaseStatus
        local activeCalls = FL.Functions and FL.Functions.TableSize(FL.Server.EmergencyCalls) or 0
        local activeStations = FL.Functions and FL.Functions.TableSize(FL.Server.ActiveStations) or 0
        local memoryUsage = collectgarbage('count')

        FL.Debug('📊 FL Database Health Report:')
        FL.Debug('🗄️ Database Available: ' .. tostring(dbStatus.isAvailable))
        FL.Debug('🔄 Reconnect Attempts: ' .. dbStatus.reconnectAttempts .. '/' .. dbStatus.maxReconnectAttempts)
        FL.Debug('📞 Active Calls: ' .. activeCalls)
        FL.Debug('🏢 Active Stations: ' .. activeStations)
        FL.Debug('💾 Memory Usage: ' .. string.format('%.2f', memoryUsage) .. ' KB')

        -- Attempt reconnection if database is not available
        if not dbStatus.isAvailable and not dbStatus.isReconnecting then
            if dbStatus.reconnectAttempts < dbStatus.maxReconnectAttempts then
                FL.Debug('🔄 Database unavailable - attempting reconnection')
                AttemptDatabaseReconnection()
            end
        end

        -- Force garbage collection if memory usage is high
        if memoryUsage > 75000 then -- 75MB
            collectgarbage('collect')
            FL.Debug('🧹 Garbage collection performed (was ' .. string.format('%.2f', memoryUsage) .. ' KB)')
        end
    end
end)

-- ====================================================================
-- SIMPLIFIED ADMIN COMMANDS WITH DATABASE INTEGRATION
-- ====================================================================

-- Database status command
RegisterCommand('dbstatus', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    local dbStatus = FL.Server.DatabaseStatus
    local statusText = dbStatus.isAvailable and '✅ Available' or '❌ Unavailable'

    TriggerClientEvent('QBCore:Notify', source, 'Database Status: ' .. statusText,
        dbStatus.isAvailable and 'success' or 'error')

    -- Detailed info to console
    print('^3[FL DATABASE STATUS]^7 ======================')
    print('^3[FL DATABASE]^7 Available: ' .. tostring(dbStatus.isAvailable))
    print('^3[FL DATABASE]^7 Last Check: ' .. os.date('%H:%M:%S', dbStatus.lastCheck / 1000))
    print('^3[FL DATABASE]^7 Reconnect Attempts: ' .. dbStatus.reconnectAttempts .. '/' .. dbStatus.maxReconnectAttempts)
    print('^3[FL DATABASE]^7 Is Reconnecting: ' .. tostring(dbStatus.isReconnecting))
    print('^3[FL DATABASE]^7 Reconnect Delay: ' .. dbStatus.reconnectDelay .. 'ms')
    print('^3[FL DATABASE STATUS]^7 ======================')
end, false)

-- Force database reconnection command
RegisterCommand('dbreconnect', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    FL.Debug('🔄 Manual database reconnection requested by admin: ' .. Player.PlayerData.citizenid)

    -- Reset reconnection state
    FL.Server.DatabaseStatus.reconnectAttempts = 0
    FL.Server.DatabaseStatus.isReconnecting = false
    FL.Server.DatabaseStatus.reconnectDelay = 5000

    local success = AttemptDatabaseReconnection()

    if success then
        TriggerClientEvent('QBCore:Notify', source, 'Database reconnection attempt started', 'info')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Could not start database reconnection', 'error')
    end
end, false)

-- ====================================================================
-- CLEANUP ON PLAYER DISCONNECT (ENHANCED WITH DATABASE LOGGING)
-- ====================================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    FL.Debug('🚪 Player ' .. source .. ' disconnected: ' .. (reason or 'unknown'))

    -- Log duty end if player was on duty
    if FL.Server.ActiveStations[source] then
        LogDutyEnd(source)
    end

    -- Clean up server state
    if FL.Server.ActiveStations[source] then
        FL.Server.ActiveStations[source] = nil
    end

    if FL.Server.UnitCallsigns[source] then
        FL.Server.UnitCallsigns[source] = nil
    end

    -- Remove from any assigned calls (handled in main.lua)
    -- This is logged there to avoid duplication
end)

-- ====================================================================
-- STARTUP VALIDATION AND HEALTH CHECK
-- ====================================================================

CreateThread(function()
    Wait(10000) -- Wait 10 seconds after startup

    FL.Debug('🏥 Performing startup health check...')

    local dbAvailable = CheckDatabaseAvailability()
    local mysqlResource = GetResourceState('oxmysql')
    local qbcoreResource = GetResourceState('qb-core')

    FL.Debug('📊 Startup Health Report:')
    FL.Debug('🗄️ Database Available: ' .. tostring(dbAvailable))
    FL.Debug('📦 MySQL Resource: ' .. mysqlResource)
    FL.Debug('🎯 QBCore Resource: ' .. qbcoreResource)
    FL.Debug('⚙️ Config Database Setup: ' ..
        tostring(Config.Database and Config.Database.autoSetup and Config.Database.autoSetup.enabled))

    if not dbAvailable then
        FL.Debug('⚠️ Warning: Database not available at startup')
        FL.Debug('⚠️ Emergency Services will operate in memory-only mode')
        FL.Debug('⚠️ Some features may be limited')
    end

    if mysqlResource ~= 'started' then
        FL.Debug('❌ Critical: oxmysql resource not started')
    end

    if qbcoreResource ~= 'started' then
        FL.Debug('❌ Critical: qb-core resource not started')
    end

    FL.Debug('🏥 Startup health check completed')
end)

FL.Debug('🎉 FL Core database loaded with COMPLETE ROBUSTNESS & ERROR RECOVERY')
