import notify
proc sendConfigError*(msg: string) =
  var n = newNotification("GoodWm Config Error: ", msg, "")
  discard n.show
