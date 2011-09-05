PLAYER_COLORS = ['Blue', 'Red', 'Green', 'Yellow']

TILES_ACROSS = 10
TILES_DOWN = 6

window.game_data =
  expectedPlayers: null
  readyPlayers: null
  scores: null
  currentPlayer: null

exports.init = ->

  # A game offer has been made
  SS.events.on 'gameOffer', (message) ->
    if lobby_data.currentUser is message.host
      beginGame(message.host, message.players)
      $("<tr><td colspan='2' class='announce gameOffer'>You have offered to host a game for #{message.players}</td></tr>").hide().appendTo('#chatlog').slideDown()
    else if lobby_data.currentUser in message.players
      beginGame(message.host, message.players)
      $("<tr><td colspan='2' class='announce gameOffer'>#{message.host} has offered to play a game with you, <a id='accept' href='#'>click here to accept</a></td></tr>").hide().appendTo('#chatlog').slideDown()

  # A game offer has been accepted
  SS.events.on 'acceptOffer', (message) ->
    if lobby_data.currentUser isnt message.player
      $("<tr><td colspan='2' class='announce acceptOffer'>#{message.player} has accepted the game</td></tr>").hide().appendTo('#chatlog').slideDown()

    if message.player in game_data.expectedPlayers
      game_data.readyPlayers.push(message.player)

    if allPlayersReady()
      $("<tr><td colspan='2' class='announce gameBegins'>All players have accepted the game.</td></tr>").hide().appendTo('#chatlog').slideDown()
      activateGame()

  SS.events.on 'playMove', (message) ->
    return if gameOver()

    player = message.player
    tile = lookupTile(message.x, message.y)

    owner = tile.data('owner')
    return unless owner is player or not owner?

    game_data.scores[player] += 1
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
        previous_score = game_data.scores[old_owner]
        game_data.scores[old_owner] -= old_atoms
        if previous_score > 0 && game_data.scores[old_owner] == 0
          playerLost(old_owner)
        game_data.scores[player] += old_atoms
        updateScoreBoard()
        return if gameOver()

  gameOver = ->
    game_data.readyPlayers.length - $('#playerList li.gameOver').length == 1

  updateScoreBoard = ->
    $.each game_data.readyPlayers, (index, player) ->
      $("#playerList li##{player} span").text(game_data.scores[player])

  playerLost = (player) ->
    $("#playerList li##{player}").addClass('gameOver')

  playerAlive = (player) ->
    not $("#playerList li##{player}").hasClass('gameOver')

  playerColor = (player) ->
    player_index = game_data.readyPlayers.indexOf(player)
    PLAYER_COLORS[player_index]

  $('#board img').live 'click', ->
    return if gameOver()

    if playerAlive(lobby_data.currentUser)
      x = $(this).data('x')
      y = $(this).data('y')
      SS.server.app.playMove lobby_data.currentUser, x, y, (success) ->
        console.log("Player #{lobby_data.currentUser} played at #{x}, #{y}")

  beginGame = (host, players) ->
    game_data.expectedPlayers = players.concat(host)
    game_data.readyPlayers = [host]

  allPlayersReady = ->
    game_data.expectedPlayers.length == game_data.readyPlayers.length

  activateGame = ->
    $('#game').fadeIn()
    game_data.scores = {}
    drawScoreBoard()
    drawGameBoard()

  lookupTile = (x, y) ->
    $("#board ol:nth-child(#{y}) li:nth-child(#{x}) img")

  drawScoreBoard = ->
    $('#playerList').children().remove()

    $.each game_data.readyPlayers, (index, player) ->
      $("<li id='#{player}'><a>#{player}</a><span>0</span></li>").hide().appendTo('#playerList').slideDown()
      game_data.scores[player] = 0

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
