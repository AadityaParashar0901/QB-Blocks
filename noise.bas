Sub RePERM (SEED As _Unsigned Integer)
    Randomize SEED
    ReDim perm2(0 To 255, 0 To 255, 0 To 7) As Single
    For I = 0 To 255
        For J = 0 To 255
            For K = 0 To 7
                perm2(I, J, K) = Rnd
    Next K, J, I
    Randomize SEED
    ReDim perm3(0 To 15, 0 To 15, 0 To 15, 0 To 7) As Single
    For I = 0 To 15: For J = 0 To 15: For K = 0 To 15: For L = 0 To 7
                    perm3(I, J, K, L) = Rnd
    Next L, K, J, I
End Sub
Function interpolate! (A!, B!, C!)
    interpolate! = A! + (B! - A!) * C!
End Function
Function fractal2! (X As Long, Y As Long, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double amplitude, total, maxAmplitude, scale
    Dim As Single tX, tY
    Dim As _Byte i
    amplitude = 1: total = 0: maxAmplitude = 0: scale = S
    For i = 0 To O
        tX = X / scale
        tY = Y / scale
        fX& = Int(tX)
        fY& = Int(tY)
        dX! = tX - fX&
        dY! = tY - fY&
        dX! = ((6 * dX! - 15) * dX! + 10) * dX! * dX! * dX!
        dY! = ((6 * dY! - 15) * dY! + 10) * dY! * dY! * dY!
        fX~%% = fX& And 255
        fY~%% = fY& And 255
        fX1~%% = fX~%% + 1
        fY1~%% = fY~%% + 1
        n00! = perm2(fX~%%, fY~%%, M)
        n10! = perm2(fX1~%%, fY~%%, M)
        n01! = perm2(fX~%%, fY1~%%, M)
        n11! = perm2(fX1~%%, fY1~%%, M)
        i1! = n00! + (n10! - n00!) * dX!
        i2! = n01! + (n11! - n01!) * dX!
        n! = i1! + (i2! - i1!) * dY!
        total = total + amplitude * n!
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude / 2
        scale = scale / 2
    Next i
    fractal2! = total / maxAmplitude
End Function
Function fractal3! (X As Long, Y As Long, Z As Long, S As _Unsigned Long, O As _Unsigned _Byte, M As _Unsigned _Byte) Static
    Dim As Double amplitude, total, maxAmplitude, scale
    Dim As Single tX, tY, tZ
    Dim As _Byte i
    amplitude = 1: total = 0: maxAmplitude = 0: scale = S
    For i = 0 To O
        tX = X / scale
        tY = Y / scale
        tZ = Z / scale
        fX& = Int(tX)
        fY& = Int(tY)
        fZ& = Int(tZ)
        dX! = tX - fX&
        dY! = tY - fY&
        dZ! = tZ - fZ&
        dX! = ((6 * dX! - 15) * dX! + 10) * dX! * dX! * dX!
        dY! = ((6 * dY! - 15) * dY! + 10) * dY! * dY! * dY!
        dZ! = ((6 * dZ! - 15) * dZ! + 10) * dZ! * dZ! * dZ!
        fX~`4 = fX& And 255
        fY~`4 = fY& And 255
        fZ~`4 = fZ& And 255
        fX1~`4 = fX~`4 + 1
        fY1~`4 = fY~`4 + 1
        fZ1~`4 = fZ~`4 + 1
        n000! = perm3(fX~`4, fY~`4, fZ~`4, M)
        n100! = perm3(fX1~`4, fY~`4, fZ~`4, M)
        n010! = perm3(fX~`4, fY1~`4, fZ~`4, M)
        n110! = perm3(fX1~`4, fY1~`4, fZ~`4, M)
        n001! = perm3(fX~`4, fY~`4, fZ1~`4, M)
        n101! = perm3(fX1~`4, fY~`4, fZ1~`4, M)
        n011! = perm3(fX~`4, fY1~`4, fZ1~`4, M)
        n111! = perm3(fX1~`4, fY1~`4, fZ1~`4, M)
        i01! = n000! + (n100! - n000!) * dX!
        i02! = n010! + (n110! - n010!) * dX!
        i11! = n001! + (n101! - n001!) * dX!
        i12! = n011! + (n111! - n011!) * dX!
        n1! = i01! + (i02! - i01!) * dY!
        n2! = i11! + (i12! - i11!) * dY!
        total = total + amplitude * (n1! + (n2! - n1!) * dZ!)
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude / 2
        scale = scale / 2
    Next i
    fractal3! = total / maxAmplitude
End Function
