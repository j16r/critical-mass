window.ss = require('socketstream')

ss.server.on 'ready', ->

  jQuery ->
    require('/lobby')
    require('/game')
