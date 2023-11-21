fx_version 'cerulean'
game 'gta5'

description 'QBX_Houses'
repository 'https://github.com/Qbox-project/qbx_houses'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/utils.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/reset.css',
    'html/style.css',
    'html/script.js',
    'html/img/dynasty8-logo.png'
}

dependencies {
    'qbx_interior',
    'Renewed-Weathersync'
}

provide 'qb-houses'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
