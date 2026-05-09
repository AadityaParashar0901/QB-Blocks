For id = LBound(Workers) To UBound(Workers)
    Workers(id).Quit = -1
    joinThread id
    Write_Log "Terminated Thread " + _ToStr$(id)
Next id
