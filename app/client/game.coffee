PLAYER_COLORS = ['Blue', 'Red', 'Green', 'Yellow']

TILES_ACROSS = 10
TILES_DOWN = 6

window.game_data =
  currentPlayer: null
  players: null
  scores: null
  currentGame: null

exports.init = ->

  # SS Event handlers ##########################################################

  SS.events.on 'gameOffer', (game) ->
    SS.client.lobby.announce($('<p>').text("#{game.host} has offered to play a game with you. ").append($('<a>').attr('id', 'accept').text('Click here to accept.').data('game_id', game.id)), 'gameOffer')

  SS.events.on 'acceptOffer', (player) ->
    SS.client.lobby.announce("#{player} has accepted the game", 'acceptOffer')

  SS.events.on 'gameBegins', (game, channel_name) ->
    SS.client.lobby.announce('All players have accepted the game', 'gameBegins')
    activateGame(game)

  SS.events.on 'playMove', (move, channel_name) ->
    player = move.player
    tile = lookupTile(move.x, move.y)

    owner = tile.data('owner')
    return unless owner is player or not owner?

    game_data.scores[player] += 1
    updateScoreBoard()
    fuseAtoms(player, tile)

    game_data.currentPlayer = move.newPlayer

  # DOM Event handlers #########################################################

  $('#accept').live 'click', ->
    game_id = $(this).data('game_id')
    SS.server.app.acceptGame game_id, lobby_data.currentUser, (success) ->

  $('#board img').live 'click', ->
    return if game_data.currentPlayer isnt lobby_data.currentUser || !playerAlive(lobby_data.currentUser)

    x = $(this).data('x')
    y = $(this).data('y')
    SS.server.app.playMove game_data.currentGame, x, y, (success) ->

  # Functions #################################################################

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
        tile[0].src = "/images/empty_tile.png"

        # Place atoms in adjacent tiles unless the game is over
        unless gameOver()
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

  gameOver = ->
    $('#playerList li:not(.gameOver)').length == 1

  updateScoreBoard = ->
    $.each game_data.players, (index, player) ->
      $("#playerList li##{player} span").text(game_data.scores[player])

  playerLost = (player) ->
    $("#playerList li##{player}").addClass('gameOver')

  playerAlive = (player) ->
    not $("#playerList li##{player}").hasClass('gameOver')

  playerColor = (player) ->
    player_index = game_data.players.indexOf(player)
    PLAYER_COLORS[player_index]

  activateGame = (game) ->
    game_data.scores = {}
    game_data.currentPlayer = game.currentPlayer
    game_data.players = game.readyPlayers
    game_data.currentGame = game.id

    clearGameBoard()
    clearScoreBoard()
    drawScoreBoard()
    drawGameBoard()

    SS.client.lobby.slideLobby($('#topmenu').outerHeight() + $('#game').outerHeight(true))
    $('#game').fadeIn()

  lookupTile = (x, y) ->
    $("#board ol:nth-child(#{y}) li:nth-child(#{x}) img")

  clearScoreBoard = ->
    $('#playerList').children().remove()
  
  clearGameBoard = ->
    $('#board').children().remove()

  drawScoreBoard = ->
    $.each game_data.players, (index, player) ->
      $('<li>').attr('id', player).append($('<a>').text(player).add($('<span>').text('0'))).appendTo('#playerList')
      game_data.scores[player] = 0

  drawGameBoard = ->
    for y in [1..TILES_DOWN]
      $('#board').append($('<ol>'))
      row = $('#board ol:last-child')
      for x in [1..TILES_ACROSS]
        row.append($('<li>').append($('<img>').attr('src', '/images/empty_tile.png')))
        $('#board ol:last-child li:last-child img').data('x', x).data('y', y)

    $('#board ol:first-child li:first-child img').addClass('corner')
    $('#board ol:first-child li:last-child img').addClass('corner')
    $('#board ol:last-child li:first-child img').addClass('corner')
    $('#board ol:last-child li:last-child img').addClass('corner')

    $('#board ol:first-child li img').addClass('edge')
    $('#board ol:last-child li img').addClass('edge')
    $('#board ol li:first-child img').addClass('edge')
    $('#board ol li:last-child img').addClass('edge')
