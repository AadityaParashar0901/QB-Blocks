'$Dynamic
$Resize:On

Type Vec2_Float
    As Single X, Y
End Type
Type Vec2_Int
    As Integer X, Y
End Type
Type Vec3_Float
    As Single X, Y, Z
End Type
Type Vec3_Int
    As Integer X, Y, Z
End Type
Type Block
    As _Byte Block, Light
End Type
Type Chunk
    As Integer X, Z
    As _Unsigned Long Count, TCount, ShowCount, ShowTCount
    As _Byte isChunkDataLoaded, isRenderDataLoaded
    As Integer MinimumHeight, MaximumHeight
End Type
Type ModelInfo
    As _Unsigned Integer ModelID
    As _Unsigned Long StartOffset
    As _Unsigned Long TotalPoints
End Type

Screen _NewImage(960, 540, 32)
_PrintMode _KeepBackground

Const IMAGE_SIZE = 16
Dim Shared As Long TotalImages, AssetsImage(0), Textures, SunTexture, MoonTexture, CloudsTexture
Dim Shared AssetsModel(0) As ModelInfo, AssetsModelVertices(0) As Vec3_Float, AssetsModelTexCoords(0) As Vec2_Float

Const ChunkHeight = 256
Const GenerationChunkHeight = 256

Dim Shared As Vec3_Float Player_Position, Player_Velocity
Dim Shared As Vec2_Float Player_Angle
Dim Shared WorldFolder$
Dim Shared As _Unsigned _Byte FOV, RenderDistance, FOG, Brightness
Dim Shared As _Byte Zoom, FLYMODE
FOV = 90
RenderDistance = 8
FOG = -1
Brightness = 0
FLYMODE = -1
Game_Settings_Load
Game_Settings_Save
Const Player_Height = 1.8
Const Player_Obesity = 0.5
Dim Shared Player_Speed
Dim Shared As Vec3_Float Block_Selection_Ray
Dim Shared As _Unsigned Long Time, SkyLight
Dim Shared As Single SkyColorRed, SkyColorGreen, SkyColorBlue
SkyColorRed = 1
SkyColorGreen = 1
SkyColorBlue = 0.5

$Let GL = -1
Const WriteLogs = -1

_Title "QB Blocks 4"

If WriteLogs Then Open "log.txt" For Output As #100
LOADINGSCREENBACKGROUNDIMAGE = _LoadImage("assets/gui/background_loading.png", 32)
Open "assets/assets.list" For Input As #1
Do
    Line Input #1, L$
    If Left$(L$, 2) = "//" Then _Continue
    Select Case L$
        Case "textures {"
            ShowLoadingScreen "Loading Textures"
            Do
                Line Input #1, L$
                If Left$(L$, 2) = "//" Then _Continue
                Select Case L$
                    Case "}": Exit Do
                    Case Else: AssetsLoadImage Left$(L$, Len(L$))
                End Select
            Loop
        Case "blocks {"
            ShowLoadingScreen "Loading Block Data"
            Dim BlockName As String
            Do
                Line Input #1, L$
                If Left$(L$, 2) = "//" Then _Continue
                Select Case L$
                    Case "}": Exit Do
                    Case Else:
                        Select Case Left$(L$, InStr(L$, " ") - 1)
                            Case "totalblocks"
                                TotalBlocks = Val(Mid$(L$, 15))
                                WriteLog "Total Blocks: " + _Trim$(Str$(TotalBlocks))
                                CurrentBlock = 0
                                Dim Shared As _Unsigned Long BlockFaces(1 To TotalBlocks, 1 To 6), BlockModel(1 To TotalBlocks)
                            Case "name"
                                BlockName = Mid$(L$, 9, Len(L$) - 9)
                                CurrentBlock = CurrentBlock + 1
                                WriteLog "New Block: " + BlockName + "_" + _Trim$(Str$(CurrentBlock))
                            Case "textures"
                                L$ = Mid$(L$, 12)
                                If Left$(L$, 1) = "[" Then
                                    nBlockFace = 0
                                    L$ = Mid$(L$, 2)
                                    Do
                                        nBlockFace = nBlockFace + 1
                                        BlockFaces(CurrentBlock, nBlockFace) = Val(L$)
                                        L$ = Mid$(L$, InStr(L$, ",") + 1)
                                        If nBlockFace = 6 Then Exit Do
                                    Loop
                                Else
                                    For nBlockFace = 1 To 6
                                        BlockFaces(CurrentBlock, nBlockFace) = Val(L$)
                                    Next nBlockFace
                                End If
                                T$ = "["
                                For nBlockFace = 1 To 6
                                    T$ = T$ + _Trim$(Str$(BlockFaces(CurrentBlock, nBlockFace)))
                                    If nBlockFace < 6 Then T$ = T$ + "," Else T$ = T$ + "]"
                                Next nBlockFace
                                WriteLog "Block Face Textures: " + T$
                            Case "model"
                                BlockModel(CurrentBlock) = Val(Mid$(L$, 9))
                                WriteLog "Block Model: " + _Trim$(Str$(BlockModel(CurrentBlock)))
                        End Select
                End Select
            Loop
        Case "models {"
            ShowLoadingScreen "Loading Models"
            Do
                Line Input #1, L$
                If Left$(L$, 2) = "//" Then _Continue
                Select Case L$
                    Case "}": Exit Do
                    Case Else: AssetsLoadModel L$
                End Select
            Loop
        Case "end": Exit Do
        Case Else
            Select Case Left$(L$, InStr(L$, " ") - 1)
                Case "sun"
                    SunTexture = _LoadImage("assets/environment/" + Mid$(L$, InStr(L$, " ") + 1) + ".png", 32)
                Case "moon"
                    MoonTexture = _LoadImage("assets/environment/" + Mid$(L$, InStr(L$, " ") + 1) + ".png", 32)
                Case "clouds"
                    CloudsTexture = _LoadImage("assets/environment/" + Mid$(L$, InStr(L$, " ") + 1) + ".png", 32)
            End Select
    End Select
Loop

$If GL Then
    ShowLoadingScreen "Generating Secondary Textures"
    Textures = _NewImage(IMAGE_SIZE, UBound(AssetsImage) * IMAGE_SIZE, 32)
    For I = 1 To UBound(AssetsImage)
        _PutImage (0, (I - 1) * IMAGE_SIZE), AssetsImage(I), Textures
    Next I
    __GL_Generate_Texture = -1
    While __GL_Generate_Texture: Wend
    WriteLog "Secondary Texture Generated"
$End If

If _DirExists("saves") = 0 Then MkDir "saves"

ShowLoadingScreen "Initializing Chunks"
Const MaxRenderDistance = 16, MaxChunks = (MaxRenderDistance * 2 + 1) ^ 2 + 1
Dim Shared Chunks(1 To MaxChunks) As Chunk
Dim Shared ChunkData(1 To MaxChunks, 0 To 17, 0 To ChunkHeight + 1, 0 To 17) As Block
Dim Shared TMPCHUNKDATA(0 To 17, 0 To ChunkHeight + 1, 0 To 17) As Block
Dim Shared LoadedChunks As _Unsigned Integer
Const ChunkSectionVerticesSize = 64 * ChunkHeight '256
Const TotalVertices = MaxChunks * ChunkSectionVerticesSize
Dim Shared Vertices(1 To TotalVertices) As Vec3_Int
Dim Shared TVertices(1 To TotalVertices) As Vec3_Int
Dim Shared TexCoords(1 To TotalVertices) As Vec2_Float
Dim Shared TTexCoords(1 To TotalVertices) As Vec2_Float
Dim Shared Normals(1 To TotalVertices) As Vec3_Float
Dim Shared TNormals(1 To TotalVertices) As Vec3_Float

Dim Shared perm(0 To 458751) As Single

ShowLoadingScreen "Generating World"
Randomize Timer
SEED = Int(Rnd * 65536)
RePERM SEED

WorldFolder$ = _Trim$(Str$(SEED))
If _DirExists("saves/" + WorldFolder$) = 0 Then MkDir "saves/" + WorldFolder$
If _DirExists("saves/" + WorldFolder$ + "/chunks") = 0 Then MkDir "saves/" + WorldFolder$ + "/chunks"

Dim Shared isPaused As _Byte
Dim Shared ChunkLoadTime As _Unsigned Integer
Player_Position.Y = GenerationChunkHeight / 2

Dim Shared As _Unsigned Integer LFPS, GFPS, LFPSCount, GFPSCount: LFPS = 60
FPSCounterTimer = _FreeTimer: On Timer(FPSCounterTimer, 1) GoSub FPSCounter: Timer(FPSCounterTimer) Off
GameTickTimer = _FreeTimer: On Timer(GameTickTimer, 1 / 20) GoSub GameTick: Timer(GameTickTimer) Off

LoadChunkDirection = 1
LoadChunkLength = 1

_Title "QB Blocks 4 - " + WorldFolder$

Cls
_GLRender _Behind
allowGL = -1
Do 'Main Loop
    _Limit 60
    LFPSCount = LFPSCount + 1
    _KeyClear
    If _KeyDown(27) Then
        isPaused = Not isPaused
        While _KeyDown(27): Wend
    End If
    If isPaused Then
        While _MouseInput: Wend
        _MouseShow
        _Continue
    Else
        isPaused = Not _WindowHasFocus
        _MouseHide
    End If
    If _Resize Then
        Screen _NewImage(_ResizeWidth, _ResizeHeight, 32)
        _PrintMode _KeepBackground
    End If
    If LFPSCount Mod 2 Then
        ChunkX = Int(Player_Position.X / 16): ChunkZ = Int(Player_Position.Z / 16)
        For I = LBound(Chunks) To UBound(Chunks)
            If Chunks(I).isChunkDataLoaded = 0 Then _Continue
            If InRange(-RenderDistance, Chunks(I).X - ChunkX, RenderDistance) = 0 Or InRange(-RenderDistance, Chunks(I).Z - ChunkZ, RenderDistance) = 0 Then
                Chunks(I).X = 0: Chunks(I).Z = 0
                Chunks(I).Count = 0: Chunks(I).TCount = 0
                Chunks(I).isChunkDataLoaded = 0: Chunks(I).isRenderDataLoaded = 0
                LoadedChunks = LoadedChunks - 1
                Exit For
            End If
        Next I
        For I = 0 To 63
            ChunkLoadingStartTime = Timer(0.001)
            CL = 0
            EXITFOR = 0
            If InRange(-RenderDistance, LoadChunkX, RenderDistance) And InRange(-RenderDistance, LoadChunkZ, RenderDistance) Then CL = LoadChunk(ChunkX + LoadChunkX, ChunkZ + LoadChunkZ)
            If CL Then EXITFOR = -1
            If CL Then ChunkLoadTime = Int(1000 * (Timer(0.001) - ChunkLoadingStartTime)) Else ChunkLoadTime = 0
            E = 0
            Select Case LoadChunkDirection
                Case 1: LoadChunkZ = LoadChunkZ + 1
                    If LoadChunkZ - InitialLoadChunkZ = LoadChunkLength + 1 Then E = -1
                Case 2: LoadChunkX = LoadChunkX + 1
                    If LoadChunkX - InitialLoadChunkX = LoadChunkLength + 1 Then E = -1
                Case 3: LoadChunkZ = LoadChunkZ - 1
                    If InitialLoadChunkZ - LoadChunkZ = LoadChunkLength + 1 Then E = -1
                Case 4: LoadChunkX = LoadChunkX - 1
                    If InitialLoadChunkX - LoadChunkX = LoadChunkLength + 1 Then E = -1
            End Select
            If E Then
                LoadChunkDirection = LoadChunkDirection + 1
                If LoadChunkDirection = 5 Then LoadChunkDirection = 1
                If LoadChunkDirection = 1 Or LoadChunkDirection = 3 Then LoadChunkLength = LoadChunkLength + 1
                If LoadChunkLength = 2 * RenderDistance + 1 Then LoadChunkLength = 0: LoadChunkX = 0: LoadChunkZ = 0
                InitialLoadChunkX = LoadChunkX
                InitialLoadChunkZ = LoadChunkZ
            End If
            If EXITFOR Then Exit For
        Next I
    End If
    While _MouseInput
        Player_Angle.X = Player_Angle.X + _MouseMovementX / 8
        Player_Angle.Y = Player_Angle.Y - _MouseMovementY / 8
        If Player_Angle.Y < -90 Then Player_Angle.Y = -90
        If Player_Angle.Y > 90 Then Player_Angle.Y = 90
        If Player_Angle.X < -180 Then Player_Angle.X = Player_Angle.X + 360
        If Player_Angle.X > 180 Then Player_Angle.X = Player_Angle.X - 360
        _MouseMove _Width / 2, _Height / 2
    Wend
    If _KeyDown(100306) Then Player_Speed = 16 Else Player_Speed = 4
    If _KeyDown(87) Or _KeyDown(119) Then PlayerMove Player_Angle.X - 90, Player_Speed / LFPS
    If _KeyDown(83) Or _KeyDown(115) Then PlayerMove Player_Angle.X + 90, Player_Speed / LFPS
    If _KeyDown(65) Or _KeyDown(97) Then PlayerMove Player_Angle.X + 180, Player_Speed / LFPS
    If _KeyDown(68) Or _KeyDown(100) Then PlayerMove Player_Angle.X, Player_Speed / LFPS
    Zoom = _KeyDown(67) Or _KeyDown(99)
    If _KeyDown(100304) Then Player_Position.Y = Player_Position.Y - Player_Speed / LFPS
    If _KeyDown(70) Or _KeyDown(102) Then FOG = Not FOG: While _KeyDown(70) Or _KeyDown(102): Wend
    If _KeyDown(71) Or _KeyDown(103) Then FLYMODE = Not FLYMODE: While _KeyDown(71) Or _KeyDown(103): Wend
    If FLYMODE = 0 Then
        If isTransparent(getBlock(Player_Position.X, Player_Position.Y - Player_Height, Player_Position.Z)) Then
            Player_Velocity.Y = Player_Velocity.Y - 10 / LFPS
        Else
            Player_Velocity.Y = 0
            If _KeyDown(32) Then Player_Velocity.Y = 4
        End If
        Player_Position.Y = Player_Position.Y + Player_Velocity.Y / LFPS
    Else
        If _KeyDown(32) Then Player_Position.Y = Player_Position.Y + Player_Speed / LFPS
    End If
Loop
System

FPSCounter:
If LFPSCount Then LFPS = LFPSCount
LFPSCount = 0
GFPS = GFPSCount: GFPSCount = 0
Return

GameTick:
Time = Time + 1
If Time > 28800 Then Time = 0
Return

$If GL Then
    Sub _GL
        Shared allowGL, __GL_Generate_Texture
        Static As Long TextureHandle, SunTextureHandle, MoonTextureHandle, CloudsTextureHandle
        If __GL_Generate_Texture Then
            If Textures < -1 Then GL_Generate_Texture TextureHandle, Textures
            If SunTexture < -1 Then GL_Generate_Texture SunTextureHandle, SunTexture
            If MoonTexture < -1 Then GL_Generate_Texture MoonTextureHandle, MoonTexture
            If CloudsTexture < -1 Then GL_Generate_Texture CloudsTextureHandle, CloudsTexture
            __GL_Generate_Texture = 0
        End If
        If allowGL = 0 Then Exit Sub

        _glViewport 0, 0, _Width - 1, _Height - 1
        _glEnable _GL_BLEND
        _glDisable _GL_MULTISAMPLE
        _glEnable _GL_DEPTH_TEST

        _glClearColor SkyColorRed, SkyColorGreen, SkyColorBlue, 0
        _glClear _GL_DEPTH_BUFFER_BIT Or _GL_COLOR_BUFFER_BIT

        _glTranslatef 0, 0, -0.25
        _glRotatef -Player_Angle.Y, 1, 0, 0
        _glRotatef Player_Angle.X, 0, 1, 0
        _glTranslatef -Player_Position.X, -Player_Position.Y, -Player_Position.Z

        _glMatrixMode _GL_PROJECTION
        _glLoadIdentity
        If Zoom Then _gluPerspective 30, _Width / _Height, 0.1, Max(ChunkHeight, RenderDistance * 16 + 64) Else _gluPerspective FOV, _Width / _Height, 0.1, Max(ChunkHeight, RenderDistance * 16 + 64)

        _glMatrixMode _GL_MODELVIEW

        If FOG Then
            _glEnable _GL_FOG

            _glFogi _GL_FOG_MODE, _GL_EXP
            _glFogf _GL_FOG_START, 16 * RenderDistance - 64
            _glFogf _GL_FOG_END, 16 * RenderDistance - 32
            _glFogfv _GL_FOG_COLOR, glVec4(0.75, 0.88, 1, 1)
            _glFogf _GL_FOG_DENSITY, 0.01
        End If

        _glEnable _GL_LIGHTING
        _glEnable _GL_LIGHT0

        _glLightfv _GL_LIGHT0, _GL_AMBIENT, glVec4(SkyColorRed, SkyColorGreen, SkyColorBlue, 0)
        _glLightfv _GL_LIGHT0, _GL_DIFFUSE, glVec4(SkyColorRed, SkyColorGreen, SkyColorBlue, 0)
        _glLightfv _GL_LIGHT0, _GL_SPECULAR, glVec4(SkyColorRed, SkyColorGreen, SkyColorBlue, 0)
        _glLightfv _GL_LIGHT0, _GL_POSITION, glVec4(Player_Position.X, Player_Position.Y, Player_Position.Z, 0)
        _glLightfv _GL_LIGHT0, _GL_SPOT_DIRECTION, glVec4(0, 1, 0, 0)
        _glLightfv _GL_LIGHT0, _GL_SPOT_EXPONENT, glVec4(1, 0, 0, 0)

        _glEnable _GL_COLOR_MATERIAL
        _glColorMaterial _GL_FRONT, _GL_DIFFUSE

        _glEnable _GL_TEXTURE_2D

        _glBindTexture _GL_TEXTURE_2D, TextureHandle

        _glEnableClientState _GL_VERTEX_ARRAY
        _glEnableClientState _GL_TEXTURE_COORD_ARRAY
        _glEnableClientState _GL_NORMAL_ARRAY

        For I = LBound(Chunks) - 1 To UBound(Chunks) - 1
            If Chunks(I + 1).ShowCount = 0 Or Chunks(I + 1).isRenderDataLoaded = 0 Then _Continue
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(I * ChunkSectionVerticesSize + 1))
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TexCoords(I * ChunkSectionVerticesSize + 1))
            _glNormalPointer _GL_FLOAT, 0, _Offset(Normals(I * ChunkSectionNormalsSize + 1))
            _glDrawArrays _GL_QUADS, 0, Chunks(I + 1).ShowCount
        Next I

        For I = LBound(Chunks) - 1 To UBound(Chunks) - 1
            If Chunks(I + 1).ShowTCount = 0 Or Chunks(I + 1).isRenderDataLoaded = 0 Then _Continue
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(TVertices(I * ChunkSectionVerticesSize + 1))
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TTexCoords(I * ChunkSectionVerticesSize + 1))
            _glNormalPointer _GL_FLOAT, 0, _Offset(TNormals(I * ChunkSectionNormalsSize + 1))
            _glDrawArrays _GL_QUADS, 0, Chunks(I + 1).ShowTCount
        Next I

        _glDisableClientState _GL_VERTEX_ARRAY
        _glDisableClientState _GL_TEXTURE_COORD_ARRAY
        _glDisableClientState _GL_NORMAL_ARRAY

        _glDisable _GL_TEXTURE_2D
        _glDisable _GL_COLOR_MATERIAL
        _glDisable _GL_LIGHT0
        _glDisable _GL_LIGHTING
        If FOG Then _glDisable _GL_FOG
        _glDisable _GL_DEPTH_TEST
        _glDisable _GL_MULTISAMPLE
        _glDisable _GL_BLEND
        _glFlush
        ShowInfo
        _Display
        GFPSCount = GFPSCount + 1
    End Sub

    Sub GL_Generate_Texture (TextureHandle As Long, Texture As Long)
        Dim M As _MEM
        _glGenTextures 1, _Offset(TextureHandle)
        _glBindTexture _GL_TEXTURE_2D, TextureHandle
        M = _MemImage(Texture)
        _glTexImage2D _GL_TEXTURE_2D, 0, _GL_RGBA, _Width(Texture), _Height(Texture), 0, _GL_BGRA_EXT, _GL_UNSIGNED_BYTE, M.OFFSET
        _MemFree M
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MIN_FILTER, _GL_NEAREST
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MAG_FILTER, _GL_NEAREST
    End Sub

    Function glVec4%& (X!, Y!, Z!, W!)
        Static VEC4(3) As Single
        VEC4(0) = X!: VEC4(1) = Y!: VEC4(2) = Z!: VEC4(3) = W!
        glVec4%& = _Offset(VEC4())
    End Function
$End If

Sub ShowInfo
    Cls 2, 0
    Print "FPS (G/L): "; GFPS; "/"; LFPS
    Print "Position: "; Player_Position.X; Player_Position.Y; Player_Position.Z
    Print "Angle: "; Player_Angle.X; Player_Angle.Y
    Print "Chunk Loading Time: "; ChunkLoadTime
End Sub

Sub RePERM (SEED As _Unsigned Integer)
    Randomize SEED
    ReDim perm(0 To 65536 * 7 - 1) As Single
    For I = 0 To 65536 * 7 - 1
        perm(I) = Rnd
    Next I
End Sub
Function hash# (X As _Unsigned Integer, M As _Unsigned _Byte)
    hash# = perm(M * 65535 + X)
End Function
Function fade# (t As Double) Static
    fade# = ((6 * t - 15) * t + 10) * t ^ 3
End Function
Function interpolate# (A#, B#, C#) Static
    interpolate# = A# + (B# - A#) * C#
End Function
Function noise1# (X As Double, M As _Unsigned _Byte) Static
    fX% = Int(X): dX# = fade#(X - fX%)
    noise1# = interpolate#(hash(fX%, M), hash(fX% + 1, M), dX#)
End Function
Function noise2# (X As Double, Y As Double, M As _Unsigned _Byte) Static
    fX% = Int(X): dX# = fade#(X - fX%)
    fY% = Int(Y): dY# = fade#(Y - fY%)
    noise2# = interpolate#(interpolate#(hash(fX% + fY% * 57, M), hash(fX% + fY% * 57 + 1, M), dX#), interpolate#(hash(fX% + fY% * 57 + 57, M), hash(fX% + fY% * 57 + 58, M), dX#), dY#)
End Function
Function noise3# (X As Double, Y As Double, Z As Double, M As _Unsigned _Byte) Static
    fX% = Int(X): dX# = fade#(X - fX%)
    fY% = Int(Y): dY# = fade#(Y - fY%)
    fZ% = Int(Z): dZ# = fade#(Z - fZ%)
    noise3# = interpolate#(interpolate#(interpolate#(hash(fX% + (fY% + fZ% * 57) * 57, M), hash(fX% + (fY% + fZ% * 57) * 57 + 1, M), dX#), interpolate#(hash(fX% + (fY% + fZ% * 57) * 57 + 57, M), hash(fX% + (fY% + fZ% * 57) * 57 + 58, M), dX#), dY#), interpolate#(interpolate#(hash(fX% + (fY% + fZ% * 57 + 57) * 57, M), hash(fX% + (fY% + fZ% * 57 + 57) * 57 + 1, M), dX#), interpolate#(hash(fX% + (fY% + fZ% * 57 + 57) * 57 + 57, M), hash(fX% + (fY% + fZ% * 57 + 57) * 57 + 58, M), dX#), dY#), dZ#)
End Function
Function fractal1# (X As Integer, O As _Unsigned _Byte, S As _Unsigned Long, M As _Unsigned _Byte) Static
    Dim As Double a, t, d, I
    a = 1: t = 0: d = 0
    For I = 0 To O
        t = t + a * noise1#(X / a / S, M): d = d + a: a = a / 2
    Next I
    fractal1# = t / d
End Function
Function fractal2# (X As Integer, Y As Integer, O As _Unsigned _Byte, S As _Unsigned Long, M As _Unsigned _Byte) Static
    Dim As Double a, t, d, I
    a = 1: t = 0: d = 0
    For I = 0 To O
        t = t + a * noise2#(X / a / S, Y / a / S, M): d = d + a: a = a / 2
    Next I
    fractal2# = t / d
End Function
Function fractal3# (X As Integer, Y As Integer, Z As Integer, O As _Unsigned _Byte, S As _Unsigned Long, M As _Unsigned _Byte) Static
    Dim As Double a, t, d, I
    a = 1: t = 0: d = 0
    For I = 0 To O
        t = t + a * noise3#(X / a / S, Y / a / S, Z / a / S, M): d = d + a: a = a / 2
    Next I
    fractal3# = t / d
End Function

Function isTransparent (B As _Unsigned _Byte)
    isTransparent = (B = 0) Or (B = 6) Or (B = 10)
End Function

Function getBlock (X, Y, Z)
    Dim As Integer CX, CZ: Dim As _Unsigned _Byte CPX, CPY, CPZ
    Camera2ChunkRelativePosition X, Y, Z, CX, CZ, CPX, CPY, CPZ
    For I = 1 To UBound(Chunks)
        If Chunks(I).X = CX And Chunks(I).Z = CZ And Chunks(I).isChunkDataLoaded Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Function
    getBlock = ChunkData(FoundI, CPX, CPY, CPZ).Block
End Function

Function isBlockFluid (B As _Unsigned _Byte)
    isBlockFluid = (B = 0)
End Function

Sub PlayerMove (Angle As Single, Speed As Single)
    Dim As Single dX, dZ
    dX = Cos(_D2R(Angle)) * Speed
    dZ = Sin(_D2R(Angle)) * Speed
    If FLYMODE Then
        Player_Position.X = Player_Position.X + dX
        Player_Position.Z = Player_Position.Z + dZ
    Else
        If isTransparent(getBlock(Player_Position.X + Sgn(dX) * Player_Obesity, Player_Position.Y, Player_Position.Z)) And isTransparent(getBlock(Player_Position.X + Sgn(dX) * Player_Obesity, Player_Position.Y - 1, Player_Position.Z)) Then Player_Position.X = Player_Position.X + dX
        If isTransparent(getBlock(Player_Position.X, Player_Position.Y, Player_Position.Z + Sgn(dZ) * Player_Obesity)) And isTransparent(getBlock(Player_Position.X, Player_Position.Y - 1, Player_Position.Z + Sgn(dZ) * Player_Obesity)) Then Player_Position.Z = Player_Position.Z + dZ
    End If
End Sub

Sub Player_Data_Load
    If _FileExists("saves/" + WorldFolder$ + "/player.dat") = 0 Then Exit Sub
    __F = FreeFile
    Open "saves/" + WorldFolder$ + "/player.dat" For Binary As #__F
    Get #__F, , Player_Position
    Get #__F, , Player_Angle
    Get #__F, , Player_Velocity
    Get #__F, , Time
    Close #__F
End Sub

Sub Player_Data_Save
    __F = FreeFile
    Open "saves/" + WorldFolder$ + "/player.dat" For Binary As #__F
    Put #__F, , Player_Position
    Put #__F, , Player_Angle
    Put #__F, , Player_Velocity
    Put #__F, , Time
    Close #__F
End Sub

Function LoadChunk (CX As Integer, CZ As Integer)
    ST! = Timer(0.01)
    For I = LBound(Chunks) To UBound(Chunks)
        If Chunks(I).X = CX And Chunks(I).Z = CZ And Chunks(I).isChunkDataLoaded = -1 Then Exit Function
        If Chunks(I).isChunkDataLoaded = 0 And FoundI = 0 Then FoundI = I
    Next I
    If FoundI = 0 Then WriteLog "Cannot Allocate Space to load Chunk": Exit Function
    WriteLog "Loading Chunk: " + _Trim$(Str$(FoundI)) + " - " + _Trim$(Str$(CX)) + "_" + _Trim$(Str$(CZ)) + ":" + _Trim$(Str$((Timer(0.01) - ST!) * 1000))
    If Chunk_In(CX, CZ, FoundI) = 0 Then
        CX16 = CX * 16
        CZ16 = CZ * 16
        Chunks(FoundI).X = CX
        Chunks(FoundI).Z = CZ
        Chunks(FoundI).MinimumHeight = GenerationChunkHeight
        Chunks(FoundI).MaximumHeight = 1
        For X = 0 To 17: For Z = 0 To 17: For Y = 0 To ChunkHeight + 1
                    ChunkData(FoundI, X, Y, Z).Block = 0
        Next Y, Z, X
        For X = -3 To 20
            For Z = -3 To 20
                H = Int(GenerationChunkHeight * (fractal2(CX16 + X, CZ16 + Z, 0, 64, 0) + (fractal2(CX16 + X, CZ16 + Z, 7, 256, 1) * fractal2(CX16 + X, CZ16 + Z, 7, 64, 2))) / 4)
                If H < LBound(ChunkData, 3) Then _Continue
                Chunks(FoundI).MinimumHeight = Min(Chunks(FoundI).MinimumHeight, H - 1)
                Chunks(FoundI).MaximumHeight = Max(Chunks(FoundI).MaximumHeight, H)
                Biome = Int(4 * fractal2(CX16 + X, CZ16 + Z, 0, 256, 3))
                SpawnTrees = 0
                Select Case Biome
                    Case 0: BiomeSurfaceBlock = 3: BiomeUnderSurfaceBlock = 3
                    Case 1, 2: BiomeSurfaceBlock = 1: BiomeUnderSurfaceBlock = 2: SpawnTrees = -1
                    Case 3: BiomeSurfaceBlock = 4: BiomeUnderSurfaceBlock = 2: SpawnTrees = -1
                End Select
                canPlaceBlock = InRange(0, X, 17) And InRange(0, Z, 17)
                If canPlaceBlock Then
                    For Y = 0 To H - 1
                        ChunkData(FoundI, X, Y, Z).Block = BiomeUnderSurfaceBlock
                    Next Y
                    ChunkData(FoundI, X, Y, Z).Block = BiomeSurfaceBlock
                End If
                If SpawnTrees And fractal2(CX16 + X, CZ16 + Z, 0, 2, 4) > 0.8 Then
                    If canPlaceBlock Then
                        ChunkData(FoundI, X, Y + 1, Z).Block = 5
                        ChunkData(FoundI, X, Y + 2, Z).Block = 5
                        ChunkData(FoundI, X, Y + 3, Z).Block = 5
                    End If
                    For XX = X - 3 To X + 3
                        For ZZ = Z - 3 To Z + 3
                            If canPlaceBlock And InRange(0, XX, 17) And InRange(0, ZZ, 17) And InRange(0, Y + 4, 257) Then ChunkData(FoundI, XX, Y + 4, ZZ).Block = 6
                    Next ZZ, XX
                End If
            Next Z
        Next X
    End If
    Chunks(FoundI).isChunkDataLoaded = -1
    ReloadChunk FoundI
    LoadChunk = -1
    WriteLog "Chunk Loaded: " + _Trim$(Str$(FoundI)) + " - " + _Trim$(Str$(CX)) + "_" + _Trim$(Str$(CZ)) + ":" + _Trim$(Str$((Timer(0.01) - ST!) * 1000))
    LoadedChunks = LoadedChunks + 1
End Function

Sub ReloadChunk (FoundI As _Unsigned Integer)
    Dim As _Unsigned _Byte Face, Visibility, Block
    Dim As _Unsigned Long LV, LTV
    LV = (FoundI - 1) * ChunkSectionVerticesSize
    LTV = (FoundI - 1) * ChunkSectionVerticesSize
    CX16 = Chunks(FoundI).X * 16
    CZ16 = Chunks(FoundI).Z * 16
    For X = 1 To 16: For Z = 1 To 16: For Y = Chunks(FoundI).MinimumHeight To Chunks(FoundI).MaximumHeight
                Block = ChunkData(FoundI, X, Y, Z).Block
                If Block = 0 Then _Continue
                Visibility = -(isTransparent(ChunkData(FoundI, X + 1, Y, Z).Block) + 2 * isTransparent(ChunkData(FoundI, X - 1, Y, Z).Block) + 4 * isTransparent(ChunkData(FoundI, X, Y + 1, Z).Block) + 8 * isTransparent(ChunkData(FoundI, X, Y - 1, Z).Block) + 16 * isTransparent(ChunkData(FoundI, X, Y, Z + 1).Block) + 32 * isTransparent(ChunkData(FoundI, X, Y, Z - 1).Block))
                If Visibility = 0 Then _Continue
                If InRange(LBound(BlockFaces, 1), Block, UBound(BlockFaces, 1)) = 0 Then _Continue
                If isTransparent(Block) Then
                    For I = 0 To 23
                        Face = _SHL(1, _SHR(I, 2))
                        If (Face And Visibility) = 0 Then _Continue
                        LTV = LTV + 1
                        TVertices(LV).X = AssetsModelVertices(I + 1).X + CX16 + X
                        TVertices(LV).Y = AssetsModelVertices(I + 1).Y + Y
                        TVertices(LV).Z = AssetsModelVertices(I + 1).Z + CZ16 + Z
                        TTexCoords(LV).X = AssetsModelTexCoords(I + 1).X
                        TTexCoords(LV).Y = (AssetsModelTexCoords(I + 1).Y + BlockFaces(Block, _SHR(I, 2) + 1) - 1) / TotalImages
                        Chunks(FoundI).TCount = Chunks(FoundI).TCount + 1
                        Select Case _SHR(I, 2)
                            Case 1: TNormals(LTV).X = 1: TNormals(LTV).Y = 0: TNormals(LTV).Z = 0
                            Case 2: TNormals(LTV).X = -1: TNormals(LTV).Y = 0: TNormals(LTV).Z = 0
                            Case 3: TNormals(LTV).X = 0: TNormals(LTV).Y = 1: TNormals(LTV).Z = 0
                            Case 4: TNormals(LTV).X = 0: TNormals(LTV).Y = -1: TNormals(LTV).Z = 0
                            Case 5: TNormals(LTV).X = 0: TNormals(LTV).Y = 0: TNormals(LTV).Z = 1
                            Case 6: TNormals(LTV).X = 0: TNormals(LTV).Y = 0: TNormals(LTV).Z = -1
                        End Select
                        Normals(LTV).X = Normals(LTV).X + Vertices(LTV).X
                        Normals(LTV).Y = Normals(LTV).Y + Vertices(LTV).Y
                        Normals(LTV).Z = Normals(LTV).Z + Vertices(LTV).Z
                    Next I
                Else
                    For I = 0 To 23
                        Face = _SHL(1, _SHR(I, 2))
                        If (Face And Visibility) = 0 Then _Continue
                        LV = LV + 1
                        Vertices(LV).X = AssetsModelVertices(I + 1).X + CX16 + X
                        Vertices(LV).Y = AssetsModelVertices(I + 1).Y + Y
                        Vertices(LV).Z = AssetsModelVertices(I + 1).Z + CZ16 + Z
                        TexCoords(LV).X = AssetsModelTexCoords(I + 1).X
                        TexCoords(LV).Y = (AssetsModelTexCoords(I + 1).Y + BlockFaces(Block, _SHR(I, 2) + 1) - 1) / TotalImages
                        Chunks(FoundI).Count = Chunks(FoundI).Count + 1
                        Select Case _SHR(I, 2)
                            Case 1: Normals(LV).X = 1: Normals(LV).Y = 0: Normals(LV).Z = 0
                            Case 2: Normals(LV).X = -1: Normals(LV).Y = 0: Normals(LV).Z = 0
                            Case 3: Normals(LV).X = 0: Normals(LV).Y = 1: Normals(LV).Z = 0
                            Case 4: Normals(LV).X = 0: Normals(LV).Y = -1: Normals(LV).Z = 0
                            Case 5: Normals(LV).X = 0: Normals(LV).Y = 0: Normals(LV).Z = 1
                            Case 6: Normals(LV).X = 0: Normals(LV).Y = 0: Normals(LV).Z = -1
                        End Select
                        Normals(LV).X = Normals(LV).X + Vertices(LV).X
                        Normals(LV).Y = Normals(LV).Y + Vertices(LV).Y
                        Normals(LV).Z = Normals(LV).Z + Vertices(LV).Z
                    Next I
                End If
    Next Y, Z, X
    Chunks(FoundI).isRenderDataLoaded = -1
    Chunks(FoundI).ShowCount = Chunks(FoundI).Count
    Chunks(FoundI).ShowTCount = Chunks(FoundI).TCount
End Sub

Function Chunk_In (CX As Integer, CZ As Integer, FoundI As Integer)
    If FoundI = 0 Then Exit Function
    __F = FreeFile
    FILE$ = _Trim$(Str$(Int(CX / 16))) + "_" + _Trim$(Str$(Int(CZ / 16)))
    If _FileExists("saves/" + WorldFolder$ + "/chunks/" + FILE$ + ".region") = 0 Then Exit Function
    Open "saves/" + WorldFolder$ + "/chunks/" + FILE$ + ".region" For Binary As #__F
    Dim Chunk As Chunk
    Do
        Get #__F, , Chunk
        Get #__F, , TMPCHUNKDATA()
        If Chunk.X = CX And Chunk.Z = CZ Then Found = -1: Exit Do
        If EOF(__F) Then Exit Do
    Loop
    Close #__F
    If Found = 0 Then Exit Function
    Dim T As Block
    For X = 0 To 17
        For Y = 0 To ChunkHeight + 1
            For Z = 0 To 17
                T = TMPCHUNKDATA(X, Y, Z)
                ChunkData(FoundI, X, Y, Z) = T
    Next Z, Y, X
    Chunk_In = -1
End Function

Sub Chunk_Out (FoundI As Integer)
    Dim TMPChunk As Chunk
    If Chunks(FoundI).isChunkDataLoaded = 0 Then Exit Sub
    TMPChunk = Chunks(FoundI)
    TMPChunk.ShowCount = 0
    TMPChunk.ShowTCount = 0
    TMPChunk.Count = 0
    TMPChunk.TCount = 0
    TMPChunk.isRenderDataLoaded = 0
    For X = 0 To 17
        For Y = 0 To ChunkHeight + 1
            For Z = 0 To 17
                TMPCHUNKDATA(X, Y, Z) = ChunkData(FoundI, X, Y, Z)
    Next Z, Y, X
    __F = FreeFile
    FILE$ = _Trim$(Str$(Int(Chunks(FoundI).X / 16))) + "_" + _Trim$(Str$(Int(Chunks(FoundI).Z / 16)))
    Open "saves/" + WorldFolder$ + "/chunks/" + FILE$ + ".region" For Binary As #__F
    Seek #__F, LOF(__F) + 1
    Put #__F, , TMPChunk
    Put #__F, , TMPCHUNKDATA()
    Close #__F
End Sub

Sub Game_Settings_Load
    If _FileExists("saves/settings.dat") = 0 Then Exit Sub
    __F = FreeFile
    Open "saves/settings.dat" For Binary As #__F
    Get #__F, , FOV
    Get #__F, , RenderDistance
    Get #__F, , FOG
    Get #__F, , Brightness
    Close #__F
End Sub

Sub Game_Settings_Save
    If _DirExists("saves") = 0 Then MkDir "saves"
    __F = FreeFile
    Open "saves/settings.dat" For Binary As #__F
    Put #__F, , FOV
    Put #__F, , RenderDistance
    Put #__F, , FOG
    Get #__F, , Brightness
    Close #__F
End Sub

Sub WriteLog (T$)
    If WriteLogs Then Print #100, "[" + Time$ + "]:[" + T$ + "]"
End Sub
Sub AssetsLoadImage (F$)
    WriteLog "Loading Image Asset: " + F$
    If _FileExists("assets/textures/" + F$ + ".png") Then __T& = _LoadImage("assets/textures/" + F$ + ".png", 32)
    If _FileExists("assets/textures/" + F$ + ".jpg") Then __T& = _LoadImage("assets/textures/" + F$ + ".jpg", 32)
    If _FileExists("assets/textures/" + F$) Then __T& = _LoadImage("assets/textures/" + F$, 32)
    If __T& < -1 Then
        WriteLog "Image Asset loaded"
    Else
        WriteLog "Couldn't load Image Asset"
    End If
    If AssetsImage(UBound(AssetsImage)) < -1 Then ReDim _Preserve AssetsImage(1 To UBound(AssetsImage) + 1) As Long
    AssetsImage(UBound(AssetsImage)) = __T&
    TotalImages = UBound(AssetsImage)
End Sub
Sub AssetsLoadModel (F$)
    WriteLog "Loading Model Asset: " + F$
    If UBound(AssetsModel) = 0 Then ReDim AssetsModel(1 To 1) As ModelInfo Else ReDim _Preserve AssetsModel(1 To UBound(AssetsModel) + 1) As ModelInfo
    __F = FreeFile
    Open "assets/models/" + F$ + ".model" For Input As #__F
    AssetsModel(UBound(AssetsModel)).StartOffset = UBound(AssetsModelVertices) + 1
    Do
        Line Input #__F, L$
        If L$ = "" And EOF(__F) Then Exit Do
        If Left$(L$, 2) = "//" Then _Continue
        If UBound(AssetsModelVertices) = 0 Then ReDim AssetsModelVertices(1 To 1) As Vec3_Float Else ReDim _Preserve AssetsModelVertices(1 To UBound(AssetsModelVertices) + 1) As Vec3_Float
        If UBound(AssetsModelTexCoords) = 0 Then ReDim AssetsModelTexCoords(1 To 1) As Vec2_Float Else ReDim _Preserve AssetsModelTexCoords(1 To UBound(AssetsModelTexCoords) + 1) As Vec2_Float
        V = 0
        Do
            V = V + 1
            T = Val(L$)
            If V < 5 Then L$ = Mid$(L$, InStr(L$, ",") + 1)
            Select Case V
                Case 1: AssetsModelVertices(UBound(AssetsModelVertices)).X = T
                Case 2: AssetsModelVertices(UBound(AssetsModelVertices)).Y = T
                Case 3: AssetsModelVertices(UBound(AssetsModelVertices)).Z = T
                Case 4: AssetsModelTexCoords(UBound(AssetsModelTexCoords)).X = T
                Case 5: AssetsModelTexCoords(UBound(AssetsModelTexCoords)).Y = T
            End Select
            If V = 5 Then Exit Do
        Loop
        If EOF(__F) Then Exit Do
    Loop
    AssetsModel(UBound(AssetsModel)).TotalPoints = UBound(AssetsModelVertices) - AssetsModel(UBound(AssetsModel)).StartOffset
    Close #__F
    WriteLog "Model Loaded"
End Sub
Sub NewScreen (W, H, T$)
    Screen _NewImage(W, H, 32)
    _Title T$
    _PrintMode _KeepBackground
End Sub
Sub ShowLoadingScreen (M$)
    Shared LOADINGSCREENBACKGROUNDIMAGE As Long
    Cls
    _PutImage (0, 0)-(_Width - 1, _Height - 1), LOADINGSCREENBACKGROUNDIMAGE
    CenterPrintString _Height * 0.75, M$
    _Display
    WriteLog M$
End Sub
Sub CenterPrintString (Y, T$)
    PrintString (_Width - Len(T$) * _FontWidth) / 2, Y, T$
End Sub
Sub PrintString (X, Y, T$)
    _PrintString (X, Y - _FontHeight / 2), T$
End Sub
Function Dis2 (X1, Y1, X2, Y2)
    Dis2 = _Hypot(X2 - X1, Y2 - Y1)
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
Function InBox (X1, Y1, X, Y, X2, Y2)
    InBox = InRange(X1, X, X2) And InRange(Y1, Y, Y2)
End Function
Sub Camera2ChunkRelativePosition (X, Y, Z, CX As Integer, CZ As Integer, CPX As _Unsigned _Byte, CPY As _Unsigned _Byte, CPZ As _Unsigned _Byte)
    CX = Int(X / 16)
    CZ = Int(Z / 16)
    CPX = Int(X) - CX * 16
    CPY = Int(Y)
    CPZ = Int(Z) - CZ * 16
End Sub
