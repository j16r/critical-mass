TILES_ACROSS = 10
TILES_DOWN = 6
ATOM_COUNT_TO_CLASS_NAMES = ['zero', 'one', 'two', 'three', 'four']

client = require('/client')

window.gameData =
  currentGame: null

# ss Event handlers ##########################################################

ss.event.on 'gameOffer', (game) ->
  console.log "Received a game offer: ", game
  acceptLink = $('<a>').text('Click here to accept.').click ->
    ss.rpc 'system.acceptGame', game.id, client.currentUser(), (success) ->

  client.announce($('<span>').text("#{game.host} has offered to play a game with you. ").append(acceptLink), 'gameOffer')

ss.event.on 'acceptOffer', (player) ->
  client.announce("#{player} has accepted the game", 'acceptOffer')

ss.event.on 'gameBegins', (game, channelName) ->
  client.announce('All players have accepted the game', 'gameBegins')
  activateGame(game)

ss.event.on 'playMove', (move, channelName) ->
  player = move.player
  tile = lookupTile(move.x, move.y)

  owner = tile.data('owner')
  return unless owner is player or not owner?

  drawActivePlayer(player)
  addToPlayerScore(player, 1)
  fuseAtoms(player, tile)
  nextTurn(move.newPlayer) unless gameOver()

# DOM Event handlers #########################################################

$('#board li').live 'click', ->
  console.log("Click...")
  #return if currentPlayerName(gameData.currentPlayer) isnt client.currentUser()
  return if gameData.currentPlayer isnt client.currentUser()

  console.log("...", this)
  x = $(this).data('x')
  y = $(this).data('y')
  ss.rpc 'system.playMove', gameData.currentGame, x, y, (success) ->

# Functions #################################################################

nextTurn = (playerName) ->
  gameData.currentPlayer = playerName

playerIndex = (playerName) ->
  gameData.players.indexOf(playerName) + 1

currentPlayerName = (playerName) ->
  $("#playerList li:nth-child(#{playerIndex playerName})").attr('id')
  
drawActivePlayer = (playerName) ->
  $('#playerList li').removeClass('active')
  $("#playerList li:nth-child(#{playerIndex(playerName)})").addClass('active')

fuseAtoms = (player, tile) ->
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
  gameData.currentPlayer = game.currentPlayer
  gameData.players = game.readyPlayers
  gameData.currentGame = game.id

  clearGameBoard()
  clearScoreBoard()
  drawScoreBoard(game.readyPlayers)
  drawGameBoard()

  client.slideLobby($('#topmenu').outerHeight() + $('#game').outerHeight(true))
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
