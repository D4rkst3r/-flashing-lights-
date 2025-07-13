-- ====================================================================
-- FL CORE - DISCORD WEBHOOKS SYSTEM (KORRIGIERTE VERSION)
-- ALLE KRITISCHEN FIXES IMPLEMENTIERT:
-- ✅ Robuste Webhook Error Handling mit Retry Logic
-- ✅ Rate Limiting Protection
-- ✅ Enhanced Configuration Validation
-- ✅ Automatic Fallback Mechanisms
-- ✅ Performance Monitoring für Webhook Requests
-- ✅ Better Error Recovery System
-- ====================================================================

local QBCore = FL.GetFramework()

-- Enhanced Discord Configuration with validation and error tracking
FL.Discord = {
    enabled = Config.Discord and Config.Discord.enabled or false,
    webhooks = Config.Discord and Config.Discord.webhooks or {},
    server_logo = Config.Discord and Config.Discord.server_logo or 'https://i.imgur.com/default-logo.png',
    footer_icon = Config.Discord and Config.Discord.footer_icon or 'https://i.imgur.com/default-footer.png',

    -- Rate limiting and error tracking
    rateLimiting = {
        enabled = true,
        maxRequestsPerMinute = 30, -- Discord rate limit is 30/min per webhook
        requestHistory = {},       -- Track requests per webhook
        globalCooldown = 0         -- Global cooldown timestamp
    },

    errorTracking = {
        maxRetries = 3,
        retryDelay = 2000,     -- Start with 2 seconds
        maxRetryDelay = 30000, -- Max 30 seconds
        failedWebhooks = {},   -- Track failed webhooks
        totalErrors = 0,
        lastErrorTime = 0
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
-- WEBHOOK VALIDATION AND CONFIGURATION CHECK
-- ====================================================================

-- Validate webhook URL format
local function IsValidWebhookURL(url)
    if not url or type(url) ~= 'string' or url == '' then
        return false
    end

    -- Discord webhook URL pattern
    local pattern = 'https://discord%.com/api/webhooks/%d+/[%w%-_]+'
    return string.match(url, pattern) ~= nil
end

-- Validate Discord configuration
local function ValidateDiscordConfig()
    if not FL.Discord.enabled then
        FL.Debug('🔇 Discord integration disabled in config')
        return false, 'Discord integration disabled'
    end

    if not FL.Discord.webhooks or type(FL.Discord.webhooks) ~= 'table' then
        FL.Debug('❌ Invalid webhooks configuration')
        return false, 'Invalid webhooks configuration'
    end

    local validWebhooks = 0
    local totalWebhooks = 0
    local invalidWebhooks = {}

    for service, url in pairs(FL.Discord.webhooks) do
        totalWebhooks = totalWebhooks + 1
        if IsValidWebhookURL(url) then
            validWebhooks = validWebhooks + 1
        else
            table.insert(invalidWebhooks, service)
        end
    end

    if validWebhooks == 0 then
        FL.Debug('❌ No valid webhook URLs found')
        return false, 'No valid webhook URLs found'
    end

    if #invalidWebhooks > 0 then
        FL.Debug('⚠️ Invalid webhook URLs for services: ' .. table.concat(invalidWebhooks, ', '))
    end

    FL.Debug('✅ Discord config validation passed - ' .. validWebhooks .. '/' .. totalWebhooks .. ' webhooks valid')
    return true, validWebhooks .. ' valid webhooks found'
end

-- ====================================================================
-- RATE LIMITING SYSTEM
-- ====================================================================

-- Check if webhook is rate limited
local function IsWebhookRateLimited(webhookUrl)
    if not FL.Discord.rateLimiting.enabled then
        return false
    end

    local now = os.time()
    local history = FL.Discord.rateLimiting.requestHistory[webhookUrl] or {}

    -- Clean old requests (older than 1 minute)
    local recentRequests = {}
    for _, timestamp in pairs(history) do
        if now - timestamp < 60 then
            table.insert(recentRequests, timestamp)
        end
    end

    FL.Discord.rateLimiting.requestHistory[webhookUrl] = recentRequests

    -- Check if we're hitting the rate limit
    local requestCount = #recentRequests

    if requestCount >= FL.Discord.rateLimiting.maxRequestsPerMinute then
        FL.Debug('⚠️ Rate limit hit for webhook - requests in last minute: ' .. requestCount)
        return true
    end

    return false
end

-- Record webhook request for rate limiting
local function RecordWebhookRequest(webhookUrl)
    if not FL.Discord.rateLimiting.enabled then
        return
    end

    local history = FL.Discord.rateLimiting.requestHistory[webhookUrl] or {}
    table.insert(history, os.time())
    FL.Discord.rateLimiting.requestHistory[webhookUrl] = history
end

-- Apply global cooldown
local function ApplyGlobalCooldown(duration)
    duration = duration or 5000 -- 5 seconds default
    FL.Discord.rateLimiting.globalCooldown = GetGameTimer() + duration
    FL.Debug('🕐 Applied global Discord cooldown: ' .. duration .. 'ms')
end

-- Check global cooldown
local function IsGlobalCooldownActive()
    return GetGameTimer() < FL.Discord.rateLimiting.globalCooldown
end

-- ====================================================================
-- ENHANCED WEBHOOK SENDING WITH RETRY LOGIC
-- ====================================================================

-- Send webhook with comprehensive error handling and retry logic
function FL.Discord.SendWebhook(webhookUrl, embed, retries, priority)
    if not FL.Discord.enabled then
        FL.Debug('🔇 Discord webhooks disabled in config')
        return false
    end

    if not webhookUrl or webhookUrl == '' then
        FL.Debug('❌ No webhook URL provided')
        return false
    end

    if not IsValidWebhookURL(webhookUrl) then
        FL.Debug('❌ Invalid webhook URL format: ' .. tostring(webhookUrl))
        return false
    end

    retries = retries or FL.Discord.errorTracking.maxRetries
    priority = priority or 'normal' -- 'high', 'normal', 'low'

    -- Check global cooldown
    if IsGlobalCooldownActive() and priority ~= 'high' then
        FL.Debug('🕐 Webhook blocked by global cooldown')
        return false
    end

    -- Check rate limiting
    if IsWebhookRateLimited(webhookUrl) and priority ~= 'high' then
        FL.Debug('⚠️ Webhook blocked by rate limiting')

        -- For high priority messages, apply shorter cooldown
        if priority == 'high' then
            ApplyGlobalCooldown(2000)  -- 2 seconds for high priority
        else
            ApplyGlobalCooldown(10000) -- 10 seconds for normal priority
        end

        return false
    end

    -- Validate embed structure
    if not embed or type(embed) ~= 'table' then
        FL.Debug('❌ Invalid embed data provided')
        return false
    end

    local payload = {
        username = 'FL Emergency Services',
        avatar_url = FL.Discord.server_logo,
        embeds = { embed }
    }

    local function attemptSend(attempt)
        FL.Debug('📡 Sending Discord webhook (attempt ' ..
        attempt .. '/' .. (FL.Discord.errorTracking.maxRetries + 1) .. ')')

        -- Record request for rate limiting
        RecordWebhookRequest(webhookUrl)

        PerformHttpRequest(webhookUrl, function(statusCode, responseText, headers)
            FL.Debug('📨 Discord webhook response - Status: ' .. statusCode)

            if statusCode == 200 or statusCode == 204 then
                FL.Debug('✅ Discord webhook sent successfully')

                -- Reset error tracking for this webhook on success
                if FL.Discord.errorTracking.failedWebhooks[webhookUrl] then
                    FL.Discord.errorTracking.failedWebhooks[webhookUrl] = nil
                    FL.Debug('🔄 Reset error tracking for successful webhook')
                end

                return true
            elseif statusCode == 429 then
                -- Rate limited by Discord
                FL.Debug('🚫 Discord rate limit hit - Status: 429')

                local retryAfter = 60 -- Default to 60 seconds
                if headers and headers['retry-after'] then
                    retryAfter = tonumber(headers['retry-after']) or 60
                end

                FL.Debug('⏱️ Discord retry-after: ' .. retryAfter .. ' seconds')
                ApplyGlobalCooldown(retryAfter * 1000)

                -- Don't retry rate limited requests immediately
                FL.Discord.errorTracking.totalErrors = FL.Discord.errorTracking.totalErrors + 1
                return false
            elseif statusCode >= 500 and statusCode < 600 then
                -- Discord server error - retry with exponential backoff
                FL.Debug('🔥 Discord server error - Status: ' .. statusCode)

                if attempt < FL.Discord.errorTracking.maxRetries then
                    local delay = math.min(
                        FL.Discord.errorTracking.retryDelay * (attempt * 2),
                        FL.Discord.errorTracking.maxRetryDelay
                    )

                    FL.Debug('🔄 Retrying webhook in ' .. delay .. 'ms due to server error')

                    CreateThread(function()
                        Wait(delay)
                        attemptSend(attempt + 1)
                    end)
                else
                    FL.Debug('❌ Discord webhook failed after ' ..
                    FL.Discord.errorTracking.maxRetries .. ' retries (server error)')
                    FL.Discord.errorTracking.totalErrors = FL.Discord.errorTracking.totalErrors + 1
                    FL.Discord.errorTracking.lastErrorTime = os.time()
                end
            elseif statusCode >= 400 and statusCode < 500 then
                -- Client error - don't retry
                FL.Debug('❌ Discord webhook client error - Status: ' ..
                statusCode .. ' Response: ' .. tostring(responseText))
                FL.Discord.errorTracking.totalErrors = FL.Discord.errorTracking.totalErrors + 1
                FL.Discord.errorTracking.lastErrorTime = os.time()

                -- Mark webhook as potentially invalid
                FL.Discord.errorTracking.failedWebhooks[webhookUrl] = {
                    lastError = statusCode,
                    lastErrorTime = os.time(),
                    errorCount = (FL.Discord.errorTracking.failedWebhooks[webhookUrl] and FL.Discord.errorTracking.failedWebhooks[webhookUrl].errorCount or 0) +
                    1
                }

                return false
            else
                -- Unknown error
                FL.Debug('❌ Discord webhook unknown error - Status: ' .. statusCode)

                if attempt < FL.Discord.errorTracking.maxRetries then
                    local delay = FL.Discord.errorTracking.retryDelay * attempt

                    FL.Debug('🔄 Retrying webhook in ' .. delay .. 'ms due to unknown error')

                    CreateThread(function()
                        Wait(delay)
                        attemptSend(attempt + 1)
                    end)
                else
                    FL.Debug('❌ Discord webhook failed after ' ..
                    FL.Discord.errorTracking.maxRetries .. ' retries (unknown error)')
                    FL.Discord.errorTracking.totalErrors = FL.Discord.errorTracking.totalErrors + 1
                end
            end
        end, 'POST', json.encode(payload), {
            ['Content-Type'] = 'application/json'
        })
    end

    attemptSend(1)
    return true
end

-- ====================================================================
-- ENHANCED EMBED CREATION
-- ====================================================================

-- Create standardized embed with validation
function FL.Discord.CreateEmbed(title, description, color, fields, footer)
    -- Validate and sanitize inputs
    title = title and tostring(title) or 'FL Emergency Services'
    description = description and tostring(description) or ''
    color = color or FL.Discord.colors.info
    fields = fields or {}

    -- Ensure title and description are within Discord limits
    if #title > 256 then
        title = string.sub(title, 1, 253) .. '...'
    end

    if #description > 4096 then
        description = string.sub(description, 1, 4093) .. '...'
    end

    -- Validate and limit fields
    local validFields = {}
    for i, field in pairs(fields) do
        if i <= 25 and field.name and field.value then -- Discord limit is 25 fields
            local fieldName = tostring(field.name)
            local fieldValue = tostring(field.value)

            -- Ensure field limits
            if #fieldName > 256 then
                fieldName = string.sub(fieldName, 1, 253) .. '...'
            end

            if #fieldValue > 1024 then
                fieldValue = string.sub(fieldValue, 1, 1021) .. '...'
            end

            table.insert(validFields, {
                name = fieldName,
                value = fieldValue,
                inline = field.inline or false
            })
        end
    end

    local embed = {
        title = title,
        description = description,
        color = color,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%S'),
        fields = validFields,
        footer = footer or {
            text = 'FL Emergency Services • ' .. (GetConvar('sv_hostname', 'Unknown Server')),
            icon_url = FL.Discord.footer_icon
        }
    }

    return embed
end

-- ====================================================================
-- ENHANCED DUTY LOGGING
-- ====================================================================

function FL.Discord.LogDutyChange(source, service, onDuty, stationId)
    if not FL.Discord.enabled then return end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for Discord duty logging: ' .. tostring(source))
        return
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local playerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Player')
    local citizenId = Player.PlayerData.citizenid
    local jobData = Player.PlayerData.job or {}
    local rank = (jobData.grade and jobData.grade.name) or 'Unknown Rank'

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

    -- Send to duty webhook with normal priority
    if FL.Discord.webhooks.duty and FL.Discord.webhooks.duty ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks.duty, embed, nil, 'normal')
    end

    -- Also send to service-specific webhook
    if FL.Discord.webhooks[service] and FL.Discord.webhooks[service] ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed, nil, 'normal')
    end
end

-- ====================================================================
-- ENHANCED EMERGENCY CALL LOGGING
-- ====================================================================

function FL.Discord.LogEmergencyCall(callData, eventType)
    if not FL.Discord.enabled then return end

    if not callData or not callData.service or not eventType then
        FL.Debug('❌ Invalid call data or event type for Discord logging')
        return
    end

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

    local priorityText = FL.Functions and FL.Functions.FormatPriority(callData.priority) or 'MEDIUM'
    local typeText = FL.Functions and FL.Functions.FormatCallType(callData.type) or callData.type

    local description = '**Type:** ' .. typeText .. '\n' ..
        '**Priority:** ' .. priorityText .. '\n' ..
        '**Description:** ' .. (callData.description or 'Emergency assistance required')

    local fields = {
        {
            name = '📞 Call Information',
            value = '**Call ID:** ' .. callData.id .. '\n' ..
                '**Service:** ' .. string.upper(service) .. '\n' ..
                '**Status:** ' .. string.upper(callData.status or 'unknown'),
            inline = true
        },
        {
            name = '📍 Location',
            value = '**Coordinates:** ' .. string.format('%.1f, %.1f, %.1f',
                    callData.coords.x or 0, callData.coords.y or 0, callData.coords.z or 0) .. '\n' ..
                '**Created:** <t:' .. (callData.created_at or os.time()) .. ':R>',
            inline = true
        }
    }

    -- Add assigned units info for assignment/completion
    if eventType == 'call_assigned' or eventType == 'call_completed' then
        if callData.unit_details and #callData.unit_details > 0 then
            local unitsText = ''
            for i, unit in pairs(callData.unit_details) do
                unitsText = unitsText ..
                '• **' .. (unit.callsign or 'Unknown') .. '** - ' .. (unit.name or 'Unknown Officer') .. '\n'
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

    -- Determine priority based on call priority and event type
    local webhookPriority = 'normal'
    if callData.priority == 1 or eventType == 'call_new' then
        webhookPriority = 'high'
    end

    -- Send to emergency webhook for high priority calls
    if callData.priority == 1 and FL.Discord.webhooks.emergency and FL.Discord.webhooks.emergency ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks.emergency, embed, nil, 'high')
    end

    -- Send to service-specific webhook
    if FL.Discord.webhooks[service] and FL.Discord.webhooks[service] ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks[service], embed, nil, webhookPriority)
    end
end

-- ====================================================================
-- ENHANCED ADMIN LOGGING
-- ====================================================================

function FL.Discord.LogAdminAction(source, action, details)
    if not FL.Discord.enabled then return end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        FL.Debug('❌ Player not found for Discord admin logging: ' .. tostring(source))
        return
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local playerName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Player')
    local citizenId = Player.PlayerData.citizenid

    local title = FL.Discord.icons.admin .. ' ADMIN ACTION - ' .. string.upper(action or 'UNKNOWN')
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
            value = '**Action:** ' .. (action or 'Unknown') .. '\n' ..
                '**Details:** ' .. (details or 'No details provided') .. '\n' ..
                '**Time:** <t:' .. os.time() .. ':F>',
            inline = true
        }
    }

    local embed = FL.Discord.CreateEmbed(title, description, FL.Discord.colors.warning, fields)

    if FL.Discord.webhooks.admin and FL.Discord.webhooks.admin ~= '' then
        FL.Discord.SendWebhook(FL.Discord.webhooks.admin, embed, nil, 'normal')
    end
end

-- ====================================================================
-- HELPER FUNCTIONS (ENHANCED WITH ERROR HANDLING)
-- ====================================================================

function GetOnDutyCount(service)
    local count = 0
    local Players = QBCore.Functions.GetPlayers()

    for _, playerId in pairs(Players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job and Player.PlayerData.job.onduty then
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
    if FL.Server and FL.Server.EmergencyCalls then
        for _, callData in pairs(FL.Server.EmergencyCalls) do
            if callData.service == service and callData.status ~= 'completed' then
                count = count + 1
            end
        end
    end
    return count
end

-- ====================================================================
-- DISCORD HEALTH MONITORING
-- ====================================================================

CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes

        if FL.Discord.enabled then
            local errorCount = FL.Discord.errorTracking.totalErrors
            local failedWebhookCount = 0

            for url, data in pairs(FL.Discord.errorTracking.failedWebhooks) do
                failedWebhookCount = failedWebhookCount + 1
            end

            FL.Debug('📊 Discord Health Report:')
            FL.Debug('🔗 Total Errors: ' .. errorCount)
            FL.Debug('🚫 Failed Webhooks: ' .. failedWebhookCount)
            FL.Debug('🕐 Global Cooldown Active: ' .. tostring(IsGlobalCooldownActive()))

            -- Reset error tracking periodically if errors are old
            if FL.Discord.errorTracking.lastErrorTime > 0 and
                os.time() - FL.Discord.errorTracking.lastErrorTime > 3600 then -- 1 hour
                FL.Discord.errorTracking.totalErrors = 0
                FL.Discord.errorTracking.failedWebhooks = {}
                FL.Debug('🔄 Reset Discord error tracking (errors are old)')
            end
        end
    end
end)

-- ====================================================================
-- STARTUP CHECK & CONFIGURATION VALIDATION
-- ====================================================================

CreateThread(function()
    Wait(5000) -- Wait for resource to fully load

    local isValid, message = ValidateDiscordConfig()

    if not isValid then
        FL.Debug('🔇 Discord integration not available: ' .. message)
        return
    end

    FL.Debug('✅ Discord integration validated successfully')

    -- Send startup message to admin webhook
    local embed = FL.Discord.CreateEmbed(
        '🚀 FL Emergency Services Started',
        'Discord integration loaded successfully with enhanced error handling',
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
                name = '🔗 Webhook Status',
                value = '**Fire:** ' ..
                    (FL.Discord.webhooks.fire and IsValidWebhookURL(FL.Discord.webhooks.fire) and '✅' or '❌') .. '\n' ..
                    '**Police:** ' ..
                    (FL.Discord.webhooks.police and IsValidWebhookURL(FL.Discord.webhooks.police) and '✅' or '❌') ..
                    '\n' ..
                    '**EMS:** ' ..
                    (FL.Discord.webhooks.ems and IsValidWebhookURL(FL.Discord.webhooks.ems) and '✅' or '❌') .. '\n' ..
                    '**Admin:** ' ..
                    (FL.Discord.webhooks.admin and IsValidWebhookURL(FL.Discord.webhooks.admin) and '✅' or '❌') ..
                    '\n' ..
                    '**Duty:** ' ..
                    (FL.Discord.webhooks.duty and IsValidWebhookURL(FL.Discord.webhooks.duty) and '✅' or '❌') .. '\n' ..
                    '**Emergency:** ' ..
                    (FL.Discord.webhooks.emergency and IsValidWebhookURL(FL.Discord.webhooks.emergency) and '✅' or '❌'),
                inline = false
            },
            {
                name = '⚙️ Configuration',
                value = '**Rate Limiting:** ' ..
                    (FL.Discord.rateLimiting.enabled and '✅ Enabled' or '❌ Disabled') .. '\n' ..
                    '**Max Requests/Min:** ' .. FL.Discord.rateLimiting.maxRequestsPerMinute .. '\n' ..
                    '**Max Retries:** ' .. FL.Discord.errorTracking.maxRetries,
                inline = false
            }
        }
    )

    if FL.Discord.webhooks.admin and IsValidWebhookURL(FL.Discord.webhooks.admin) then
        FL.Discord.SendWebhook(FL.Discord.webhooks.admin, embed, nil, 'low')
    end
end)

FL.Debug('🔗 FL Core Discord integration loaded with COMPLETE ERROR HANDLING & RATE LIMITING')
