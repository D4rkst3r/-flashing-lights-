fx_version 'cerulean'
game 'gta5'

author 'FlashingLights Emergency Services'
description 'Core module for Emergency Services System - ENHANCED VERSION'
version '2.0.0'

-- Dependencies
dependency 'qb-core'
dependency 'qtarget' -- or 'ox_target' or 'qb-target'

-- Shared scripts
shared_scripts {
    'config.lua',
    'shared/*.lua'
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/discord.lua', -- NEW
    'server/vehicles.lua' -- NEW
}

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/qtarget.lua', -- NEW
    'client/vehicles.lua' -- NEW
}

-- UI files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg',
    'html/sounds/*.wav', -- NEW
    'html/sounds/*.mp3'  -- NEW
}

lua54 'yes'
