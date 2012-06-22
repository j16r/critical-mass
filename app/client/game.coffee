TILES_ACROSS = 10
TILES_DOWN = 6
ATOM_COUNT_TO_CLASS_NAMES = ['zero', 'one', 'two', 'three', 'four']

window.game_data =
  currentGame: null

exports.init = ->

  # SS Event handlers ##########################################################

  SS.events.on 'gameOffer', (game) ->
    console.log "Received a game offer: ", game
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
  
  playerIndex = (playerName) ->
    game_data.players.indexOf(playerName) + 1
  
  currentPlayerName = (playerName) ->
    $("#playerList li:nth-child(#{playerIndex playerName})").attr('id')

  $('#board li').live 'click', ->
    console.log("Click...")
    #return if currentPlayerName(game_data.currentPlayer) isnt SS.client.lobby.currentUser()
    return if game_data.currentPlayer isnt SS.client.lobby.currentUser()

    console.log("...", this)
    x = $(this).data('x')
    y = $(this).data('y')
    SS.server.app.playMove game_data.currentGame, x, y, (success) ->

  # Functions #################################################################

  #playerIndex = (player) ->
    #foundIndex = null
    #for element, index in $('#playerList li')
      #foundIndex = index if $(element).attr('id') is player
    #foundIndex

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
        tile.data('atoms', null).data('owner', null)

        # Place atoms in adjacent tiles unless the game is over
        unless gameOver()
          tiles.push(lookupTile(x - 1, y)) if x > 1
          tiles.push(lookupTile(x + 1, y)) if x < TILES_ACROSS
          tiles.push(lookupTile(x, y - 1)) if y > 1
          tiles.push(lookupTile(x, y + 1)) if y < TILES_DOWN

      else
        tile.data('atoms', atoms).addClass(ATOM_COUNT_TO_CLASS_NAMES[atoms])

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
    $("#board ol:nth-child(#{y}) li:nth-child(#{x})")

  clearScoreBoard = ->
    $('#playerList').empty()
  
  clearGameBoard = ->
    $('#board').empty()

  drawScoreBoard = (players) ->
    console.log("Drawing scoreboard ", players)
    for player in players
      $('<li>').attr('id', player).append($('<a>').text(player).add($('<span>').addClass('score').text('0'))).appendTo('#playerList')

  drawGameBoard = ->
    board = $('#board')
    for y in [1..TILES_DOWN]
      row = $('<ol>').appendTo(board)
      for x in [1..TILES_ACROSS]
        $('<li>').data('x', x).data('y', y)
          .append('<div><img src="/images/blank.gif">')
          .appendTo(row)

    $('ol:first-child li:first-child, ol:first-child li:last-child, ol:last-child li:first-child, ol:last-child li:last-child', board)
        .addClass('corner')

    $('ol:first-child li, ol:last-child li, ol li:first-child, ol li:last-child', board)
        .addClass('edge')
