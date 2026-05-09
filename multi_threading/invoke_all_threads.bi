For id = LBound(Workers) To UBound(Workers)
    Workers(id).id = id
    If invokeWorker(id) Then Write_Log "Started Thread: " + _ToStr$(id) Else Write_Log "Cannot Start Thread: " + _ToStr$(id)
Next id
