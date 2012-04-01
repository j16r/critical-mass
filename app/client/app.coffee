# Client-side Code

# Bind to socket events
SS.socket.on 'disconnect', ->
SS.socket.on 'reconnect', ->

# This method is called automatically when the websocket connection is established. Do not rename/delete
exports.init = ->

  # Start the lobby
  SS.client.lobby.init()

  # Start the game
  SS.client.game.init()
