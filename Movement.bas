_KeyClear
If _KeyDown(87) Or _KeyDown(119) Then PlayerMove CameraAngle.X - 90, MoveSpeed / LFPS 'W
If _KeyDown(83) Or _KeyDown(115) Then PlayerMove CameraAngle.X + 90, MoveSpeed / LFPS 'S
If _KeyDown(65) Or _KeyDown(97) Then PlayerMove CameraAngle.X + 180, MoveSpeed / LFPS 'A
If _KeyDown(68) Or _KeyDown(100) Then PlayerMove CameraAngle.X, MoveSpeed / LFPS 'D
ZOOM = _KeyDown(67) Or _KeyDown(99)
If _KeyDown(27) Then 'Esc
    While _KeyDown(27): Wend
    isPaused = -1
End If
Time = IIF(_KeyDown(84) Or _KeyDown(116), Time + 20, Time)
If (_KeyDown(70) Or _KeyDown(102)) Then 'F
    While _KeyDown(70) Or _KeyDown(102): _Limit 30: Wend
    FLYMODE = Not FLYMODE
End If: FLYMODE = IIF(InRange(1, Camera.Y, ChunkHeight) = 0, -1, FLYMODE)
If _KeyDown(71) Or _KeyDown(103) Then 'G
    While _KeyDown(71) Or _KeyDown(103): _Limit 30: Wend
    FOG = IIF(FOG > 0, -1, 1)
End If
If _KeyDown(15616) Then
    While _KeyDown(15616): _Limit 30: Wend
    ShowDebugInfo = Not ShowDebugInfo
End If
If _KeyDown(100304) Then 'LShift
    If FLYMODE Then
        Camera.Y = Camera.Y - MoveSpeed / LFPS
    Else
        If BlockExists(Camera.X, Camera.Y - PlayerHeight, Camera.Z) = 0 Then Camera.Y = Camera.Y - MoveSpeed / LFPS
    End If
End If
If _KeyDown(32) Then 'Space
    If FLYMODE Then
        Camera.Y = Camera.Y + MoveSpeed / LFPS
    Else
        If BlockExists(Camera.X, Camera.Y - PlayerHeight, Camera.Z) <> 0 Then PlayerVelocity.Y = 6
    End If
End If
If _KeyDown(100306) Then 'LCtrl
    If FLYMODE Then
        MoveSpeed = 64
    Else
        If isBlockFluid(BlockExists(Camera.X, Camera.Y - 1, Camera.Z)) Then MoveSpeed = 3 Else MoveSpeed = 6
    End If
Else
    If isBlockFluid(BlockExists(Camera.X, Camera.Y - 1, Camera.Z)) Then MoveSpeed = 2 Else MoveSpeed = 4
End If
If FLYMODE = 0 Then
    Camera.Y = Camera.Y + PlayerVelocity.Y / LFPS
    If isTransparent(BlockExists(Camera.X, Camera.Y - PlayerHeight, Camera.Z)) = 0 Then
        PlayerVelocity.Y = 0
    Else
        PlayerVelocity.Y = PlayerVelocity.Y + Gravity / LFPS
    End If
End If
BlockOnCamera = BlockExists(Camera.X, Camera.Y, Camera.Z) 'For Calculating Fog Colour under water
