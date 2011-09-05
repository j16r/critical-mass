MAX_PLAYERS = 4

window.lobby_data =
  currentUser: null

# The game lobby, where people go to find others to play games with
exports.init = ->

  SS.server.app.init (username) ->
    if username
      revealMainScreen()
      lobby_data.currentUser = username
    else
      revealLogin()

  # SS Event handlers ##########################################################

  # A user has signed on
  SS.events.on 'userSignon', (username) ->
    return if $("#userList li##{username}").length > 0

    $("<li id='#{username}'>#{username}</li>").hide().appendTo('#userList').slideDown()
    $("<tr><td colspan='2' class='announce signon'>#{username} signed on</td></tr>").hide().appendTo('#chatLog').slideDown()

  # A user has signed off
  SS.events.on 'userSignoff', (username) ->
    console.log(username)
    userLabel = $("#userList li##{username}")
    return unless userLabel

    userLabel.remove()
    $("<tr><td colspan='2' class='announce signoff'>#{username} signed off</td></tr>").hide().appendTo('#chatLog').slideDown()

  # a new chat message was sent
  SS.events.on 'newMessage', (message) ->
    $("<tr><th>#{message['user']}</th><td>#{message['text']}</td></tr>").hide().appendTo('#chatLog').slideDown()
    $('#channel').animate({scrollTop: $('#chatLog').height()}, 0)

  # DOM Event handlers #########################################################

  $('#chatroom').show().submit ->
    message = $('#message').val()
    return unless message.length > 0

    SS.server.app.sendMessage message, (success) ->
      if success
        $('#message').val('')
      else
        alert('Unable to send message')

  $('#login').show().submit ->
    username = $('#username').val()
    return unless username.length > 0

    SS.server.app.login username, (response) ->
      $('#errors').children().remove()
      $('#userList').children().remove()

      if response.success
        console.log("Users online: ", response.usersOnline)
        lobby_data.currentUser = username
        $('#username').val('')
        revealMainScreen()
        console.log("Users online: ", response.usersOnline)
        $.each response.usersOnline, (index, user) ->
          $("<li id='#{user}'>#{user}</li>").hide().appendTo('#userList').slideDown()
      else
        $('#errors').append("<ul><li>#{response.message}</li></ul>")

  $('#userList li').live 'click',  ->
    return if $(this).text() is lobby_data.currentUser

    if selectedUsers().length < (MAX_PLAYERS - 1)
      $(this).toggleClass('selected')

    if selectedUsers().length > 0
      $('#startGame').addClass('active')
    else
      $('#startGame').removeClass('active')

  $('#startGame.active').live 'click', ->
    SS.server.app.offerGame lobby_data.currentUser, selectedUsers(), (success) ->

  $('#accept').live 'click', ->
    SS.server.app.acceptGame lobby_data.currentUser, (success) ->

  $('#logout').click ->
    SS.server.app.logout (success) ->
      if success then revealLogin()

  # Functions #################################################################

  revealLogin = ->
    $('#main').hide()
    $('#authentication').fadeIn()

  revealMainScreen = ->
    $('#authentication').hide()
    $('#main').fadeIn()

  selectedUsers = ->
    $.map $('#userList li.selected'), (li, index) ->
      $(li).text()
