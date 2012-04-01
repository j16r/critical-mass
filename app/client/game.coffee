TILES_ACROSS = 10
TILES_DOWN = 6

window.game_data =
  currentGame: null

exports.init = ->

  # SS Event handlers ##########################################################

  SS.events.on 'gameOffer', (game) ->
    acceptLink = $('<a>').text('Click here to accept.').click ->
      SS.server.app.acceptGame game.id, SS.client.lobby.currentUser(), (success) ->

    SS.client.lobby.announce($('<span>').text("#{game.host} has offered to play a game with you. ").append(acceptLink), 'gameOffer')

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

    addToPlayerScore(player, 1)

    fuseAtoms(player, tile)

    $('#playerList li').removeClass('active')
    $("#playerList li:nth-child(#{move.player})").addClass('active')

  # DOM Event handlers #########################################################
  
  currentPlayerName = (currentPlayerIndex) ->
    $("#playerList li:nth-child(#{currentPlayerIndex + 1})").attr('id')

  $('#board img').live 'click', ->
    return if currentPlayerName(game_data.currentPlayer) isnt SS.client.lobby.currentUser()

    x = $(this).data('x')
    y = $(this).data('y')
    SS.server.app.playMove game_data.currentGame, x, y, (success) ->

  # Functions #################################################################

  playerIndex = (player) ->
    foundIndex = null
    $.each $('#playerList li'), (index, element) ->
      foundIndex = index if $(element).attr('id') is player
    foundIndex

  fuseAtoms = (player, tile) ->
    playerIndex = playerIndex(player)
    tiles = [tile]
    while tile = tiles.pop()
      x = tile.data('x')
      y = tile.data('y')
      oldAtoms = (tile.data('atoms') || 0)
      oldOwner = tile.data('owner')

      # New owner
      tile.data('owner', player)

      # Set new amount of atoms
      atoms = (oldAtoms || 0) + 1

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
        tile[0].src = "/images/atoms_#{playerIndex}-#{atoms}.png"

      # Update the scores
      if oldOwner? and oldOwner isnt player
        oldOwnerPreviousScore = parseInt($("#playerList li##{oldOwner} .score").text())
        if oldOwnerPreviousScore > 0 && addToPlayerScore(oldOwner, -oldAtoms) == 0
          playerLost(oldOwner)
        addToPlayerScore(player, oldAtoms)

  addToPlayerScore = (player, atoms) ->
    scoreElement = $("#playerList li##{player} .score")
    score = parseInt(scoreElement.text()) + atoms
    scoreElement.text(score)
    score

  gameOver = ->
    $('#playerList li:not(.gameOver)').length == 1

  playerLost = (player) ->
    $("#playerList li##{player}").addClass('gameOver')

  playerAlive = (player) ->
    not $("#playerList li##{player}").hasClass('gameOver')

  activateGame = (game) ->
    game_data.currentPlayer = game.currentPlayer
    game_data.players = game.readyPlayers
    game_data.currentGame = game.id

    clearGameBoard()
    clearScoreBoard()
    drawScoreBoard(game.readyPlayers)
    drawGameBoard()

    SS.client.lobby.slideLobby($('#topmenu').outerHeight() + $('#game').outerHeight(true))
    $('#game').fadeIn()

  lookupTile = (x, y) ->
    $("#board ol:nth-child(#{y}) li:nth-child(#{x}) img")

  clearScoreBoard = ->
    $('#playerList').children().remove()
  
  clearGameBoard = ->
    $('#board').children().remove()

  drawScoreBoard = (players) ->
    console.log("Drawing scoreboard ", players)
    $.each players, (index, player) ->
      $('<li>').attr('id', player).append($('<a>').text(player).add($('<span>').addClass('score').text('0'))).appendTo('#playerList')

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
