-- ====================================================================
-- FL EMERGENCY SERVICES - MONITORING DASHBOARD
-- ====================================================================

FL.Monitoring = {
    startTime = os.time(),

    getSystemStats = function()
        local stats = {
            uptime = os.time() - self.startTime,
            activeCalls = FL.Functions.TableSize(FL.Server.EmergencyCalls),
            activeStations = FL.Functions.TableSize(FL.Server.ActiveStations),
            callsigns = FL.Functions.TableSize(FL.Server.UnitCallsigns),
            databaseStatus = FL.Server.DatabaseStatus and FL.Server.DatabaseStatus.isAvailable or false,
            memoryUsage = math.floor(collectgarbage('count')),
            playerCount = #GetPlayers()
        }

        -- Service-specific stats
        stats.services = {}
        for service, _ in pairs(Config.EmergencyServices) do
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

-- Admin command for system status
RegisterCommand('flstatus', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    local stats = FL.Monitoring.getSystemStats()

    -- Send to client
    TriggerClientEvent('QBCore:Notify', source,
        'FL Status: ' .. stats.activeCalls .. ' calls, ' .. stats.playerCount .. ' players - Check console', 'info')

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

-- Performance monitoring command
RegisterCommand('flperf', function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions for this command', 'error')
        return
    end

    -- Force garbage collection and get before/after
    local memBefore = collectgarbage('count')
    collectgarbage('collect')
    local memAfter = collectgarbage('count')

    local freed = memBefore - memAfter

    TriggerClientEvent('QBCore:Notify', source,
        'Performance: ' .. math.floor(memAfter) .. ' KB memory (' .. math.floor(freed) .. ' KB freed)', 'info')

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

FL.Debug('📊 Monitoring system loaded')
