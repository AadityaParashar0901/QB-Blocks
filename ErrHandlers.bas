ErrHandler:
Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][Error" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
Resume Next
GLErrHandler:
Write_Log "[" + _Trim$(Str$(GFPSCount)) + "][GL Error" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
Resume Next
