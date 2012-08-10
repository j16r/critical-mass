# Exported functions ##########################################################

exports.currentUser = ->
  $('#currentUser').text()

exports.message = (row) ->
  row.hide().appendTo('#chatLog').slideDown()

exports.announce = (message, type) ->
  exports.message $('<tr>').append(
    $('<td>')
      .attr('colspan', 2)
      .addClass('announce')
      .addClass(type)
      .html(message))

exports.resizeLobby = (top) ->
  newLobbyHeight = window.innerHeight - (top + $('#lobby h1').outerHeight() + $('#text').outerHeight())
  $('#channel')
    .height(newLobbyHeight)
  newUserlistHeight = newLobbyHeight - ($('#users h4').outerHeight() + $('#menu').outerHeight())
  $('#userList')
    .height(newUserlistHeight)

exports.slideLobby = (top) ->
  exports.resizeLobby(top)
  $('#lobby')
    .height(window.innerHeight)
    .animate({top: top})
