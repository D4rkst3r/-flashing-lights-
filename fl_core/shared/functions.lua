-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - SHARED FUNCTIONS (FIVEM KOMPATIBLE VERSION)
-- ALLE KRITISCHEN FIXES IMPLEMENTIERT + FIVEM KOMPATIBILITÄT:
-- ✅ FiveM-kompatible Zeit-Funktionen (ohne os.date/os.time)
-- ✅ Enhanced Input Validation für alle Funktionen
-- ✅ Null-Safety für alle Parameter und Return Values
-- ✅ Better Error Handling mit Try-Catch Pattern
-- ✅ Performance Optimierungen für häufig genutzte Funktionen
-- ✅ Extended Utility Functions für bessere Code-Reuse
-- ✅ Robust Framework Integration mit Fallbacks
-- ====================================================================

-- Initialize FL namespace with validation
if not FL then
    FL = {}
    print('^3[FL-SHARED]^7 Initialized FL namespace')
end

if not FL.Functions then
    FL.Functions = {}
end

-- Framework integration with enhanced error handling
FL.QBCore = nil
FL.FrameworkReady = false
FL.InitializationAttempts = 0
FL.MaxInitializationAttempts = 10

-- FiveM-compatible time functions
FL.TimeUtils = {
    -- Get current timestamp (FiveM compatible)
    getTimestamp = function()
        return GetGameTimer()
    end,

    -- Get formatted time (FiveM compatible)
    getFormattedTime = function()
        local gameTimer = GetGameTimer()
        local hours = math.floor(gameTimer / 3600000) % 24
        local minutes = math.floor(gameTimer / 60000) % 60
        local seconds = math.floor(gameTimer / 1000) % 60
        return string.format('%02d:%02d:%02d', hours, minutes, seconds)
    end,

    -- Get Unix timestamp equivalent
    getUnixTime = function()
        -- Approximate Unix timestamp based on game timer
        -- This is not exact but works for relative timing
        local baseTime = 1640995200 -- Jan 1, 2022 as base
        return baseTime + math.floor(GetGameTimer() / 1000)
    end
}

-- ====================================================================
-- FRAMEWORK INTEGRATION (ENHANCED WITH RETRY LOGIC)
-- ====================================================================

-- Get QBCore framework instance with retry logic
function FL.GetFramework()
    if FL.QBCore and FL.FrameworkReady then
        return FL.QBCore
    end

    FL.InitializationAttempts = FL.InitializationAttempts + 1

    if FL.InitializationAttempts > FL.MaxInitializationAttempts then
        FL.Debug('❌ CRITICAL: Failed to initialize framework after ' .. FL.MaxInitializationAttempts .. ' attempts')
        return nil
    end

    local success, framework = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if success and framework then
        FL.QBCore = framework
        FL.FrameworkReady = true
        FL.Debug('✅ Framework initialized successfully on attempt ' .. FL.InitializationAttempts)
        return FL.QBCore
    else
        FL.Debug('⚠️ Framework initialization failed on attempt ' ..
            FL.InitializationAttempts .. ': ' .. tostring(framework))
        return nil
    end
end

-- Safe framework getter with fallback
function FL.GetFrameworkSafe()
    local framework = FL.GetFramework()
    if framework then
        return framework
    end

    -- Fallback attempt
    CreateThread(function()
        Wait(1000)
        FL.GetFramework()
    end)

    return nil
end

-- ====================================================================
-- ENHANCED DEBUG SYSTEM (FIVEM KOMPATIBEL)
-- ====================================================================

-- Debug function with enhanced features (FiveM compatible)
function FL.Debug(message, level, category)
    if not Config or not Config.Debug then
        return
    end

    -- Validate inputs
    message = tostring(message or 'nil')
    level = level or 'INFO'
    category = category or 'GENERAL'

    -- Add timestamp (FiveM compatible)
    local timestamp = FL.TimeUtils.getFormattedTime()

    -- Color coding based on level
    local colors = {
        ERROR = '^1', -- Red
        WARN = '^3',  -- Yellow
        INFO = '^2',  -- Green
        DEBUG = '^6'  -- Purple
    }

    local color = colors[level] or '^7' -- White default

    print(color .. '[FL-' .. category .. ' ' .. level .. ' ' .. timestamp .. ']^7 ' .. message)
end

-- Performance profiler for functions
FL.Profiler = {
    enabled = false,
    timings = {},
    calls = {}
}

function FL.StartProfile(functionName)
    if not FL.Profiler.enabled then return end

    functionName = tostring(functionName or 'unknown')
    FL.Profiler.timings[functionName] = GetGameTimer()
end

function FL.EndProfile(functionName)
    if not FL.Profiler.enabled then return end

    functionName = tostring(functionName or 'unknown')
    local startTime = FL.Profiler.timings[functionName]

    if startTime then
        local duration = GetGameTimer() - startTime
        FL.Profiler.calls[functionName] = (FL.Profiler.calls[functionName] or 0) + 1
        FL.Debug('⏱️ ' .. functionName .. ' took ' .. duration .. 'ms (call #' .. FL.Profiler.calls[functionName] .. ')',
            'DEBUG', 'PROFILER')
        FL.Profiler.timings[functionName] = nil
    end
end

-- ====================================================================
-- SAFE UTILITY FUNCTIONS (ENHANCED WITH NULL-SAFETY)
-- ====================================================================

-- Safe string operations
FL.SafeString = {
    -- Safe string length
    len = function(str)
        if not str or type(str) ~= 'string' then
            return 0
        end
        return string.len(str)
    end,

    -- Safe string substring
    sub = function(str, start, finish)
        if not str or type(str) ~= 'string' then
            return ''
        end
        start = tonumber(start) or 1
        finish = tonumber(finish) or string.len(str)
        return string.sub(str, start, finish)
    end,

    -- Safe string formatting
    format = function(fmt, ...)
        if not fmt or type(fmt) ~= 'string' then
            return ''
        end

        local success, result = pcall(string.format, fmt, ...)
        if success then
            return result
        else
            FL.Debug('⚠️ String format error: ' .. tostring(result), 'WARN', 'SAFE_STRING')
            return fmt
        end
    end,

    -- Safe string to number conversion
    toNumber = function(str, default)
        if not str then
            return default or 0
        end

        local num = tonumber(str)
        return num or (default or 0)
    end
}

-- Safe table operations
FL.SafeTable = {
    -- Safe table size calculation
    size = function(tbl)
        if not tbl or type(tbl) ~= 'table' then
            return 0
        end

        local count = 0
        for _ in pairs(tbl) do
            count = count + 1
        end
        return count
    end,

    -- Safe table key check
    hasKey = function(tbl, key)
        if not tbl or type(tbl) ~= 'table' then
            return false
        end
        return tbl[key] ~= nil
    end,

    -- Safe table value retrieval
    getValue = function(tbl, key, default)
        if not tbl or type(tbl) ~= 'table' then
            return default
        end

        local value = tbl[key]
        return value ~= nil and value or default
    end,

    -- Safe table merge
    merge = function(target, source)
        if not target or type(target) ~= 'table' then
            target = {}
        end

        if not source or type(source) ~= 'table' then
            return target
        end

        for key, value in pairs(source) do
            target[key] = value
        end

        return target
    end
}

-- ====================================================================
-- EMERGENCY SERVICE FUNCTIONS (ENHANCED WITH VALIDATION)
-- ====================================================================

-- Check if player has emergency service job (enhanced validation)
function FL.Functions.IsEmergencyService(jobname)
    if not jobname or type(jobname) ~= 'string' or jobname == '' then
        return false
    end

    if not Config or not Config.EmergencyServices then
        FL.Debug('❌ Config.EmergencyServices not available', 'ERROR', 'VALIDATION')
        return false
    end

    return Config.EmergencyServices[jobname] ~= nil
end

-- Get emergency service data with comprehensive validation
function FL.Functions.GetServiceData(serviceName)
    FL.StartProfile('GetServiceData')

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name provided to GetServiceData: ' .. tostring(serviceName), 'ERROR', 'VALIDATION')
        FL.EndProfile('GetServiceData')
        return nil
    end

    if not Config or not Config.EmergencyServices then
        FL.Debug('❌ Config.EmergencyServices not available', 'ERROR', 'CONFIG')
        FL.EndProfile('GetServiceData')
        return nil
    end

    local serviceData = Config.EmergencyServices[serviceName]

    if not serviceData then
        FL.Debug('⚠️ Service data not found for: ' .. serviceName, 'WARN', 'SERVICE')
        FL.EndProfile('GetServiceData')
        return nil
    end

    -- Validate service data structure
    local requiredFields = { 'label', 'shortname', 'color', 'blip' }
    for _, field in pairs(requiredFields) do
        if not serviceData[field] then
            FL.Debug('⚠️ Missing required field "' .. field .. '" in service data for: ' .. serviceName, 'WARN',
                'VALIDATION')
        end
    end

    FL.EndProfile('GetServiceData')
    return serviceData
end

-- Get station data by ID with validation
function FL.Functions.GetStationData(stationId)
    FL.StartProfile('GetStationData')

    if not stationId or type(stationId) ~= 'string' or stationId == '' then
        FL.Debug('❌ Invalid station ID provided: ' .. tostring(stationId), 'ERROR', 'VALIDATION')
        FL.EndProfile('GetStationData')
        return nil
    end

    if not Config or not Config.Stations then
        FL.Debug('❌ Config.Stations not available', 'ERROR', 'CONFIG')
        FL.EndProfile('GetStationData')
        return nil
    end

    local stationData = Config.Stations[stationId]

    if not stationData then
        FL.Debug('⚠️ Station data not found for: ' .. stationId, 'WARN', 'STATION')
        FL.EndProfile('GetStationData')
        return nil
    end

    -- Validate station data structure
    local requiredFields = { 'service', 'name', 'coords' }
    for _, field in pairs(requiredFields) do
        if not stationData[field] then
            FL.Debug('⚠️ Missing required field "' .. field .. '" in station data for: ' .. stationId, 'WARN',
                'VALIDATION')
        end
    end

    FL.EndProfile('GetStationData')
    return stationData
end

-- Get stations for specific service with enhanced filtering
function FL.Functions.GetServiceStations(serviceName)
    FL.StartProfile('GetServiceStations')

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name provided to GetServiceStations: ' .. tostring(serviceName), 'ERROR',
            'VALIDATION')
        FL.EndProfile('GetServiceStations')
        return {}
    end

    if not Config or not Config.Stations then
        FL.Debug('❌ Config.Stations not available', 'ERROR', 'CONFIG')
        FL.EndProfile('GetServiceStations')
        return {}
    end

    local stations = {}
    local stationCount = 0

    for stationId, stationData in pairs(Config.Stations) do
        if stationData and stationData.service == serviceName then
            stations[stationId] = stationData
            stationCount = stationCount + 1
        end
    end

    FL.Debug('✅ Found ' .. stationCount .. ' stations for service: ' .. serviceName, 'INFO', 'SERVICE')
    FL.EndProfile('GetServiceStations')
    return stations
end

-- ====================================================================
-- COORDINATE AND DISTANCE FUNCTIONS (ENHANCED)
-- ====================================================================

-- Calculate distance between two coordinates with validation
function FL.Functions.GetDistance(coords1, coords2)
    FL.StartProfile('GetDistance')

    -- Validate inputs
    if not coords1 or not coords2 then
        FL.Debug('❌ Invalid coordinates provided to GetDistance', 'ERROR', 'VALIDATION')
        FL.EndProfile('GetDistance')
        return 0
    end

    -- Convert to vector3 if needed with validation
    local function toVector3Safe(coords)
        if type(coords) == 'vector3' then
            return coords
        elseif type(coords) == 'table' and coords.x and coords.y and coords.z then
            return vector3(
                tonumber(coords.x) or 0,
                tonumber(coords.y) or 0,
                tonumber(coords.z) or 0
            )
        else
            FL.Debug('⚠️ Invalid coordinate format in GetDistance', 'WARN', 'VALIDATION')
            return vector3(0, 0, 0)
        end
    end

    local vec1 = toVector3Safe(coords1)
    local vec2 = toVector3Safe(coords2)

    local distance = #(vec1 - vec2)

    FL.EndProfile('GetDistance')
    return distance
end

-- Enhanced coordinate validation
function FL.Functions.ValidateCoords(coords)
    if not coords then
        return false, 'Coordinates are nil'
    end

    if type(coords) == 'vector3' then
        -- Check for NaN or infinite values
        local x, y, z = coords.x, coords.y, coords.z
        if x ~= x or y ~= y or z ~= z then -- NaN check
            return false, 'Coordinates contain NaN values'
        end
        if x == math.huge or y == math.huge or z == math.huge or
            x == -math.huge or y == -math.huge or z == -math.huge then
            return false, 'Coordinates contain infinite values'
        end
        return true, 'Valid vector3 coordinates'
    elseif type(coords) == 'table' and coords.x and coords.y and coords.z then
        local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
        if not x or not y or not z then
            return false, 'Coordinates contain non-numeric values'
        end
        -- Check for reasonable coordinate ranges (San Andreas map)
        if x < -4000 or x > 4000 or y < -4000 or y > 4000 or z < -1000 or z > 1000 then
            return false, 'Coordinates outside reasonable map bounds'
        end
        return true, 'Valid table coordinates'
    end

    return false, 'Invalid coordinate format'
end

-- ====================================================================
-- UNIFORM FUNCTIONS (ENHANCED WITH VALIDATION)
-- ====================================================================

-- Get uniform data for service and gender with comprehensive validation
function FL.Functions.GetUniform(serviceName, gender)
    FL.StartProfile('GetUniform')

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name for uniform: ' .. tostring(serviceName), 'ERROR', 'VALIDATION')
        FL.EndProfile('GetUniform')
        return nil
    end

    if gender ~= 0 and gender ~= 1 then
        FL.Debug('⚠️ Invalid gender for uniform (expected 0 or 1): ' .. tostring(gender), 'WARN', 'VALIDATION')
        gender = 1 -- Default to male
    end

    if not Config or not Config.Uniforms then
        FL.Debug('❌ Config.Uniforms not available', 'ERROR', 'CONFIG')
        FL.EndProfile('GetUniform')
        return nil
    end

    if not Config.Uniforms[serviceName] then
        FL.Debug('❌ No uniform found for service: ' .. serviceName, 'ERROR', 'UNIFORM')
        FL.EndProfile('GetUniform')
        return nil
    end

    local genderKey = (gender == 0) and 'female' or 'male'
    local uniform = Config.Uniforms[serviceName][genderKey]

    if not uniform then
        FL.Debug('❌ No uniform found for service: ' .. serviceName .. ', gender: ' .. genderKey, 'ERROR', 'UNIFORM')
        FL.EndProfile('GetUniform')
        return nil
    end

    -- Validate uniform data structure
    local requiredFields = { 'tshirt_1', 'torso_1', 'arms', 'pants_1', 'shoes_1' }
    for _, field in pairs(requiredFields) do
        if uniform[field] == nil then
            FL.Debug('⚠️ Missing uniform field "' .. field .. '" for service: ' .. serviceName, 'WARN', 'UNIFORM')
        end
    end

    FL.EndProfile('GetUniform')
    return uniform
end

-- Check if player is wearing service uniform (enhanced validation)
function FL.Functions.IsWearingUniform(ped, serviceName)
    FL.StartProfile('IsWearingUniform')

    if not ped or ped <= 0 then
        FL.Debug('❌ Invalid ped for uniform check: ' .. tostring(ped), 'ERROR', 'VALIDATION')
        FL.EndProfile('IsWearingUniform')
        return false
    end

    if not DoesEntityExist(ped) then
        FL.Debug('❌ Ped does not exist for uniform check: ' .. ped, 'ERROR', 'VALIDATION')
        FL.EndProfile('IsWearingUniform')
        return false
    end

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name for uniform check: ' .. tostring(serviceName), 'ERROR', 'VALIDATION')
        FL.EndProfile('IsWearingUniform')
        return false
    end

    local gender = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') and 0 or 1
    local uniform = FL.Functions.GetUniform(serviceName, gender)

    if not uniform then
        FL.EndProfile('IsWearingUniform')
        return false
    end

    -- Check key uniform pieces with error handling
    local success, currentTorso = pcall(GetPedDrawableVariation, ped, 11)
    if not success then
        FL.Debug('❌ Failed to get ped torso variation', 'ERROR', 'PED')
        FL.EndProfile('IsWearingUniform')
        return false
    end

    local success2, currentPants = pcall(GetPedDrawableVariation, ped, 4)
    if not success2 then
        FL.Debug('❌ Failed to get ped pants variation', 'ERROR', 'PED')
        FL.EndProfile('IsWearingUniform')
        return false
    end

    local isWearing = (currentTorso == uniform.torso_1) and (currentPants == uniform.pants_1)

    FL.EndProfile('IsWearingUniform')
    return isWearing
end

-- ====================================================================
-- EQUIPMENT FUNCTIONS (ENHANCED WITH VALIDATION)
-- ====================================================================

-- Get equipment list for service with validation
function FL.Functions.GetServiceEquipment(serviceName)
    FL.StartProfile('GetServiceEquipment')

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name for equipment: ' .. tostring(serviceName), 'ERROR', 'VALIDATION')
        FL.EndProfile('GetServiceEquipment')
        return {}
    end

    if not Config or not Config.Equipment then
        FL.Debug('❌ Config.Equipment not available', 'ERROR', 'CONFIG')
        FL.EndProfile('GetServiceEquipment')
        return {}
    end

    local equipment = Config.Equipment[serviceName] or {}

    -- Validate equipment items
    local validEquipment = {}
    for _, item in pairs(equipment) do
        if item and type(item) == 'string' and item ~= '' then
            table.insert(validEquipment, item)
        else
            FL.Debug('⚠️ Invalid equipment item for service ' .. serviceName .. ': ' .. tostring(item), 'WARN',
                'EQUIPMENT')
        end
    end

    FL.Debug('✅ Found ' .. #validEquipment .. ' equipment items for service: ' .. serviceName, 'INFO', 'EQUIPMENT')
    FL.EndProfile('GetServiceEquipment')
    return validEquipment
end

-- Check if item is service equipment with validation
function FL.Functions.IsServiceEquipment(itemName, serviceName)
    if not itemName or type(itemName) ~= 'string' or itemName == '' then
        return false
    end

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        return false
    end

    local equipment = FL.Functions.GetServiceEquipment(serviceName)
    for _, item in pairs(equipment) do
        if item == itemName then
            return true
        end
    end
    return false
end

-- ====================================================================
-- EMERGENCY CALL FUNCTIONS (ENHANCED)
-- ====================================================================

-- Get emergency call types for service with validation
function FL.Functions.GetEmergencyCallTypes(serviceName)
    FL.StartProfile('GetEmergencyCallTypes')

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name for call types: ' .. tostring(serviceName), 'ERROR', 'VALIDATION')
        FL.EndProfile('GetEmergencyCallTypes')
        return {}
    end

    if not Config or not Config.EmergencyCalls then
        FL.Debug('❌ Config.EmergencyCalls not available', 'ERROR', 'CONFIG')
        FL.EndProfile('GetEmergencyCallTypes')
        return {}
    end

    local callTypes = Config.EmergencyCalls[serviceName] or {}

    FL.EndProfile('GetEmergencyCallTypes')
    return callTypes
end

-- Generate random emergency call with enhanced validation
function FL.Functions.GenerateEmergencyCall(serviceName)
    FL.StartProfile('GenerateEmergencyCall')

    if not serviceName or type(serviceName) ~= 'string' or serviceName == '' then
        FL.Debug('❌ Invalid service name for call generation: ' .. tostring(serviceName), 'ERROR', 'VALIDATION')
        FL.EndProfile('GenerateEmergencyCall')
        return nil
    end

    local callTypes = FL.Functions.GetEmergencyCallTypes(serviceName)
    if #callTypes == 0 then
        FL.Debug('❌ No call types available for service: ' .. serviceName, 'ERROR', 'CALLS')
        FL.EndProfile('GenerateEmergencyCall')
        return nil
    end

    local randomType = callTypes[math.random(1, #callTypes)]

    -- Generate random location within reasonable bounds
    local randomCoords = vector3(
        math.random(-3000, 3000),
        math.random(-3000, 3000),
        math.random(0, 500)
    )

    local emergencyCall = {
        id = math.random(10000, 99999),
        type = randomType,
        service = serviceName,
        coords = randomCoords,
        timestamp = FL.TimeUtils.getUnixTime(),
        status = 'pending',
        priority = math.random(1, 3),
        description = FL.Functions.GetCallDescription(randomType),
        created_at = FL.TimeUtils.getUnixTime()
    }

    FL.EndProfile('GenerateEmergencyCall')
    return emergencyCall
end

-- Get call description based on type with fallback
function FL.Functions.GetCallDescription(callType)
    if not callType or type(callType) ~= 'string' or callType == '' then
        return 'Emergency assistance required'
    end

    local descriptions = {
        -- Fire descriptions
        ['structure_fire'] = 'Structure fire reported, multiple units requested',
        ['vehicle_fire'] = 'Vehicle fire on roadway, traffic hazard',
        ['wildfire'] = 'Vegetation fire spreading rapidly',
        ['rescue_operation'] = 'Person trapped, rescue equipment needed',
        ['hazmat_incident'] = 'Hazardous materials incident, specialized team required',

        -- Police descriptions
        ['robbery'] = 'Armed robbery in progress, suspects on scene',
        ['traffic_stop'] = 'Traffic violation, backup requested',
        ['domestic_disturbance'] = 'Domestic dispute, handle with caution',
        ['pursuit'] = 'High-speed pursuit, multiple units needed',
        ['theft'] = 'Theft reported, suspect description available',
        ['assault'] = 'Assault in progress, immediate response required',

        -- EMS descriptions
        ['cardiac_arrest'] = 'Cardiac arrest, CPR in progress',
        ['traffic_accident'] = 'Motor vehicle accident with injuries',
        ['overdose'] = 'Possible drug overdose, naloxone may be needed',
        ['fall_injury'] = 'Fall from height, possible spinal injury',
        ['gunshot_wound'] = 'Gunshot wound, trauma team on standby',
        ['medical_emergency'] = 'Medical emergency, nature unknown'
    }

    return descriptions[callType] or 'Emergency assistance required'
end

-- ====================================================================
-- VALIDATION FUNCTIONS (ENHANCED)
-- ====================================================================

-- Validate service name with detailed feedback
function FL.Functions.ValidateService(serviceName)
    if not serviceName then
        return false, 'Service name is nil'
    end

    if type(serviceName) ~= 'string' then
        return false, 'Service name must be a string'
    end

    if serviceName == '' then
        return false, 'Service name cannot be empty'
    end

    if not Config or not Config.EmergencyServices then
        return false, 'Emergency services configuration not available'
    end

    if Config.EmergencyServices[serviceName] == nil then
        return false, 'Service "' .. serviceName .. '" not found in configuration'
    end

    return true, 'Valid service name'
end

-- Validate station ID with detailed feedback
function FL.Functions.ValidateStation(stationId)
    if not stationId then
        return false, 'Station ID is nil'
    end

    if type(stationId) ~= 'string' then
        return false, 'Station ID must be a string'
    end

    if stationId == '' then
        return false, 'Station ID cannot be empty'
    end

    if not Config or not Config.Stations then
        return false, 'Stations configuration not available'
    end

    if Config.Stations[stationId] == nil then
        return false, 'Station "' .. stationId .. '" not found in configuration'
    end

    return true, 'Valid station ID'
end

-- ====================================================================
-- FORMATTING FUNCTIONS (ENHANCED WITH ERROR HANDLING + FIVEM KOMPATIBEL)
-- ====================================================================

-- Format time for display with validation (FiveM compatible)
function FL.Functions.FormatTime(timestamp)
    if not timestamp then
        return 'Unknown'
    end

    local num_timestamp = tonumber(timestamp)
    if not num_timestamp then
        return 'Invalid'
    end

    -- FiveM-compatible time formatting
    local hours = math.floor(num_timestamp / 3600) % 24
    local minutes = math.floor(num_timestamp / 60) % 60
    local seconds = num_timestamp % 60

    return string.format('%02d:%02d:%02d', hours, minutes, seconds)
end

-- Format date for display with validation (FiveM compatible)
function FL.Functions.FormatDate(timestamp)
    if not timestamp then
        return 'Unknown'
    end

    local num_timestamp = tonumber(timestamp)
    if not num_timestamp then
        return 'Invalid'
    end

    -- Simple date formatting (basic approach for FiveM)
    local days = math.floor(num_timestamp / 86400)
    local month = ((days % 365) / 30) + 1
    local day = (days % 30) + 1
    local year = 2024 + math.floor(days / 365)

    return string.format('%02d/%02d/%04d', math.floor(month), math.floor(day), math.floor(year))
end

-- Format distance for display with validation
function FL.Functions.FormatDistance(distance)
    local num_distance = tonumber(distance)
    if not num_distance then
        return 'Unknown'
    end

    if num_distance < 0 then
        return '0m'
    end

    if num_distance < 1000 then
        return string.format('%.0fm', num_distance)
    else
        return string.format('%.1fkm', num_distance / 1000)
    end
end

-- Format priority for display with validation
function FL.Functions.FormatPriority(priority)
    local priorities = {
        [1] = 'HIGH',
        [2] = 'MEDIUM',
        [3] = 'LOW'
    }

    local num_priority = tonumber(priority)
    if not num_priority then
        return 'UNKNOWN'
    end

    return priorities[num_priority] or 'UNKNOWN'
end

-- Format call type for display
function FL.Functions.FormatCallType(callType)
    if not callType or type(callType) ~= 'string' or callType == '' then
        return 'Unknown'
    end

    local formatted = callType:gsub('_', ' ')
    formatted = formatted:gsub('%b()', '')           -- Remove anything in parentheses
    formatted = formatted:gsub('%s+', ' ')           -- Multiple spaces to single space
    formatted = formatted:gsub('^%s*(.-)%s*$', '%1') -- Trim whitespace

    -- Capitalize first letter of each word
    formatted = formatted:gsub('(%a)([%w_]*)', function(first, rest)
        return first:upper() .. rest:lower()
    end)

    return formatted
end

-- ====================================================================
-- TABLE FUNCTIONS (ENHANCED WITH ERROR HANDLING)
-- ====================================================================

-- Deep copy table with circular reference protection
function FL.Functions.DeepCopy(orig, seen)
    seen = seen or {}

    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        if seen[orig] then
            FL.Debug('⚠️ Circular reference detected in DeepCopy', 'WARN', 'TABLE')
            return seen[orig]
        end

        copy = {}
        seen[orig] = copy

        for orig_key, orig_value in next, orig, nil do
            copy[FL.Functions.DeepCopy(orig_key, seen)] = FL.Functions.DeepCopy(orig_value, seen)
        end

        local mt = getmetatable(orig)
        if mt then
            setmetatable(copy, FL.Functions.DeepCopy(mt, seen))
        end
    else
        copy = orig
    end

    return copy
end

-- Check if table is empty with validation
function FL.Functions.IsTableEmpty(t)
    if not t or type(t) ~= 'table' then
        return true
    end
    return next(t) == nil
end

-- Get table size with validation
function FL.Functions.TableSize(t)
    if not t or type(t) ~= 'table' then
        return 0
    end

    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Safe table access with path (e.g., "player.job.grade.level")
function FL.Functions.GetTablePath(tbl, path, default)
    if not tbl or type(tbl) ~= 'table' then
        return default
    end

    if not path or type(path) ~= 'string' or path == '' then
        return default
    end

    local current = tbl
    for key in path:gmatch('[^%.]+') do
        if type(current) ~= 'table' or current[key] == nil then
            return default
        end
        current = current[key]
    end

    return current
end

-- ====================================================================
-- MATHEMATICAL FUNCTIONS (ENHANCED)
-- ====================================================================

-- Safe number operations
FL.SafeMath = {
    -- Safe addition
    add = function(a, b)
        local num_a = tonumber(a) or 0
        local num_b = tonumber(b) or 0
        return num_a + num_b
    end,

    -- Safe subtraction
    sub = function(a, b)
        local num_a = tonumber(a) or 0
        local num_b = tonumber(b) or 0
        return num_a - num_b
    end,

    -- Safe multiplication
    mul = function(a, b)
        local num_a = tonumber(a) or 0
        local num_b = tonumber(b) or 0
        return num_a * num_b
    end,

    -- Safe division
    div = function(a, b)
        local num_a = tonumber(a) or 0
        local num_b = tonumber(b) or 1
        if num_b == 0 then
            FL.Debug('⚠️ Division by zero attempted', 'WARN', 'MATH')
            return 0
        end
        return num_a / num_b
    end,

    -- Safe percentage calculation
    percent = function(value, total)
        local num_value = tonumber(value) or 0
        local num_total = tonumber(total) or 1
        if num_total == 0 then
            return 0
        end
        return (num_value / num_total) * 100
    end,

    -- Clamp value between min and max
    clamp = function(value, min, max)
        local num_value = tonumber(value) or 0
        local num_min = tonumber(min) or 0
        local num_max = tonumber(max) or 100

        if num_min > num_max then
            num_min, num_max = num_max, num_min
        end

        return math.max(num_min, math.min(num_max, num_value))
    end
}

-- ====================================================================
-- CLEANUP AND INITIALIZATION
-- ====================================================================

-- Initialize shared functions
CreateThread(function()
    -- Wait a bit for config to load
    Wait(1000)

    FL.Debug('🚀 FL Shared Functions initialized', 'INFO', 'INIT')
    FL.Debug('📊 Available functions: ' .. FL.SafeTable.size(FL.Functions), 'INFO', 'INIT')

    -- Validate critical config sections
    local configSections = { 'EmergencyServices', 'Stations', 'Uniforms', 'Equipment' }
    for _, section in pairs(configSections) do
        if Config and Config[section] then
            FL.Debug('✅ Config.' .. section .. ' loaded with ' .. FL.SafeTable.size(Config[section]) .. ' entries',
                'INFO', 'CONFIG')
        else
            FL.Debug('⚠️ Config.' .. section .. ' not available', 'WARN', 'CONFIG')
        end
    end

    FL.Debug('🕒 Time system: ' .. FL.TimeUtils.getFormattedTime(), 'INFO', 'TIME')
end)

FL.Debug('📚 Shared functions loaded successfully with ENHANCED VALIDATION & FIVEM COMPATIBILITY')
