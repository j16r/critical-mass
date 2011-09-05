window.lobby_data =
  userList: {}
  currentUser: null

# The game lobby, where people go to find others to play games with
exports.init = ->

  # Periodically publish the list of users online
  SS.events.on 'usersOnline', (users) ->
    $.each users, (index, user) ->
      if not lobby_data.userList[user]
        lobby_data.userList[user] = true
        $("<li>#{user}</li>").hide().appendTo('#userlist').slideDown()
        $("<tr><td colspan='2' class='announce signon'>#{user} signed on</td></tr>").hide().appendTo('#chatlog').slideDown()

  # Listen for new messages and append them to the screen
  SS.events.on 'newMessage', (message) ->
    $("<tr><th>#{message['user']}</th><td>#{message['text']}</td></tr>").hide().appendTo('#chatlog').slideDown()
    $('#channel').animate({scrollTop: $('#chatlog').height()}, 0)

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
          lobby_data.currentUser = username

  $('#userlist li').live 'click',  ->
    if $(this).text() isnt lobby_data.currentUser

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
    SS.server.app.offerGame lobby_data.currentUser, selectedUsers(), (success) ->
      console.log('Game offered')

  $('#accept').live 'click', ->
    SS.server.app.acceptGame lobby_data.currentUser, (success) ->
      console.log('Game accepted')

  $('#logout').click ->
    SS.server.app.logout (success) ->
      if success
        $('#main').hide()
        $('#logout').hide()
        $('#authentication').fadeIn()

  revealMainScreen = ->
    $('#authentication').fadeOut()
    $('#main').show()

  selectedUsers = ->
    $.map $('#userlist li.selected'), (li, index) ->
      $(li).text()
