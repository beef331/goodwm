var
    goToWorkspace*: proc (i : int)


proc invokeGoToWorkspace*(i : int)=
    if(goToWorkspace != nil): goToWorkspace(i)

