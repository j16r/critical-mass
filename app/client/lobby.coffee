userList = {}
currentUser = null
expectedPlayers = null
readyPlayers = null
scores = null

PLAYER_COLORS = ['Blue', 'Red', 'Green', 'Yellow']

TILES_ACROSS = 10
TILES_DOWN = 6

# The game lobby, where people go to find others to play games with
exports.init = ->

  # Periodically publish the list of users online
  SS.events.on 'usersOnline', (users) ->
    $.each users, (index, user) ->
      if not userList[user]
        userList[user] = true
        $("<li>#{user}</li>").hide().appendTo('#userlist').slideDown()
        $("<tr><td colspan='2' class='announce signon'>#{user} signed on</td></tr>").hide().appendTo('#chatlog').slideDown()

  # Listen for new messages and append them to the screen
  SS.events.on 'newMessage', (message) ->
    $("<tr><th>#{message['user']}</th><td>#{message['text']}</td></tr>").hide().appendTo('#chatlog').slideDown()
    $('#channel').animate({scrollTop: $('#chatlog').height()}, 0)

  # A game offer has been made
  SS.events.on 'gameOffer', (message) ->
    if currentUser is message.host
      beginGame(message.host, message.players)
      $("<tr><td colspan='2' class='announce gameOffer'>You have offered to host a game for #{message.players}</td></tr>").hide().appendTo('#chatlog').slideDown()
    else if currentUser in message.players
      beginGame(message.host, message.players)
      $("<tr><td colspan='2' class='announce gameOffer'>#{message.host} has offered to play a game with you, <a id='accept' href='#'>click here to accept</a></td></tr>").hide().appendTo('#chatlog').slideDown()

  # A game offer has been accepted
  SS.events.on 'acceptOffer', (message) ->
    if currentUser isnt message.player
      $("<tr><td colspan='2' class='announce acceptOffer'>#{message.player} has accepted the game</td></tr>").hide().appendTo('#chatlog').slideDown()

    if message.player in expectedPlayers
      readyPlayers.push(message.player)

    if allPlayersReady()
      $("<tr><td colspan='2' class='announce gameBegins'>All players have accepted the game.</td></tr>").hide().appendTo('#chatlog').slideDown()
      activateGame()

  SS.events.on 'playMove', (message) ->
    return if gameOver()

    player = message.player
    tile = lookupTile(message.x, message.y)

    owner = tile.data('owner')
    return unless owner is player or not owner?

    scores[player] += 1
    updateScoreBoard()
    fuseAtoms(player, tile)

  fuseAtoms = (player, tile) ->
    tiles = [tile]
    while tile = tiles.pop()
      x = tile.data('x')
      y = tile.data('y')
      old_atoms = (tile.data('atoms') || 0)
      old_owner = tile.data('owner')

      # New owner
      tile.data('owner', player)

      # Set new amount of atoms
      atoms = (old_atoms || 0) + 1

      if tile.hasClass('corner') && atoms > 1 || tile.hasClass('edge') && atoms > 2 || atoms > 3
        tile.data('atoms', null)
        tile.data('owner', null)
        tile[0].src = "/images/Tile.png"

        # Place atoms in adjacent tiles
        tiles.push(lookupTile(x - 1, y)) if x > 1
        tiles.push(lookupTile(x + 1, y)) if x < TILES_ACROSS
        tiles.push(lookupTile(x, y - 1)) if y > 1
        tiles.push(lookupTile(x, y + 1)) if y < TILES_DOWN

      else
        tile.data('atoms', atoms)
        tile[0].src = "/images/#{playerColor(player)}_#{atoms}.png"

      # Update the scores
      if old_owner? and old_owner isnt player
        previous_score = scores[old_owner]
        scores[old_owner] -= old_atoms
        if previous_score > 0 && scores[old_owner] == 0
          playerLost(old_owner)
        scores[player] += old_atoms
        updateScoreBoard()
        return if gameOver()

  gameOver = ->
    readyPlayers.length - $('#playerList li.gameOver').length == 1

  updateScoreBoard = ->
    $.each readyPlayers, (index, player) ->
      $("#playerList li##{player} span").text(scores[player])

  playerLost = (player) ->
    $("#playerList li##{player}").addClass('gameOver')

  playerAlive = (player) ->
    not $("#playerList li##{player}").hasClass('gameOver')

  playerColor = (player) ->
    player_index = readyPlayers.indexOf(player)
    PLAYER_COLORS[player_index]

  # Show the chat form and bind to the submit action
  # Note how we're passing the message to the server-side method as the first argument
  # If you wish to pass multiple variable use an object - e.g. {message: 'hi!', nickname: 'socket'}
  $('#chatroom').show().submit ->
    message = $('#message').val()
    if message.length > 0
      SS.server.app.sendMessage message, (success) ->
        if success
          $('#message').val('')
        else
          alert('Unable to send message')

  # User logins
  $('#login').show().submit ->
    username = $('#username').val()
    if username.length > 0
      SS.server.app.login username, (success) ->
        if success
          revealMainScreen()
          currentUser = username

  $('#userlist li').live 'click',  ->
    if $(this).text() isnt currentUser

      if selectedUsers().length < 3
        if $(this).hasClass('selected')
          $(this).removeClass('selected')
        else
          $(this).addClass('selected')

      if selectedUsers().length > 0
        $('#startGame').addClass('active')
      else
        $('#startGame').removeClass('active')

  $('#startGame.active').live 'click', ->
    SS.server.app.offerGame currentUser, selectedUsers(), (success) ->
      console.log('Game offered')

  $('#accept').live 'click', ->
    SS.server.app.acceptGame currentUser, (success) ->
      console.log('Game accepted')

  $('#logout').click ->
    SS.server.app.logout (success) ->
      if success
        $('#main').hide()
        $('#logout').hide()
        $('#authentication').fadeIn()

  $('#board img').live 'click', ->
    return if gameOver()

    if playerAlive(currentUser)
      x = $(this).data('x')
      y = $(this).data('y')
      SS.server.app.playMove currentUser, x, y, (success) ->
        console.log("Player #{currentUser} played at #{x}, #{y}")

  revealMainScreen = ->
    $('#authentication').fadeOut()
    $('#main').show()

  selectedUsers = ->
    $.map $('#userlist li.selected'), (li, index) ->
      $(li).text()

  allPlayersReady = ->
    expectedPlayers.length == readyPlayers.length

  beginGame = (host, players) ->
    expectedPlayers = players.concat(host)
    readyPlayers = [host]

  activateGame = ->
    $('#game').fadeIn()
    scores = {}
    drawScoreBoard()
    drawGameBoard()

  lookupTile = (x, y) ->
    $("#board ol:nth-child(#{y}) li:nth-child(#{x}) img")

  drawScoreBoard = ->
    $('#playerList').children().remove()

    $.each readyPlayers, (index, player) ->
      $("<li id='#{player}'><a>#{player}</a><span>0</span></li>").hide().appendTo('#playerList').slideDown()
      scores[player] = 0

  drawGameBoard = ->
    $('#board').children().remove()

    for y in [1..TILES_DOWN]
      $('#board').append($('<ol>'))
      row = $('#board ol:last-child')
      for x in [1..TILES_ACROSS]
        row.append($("<li><img src='/images/Tile.png'></li>"))
        $('#board ol:last-child li:last-child img').data('x', x).data('y', y)

    $('#board ol:first-child li:first-child img').addClass('corner')
    $('#board ol:first-child li:last-child img').addClass('corner')
    $('#board ol:last-child li:first-child img').addClass('corner')
    $('#board ol:last-child li:last-child img').addClass('corner')

    $('#board ol:first-child li img').addClass('edge')
    $('#board ol:last-child li img').addClass('edge')
    $('#board ol li:first-child img').addClass('edge')
    $('#board ol li:last-child img').addClass('edge')
