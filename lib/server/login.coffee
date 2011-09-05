exports.authenticate = (params, cb) ->
  cb({success: true, user_id: 21323, info: {username: 'joebloggs'}})
