# Private functions ##########################################################

withSession = (sessionId, process) =>
  return unless sessionId?

  R.hget 'sessions', sessionId, (error, sessionData) =>
    if sessionData?
      session = JSON.parse sessionData
      process session
    else
      console.warn "Action called on expired session #{sessionId}"

pollOnlineUsers = () ->
  R.hgetall 'sessions', (error, sessions) =>
    for sessionId, sessionData of sessions
      session = JSON.parse(sessionData)
      unless session? && currentHeartbeat session.lastHeartbeatAt
        console.log "Expiring '#{session.userName}' because they haven't sent a heartbeat in a while"
        R.hdel 'sessions', sessionId
        R.hdel 'users', session.userName
        SS.publish.broadcast 'userTimeout', session.userName

currentHeartbeat = (heartbeatAt) ->
  heartbeatAt? && (new Date().getTime() - heartbeatAt) < 30000

usersOnline = (cb) ->
  R.hgetall 'sessions', (error, sessions) =>
    userNames = (JSON.parse(sessionData).userName for sessionId, sessionData of sessions)
    cb userNames

# Startup #####################################################################

exports.init =
  R.del 'users'
  setInterval (-> pollOnlineUsers()), 1000

# Actions #####################################################################

exports.actions =

  restoreSession: (cb) ->
    console.log "Attempting to restore session for #{@session.id}"
    R.hget 'sessions', @session.id, (error, sessionData) =>
      if sessionData?
        session = JSON.parse sessionData
        console.log "Found session data ", session, session.userName
        SS.publish.broadcast 'userSignon', session.userName
        usersOnline (userNames) =>
          cb success: true, usersOnline: userNames, username: session.userName
      else
        console.log "No session saved for ", @session.id
        cb success: false

  login: (userName, cb) ->
    console.log "'#{userName}' is attempting to login..."

    R.hget 'users', userName, (error, sessionId) =>
      if sessionId?
        console.log "'#{userName}' is already logged in with sessionID #{sessionId}"
        cb success: false
        
      else
        console.log("making new session for '#{userName}':#{@session.id}")
        now = new Date()
        session = {
          id: @session.id,
          userName: userName,
          loggedInAt: now,
          lastHeartbeatAt: now.getTime()
        }
        R.hset 'users', userName, session.id
        R.hset 'sessions', session.id, JSON.stringify(session)
        @session.setUserId(userName)
        SS.publish.broadcast 'userSignon', userName
        usersOnline (userNames) =>
          cb success: true, usersOnline: userNames
  
  logout: (cb) ->
    withSession @session.id, (session) =>
      R.hdel 'users', session.userName
      R.hdel 'sessions', session.id
      SS.publish.broadcast 'userSignoff', session.userName
      cb true
  
  heartbeat: (cb) ->
    withSession @session.id, (session) =>
      session.lastHeartbeatAt = new Date().getTime()
      R.hset 'sessions', session.id, JSON.stringify(session)
      cb true

  sendMessage: (message, cb) ->
    withSession @session.id, (session) =>
      data = {user: session.userName, text: message}
      if message.length > 0
        SS.publish.broadcast 'newMessage', data
        cb true
      else
        cb false

  offerGame: (players, cb) ->
    withSession @session.id, (session) =>
      gameId = session.id
      game = {
        id: gameId,
        host: session.userName,
        channel: "games:#{gameId}"
        currentPlayer: session.userName,
        readyPlayers: [session.userName],
        offeredPlayers: players,
        expectedPlayers: players.concat(session.userName)}

      console.log("Game created: ", game)

      R.hset 'games', gameId, JSON.stringify(game)

      @session.channel.subscribe(game.channel)
      for player in game.offeredPlayers
        console.log("Offering game to ", player)
        SS.publish.user(player, 'gameOffer', game)

      cb true

  acceptGame: (gameId, player, cb) ->
    withSession @session.id, (session) =>
      R.hget 'games', gameId, (error, gameData) =>
        return unless gameData?

        game = JSON.parse gameData
        player = session.userName

        @session.channel.subscribe(game.channel)
        game.readyPlayers.push(player)
        R.hset 'games', gameId, JSON.stringify(game)
        console.log("Player ", player, " accepted: ", game)
        cb true

        SS.publish.user(player, 'acceptOffer', player) for player in game.expectedPlayers

        if game.expectedPlayers.length == game.readyPlayers.length
          SS.publish.channel game.channel, 'gameBegins', game

  playMove: (gameId, x, y, cb) ->
    R.hget 'games', gameId, (error, gameData) =>
      return unless gameData?

      game = JSON.parse gameData

      # Advance the player
      move = {player: game.currentPlayer, x: x, y: y}
      newPlayerIndex = (game.readyPlayers.indexOf(game.currentPlayer) + 1) % game.readyPlayers.length
      game.currentPlayer = game.readyPlayers[newPlayerIndex]
      R.hset 'games', gameId, JSON.stringify(game)
      move.newPlayer = game.currentPlayer

      SS.publish.channel game.channel, 'playMove', move

      cb true
