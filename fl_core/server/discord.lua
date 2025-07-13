-- ====================================================================
-- FL CORE - DISCORD WEBHOOKS SYSTEM (FIXED VERSION)
-- Verwendet jetzt Config.Discord statt hardcoded URLs
-- ====================================================================

-- server/discord.lua - ERSETZE DEN GANZEN INHALT MIT DIESEM CODE

local QBCore = FL.GetFramework()

-- Discord Configuration - VERWENDET JETZT CONFIG.DISCORD
FL.Discord = {
    enabled = Config.Discord.enabled or false,
    webhooks = Config.Discord.webhooks or {},
    server_logo = Config.Discord.server_logo or 'https://i.imgur.com/default-logo.png',
    footer_icon = Config.Discord.footer_icon or 'https://i.imgur.com/default-footer.png',

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
    if not FL.Discord.enabled then
        FL.Debug('🔇 Discord webhooks disabled in config')
        return false
    end

    if not webhookUrl or webhookUrl == '' then
        FL.Debug('❌ No webhook URL provided')
        return false
    end

    retries = retries or 3

    local payload = {
        username = 'FL Emergency Services',
        avatar_url = FL.Discord.server_logo,
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
            text = 'FL Emergency Services • ' .. (GetConvar('sv_hostname', 'Unknown Server')),
            icon_url = FL.Discord.footer_icon
        }
    }

    return embed
end

-- ====================================================================
-- DUTY LOGGING
-- ====================================================================

function FL.Discord.LogDutyChange(source, service, onDuty, stationId)
    if not FL.Discord.enabled then return end

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
    if FL.Discord.webhooks.duty and FL.Discord.webhooks.duty ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks.duty, embed)
    end

    -- Also send to service-specific webhook
    if FL.Discord.webhooks[service] and FL.Discord.webhooks[service] ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed)
    end
end

-- ====================================================================
-- EMERGENCY CALL LOGGING
-- ====================================================================

function FL.Discord.LogEmergencyCall(callData, eventType)
    if not FL.Discord.enabled then return end

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
    if callData.priority == 1 and FL.Discord.webhooks.emergency and FL.Discord.webhooks.emergency ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks.emergency, embed)
    end

    -- Send to service-specific webhook
    if FL.Discord.webhooks[service] and FL.Discord.webhooks[service] ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed)
    end
end

-- ====================================================================
-- ADMIN LOGGING
-- ====================================================================

function FL.Discord.LogAdminAction(source, action, details)
    if not FL.Discord.enabled then return end

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

    if FL.Discord.webhooks.admin and FL.Discord.webhooks.admin ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks.admin, embed)
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

-- ====================================================================
-- STARTUP CHECK & TEST MESSAGE
-- ====================================================================

CreateThread(function()
    Wait(5000) -- Wait for resource to fully load

    if not FL.Discord.enabled then
        FL.Debug('🔇 Discord integration disabled in config')
        return
    end

    local missingWebhooks = {}
    for service, webhookUrl in pairs(FL.Discord.webhooks) do
        if not webhookUrl or webhookUrl == '' then
            table.insert(missingWebhooks, service)
        end
    end

    if #missingWebhooks > 0 then
        FL.Debug('⚠️ Missing Discord webhooks for: ' .. table.concat(missingWebhooks, ', '))
        FL.Debug('📝 Please configure webhooks in config.lua')
    else
        FL.Debug('✅ All Discord webhooks configured')

        -- Send test message to admin webhook
        local embed = FL.Discord.CreateEmbed(
            '🚀 FL Emergency Services Started',
            'Discord integration loaded successfully with Config.Discord',
            FL.Discord.colors.success,
            {
                {
                    name = '📊 Server Information',
                    value = '**Server:** ' .. (GetConvar('sv_hostname', 'Unknown Server')) .. '\n' ..
                        '**Resource:** fl_core\n' ..
                        '**Started:** <t:' .. os.time() .. ':F>',
                    inline = false
                },
                {
                    name = '🔗 Configured Webhooks',
                    value = '**Fire:** ' .. (FL.Discord.webhooks.fire and '✅' or '❌') .. '\n' ..
                        '**Police:** ' .. (FL.Discord.webhooks.police and '✅' or '❌') .. '\n' ..
                        '**EMS:** ' .. (FL.Discord.webhooks.ems and '✅' or '❌') .. '\n' ..
                        '**Admin:** ' .. (FL.Discord.webhooks.admin and '✅' or '❌') .. '\n' ..
                        '**Duty:** ' .. (FL.Discord.webhooks.duty and '✅' or '❌') .. '\n' ..
                        '**Emergency:** ' .. (FL.Discord.webhooks.emergency and '✅' or '❌'),
                    inline = false
                }
            }
        )

        if FL.Discord.webhooks.admin and FL.Discord.webhooks.admin ~= '' then
            FL.Discord.SendWebhook(FL.Discord.webhooks.admin, embed)
        end
    end
end)

-- ====================================================================
-- EVENT INTEGRATIONS (UNCHANGED)
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

-- Admin Commands mit Discord Logging
RegisterCommand('testcall', function(source, args, rawCommand)
    -- ... original testcall logic ...

    -- Log admin action
    local details = 'Created test call for service: ' .. (args[1] or 'unknown')
    FL.Discord.LogAdminAction(source, 'CREATE_TEST_CALL', details)
end, false)

FL.Debug('🔗 FL Core Discord integration loaded successfully (using Config.Discord)')
