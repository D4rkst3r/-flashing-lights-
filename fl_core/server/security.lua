-- ====================================================================
-- FL EMERGENCY SERVICES - SECURITY & RATE LIMITING
-- ====================================================================

FL.Security = {
    rateLimits = {},

    -- Check if player exceeds rate limit
    checkRateLimit = function(source, action, limit, window)
        limit = limit or 10
        window = window or 60000 -- 1 minute default

        local now = GetGameTimer()
        local key = source .. '_' .. action
        local requests = self.rateLimits[key] or {}

        -- Clean old requests
        local cleanRequests = {}
        for _, timestamp in pairs(requests) do
            if now - timestamp <= window then
                table.insert(cleanRequests, timestamp)
            end
        end

        if #cleanRequests >= limit then
            FL.Debug('⚠️ Rate limit exceeded for player ' .. source .. ' action: ' .. action)
            return false, 'Rate limit exceeded. Please wait before trying again.'
        end

        -- Add current request
        table.insert(cleanRequests, now)
        self.rateLimits[key] = cleanRequests

        return true
    end,

    -- Clean old rate limit data
    cleanup = function()
        local now = GetGameTimer()
        local cleaned = 0

        for key, requests in pairs(self.rateLimits) do
            local cleanRequests = {}
            for _, timestamp in pairs(requests) do
                if now - timestamp <= 300000 then -- Keep 5 minutes of data
                    table.insert(cleanRequests, timestamp)
                end
            end

            if #cleanRequests == 0 then
                self.rateLimits[key] = nil
                cleaned = cleaned + 1
            else
                self.rateLimits[key] = cleanRequests
            end
        end

        if cleaned > 0 then
            FL.Debug('🧹 Cleaned ' .. cleaned .. ' old rate limit entries')
        end
    end
}

-- Rate limit middleware for server events
function FL.RateLimitMiddleware(eventName, limit, window)
    return function(handler)
        return function(...)
            local success, message = FL.Security.checkRateLimit(source, eventName, limit, window)

            if not success then
                TriggerClientEvent('QBCore:Notify', source, message, 'error')
                return
            end

            -- Call original handler
            handler(...)
        end
    end
end

-- Cleanup thread
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        FL.Security.cleanup()
    end
end)

FL.Debug('🛡️ Security system loaded')
