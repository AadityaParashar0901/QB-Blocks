Function Button (T~%%, X As Integer, Y As Integer, S$)
    Select Case T~%%
        Case 1:
            If InRange(X - 200, _MouseX, X + 199) And InRange(Y - 20, _MouseY, Y + 19) Then
                _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(4)
                Button = _MouseButton(1)
                While _MouseButton(1) Or _MouseInput: Wend
            Else
                _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(3)
            End If
            PrintString X - Len(S$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, S$
        Case 9:
            _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(5)
            PrintString X - Len(S$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, S$
        Case 2:
            If InRange(X - 11, _MouseX, X + 11) And InRange(Y - 6, _MouseY, Y + 6) Then
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(15)
                Button = _MouseButton(1)
                While _MouseButton(1) Or _MouseInput: Wend
            Else
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(14)
            End If
        Case 3:
            If InRange(X - 11, _MouseX, X + 11) And InRange(Y - 6, _MouseY, Y + 6) Then
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(17)
                Button = _MouseButton(1)
                While _MouseButton(1) Or _MouseInput: Wend
            Else
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(16)
            End If
    End Select
End Function
Sub InputBox (X As Integer, Y As Integer, S$, H$, isInFocus As _Unsigned Integer, KeyHit As _Unsigned _Byte)
    _PutImage (X - 200, Y - 10)-(X + 199, Y + 9), GUI_ASSETS&(11)
    If isInFocus And 2 * Timer(0.1) - Int(2 * Timer) > 0.5 Then C$ = "_"
    T$ = Right$(S$, 400 \ FONTWIDTH)
    PrintString X - 200, Y - FONTHEIGHT / 2, T$ + C$
    If Len(T$) = 0 Then PrintString X - Len(H$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, H$
    If isInFocus = 0 Then Exit Sub
    Select Case KeyHit
        Case 8: S$ = Left$(S$, Len(S$) - 1)
        Case 32 To 126: S$ = S$ + Chr$(KeyHit)
    End Select
End Sub
Sub CheckBox (X As Integer, Y As Integer, S$, C As _Unsigned _Byte)
    If C Then
        _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(19)
        If InRange(X - 10, _MouseX, X + 9) And InRange(Y - 10, _MouseY, Y + 9) Then
            _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(21)
            While _MouseButton(1) Or _MouseInput: C = 0: Wend
        End If
    Else
        _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(18)
        If InRange(X - 10, _MouseX, X + 9) And InRange(Y - 10, _MouseY, Y + 9) Then
            _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(20)
            While _MouseButton(1) Or _MouseInput: C = -1: Wend
        End If
    End If
    PrintString X + 18, Y - FONTHEIGHT / 2, S$
End Sub
Sub Slider (B As _Unsigned _Byte, X As Integer, Y As Integer, S$, A!, C!)
    T! = (B - A!) / (C! - A!) * 384 - 192
    If InRange(X - 200, _MouseX, X + 199) And InRange(Y - 20, _MouseY, Y + 19) Then
        _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(11)
        _PutImage (X + T - 8, Y - 20)-(X + T + 7, Y + 19), GUI_ASSETS&(13)
        If _MouseButton(1) Then
            B = A! + (_MouseX - X + 192) * (C! - A!) / 384
        End If
    Else
        _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(10)
        _PutImage (X + T - 8, Y - 20)-(X + T + 7, Y + 19), GUI_ASSETS&(12)
    End If
    T$ = S$ + ": " + _Trim$(Str$(B))
    PrintString X - Len(T$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, T$
End Sub
