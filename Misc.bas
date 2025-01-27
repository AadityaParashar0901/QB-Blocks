Function TS$ (A)
    TS$ = _Trim$(Str$(A))
End Function
Function Dis2 (X1, Y1, X2, Y2)
    Dis2 = _Hypot(X1 - X2, Y1 - Y2) 'Got this _hypot() idea from bplus
End Function
Function Min (A, B)
    Min = -A * (A < B) - B * (A >= B)
End Function
Function Max (A, B)
    Max = -A * (A > B) - B * (A <= B)
End Function
Function InRange (A, B, C)
    InRange = (A <= B) And (B <= C)
End Function
Function Clamp (A, B, C)
    Clamp = B - (A - B) * (B < A) - (C - B) * (C < B)
End Function
Function ClampCycle (A, B, C)
    ClampCycle = B - (C - B) * (B < A) - (A - B) * (C < B)
End Function
Function IIF (A, B, C)
    IIF = -B * (A <> 0) - C * (A = 0)
End Function
Function MouseInBox (X1, Y1, X2, Y2)
    MouseInBox = InRange(X1, _MouseX, X2) And InRange(Y1, _MouseY, Y2)
End Function
