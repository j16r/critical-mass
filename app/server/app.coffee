# Server-side Code

exports.actions =
  
  sendMessage: (message, cb) ->
    data = {user: @session.user['session']['user_id'], text: message}
    if message.length > 0
      SS.publish.broadcast 'newMessage', data
      cb true
    else
      cb false

  login: (username, cb) ->
    @session.authenticate 'login', username, (response) =>
      @session.setUserId(username)
      SS.users.online.now (users) ->
        SS.publish.broadcast 'usersOnline', users
      cb(response)

  logout: (cb) ->
    @session.user.logout(cb)

  offerGame: (host, players, cb) ->
    SS.publish.broadcast 'gameOffer', {host: host, players: players}
    cb true

  acceptGame: (player, cb) ->
    SS.publish.broadcast 'acceptOffer', {player: player}
    cb true

  playMove: (player, x, y, cb) ->
    SS.publish.broadcast 'playMove', {player: player, x: x, y: y}
    cb true
