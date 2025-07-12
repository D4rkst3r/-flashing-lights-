Config = {}

-- ===================================
-- FLASHING LIGHTS CORE CONFIGURATION
-- ===================================

-- Debug Modus (für Entwicklung)
Config.Debug = true

-- Sprache (für spätere Übersetzungen)
Config.Locale = 'en'

-- Database Settings
Config.DatabaseTables = {
    emergency_jobs = 'fl_emergency_jobs',
    duty_logs = 'fl_duty_logs',
    incidents = 'fl_incidents',
    equipment = 'fl_equipment'
}

-- ===================================
-- JOB SYSTEM
-- ===================================

Config.Jobs = {
    ['fire'] = {
        label = 'Fire Department',
        shortname = 'FD',
        type = 'leo',
        defaultduty = false,
        grades = {
            ['0'] = { name = 'Recruit', label = 'Recruit Firefighter', payment = 50 },
            ['1'] = { name = 'firefighter', label = 'Firefighter', payment = 75 },
            ['2'] = { name = 'driver', label = 'Driver/Engineer', payment = 100 },
            ['3'] = { name = 'lieutenant', label = 'Lieutenant', payment = 125 },
            ['4'] = { name = 'captain', label = 'Captain', payment = 150 },
            ['5'] = { name = 'chief', label = 'Fire Chief', payment = 200 }
        }
    },
    ['ambulance'] = {
        label = 'Emergency Medical Services',
        shortname = 'EMS',
        type = 'leo',
        defaultduty = false,
        grades = {
            ['0'] = { name = 'emt', label = 'EMT', payment = 50 },
            ['1'] = { name = 'paramedic', label = 'Paramedic', payment = 75 },
            ['2'] = { name = 'supervisor', label = 'EMS Supervisor', payment = 100 },
            ['3'] = { name = 'chief', label = 'EMS Chief', payment = 150 }
        }
    },
    ['police'] = {
        label = 'Police Department',
        shortname = 'PD',
        type = 'leo',
        defaultduty = false,
        grades = {
            ['0'] = { name = 'cadet', label = 'Police Cadet', payment = 50 },
            ['1'] = { name = 'officer', label = 'Police Officer', payment = 75 },
            ['2'] = { name = 'senior', label = 'Senior Officer', payment = 100 },
            ['3'] = { name = 'sergeant', label = 'Sergeant', payment = 125 },
            ['4'] = { name = 'lieutenant', label = 'Lieutenant', payment = 150 },
            ['5'] = { name = 'captain', label = 'Captain', payment = 175 },
            ['6'] = { name = 'chief', label = 'Police Chief', payment = 200 }
        }
    }
}

-- ===================================
-- STATION LOCATIONS (AMERIKANISCHES SETTING)
-- ===================================

Config.Stations = {
    -- Feuerwehr Station 1 (Los Santos)
    ['fire_station_1'] = {
        label = 'Fire Station 1',
        job = 'fire',
        coords = vector3(216.88, -1644.0, 29.8),
        blip = {
            sprite = 436,
            color = 1,
            scale = 0.8,
            name = 'Fire Department'
        },
        duty_point = vector3(215.54, -1640.12, 29.8),
        garage = vector3(203.59, -1636.04, 29.8),
        equipment_room = vector3(213.44, -1643.96, 29.8)
    },

    -- EMS Station (Pillbox Medical Center)
    ['ems_station_1'] = {
        label = 'Pillbox Medical Center',
        job = 'ambulance',
        coords = vector3(307.7, -1433.4, 29.8),
        blip = {
            sprite = 61,
            color = 2,
            scale = 0.8,
            name = 'Emergency Medical Services'
        },
        duty_point = vector3(310.86, -1430.24, 29.8),
        garage = vector3(320.48, -1478.96, 29.8),
        equipment_room = vector3(306.34, -1433.03, 29.8)
    },

    -- Polizei Station (Mission Row)
    ['police_station_1'] = {
        label = 'Mission Row Police Department',
        job = 'police',
        coords = vector3(428.8, -984.5, 30.7),
        blip = {
            sprite = 60,
            color = 3,
            scale = 0.8,
            name = 'Police Department'
        },
        duty_point = vector3(450.15, -985.48, 30.69),
        garage = vector3(448.159, -1017.26, 28.56),
        equipment_room = vector3(461.23, -999.29, 30.69)
    }
}

-- ===================================
-- DUTY SYSTEM
-- ===================================

Config.DutySystem = {
    -- Marker für Einstempeln
    marker = {
        type = 1,
        size = vector3(1.5, 1.5, 1.0),
        color = { r = 0, g = 150, b = 255, a = 100 },
        bobUpAndDown = false,
        faceCamera = false,
        rotate = false
    },

    -- Automatische Kleidung beim Dienstantritt
    auto_uniform = true,

    -- Log alle Dienstzeiten in der Datenbank
    log_duty_times = true
}

-- ===================================
-- NOTIFICATION SYSTEM
-- ===================================

Config.Notifications = {
    type = 'qb', -- 'qb', 'ox', 'custom'
    position = 'top-right',
    timeout = 5000
}

-- ===================================
-- BLIP SYSTEM
-- ===================================

Config.ShowStationBlips = true
Config.ShowDutyBlips = true -- Zeige alle Spieler im Dienst auf der Karte

-- ===================================
-- PERMISSIONS
-- ===================================

Config.Permissions = {
    -- Admin Commands
    admin_commands = {
        'admin',
        'god'
    },

    -- Wer kann Einsätze erstellen/bearbeiten
    manage_incidents = {
        'admin',
        'dispatcher'
    }
}
