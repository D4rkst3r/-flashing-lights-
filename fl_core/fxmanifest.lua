fx_version 'cerulean'
game 'gta5'

author 'FlashingLights Emergency Services'
description 'Core module for Emergency Services System - FIXED VERSION'
version '1.1.0'

-- QBCore dependency
dependency 'qb-core'

-- Shared scripts (both client and server) - loaded first
shared_scripts {
    'config.lua',
    'shared/*.lua'
}

-- Server scripts - loaded after shared (FIXED Ladereihenfolge)
server_scripts {
    '@oxmysql/lib/MySQL.lua', -- QBCore 1.3.0 uses oxmysql
    'server/main.lua',        -- Main server script with fixed NUI handling
    -- database.lua entfernt da redundant zu main.lua
}

-- Client scripts (FIXED - Main enthält jetzt alle NUI Callbacks)
client_scripts {
    'client/main.lua' -- Contains ALL client logic including NUI callbacks
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
