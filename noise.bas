' Optimized Noise Functions
'------------------------------

Sub RePERM (SEED As _Unsigned Integer)
    Randomize SEED
    ReDim perm(0 To 65536 * 7 - 1) As Single
    For I = 0 To 65536 * 7 - 1
        perm(I) = Rnd
    Next I
End Sub
' Optimized hash function remains similar. If possible, consider caching
' repeated calls if the same (X, M) are used frequently.
Function hash! (X As _Unsigned Integer, M As _Unsigned _Byte)
    hash! = perm(M * 65536 + X)
End Function

' Optimized fade function – compute powers manually.
Function fade! (t As Double) Static
    ' Compute t^2, t^3, t^4, and t^5 with multiplications
    Dim As Double t2, t3, t4, t5
    t2 = t * t
    t3 = t2 * t
    t4 = t3 * t
    t5 = t4 * t
    ' Fade curve: 6t^5 - 15t^4 + 10t^3
    fade! = 6 * t5 - 15 * t4 + 10 * t3
End Function

' Optimized linear interpolation – remains straightforward.
Function interpolate! (A!, B!, C!) Static
    interpolate! = A! + (B! - A!) * C!
End Function

' Optimized noise1 function.
Function noise1! (X As Double, M As _Unsigned _Byte) Static
    Dim As Long fX
    Dim As Single dX, n0, n1
    fX = Int(X)
    dX = fade!(X - fX)
    n0 = hash!(fX, M)
    n1 = hash!(fX + 1, M)
    noise1! = interpolate!(n0, n1, dX)
End Function

' Optimized 2D noise function.
Function noise2! (X As Double, Y As Double, M As _Unsigned _Byte) Static
    Dim As Long fX, fY
    Dim As Single dX, dY
    Dim As Single n00, n10, n01, n11
    fX = Int(X)
    fY = Int(Y)
    dX = fade!(X - fX)
    dY = fade!(Y - fY)

    ' Pre-calculate indices with the constant 57 factor.
    Dim baseXY As Long
    baseXY = fX + fY * 57
    n00 = hash!(baseXY, M)
    n10 = hash!(baseXY + 1, M)
    n01 = hash!(baseXY + 57, M)
    n11 = hash!(baseXY + 58, M)

    Dim i1 As Single, i2 As Single
    i1 = interpolate!(n00, n10, dX)
    i2 = interpolate!(n01, n11, dX)
    noise2! = interpolate!(i1, i2, dY)
End Function

' Optimized 3D noise function.
Function noise3! (X As Double, Y As Double, Z As Double, M As _Unsigned _Byte) Static
    Dim As Long fX, fY, fZ
    Dim As Single dX, dY, dZ
    fX = Int(X)
    fY = Int(Y)
    fZ = Int(Z)
    dX = fade!(X - fX)
    dY = fade!(Y - fY)
    dZ = fade!(Z - fZ)

    ' For 3D, combine indices carefully. Using 57 as a constant offset.
    Dim A0 As Long, A1 As Long, B0 As Long, B1 As Long
    A0 = fX + (fY + fZ * 57) * 57
    A1 = A0 + 1
    B0 = fX + ((fY + 57) + fZ * 57) * 57
    B1 = B0 + 1

    Dim C0 As Single, C1 As Single, C2 As Single, C3 As Single
    C0 = interpolate!(hash!(A0, M), hash!(A1, M), dX)
    C1 = interpolate!(hash!(A0 + 57, M), hash!(A1 + 57, M), dX)
    C2 = interpolate!(hash!(B0, M), hash!(B1, M), dX)
    C3 = interpolate!(hash!(B0 + 57, M), hash!(B1 + 57, M), dX)

    Dim i1 As Single, i2 As Single
    i1 = interpolate!(C0, C1, dY)
    i2 = interpolate!(C2, C3, dY)
    noise3! = interpolate!(i1, i2, dZ)
End Function

' Optimized fractal noise functions.
' These accumulate noise from several octaves and use a loop to adjust scale and amplitude.
Function fractal1! (X As Long, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double amplitude, total, maxAmplitude, scale
    Dim As Integer i
    amplitude = 1: total = 0: maxAmplitude = 0: scale = S
    For i = 0 To O
        total = total + amplitude * noise1!(X / scale, M)
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude / 2
        scale = scale / 2
    Next i
    fractal1! = total / maxAmplitude
End Function

Function fractal2! (X As Long, Y As Long, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double amplitude, total, maxAmplitude, scale
    Dim As Integer i
    amplitude = 1: total = 0: maxAmplitude = 0: scale = S
    For i = 0 To O
        total = total + amplitude * noise2!(X / scale, Y / scale, M)
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude / 2
        scale = scale / 2
    Next i
    fractal2! = total / maxAmplitude
End Function

Function fractal3! (X As Long, Y As Long, Z As Long, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double amplitude, total, maxAmplitude, scale
    Dim As Integer i
    amplitude = 1: total = 0: maxAmplitude = 0: scale = S
    For i = 0 To O
        total = total + amplitude * noise3!(X / scale, Y / scale, Z / scale, M)
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude / 2
        scale = scale / 2
    Next i
    fractal3! = total / maxAmplitude
End Function
