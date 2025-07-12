-- ===================================
-- FLASHING LIGHTS SERVER CALLBACKS
-- ===================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ===================================
-- DUTY SYSTEM CALLBACKS
-- ===================================

-- Get player duty status and information
QBCore.Functions.CreateCallback('fl_core:getDutyStatus', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    local session = DutySessions[source]
    local dutyTime = 0

    if session then
        dutyTime = FL.GetTimestamp() - session.startTime
    end

    cb({
        onduty = Player.PlayerData.job.onduty,
        job = Player.PlayerData.job.name,
        grade = Player.PlayerData.job.grade,
        session = session,
        dutyTime = dutyTime,
        formattedDutyTime = FL.FormatTime(dutyTime)
    })
end)

-- Check if player is authorized for emergency job
QBCore.Functions.CreateCallback('fl_core:checkJobAuthorization', function(source, cb, job)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local isAuthorized = IsPlayerAuthorizedForJob(citizenid, job)

    cb(isAuthorized)
end)

-- Get all players on duty for specific job
QBCore.Functions.CreateCallback('fl_core:getOnDutyPlayers', function(source, cb, job)
    local players = FL.GetOnDutyPlayers(job)
    cb(players)
end)

-- Get duty statistics for all emergency services
QBCore.Functions.CreateCallback('fl_core:getDutyStats', function(source, cb, job)
    job = job or 'all'

    local stats = {
        total_on_duty = 0,
        by_job = {},
        detailed = {}
    }

    for jobName, jobConfig in pairs(Config.Jobs) do
        local players = FL.GetOnDutyPlayers(jobName)
        local detailed = {}

        for _, player in pairs(players) do
            table.insert(detailed, {
                source = player.source,
                name = player.name,
                rank = player.job.grade.label,
                grade = player.job.grade.level
            })
        end

        stats.by_job[jobName] = {
            count = #players,
            label = jobConfig.label,
            players = detailed
        }

        stats.total_on_duty = stats.total_on_duty + #players
    end

    cb(stats)
end)

-- ===================================
-- INCIDENT SYSTEM CALLBACKS
-- ===================================

-- Get all active incidents
QBCore.Functions.CreateCallback('fl_core:getActiveIncidents', function(source, cb)
    cb(ActiveIncidents)
end)

-- Get specific incident by ID
QBCore.Functions.CreateCallback('fl_core:getIncident', function(source, cb, incidentId)
    local incident = ActiveIncidents[incidentId]
    cb(incident)
end)

-- Get incidents by type
QBCore.Functions.CreateCallback('fl_core:getIncidentsByType', function(source, cb, incidentType)
    local incidents = {}

    for id, incident in pairs(ActiveIncidents) do
        if incident.type == incidentType then
            incidents[id] = incident
        end
    end

    cb(incidents)
end)

-- Get incidents assigned to player
QBCore.Functions.CreateCallback('fl_core:getAssignedIncidents', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local assignedIncidents = {}
    local citizenid = Player.PlayerData.citizenid

    for id, incident in pairs(ActiveIncidents) do
        for _, unit in pairs(incident.assigned_units) do
            if unit.citizenid == citizenid then
                assignedIncidents[id] = incident
                break
            end
        end
    end

    cb(assignedIncidents)
end)

-- ===================================
-- STATION SYSTEM CALLBACKS
-- ===================================

-- Get station information
QBCore.Functions.CreateCallback('fl_core:getStationInfo', function(source, cb, stationId)
    local station = FL.GetStationConfig(stationId)
    if not station then
        cb(false)
        return
    end

    -- Get players currently at this station
    local playersAtStation = {}
    for playerId, session in pairs(DutySessions) do
        if session.station == stationId then
            local Player = QBCore.Functions.GetPlayer(playerId)
            if Player then
                table.insert(playersAtStation, {
                    source = playerId,
                    name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                    job = Player.PlayerData.job,
                    dutyTime = FL.GetTimestamp() - session.startTime
                })
            end
        end
    end

    cb({
        config = station,
        playersOnDuty = playersAtStation,
        totalOnDuty = #playersAtStation
    })
end)

-- Get all stations for a specific job
QBCore.Functions.CreateCallback('fl_core:getJobStations', function(source, cb, job)
    local stations = {}

    for stationId, station in pairs(Config.Stations) do
        if station.job == job then
            stations[stationId] = station
        end
    end

    cb(stations)
end)

-- ===================================
-- EQUIPMENT SYSTEM CALLBACKS
-- ===================================

-- Get player equipment
QBCore.Functions.CreateCallback('fl_core:getPlayerEquipment', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local query = 'SELECT * FROM fl_equipment WHERE citizenid = ? AND status = ?'

    MySQL.query(query, { citizenid, 'assigned' }, function(result)
        cb(result or {})
    end)
end)

-- Check if player has specific equipment
QBCore.Functions.CreateCallback('fl_core:hasEquipment', function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local query = 'SELECT * FROM fl_equipment WHERE citizenid = ? AND item = ? AND status = ?'

    MySQL.query(query, { citizenid, itemName, 'assigned' }, function(result)
        cb(result and #result > 0)
    end)
end)

-- ===================================
-- VEHICLE SYSTEM CALLBACKS
-- ===================================

-- Get available vehicles for job
QBCore.Functions.CreateCallback('fl_core:getJobVehicles', function(source, cb, job)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    -- This would typically come from a vehicle configuration
    -- For now, we'll return some default vehicles based on job
    local vehicles = {}

    if job == 'fire' then
        vehicles = {
            { model = 'firetruk',  label = 'Fire Truck',   livery = 0 },
            { model = 'firetruck', label = 'Ladder Truck', livery = 0 }
        }
    elseif job == 'ambulance' then
        vehicles = {
            { model = 'ambulance', label = 'Ambulance', livery = 0 }
        }
    elseif job == 'police' then
        vehicles = {
            { model = 'police',  label = 'Police Cruiser', livery = 0 },
            { model = 'police2', label = 'Police Buffalo', livery = 0 }
        }
    end

    cb(vehicles)
end)

-- Log vehicle usage
QBCore.Functions.CreateCallback('fl_core:logVehicleUsage', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    local query = [[
        INSERT INTO fl_vehicle_logs (citizenid, job, vehicle_model, vehicle_plate, action,
                                   location_x, location_y, location_z, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    MySQL.insert(query, {
        Player.PlayerData.citizenid,
        Player.PlayerData.job.name,
        data.model,
        data.plate,
        data.action,
        data.location.x,
        data.location.y,
        data.location.z,
        FL.GetTimestamp()
    }, function(result)
        cb(result ~= nil)
    end)
end)

-- ===================================
-- REPORTING SYSTEM CALLBACKS
-- ===================================

-- Get duty logs for player
QBCore.Functions.CreateCallback('fl_core:getDutyLogs', function(source, cb, citizenid, limit)
    citizenid = citizenid or nil
    limit = limit or 50

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    -- If no citizenid provided, use current player's
    if not citizenid then
        citizenid = Player.PlayerData.citizenid
    end

    -- Check if player has permission to view other player's logs
    if citizenid ~= Player.PlayerData.citizenid then
        if not FL.HasPermission(source, 'admin') then
            cb({})
            return
        end
    end

    local query = [[
        SELECT * FROM fl_duty_logs
        WHERE citizenid = ?
        ORDER BY start_time DESC
        LIMIT ?
    ]]

    MySQL.query(query, { citizenid, limit }, function(result)
        cb(result or {})
    end)
end)

-- Get incident statistics
QBCore.Functions.CreateCallback('fl_core:getIncidentStats', function(source, cb, timeRange)
    timeRange = timeRange or 7 -- days

    local startTime = FL.GetTimestamp() - (timeRange * 24 * 3600)

    local query = [[
        SELECT
            type,
            priority,
            status,
            COUNT(*) as count,
            AVG(CASE WHEN completed_at IS NOT NULL THEN completed_at - created_at END) as avg_response_time
        FROM fl_incidents
        WHERE created_at >= ?
        GROUP BY type, priority, status
        ORDER BY type, priority
    ]]

    MySQL.query(query, { startTime }, function(result)
        cb(result or {})
    end)
end)

-- ===================================
-- PLAYER MANAGEMENT CALLBACKS
-- ===================================

-- Add player to emergency job
QBCore.Functions.CreateCallback('fl_core:addPlayerToJob', function(source, cb, targetId, job, grade)
    -- Check permissions
    if not FL.HasPermission(source, 'admin') then
        cb(false, 'No permission')
        return
    end

    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        cb(false, 'Player not found')
        return
    end

    grade = grade or 0

    -- Add to emergency jobs table
    AddPlayerToEmergencyJob(TargetPlayer.PlayerData.citizenid, job, grade, source)

    -- Set player job
    TargetPlayer.Functions.SetJob(job, grade)

    cb(true, 'Player added to ' .. job)
end)

-- Remove player from emergency job
QBCore.Functions.CreateCallback('fl_core:removePlayerFromJob', function(source, cb, targetId, job)
    -- Check permissions
    if not FL.HasPermission(source, 'admin') then
        cb(false, 'No permission')
        return
    end

    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        cb(false, 'Player not found')
        return
    end

    -- Remove from emergency jobs table
    RemovePlayerFromEmergencyJob(TargetPlayer.PlayerData.citizenid, job)

    -- Set player to unemployed
    TargetPlayer.Functions.SetJob('unemployed', 0)

    cb(true, 'Player removed from ' .. job)
end)

-- ===================================
-- PERMISSION CALLBACKS
-- ===================================

-- Check if player has permission
QBCore.Functions.CreateCallback('fl_core:hasPermission', function(source, cb, permission)
    local hasPermission = FL.HasPermission(source, permission)
    cb(hasPermission)
end)

-- Get player permissions
QBCore.Functions.CreateCallback('fl_core:getPlayerPermissions', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local permissions = {}

    -- Check admin permissions
    for _, perm in pairs(Config.Permissions.admin_commands) do
        if QBCore.Functions.HasPermission(source, perm) then
            table.insert(permissions, perm)
        end
    end

    -- Check manage incidents permission
    for _, perm in pairs(Config.Permissions.manage_incidents) do
        if QBCore.Functions.HasPermission(source, perm) then
            table.insert(permissions, perm)
        end
    end

    cb(permissions)
end)

-- ===================================
-- MISCELLANEOUS CALLBACKS
-- ===================================

-- Get server statistics
QBCore.Functions.CreateCallback('fl_core:getServerStats', function(source, cb)
    local stats = {
        totalPlayers = #QBCore.Functions.GetPlayers(),
        totalOnDuty = 0,
        activeIncidents = 0,
        completedIncidentsToday = 0
    }

    -- Count on duty players
    for _, _ in pairs(DutySessions) do
        stats.totalOnDuty = stats.totalOnDuty + 1
    end

    -- Count active incidents
    for _, _ in pairs(ActiveIncidents) do
        stats.activeIncidents = stats.activeIncidents + 1
    end

    -- Count completed incidents today
    local todayStart = FL.GetTimestamp() - (24 * 3600)
    local query = 'SELECT COUNT(*) as count FROM fl_incidents WHERE status = ? AND completed_at >= ?'

    MySQL.query(query, { 'completed', todayStart }, function(result)
        if result and result[1] then
            stats.completedIncidentsToday = result[1].count
        end
        cb(stats)
    end)
end)

-- Validate coordinates
QBCore.Functions.CreateCallback('fl_core:validateCoords', function(source, cb, coords)
    local isValid = FL.IsValidCoords(coords)
    cb(isValid)
end)

-- Get distance between two points
QBCore.Functions.CreateCallback('fl_core:getDistance', function(source, cb, pos1, pos2)
    local distance = FL.GetDistance(pos1, pos2)
    cb(distance)
end)

FL.Debug('Server callbacks loaded successfully')
