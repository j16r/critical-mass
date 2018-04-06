redis_ = require('redis')
redis = redis_.createClient()

# Private functions ##########################################################

withSession = (sessionId, process) =>
  return unless sessionId?

  redis.hget 'sessions', sessionId, (error, sessionData) =>
    if sessionData?
      session = JSON.parse sessionData
      process session
    else
      console.warn "Action called on expired session #{sessionId}"

isCurrentHeartbeat = (heartbeatAt) ->
  heartbeatAt? && (new Date().getTime() - heartbeatAt) < 30000

usersOnline = (response) ->
  redis.hgetall 'sessions', (error, sessions) =>
    userNames = (JSON.parse(sessionData).userName for sessionId, sessionData of sessions)
    response userNames

pollOnlineUsers = ->
  console.log("Polling sessions")
  redis.hgetall 'sessions', (error, sessions) =>
    console.log("Sessions: #{sessions}")
    for sessionId, sessionData of sessions
      console.log("Polling #{sessionId}")
      session = JSON.parse(sessionData)
      unless session? && isCurrentHeartbeat session.lastHeartbeatAt
        console.log "Expiring '#{session.userName}' because they haven't sent a heartbeat in a while"
        redis.hdel 'sessions', sessionId
        redis.hdel 'users', session.userName
        ss.publish.broadcast 'userTimeout', session.userName

redis.on 'ready', ->
  console.log("redis ready")
  redis.del 'sessions'
  #setInterval pollOnlineUsers, 1000

exports.actions = (request, response, ss) ->

  request.use('session')

  # Actions ####################################################################

  login: (userName) ->
    console.log "'#{userName}' is attempting to login..."

    redis.hget 'users', userName, (error, sessionId) =>
      if sessionId?
        console.log "'#{userName}' is already logged in with sessionID #{sessionId}"
        response success: false
        
      else
        console.log("making new session for '#{userName}':#{request.session.id}")
        now = new Date()
        session = {
          id: request.session.id,
          userName: userName,
          loggedInAt: now,
          lastHeartbeatAt: now.getTime()
        }
        redis.hset 'users', userName, session.id
        redis.hset 'sessions', session.id, JSON.stringify(session)
        request.session.setUserId(userName)
        ss.publish.broadcast 'userSignon', userName
        usersOnline (userNames) =>
          response success: true, usersOnline: userNames

  restoreSession: ->
    console.log "Attempting to restore session for #{request.session.id}"
    redis.hget 'sessions', request.session.id, (error, sessionData) =>
      if sessionData?
        session = JSON.parse sessionData
        console.log "Found session data ", session, session.userName
        ss.publish.broadcast 'userSignon', session.userName
        usersOnline (userNames) =>
          response success: true, usersOnline: userNames, username: session.userName
      else
        console.log "No session saved for ", request.session.id
        response success: false

  logout: ->
    withSession request.session.id, (session) =>
      redis.hdel 'users', session.userName
      redis.hdel 'sessions', session.id
      ss.publish.broadcast 'userSignoff', session.userName
      response true
  
  heartbeat: ->
    withSession request.session.id, (session) =>
      session.lastHeartbeatAt = new Date().getTime()
      redis.hset 'sessions', session.id, JSON.stringify(session)
      response true

  sendMessage: (message) ->
    withSession request.session.id, (session) =>
      data = {user: session.userName, text: message}
      if message.length > 0
        ss.publish.broadcast 'newMessage', data
        response true
      else
        response false

  offerGame: (players) ->
    withSession request.session.id, (session) =>
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

      redis.hset 'games', gameId, JSON.stringify(game)

      request.session.channel.subscribe(game.channel)
      for player in game.offeredPlayers
        console.log("Offering game to ", player)
        ss.publish.user(player, 'gameOffer', game)

      response true

  acceptGame: (gameId, player) ->
    withSession request.session.id, (session) =>
      redis.hget 'games', gameId, (error, gameData) =>
        return unless gameData?

        game = JSON.parse gameData
        player = session.userName

        request.session.channel.subscribe(game.channel)
        game.readyPlayers.push(player)
        redis.hset 'games', gameId, JSON.stringify(game)
        console.log("Player ", player, " accepted: ", game)
        response true

        ss.publish.user(player, 'acceptOffer', player) for player in game.expectedPlayers

        if game.expectedPlayers.length == game.readyPlayers.length
          ss.publish.channel game.channel, 'gameBegins', game

  playMove: (gameId, x, y) ->
    redis.hget 'games', gameId, (error, gameData) =>
      return unless gameData?

      game = JSON.parse gameData

      # Advance the player
      move = {player: game.currentPlayer, x: x, y: y}
      newPlayerIndex = (game.readyPlayers.indexOf(game.currentPlayer) + 1) % game.readyPlayers.length
      game.currentPlayer = game.readyPlayers[newPlayerIndex]
      redis.hset 'games', gameId, JSON.stringify(game)
      move.newPlayer = game.currentPlayer

      ss.publish.channel game.channel, 'playMove', move

      response true

