Sub Build_Clouds
    Dim CloudsImage As Long
    Dim __X, __Z, __I%
    Dim As Integer hW, hH
    CloudsImage = _LoadImage("assets/environment/clouds.png", 32)
    TotalClouds = 0
    hW = _ShR(_Width(CloudsImage), 1)
    hH = _ShR(_Height(CloudsImage), 1)
    For __X = 0 To _Width(CloudsImage) - 1
        For __Z = 0 To _Height(CloudsImage) - 1
            If GetColorAtPosition&(CloudsImage, __X, __Z) = 0 Then _Continue
            For __I% = 0 To 23
                Select Case _ShR(__I%, 2)
                    Case 0: If GetColorAtPosition&(CloudsImage, __X + 1, __Z) Then _Continue
                    Case 1: If GetColorAtPosition&(CloudsImage, __X - 1, __Z) Then _Continue
                    Case 4: If GetColorAtPosition&(CloudsImage, __X, __Z + 1) Then _Continue
                    Case 5: If GetColorAtPosition&(CloudsImage, __X, __Z - 1) Then _Continue
                End Select
                CloudVertices(TotalClouds).X = (__X - hW) * 16 + _ShL(CubeVertices(__I%).X, 4): CloudVertices(TotalClouds).Y = CloudsHeight + _ShL(CubeVertices(__I%).Y, 2): CloudVertices(TotalClouds).Z = (__Z - hH) * 16 + _ShL(CubeVertices(__I%).Z, 4)
                CloudColors(TotalClouds).X = 255: CloudColors(TotalClouds).Y = 255: CloudColors(TotalClouds).Z = 255: CloudColors(TotalClouds).W = 191 ' _RGBA(255, 255, 255, 191)
                TotalClouds = TotalClouds + 1
            Next __I%
    Next __Z, __X
    _FreeImage CloudsImage
End Sub
Sub DrawClouds
    If Clouds = 0 Then Exit Sub
    Dim As _Unsigned Long I
    Dim As Single __MaxX, __MinX, __MaxZ, __MinZ
    Static As Single CloudsTranslateX
    '    Draw Clouds
    _glTranslatef CloudsTranslateX, 0, 0
    _glEnableClientState _GL_VERTEX_ARRAY
    _glEnableClientState _GL_COLOR_ARRAY
    _glVertexPointer 3, _GL_INT, 0, _Offset(CloudVertices(0))
    _glColorPointer 4, _GL_UNSIGNED_BYTE, 0, _Offset(CloudColors(0))
    _glDrawArrays _GL_QUADS, 0, TotalClouds
    _glTranslatef -CloudsTranslateX, 0, 0
    _glDisableClientState _GL_COLOR_ARRAY
    _glDisableClientState _GL_VERTEX_ARRAY
    '    Simulate Clouds
    CloudsTranslateX = ClampCycle(0, CloudsTranslateX + 0.05, 3.95)
    __MaxX = (Camera.Position.X + 2048) \ 4: __MinX = (Camera.Position.X - 2048) \ 4
    __MaxZ = (Camera.Position.Z + 2048) \ 4: __MinZ = (Camera.Position.Z - 2048) \ 4
    For I = 0 To TotalClouds - 1 Step 4
        If CloudVertices(I).X \ 4 > __MaxX Then
            CloudVertices(I).X = CloudVertices(I).X - 4096
            CloudVertices(I + 1).X = CloudVertices(I + 1).X - 4096
            CloudVertices(I + 2).X = CloudVertices(I + 2).X - 4096
            CloudVertices(I + 3).X = CloudVertices(I + 3).X - 4096
        ElseIf CloudVertices(I).X \ 4 < __MinX Then
            CloudVertices(I).X = CloudVertices(I).X + 4096
            CloudVertices(I + 1).X = CloudVertices(I + 1).X + 4096
            CloudVertices(I + 2).X = CloudVertices(I + 2).X + 4096
            CloudVertices(I + 3).X = CloudVertices(I + 3).X + 4096
        End If
        If CloudsTranslateX = 0 Then
            CloudVertices(I).X = CloudVertices(I).X + 4
            CloudVertices(I + 1).X = CloudVertices(I + 1).X + 4
            CloudVertices(I + 2).X = CloudVertices(I + 2).X + 4
            CloudVertices(I + 3).X = CloudVertices(I + 3).X + 4
        End If
        If CloudVertices(I).Z \ 4 > __MaxZ Then
            CloudVertices(I).Z = CloudVertices(I).Z - 4096
            CloudVertices(I + 1).Z = CloudVertices(I + 1).Z - 4096
            CloudVertices(I + 2).Z = CloudVertices(I + 2).Z - 4096
            CloudVertices(I + 3).Z = CloudVertices(I + 3).Z - 4096
        ElseIf CloudVertices(I).Z \ 4 < __MinZ Then
            CloudVertices(I).Z = CloudVertices(I).Z + 4096
            CloudVertices(I + 1).Z = CloudVertices(I + 1).Z + 4096
            CloudVertices(I + 2).Z = CloudVertices(I + 2).Z + 4096
            CloudVertices(I + 3).Z = CloudVertices(I + 3).Z + 4096
        End If
    Next I
    If GL_CURRENT_STATE = CONST_GL_STATE_Gameplay Then GameTime = ClampCycle(0, GameTime + 1 / GFPS - (_KeyDown(84) Or _KeyDown(116)), 1439)
End Sub
