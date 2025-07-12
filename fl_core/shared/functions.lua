-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - SHARED FUNCTIONS
-- ====================================================================

-- Initialize FL namespace
if not FL then FL = {} end
if not FL.Functions then FL.Functions = {} end

-- Get QBCore framework instance
FL.QBCore = nil

-- Initialize framework
function FL.GetFramework()
    if FL.QBCore == nil then
        FL.QBCore = exports['qb-core']:GetCoreObject()
    end
    return FL.QBCore
end

-- Debug function
function FL.Debug(message)
    if Config.Debug then
        print('^3[FL-CORE DEBUG]^7 ' .. tostring(message))
    end
end

-- ====================================================================
-- UTILITY FUNCTIONS
-- ====================================================================

-- Check if player has emergency service job
function FL.Functions.IsEmergencyService(jobname)
    if not jobname then return false end

    for service, data in pairs(Config.EmergencyServices) do
        if service == jobname then
            return true
        end
    end
    return false
end

-- Get emergency service data
function FL.Functions.GetServiceData(serviceName)
    return Config.EmergencyServices[serviceName] or nil
end

-- Get station data by ID
function FL.Functions.GetStationData(stationId)
    return Config.Stations[stationId] or nil
end

-- Get stations for specific service
function FL.Functions.GetServiceStations(serviceName)
    local stations = {}
    for stationId, stationData in pairs(Config.Stations) do
        if stationData.service == serviceName then
            stations[stationId] = stationData
        end
    end
    return stations
end

-- Calculate distance between two coordinates
function FL.Functions.GetDistance(coords1, coords2)
    if not coords1 or not coords2 then return 0 end

    -- Convert to vector3 if needed
    if type(coords1) == 'table' and coords1.x then
        coords1 = vector3(coords1.x, coords1.y, coords1.z)
    end
    if type(coords2) == 'table' and coords2.x then
        coords2 = vector3(coords2.x, coords2.y, coords2.z)
    end

    return #(coords1 - coords2)
end

-- ====================================================================
-- UNIFORM FUNCTIONS
-- ====================================================================

-- Get uniform data for service and gender
function FL.Functions.GetUniform(serviceName, gender)
    if not Config.Uniforms[serviceName] then
        FL.Debug('No uniform found for service: ' .. tostring(serviceName))
        return nil
    end

    local genderKey = (gender == 0) and 'female' or 'male'
    return Config.Uniforms[serviceName][genderKey] or nil
end

-- Check if player is wearing service uniform
function FL.Functions.IsWearingUniform(ped, serviceName)
    if not ped or not serviceName then return false end

    local gender = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') and 0 or 1
    local uniform = FL.Functions.GetUniform(serviceName, gender)

    if not uniform then return false end

    -- Check key uniform pieces (jacket and pants)
    local currentTorso = GetPedDrawableVariation(ped, 11) -- Torso
    local currentPants = GetPedDrawableVariation(ped, 4)  -- Pants

    return (currentTorso == uniform.torso_1) and (currentPants == uniform.pants_1)
end

-- ====================================================================
-- EQUIPMENT FUNCTIONS
-- ====================================================================

-- Get equipment list for service
function FL.Functions.GetServiceEquipment(serviceName)
    return Config.Equipment[serviceName] or {}
end

-- Check if item is service equipment
function FL.Functions.IsServiceEquipment(itemName, serviceName)
    local equipment = FL.Functions.GetServiceEquipment(serviceName)
    for _, item in pairs(equipment) do
        if item == itemName then
            return true
        end
    end
    return false
end

-- ====================================================================
-- EMERGENCY CALL FUNCTIONS
-- ====================================================================

-- Get emergency call types for service
function FL.Functions.GetEmergencyCallTypes(serviceName)
    return Config.EmergencyCalls[serviceName] or {}
end

-- Generate random emergency call
function FL.Functions.GenerateEmergencyCall(serviceName)
    local callTypes = FL.Functions.GetEmergencyCallTypes(serviceName)
    if #callTypes == 0 then return nil end

    local randomType = callTypes[math.random(1, #callTypes)]

    -- Generate random location (this should be expanded with proper spawn points)
    local randomCoords = vector3(
        math.random(-3000, 3000),
        math.random(-3000, 3000),
        math.random(0, 500)
    )

    return {
        id = math.random(10000, 99999),
        type = randomType,
        service = serviceName,
        coords = randomCoords,
        timestamp = os.time(),
        status = 'pending',           -- pending, assigned, active, completed
        priority = math.random(1, 3), -- 1 = high, 2 = medium, 3 = low
        description = FL.Functions.GetCallDescription(randomType)
    }
end

-- Get call description based on type
function FL.Functions.GetCallDescription(callType)
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
-- VALIDATION FUNCTIONS
-- ====================================================================

-- Validate coordinates
function FL.Functions.ValidateCoords(coords)
    if not coords then return false end

    if type(coords) == 'vector3' then
        return true
    elseif type(coords) == 'table' and coords.x and coords.y and coords.z then
        return true
    end

    return false
end

-- Validate service name
function FL.Functions.ValidateService(serviceName)
    return Config.EmergencyServices[serviceName] ~= nil
end

-- Validate station ID
function FL.Functions.ValidateStation(stationId)
    return Config.Stations[stationId] ~= nil
end

-- ====================================================================
-- FORMATTING FUNCTIONS
-- ====================================================================

-- Format time for display
function FL.Functions.FormatTime(timestamp)
    return os.date('%H:%M:%S', timestamp)
end

-- Format date for display
function FL.Functions.FormatDate(timestamp)
    return os.date('%m/%d/%Y', timestamp)
end

-- Format distance for display
function FL.Functions.FormatDistance(distance)
    if distance < 1000 then
        return string.format('%.0fm', distance)
    else
        return string.format('%.1fkm', distance / 1000)
    end
end

-- Format priority for display
function FL.Functions.FormatPriority(priority)
    local priorities = {
        [1] = 'HIGH',
        [2] = 'MEDIUM',
        [3] = 'LOW'
    }
    return priorities[priority] or 'UNKNOWN'
end

-- ====================================================================
-- TABLE FUNCTIONS
-- ====================================================================

-- Deep copy table
function FL.Functions.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[FL.Functions.DeepCopy(orig_key)] = FL.Functions.DeepCopy(orig_value)
        end
        setmetatable(copy, FL.Functions.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Check if table is empty
function FL.Functions.IsTableEmpty(t)
    return next(t) == nil
end

-- Get table size
function FL.Functions.TableSize(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

FL.Debug('Shared functions loaded successfully')
