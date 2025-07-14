-- ====================================================================
-- FL EMERGENCY SERVICES - MONITORING DASHBOARD (QBCORE FIX)
-- ====================================================================

local QBCore = FL.GetFramework()

-- Wait for QBCore to be ready
CreateThread(function()
    local attempts = 0
    while not QBCore and attempts < 10 do
        QBCore = FL.GetFramework()
        if not QBCore then
            Wait(1000)
            attempts = attempts + 1
            FL.Debug('⏳ Waiting for QBCore in monitoring.lua... Attempt ' .. attempts)
        end
    end

    if not QBCore then
        FL.Debug('❌ CRITICAL: QBCore not available in monitoring.lua after 10 attempts')
        return
    end

    FL.Debug('✅ QBCore loaded successfully in monitoring.lua')
end)

FL.Monitoring = {
    startTime = os.time(),

    getSystemStats = function()
        local stats = {
            uptime = os.time() - FL.Monitoring.startTime,
            activeCalls = FL.Functions and FL.Functions.TableSize(FL.Server.EmergencyCalls) or 0,
            activeStations = FL.Functions and FL.Functions.TableSize(FL.Server.ActiveStations) or 0,
            callsigns = FL.Functions and FL.Functions.TableSize(FL.Server.UnitCallsigns) or 0,
            databaseStatus = FL.Server.DatabaseStatus and FL.Server.DatabaseStatus.isAvailable or false,
            memoryUsage = math.floor(collectgarbage('count')),
            playerCount = #GetPlayers()
        }

        -- Service-specific stats
        stats.services = {}
        for service, _ in pairs(Config.EmergencyServices or {}) do
            stats.services[service] = {
                onDuty = GetOnDutyCount(service),
                activeCalls = GetActiveCallsCount(service)
            }
        end

        return stats
    end,

    formatUptime = function(seconds)
        local days = math.floor(seconds / 86400)
        local hours = math.floor((seconds % 86400) / 3600)
        local minutes = math.floor((seconds % 3600) / 60)

        if days > 0 then
            return string.format('%dd %dh %dm', days, hours, minutes)
        elseif hours > 0 then
            return string.format('%dh %dm', hours, minutes)
        else
            return string.format('%dm', minutes)
        end
    end
}

-- Enhanced permission check with fallbacks
local function HasAdminPermission(source)
    if not source or source <= 0 then
        return false
    end

    -- Method 1: QBCore permission check
    if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(source, 'admin') or
            QBCore.Functions.HasPermission(source, 'god') then
            return true
        end
    end

    -- Method 2: QBCore player permission check
    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.permission then
            local permission = Player.PlayerData.permission
            if permission == 'admin' or permission == 'god' then
                return true
            end
        end
    end

    -- Method 3: Ace permission check (FiveM native)
    if IsPlayerAceAllowed(source, 'command') or
        IsPlayerAceAllowed(source, 'admin') or
        IsPlayerAceAllowed(source, 'fl.admin') then
        return true
    end

    -- Method 4: Check if player is server owner/console
    if source == 0 then -- Console
        return true
    end

    return false
end

-- Admin command for system status (FIXED)
RegisterCommand('flstatus', function(source, args)
    if not HasAdminPermission(source) then
        if source > 0 then
            TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        end
        return
    end

    local stats = FL.Monitoring.getSystemStats()

    -- Send to client if not console
    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source,
            'FL Status: ' .. stats.activeCalls .. ' calls, ' .. stats.playerCount .. ' players - Check console', 'info')
    end

    -- Detailed console output
    print('^3[FL SYSTEM STATUS]^7 ===========================')
    print('^2[FL STATUS]^7 Uptime: ' .. FL.Monitoring.formatUptime(stats.uptime))
    print('^2[FL STATUS]^7 Players: ' .. stats.playerCount)
    print('^2[FL STATUS]^7 Active Calls: ' .. stats.activeCalls)
    print('^2[FL STATUS]^7 Active Stations: ' .. stats.activeStations)
    print('^2[FL STATUS]^7 Unit Callsigns: ' .. stats.callsigns)
    print('^2[FL STATUS]^7 Database: ' .. (stats.databaseStatus and '✅ Online' or '❌ Offline'))
    print('^2[FL STATUS]^7 Memory: ' .. stats.memoryUsage .. ' KB')
    print('^3[FL SERVICES]^7 ---------------------------')

    for service, serviceStats in pairs(stats.services) do
        local serviceName = string.upper(service)
        print('^6[FL ' ..
        serviceName .. ']^7 On Duty: ' .. serviceStats.onDuty .. ' | Active Calls: ' .. serviceStats.activeCalls)
    end

    print('^3[FL SYSTEM STATUS]^7 ===========================')
end, false)

-- Performance monitoring command (FIXED)
RegisterCommand('flperf', function(source, args)
    if not HasAdminPermission(source) then
        if source > 0 then
            TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        end
        return
    end

    -- Force garbage collection and get before/after
    local memBefore = collectgarbage('count')
    collectgarbage('collect')
    local memAfter = collectgarbage('count')

    local freed = memBefore - memAfter

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source,
            'Performance: ' .. math.floor(memAfter) .. ' KB memory (' .. math.floor(freed) .. ' KB freed)', 'info')
    end

    print('^3[FL PERFORMANCE]^7 ======================')
    print('^2[FL PERF]^7 Memory Before GC: ' .. math.floor(memBefore) .. ' KB')
    print('^2[FL PERF]^7 Memory After GC: ' .. math.floor(memAfter) .. ' KB')
    print('^2[FL PERF]^7 Memory Freed: ' .. math.floor(freed) .. ' KB')

    if FL.Profiler and FL.Profiler.calls then
        print('^3[FL PROFILER]^7 Function Calls:')
        for func, count in pairs(FL.Profiler.calls) do
            print('^6[FL PROF]^7 ' .. func .. ': ' .. count .. ' calls')
        end
    end

    print('^3[FL PERFORMANCE]^7 ======================')
end, false)

FL.Debug('📊 Monitoring system loaded with FIXED PERMISSIONS')
