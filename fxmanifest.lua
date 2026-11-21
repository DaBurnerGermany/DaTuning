fx_version 'cerulean'
game 'gta5'

description 'DaTuning - Fahrzeugwerkstatt für ESX und QBCore'
version '1.0.0'

dependencies {
    '/onesync',
    'oxmysql'
}

shared_scripts { 'locale.lua', 'config.lua', 'framework.lua' }
client_scripts { 'paint.lua', 'client.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'ui/index.html'
files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}
