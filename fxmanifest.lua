fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

games { 'rdr3', 'rdr3_common' }

description 'A versitle prop placement script '
author 'Breadlord'
version '1.0.0'

ui_page "html/index.html"

files {
  "html/index.html",
  "html/style.css",
  "html/script.js",
  "shared/catalog.json"
}


shared_scripts {
    'shared/config.lua',
    

}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

escrow_ignore {
    'config/config.lua',
    'shared/config.lua',


}
dependency '/assetpacks'