games = {}

exports.actions =

  login: (username, cb) ->
    @session.authenticate 'login', username, (response) =>
      if response.success
        SS.users.online.now (users) ->
          cb({success: true, usersOnline: users})
        @session.setUserId(username)
        SS.publish.broadcast 'userSignon', username
      else
        cb(response)

  logout: (cb) ->
    username = @session.user['session']['user_id']
    @session.user.logout(cb)
    SS.publish.broadcast 'userSignoff', username

  sendMessage: (message, cb) ->
    data = {user: @session.user['session']['user_id'], text: message}
    if message.length > 0
      SS.publish.broadcast 'newMessage', data
      cb true
    else
      cb false

  offerGame: (host, players, cb) ->
    game_id = host
    game = games[game_id] = {
      id: game_id,
      host: host,
      expectedPlayers: players.concat(host),
      offeredPlayers: players,
      readyPlayers: [host],
      currentPlayer: host,
      channel: "games:#{game_id}"}

    @session.channel.subscribe(game.channel)
    SS.publish.user(player, 'gameOffer', game) for player in players

    cb true

  acceptGame: (game_id, player, cb) ->
    SS.publish.user(player, 'acceptOffer', player) for player in players

    return unless game = games[game_id]

    cb true

    @session.channel.subscribe(game.channel)
    game.readyPlayers.push(player)
    if game.expectedPlayers.length == game.readyPlayers.length
      SS.publish.channel game.channel, 'gameBegins', game

  playMove: (game_id, x, y, cb) ->
    return unless game = games[game_id]

    currentPlayer = game.currentPlayer

    newPlayerIndex = game.readyPlayers.indexOf(currentPlayer) + 1
    newPlayerIndex = 0 if newPlayerIndex == game.readyPlayers.length
    game.currentPlayer = game.readyPlayers[newPlayerIndex]

    move = {player: currentPlayer, x: x, y: y, newPlayer: game.currentPlayer}
    SS.publish.channel game.channel, 'playMove', move

    cb true
