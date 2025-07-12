-- ===================================
-- FLASHING LIGHTS DATABASE SETUP
-- ===================================

function CreateDatabaseTables()
    FL.Debug('Creating database tables...')

    -- Emergency Jobs Table (für Job-Whitelist)
    local emergencyJobsTable = [[
        CREATE TABLE IF NOT EXISTS `fl_emergency_jobs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `job` varchar(50) NOT NULL,
            `grade` int(11) NOT NULL DEFAULT 0,
            `hired_by` varchar(50) DEFAULT NULL,
            `hired_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `status` enum('active','inactive','suspended') DEFAULT 'active',
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_citizen_job` (`citizenid`, `job`),
            KEY `idx_citizenid` (`citizenid`),
            KEY `idx_job` (`job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Duty Logs Table (für Dienstzeiten-Tracking)
    local dutyLogsTable = [[
        CREATE TABLE IF NOT EXISTS `fl_duty_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `session_id` varchar(50) NOT NULL,
            `citizenid` varchar(50) NOT NULL,
            `job` varchar(50) NOT NULL,
            `grade` int(11) NOT NULL,
            `station` varchar(100) NOT NULL,
            `start_time` int(11) NOT NULL,
            `end_time` int(11) DEFAULT NULL,
            `duration` int(11) DEFAULT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `session_id` (`session_id`),
            KEY `idx_citizenid` (`citizenid`),
            KEY `idx_job` (`job`),
            KEY `idx_start_time` (`start_time`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Incidents Table (für Einsätze)
    local incidentsTable = [[
        CREATE TABLE IF NOT EXISTS `fl_incidents` (
            `id` varchar(50) NOT NULL,
            `type` varchar(50) NOT NULL,
            `title` varchar(255) NOT NULL,
            `description` text,
            `location_x` double NOT NULL,
            `location_y` double NOT NULL,
            `location_z` double NOT NULL,
            `postal` varchar(10) DEFAULT NULL,
            `priority` int(11) NOT NULL DEFAULT 2,
            `status` enum('open','assigned','enroute','onscene','completed','cancelled') DEFAULT 'open',
            `assigned_units` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`assigned_units`)),
            `created_by` int(11) NOT NULL,
            `created_at` int(11) NOT NULL,
            `updated_at` int(11) NOT NULL,
            `completed_at` int(11) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_type` (`type`),
            KEY `idx_status` (`status`),
            KEY `idx_priority` (`priority`),
            KEY `idx_created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Equipment Table (für Ausrüstungs-Tracking)
    local equipmentTable = [[
        CREATE TABLE IF NOT EXISTS `fl_equipment` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `job` varchar(50) NOT NULL,
            `item` varchar(100) NOT NULL,
            `serial_number` varchar(100) DEFAULT NULL,
            `assigned_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `assigned_by` varchar(50) DEFAULT NULL,
            `status` enum('assigned','returned','lost','damaged') DEFAULT 'assigned',
            `notes` text DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_citizenid` (`citizenid`),
            KEY `idx_job` (`job`),
            KEY `idx_item` (`item`),
            KEY `idx_status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Vehicle Logs Table (für Fahrzeug-Nutzung)
    local vehicleLogsTable = [[
        CREATE TABLE IF NOT EXISTS `fl_vehicle_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `job` varchar(50) NOT NULL,
            `vehicle_model` varchar(100) NOT NULL,
            `vehicle_plate` varchar(20) NOT NULL,
            `action` enum('spawned','returned','impounded') NOT NULL,
            `location_x` double DEFAULT NULL,
            `location_y` double DEFAULT NULL,
            `location_z` double DEFAULT NULL,
            `mileage_start` int(11) DEFAULT NULL,
            `mileage_end` int(11) DEFAULT NULL,
            `fuel_start` int(11) DEFAULT NULL,
            `fuel_end` int(11) DEFAULT NULL,
            `damage_report` text DEFAULT NULL,
            `timestamp` int(11) NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_citizenid` (`citizenid`),
            KEY `idx_job` (`job`),
            KEY `idx_plate` (`vehicle_plate`),
            KEY `idx_timestamp` (`timestamp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Medical Reports Table (für EMS Patientenberichte)
    local medicalReportsTable = [[
        CREATE TABLE IF NOT EXISTS `fl_medical_reports` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `report_id` varchar(50) NOT NULL,
            `incident_id` varchar(50) DEFAULT NULL,
            `patient_citizenid` varchar(50) DEFAULT NULL,
            `patient_name` varchar(255) DEFAULT NULL,
            `treating_paramedic` varchar(50) NOT NULL,
            `location_x` double NOT NULL,
            `location_y` double NOT NULL,
            `location_z` double NOT NULL,
            `injury_type` varchar(100) DEFAULT NULL,
            `injury_severity` enum('minor','moderate','severe','critical') DEFAULT 'minor',
            `treatment_given` text DEFAULT NULL,
            `transported_to` varchar(255) DEFAULT NULL,
            `outcome` enum('treated_released','transported','deceased','refused_treatment') DEFAULT 'treated_released',
            `vitals` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`vitals`)),
            `created_at` int(11) NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `report_id` (`report_id`),
            KEY `idx_incident_id` (`incident_id`),
            KEY `idx_patient` (`patient_citizenid`),
            KEY `idx_paramedic` (`treating_paramedic`),
            KEY `idx_created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Fire Reports Table (für Feuerwehr-Einsatzberichte)
    local fireReportsTable = [[
        CREATE TABLE IF NOT EXISTS `fl_fire_reports` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `report_id` varchar(50) NOT NULL,
            `incident_id` varchar(50) DEFAULT NULL,
            `fire_chief` varchar(50) NOT NULL,
            `location_x` double NOT NULL,
            `location_y` double NOT NULL,
            `location_z` double NOT NULL,
            `fire_type` varchar(100) DEFAULT NULL,
            `cause` varchar(255) DEFAULT NULL,
            `damage_estimate` int(11) DEFAULT NULL,
            `injuries` int(11) DEFAULT 0,
            `fatalities` int(11) DEFAULT 0,
            `units_responded` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`units_responded`)),
            `suppression_method` varchar(100) DEFAULT NULL,
            `water_used` int(11) DEFAULT NULL,
            `duration_minutes` int(11) DEFAULT NULL,
            `status` enum('extinguished','contained','monitoring','under_investigation') DEFAULT 'extinguished',
            `notes` text DEFAULT NULL,
            `created_at` int(11) NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `report_id` (`report_id`),
            KEY `idx_incident_id` (`incident_id`),
            KEY `idx_fire_chief` (`fire_chief`),
            KEY `idx_created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    -- Execute table creation
    local tables = {
        { name = 'fl_emergency_jobs',  query = emergencyJobsTable },
        { name = 'fl_duty_logs',       query = dutyLogsTable },
        { name = 'fl_incidents',       query = incidentsTable },
        { name = 'fl_equipment',       query = equipmentTable },
        { name = 'fl_vehicle_logs',    query = vehicleLogsTable },
        { name = 'fl_medical_reports', query = medicalReportsTable },
        { name = 'fl_fire_reports',    query = fireReportsTable }
    }

    for _, table in pairs(tables) do
        MySQL.query(table.query, {}, function(result)
            if result then
                FL.Debug('Table ' .. table.name .. ' created/verified successfully')
            else
                print('^1[FL-ERROR]^7 Failed to create table: ' .. table.name)
            end
        end)
    end

    -- Insert default data
    Wait(1000) -- Wait for tables to be created
    InsertDefaultData()
end

function InsertDefaultData()
    FL.Debug('Inserting default data...')

    -- Check if we have any emergency job entries, if not, insert some defaults
    MySQL.query('SELECT COUNT(*) as count FROM fl_emergency_jobs', {}, function(result)
        if result and result[1] and result[1].count == 0 then
            FL.Debug('No emergency job entries found, this is normal for first-time setup')
            -- In a real scenario, you would add your admin citizenids here
            -- Example:
            -- MySQL.insert('INSERT INTO fl_emergency_jobs (citizenid, job, grade, hired_by) VALUES (?, ?, ?, ?)',
            --     {'ABC12345', 'fire', 5, 'system'})
        end
    end)

    FL.Debug('Default data setup completed')
end

-- ===================================
-- UTILITY FUNCTIONS
-- ===================================

-- Add player to emergency job
function AddPlayerToEmergencyJob(citizenid, job, grade, hiredBy)
    grade = grade or 0
    hiredBy = hiredBy or 'system'

    local query = [[
        INSERT INTO fl_emergency_jobs (citizenid, job, grade, hired_by, status)
        VALUES (?, ?, ?, ?, 'active')
        ON DUPLICATE KEY UPDATE
        grade = VALUES(grade),
        hired_by = VALUES(hired_by),
        hired_at = CURRENT_TIMESTAMP,
        status = 'active'
    ]]

    MySQL.insert(query, { citizenid, job, grade, hiredBy }, function(result)
        if result then
            FL.Debug('Added ' .. citizenid .. ' to ' .. job .. ' with grade ' .. grade)
        else
            print('^1[FL-ERROR]^7 Failed to add player to emergency job')
        end
    end)
end

-- Remove player from emergency job
function RemovePlayerFromEmergencyJob(citizenid, job)
    local query = 'UPDATE fl_emergency_jobs SET status = ? WHERE citizenid = ? AND job = ?'

    MySQL.update(query, { 'inactive', citizenid, job }, function(result)
        if result then
            FL.Debug('Removed ' .. citizenid .. ' from ' .. job)
        else
            print('^1[FL-ERROR]^7 Failed to remove player from emergency job')
        end
    end)
end

-- Check if player is authorized for emergency job
function IsPlayerAuthorizedForJob(citizenid, job)
    local query = 'SELECT * FROM fl_emergency_jobs WHERE citizenid = ? AND job = ? AND status = ?'

    local result = MySQL.query.await(query, { citizenid, job, 'active' })
    return result and #result > 0
end
