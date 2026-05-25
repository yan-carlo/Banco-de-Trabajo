fx_version 'cerulean'
game 'gta5'

name        'yn-dealer-menu'
description 'Menú profesional de dealer — venta y traspaso de vehículos entre jugadores'
version     '1.0.0'
author      'YN Scripts'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/vehicle_utils.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/callbacks.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
