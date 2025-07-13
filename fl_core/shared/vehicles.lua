-- ====================================================================
-- FL CORE - EMERGENCY VEHICLE MANAGEMENT SYSTEM
-- Vollständiges Fahrzeug-System für Emergency Services
-- ====================================================================

-- shared/vehicles.lua - Neue Datei erstellen

-- Emergency Vehicle Configuration
Config.EmergencyVehicles = {
    ['fire'] = {
        ['firetruk'] = {
            label = 'Fire Truck',
            model = 'firetruk',
            category = 'heavy',
            seats = 4,
            fuel_capacity = 100,
            equipment_storage = 50,
            water_capacity = 2000,
            required_rank = 1,
            features = {
                sirens = true,
                lights = true,
                ladder = true,
                water_cannon = true,
                rescue_equipment = true
            },
            spawn_locations = {
                'fire_station_1',
                'fire_station_2'
            }
        },
        ['ambulance'] = {
            label = 'Rescue Ambulance',
            model = 'ambulance',
            category = 'rescue',
            seats = 2,
            fuel_capacity = 80,
            equipment_storage = 30,
            required_rank = 0,
            features = {
                sirens = true,
                lights = true,
                rescue_equipment = true,
                medical_bay = true
            },
            spawn_locations = {
                'fire_station_1'
            }
        }
    },

    ['police'] = {
        ['police'] = {
            label = 'Police Cruiser',
            model = 'police',
            category = 'patrol',
            seats = 4,
            fuel_capacity = 65,
            equipment_storage = 20,
            required_rank = 0,
            features = {
                sirens = true,
                lights = true,
                radar = true,
                computer = true,
                prisoner_transport = true
            },
            spawn_locations = {
                'police_station_1',
                'police_station_2'
            }
        },
        ['police2'] = {
            label = 'Police Buffalo',
            model = 'police2',
            category = 'patrol',
            seats = 4,
            fuel_capacity = 70,
            equipment_storage = 25,
            required_rank = 2,
            features = {
                sirens = true,
                lights = true,
                radar = true,
                computer = true,
                pursuit_mode = true
            },
            spawn_locations = {
                'police_station_1'
            }
        },
        ['policeb'] = {
            label = 'Police Bike',
            model = 'policeb',
            category = 'motorcycle',
            seats = 1,
            fuel_capacity = 15,
            equipment_storage = 5,
            required_rank = 1,
            features = {
                sirens = true,
                lights = true,
                speed_boost = true
            },
            spawn_locations = {
                'police_station_1'
            }
        }
    },

    ['ems'] = {
        ['ambulance'] = {
            label = 'Ambulance',
            model = 'ambulance',
            category = 'medical',
            seats = 2,
            fuel_capacity = 70,
            equipment_storage = 40,
            patient_capacity = 2,
            required_rank = 0,
            features = {
                sirens = true,
                lights = true,
                medical_bay = true,
                stretcher = true,
                defibrillator = true
            },
            spawn_locations = {
                'ems_station_1'
            }
        },
        ['lguard'] = {
            label = 'Lifeguard',
            model = 'lguard',
            category = 'rescue',
            seats = 2,
            fuel_capacity = 50,
            equipment_storage = 20,
            required_rank = 1,
            features = {
                sirens = true,
                lights = true,
                water_rescue = true,
                emergency_equipment = true
            },
            spawn_locations = {
                'ems_station_1'
            }
        }
    }
}

-- Vehicle Equipment Storage
Config.VehicleEquipment = {
    ['fire'] = {
        ['firetruk'] = {
            'fire_extinguisher',
            'fire_hose',
            'fire_axe',
            'breathing_apparatus',
            'halligan_tool',
            'thermal_camera',
            'ladder',
            'chainsaw'
        },
        ['ambulance'] = {
            'first_aid_kit',
            'rope',
            'breathing_apparatus',
            'rescue_tools'
        }
    },

    ['police'] = {
        ['police'] = {
            'handcuffs',
            'radar_gun',
            'breathalyzer',
            'spike_strips',
            'body_camera'
        },
        ['police2'] = {
            'handcuffs',
            'radar_gun',
            'breathalyzer',
            'spike_strips',
            'body_camera',
            'tactical_equipment'
        },
        ['policeb'] = {
            'handcuffs',
            'radar_gun',
            'breathalyzer'
        }
    },

    ['ems'] = {
        ['ambulance'] = {
            'defibrillator',
            'medical_bag',
            'stretcher',
            'oxygen_mask',
            'bandages',
            'morphine',
            'iv_drip'
        },
        ['lguard'] = {
            'first_aid_kit',
            'rescue_buoy',
            'oxygen_tank',
            'diving_gear'
        }
    }
}
