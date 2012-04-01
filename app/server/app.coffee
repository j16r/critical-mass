# Private functions ##########################################################

withSession = (sessionId, process) =>
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

  login: (userName, cb) ->
    console.log "'#{userName}' is attempting to login..."

    R.hget 'users', userName, (error, sessionId) =>
      if sessionId?
        console.log "'#{userName}' is already logged in"
        cb success: false
        
      else
        console.log("making new session for '#{userName}'")
        now = new Date()
        session = {
          id: @session.id,
          userName: userName,
          loggedInAt: now,
          lastHeartbeatAt: now.getTime()
        }
        R.hset 'users', userName, session.id
        R.hset 'sessions', session.id, JSON.stringify(session)
        SS.publish.broadcast 'userSignon', userName
        usersOnline (userNames) =>
          cb success: true, usersOnline: userNames
  
  logout: (cb) ->
    withSession @session.id, (session) =>
      R.hset 'users', session.userName, null
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
      SS.publish.user(player, 'gameOffer', game) for player in game.offeredPlayers

      cb true

  acceptGame: (gameId, player, cb) ->
    return unless game = games[gameId]

    console.log("Player ", player, " accepted: ", game)
    @session.channel.subscribe(game.channel)
    game.readyPlayers.push(player)
    cb true

    SS.publish.user(player, 'acceptOffer', player) for player in game.expectedPlayers

    if game.expectedPlayers.length == game.readyPlayers.length
      SS.publish.channel game.channel, 'gameBegins', game

  playMove: (gameId, x, y, cb) ->
    return unless game = games[gameId]

    # Advance the player
    move = {player: game.currentPlayer, x: x, y: y}
    game.currentPlayer += 1
    game.currentPlayer = 0 if game.currentPlayer == game.readyPlayers.length
    move.newPlayer = game.currentPlayer

    SS.publish.channel game.channel, 'playMove', move

    cb true

