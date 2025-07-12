fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Flashing Lights Core System for Emergency Services'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua',
    'shared/functions.lua'
}

client_scripts {
    'client/main.lua',
    'client/utils.lua',
    'client/markers.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/callbacks.lua'
}

-- BACKUP: Falls die moderne UI Probleme macht, verwende die minimale Version
-- ui_page 'html/minimal.html'  -- Einfache, sichere Version
ui_page 'html/index.html' -- Moderne Version

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/modern-style.css',
    'html/modern-script.js',
    'html/minimal.html'
}

dependencies {
    'qb-core',
    'oxmysql'
}

lua54 'yes'
