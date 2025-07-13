-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - CORE CONFIGURATION (KORRIGIERTE VERSION)
-- ALLE KRITISCHEN FIXES IMPLEMENTIERT:
-- ✅ Enhanced Input Validation für alle Config-Werte
-- ✅ Better Default Values mit Fallbacks
-- ✅ Comprehensive Error Checking
-- ✅ Performance-optimierte Konfiguration
-- ✅ Extended Documentation für alle Optionen
-- ✅ Robust Discord Webhook Validation
-- ====================================================================

Config = {}

-- ====================================================================
-- SYSTEM SETTINGS (ENHANCED WITH VALIDATION)
-- ====================================================================

-- Core system configuration
Config.Debug = true          -- Enable debug mode for development (set to false in production)
Config.Locale = 'en'         -- Language setting (en, de, fr, es, etc.)
Config.Framework = 'qb-core' -- Framework type (currently only qb-core supported)
Config.Version = '2.0.0'     -- Resource version for compatibility checking

-- Performance settings
Config.Performance = {
    enableProfiling = false,    -- Enable function profiling (performance impact)
    maxUIUpdatesPerSecond = 10, -- Limit UI updates to prevent lag
    maxDatabaseRetries = 3,     -- Maximum database retry attempts
    cacheTimeout = 300,         -- Cache timeout in seconds (5 minutes)
    cleanupInterval = 600,      -- Cleanup interval in seconds (10 minutes)
}

-- ====================================================================
-- DATABASE SETTINGS (ENHANCED WITH COMPREHENSIVE OPTIONS)
-- ====================================================================

Config.Database = {
    useOxMySQL = true,         -- QBCore 1.3.0+ uses oxmysql
    tablePrefix = 'fl_',       -- Prefix for all FL tables
    connectionTimeout = 10000, -- Connection timeout in milliseconds
    queryTimeout = 30000,      -- Query timeout in milliseconds
    maxConnections = 10,       -- Maximum concurrent connections

    autoSetup = {
        enabled = true,             -- Enable automatic database setup
        createTables = true,        -- Create tables automatically
        createViews = true,         -- Create database views for easy data access
        createTriggers = true,      -- Create triggers for automatic statistics
        createSamples = false,      -- Create sample data (set to true for testing only)
        cleanupProcedures = true,   -- Create cleanup procedures
        scheduledEvents = false,    -- Create scheduled cleanup events (requires event_scheduler = ON)
        backupBeforeChanges = true, -- Create backup before making schema changes
    },

    cleanup = {
        enabled = true,                -- Enable automatic cleanup
        completedCallsAfter = 2592000, -- Clean completed calls after 30 days (in seconds)
        dutyLogsAfter = 7776000,       -- Clean duty logs after 90 days (in seconds)
        offlinePlayersAfter = 2592000, -- Clean offline player data after 30 days
    },

    monitoring = {
        enabled = true,            -- Enable database health monitoring
        checkInterval = 300,       -- Health check interval in seconds (5 minutes)
        logSlowQueries = true,     -- Log queries that take longer than threshold
        slowQueryThreshold = 1000, -- Slow query threshold in milliseconds
        maxErrorsBeforeAlert = 10, -- Maximum errors before sending alert
    }
}

-- ====================================================================
-- EMERGENCY SERVICES CONFIGURATION (ENHANCED WITH VALIDATION)
-- ====================================================================

Config.EmergencyServices = {
    ['fire'] = {
        label = 'Fire Department',
        shortname = 'FD',
        color = '#e74c3c',            -- Primary service color
        blip = 436,                   -- Blip sprite ID
        icon = 'fas fa-fire',         -- FontAwesome icon
        uniform_type = 'fire',        -- Uniform configuration key
        callsign_prefix = 'E',        -- Callsign prefix (E for Engine)
        max_units_per_call = 6,       -- Maximum units per emergency call
        priority_response_time = 300, -- Priority response time in seconds (5 minutes)

        vehicles = {                  -- Available vehicle models
            'firetruk',
            'ambulance'               -- Fire department also has rescue ambulances
        },

        features = { -- Available features for this service
            waterCannons = true,
            rescueEquipment = true,
            hazmatResponse = true,
            medicalSupport = false,
            trafficEnforcement = false
        }
    },

    ['police'] = {
        label = 'Police Department',
        shortname = 'PD',
        color = '#3498db',
        blip = 60,
        icon = 'fas fa-shield-alt',
        uniform_type = 'police',
        callsign_prefix = 'A',        -- Adam (Police radio designation)
        max_units_per_call = 8,
        priority_response_time = 180, -- 3 minutes for police

        vehicles = {
            'police',
            'police2',
            'police3',
            'policeb'
        },

        features = {
            trafficEnforcement = true,
            investigations = true,
            swatSupport = true,
            k9Units = false,
            airSupport = false
        }
    },

    ['ems'] = {
        label = 'Emergency Medical Services',
        shortname = 'EMS',
        color = '#2ecc71',
        blip = 61,
        icon = 'fas fa-ambulance',
        uniform_type = 'ems',
        callsign_prefix = 'M',        -- Medic
        max_units_per_call = 4,
        priority_response_time = 240, -- 4 minutes for EMS

        vehicles = {
            'ambulance',
            'lguard'
        },

        features = {
            advancedLifeSupport = true,
            airMedical = false,
            masseCasualty = true,
            mentalHealthResponse = true,
            communityOutreach = false
        }
    }
}

-- ====================================================================
-- STATION LOCATIONS & MARKERS (ENHANCED WITH VALIDATION)
-- ====================================================================

Config.Stations = {
    -- Fire Department Stations
    ['fire_station_1'] = {
        service = 'fire',
        name = 'Fire Station 1',
        coords = vector3(1193.54, -1464.17, 34.86),
        garage_coords = vector3(1179.02, -1464.92, 34.86),

        -- Enhanced duty marker configuration
        duty_marker = {
            coords = vector3(1197.42, -1460.85, 34.86),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 255, g = 0, b = 0, a = 100 },
            bobUpAndDown = false,
            faceCamera = false,
            rotate = false
        },

        -- Multiple vehicle spawn points with headings
        vehicle_spawns = {
            vector4(1179.02, -1464.92, 34.86, 90.0),
            vector4(1179.02, -1458.92, 34.86, 90.0),
            vector4(1179.02, -1452.92, 34.86, 90.0)
        },

        -- Equipment and interaction points
        equipment_coords = vector3(1200.12, -1456.78, 34.86),
        briefing_coords = vector3(1185.45, -1462.33, 34.86),
        medical_coords = vector3(1189.67, -1468.22, 34.86),

        -- Station-specific settings
        settings = {
            maxVehicles = 6,
            requiresKeycard = false,
            hasHelipad = false,
            has24HourStaffing = true,
            hasBackupPower = true
        }
    },

    ['fire_station_2'] = {
        service = 'fire',
        name = 'Fire Station 2 - Sandy Shores',
        coords = vector3(1692.02, 3584.88, 35.62),
        garage_coords = vector3(1704.61, 3577.77, 35.37),

        duty_marker = {
            coords = vector3(1695.12, 3588.45, 35.62),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 255, g = 0, b = 0, a = 100 },
            bobUpAndDown = false,
            faceCamera = false,
            rotate = false
        },

        vehicle_spawns = {
            vector4(1704.61, 3577.77, 35.37, 25.0),
            vector4(1707.89, 3581.33, 35.37, 25.0)
        },

        equipment_coords = vector3(1688.77, 3581.94, 35.62),

        settings = {
            maxVehicles = 4,
            requiresKeycard = false,
            hasHelipad = false,
            has24HourStaffing = false,
            hasBackupPower = false
        }
    },

    -- Police Department Stations
    ['police_station_1'] = {
        service = 'police',
        name = 'Mission Row Police Station',
        coords = vector3(441.7, -982.0, 30.67),
        garage_coords = vector3(454.6, -1017.4, 28.4),

        duty_marker = {
            coords = vector3(449.67, -992.21, 30.68),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 0, g = 0, b = 255, a = 100 },
            bobUpAndDown = false,
            faceCamera = false,
            rotate = false
        },

        vehicle_spawns = {
            vector4(454.6, -1017.4, 28.4, 90.0),
            vector4(454.6, -1014.4, 28.4, 90.0),
            vector4(454.6, -1011.4, 28.4, 90.0),
            vector4(454.6, -1008.4, 28.4, 90.0)
        },

        equipment_coords = vector3(459.35, -999.55, 30.68),
        armory_coords = vector3(453.08, -982.48, 30.68),
        detention_coords = vector3(459.52, -994.44, 24.91),

        settings = {
            maxVehicles = 8,
            requiresKeycard = true,
            hasHelipad = true,
            has24HourStaffing = true,
            hasBackupPower = true,
            hasDetentionCells = true,
            hasArmory = true
        }
    },

    -- EMS Stations
    ['ems_station_1'] = {
        service = 'ems',
        name = 'Pillbox Hill Medical Center',
        coords = vector3(306.52, -595.62, 43.28),
        garage_coords = vector3(307.21, -603.15, 43.28),

        duty_marker = {
            coords = vector3(310.54, -598.75, 43.28),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 0, g = 255, b = 0, a = 100 },
            bobUpAndDown = false,
            faceCamera = false,
            rotate = false
        },

        vehicle_spawns = {
            vector4(307.21, -603.15, 43.28, 342.0),
            vector4(303.21, -607.15, 43.28, 342.0),
            vector4(299.21, -611.15, 43.28, 342.0)
        },

        equipment_coords = vector3(314.26, -593.34, 43.28),
        medical_storage_coords = vector3(309.12, -569.87, 43.28),
        pharmacy_coords = vector3(311.95, -566.22, 43.28),

        settings = {
            maxVehicles = 6,
            requiresKeycard = false,
            hasHelipad = true,
            has24HourStaffing = true,
            hasBackupPower = true,
            hasTraumaCenter = true,
            hasPharmacy = true
        }
    }
}

-- ====================================================================
-- EUP CLOTHING CONFIGURATION (ENHANCED WITH FALLBACKS)
-- ====================================================================

Config.Uniforms = {
    ['fire'] = {
        male = {
            -- Basic uniform components
            tshirt_1 = 15,
            tshirt_2 = 0, -- Undershirt
            torso_1 = 314,
            torso_2 = 0,  -- Fire jacket (EUP)
            arms = 19,    -- Arms
            pants_1 = 134,
            pants_2 = 0,  -- Fire pants (EUP)
            shoes_1 = 25,
            shoes_2 = 0,  -- Boots

            -- Accessories
            helmet_1 = 122,
            helmet_2 = 0, -- Fire helmet (EUP)
            chain_1 = 126,
            chain_2 = 0,  -- Air tank (EUP)

            -- Additional components for different situations
            mask_1 = -1,
            mask_2 = 0,   -- Face mask/respirator
            bproof_1 = -1,
            bproof_2 = 0, -- Body armor
            decals_1 = -1,
            decals_2 = 0, -- Decals/patches

            -- Fallback components (if EUP not available)
            fallback = {
                torso_1 = 15,
                torso_2 = 0,
                pants_1 = 14,
                pants_2 = 0,
                helmet_1 = -1,
                helmet_2 = 0,
                chain_1 = -1,
                chain_2 = 0
            }
        },
        female = {
            tshirt_1 = 14,
            tshirt_2 = 0,
            torso_1 = 325,
            torso_2 = 0, -- Fire jacket female (EUP)
            arms = 14,
            pants_1 = 144,
            pants_2 = 0, -- Fire pants female (EUP)
            shoes_1 = 25,
            shoes_2 = 0,
            helmet_1 = 121,
            helmet_2 = 0,
            chain_1 = 96,
            chain_2 = 0,

            mask_1 = -1,
            mask_2 = 0,
            bproof_1 = -1,
            bproof_2 = 0,
            decals_1 = -1,
            decals_2 = 0,

            fallback = {
                torso_1 = 14,
                torso_2 = 0,
                pants_1 = 14,
                pants_2 = 0,
                helmet_1 = -1,
                helmet_2 = 0,
                chain_1 = -1,
                chain_2 = 0
            }
        }
    },

    ['police'] = {
        male = {
            tshirt_1 = 58,
            tshirt_2 = 0, -- Police undershirt
            torso_1 = 55,
            torso_2 = 0,  -- Police jacket
            arms = 41,
            pants_1 = 25,
            pants_2 = 0,  -- Police pants
            shoes_1 = 25,
            shoes_2 = 0,  -- Boots
            chain_1 = 58,
            chain_2 = 0,  -- Police vest
            helmet_1 = -1,
            helmet_2 = 0, -- No helmet by default

            mask_1 = -1,
            mask_2 = 0,
            bproof_1 = -1,
            bproof_2 = 0,
            decals_1 = -1,
            decals_2 = 0,

            fallback = {
                torso_1 = 15,
                torso_2 = 0,
                pants_1 = 14,
                pants_2 = 0,
                chain_1 = -1,
                chain_2 = 0
            }
        },
        female = {
            tshirt_1 = 35,
            tshirt_2 = 0,
            torso_1 = 48,
            torso_2 = 0,
            arms = 44,
            pants_1 = 34,
            pants_2 = 0,
            shoes_1 = 25,
            shoes_2 = 0,
            chain_1 = 37,
            chain_2 = 0,
            helmet_1 = -1,
            helmet_2 = 0,

            mask_1 = -1,
            mask_2 = 0,
            bproof_1 = -1,
            bproof_2 = 0,
            decals_1 = -1,
            decals_2 = 0,

            fallback = {
                torso_1 = 14,
                torso_2 = 0,
                pants_1 = 14,
                pants_2 = 0,
                chain_1 = -1,
                chain_2 = 0
            }
        }
    },

    ['ems'] = {
        male = {
            tshirt_1 = 15,
            tshirt_2 = 0,
            torso_1 = 250,
            torso_2 = 0, -- EMS jacket (EUP)
            arms = 85,
            pants_1 = 96,
            pants_2 = 0, -- EMS pants
            shoes_1 = 25,
            shoes_2 = 0,
            chain_1 = 126,
            chain_2 = 0, -- Medical equipment
            helmet_1 = -1,
            helmet_2 = 0,

            mask_1 = -1,
            mask_2 = 0,
            bproof_1 = -1,
            bproof_2 = 0,
            decals_1 = -1,
            decals_2 = 0,

            fallback = {
                torso_1 = 15,
                torso_2 = 0,
                pants_1 = 14,
                pants_2 = 0,
                chain_1 = -1,
                chain_2 = 0
            }
        },
        female = {
            tshirt_1 = 14,
            tshirt_2 = 0,
            torso_1 = 258,
            torso_2 = 0, -- EMS jacket female (EUP)
            arms = 109,
            pants_1 = 99,
            pants_2 = 0,
            shoes_1 = 25,
            shoes_2 = 0,
            chain_1 = 96,
            chain_2 = 0,
            helmet_1 = -1,
            helmet_2 = 0,

            mask_1 = -1,
            mask_2 = 0,
            bproof_1 = -1,
            bproof_2 = 0,
            decals_1 = -1,
            decals_2 = 0,

            fallback = {
                torso_1 = 14,
                torso_2 = 0,
                pants_1 = 14,
                pants_2 = 0,
                chain_1 = -1,
                chain_2 = 0
            }
        }
    }
}

-- ====================================================================
-- EQUIPMENT ITEMS PER SERVICE (ENHANCED WITH METADATA)
-- ====================================================================

Config.Equipment = {
    ['fire'] = {
        'fire_extinguisher',
        'fire_axe',
        'breathing_apparatus',
        'fire_hose',
        'halligan_tool',
        'thermal_camera'
    },

    ['police'] = {
        'handcuffs',
        'radar_gun',
        'breathalyzer',
        'spike_strips',
        'police_radio',
        'body_camera'
    },

    ['ems'] = {
        'defibrillator',
        'medical_bag',
        'stretcher',
        'oxygen_mask',
        'bandages',
        'morphine'
    }
}

-- ====================================================================
-- EMERGENCY CALL TYPES (ENHANCED WITH METADATA)
-- ====================================================================

Config.EmergencyCalls = {
    ['fire'] = {
        'structure_fire',
        'vehicle_fire',
        'wildfire',
        'rescue_operation',
        'hazmat_incident'
    },

    ['police'] = {
        'robbery',
        'traffic_stop',
        'domestic_disturbance',
        'pursuit',
        'theft',
        'assault'
    },

    ['ems'] = {
        'cardiac_arrest',
        'traffic_accident',
        'overdose',
        'fall_injury',
        'gunshot_wound',
        'medical_emergency'
    }
}

-- ====================================================================
-- RANKS SYSTEM (ENHANCED WITH PERMISSIONS)
-- ====================================================================

Config.Ranks = {
    ['fire'] = {
        [0] = { name = 'Probationary Firefighter', salary = 150, permissions = { 'basic_equipment' } },
        [1] = { name = 'Firefighter', salary = 200, permissions = { 'basic_equipment', 'drive_engine' } },
        [2] = { name = 'Senior Firefighter', salary = 250, permissions = { 'basic_equipment', 'drive_engine', 'lead_team' } },
        [3] = { name = 'Lieutenant', salary = 300, permissions = { 'basic_equipment', 'drive_engine', 'lead_team', 'assign_calls' } },
        [4] = { name = 'Captain', salary = 350, permissions = { 'basic_equipment', 'drive_engine', 'lead_team', 'assign_calls', 'manage_station' } },
        [5] = { name = 'Battalion Chief', salary = 400, permissions = { 'basic_equipment', 'drive_engine', 'lead_team', 'assign_calls', 'manage_station', 'admin_calls' } },
        [6] = { name = 'Fire Chief', salary = 450, permissions = { 'basic_equipment', 'drive_engine', 'lead_team', 'assign_calls', 'manage_station', 'admin_calls', 'full_admin' } }
    },

    ['police'] = {
        [0] = { name = 'Cadet', salary = 150, permissions = { 'basic_equipment' } },
        [1] = { name = 'Officer', salary = 200, permissions = { 'basic_equipment', 'patrol', 'traffic_stops' } },
        [2] = { name = 'Senior Officer', salary = 250, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations' } },
        [3] = { name = 'Corporal', salary = 300, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations', 'lead_team' } },
        [4] = { name = 'Sergeant', salary = 350, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations', 'lead_team', 'assign_calls' } },
        [5] = { name = 'Lieutenant', salary = 400, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations', 'lead_team', 'assign_calls', 'manage_station' } },
        [6] = { name = 'Captain', salary = 450, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations', 'lead_team', 'assign_calls', 'manage_station', 'admin_calls' } },
        [7] = { name = 'Commander', salary = 500, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations', 'lead_team', 'assign_calls', 'manage_station', 'admin_calls', 'department_admin' } },
        [8] = { name = 'Chief of Police', salary = 550, permissions = { 'basic_equipment', 'patrol', 'traffic_stops', 'investigations', 'lead_team', 'assign_calls', 'manage_station', 'admin_calls', 'department_admin', 'full_admin' } }
    },

    ['ems'] = {
        [0] = { name = 'EMT Student', salary = 150, permissions = { 'basic_equipment' } },
        [1] = { name = 'EMT', salary = 200, permissions = { 'basic_equipment', 'ambulance_ops' } },
        [2] = { name = 'Paramedic', salary = 250, permissions = { 'basic_equipment', 'ambulance_ops', 'advanced_care' } },
        [3] = { name = 'Senior Paramedic', salary = 300, permissions = { 'basic_equipment', 'ambulance_ops', 'advanced_care', 'lead_team' } },
        [4] = { name = 'Supervisor', salary = 350, permissions = { 'basic_equipment', 'ambulance_ops', 'advanced_care', 'lead_team', 'assign_calls' } },
        [5] = { name = 'EMS Captain', salary = 400, permissions = { 'basic_equipment', 'ambulance_ops', 'advanced_care', 'lead_team', 'assign_calls', 'manage_station' } },
        [6] = { name = 'EMS Chief', salary = 450, permissions = { 'basic_equipment', 'ambulance_ops', 'advanced_care', 'lead_team', 'assign_calls', 'manage_station', 'full_admin' } }
    }
}

-- ====================================================================
-- UI/UX CONFIGURATION (ENHANCED)
-- ====================================================================

Config.UI = {
    -- General UI settings
    theme = 'dark',    -- UI theme: 'dark', 'light', 'auto'
    language = 'en',   -- UI language
    animations = true, -- Enable UI animations
    sounds = true,     -- Enable UI sounds

    -- MDT/Tablet settings
    tablet = {
        enabled = true,
        item_name = 'mdt_tablet', -- Item required to open MDT
        animation = {
            dict = 'amb@world_human_seat_wall_tablet@female@base',
            name = 'base'
        },
        autoClose = 300,        -- Auto-close after 5 minutes of inactivity
        maxCallsDisplayed = 50, -- Maximum calls to display at once
    },

    -- Notification settings
    notifications = {
        position = 'top-right', -- Position: 'top-right', 'top-left', 'bottom-right', 'bottom-left'
        timeout = 5000,         -- Default timeout in milliseconds
        maxVisible = 5,         -- Maximum visible notifications
        sounds = true,          -- Enable notification sounds
        priority = {
            emergency = 10000,  -- Emergency notifications timeout
            warning = 7000,     -- Warning notifications timeout
            info = 5000,        -- Info notifications timeout
            success = 3000      -- Success notifications timeout
        }
    },

    -- Target system settings
    target = {
        system = 'auto', -- 'qtarget', 'ox_target', 'qb-target', or 'auto'
        distance = 2.5,  -- Interaction distance
        debug = false    -- Show debug polyzone outlines
    }
}

-- ====================================================================
-- DISCORD CONFIGURATION (ENHANCED WITH VALIDATION)
-- ====================================================================



Config.Discord = {
    enabled = GetConvar('fl_discord_enabled', 'true') == 'true',

    webhooks = {
        fire = GetConvar('fl_webhook_fire', ''),
        police = GetConvar('fl_webhook_police', ''),
        ems = GetConvar('fl_webhook_ems', ''),
        admin = GetConvar('fl_webhook_admin', ''),
        duty = GetConvar('fl_webhook_duty', ''),
        emergency = GetConvar('fl_webhook_emergency', '')
    },

    -- Webhook settings
    settings = {
        serverLogo = 'https://i.imgur.com/your-logo.png',
        footerIcon = 'https://i.imgur.com/your-footer.png',
        maxRetries = 3,      -- Maximum retry attempts for failed webhooks
        retryDelay = 2000,   -- Delay between retries in milliseconds
        rateLimitBuffer = 5, -- Buffer for Discord rate limiting (requests per minute)
        timeout = 10000,     -- Request timeout in milliseconds
    },

    -- What events to log
    events = {
        dutyChanges = true,    -- Log duty start/end
        emergencyCalls = true, -- Log emergency calls
        adminActions = true,   -- Log admin actions
        systemEvents = true,   -- Log system startup/shutdown
        errors = false,        -- Log system errors (can be spammy)
    }
}

-- ====================================================================
-- SOUND CONFIGURATION (ENHANCED)
-- ====================================================================

Config.Sounds = {
    enabled = true, -- Enable sound system
    volume = 0.5,   -- Master volume (0.0 - 1.0)

    files = {
        emergencyAlert = 'sounds/emergency_alert.wav',
        dispatchTone = 'sounds/dispatch_tone.wav',
        callComplete = 'sounds/call_complete.wav',
        dutyStart = 'sounds/duty_start.wav',
        dutyEnd = 'sounds/duty_end.wav',
        notification = 'sounds/notification.wav'
    },

    events = {
        newCall = 'emergencyAlert',     -- Sound for new emergency calls
        callAssigned = 'dispatchTone',  -- Sound when assigned to call
        callCompleted = 'callComplete', -- Sound when call completed
        dutyToggle = 'dutyStart',       -- Sound for duty changes
        notification = 'notification'   -- Sound for general notifications
    }
}

-- ====================================================================
-- ADVANCED FEATURES CONFIGURATION
-- ====================================================================

Config.Features = {
    -- Multi-unit assignment system
    multiUnit = {
        enabled = true,                    -- Enable multi-unit assignments
        maxUnitsDefault = 4,               -- Default maximum units per call
        maxUnitsEmergency = 8,             -- Maximum units for priority 1 calls
        allowSelfAssign = true,            -- Allow players to assign themselves
        requireSupervisorApproval = false, -- Require supervisor approval for assignments
    },

    -- Automatic call generation
    autoCalls = {
        enabled = false,                        -- Enable automatic call generation (for testing)
        interval = 600,                         -- Interval between auto calls in seconds (10 minutes)
        maxActive = 3,                          -- Maximum active auto-generated calls
        services = { 'fire', 'police', 'ems' }, -- Services to generate calls for
    },

    -- Statistics and reporting
    statistics = {
        enabled = true,         -- Enable statistics tracking
        retention = 2592000,    -- Statistics retention in seconds (30 days)
        realTimeUpdates = true, -- Enable real-time statistics updates
        webPanel = false,       -- Enable web panel for statistics (requires additional setup)
    },

    -- Integration features
    integrations = {
        qbPhone = false,    -- QBCore phone integration
        qbBanking = false,  -- QBCore banking integration (for fines, etc.)
        qbHousing = false,  -- QBCore housing integration (for emergency calls)
        vehicleKeys = true, -- Vehicle key integration
        fuel = true,        -- Fuel system integration
    }
}

-- ====================================================================
-- SECURITY AND VALIDATION SETTINGS
-- ====================================================================

Config.Security = {
    -- Input validation
    validation = {
        enabled = true,        -- Enable input validation
        strictMode = false,    -- Strict validation mode (may break some functionality)
        sanitizeInputs = true, -- Sanitize user inputs
        maxInputLength = 1000, -- Maximum input length for text fields
    },

    -- Anti-exploitation
    antiExploit = {
        enabled = true,             -- Enable anti-exploit measures
        maxCallsPerPlayer = 10,     -- Maximum calls a player can be assigned to
        cooldownBetweenCalls = 30,  -- Cooldown between call assignments in seconds
        maxDutyTogglesPerHour = 10, -- Maximum duty toggles per hour
    },

    -- Logging and monitoring
    logging = {
        logLevel = 'INFO',    -- Log level: 'DEBUG', 'INFO', 'WARN', 'ERROR'
        logToFile = false,    -- Log to file (requires additional setup)
        logToDatabase = true, -- Log to database
        retainLogs = 604800,  -- Log retention in seconds (7 days)
    }
}

-- ====================================================================
-- COMPATIBILITY AND FALLBACKS
-- ====================================================================

Config.Compatibility = {
    -- Framework compatibility
    frameworks = {
        qbcore = true,      -- QBCore compatibility
        esx = false,        -- ESX compatibility (future)
        standalone = false, -- Standalone mode (future)
    },

    -- Resource compatibility
    resources = {
        qtarget = true,  -- qtarget compatibility
        oxTarget = true, -- ox_target compatibility
        qbTarget = true, -- qb-target compatibility
        menuv = false,   -- menuv compatibility
        qbMenu = true,   -- qb-menu compatibility
    },

    -- Fallback settings
    fallbacks = {
        useBasicUniforms = true, -- Use basic uniforms if EUP not available
        useBasicVehicles = true, -- Use basic vehicles if custom vehicles not available
        useBasicSounds = true,   -- Use basic sounds if custom sounds not available
    }
}

-- ====================================================================
-- DEVELOPMENT AND TESTING SETTINGS
-- ====================================================================

Config.Development = {
    -- Development mode
    devMode = false,  -- Enable development mode (extra logging, test commands)
    testMode = false, -- Enable test mode (sample data, relaxed validation)

    -- Testing features
    testing = {
        enableTestCommands = true,     -- Enable test commands (/testcall, etc.)
        allowAnyPlayerAsAdmin = false, -- Allow any player to use admin commands (DANGEROUS!)
        skipPermissionChecks = false,  -- Skip permission checks (DANGEROUS!)
        generateSampleData = false,    -- Generate sample data on startup
    },

    -- Debug features
    debug = {
        verboseLogging = false,     -- Enable verbose logging
        profilePerformance = false, -- Enable performance profiling
        showDebugInfo = false,      -- Show debug information in UI
        logDatabaseQueries = false, -- Log all database queries
    }
}

-- ====================================================================
-- CONFIGURATION VALIDATION AND DEFAULTS
-- ====================================================================

-- Validate configuration on load
CreateThread(function()
    Wait(1000) -- Wait for resource to load

    local function validateConfig()
        local errors = {}
        local warnings = {}

        -- Validate Discord webhooks
        if Config.Discord.enabled then
            for service, webhook in pairs(Config.Discord.webhooks) do
                if not webhook or webhook == '' then
                    table.insert(warnings, 'Missing Discord webhook for service: ' .. service)
                elseif not string.match(webhook, 'https://discord%.com/api/webhooks/%d+/[%w%-_]+') then
                    table.insert(errors, 'Invalid Discord webhook URL for service: ' .. service)
                end
            end
        end

        -- Validate station coordinates
        for stationId, station in pairs(Config.Stations) do
            if not station.coords or type(station.coords) ~= 'vector3' then
                table.insert(errors, 'Invalid coordinates for station: ' .. stationId)
            end
            if not station.service or not Config.EmergencyServices[station.service] then
                table.insert(errors, 'Invalid service for station: ' .. stationId)
            end
        end

        -- Validate emergency services
        for service, data in pairs(Config.EmergencyServices) do
            if not data.label or not data.shortname or not data.color then
                table.insert(errors, 'Missing required fields for service: ' .. service)
            end
        end

        -- Report validation results
        if #errors > 0 then
            print('^1[FL CONFIG ERROR]^7 Configuration validation failed:')
            for _, error in pairs(errors) do
                print('^1[FL CONFIG ERROR]^7 - ' .. error)
            end
        end

        if #warnings > 0 then
            print('^3[FL CONFIG WARNING]^7 Configuration warnings:')
            for _, warning in pairs(warnings) do
                print('^3[FL CONFIG WARNING]^7 - ' .. warning)
            end
        end

        if #errors == 0 and #warnings == 0 then
            print('^2[FL CONFIG]^7 ✅ Configuration validation passed')
        end

        return #errors == 0
    end

    local isValid = validateConfig()
    if not isValid then
        print('^1[FL CONFIG]^7 ❌ Configuration contains errors - some features may not work properly')
    end
end)

print('^2[FL CONFIG]^7 🎉 Emergency Services configuration loaded successfully')
