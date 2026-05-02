fx_version 'cerulean'
game 'gta5'

name        'yn-chopshop'
description 'Sistema de robo de vehículo y desguace'
version     '1.0.0'
author      'YN Scripts'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/npc.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
}
