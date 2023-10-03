fx_version 'cerulean'
game 'gta5'

description 'QBX-Houses'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    '@qb-core/shared/locale.lua',
    '@qbx_core/import.lua',
    'locales/en.lua',
    'locales/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/decorate.lua',
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

modules {
    'qbx_core:core',
    'qbx_core:playerdata',
    'qbx_core:utils'
}

files {
    'html/index.html',
    'html/reset.css',
    'html/style.css',
    'html/script.js',
    'html/img/dynasty8-logo.png'
}

dependencies {
    'qbx_interior',
    'qbx_weathersync'
}

provide 'qb-houses'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
