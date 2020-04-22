var
    goToWorkspace*: proc (i : int)
    reloadConfig*: proc()


proc invokeGoToWorkspace*(i : int)=
    if(goToWorkspace != nil): goToWorkspace(i)

proc invokeReloadConfig*()=
    if(reloadConfig != nil): reloadConfig()

