fx_version 'cerulean'
game 'gta5'

author 'FlashingLights Emergency Services'
description 'Core module for Emergency Services System'
version '1.0.0'

-- QBCore dependency
dependency 'qb-core'

-- Shared scripts (both client and server) - loaded first
shared_scripts {
    'config.lua',
    'shared/*.lua'
}

-- Server scripts - loaded after shared
server_scripts {
    '@oxmysql/lib/MySQL.lua', -- QBCore 1.3.0 uses oxmysql
    'server/database.lua',    -- Auto database setup
    'server/main.lua',        -- QBCore integration version
    -- 'server/commands.lua',   -- REMOVED - using QBCore commands now
}

-- Client scripts
client_scripts {
    'client/main.lua' -- QBCore integration version
}

-- UI files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg'
}

-- Ensure this resource starts after qb-core
dependency 'qb-core'

lua54 'yes'
