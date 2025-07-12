local QBCore = exports['qb-core']:GetCoreObject()

-- ===================================
-- FLASHING LIGHTS CORE SERVER
-- ===================================

-- Store active duty sessions
local DutySessions = {}
local ActiveIncidents = {}

-- ===================================
-- RESOURCE START/STOP
-- ===================================

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        FL.Debug('Flashing Lights Core started successfully!')

        -- Create database tables if they don't exist
        CreateDatabaseTables()

        -- Load active incidents
        LoadActiveIncidents()

        -- Setup station blips
        TriggerClientEvent('fl_core:setupStationBlips', -1)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        FL.Debug('Flashing Lights Core stopped!')

        -- End all duty sessions
        for playerId, session in pairs(DutySessions) do
            EndDutySession(playerId, true)
        end
    end
end)

-- ===================================
-- DUTY SYSTEM
-- ===================================

-- Handle duty interaction from client
RegisterNetEvent('fl_core:dutyInteraction', function(station)
    local src = source
    FL.Debug('Server received duty interaction for station: ' .. tostring(station) .. ' from player: ' .. src)

    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        FL.Debug('Player not found: ' .. src)
        return
    end

    local stationConfig = FL.GetStationConfig(station)
    if not stationConfig then
        FL.Notify(src, 'Invalid station configuration', 'error')
        FL.Debug('Invalid station config: ' .. tostring(station))
        return
    end

    local job = Player.PlayerData.job.name
    if job ~= stationConfig.job then
        FL.Notify(src, 'You are not authorized to use this station', 'error')
        FL.Debug('Job mismatch - Player: ' .. job .. ', Station: ' .. stationConfig.job)
        return
    end

    if Player.PlayerData.job.onduty then
        FL.Debug('Player ' .. src .. ' ending duty at ' .. station)
        EndDutyProcess(src, station)
    else
        FL.Debug('Player ' .. src .. ' starting duty at ' .. station)
        StartDutyProcess(src, station)
    end
end)

-- End duty session
RegisterNetEvent('fl_core:endDuty', function(station)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    -- Check if on duty
    if not Player.PlayerData.job.onduty then
        FL.Notify(src, 'You are not on duty', 'error')
        return
    end

    -- End duty session
    local success = EndDutySession(src)
    if success then
        -- Set player off duty
        Player.Functions.SetJobDuty(false)

        -- Remove uniform
        TriggerClientEvent('fl_core:removeUniform', src)

        -- Notify player
        FL.Notify(src, 'You are now off duty', 'info')

        -- Notify other emergency services
        local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        local jobLabel = FL.GetJobConfig(Player.PlayerData.job.name).label
        FL.NotifyEmergencyServices(playerName .. ' (' .. jobLabel .. ') is now off duty', 'info')

        FL.Debug('Player ' .. src .. ' ended duty')
    end
end)

-- Start duty session in database
function StartDutySession(playerId, station)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return false end

    local sessionId = FL.GenerateIncidentId()
    local timestamp = FL.GetTimestamp()

    -- Store in memory
    DutySessions[playerId] = {
        sessionId = sessionId,
        citizenid = Player.PlayerData.citizenid,
        job = Player.PlayerData.job.name,
        grade = Player.PlayerData.job.grade.level,
        station = station,
        startTime = timestamp,
        endTime = nil
    }

    -- Store in database if logging is enabled
    if Config.DutySystem.log_duty_times then
        local query = [[
            INSERT INTO fl_duty_logs (session_id, citizenid, job, grade, station, start_time)
            VALUES (?, ?, ?, ?, ?, ?)
        ]]

        MySQL.insert(query, {
            sessionId,
            Player.PlayerData.citizenid,
            Player.PlayerData.job.name,
            Player.PlayerData.job.grade.level,
            station,
            timestamp
        })
    end

    return sessionId
end

-- End duty session
function EndDutySession(playerId, forceEnd)
    local session = DutySessions[playerId]
    if not session then return false end

    local timestamp = FL.GetTimestamp()
    local duration = timestamp - session.startTime

    -- Update database if logging is enabled
    if Config.DutySystem.log_duty_times then
        local query = [[
            UPDATE fl_duty_logs
            SET end_time = ?, duration = ?
            WHERE session_id = ?
        ]]

        MySQL.update(query, {
            timestamp,
            duration,
            session.sessionId
        })
    end

    -- Remove from memory
    DutySessions[playerId] = nil

    FL.Debug('Duty session ended for player ' .. playerId .. ' (Duration: ' .. FL.FormatTime(duration) .. ')')

    return true
end

-- Handle player disconnect
AddEventHandler('playerDropped', function()
    local src = source

    if DutySessions[src] then
        EndDutySession(src, true)
        FL.Debug('Player ' .. src .. ' disconnected while on duty - session ended')
    end
end)

-- ===================================
-- INCIDENT SYSTEM
-- ===================================

-- Create new incident
RegisterNetEvent('fl_core:createIncident', function(data)
    local src = source

    -- Check permissions
    if not FL.HasPermission(src, 'manage_incidents') then
        FL.Notify(src, 'You do not have permission to create incidents', 'error')
        return
    end

    local incidentId = CreateIncident(data, src)
    if incidentId then
        FL.Notify(src, 'Incident ' .. incidentId .. ' created successfully', 'success')
    end
end)

-- Create incident
function CreateIncident(data, creator)
    local incidentId = FL.GenerateIncidentId()
    local timestamp = FL.GetTimestamp()

    local incident = {
        id = incidentId,
        type = data.type or 'emergency',
        title = data.title or 'Emergency Call',
        description = data.description or '',
        location = data.location or vector3(0, 0, 0),
        postal = data.postal or '',
        priority = data.priority or 2,
        status = 'open',
        assigned_units = {},
        created_by = creator or 0,
        created_at = timestamp,
        updated_at = timestamp
    }

    -- Store in memory
    ActiveIncidents[incidentId] = incident

    -- Store in database
    local query = [[
        INSERT INTO fl_incidents (id, type, title, description, location_x, location_y, location_z,
                                postal, priority, status, created_by, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    MySQL.insert(query, {
        incidentId,
        incident.type,
        incident.title,
        incident.description,
        incident.location.x,
        incident.location.y,
        incident.location.z,
        incident.postal,
        incident.priority,
        incident.status,
        incident.created_by,
        incident.created_at,
        incident.updated_at
    })

    -- Notify dispatch and emergency services
    TriggerClientEvent('fl_dispatch:newIncident', -1, incident)

    FL.Debug('New incident created: ' .. incidentId)

    return incidentId
end

-- Load active incidents from database
function LoadActiveIncidents()
    local query = [[
        SELECT * FROM fl_incidents
        WHERE status IN ('open', 'assigned', 'enroute', 'onscene')
        ORDER BY created_at DESC
    ]]

    MySQL.query(query, {}, function(result)
        if result then
            for _, incident in pairs(result) do
                ActiveIncidents[incident.id] = {
                    id = incident.id,
                    type = incident.type,
                    title = incident.title,
                    description = incident.description,
                    location = vector3(incident.location_x, incident.location_y, incident.location_z),
                    postal = incident.postal,
                    priority = incident.priority,
                    status = incident.status,
                    assigned_units = json.decode(incident.assigned_units or '[]'),
                    created_by = incident.created_by,
                    created_at = incident.created_at,
                    updated_at = incident.updated_at
                }
            end

            FL.Debug('Loaded ' .. #result .. ' active incidents')
        end
    end)
end

-- ===================================
-- CALLBACKS
-- ===================================

-- Get player duty status
QBCore.Functions.CreateCallback('fl_core:getDutyStatus', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    cb({
        onduty = Player.PlayerData.job.onduty,
        job = Player.PlayerData.job.name,
        grade = Player.PlayerData.job.grade,
        session = DutySessions[source]
    })
end)

-- Get active incidents
QBCore.Functions.CreateCallback('fl_core:getActiveIncidents', function(source, cb)
    cb(ActiveIncidents)
end)

-- Get duty statistics
QBCore.Functions.CreateCallback('fl_core:getDutyStats', function(source, cb, job)
    job = job or 'all'

    local stats = {
        total_on_duty = 0,
        by_job = {}
    }

    for jobName, _ in pairs(Config.Jobs) do
        local players = FL.GetOnDutyPlayers(jobName)
        stats.by_job[jobName] = #players
        stats.total_on_duty = stats.total_on_duty + #players
    end

    cb(stats)
end)
