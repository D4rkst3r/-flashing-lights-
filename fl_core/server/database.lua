-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - AUTOMATIC DATABASE SETUP
-- ====================================================================

-- Initialize FL.Database namespace
if not FL then FL = {} end
if not FL.Database then FL.Database = {} end

-- Local debug function in case FL.Debug isn't available yet
local function LocalDebug(message)
    if FL and FL.Debug then
        FL.Debug(message)
    else
        print('^3[FL-DATABASE]^7 ' .. tostring(message))
    end
end

-- ====================================================================
-- CONFIGURATION
-- ====================================================================

-- Database setup configuration (uses values from Config.lua with fallbacks)
local DB_CONFIG = {
    create_views = (Config and Config.Database and Config.Database.autoSetup and Config.Database.autoSetup.createViews) or
    true,
    create_triggers = (Config and Config.Database and Config.Database.autoSetup and Config.Database.autoSetup.createTriggers) or
    true,
    create_samples = (Config and Config.Database and Config.Database.autoSetup and Config.Database.autoSetup.createSamples) or
    false,
    cleanup_procedures = (Config and Config.Database and Config.Database.autoSetup and Config.Database.autoSetup.cleanupProcedures) or
    true,
    scheduled_events = (Config and Config.Database and Config.Database.autoSetup and Config.Database.autoSetup.scheduledEvents) or
    false,
    version = "1.0.0" -- Database schema version
}

-- ====================================================================
-- CORE TABLES
-- ====================================================================

local CORE_TABLES = {
    -- Emergency duty log table
    fl_duty_log = [[
        CREATE TABLE IF NOT EXISTS `fl_duty_log` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `service` varchar(20) NOT NULL,
            `station` varchar(50) NOT NULL,
            `duty_start` timestamp DEFAULT CURRENT_TIMESTAMP,
            `duty_end` timestamp NULL,
            `duration` int(11) DEFAULT 0,
            `notes` text DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `service` (`service`),
            KEY `duty_start` (`duty_start`),
            KEY `idx_duty_log_service_date` (`service`, `duty_start`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],

    -- Emergency calls table
    fl_emergency_calls = [[
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
            `response_time` int(11) DEFAULT NULL,
            `reporter` varchar(100) DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `call_id` (`call_id`),
            KEY `service` (`service`),
            KEY `status` (`status`),
            KEY `priority` (`priority`),
            KEY `created_at` (`created_at`),
            KEY `idx_calls_service_status` (`service`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],

    -- Service whitelist table
    fl_service_whitelist = [[
        CREATE TABLE IF NOT EXISTS `fl_service_whitelist` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `service` varchar(20) NOT NULL,
            `rank` int(2) DEFAULT 0,
            `added_by` varchar(50) NOT NULL,
            `added_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `notes` text DEFAULT NULL,
            `status` varchar(20) DEFAULT 'active',
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid_service` (`citizenid`, `service`),
            KEY `service` (`service`),
            KEY `rank` (`rank`),
            KEY `idx_whitelist_service_rank` (`service`, `rank`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],

    -- Service statistics table
    fl_service_stats = [[
        CREATE TABLE IF NOT EXISTS `fl_service_stats` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `service` varchar(20) NOT NULL,
            `calls_completed` int(11) DEFAULT 0,
            `total_duty_time` int(11) DEFAULT 0,
            `rank_achievements` text DEFAULT NULL,
            `last_duty` timestamp NULL,
            `join_date` timestamp DEFAULT CURRENT_TIMESTAMP,
            `commendations` int(11) DEFAULT 0,
            `performance_score` decimal(5,2) DEFAULT 0.00,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid_service_stats` (`citizenid`, `service`),
            KEY `service_stats` (`service`),
            KEY `calls_completed` (`calls_completed`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],

    -- System configuration table
    fl_system_config = [[
        CREATE TABLE IF NOT EXISTS `fl_system_config` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `config_key` varchar(100) NOT NULL,
            `config_value` text DEFAULT NULL,
            `description` text DEFAULT NULL,
            `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `updated_by` varchar(50) DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `config_key` (`config_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

-- ====================================================================
-- DATABASE VIEWS
-- ====================================================================

local DATABASE_VIEWS = {
    -- Active duty sessions view
    fl_active_duty = [[
        CREATE OR REPLACE VIEW `fl_active_duty` AS
        SELECT
            dl.citizenid,
            dl.service,
            dl.station,
            dl.duty_start,
            TIMESTAMPDIFF(MINUTE, dl.duty_start, NOW()) as minutes_on_duty,
            sw.rank,
            CASE
                WHEN p.charinfo IS NOT NULL THEN JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname'))
                ELSE 'Unknown'
            END as firstname,
            CASE
                WHEN p.charinfo IS NOT NULL THEN JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                ELSE 'Player'
            END as lastname
        FROM fl_duty_log dl
        LEFT JOIN fl_service_whitelist sw ON dl.citizenid = sw.citizenid AND dl.service = sw.service
        LEFT JOIN players p ON dl.citizenid = p.citizenid
        WHERE dl.duty_end IS NULL
        ORDER BY dl.duty_start DESC;
    ]],

    -- Emergency call statistics view
    fl_call_stats = [[
        CREATE OR REPLACE VIEW `fl_call_stats` AS
        SELECT
            service,
            COUNT(*) as total_calls,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_calls,
            SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_calls,
            SUM(CASE WHEN status = 'assigned' THEN 1 ELSE 0 END) as assigned_calls,
            SUM(CASE WHEN priority = 1 THEN 1 ELSE 0 END) as high_priority,
            SUM(CASE WHEN priority = 2 THEN 1 ELSE 0 END) as medium_priority,
            SUM(CASE WHEN priority = 3 THEN 1 ELSE 0 END) as low_priority,
            AVG(CASE WHEN response_time IS NOT NULL THEN response_time ELSE NULL END) as avg_response_time,
            DATE(created_at) as call_date
        FROM fl_emergency_calls
        GROUP BY service, DATE(created_at)
        ORDER BY call_date DESC;
    ]],

    -- Service member roster view
    fl_service_roster = [[
        CREATE OR REPLACE VIEW `fl_service_roster` AS
        SELECT
            sw.service,
            sw.citizenid,
            CASE
                WHEN p.charinfo IS NOT NULL THEN CONCAT(
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')),
                    ' ',
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                )
                ELSE 'Unknown Player'
            END as player_name,
            sw.rank,
            sw.added_at as join_date,
            sw.status,
            COALESCE(ss.calls_completed, 0) as calls_completed,
            COALESCE(ss.total_duty_time, 0) as total_duty_hours,
            COALESCE(ss.performance_score, 0.00) as performance_score,
            ss.last_duty
        FROM fl_service_whitelist sw
        LEFT JOIN players p ON sw.citizenid = p.citizenid
        LEFT JOIN fl_service_stats ss ON sw.citizenid = ss.citizenid AND sw.service = ss.service
        WHERE sw.status = 'active'
        ORDER BY sw.service, sw.rank DESC, sw.added_at ASC;
    ]]
}

-- ====================================================================
-- DATABASE TRIGGERS
-- ====================================================================

local DATABASE_TRIGGERS = {
    -- Update stats when duty ends
    tr_duty_end_stats = [[
        CREATE TRIGGER `tr_duty_end_stats`
        AFTER UPDATE ON `fl_duty_log`
        FOR EACH ROW
        BEGIN
            IF OLD.duty_end IS NULL AND NEW.duty_end IS NOT NULL THEN
                INSERT INTO fl_service_stats (citizenid, service, total_duty_time, last_duty)
                VALUES (NEW.citizenid, NEW.service, NEW.duration, NEW.duty_end)
                ON DUPLICATE KEY UPDATE
                    total_duty_time = total_duty_time + NEW.duration,
                    last_duty = NEW.duty_end;
            END IF;
        END;
    ]],

    -- Update stats when call completed
    tr_call_complete_stats = [[
        CREATE TRIGGER `tr_call_complete_stats`
        AFTER UPDATE ON `fl_emergency_calls`
        FOR EACH ROW
        BEGIN
            IF OLD.status != 'completed' AND NEW.status = 'completed' AND NEW.assigned_units IS NOT NULL THEN
                -- This is a simplified version - in production you'd parse the JSON assigned_units
                UPDATE fl_service_stats
                SET calls_completed = calls_completed + 1,
                    performance_score = LEAST(performance_score + 0.1, 10.0)
                WHERE service = NEW.service;
            END IF;
        END;
    ]]
}

-- ====================================================================
-- CLEANUP PROCEDURES
-- ====================================================================

local CLEANUP_PROCEDURES = {
    -- Clean old completed calls
    sp_cleanup_old_calls = [[
        CREATE PROCEDURE `sp_cleanup_old_calls`()
        BEGIN
            DECLARE cleaned_count INT DEFAULT 0;

            SELECT COUNT(*) INTO cleaned_count
            FROM fl_emergency_calls
            WHERE status = 'completed'
            AND completed_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

            DELETE FROM fl_emergency_calls
            WHERE status = 'completed'
            AND completed_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

            INSERT INTO fl_system_config (config_key, config_value, description, updated_by)
            VALUES ('last_cleanup_calls', NOW(), CONCAT('Cleaned ', cleaned_count, ' old calls'), 'SYSTEM')
            ON DUPLICATE KEY UPDATE
                config_value = NOW(),
                description = CONCAT('Cleaned ', cleaned_count, ' old calls'),
                updated_by = 'SYSTEM';
        END;
    ]],

    -- Clean old duty logs
    sp_cleanup_old_duty_logs = [[
        CREATE PROCEDURE `sp_cleanup_old_duty_logs`()
        BEGIN
            DECLARE cleaned_count INT DEFAULT 0;

            SELECT COUNT(*) INTO cleaned_count
            FROM fl_duty_log
            WHERE duty_end IS NOT NULL
            AND duty_end < DATE_SUB(NOW(), INTERVAL 90 DAY);

            DELETE FROM fl_duty_log
            WHERE duty_end IS NOT NULL
            AND duty_end < DATE_SUB(NOW(), INTERVAL 90 DAY);

            INSERT INTO fl_system_config (config_key, config_value, description, updated_by)
            VALUES ('last_cleanup_duty', NOW(), CONCAT('Cleaned ', cleaned_count, ' old duty logs'), 'SYSTEM')
            ON DUPLICATE KEY UPDATE
                config_value = NOW(),
                description = CONCAT('Cleaned ', cleaned_count, ' old duty logs'),
                updated_by = 'SYSTEM';
        END;
    ]]
}

-- ====================================================================
-- SAMPLE DATA
-- ====================================================================

local SAMPLE_DATA = {
    -- Sample system configuration
    system_config = {
        {
            config_key = 'db_version',
            config_value = DB_CONFIG.version,
            description = 'Database schema version',
            updated_by = 'SYSTEM'
        },
        {
            config_key = 'auto_cleanup_enabled',
            config_value = 'true',
            description = 'Automatic cleanup of old records',
            updated_by = 'SYSTEM'
        },
        {
            config_key = 'max_duty_hours',
            config_value = '12',
            description = 'Maximum continuous duty hours',
            updated_by = 'SYSTEM'
        }
    },

    -- Sample emergency calls (for testing)
    emergency_calls = {
        {
            call_id = 'FLFIRE001',
            service = 'fire',
            call_type = 'structure_fire',
            coords_x = 1193.54,
            coords_y = -1464.17,
            coords_z = 34.86,
            priority = 1,
            description = 'Structure fire at downtown warehouse - multiple units requested',
            status = 'pending',
            reporter = 'Anonymous Caller'
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
            status = 'pending',
            reporter = 'Store Employee'
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
            status = 'pending',
            reporter = 'Witness'
        }
    }
}

-- ====================================================================
-- SETUP FUNCTIONS
-- ====================================================================

-- Execute SQL with error handling
function FL.Database.ExecuteSQL(query, description)
    local success = false
    local errorMsg = nil

    MySQL.query(query, {}, function(result)
        success = true
        LocalDebug('✅ ' .. (description or 'SQL executed'))
    end, function(error)
        errorMsg = error
        LocalDebug('❌ Failed to execute: ' .. (description or 'SQL') .. ' - Error: ' .. tostring(error))
    end)

    -- Wait for completion (simple synchronous approach)
    local timeout = 0
    while success == false and errorMsg == nil and timeout < 100 do -- 10 second timeout
        Wait(100)
        timeout = timeout + 1
    end

    if timeout >= 100 then
        LocalDebug('❌ SQL execution timed out: ' .. (description or 'SQL'))
        return false, 'Timeout'
    end

    return success, errorMsg
end

-- Create core tables
function FL.Database.CreateTables()
    LocalDebug('🔨 Creating core database tables...')

    for tableName, tableSQL in pairs(CORE_TABLES) do
        local success, error = FL.Database.ExecuteSQL(tableSQL, 'Create table: ' .. tableName)
        if not success then
            LocalDebug('❌ Failed to create table ' .. tableName .. ': ' .. tostring(error))
            return false
        end
    end

    LocalDebug('✅ All core tables created successfully')
    return true
end

-- Create database views
function FL.Database.CreateViews()
    if not DB_CONFIG.create_views then
        LocalDebug('⏭️ Skipping database views creation (disabled in config)')
        return true
    end

    LocalDebug('👁️ Creating database views...')

    for viewName, viewSQL in pairs(DATABASE_VIEWS) do
        local success, error = FL.Database.ExecuteSQL(viewSQL, 'Create view: ' .. viewName)
        if not success then
            LocalDebug('⚠️ Failed to create view ' .. viewName .. ': ' .. tostring(error))
            -- Views are not critical, continue
        end
    end

    LocalDebug('✅ Database views creation completed')
    return true
end

-- Create database triggers
function FL.Database.CreateTriggers()
    if not DB_CONFIG.create_triggers then
        LocalDebug('⏭️ Skipping database triggers creation (disabled in config)')
        return true
    end

    LocalDebug('⚡ Creating database triggers...')

    -- Drop existing triggers first
    for triggerName, _ in pairs(DATABASE_TRIGGERS) do
        MySQL.query('DROP TRIGGER IF EXISTS `' .. triggerName .. '`', {})
    end

    Wait(100) -- Give time for drops to complete

    for triggerName, triggerSQL in pairs(DATABASE_TRIGGERS) do
        local success, error = FL.Database.ExecuteSQL(triggerSQL, 'Create trigger: ' .. triggerName)
        if not success then
            LocalDebug('⚠️ Failed to create trigger ' .. triggerName .. ': ' .. tostring(error))
            -- Triggers are not critical, continue
        end
    end

    LocalDebug('✅ Database triggers creation completed')
    return true
end

-- Create cleanup procedures
function FL.Database.CreateProcedures()
    if not DB_CONFIG.cleanup_procedures then
        LocalDebug('⏭️ Skipping cleanup procedures creation (disabled in config)')
        return true
    end

    LocalDebug('🧹 Creating cleanup procedures...')

    -- Drop existing procedures first
    for procName, _ in pairs(CLEANUP_PROCEDURES) do
        MySQL.query('DROP PROCEDURE IF EXISTS `' .. procName .. '`', {})
    end

    Wait(100) -- Give time for drops to complete

    for procName, procSQL in pairs(CLEANUP_PROCEDURES) do
        local success, error = FL.Database.ExecuteSQL(procSQL, 'Create procedure: ' .. procName)
        if not success then
            LocalDebug('⚠️ Failed to create procedure ' .. procName .. ': ' .. tostring(error))
        end
    end

    LocalDebug('✅ Cleanup procedures creation completed')
    return true
end

-- Insert sample data
function FL.Database.InsertSampleData()
    if not DB_CONFIG.create_samples then
        LocalDebug('⏭️ Skipping sample data insertion (disabled in config)')
        return true
    end

    LocalDebug('📋 Inserting sample data...')

    -- Insert system configuration
    for _, config in pairs(SAMPLE_DATA.system_config) do
        MySQL.insert(
        'INSERT INTO fl_system_config (config_key, config_value, description, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE config_value = VALUES(config_value)',
            {
                config.config_key,
                config.config_value,
                config.description,
                config.updated_by
            })
    end

    -- Insert sample emergency calls
    for _, call in pairs(SAMPLE_DATA.emergency_calls) do
        MySQL.insert(
        'INSERT IGNORE INTO fl_emergency_calls (call_id, service, call_type, coords_x, coords_y, coords_z, priority, description, status, reporter) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {
                call.call_id,
                call.service,
                call.call_type,
                call.coords_x,
                call.coords_y,
                call.coords_z,
                call.priority,
                call.description,
                call.status,
                call.reporter
            })
    end

    LocalDebug('✅ Sample data insertion completed')
    return true
end

-- Check if database is already initialized
function FL.Database.IsInitialized()
    local initialized = false
    local completed = false

    MySQL.query('SELECT config_value FROM fl_system_config WHERE config_key = ? LIMIT 1', {
        'db_version'
    }, function(result)
        if result and #result > 0 then
            initialized = (result[1].config_value == DB_CONFIG.version)
        end
        completed = true
    end, function(error)
        LocalDebug('⚠️ Could not check database initialization status: ' .. tostring(error))
        completed = true
    end)

    -- Wait for query completion with timeout
    local timeout = 0
    while not completed and timeout < 50 do -- 5 second timeout
        Wait(100)
        timeout = timeout + 1
    end

    if timeout >= 50 then
        LocalDebug('⚠️ Database initialization check timed out, assuming not initialized')
        return false
    end

    return initialized
end

-- Main database initialization function
function FL.Database.Initialize()
    LocalDebug('🚀 Starting automatic database setup...')
    LocalDebug('📊 Configuration: Views=' .. tostring(DB_CONFIG.create_views) ..
        ', Triggers=' .. tostring(DB_CONFIG.create_triggers) ..
        ', Samples=' .. tostring(DB_CONFIG.create_samples) ..
        ', Procedures=' .. tostring(DB_CONFIG.cleanup_procedures))

    -- Step 1: Create core tables
    if not FL.Database.CreateTables() then
        LocalDebug('❌ Database initialization failed at table creation')
        return false
    end

    -- Step 2: Create views
    FL.Database.CreateViews()

    -- Step 3: Create triggers
    FL.Database.CreateTriggers()

    -- Step 4: Create procedures
    FL.Database.CreateProcedures()

    -- Step 5: Insert sample data
    FL.Database.InsertSampleData()

    -- Step 6: Mark as initialized
    MySQL.insert(
    'INSERT INTO fl_system_config (config_key, config_value, description, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE config_value = VALUES(config_value)',
        {
            'db_version',
            DB_CONFIG.version,
            'Database schema version',
            'SYSTEM'
        })

    LocalDebug('🎉 Database initialization completed successfully!')
    LocalDebug('📈 Database version: ' .. DB_CONFIG.version)

    return true
end

-- Manual cleanup function (can be called by admin command)
function FL.Database.RunCleanup()
    if not DB_CONFIG.cleanup_procedures then
        LocalDebug('🚫 Cleanup procedures not available')
        return false
    end

    LocalDebug('🧹 Running manual database cleanup...')

    -- Run cleanup procedures
    MySQL.query('CALL sp_cleanup_old_calls()', {})
    MySQL.query('CALL sp_cleanup_old_duty_logs()', {})

    LocalDebug('✅ Database cleanup completed')
    return true
end

-- Get database statistics
function FL.Database.GetStats()
    local stats = {}

    -- Get table sizes
    MySQL.query([[
        SELECT
            table_name,
            table_rows,
            ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
        AND table_name LIKE 'fl_%'
        ORDER BY table_name
    ]], {}, function(result)
        stats.tables = result or {}
    end)

    -- Get recent activity
    MySQL.query('SELECT COUNT(*) as active_duty FROM fl_duty_log WHERE duty_end IS NULL', {}, function(result)
        stats.active_duty = result[1]?.active_duty or 0
    end)

    MySQL.query('SELECT COUNT(*) as pending_calls FROM fl_emergency_calls WHERE status = ?', { 'pending' },
        function(result)
            stats.pending_calls = result[1]?.pending_calls or 0
        end)

    return stats
end

LocalDebug('📦 Database module loaded successfully')
