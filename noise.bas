Sub RePERM (SEED As _Unsigned Integer)
    Randomize SEED
    ReDim perm(0 To 65536 * 7 - 1) As Single
    For I = 0 To 65536 * 7 - 1
        perm(I) = Rnd
    Next I
End Sub
Function hash! (X As _Unsigned Integer, M As _Unsigned _Byte)
    hash! = perm(M * 65536 + X)
End Function
Function fade! (t As Double) Static
    fade! = ((6 * t - 15) * t + 10) * t ^ 3
End Function
Function interpolate! (A!, B!, C!) Static
    interpolate! = A! + (B! - A!) * C!
End Function
Function noise1! (X As Double, M As _Unsigned _Byte) Static
    fX% = Int(X): dX! = fade!(X - fX%)
    noise1! = interpolate!(hash(fX%, M), hash(fX% + 1, M), dX!)
End Function
Function noise2! (X As Double, Y As Double, M As _Unsigned _Byte) Static
    fX% = Int(X): dX! = fade!(X - fX%)
    fY% = Int(Y): dY! = fade!(Y - fY%)
    noise2! = interpolate!(interpolate!(hash(fX% + fY% * 57, M), hash(fX% + fY% * 57 + 1, M), dX!), interpolate!(hash(fX% + fY% * 57 + 57, M), hash(fX% + fY% * 57 + 58, M), dX!), dY!)
End Function
Function noise3! (X As Double, Y As Double, Z As Double, M As _Unsigned _Byte) Static
    fX% = Int(X): dX! = fade!(X - fX%)
    fY% = Int(Y): dY! = fade!(Y - fY%)
    fZ% = Int(Z): dZ! = fade!(Z - fZ%)
    noise3! = interpolate!(interpolate!(interpolate!(hash(fX% + (fY% + fZ% * 57) * 57, M), hash(fX% + (fY% + fZ% * 57) * 57 + 1, M), dX!), interpolate!(hash(fX% + (fY% + fZ% * 57) * 57 + 57, M), hash(fX% + (fY% + fZ% * 57) * 57 + 58, M), dX!), dY!), interpolate!(interpolate!(hash(fX% + (fY% + fZ% * 57 + 57) * 57, M), hash(fX% + (fY% + fZ% * 57 + 57) * 57 + 1, M), dX!), interpolate!(hash(fX% + (fY% + fZ% * 57 + 57) * 57 + 57, M), hash(fX% + (fY% + fZ% * 57 + 57) * 57 + 58, M), dX!), dY!), dZ!)
End Function
Function fractal1! (X As Integer, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double a, t, d, I
    a = 1: t = 0: d = 0
    For I = 0 To O
        t = t + a * noise1!(X / a / S, M): d = d + a: a = a / 2
    Next I
    fractal1! = t / d
End Function
Function fractal2! (X As Integer, Y As Integer, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double a, t, d, I
    a = 1: t = 0: d = 0
    For I = 0 To O
        t = t + a * noise2!(X / a / S, Y / a / S, M): d = d + a: a = a / 2
    Next I
    fractal2! = t / d
End Function
Function fractal3! (X As Integer, Y As Integer, Z As Integer, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double a, t, d, I
    a = 1: t = 0: d = 0
    For I = 0 To O
        t = t + a * noise3!(X / a / S, Y / a / S, Z / a / S, M): d = d + a: a = a / 2
    Next I
    fractal3! = t / d
End Function
