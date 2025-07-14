fx_version 'cerulean'
game 'gta5'

author 'FlashingLights Emergency Services'
description 'Core module for Emergency Services System - FIXED VERSION 2.0.1'
version '2.0.1'

-- Dependencies (Enhanced with optional dependencies)
dependency 'qb-core'
dependencies {
    'qb-core',
    'qb-target'
}

-- Shared scripts (load order optimized)
shared_scripts {
    'config.lua',
    'shared/*.lua'
}

-- Server scripts (load order critical)
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',     -- FIXED: Rate limiting now properly defined first
    'server/discord.lua',
    'server/vehicles.lua', -- FIXED: FL.Client references corrected
    'server/security.lua',
    'server/monitoring.lua'
}

-- Client scripts (load order optimized)
client_scripts {
    'client/main.lua',           -- FIXED: GetBlipList() and cleanup issues resolved
    'client/qtarget.lua',        -- FIXED: Enhanced target system compatibility
    'client/vehicles.lua',
    'client/vehicle_manager.lua' -- FIXED: 'self' parameter issues resolved
}

-- UI files (Enhanced with sounds and assets)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg',
    'html/img/*.gif',
    'html/sounds/*.wav',
    'html/sounds/*.mp3',
    'html/fonts/*.ttf',
    'html/fonts/*.woff'
}

-- Modern Lua version for better performance
lua54 'yes'

-- Enhanced metadata for resource management
provides {
    'emergency_services',
    'fl_core'
}

-- Client and server exports for other resources
client_exports {
    'GetPlayerServiceInfo',
    'IsPlayerOnDuty',
    'OpenMDT',
    'CloseMDT'
}

server_exports {
    'CreateEmergencyCall',
    'AssignUnitToCall',
    'CompleteEmergencyCall',
    'GetActiveEmergencyCalls',
    'IsPlayerEmergencyService'
}

-- Resource configuration
data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'

-- Escrow protection (if using encrypted parts)
escrow_ignore {
    'config.lua',
    'shared/*.lua',
    'html/**/*',
    'README.md',
    'CHANGELOG.md'
}
