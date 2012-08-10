MAX_PLAYERS = 4

client = require('/client')

# The game lobby, where people go to find others to play games with

ss.rpc 'system.restoreSession', (response) ->
  if response.success is true
    initLogin(response.username, response.usersOnline)
  else
    revealLogin()

# ss Event handlers ##########################################################

# A user has signed on
ss.event.on 'userSignon', (username) ->
  return if $("#userList li##{username}").length > 0

  $('<li>').attr('id', username).text(username).hide().appendTo('#userList').slideDown()

  return unless username is client.currentUser()
  client.announce("#{username} signed on", 'signOn')

# A user has signed off
ss.event.on 'userSignoff', (username) ->
  return unless userLabel = $("#userList li##{username}")

  userLabel.remove()
  client.announce("#{username} signed off", 'signOff')

ss.event.on 'userTimeout', (username) ->
  return unless userLabel = $("#userList li##{username}")

  userLabel.remove()
  client.announce("#{username} timed out", 'signOff')

# a new chat message was sent
ss.event.on 'newMessage', (message) ->
  client.message($('<tr>').append($('<th>').text(message.user)).append($('<td>').text(message.text)))
  $("table tr:last-child").addClass("own") if message.user is client.currentUser()
  $('#channel').animate({scrollTop: $('#chatLog').height()}, 0)

# Player entered a game
ss.event.on 'playerBusy', (message) ->
  $.each message.users, (user) ->
    $('<li>').attr('id', user).addClass('busy')

ss.event.on 'signedOn', (response) ->

# DOM Event handlers #########################################################

$('#chatroom').submit ->
  return unless (message = $('#message').val()).length > 0

  ss.rpc 'system.sendMessage', message, (success) ->
    if success
      $('#message').val('')
    else
      alert('Unable to send message')

$('#login').submit ->
  username = $('#username').val()
  return unless username.length > 0

  ss.rpc 'system.login', username, (response) ->
    console.log("response ", response)
    $('#errors').children().remove()
    $('#userList').children().remove()

    if response.success
      initLogin(username, response.usersOnline)
    else
      $('#errors').append('<ul>').append('<li>').text(response.message)

$('#userList li').live 'click',  ->
  return if $(this).text() is client.currentUser()

  if selectedUsers().length < (MAX_PLAYERS - 1)
    $(this).toggleClass('selected')

  if selectedUsers().length > 0
    $('#startGame').addClass('active')
  else
    $('#startGame').removeClass('active')

$('#startGame.active').live 'click', ->
  players = selectedUsers()
  ss.rpc 'system.offerGame', players, (success) ->
    $('#startGame').removeClass('active')
    $('#userList li').removeClass('selected')
    client.announce("You have offered to host a game for #{players.join(', ')}", 'gameOffer')

$('#logout').click ->
  clearInterval window.heartbeat
  revealLogin()
  ss.rpc 'system.logout', (success) ->

$(window).resize ->
  client.resizeLobby($('#lobby').position().top)

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
    client.slideLobby($('#topmenu').height() + 1)

selectedUsers = ->
  $(li).text() for li in $('#userList li.selected')

startHeartbeat = ->
  window.heartbeat = setInterval (-> ss.rpc 'system.heartbeat'), 15000
