GameTick:
Time = Time + 1
If Time >= 28800 Then Time = 0
HOUR = Time \ 1200
MINUTEPER60 = ((Time \ 20) Mod 60) / 60
PSkyColor = GetSkyColour(HOUR)
NSkyColor = GetSkyColour(HOUR + 1)
SkyColor = _RGB32(interpolate(_Red32(PSkyColor), _Red32(NSkyColor), MINUTEPER60), interpolate(_Green32(PSkyColor), _Green32(NSkyColor), MINUTEPER60), interpolate(_Blue32(PSkyColor), _Blue32(NSkyColor), MINUTEPER60))
SkyColorRed = _Red32(SkyColor) / 255
SkyColorGreen = _Green32(SkyColor) / 255
SkyColorBlue = _Blue32(SkyColor) / 255
LINEDESIGNINTEGER = _SHR(LINEDESIGNINTEGER, 1) - (LINEDESIGNINTEGER = 1) * 32768
TMPMAXCHUNKLOADTIME = 0
For __I = 1 To UBound(ChunkLoadTimeHistory)
    TMPMAXCHUNKLOADTIME = Max(ChunkLoadTimeHistory(__I), TMPMAXCHUNKLOADTIME)
Next __I
MaxChunkLoadTime = TMPMAXCHUNKLOADTIME
Return
Function GetSkyColour& (T As _Unsigned Integer)
    Select Case T Mod 24
        Case 0: GetSkyColour = _RGB32(0, 0, 0)
        Case 1 To 4: GetSkyColour = _RGB32(0, 0, 51)
        Case 5: GetSkyColour = _RGB32(255, 153, 102)
        Case 6: GetSkyColour = _RGB32(255, 204, 153)
        Case 7, 8: GetSkyColour = _RGB32(102, 204, 255)
        Case 9 To 14: GetSkyColour = _RGB32(51, 153, 255)
        Case 15 To 17: GetSkyColour = _RGB32(255, 153, 102)
        Case 18: GetSkyColour = _RGB32(255, 102, 51)
        Case 19: GetSkyColour = _RGB32(102, 51, 153)
        Case 20 To 23: GetSkyColour = _RGB32(0, 0, 51)
    End Select
End Function
Function GameTime$
    Static oldGT$, oldTime As Long
    If oldTime <> Time \ 20 Then
        T& = Time \ 20
        H$ = _Trim$(Str$(T& \ 60))
        M$ = _Trim$(Str$(T& Mod 60))
        oldGT$ = String$(2 - Len(H$), 48) + _Trim$(Str$(T& \ 60)) + ":" + String$(2 - Len(M$), 48) + M$
        oldTime = T&
    End If
    GameTime$ = oldGT$
End Function
