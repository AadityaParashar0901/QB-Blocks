ErrHandler:
F$ = _InclErrorFile$
If Len(F$) Then
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][Error" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "->" + F$ + Str$(_InclErrorLine) + "]"
Else
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][Error" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
End If
Resume Next
GLErrHandler:
F$ = _InclErrorFile$
If Len(F$) Then
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][GLError" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "->" + F$ + Str$(_InclErrorLine) + "]"
Else
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][GLError" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
End If
Resume Next
