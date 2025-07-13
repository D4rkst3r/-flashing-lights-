-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - CORE CONFIGURATION
-- ====================================================================

Config = {}

-- System Settings
Config.Debug = true          -- Debug mode for development
Config.Locale = 'en'         -- Language setting
Config.Framework = 'qb-core' -- Framework type

-- Database Settings
Config.Database = {
    useOxMySQL = true,            -- QBCore 1.3.0 uses oxmysql
    tablePrefix = 'fl_',          -- Prefix for all FL tables
    autoSetup = {
        enabled = true,           -- Enable automatic database setup
        createViews = true,       -- Create database views for easy data access
        createTriggers = true,    -- Create triggers for automatic statistics
        createSamples = true,     -- Create sample data (set to true for testing)
        cleanupProcedures = true, -- Create cleanup procedures
        scheduledEvents = false   -- Create scheduled cleanup events (requires event_scheduler = ON)
    }
}

-- Emergency Services Configuration
Config.EmergencyServices = {
    ['fire'] = {
        label = 'Fire Department',
        shortname = 'FD',
        color = '#e74c3c', -- Red
        blip = 436,        -- Fire station blip
        uniform_type = 'fire',
        vehicles = {
            'firetruk', -- Fire Truck
            'ambulance' -- For rescue operations
        }
    },
    ['police'] = {
        label = 'Police Department',
        shortname = 'PD',
        color = '#3498db', -- Blue
        blip = 60,         -- Police station blip
        uniform_type = 'police',
        vehicles = {
            'police',
            'police2',
            'police3',
            'policeb' -- Police bike
        }
    },
    ['ems'] = {
        label = 'Emergency Medical Services',
        shortname = 'EMS',
        color = '#2ecc71', -- Green
        blip = 61,         -- Hospital blip
        uniform_type = 'ems',
        vehicles = {
            'ambulance',
            'lguard' -- Lifeguard vehicle
        }
    }
}

-- Station Locations & Markers
Config.Stations = {
    -- Fire Department Stations
    ['fire_station_1'] = {
        service = 'fire',
        name = 'Fire Station 1',
        coords = vector3(1193.54, -1464.17, 34.86), -- Los Santos Fire Department
        garage_coords = vector3(1179.02, -1464.92, 34.86),

        -- Duty markers
        duty_marker = {
            coords = vector3(1197.42, -1460.85, 34.86),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 255, g = 0, b = 0, a = 100 } -- Red marker
        },

        -- Vehicle spawn points
        vehicle_spawns = {
            vector4(1179.02, -1464.92, 34.86, 90.0),
            vector4(1179.02, -1458.92, 34.86, 90.0)
        },

        -- Equipment lockers
        equipment_coords = vector3(1200.12, -1456.78, 34.86)
    },

    -- Police Department Stations
    ['police_station_1'] = {
        service = 'police',
        name = 'Mission Row Police Station',
        coords = vector3(441.7, -982.0, 30.67), -- Mission Row PD
        garage_coords = vector3(454.6, -1017.4, 28.4),

        duty_marker = {
            coords = vector3(449.67, -992.21, 30.68),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 0, g = 0, b = 255, a = 100 } -- Blue marker
        },

        vehicle_spawns = {
            vector4(454.6, -1017.4, 28.4, 90.0),
            vector4(454.6, -1014.4, 28.4, 90.0),
            vector4(454.6, -1011.4, 28.4, 90.0)
        },

        equipment_coords = vector3(459.35, -999.55, 30.68)
    },

    -- EMS Stations
    ['ems_station_1'] = {
        service = 'ems',
        name = 'Pillbox Hill Medical Center',
        coords = vector3(306.52, -595.62, 43.28), -- Pillbox Hospital
        garage_coords = vector3(307.21, -603.15, 43.28),

        duty_marker = {
            coords = vector3(310.54, -598.75, 43.28),
            size = vector3(2.0, 2.0, 1.0),
            color = { r = 0, g = 255, b = 0, a = 100 } -- Green marker
        },

        vehicle_spawns = {
            vector4(307.21, -603.15, 43.28, 342.0),
            vector4(303.21, -607.15, 43.28, 342.0)
        },

        equipment_coords = vector3(314.26, -593.34, 43.28)
    }
}

-- EUP Clothing Configuration
Config.Uniforms = {
    ['fire'] = {
        male = {
            tshirt_1 = 15,
            tshirt_2 = 0, -- Undershirt
            torso_1 = 314,
            torso_2 = 0,  -- Fire jacket (EUP)
            arms = 19,    -- Arms
            pants_1 = 134,
            pants_2 = 0,  -- Fire pants (EUP)
            shoes_1 = 25,
            shoes_2 = 0,  -- Boots
            helmet_1 = 122,
            helmet_2 = 0, -- Fire helmet (EUP)
            chain_1 = 126,
            chain_2 = 0   -- Air tank (EUP)
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
            chain_2 = 0
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
            pants_2 = 0, -- Police pants
            shoes_1 = 25,
            shoes_2 = 0, -- Boots
            chain_1 = 58,
            chain_2 = 0, -- Police vest
            helmet_1 = -1,
            helmet_2 = 0 -- No helmet by default
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
            helmet_2 = 0
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
            helmet_2 = 0
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
            helmet_2 = 0
        }
    }
}

-- Equipment Items per Service
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

-- Emergency Call Types
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

-- Notification Settings
Config.Notifications = {
    position = 'top-right', -- Position of notifications
    timeout = 5000,         -- How long notifications stay (ms)
    sounds = true           -- Enable notification sounds
}

-- Permissions & Ranks
Config.Ranks = {
    ['fire'] = {
        [0] = 'Probationary Firefighter',
        [1] = 'Firefighter',
        [2] = 'Senior Firefighter',
        [3] = 'Lieutenant',
        [4] = 'Captain',
        [5] = 'Battalion Chief',
        [6] = 'Fire Chief'
    },

    ['police'] = {
        [0] = 'Cadet',
        [1] = 'Officer',
        [2] = 'Senior Officer',
        [3] = 'Corporal',
        [4] = 'Sergeant',
        [5] = 'Lieutenant',
        [6] = 'Captain',
        [7] = 'Commander',
        [8] = 'Chief of Police'
    },

    ['ems'] = {
        [0] = 'EMT Student',
        [1] = 'EMT',
        [2] = 'Paramedic',
        [3] = 'Senior Paramedic',
        [4] = 'Supervisor',
        [5] = 'EMS Captain',
        [6] = 'EMS Chief'
    }
}

-- Tablet/MDT Configuration
Config.MDT = {
    enabled = true,
    item_name = 'mdt_tablet', -- Item required to open MDT
    animation = {
        dict = 'amb@world_human_seat_wall_tablet@female@base',
        name = 'base'
    }
}
-- UI Configuration
Config.UseAdvancedUI = true  -- Use UI menus instead of direct toggle
Config.TargetSystem = 'auto' -- 'qtarget', 'ox_target', 'qb-target', or 'auto'

-- Add icons to existing service config
Config.EmergencyServices = {
    ['fire'] = {
        label = 'Fire Department',
        shortname = 'FD',
        color = '#e74c3c',
        blip = 436,
        icon = 'fas fa-fire', -- NEW
        uniform_type = 'fire',
        vehicles = {          -- NEW
            'firetruk',
            'ambulance'
        }
    },
    ['police'] = {
        label = 'Police Department',
        shortname = 'PD',
        color = '#3498db',
        blip = 60,
        icon = 'fas fa-shield-alt', -- NEW
        uniform_type = 'police',
        vehicles = {                -- NEW
            'police',
            'police2',
            'police3',
            'policeb'
        }
    },
    ['ems'] = {
        label = 'Emergency Medical Services',
        shortname = 'EMS',
        color = '#2ecc71',
        blip = 61,
        icon = 'fas fa-ambulance', -- NEW
        uniform_type = 'ems',
        vehicles = {               -- NEW
            'ambulance',
            'lguard'
        }
    }
}

-- Discord Configuration (NEW SECTION)
Config.Discord = {
    enabled = true,
    webhooks = {
        fire = '',                                      -- YOUR_FIRE_WEBHOOK_URL
        police = '',                                    -- YOUR_POLICE_WEBHOOK_URL
        ems = '',                                       -- YOUR_EMS_WEBHOOK_URL
        admin = '',                                     -- YOUR_ADMIN_WEBHOOK_URL
        duty = '',                                      -- YOUR_DUTY_WEBHOOK_URL
        emergency = ''                                  -- YOUR_EMERGENCY_WEBHOOK_URL
    },
    server_logo = 'https://i.imgur.com/your-logo.png',  -- Optional
    footer_icon = 'https://i.imgur.com/your-footer.png' -- Optional
}

-- Sound Configuration (NEW SECTION)
Config.Sounds = {
    enabled = true,
    emergency_alert = 'sounds/emergency_alert.wav',
    dispatch_tone = 'sounds/dispatch_tone.wav',
    call_complete = 'sounds/call_complete.wav'
}
