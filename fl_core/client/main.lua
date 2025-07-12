local QBCore = exports['qb-core']:GetCoreObject()

-- ===================================
-- FLASHING LIGHTS CORE CLIENT
-- ===================================

-- Local variables
local PlayerData = {}
local DutyMarkers = {}
local StationBlips = {}
local IsNearDutyMarker = false
local CurrentStation = nil
local LastDutyInteraction = 0
local TabletOpen = false
local NUIReady = false

-- ===================================
-- NUI READY SYSTEM
-- ===================================

-- Check if NUI is ready
RegisterNUICallback('nuiReady', function(data, cb)
    NUIReady = true
    FL.Debug('NUI is now ready')
    cb('ok')
end)

-- Wait for NUI to be ready before allowing interactions
function WaitForNUI(callback)
    if NUIReady then
        callback()
    else
        FL.Debug('Waiting for NUI to be ready...')
        CreateThread(function()
            local attempts = 0
            while not NUIReady and attempts < 50 do -- 5 seconds max
                Wait(100)
                attempts = attempts + 1
            end

            if NUIReady then
                FL.Debug('NUI ready after ' .. (attempts * 100) .. 'ms')
                callback()
            else
                FL.Debug('NUI failed to load after 5 seconds')
                QBCore.Functions.Notify('UI failed to load, try again', 'error')
            end
        end)
    end
end

-- ===================================
-- TABLET STATE MANAGEMENT
-- ===================================

-- Set tablet open state
function SetTabletOpen(state)
    TabletOpen = state
end

-- Get tablet open state
function IsTabletCurrentlyOpen()
    return TabletOpen
end

-- ===================================
-- KEYBOARD CONTROLS
-- ===================================

-- Keyboard handler for tablet
CreateThread(function()
    while true do
        Wait(0)

        -- F6 to toggle tablet (only for emergency services)
        if IsControlJustReleased(0, 167) then -- F6
            FL.Debug('F6 pressed - checking job...')
            FL.Debug('PlayerData.job: ' .. json.encode(PlayerData.job or {}))

            if PlayerData.job then
                FL.Debug('Job name: ' .. (PlayerData.job.name or 'none'))
                FL.Debug('Is emergency service: ' .. tostring(FL.IsEmergencyService(PlayerData.job.name)))

                if FL.IsEmergencyService(PlayerData.job.name) then
                    FL.Debug('Opening tablet...')
                    ToggleTabletUI()
                else
                    FL.Debug('Job is not emergency service: ' .. (PlayerData.job.name or 'none'))
                    QBCore.Functions.Notify('You need to be an Emergency Service worker to use the tablet', 'error')
                end
            else
                FL.Debug('No job data found')
                QBCore.Functions.Notify('Job data not loaded yet', 'error')
            end
        end

        -- ESC to close tablet if open
        if IsControlJustReleased(0, 322) then -- ESC
            if IsTabletCurrentlyOpen() then
                FL.Debug('ESC pressed - closing tablet')
                HideDutyUI()
            end
        end
    end
end)

-- Toggle tablet UI
function ToggleTabletUI()
    FL.Debug('ToggleTabletUI called')

    WaitForNUI(function()
        if IsTabletCurrentlyOpen() then
            FL.Debug('Tablet is open, hiding...')
            HideDutyUI()
        else
            FL.Debug('Tablet is closed, showing...')

            -- Get nearest station for context
            local nearestStation = GetNearestStation()
            if not nearestStation then
                -- Default based on job
                if PlayerData.job and PlayerData.job.name == 'fire' then
                    nearestStation = 'fire_station_1'
                elseif PlayerData.job and PlayerData.job.name == 'ambulance' then
                    nearestStation = 'ems_station_1'
                elseif PlayerData.job and PlayerData.job.name == 'police' then
                    nearestStation = 'police_station_1'
                else
                    nearestStation = 'fire_station_1' -- Ultimate fallback
                end
                FL.Debug('No nearest station found, using default: ' .. nearestStation)
            else
                FL.Debug('Using nearest station: ' .. nearestStation)
            end

            ShowDutyUI(nearestStation)
        end
    end)
end

-- Check if tablet is currently open
function IsTabletCurrentlyOpen()
    return TabletOpen
end

-- Get nearest emergency station
function GetNearestStation()
    if not PlayerData.job or not FL.IsEmergencyService(PlayerData.job.name) then
        return nil
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearestStation = nil
    local nearestDistance = math.huge

    for stationId, station in pairs(Config.Stations) do
        if station.job == PlayerData.job.name then
            local distance = FL.GetDistance(coords, station.coords)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestStation = stationId
            end
        end
    end

    return nearestStation
end

-- SOFORT beim Resource-Start - höchste Priorität
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Absolut sofort NUI deaktivieren
        SetNuiFocus(false, false)
        FL.Debug('Client resource started - NUI focus disabled')
    end
end)

-- Sicherstellen, dass UI beim Resource-Start sofort versteckt ist
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Sofort NUI deaktivieren
        SetNuiFocus(false, false)

        -- UI verstecken
        SendNUIMessage({
            action = 'hideTablet'
        })
        SendNUIMessage({
            action = 'hideQuickHUD'
        })

        FL.Debug('Resource started - NUI hidden')
    end
end)

-- Zusätzlich beim Client-Start
CreateThread(function()
    -- Sofort nach dem ersten Frame
    Wait(0)
    SetNuiFocus(false, false)

    -- Nochmal nach kurzer Zeit um sicher zu gehen
    Wait(1000)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideTablet'
    })
    SendNUIMessage({
        action = 'hideQuickHUD'
    })

    FL.Debug('Client thread - NUI hidden')
end)

-- Initialize when player is loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()

    FL.Debug('Player loaded with job: ' .. (PlayerData.job and PlayerData.job.name or 'none'))

    -- Sicherstellen, dass NUI initial korrekt versteckt ist
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideTablet'
    })
    SendNUIMessage({
        action = 'hideQuickHUD'
    })

    SetupStationBlips()
    SetupDutyMarkers()

    -- Show controls hint if emergency service
    if PlayerData.job and FL.IsEmergencyService(PlayerData.job.name) then
        SendNUIMessage({
            action = 'showControlsHint'
        })
        FL.Debug('Emergency service job detected, showing controls hint')
    else
        FL.Debug('Not an emergency service job: ' .. (PlayerData.job and PlayerData.job.name or 'none'))
    end
end)

-- Update player data when job changes
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo

    -- Update duty markers based on new job
    SetupDutyMarkers()

    -- Show/hide controls hint based on job
    if FL.IsEmergencyService(JobInfo.name) then
        SendNUIMessage({
            action = 'showControlsHint'
        })

        -- Update HUD if on duty
        if JobInfo.onduty then
            SendNUIMessage({
                action = 'showQuickHUD',
                data = {
                    callsign = GetPlayerUnit(),
                    status = 'Available'
                }
            })
        else
            SendNUIMessage({
                action = 'hideQuickHUD'
            })
        end
    else
        SendNUIMessage({
            action = 'hideControlsHint'
        })
        SendNUIMessage({
            action = 'hideQuickHUD'
        })
    end
end)

-- ===================================
-- STATION BLIPS
-- ===================================

-- Setup station blips
function SetupStationBlips()
    if not Config.ShowStationBlips then return end

    -- Remove existing blips
    for _, blip in pairs(StationBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    StationBlips = {}

    -- Create new blips
    for stationId, station in pairs(Config.Stations) do
        if station.blip then
            local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)

            SetBlipSprite(blip, station.blip.sprite)
            SetBlipColour(blip, station.blip.color)
            SetBlipScale(blip, station.blip.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(station.blip.name)
            EndTextCommandSetBlipName(blip)

            StationBlips[stationId] = blip
        end
    end

    FL.Debug('Station blips created')
end

-- Handle setup from server
RegisterNetEvent('fl_core:setupStationBlips', function()
    SetupStationBlips()
end)

-- ===================================
-- DUTY MARKERS
-- ===================================

-- Setup duty markers
function SetupDutyMarkers()
    -- Clear existing markers
    DutyMarkers = {}

    if not PlayerData.job then return end

    -- Only show markers for emergency service jobs
    if not FL.IsEmergencyService(PlayerData.job.name) then return end

    -- Add markers for stations that match player's job
    for stationId, station in pairs(Config.Stations) do
        if station.job == PlayerData.job.name then
            DutyMarkers[stationId] = {
                coords = station.duty_point,
                station = stationId,
                config = station
            }

            -- Setup markers using the new marker system
            FL.SetupStationMarkers(stationId, station)
        end
    end

    FL.Debug('Duty markers setup for job: ' .. PlayerData.job.name)
end

-- Main marker thread
CreateThread(function()
    while true do
        local sleep = 1000

        -- The new marker system handles everything automatically
        -- This thread is just for legacy compatibility

        Wait(sleep)
    end
end)

-- Handle duty interaction (called from marker system)
RegisterNetEvent('fl_core:dutyInteraction', function(stationId)
    -- Prevent spam clicking (2 second cooldown)
    local currentTime = GetGameTimer()
    if currentTime - LastDutyInteraction < 2000 then
        FL.Debug('Duty interaction on cooldown, ignoring...')
        return
    end
    LastDutyInteraction = currentTime

    FL.Debug('Received fl_core:dutyInteraction event for station: ' .. tostring(stationId))
    ProcessDutyInteraction(stationId)
end)

-- Process duty interaction (renamed to avoid conflict with markers.lua)
function ProcessDutyInteraction(stationId)
    if not stationId then
        FL.Debug('ProcessDutyInteraction called with nil stationId')
        return
    end

    local station = Config.Stations[stationId]
    if not station then
        FL.Debug('Station not found in config: ' .. tostring(stationId))
        return
    end

    FL.Debug('Processing duty interaction for station: ' .. stationId)

    if PlayerData.job.onduty then
        FL.Debug('Player is on duty, ending duty...')
        TriggerServerEvent('fl_core:endDuty', stationId)
    else
        FL.Debug('Player is off duty, starting duty...')
        TriggerServerEvent('fl_core:startDuty', stationId)
    end
end

-- ===================================
-- UNIFORM SYSTEM
-- ===================================

-- Apply uniform when going on duty
RegisterNetEvent('fl_core:applyUniform', function(job)
    local ped = PlayerPedId()

    -- This is where you would integrate with your clothing system
    -- For now, we'll use a basic example

    if job == 'fire' then
        -- Fire Department Uniform
        SetPedComponentVariation(ped, 11, 314, 1, 0) -- Torso
        SetPedComponentVariation(ped, 4, 127, 1, 0)  -- Legs
        SetPedComponentVariation(ped, 6, 24, 0, 0)   -- Feet
        SetPedComponentVariation(ped, 8, 15, 0, 0)   -- Undershirt
        SetPedPropIndex(ped, 0, 144, 1, true)        -- Helmet
    elseif job == 'ambulance' then
        -- EMS Uniform
        SetPedComponentVariation(ped, 11, 250, 1, 0) -- Torso
        SetPedComponentVariation(ped, 4, 96, 1, 0)   -- Legs
        SetPedComponentVariation(ped, 6, 24, 0, 0)   -- Feet
        SetPedComponentVariation(ped, 8, 15, 0, 0)   -- Undershirt
    elseif job == 'police' then
        -- Police Uniform
        SetPedComponentVariation(ped, 11, 287, 1, 0) -- Torso
        SetPedComponentVariation(ped, 4, 87, 1, 0)   -- Legs
        SetPedComponentVariation(ped, 6, 24, 0, 0)   -- Feet
        SetPedComponentVariation(ped, 8, 15, 0, 0)   -- Undershirt
        SetPedPropIndex(ped, 0, 46, 0, true)         -- Hat
    end

    QBCore.Functions.Notify('Uniform applied', 'success')
end)

-- Remove uniform when going off duty
RegisterNetEvent('fl_core:removeUniform', function()
    -- Restore player's regular clothes
    -- This would typically restore their saved outfit
    TriggerEvent('qb-clothing:client:loadPlayerClothing')

    QBCore.Functions.Notify('Uniform removed', 'info')
end)

-- ===================================
-- UI SYSTEM
-- ===================================

-- Show modern duty UI
function ShowDutyUI(stationId)
    FL.Debug('ShowDutyUI called for station: ' .. tostring(stationId))

    local station = Config.Stations[stationId]
    if not station then
        FL.Debug('Station not found: ' .. tostring(stationId))
        return
    end

    if not PlayerData.job then
        FL.Debug('No PlayerData.job available')
        QBCore.Functions.Notify('Player data not loaded', 'error')
        return
    end

    FL.Debug('Setting NUI focus and showing tablet')

    SetNuiFocus(true, true)
    SetTabletOpen(true)

    local uiData = {
        station = station,
        player = {
            name = (PlayerData.charinfo and (PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname)) or
            'Unknown Officer',
            rank = PlayerData.job.grade and PlayerData.job.grade.label or 'Unknown Rank',
            badge = PlayerData.job.grade and PlayerData.job.grade.level or 1,
            unit = GetPlayerUnit()
        },
        job = PlayerData.job.name,
        dutyStatus = PlayerData.job.onduty
    }

    FL.Debug('Sending showTablet message with data: ' .. json.encode(uiData))

    SendNUIMessage({
        action = 'showTablet',
        data = uiData
    })

    -- Show help text
    QBCore.Functions.Notify('Press F6 or ESC to close tablet', 'primary', 3000)
end

-- Hide modern duty UI
function HideDutyUI()
    FL.Debug('HideDutyUI called')

    SetNuiFocus(false, false)
    SetTabletOpen(false)

    SendNUIMessage({
        action = 'hideTablet'
    })

    FL.Debug('Tablet hidden and focus removed')
end

-- Get player unit based on job
function GetPlayerUnit()
    local units = {
        ['fire'] = 'Engine ' .. (PlayerData.job.grade.level + 1),
        ['ambulance'] = 'Medic ' .. (PlayerData.job.grade.level + 1),
        ['police'] = 'Unit ' .. (PlayerData.job.grade.level + 1)
    }
    return units[PlayerData.job.name] or 'Unit 1'
end

-- Handle NUI callbacks
RegisterNUICallback('startDuty', function(data, cb)
    TriggerServerEvent('fl_core:startDuty', data.station)
    cb('ok')
end)

RegisterNUICallback('endDuty', function(data, cb)
    TriggerServerEvent('fl_core:endDuty', data.station)
    cb('ok')
end)

RegisterNUICallback('closeTablet', function(data, cb)
    HideDutyUI()
    cb('ok')
end)

RegisterNUICallback('tabletOpened', function(data, cb)
    -- Store tablet state
    exports['fl_core']:SetTabletOpen(true)
    cb('ok')
end)

RegisterNUICallback('tabletClosed', function(data, cb)
    -- Store tablet state
    exports['fl_core']:SetTabletOpen(false)
    cb('ok')
end)

RegisterNUICallback('getEquipment', function(data, cb)
    QBCore.Functions.TriggerCallback('fl_core:getPlayerEquipment', function(equipment)
        SendNUIMessage({
            action = 'updateEquipment',
            data = equipment
        })
    end)
    cb('ok')
end)

RegisterNUICallback('getVehicles', function(data, cb)
    QBCore.Functions.TriggerCallback('fl_core:getJobVehicles', function(vehicles)
        SendNUIMessage({
            action = 'updateVehicles',
            data = vehicles
        })
    end, PlayerData.job.name)
    cb('ok')
end)

RegisterNUICallback('getStats', function(data, cb)
    QBCore.Functions.TriggerCallback('fl_core:getDutyStats', function(stats)
        SendNUIMessage({
            action = 'updateStats',
            data = stats
        })
    end)
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    TriggerEvent('fl_core:spawnVehicle', data.vehicleId)
    cb('ok')
end)

RegisterNUICallback('returnVehicle', function(data, cb)
    TriggerEvent('fl_core:returnVehicle', data.vehicleId)
    cb('ok')
end)

RegisterNUICallback('selectEquipment', function(data, cb)
    TriggerEvent('fl_core:selectEquipment', data.equipmentId)
    cb('ok')
end)

-- ===================================
-- UTILITY FUNCTIONS
-- ===================================

-- Check if player is near duty marker
function IsNearDutyPoint()
    return IsNearDutyMarker
end

-- Get current station
function GetCurrentStation()
    return CurrentStation
end

-- Get player duty status
function GetDutyStatus()
    return PlayerData.job and PlayerData.job.onduty or false
end

-- Export functions for other resources and internal modules
exports('IsNearDutyPoint', IsNearDutyPoint)
exports('GetCurrentStation', GetCurrentStation)
exports('GetDutyStatus', GetDutyStatus)
exports('ShowDutyUI', ShowDutyUI)
exports('HideDutyUI', HideDutyUI)
exports('IsTabletOpen', IsTabletCurrentlyOpen)
exports('SetTabletOpen', SetTabletOpen)
exports('ToggleTabletUI', ToggleTabletUI)

-- ===================================
-- NOTIFICATIONS
-- ===================================

-- Custom notification handler
RegisterNetEvent('fl_core:notify', function(message, type, timeout)
    -- Custom notification system - you can replace this with your preferred system
    QBCore.Functions.Notify(message, type, timeout)
end)

-- ===================================
-- COMMANDS (for testing/admin use)
-- ===================================

-- Debug command to show all stations
RegisterCommand('fl_stations', function()
    if not Config.Debug then return end

    print('^3=== Flashing Lights Stations ===^7')
    for stationId, station in pairs(Config.Stations) do
        print('^2' .. stationId .. '^7: ' .. station.label .. ' (' .. station.job .. ')')
    end
end, false)

-- Debug command to show duty status
RegisterCommand('fl_duty', function()
    if not Config.Debug then return end

    QBCore.Functions.TriggerCallback('fl_core:getDutyStatus', function(status)
        print('^3=== Duty Status ===^7')
        print('^2On Duty^7: ' .. tostring(status.onduty))
        print('^2Job^7: ' .. status.job)
        print('^2Grade^7: ' .. status.grade.label)
        if status.session then
            print('^2Session ID^7: ' .. status.session.sessionId)
            print('^2Station^7: ' .. status.session.station)
        end
    end)
end, false)

-- Debug command to test tablet (bypasses job check)
RegisterCommand('fl_tablet', function()
    if not Config.Debug then return end

    FL.Debug('Manual tablet toggle via command')

    if not PlayerData.job then
        -- Create dummy job data for testing
        PlayerData.job = {
            name = 'fire',
            grade = { label = 'Test Firefighter', level = 1 },
            onduty = false
        }
        PlayerData.charinfo = {
            firstname = 'Test',
            lastname = 'User'
        }
        FL.Debug('Created dummy job data for testing')
    end

    ToggleTabletUI()
end, false)

-- Test NUI directly without any checks
RegisterCommand('fl_testnui', function()
    if not Config.Debug then return end

    FL.Debug('Testing NUI directly...')

    if IsTabletCurrentlyOpen() then
        FL.Debug('Closing NUI test')
        SetNuiFocus(false, false)
        SetTabletOpen(false)
        SendNUIMessage({ action = 'hideTablet' })
    else
        FL.Debug('Opening NUI test')
        SetNuiFocus(true, true)
        SetTabletOpen(true)

        SendNUIMessage({
            action = 'showTablet',
            data = {
                station = { label = 'Test Station', job = 'fire', id = 'test' },
                player = { name = 'Test User', rank = 'Test Rank', badge = 1, unit = 'Test Unit' },
                job = 'fire',
                dutyStatus = false
            }
        })

        QBCore.Functions.Notify('NUI Test - Press ESC or /fl_testnui to close', 'primary')
    end
end, false)

-- Force NUI ready state
RegisterCommand('fl_nuiready', function()
    if not Config.Debug then return end

    NUIReady = true
    FL.Debug('Forced NUI ready state to true')
    QBCore.Functions.Notify('NUI marked as ready', 'success')
end, false)

-- Force show tablet with aggressive CSS override
RegisterCommand('fl_forceshow', function()
    if not Config.Debug then return end

    FL.Debug('Force showing tablet with CSS override')

    -- Send NUI message to force show
    SendNUIMessage({
        action = 'forceShow'
    })

    SetNuiFocus(true, true)
    QBCore.Functions.Notify('Forced tablet to show - Check if visible', 'primary')
end, false)

-- Command to check player data
RegisterCommand('fl_playerdata', function()
    if not Config.Debug then return end

    print('^3=== Player Data ===^7')
    print('^2PlayerData exists^7: ' .. tostring(PlayerData ~= nil))

    if PlayerData.job then
        print('^2Job Name^7: ' .. (PlayerData.job.name or 'none'))
        print('^2Job On Duty^7: ' .. tostring(PlayerData.job.onduty))
        print('^2Job Grade^7: ' .. json.encode(PlayerData.job.grade or {}))
    else
        print('^1No job data found^7')
    end

    if PlayerData.charinfo then
        print('^2Character^7: ' .. (PlayerData.charinfo.firstname or '') .. ' ' .. (PlayerData.charinfo.lastname or ''))
    else
        print('^1No character info found^7')
    end
end, false)

FL.Debug('Flashing Lights Core Client loaded successfully!')
