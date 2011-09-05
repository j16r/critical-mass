exports.authenticate = (username, cb) ->
  # FIXME: Race condition here, need atomic test and set
  R.get "user:#{username}", (error, data) =>
    if data
      cb({success: false, message: "That nickname is already taken"})
    else
      R.set "user:#{username}", username
      cb({success: true})
