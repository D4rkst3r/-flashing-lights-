-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - DATABASE SCHEMA
-- Execute this SQL manually if you prefer not to use auto-creation
-- ====================================================================

-- Table: fl_duty_log
-- Stores duty session logs for all emergency services
CREATE TABLE IF NOT EXISTS `fl_duty_log` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `service` varchar(20) NOT NULL,
    `station` varchar(50) NOT NULL,
    `duty_start` timestamp DEFAULT CURRENT_TIMESTAMP,
    `duty_end` timestamp NULL,
    `duration` int(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `service` (`service`),
    KEY `duty_start` (`duty_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: fl_emergency_calls
-- Stores all emergency calls and their status
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
    PRIMARY KEY (`id`),
    UNIQUE KEY `call_id` (`call_id`),
    KEY `service` (`service`),
    KEY `status` (`status`),
    KEY `priority` (`priority`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: fl_service_whitelist
-- Stores player permissions for emergency services
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

-- Table: fl_service_stats (Optional - for statistics tracking)
CREATE TABLE IF NOT EXISTS `fl_service_stats` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `service` varchar(20) NOT NULL,
    `calls_completed` int(11) DEFAULT 0,
    `total_duty_time` int(11) DEFAULT 0,
    `rank_achievements` text DEFAULT NULL,
    `last_duty` timestamp NULL,
    `join_date` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizenid_service_stats` (`citizenid`, `service`),
    KEY `service_stats` (`service`),
    KEY `calls_completed` (`calls_completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ====================================================================
-- SAMPLE DATA (Optional)
-- ====================================================================

-- Sample emergency service whitelists (adjust citizenids to your players)
INSERT INTO `fl_service_whitelist` (`citizenid`, `service`, `rank`, `added_by`, `notes`) VALUES
('ABC12345', 'fire', 6, 'SYSTEM', 'Fire Chief - Default Setup'),
('DEF67890', 'police', 8, 'SYSTEM', 'Chief of Police - Default Setup'),
('GHI11111', 'ems', 6, 'SYSTEM', 'EMS Chief - Default Setup');

-- Sample emergency calls (for testing purposes)
INSERT INTO `fl_emergency_calls` (`call_id`, `service`, `call_type`, `coords_x`, `coords_y`, `coords_z`, `priority`, `description`, `status`) VALUES
('FLFIRE001', 'fire', 'structure_fire', 1193.54, -1464.17, 34.86, 1, 'Structure fire at downtown warehouse - multiple units requested', 'pending'),
('FLPD002', 'police', 'robbery', 441.7, -982.0, 30.67, 1, 'Armed robbery in progress at convenience store', 'pending'),
('FLEMS003', 'ems', 'traffic_accident', 306.52, -595.62, 43.28, 2, 'Multi-vehicle accident with injuries reported', 'pending');

-- ====================================================================
-- INDEXES FOR PERFORMANCE
-- ====================================================================

-- Additional indexes for better query performance
CREATE INDEX `idx_duty_log_service_date` ON `fl_duty_log` (`service`, `duty_start`);
CREATE INDEX `idx_calls_service_status` ON `fl_emergency_calls` (`service`, `status`);
CREATE INDEX `idx_whitelist_service_rank` ON `fl_service_whitelist` (`service`, `rank`);

-- ====================================================================
-- VIEWS (Optional - for easy data access)
-- ====================================================================

-- View: Active duty sessions
CREATE OR REPLACE VIEW `fl_active_duty` AS
SELECT 
    dl.citizenid,
    dl.service,
    dl.station,
    dl.duty_start,
    TIMESTAMPDIFF(MINUTE, dl.duty_start, NOW()) as minutes_on_duty,
    sw.rank,
    CONCAT(cr.firstname, ' ', cr.lastname) as player_name
FROM fl_duty_log dl
LEFT JOIN fl_service_whitelist sw ON dl.citizenid = sw.citizenid AND dl.service = sw.service
LEFT JOIN players cr ON dl.citizenid = cr.citizenid
WHERE dl.duty_end IS NULL
ORDER BY dl.duty_start DESC;

-- View: Emergency call statistics
CREATE OR REPLACE VIEW `fl_call_stats` AS
SELECT 
    service,
    COUNT(*) as total_calls,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_calls,
    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_calls,
    SUM(CASE WHEN priority = 1 THEN 1 ELSE 0 END) as high_priority,
    AVG(CASE WHEN response_time IS NOT NULL THEN response_time ELSE NULL END) as avg_response_time
FROM fl_emergency_calls
GROUP BY service;

-- View: Service member roster
CREATE OR REPLACE VIEW `fl_service_roster` AS
SELECT 
    sw.service,
    sw.citizenid,
    CONCAT(cr.firstname, ' ', cr.lastname) as player_name,
    sw.rank,
    sw.added_at as join_date,
    COALESCE(ss.calls_completed, 0) as calls_completed,
    COALESCE(ss.total_duty_time, 0) as total_duty_hours
FROM fl_service_whitelist sw
LEFT JOIN players cr ON sw.citizenid = cr.citizenid
LEFT JOIN fl_service_stats ss ON sw.citizenid = ss.citizenid AND sw.service = ss.service
ORDER BY sw.service, sw.rank DESC, sw.added_at ASC;

-- ====================================================================
-- TRIGGERS (Optional - for automatic statistics)
-- ====================================================================

-- Trigger: Update stats when duty ends
DELIMITER $$
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
END$$

-- Trigger: Update stats when call completed
DELIMITER $$
CREATE TRIGGER `tr_call_complete_stats`
AFTER UPDATE ON `fl_emergency_calls`
FOR EACH ROW
BEGIN
    DECLARE unit_citizenid VARCHAR(50);
    DECLARE done INT DEFAULT FALSE;
    DECLARE cur CURSOR FOR 
        SELECT DISTINCT citizenid 
        FROM fl_duty_log 
        WHERE service = NEW.service 
        AND duty_start <= NEW.completed_at 
        AND (duty_end IS NULL OR duty_end >= NEW.completed_at);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    IF OLD.status != 'completed' AND NEW.status = 'completed' THEN
        OPEN cur;
        read_loop: LOOP
            FETCH cur INTO unit_citizenid;
            IF done THEN
                LEAVE read_loop;
            END IF;
            
            INSERT INTO fl_service_stats (citizenid, service, calls_completed)
            VALUES (unit_citizenid, NEW.service, 1)
            ON DUPLICATE KEY UPDATE calls_completed = calls_completed + 1;
        END LOOP;
        CLOSE cur;
    END IF;
END$$

DELIMITER ;

-- ====================================================================
-- CLEANUP PROCEDURES (Optional)
-- ====================================================================

-- Procedure: Clean old completed calls (older than 30 days)
DELIMITER $$
CREATE PROCEDURE `sp_cleanup_old_calls`()
BEGIN
    DELETE FROM fl_emergency_calls 
    WHERE status = 'completed' 
    AND completed_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
END$$

-- Procedure: Clean old duty logs (older than 90 days)
DELIMITER $$
CREATE PROCEDURE `sp_cleanup_old_duty_logs`()
BEGIN
    DELETE FROM fl_duty_log 
    WHERE duty_end IS NOT NULL 
    AND duty_end < DATE_SUB(NOW(), INTERVAL 90 DAY);
END$$

DELIMITER ;

-- ====================================================================
-- SCHEDULED EVENTS (Optional)
-- ====================================================================

-- Event: Auto-cleanup every day at 3 AM
CREATE EVENT IF NOT EXISTS `ev_daily_cleanup`
ON SCHEDULE EVERY 1 DAY
STARTS '2024-01-01 03:00:00'
DO
BEGIN
    CALL sp_cleanup_old_calls();
    CALL sp_cleanup_old_duty_logs();
END;

-- Enable event scheduler if not already enabled
-- SET GLOBAL event_scheduler = ON;