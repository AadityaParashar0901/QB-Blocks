ErrHandler:
F$ = _InclErrorFile$
LastError = Err
If Len(F$) Then
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][Error" + Str$(LastError) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "->" + F$ + Str$(_InclErrorLine) + "]"
Else
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][Error" + Str$(LastError) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
End If
Resume Next
GLErrHandler:
F$ = _InclErrorFile$
LastError = Err
If Len(F$) Then
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][GLError" + Str$(LastError) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "->" + F$ + Str$(_InclErrorLine) + "]"
Else
    Write_Log "[" + _Trim$(Str$(LFPSCount)) + "][GLError" + Str$(LastError) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
End If
Resume Next
