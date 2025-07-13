-- ====================================================================
-- FL CORE - DISCORD WEBHOOKS SYSTEM
-- Automatische Logs für alle Emergency Services Events
-- ====================================================================

-- server/discord.lua - Neue Datei erstellen

local QBCore = FL.GetFramework()

-- Discord Configuration
FL.Discord = {
    webhooks = {
        -- Main webhooks für jede Service
        fire = '',   -- YOUR_FIRE_WEBHOOK_URL_HERE
        police = '', -- YOUR_POLICE_WEBHOOK_URL_HERE
        ems = '',    -- YOUR_EMS_WEBHOOK_URL_HERE

        -- Spezielle Event-Webhooks
        admin = '',    -- YOUR_ADMIN_WEBHOOK_URL_HERE
        duty = '',     -- YOUR_DUTY_WEBHOOK_URL_HERE
        emergency = '' -- YOUR_EMERGENCY_WEBHOOK_URL_HERE
    },

    colors = {
        fire = 15158332,      -- Red
        police = 3447003,     -- Blue
        ems = 3066993,        -- Green
        emergency = 16711680, -- Bright Red
        success = 3066993,    -- Green
        warning = 16776960,   -- Yellow
        error = 15158332,     -- Red
        info = 3447003        -- Blue
    },

    icons = {
        fire = '🔥',
        police = '👮',
        ems = '🚑',
        emergency = '🚨',
        duty_start = '✅',
        duty_end = '❌',
        call_new = '📞',
        call_assigned = '👥',
        call_completed = '✅',
        admin = '⚙️'
    }
}

-- ====================================================================
-- CORE WEBHOOK FUNCTIONS
-- ====================================================================

-- Send webhook with retry logic
function FL.Discord.SendWebhook(webhookUrl, embed, retries)
    if not webhookUrl or webhookUrl == '' then
        FL.Debug('❌ No webhook URL provided')
        return false
    end

    retries = retries or 3

    local payload = {
        username = 'FL Emergency Services',
        avatar_url = 'https://i.imgur.com/your-logo.png', -- Optional: Your server logo
        embeds = { embed }
    }

    PerformHttpRequest(webhookUrl, function(statusCode, responseText, headers)
        if statusCode == 200 or statusCode == 204 then
            FL.Debug('✅ Discord webhook sent successfully')
        else
            FL.Debug('❌ Discord webhook failed: ' .. tostring(statusCode))
            if retries > 0 then
                Wait(1000)
                FL.Discord.SendWebhook(webhookUrl, embed, retries - 1)
            end
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

-- Create standardized embed
function FL.Discord.CreateEmbed(title, description, color, fields, footer)
    local embed = {
        title = title or 'FL Emergency Services',
        description = description or '',
        color = color or FL.Discord.colors.info,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%S'),
        fields = fields or {},
        footer = footer or {
            text = 'FL Emergency Services • ' .. GetPlayerName(-1) or 'Unknown Server',
            icon_url = 'https://i.imgur.com/your-footer-icon.png'
        }
    }

    return embed
end

-- ====================================================================
-- DUTY LOGGING
-- ====================================================================

function FL.Discord.LogDutyChange(source, service, onDuty, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local citizenId = Player.PlayerData.citizenid
    local rank = Player.PlayerData.job.grade.name

    local icon = onDuty and FL.Discord.icons.duty_start or FL.Discord.icons.duty_end
    local status = onDuty and 'ON DUTY' or 'OFF DUTY'
    local color = onDuty and FL.Discord.colors.success or FL.Discord.colors.warning

    local title = icon .. ' ' .. string.upper(service) .. ' - ' .. status
    local description = '**' .. playerName .. '** is now ' .. (onDuty and 'on duty' or 'off duty')

    local fields = {
        {
            name = '👤 Officer Information',
            value = '**Name:** ' .. playerName .. '\n' ..
                '**Citizen ID:** ' .. citizenId .. '\n' ..
                '**Rank:** ' .. rank,
            inline = true
        },
        {
            name = '🏢 Station Information',
            value = '**Station:** ' .. (stationId or 'Unknown') .. '\n' ..
                '**Service:** ' .. string.upper(service) .. '\n' ..
                '**Time:** <t:' .. os.time() .. ':F>',
            inline = true
        }
    }

    if onDuty then
        fields[#fields + 1] = {
            name = '📊 Duty Statistics',
            value = '**Total Officers:** ' .. GetOnDutyCount(service) .. '\n' ..
                '**Active Calls:** ' .. GetActiveCallsCount(service),
            inline = false
        }
    end

    local embed = FL.Discord.CreateEmbed(title, description, color, fields)

    -- Send to duty webhook
    FL.Discord.SendWebhook(FL.Discord.webhooks.duty, embed)

    -- Also send to service-specific webhook
    if FL.Discord.webhooks[service] then
        FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed)
    end
end

-- ====================================================================
-- EMERGENCY CALL LOGGING
-- ====================================================================

function FL.Discord.LogEmergencyCall(callData, eventType)
    local service = callData.service
    local icon = FL.Discord.icons[eventType] or FL.Discord.icons.emergency
    local color = FL.Discord.colors[service] or FL.Discord.colors.emergency

    local titles = {
        call_new = '🆕 NEW EMERGENCY CALL',
        call_assigned = '👥 CALL ASSIGNED',
        call_completed = '✅ CALL COMPLETED'
    }

    local title = titles[eventType] or 'EMERGENCY CALL UPDATE'
    title = title .. ' - ' .. string.upper(service)

    local priorityText = FL.Functions.FormatPriority(callData.priority)
    local description = '**Type:** ' .. FL.Functions.FormatCallType(callData.type) .. '\n' ..
        '**Priority:** ' .. priorityText .. '\n' ..
        '**Description:** ' .. callData.description

    local fields = {
        {
            name = '📞 Call Information',
            value = '**Call ID:** ' .. callData.id .. '\n' ..
                '**Service:** ' .. string.upper(service) .. '\n' ..
                '**Status:** ' .. string.upper(callData.status),
            inline = true
        },
        {
            name = '📍 Location',
            value = '**Coordinates:** ' .. string.format('%.1f, %.1f, %.1f',
                    callData.coords.x, callData.coords.y, callData.coords.z) .. '\n' ..
                '**Created:** <t:' .. callData.created_at .. ':R>',
            inline = true
        }
    }

    -- Add assigned units info for assignment/completion
    if eventType == 'call_assigned' or eventType == 'call_completed' then
        if callData.unit_details and #callData.unit_details > 0 then
            local unitsText = ''
            for i, unit in pairs(callData.unit_details) do
                unitsText = unitsText .. '• **' .. unit.callsign .. '** - ' .. unit.name .. '\n'
                if i >= 5 then -- Limit to 5 units for space
                    unitsText = unitsText .. '• ... and ' .. (#callData.unit_details - 5) .. ' more\n'
                    break
                end
            end

            fields[#fields + 1] = {
                name = '👥 Assigned Units (' .. #callData.unit_details .. ')',
                value = unitsText,
                inline = false
            }
        end
    end

    -- Add completion stats for completed calls
    if eventType == 'call_completed' and callData.response_time then
        local responseMinutes = math.floor(callData.response_time / 60)
        local responseSeconds = callData.response_time % 60

        fields[#fields + 1] = {
            name = '⏱️ Response Statistics',
            value = '**Response Time:** ' .. responseMinutes .. 'm ' .. responseSeconds .. 's\n' ..
                '**Completed At:** <t:' .. (callData.completed_at or os.time()) .. ':F>',
            inline = false
        }
    end

    local embed = FL.Discord.CreateEmbed(title, description, color, fields)

    -- Send to emergency webhook for high priority calls
    if callData.priority == 1 then
        FL.Discord.SendWebhook(FL.Discord.webhooks.emergency, embed)
    end

    -- Send to service-specific webhook
    if FL.Discord.webhooks[service] then
        FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed)
    end
end

-- ====================================================================
-- ADMIN LOGGING
-- ====================================================================

function FL.Discord.LogAdminAction(source, action, details)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local citizenId = Player.PlayerData.citizenid

    local title = FL.Discord.icons.admin .. ' ADMIN ACTION - ' .. string.upper(action)
    local description = '**' .. playerName .. '** performed an admin action'

    local fields = {
        {
            name = '👤 Admin Information',
            value = '**Name:** ' .. playerName .. '\n' ..
                '**Citizen ID:** ' .. citizenId .. '\n' ..
                '**Server ID:** ' .. source,
            inline = true
        },
        {
            name = '⚙️ Action Details',
            value = '**Action:** ' .. action .. '\n' ..
                '**Details:** ' .. (details or 'No details provided') .. '\n' ..
                '**Time:** <t:' .. os.time() .. ':F>',
            inline = true
        }
    }

    local embed = FL.Discord.CreateEmbed(title, description, FL.Discord.colors.warning, fields)

    FL.Discord.SendWebhook(FL.Discord.webhooks.admin, embed)
end

-- ====================================================================
-- STATISTICS LOGGING
-- ====================================================================

function FL.Discord.LogDailyStats()
    local stats = GetDailyStatistics()

    local title = '📊 DAILY STATISTICS REPORT'
    local description = 'Emergency Services activity summary for ' .. os.date('%B %d, %Y')

    local fields = {}

    for service, serviceStats in pairs(stats) do
        fields[#fields + 1] = {
            name = FL.Discord.icons[service] .. ' ' .. string.upper(service),
            value = '**Calls Handled:** ' .. serviceStats.calls_completed .. '\n' ..
                '**Avg Response:** ' .. serviceStats.avg_response_time .. 's\n' ..
                '**Peak Officers:** ' .. serviceStats.peak_officers .. '\n' ..
                '**Duty Hours:** ' .. serviceStats.total_duty_hours .. 'h',
            inline = true
        }
    end

    local embed = FL.Discord.CreateEmbed(title, description, FL.Discord.colors.info, fields)

    -- Send to all service webhooks
    for service, webhookUrl in pairs(FL.Discord.webhooks) do
        if service ~= 'admin' and service ~= 'duty' and service ~= 'emergency' then
            FL.Discord.SendWebhook(webhookUrl, embed)
        end
    end
end

-- ====================================================================
-- HELPER FUNCTIONS
-- ====================================================================

function GetOnDutyCount(service)
    local count = 0
    local Players = QBCore.Functions.GetPlayers()

    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.onduty then
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
    for _, callData in pairs(FL.Server.EmergencyCalls) do
        if callData.service == service and callData.status ~= 'completed' then
            count = count + 1
        end
    end
    return count
end

function GetDailyStatistics()
    -- This would typically query the database for the last 24 hours
    -- For now, return mock data structure
    return {
        fire = {
            calls_completed = 0,
            avg_response_time = 0,
            peak_officers = 0,
            total_duty_hours = 0
        },
        police = {
            calls_completed = 0,
            avg_response_time = 0,
            peak_officers = 0,
            total_duty_hours = 0
        },
        ems = {
            calls_completed = 0,
            avg_response_time = 0,
            peak_officers = 0,
            total_duty_hours = 0
        }
    }
end

-- ====================================================================
-- EVENT INTEGRATIONS
-- ====================================================================

-- Hook into existing duty toggle
RegisterServerEvent('fl_core:toggleDuty', function(stationId)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local isEmergency, service = IsPlayerEmergencyService(source)
    if not isEmergency then return end

    local currentDuty = Player.PlayerData.job.onduty
    local newDuty = not currentDuty

    -- Call original duty toggle function
    HandleDutyToggle(source, stationId)

    -- Log to Discord
    FL.Discord.LogDutyChange(source, service, newDuty, stationId)
end)

-- Hook into emergency call creation
local originalCreateEmergencyCall = CreateEmergencyCall
CreateEmergencyCall = function(callData)
    local callId = originalCreateEmergencyCall(callData)

    if callId then
        -- Add call ID to callData for logging
        callData.id = callId
        FL.Discord.LogEmergencyCall(callData, 'call_new')
    end

    return callId
end

-- Hook into call assignment
local originalAssignUnitToCall = AssignUnitToCall
AssignUnitToCall = function(callId, source)
    local success, message = originalAssignUnitToCall(callId, source)

    if success then
        local call = FL.Server.EmergencyCalls[callId]
        if call then
            FL.Discord.LogEmergencyCall(call, 'call_assigned')
        end
    end

    return success, message
end

-- Hook into call completion
local originalCompleteEmergencyCall = CompleteEmergencyCall
CompleteEmergencyCall = function(callId, source)
    local call = FL.Server.EmergencyCalls[callId]
    local success, message = originalCompleteEmergencyCall(callId, source)

    if success and call then
        FL.Discord.LogEmergencyCall(call, 'call_completed')
    end

    return success, message
end

-- ====================================================================
-- ADMIN COMMANDS WITH DISCORD LOGGING
-- ====================================================================

RegisterCommand('testcall', function(source, args, rawCommand)
    -- ... original testcall logic ...

    -- Log admin action
    local details = 'Created test call for service: ' .. (args[1] or 'unknown')
    FL.Discord.LogAdminAction(source, 'CREATE_TEST_CALL', details)
end, false)

RegisterCommand('clearcalls', function(source, args, rawCommand)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local hasPermission = QBCore.Functions.HasPermission(source, 'admin') or
        QBCore.Functions.HasPermission(source, 'god')

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, 'You need admin permissions', 'error')
        return
    end

    local service = args[1]
    local clearedCount = 0

    if service and FL.Functions.ValidateService(service) then
        -- Clear calls for specific service
        for callId, callData in pairs(FL.Server.EmergencyCalls) do
            if callData.service == service then
                FL.Server.EmergencyCalls[callId] = nil
                clearedCount = clearedCount + 1
            end
        end
    else
        -- Clear all calls
        clearedCount = FL.Functions.TableSize(FL.Server.EmergencyCalls)
        FL.Server.EmergencyCalls = {}
    end

    TriggerClientEvent('QBCore:Notify', source, 'Cleared ' .. clearedCount .. ' calls', 'success')

    -- Log admin action
    local details = 'Cleared ' .. clearedCount .. ' calls' .. (service and (' for ' .. service) or ' (all services)')
    FL.Discord.LogAdminAction(source, 'CLEAR_CALLS', details)
end, false)

-- ====================================================================
-- SCHEDULED REPORTS
-- ====================================================================

-- Daily statistics report (runs at midnight)
CreateThread(function()
    while true do
        local currentTime = os.date('*t')

        -- Check if it's midnight (00:00)
        if currentTime.hour == 0 and currentTime.min == 0 then
            FL.Discord.LogDailyStats()
            Wait(60000) -- Wait 1 minute to avoid duplicate sends
        end

        Wait(30000) -- Check every 30 seconds
    end
end)

-- ====================================================================
-- WEBHOOK CONFIGURATION CHECK
-- ====================================================================

CreateThread(function()
    Wait(5000) -- Wait for resource to fully load

    local missingWebhooks = {}
    for service, webhookUrl in pairs(FL.Discord.webhooks) do
        if webhookUrl == '' then
            table.insert(missingWebhooks, service)
        end
    end

    if #missingWebhooks > 0 then
        FL.Debug('⚠️ Missing Discord webhooks for: ' .. table.concat(missingWebhooks, ', '))
        FL.Debug('📝 Please configure webhooks in server/discord.lua')
    else
        FL.Debug('✅ All Discord webhooks configured')

        -- Send test message to admin webhook
        local embed = FL.Discord.CreateEmbed(
            '🚀 FL Emergency Services Started',
            'Discord integration loaded successfully',
            FL.Discord.colors.success,
            {
                {
                    name = '📊 Server Information',
                    value = '**Server:** ' .. (GetPlayerName(-1) or 'Unknown') .. '\n' ..
                        '**Resource:** fl_core\n' ..
                        '**Started:** <t:' .. os.time() .. ':F>',
                    inline = false
                }
            }
        )

        if FL.Discord.webhooks.admin ~= '' then
            FL.Discord.SendWebhook(FL.Discord.webhooks.admin, embed)
        end
    end
end)

FL.Debug('🔗 FL Core Discord integration loaded successfully')

-- ====================================================================
-- CONFIGURATION EXAMPLE
-- ====================================================================

--[[
HOW TO SETUP:

1. Create Discord Webhooks:
   - Go to your Discord server
   - Channel Settings > Integrations > Webhooks > New Webhook
   - Copy webhook URL
   - Paste into FL.Discord.webhooks above

2. Update webhook URLs:
   FL.Discord.webhooks = {
       fire = 'https://discord.com/api/webhooks/YOUR_FIRE_WEBHOOK',
       police = 'https://discord.com/api/webhooks/YOUR_POLICE_WEBHOOK',
       ems = 'https://discord.com/api/webhooks/YOUR_EMS_WEBHOOK',
       admin = 'https://discord.com/api/webhooks/YOUR_ADMIN_WEBHOOK',
       duty = 'https://discord.com/api/webhooks/YOUR_DUTY_WEBHOOK',
       emergency = 'https://discord.com/api/webhooks/YOUR_EMERGENCY_WEBHOOK'
   }

3. Recommended Discord Channels:
   - #fire-department
   - #police-department
   - #ems-department
   - #admin-logs
   - #duty-logs
   - #emergency-calls

4. Optional: Update server logo URLs in the code
]]
