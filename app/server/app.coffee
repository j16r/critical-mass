# Server-side Code

exports.actions =

  init: (cb) ->
    username = @session.user_id
    if username
      R.get "user:#{username}", (err, data) =>
        if data
          cb data
          @session.setUserId(username)
          SS.publish.broadcast 'userSignon', username
        else
          cb false
    else
      cb false

  sendMessage: (message, cb) ->
    data = {user: @session.user['session']['user_id'], text: message}
    if message.length > 0
      SS.publish.broadcast 'newMessage', data
      cb true
    else
      cb false

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
    R.del "user:#{username}"
    @session.user.logout(cb)
    SS.publish.broadcast 'userSignoff', username

  offerGame: (host, players, cb) ->
    SS.publish.broadcast 'gameOffer', {host: host, players: players}
    cb true

  acceptGame: (player, cb) ->
    SS.publish.broadcast 'acceptOffer', {player: player}
    cb true

  playMove: (player, x, y, cb) ->
    SS.publish.broadcast 'playMove', {player: player, x: x, y: y}
    cb true
