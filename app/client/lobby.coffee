MAX_PLAYERS = 4

# The game lobby, where people go to find others to play games with
exports.init = ->

  SS.server.app.restoreSession (response) ->
    if response.success is true
      initLogin(response.username, response.usersOnline)
    else
      revealLogin()

  # SS Event handlers ##########################################################

  # A user has signed on
  SS.events.on 'userSignon', (username) ->
    return if $("#userList li##{username}").length > 0

    $('<li>').attr('id', username).text(username).hide().appendTo('#userList').slideDown()

    return unless username is SS.client.lobby.currentUser()
    SS.client.lobby.announce("#{username} signed on", 'signOn')

  # A user has signed off
  SS.events.on 'userSignoff', (username) ->
    return unless userLabel = $("#userList li##{username}")

    userLabel.remove()
    SS.client.lobby.announce("#{username} signed off", 'signOff')

  SS.events.on 'userTimeout', (username) ->
    return unless userLabel = $("#userList li##{username}")

    userLabel.remove()
    SS.client.lobby.announce("#{username} timed out", 'signOff')

  # a new chat message was sent
  SS.events.on 'newMessage', (message) ->
    SS.client.lobby.message($('<tr>').append($('<th>').text(message.user)).append($('<td>').text(message.text)))
    $("table tr:last-child").addClass("own") if message.user is SS.client.lobby.currentUser()
    $('#channel').animate({scrollTop: $('#chatLog').height()}, 0)

  # Player entered a game
  SS.events.on 'playerBusy', (message) ->
    $.each message.users, (user) ->
      $('<li>').attr('id', user).addClass('busy')

  SS.events.on 'signedOn', (response) ->

  # DOM Event handlers #########################################################

  $('#chatroom').submit ->
    return unless (message = $('#message').val()).length > 0

    SS.server.app.sendMessage message, (success) ->
      if success
        $('#message').val('')
      else
        alert('Unable to send message')

  $('#login').submit ->
    username = $('#username').val()
    return unless username.length > 0

    SS.server.app.login username, (response) ->
      $('#errors').children().remove()
      $('#userList').children().remove()

      if response.success
        initLogin(username, response.usersOnline)
      else
        $('#errors').append('<ul>').append('<li>').text(response.message)

  $('#userList li').live 'click',  ->
    return if $(this).text() is SS.client.lobby.currentUser()

    if selectedUsers().length < (MAX_PLAYERS - 1)
      $(this).toggleClass('selected')

    if selectedUsers().length > 0
      $('#startGame').addClass('active')
    else
      $('#startGame').removeClass('active')

  $('#startGame.active').live 'click', ->
    players = selectedUsers()
    SS.server.app.offerGame players, (success) ->
      $('#startGame').removeClass('active')
      $('#userList li').removeClass('selected')
      SS.client.lobby.announce("You have offered to host a game for #{players.join(', ')}", 'gameOffer')

  $('#logout').click ->
    clearInterval window.heartbeat
    revealLogin()
    SS.server.app.logout (success) ->

  $(window).resize ->
    SS.client.lobby.resizeLobby($('#lobby').position().top)

  # Private functions ##########################################################
  
  initLogin = (username, usersOnline) ->
    $('#username').val('')
    $('#currentUser').text(username)
    for user in usersOnline
      $('<li>').attr('id', user).text(user).appendTo('#userList')
    startHeartbeat()
    revealMainScreen()

  revealLogin = ->
    $('#lobby').animate {top: '100%'}, ->
      $('#main').hide()
      $('#authentication').fadeIn()

  revealMainScreen = ->
    $('#authentication').fadeOut ->
      $('#main').show()
      SS.client.lobby.slideLobby($('#topmenu').height() + 1)

  selectedUsers = ->
    $(li).text() for li in $('#userList li.selected')

  startHeartbeat = ->
    window.heartbeat = setInterval (-> SS.server.app.heartbeat()), 15000

# Exported functions ##########################################################

exports.currentUser = ->
  $('#currentUser').text()

exports.announce = (message, type) ->
  SS.client.lobby.message $('<tr>').append(
    $('<td>')
      .attr('colspan', 2)
      .addClass('announce')
      .addClass(type)
      .html(message))

exports.message = (row) ->
  row.hide().appendTo('#chatLog').slideDown()

exports.slideLobby = (top) ->
  SS.client.lobby.resizeLobby(top)
  $('#lobby')
    .height(window.innerHeight)
    .animate({top: top})

exports.resizeLobby = (top) ->
  newLobbyHeight = window.innerHeight - (top + $('#lobby h1').outerHeight() + $('#text').outerHeight())
  $('#channel')
    .height(newLobbyHeight)
  newUserlistHeight = newLobbyHeight - ($('#users h4').outerHeight() + $('#menu').outerHeight())
  $('#userList')
    .height(newUserlistHeight)
