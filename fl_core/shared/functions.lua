-- ===================================
-- FLASHING LIGHTS SHARED FUNCTIONS
-- ===================================

FL = {}

-- Debug print function
function FL.Debug(msg)
    if Config.Debug then
        print('^3[FL-DEBUG]^7 ' .. tostring(msg))
    end
end

-- Get job configuration
function FL.GetJobConfig(job)
    return Config.Jobs[job] or nil
end

-- Get station configuration
function FL.GetStationConfig(station)
    return Config.Stations[station] or nil
end

-- Check if player has permission
function FL.HasPermission(source, permission)
    if not source then return false end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    -- Check if permission is in admin commands
    for _, perm in pairs(Config.Permissions.admin_commands) do
        if QBCore.Functions.HasPermission(source, perm) then
            return true
        end
    end

    -- Check specific permission
    return QBCore.Functions.HasPermission(source, permission)
end

-- Format time for display
function FL.FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, mins, secs)
    else
        return string.format("%02d:%02d", mins, secs)
    end
end

-- Calculate distance between two points
function FL.GetDistance(pos1, pos2)
    if type(pos1) == 'vector3' and type(pos2) == 'vector3' then
        return #(pos1 - pos2)
    elseif type(pos1) == 'table' and type(pos2) == 'table' then
        return math.sqrt(
            (pos1.x - pos2.x) ^ 2 +
            (pos1.y - pos2.y) ^ 2 +
            (pos1.z - pos2.z) ^ 2
        )
    end
    return 0
end

-- Get all players with specific job
function FL.GetPlayersWithJob(job)
    local players = {}
    local QBPlayers = QBCore.Functions.GetPlayers()

    for _, playerId in pairs(QBPlayers) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.name == job then
            table.insert(players, {
                source = playerId,
                citizenid = Player.PlayerData.citizenid,
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                job = Player.PlayerData.job,
                onduty = Player.PlayerData.job.onduty
            })
        end
    end

    return players
end

-- Get players on duty with specific job
function FL.GetOnDutyPlayers(job)
    local players = FL.GetPlayersWithJob(job)
    local onDutyPlayers = {}

    for _, player in pairs(players) do
        if player.onduty then
            table.insert(onDutyPlayers, player)
        end
    end

    return onDutyPlayers
end

-- Round number to decimal places
function FL.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Check if player is emergency service
function FL.IsEmergencyService(job)
    if not job then
        FL.Debug('IsEmergencyService: job is nil')
        return false
    end

    local isEmergency = job == 'police' or job == 'ambulance' or job == 'fire'
    FL.Debug('IsEmergencyService check: ' .. job .. ' = ' .. tostring(isEmergency))

    return isEmergency
end

-- Generate unique incident ID
function FL.GenerateIncidentId()
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local id = ''

    for i = 1, 8 do
        local rand = math.random(#chars)
        id = id .. chars:sub(rand, rand)
    end

    return id
end

-- Get current timestamp
function FL.GetTimestamp()
    return os.time()
end

-- Format timestamp to readable date
function FL.FormatDate(timestamp)
    return os.date('%Y-%m-%d %H:%M:%S', timestamp)
end

-- Send notification (works with different notification systems)
function FL.Notify(source, message, type, timeout)
    type = type or 'primary'
    timeout = timeout or Config.Notifications.timeout

    if Config.Notifications.type == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, message, type, timeout)
    elseif Config.Notifications.type == 'ox' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Emergency Services',
            description = message,
            type = type,
            duration = timeout
        })
    else
        -- Custom notification system
        TriggerClientEvent('fl_core:notify', source, message, type, timeout)
    end
end

-- Broadcast notification to all emergency services
function FL.NotifyEmergencyServices(message, type, jobs)
    jobs = jobs or { 'police', 'ambulance', 'fire' }

    for _, job in pairs(jobs) do
        local players = FL.GetOnDutyPlayers(job)
        for _, player in pairs(players) do
            FL.Notify(player.source, message, type)
        end
    end
end

-- Check if coordinates are valid
function FL.IsValidCoords(coords)
    if not coords then return false end

    if type(coords) == 'vector3' then
        return coords.x ~= 0 or coords.y ~= 0 or coords.z ~= 0
    elseif type(coords) == 'table' then
        return coords.x and coords.y and coords.z and
            (coords.x ~= 0 or coords.y ~= 0 or coords.z ~= 0)
    end

    return false
end

-- Get random element from table
function FL.GetRandomElement(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(#tbl)]
end

-- Deep copy table
function FL.DeepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end

    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = FL.DeepCopy(value)
    end

    return copy
end
