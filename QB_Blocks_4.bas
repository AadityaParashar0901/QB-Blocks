$Console
'$Dynamic
$Resize:On

Type Vec2_Float: As Single X, Y: End Type
Type Vec2_Int: As Integer X, Y: End Type
Type Vec3_Byte: As _Byte X, Y, Z: End Type
Type Vec3_Float: As Single X, Y, Z: End Type
Type Vec3_Int: As Integer X, Y, Z: End Type

Type ChunkType
    As Integer X, Z
    As _Unsigned Long Count, TCount, ShowCount, ShowTCount
    As Integer MinimumHeight, MaximumHeight
    As _Byte LoadedChunkData, LoadedRenderData, ShowRenderData, LevelOfDetail
End Type

Screen _NewImage(960, 540, 32)
Color _RGB32(255, 255, 255), _RGB32(0, 127)

Do Until _ScreenExists: Loop
Do While _Resize: Loop

_Title "QB Blocks 4"

Randomize Timer
Const True = -1, False = 0
$Let GL = -1

Dim Shared As _Bit FLYMODE, ZOOM, ShowDebugInfo, isPaused
Dim Shared As _Byte FOV, FOG, RenderDistance, LevelOfDetailChunkMultiplier

Dim Shared GUI_ASSETS&(1 To 21), GUI_ASSETS_ID: GUI_ASSETS_ID = 1
Dim Shared WORLDFOLDER$, WorldFlat As _Unsigned _Byte

'----------------------------------------------------------------
'Things You Can Change to compare performance
Const ChunkLoadingSpeed = 1 '1(Min) -> Fastest, 60(Max) -> Slowest
Const ChunkHeight = 256
Const GenerationChunkHeight = 256
Const WaterLevel = GenerationChunkHeight \ 3
Const NoiseSmoothness = 64
Const NoiseComplexity = 3 '0 ~ 7 Only, Higher Values will slow down Chunk Loading
Const MaxLevelOfDetail = 0 '0 ~ 4 Only, Any other value will generate an error

'Terrain Settings
Const SpawnTrees = 1

Const PlayerHeight = 1.75
Const PlayerObesity = 0.5
'----------------------------------------------------------------
'DO NOT CHANGE THIS PLEASE
Const FONTWIDTH = 16, FONTHEIGHT = 16
Const ChunkSectionSize = 32 * ChunkHeight
Const ChunkTSectionSize = 32 * ChunkHeight
'----------------------------------------------------------------
Dim Shared TotalChunks As _Unsigned Integer
Const MaxRenderDistance = 16 'Setting to 64 will require you to have roughly > 4 GiB Memory
'Formula for Memory Consumption: total_memory = ((2 * MaxRenderDistance + 1) ^ 2) * 314.47 KiB
'You can decrease the ChunkHeight to increase this
Const MAXCHUNKS = (2 * MaxRenderDistance + 1) ^ 2
'----------------------------------------------------------------
Dim Shared TMPCHUNKDATA(0 To 17, 0 To ChunkHeight + 1, 0 To 17) As _Unsigned _Byte 'To copy one chunk data for loading and saving Chunks
Dim Shared Chunk(1 To MAXCHUNKS) As ChunkType 'To store all Chunk Info
Dim Shared ChunkData(0 To 17, 0 To ChunkHeight + 1, 0 To 17, 1 To MAXCHUNKS) As _Unsigned _Byte 'All Chunk Data -> Stores the block ID at the position
Dim Shared ChunkLight(0 To 17, 0 To ChunkHeight + 1, 0 To 17, 1 To MAXCHUNKS) As _Unsigned _Bit * 4 'Light

Dim Shared As Integer ChunkLoadTime, ChunkLoadHeight, MaxChunkLoadTime, MaxChunkLoadHeight, ChunkLoadTimeHistory(1 To 80), ChunkLoadHeightHistory(1 To 80) 'To calculate chunk loading lag
Const TimeHistoryColor = &HFF00FF00
Const HeightHistoryColor = &HFF0000FF

Dim Shared As _Unsigned Long LoadedChunks, VisibleChunks, QuadsVisible, TQuadsVisible
Dim Shared As _Unsigned _Byte LoadedChunksMap(-MaxRenderDistance To MaxRenderDistance, -MaxRenderDistance To MaxRenderDistance)
'----------------------------------------------------------------
Dim Shared CubeVertices(23) As Vec3_Int, CubeTexCoords(23) As Vec2_Float
Restore CUBEMODEL
For I = 0 To 23
    Read CubeVertices(I).X, CubeVertices(I).Y, CubeVertices(I).Z, CubeTexCoords(I).X, CubeTexCoords(I).Y
Next I
CUBEMODEL:
'$Include:'assets\models\cube'
'----------------------------------------------------------------
MAXVERTICES = MAXCHUNKS * ChunkSectionSize
MAXTVERTICES = MAXCHUNKS * ChunkTSectionSize
Dim Shared ChunkDataSize As _Unsigned Long: ChunkDataSize = Len(TMPCHUNKDATA()) 'To Clear Old ChunkData
Dim Shared Vertices(1 To MAXVERTICES) As Vec3_Int, TexCoords(1 To MAXVERTICES) As Vec2_Float
Dim Shared TVertices(1 To MAXTVERTICES) As Vec3_Int, TTexCoords(1 To MAXTVERTICES) As Vec2_Float
Dim Shared VertexColors(1 To MAXVERTICES) As Vec3_Byte, TVertexColors(1 To MAXVERTICES) As Vec3_Byte

Dim Shared As Vec2_Float CameraDirection
Dim Shared Camera As Vec3_Float, CameraAngle As Vec2_Float, PlayerVelocity As Vec3_Float, BlockOnCamera As _Unsigned _Byte
Dim Shared RayPos As Vec3_Float, RayDir As Vec3_Float, RayBlockPos As Vec3_Int, RayPreviousBlockPos As Vec3_Int, BlockSelected As _Unsigned _Byte
Dim Shared As Vec2_Float CameraAngleSine, CameraAngleCoSine

CameraAngleSine.X = Sin(_D2R(CameraAngle.X)): CameraAngleSine.Y = Sin(_D2R(CameraAngle.Y))
CameraAngleCoSine.X = Cos(_D2R(CameraAngle.X)): CameraAngleCoSine.Y = Cos(_D2R(CameraAngle.Y))
'----------------------------------------------------------------
'Game Mechanics
Const Gravity = -20
Dim Shared Time As Long, SkyColor As Long: Time = 7200 'Sunrise
Dim As Long PSkyColor, NSkyColor
Dim Shared As Single SkyColorRed, SkyColorGreen, SkyColorBlue
Dim Shared COMMANDMODE As _Byte, __COMMAND$, SELECTED_BLOCK As Long: SELECTED_BLOCK = 1
Dim Shared LINEDESIGNINTEGER As _Unsigned Integer: LINEDESIGNINTEGER = 1 'Graph Border
'----------------------------------------------------------------
'$Include:'LoadAssets.bas'
If _DirExists("saves") = 0 Then MkDir "saves"
'----------------------------------------------------------------
'Default Settings
FOV = 70
RenderDistance = 8
FOG = 1
LevelOfDetailChunkMultiplier = 3
Settings True
Settings False
RenderDistance = Min(RenderDistance, MaxRenderDistance)
'----------------------------------------------------------------
If _CommandCount >= 2 Then
    WORLDFOLDER$ = Command$(1)
    WorldSeed$ = Command$(2)
    WorldFlat = Val(Command$(3))
Else
    WorldSeed$ = TS$(Int(Rnd * 65536))
    WORLDFOLDER$ = WorldSeed$
End If

Dim Shared SeedRatio As Single, Seed As _Unsigned Integer
Dim Shared perm2(0 To 255, 0 To 255, 0 To 7) As Single
Dim Shared perm3(0 To 15, 0 To 15, 0 To 15, 0 To 7) As Single

If _DirExists("saves/" + WORLDFOLDER$) = 0 Then MkDir "saves/" + WORLDFOLDER$
If _DirExists("saves/" + WORLDFOLDER$ + "/chunks") = 0 Then MkDir "saves/" + WORLDFOLDER$ + "/chunks"
If Len(WorldSeed$) Then SeedRatio = Val(WorldSeed$) / 65536 Else SeedRatio = Rnd
LoadPlayerData
SavePlayerData
Seed = SeedRatio * 65536
RePERM Seed
'Calculate Fade Function Lookup Table
Dim Shared fade!(0 To 255)
For I = 0 To 255
    T! = I / 256
    fade!(I) = T! * T! * (3 - 2 * T!)
Next I
'----------------------------------------------------------------
'Initialize Variables, Timers
Dim Shared As _Unsigned Integer LFPS, GFPS, LFPSCount, GFPSCount: LFPS = 60
FPSCounterTimer = _FreeTimer
On Timer(FPSCounterTimer, 1) GoSub FPSCounter
GameTickTimer = _FreeTimer
On Timer(GameTickTimer, 1 / 20) GoSub GameTick
Timer(GameTickTimer) On
'----------------------------------------------------------------
'Show Loading Screen
Cls
_GLRender _Behind
_Title "QB Blocks 4 - " + WORLDFOLDER$
isPaused = -1 'To stop showing Info in _GL
allowGL = -1 'To Show the Chunks while they are loading
PrintString (_Width - FONTWIDTH * Len(T$)) / 2, (_Height - FONTHEIGHT) / 2, "Loading World"
ReDim Shared Chunk(1 To MAXCHUNKS) As ChunkType: LoadedChunks = 0
ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
T$ = "Generating Chunks": TotalChunks = (2 * Min(4, RenderDistance) + 1) ^ 2
For R = 0 To Min(4, RenderDistance): For X = ChunkX - R To ChunkX + R: For Z = ChunkZ - R To ChunkZ + R
            If X > ChunkX - R And X < ChunkX + R And Z > ChunkZ - R And Z < ChunkZ + R Then _Continue
            T = LoadChunkFile(X, Z, 0)
            If _Resize Then
                Screen _NewImage(_ResizeWidth, _ResizeHeight, 32)
                Color _RGB32(255, 255, 255), _RGB32(0, 127)
            End If
            Cls 1, 0
            Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
            PrintString (_Width - FONTWIDTH * Len(T$)) / 2, (_Height - FONTHEIGHT) / 2, T$
            Line (_Width / 2 - 128, (_Height + FONTHEIGHT) / 2)-(_Width / 2 + 128, (_Height + FONTHEIGHT) / 2 + 4), _RGB32(0, 32), BF
            Line (_Width / 2 - 128, (_Height + FONTHEIGHT) / 2)-(_Width / 2 - 128 + 256 * LoadedChunks / TotalChunks, (_Height + FONTHEIGHT) / 2 + 4), _RGB32(0, 127, 255), BF
            _Display
Next Z, X: Next R
TotalChunks = (2 * RenderDistance + 1) ^ 2
'----------------------------------------------------------------
Timer(FPSCounterTimer) On
'----------------------------------------------------------------

isPaused = 0
_MouseHide
Do
    _Limit 60
    On Error GoTo ErrHandler
    LFPSCount = LFPSCount + 1
    If _WindowHasFocus = 0 Or isPaused = -1 Then
        _MouseShow: isPaused = -1
        Timer(GameTickTimer) Off
    Else
        _MouseHide
        Timer(GameTickTimer) On
    End If

    If _Resize Then
        Screen _NewImage(_ResizeWidth, _ResizeHeight, 32)
        Color _RGB32(255, 255, 255), _RGB32(0, 127)
    End If

    If (LFPSCount Mod ChunkLoadingSpeed) = 0 Then
        UnLoadChunks
        LoadChunks
    End If

    If isPaused Then 'Pause Menu
        Cls 0, 0
        While _MouseInput: Wend
        If _KeyDown(27) Then
            While _KeyDown(27): Wend
            isPaused = 0
        End If
        ShowInfoData
        Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
        If Button(1, _Width / 2, _Height * 0.4, "Back to Game") Then isPaused = 0
        If Button(1, _Width / 2, _Height / 2, "Settings") Then Settings_Dialog
        If Button(1, _Width / 2, _Height * 0.6, "Save & Exit") Then
            Timer(FPSCounterTimer) Free
            Timer(GameTickTimer) Free
            SavePlayerData
            System
        End If
        SavePlayerData
        _Display
        _Continue
    End If
    '----------------------------------------------------------------
    If COMMANDMODE = 0 Then
        'Player Camera Angle
        MW = 0: While _MouseInput
            CameraAngle.X = CameraAngle.X + _MouseMovementX / 8
            CameraAngle.Y = CameraAngle.Y - _MouseMovementY / 8
            CameraAngle.Y = Clamp(-90, CameraAngle.Y, 90)
            CameraAngle.X = ClampCycle(-180, CameraAngle.X, 180)
            CameraAngleSine.X = Sin(_D2R(CameraAngle.X)): CameraAngleSine.Y = Sin(_D2R(CameraAngle.Y))
            CameraAngleCoSine.X = Cos(_D2R(CameraAngle.X)): CameraAngleCoSine.Y = Cos(_D2R(CameraAngle.Y))
            CameraDirection.X = CameraAngleSine.X * CameraAngleCoSine.Y
            CameraDirection.Y = -CameraAngleCoSine.X * CameraAngleCoSine.Y
            MW = Sgn(MW + _MouseWheel)
            _MouseMove _Width / 2, _Height / 2
        Wend

        'Player Block Selection
        '$Include:'SelectBlock.bas'
        '----------------------------------------------------------------
        'Player Movement
        '$Include:'Movement.bas'
        '----------------------------------------------------------------
    Else
        K$ = InKey$
        If Len(K$) Then
            Select Case Asc(K$)
                Case 8: __COMMAND$ = Left$(__COMMAND$, Len(__COMMAND$) - 1)
                Case 13: If Len(__COMMAND$) Then COMMANDMODE = 0: COMMAND_PARSE __COMMAND$
                Case Else
                    __COMMAND$ = __COMMAND$ + K$
            End Select
        End If
    End If
Loop
System

'FPS Counter
FPSCounter:
If GFPSCount Then GFPS = GFPSCount
GFPSCount = 0
If LFPSCount Then LFPS = LFPSCount
LFPSCount = 0
Return

ErrHandler:
_Echo "[Error" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
Resume Next

GLErrHandler:
_Echo "[GL Error" + Str$(Err) + ":" + _ErrorMessage$ + " on line" + Str$(_ErrorLine) + "]"
Resume Next

'----------------------------------------------------------------
'Game Tick
'$Include:'GameTick.bas'
'----------------------------------------------------------------

'$Include:'Tokenizer.bas'
Sub COMMAND_PARSE (C$)
    TokenList$ = Tokenizer$(_Trim$(LCase$(C$)))
    _Echo ListStringPrint(TokenList$)
    Select Case ListStringGet(TokenList$, 1)
        Case "tp": If ListStringGet(TokenList$, 2) <> "~" Then Camera.X = Val(ListStringGet(TokenList$, 2))
            If ListStringGet(TokenList$, 3) <> "~" Then Camera.Y = Val(ListStringGet(TokenList$, 3))
            If ListStringGet(TokenList$, 4) <> "~" Then Camera.Z = Val(ListStringGet(TokenList$, 4))
        Case "rd": RenderDistance = Val(ListStringGet(TokenList$, 2))
            RenderDistance = IIF(RenderDistance, Min(MaxRenderDistance, RenderDistance), Min(8, MaxRenderDistance))
        Case "fov": FOV = Val(ListStringGet(TokenList$, 2))
    End Select
End Sub

Sub PlayerMove (Angle As Single, Speed As Single)
    Static As Single dX, dZ
    dX = Cos(_D2R(Angle)) * Speed
    dZ = Sin(_D2R(Angle)) * Speed
    If FLYMODE Then
        Camera.X = Camera.X + dX
        Camera.Z = Camera.Z + dZ
    Else
        Camera.X = Camera.X + dX * (isNotBlock(BlockExists(Camera.X + Sgn(dX) * Player_Obesity, Camera.Y, Camera.Z)) And isNotBlock(BlockExists(Camera.X + Sgn(dX) * Player_Obesity, Camera.Y - 1, Camera.Z)))
        Camera.Z = Camera.Z + dZ * (isNotBlock(BlockExists(Camera.X, Camera.Y, Camera.Z + Sgn(dZ) * Player_Obesity)) And isNotBlock(BlockExists(Camera.X, Camera.Y - 1, Camera.Z + Sgn(dZ) * Player_Obesity)))
    End If
End Sub

$If GL Then
    Sub _GL
        Dim As _Unsigned Long ChunksVisible, __QuadsVisible
        Shared allowGL, __GL_Generate_Texture, __GL_Generate_Sun_Texture, __GL_Generate_Chunks
        Static As Long TextureHandle, SunTextureHandle, MoonTextureHandle, CloudTextureHandle
        If __GL_Generate_Texture Then
            Generate_GL_Textures Texture, TextureHandle
            Generate_GL_Textures SunTexture, SunTextureHandle
            Generate_GL_Textures MoonTexture, MoonTextureHandle
            Generate_GL_Textures CloudTexture, CloudTextureHandle
            __GL_Generate_Texture = 0
        End If

        If allowGL = 0 Then Exit Sub

        On Error GoTo GLErrHandler
        _glViewport 0, 0, _Width - 1, _Height - 1
        _glEnable _GL_BLEND
        _glDisable _GL_MULTISAMPLE
        _glEnable _GL_DEPTH_TEST
        _glClearColor SkyColorRed, SkyColorGreen, SkyColorBlue, 0
        _glClear _GL_DEPTH_BUFFER_BIT Or _GL_COLOR_BUFFER_BIT
        _glTranslatef 0, 0, -0.25
        _glRotatef -CameraAngle.Y, 1, 0, 0
        _glRotatef CameraAngle.X, 0, 1, 0
        _glTranslatef 0, -Camera.Y, 0
        _glMatrixMode _GL_PROJECTION
        _glLoadIdentity
        _gluPerspective FOV + ZOOM * (FOV - 30), _Width / _Height, 0.1, Max(256, ChunkHeight * 8)
        _glMatrixMode _GL_MODELVIEW
        _glEnable _GL_TEXTURE_2D
        '----------------------------------------------------------------
        'Draw Sun and Moon
        _glBindTexture _GL_TEXTURE_2D, SunTextureHandle
        X = 0: Y = ChunkHeight * 4.5: Z = 0: S = ChunkHeight * 8
        _glRotatef Time / 80 - 180, 1, 0, 0
        _glBegin _GL_QUADS: For I = 8 To 11
            _glVertex3f X + (CubeVertices(I).X - 0.5) * S, Y + (CubeVertices(I).Y - 0.5), Z + (CubeVertices(I).Z - 0.5) * S
            _glTexCoord2f CubeTexCoords(I).X, CubeTexCoords(I).Y
        Next I: _glEnd
        _glBindTexture _GL_TEXTURE_2D, MoonTextureHandle
        X = 0: Y = ChunkHeight * 4.5: Z = 0: S = ChunkHeight * 4
        _glRotatef 180, 1, 0, 0
        _glBegin _GL_QUADS: For I = 8 To 11
            _glVertex3f X + (CubeVertices(I).X - 0.5) * S, Y + (CubeVertices(I).Y - 0.5), Z + (CubeVertices(I).Z - 0.5) * S
            _glTexCoord2f CubeTexCoords(I).X, CubeTexCoords(I).Y
        Next I: _glEnd
        _glRotatef -Time / 80, 1, 0, 0
        '----------------------------------------------------------------
        _glTranslatef -Camera.X, 0, -Camera.Z
        _glBindTexture _GL_TEXTURE_2D, TextureHandle
        If FOG > 0 Then
            _glEnable _GL_FOG
            _glFogi _GL_FOG_MODE, _GL_LINEAR
            _glFogf _GL_FOG_END, 16 * (RenderDistance - 1)
            If BlockOnCamera = BLOCK_WATER Then
                _glFogf _GL_FOG_START, 8
                _glFogfv _GL_FOG_COLOR, glVec4(0.25, 0.12, 1, 0.5)
                _glFogf _GL_FOG_DENSITY, 0.1
            Else
                _glFogf _GL_FOG_START, 8 * (RenderDistance - 1)
                _glFogfv _GL_FOG_COLOR, glVec4(SkyColorRed, SkyColorGreen, SkyColorBlue, 1)
                _glFogf _GL_FOG_DENSITY, 0.1
            End If
        End If
        '----------------------------------------------------------------
        _glCullFace _GL_TRUE
        _glEnableClientState _GL_VERTEX_ARRAY
        _glEnableClientState _GL_TEXTURE_COORD_ARRAY
        _glEnableClientState _GL_COLOR_ARRAY
        ChunksVisible = 0
        J = LBound(Chunk) - 2: For I = LBound(Chunk) To MAXCHUNKS 'Display Opaque Blocks in Chunks
            J = J + 1: If Chunk(I).ShowRenderData = 0 Or Chunk(I).ShowCount = 0 Then _Continue
            _glPushMatrix
            _glTranslatef Chunk(I).X * 16, 0, Chunk(I).Z * 16
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(J * ChunkSectionSize + 1))
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TexCoords(J * ChunkSectionSize + 1))
            _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(VertexColors(J * ChunkSectionSize + 1))
            _glDrawArrays _GL_QUADS, 0, Chunk(I).ShowCount
            _glPopMatrix
            __QuadsVisible = __QuadsVisible + Chunk(I).ShowCount
            ChunksVisible = ChunksVisible + 1
        Next I
        VisibleChunks = ChunksVisible
        J = LBound(Chunk) - 2: For I = LBound(Chunk) To MAXCHUNKS 'Display Translucent Blocks in Chunks
            J = J + 1: If Chunk(I).ShowRenderData = 0 Or Chunk(I).ShowTCount = 0 Then _Continue
            _glPushMatrix
            _glTranslatef Chunk(I).X * 16, 0, Chunk(I).Z * 16
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(TVertices(J * ChunkSectionSize + 1))
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TTexCoords(J * ChunkSectionSize + 1))
            _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(TVertexColors(J * ChunkSectionSize + 1))
            _glDrawArrays _GL_QUADS, 0, Chunk(I).ShowTCount
            __TQuadsVisible = __TQuadsVisible + Chunk(I).ShowTCount
            _glPopMatrix
        Next I
        QuadsVisible = __QuadsVisible
        TQuadsVisible = __TQuadsVisible
        If FOG > 0 Then _glDisable _GL_FOG
        _glDisableClientState _GL_VERTEX_ARRAY
        _glDisableClientState _GL_TEXTURE_COORD_ARRAY
        _glDisableClientState _GL_COLOR_ARRAY
        _glCullFace _GL_FALSE
        '----------------------------------------------------------------
        'Draw Clouds
        _glTranslatef Camera.X, 0, Camera.Z
        _glBindTexture _GL_TEXTURE_2D, CloudTextureHandle
        X = 0: Y = ChunkHeight * 1.2: Z = Time / 20: S = ChunkHeight * 256
        _glBegin _GL_QUADS: For I = 8 To 11
            _glVertex3f X + (CubeVertices(I).X - 0.5) * S, Y + (CubeVertices(I).Y - 0.5), Z + (CubeVertices(I).Z - 0.5) * S
            _glTexCoord2f CubeTexCoords(I).X, CubeTexCoords(I).Y
        Next I: _glEnd
        '----------------------------------------------------------------
        _glDisable _GL_TEXTURE_2D
        If BlockSelected Then DrawOutlineBox
        _glDisable _GL_DEPTH_TEST
        _glDisable _GL_BLEND
        _glFlush
        '----------------------------------------------------------------
        If isPaused = 0 Then
            Cls , 0
            ShowInfoData
            _PutImage (_Width / 2, _Height / 2), Cross&
            _PutImage (_Width / 2 - TEXTURESIZE, _Height - TEXTURESIZE * 2)-(_Width / 2 + TEXTURESIZE, _Height - 1), Texture, , (0, BlockFaces(SELECTED_BLOCK, 3) * TEXTURESIZE)-(TEXTURESIZE - 1, (BlockFaces(SELECTED_BLOCK, 3) + 1) * TEXTURESIZE - 1)
            If COMMANDMODE Then
                Line (0, _Height - 16)-(_Width, _Height - 1), &H7F000000, BF
                _PrintString (0, _Height - 16), __COMMAND$ + "_"
            End If
            _Display
        End If
        GFPSCount = GFPSCount + 1
    End Sub

    Sub DrawOutlineBox
        _glTranslatef -Camera.X, 0, -Camera.Z
        _glBegin _GL_LINES
        For I = 0 To 23
            _glVertex3f RayBlockPos.X + CubeVertices(I).X, RayBlockPos.Y + CubeVertices(I).Y, RayBlockPos.Z + CubeVertices(I).Z
        Next I
        _glEnd
    End Sub

    Sub Generate_GL_Textures (__T As Long, __TH As Long)
        Static M As _MEM
        _glGenTextures 1, _Offset(__TH)
        _glBindTexture _GL_TEXTURE_2D, __TH
        M = _MemImage(__T)
        _glTexImage2D _GL_TEXTURE_2D, 0, _GL_RGBA, _Width(__T), _Height(__T), 0, _GL_BGRA_EXT, _GL_UNSIGNED_BYTE, M.OFFSET
        _MemFree M
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MIN_FILTER, _GL_LINEAR
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MAG_FILTER, _GL_NEAREST
    End Sub

    Function glVec4%& (X!, Y!, Z!, W!) Static
        If firstRun` = 0 Then
            Dim VEC4(3) As Single
            firstRun` = -1
        End If
        VEC4(0) = X!: VEC4(1) = Y!: VEC4(2) = Z!: VEC4(3) = W!
    glVec4%& = _Offset(VEC4()): End Function
$End If

Sub ShowInfoData
    Dim As _Byte CX, CZ, CPX, CPY, CPZ
    Print "FPS(G/L):"; GFPS; "/"; LFPS;: Print "Seed:"; Seed;: Print "Time:"; GameTime$
    If ShowDebugInfo Then
        Print Using "Player Position: ####.## ####.## ####.##"; Camera.X; Camera.Y; Camera.Z
        Print Using "Player Angle: ####.## ###.##"; CameraAngle.X; CameraAngle.Y
        Print "Chunks L/V:"; LoadedChunks; VisibleChunks
        Print "Quads:"; QuadsVisible; TQuadsVisible
        ChunkRelativeCameraPosition Camera, CX, CZ, CPX, CPY, CPZ
        Print Using "Chunk Relative Position: #### #### ### #### ###"; CX; CZ, CPX; CPY; CPZ
        Print "Selected Block:"; Int(RayBlockPos.X); Int(RayBlockPos.Y); Int(RayBlockPos.Z)
        $Checking:Off
        __X = _Width - 328
        Line (__X - 1, 7)-(_Width - 7, 73), -1, B , LINEDESIGNINTEGER
        Line (__X, 8)-(_Width - 8, 72), &H3F000000, BF
        Line (__X, 72 - 1024 / MaxChunkLoadTime)-(_Width - 8, 72 - 1024 / MaxChunkLoadTime), TimeHistoryColor And &HAFFFFFFF
        Line (__X, 72 - 1024 / MaxChunkLoadHeight)-(_Width - 8, 72 - 1024 / MaxChunkLoadHeight), HeightHistoryColor And &HAFFFFFFF
        Color TimeHistoryColor, 0: _PrintString (__X, 8), "T:" + _Trim$(Str$(MaxChunkLoadTime))
        Color HeightHistoryColor: _PrintString (__X, 24), "C:" + _Trim$(Str$(MaxChunkLoadHeight))
        Color -1, &H7F000000
        For I = 1 To UBound(ChunkLoadTimeHistory) - 1
            __X = __X + 4
            Line (__X, 72 - 64 * ChunkLoadTimeHistory(I) / MaxChunkLoadTime)-(__X + 4, 72 - 64 * ChunkLoadTimeHistory(I + 1) / MaxChunkLoadTime), TimeHistoryColor And &HAFFFFFFF
            Line (__X, 72 - 64 * ChunkLoadHeightHistory(I) / MaxChunkLoadHeight)-(__X + 4, 72 - 64 * ChunkLoadHeightHistory(I + 1) / MaxChunkLoadHeight), HeightHistoryColor And &HAFFFFFFF
        Next I
        oX = _Width - MaxRenderDistance - 32
        oY = 74 + MaxRenderDistance
        tP1X = -MaxRenderDistance: tP1Y = -MaxRenderDistance
        tP2X = MaxRenderDistance: tP2Y = -MaxRenderDistance
        tP3X = MaxRenderDistance: tP3Y = MaxRenderDistance
        tP4X = -MaxRenderDistance: tP4Y = MaxRenderDistance
        P1X = -tP1X * CameraAngleCoSine.X - tP1Y * CameraAngleSine.X
        P1Y = tP1X * CameraAngleSine.X - tP1Y * CameraAngleCoSine.X
        P2X = -tP2X * CameraAngleCoSine.X - tP2Y * CameraAngleSine.X
        P2Y = tP2X * CameraAngleSine.X - tP2Y * CameraAngleCoSine.X
        P3X = -tP3X * CameraAngleCoSine.X - tP3Y * CameraAngleSine.X
        P3Y = tP3X * CameraAngleSine.X - tP3Y * CameraAngleCoSine.X
        P4X = -tP4X * CameraAngleCoSine.X - tP4Y * CameraAngleSine.X
        P4Y = tP4X * CameraAngleSine.X - tP4Y * CameraAngleCoSine.X
        Line (oX - P1X, oY - P1Y)-(oX - P2X, oY - P2Y), _RGB32(0)
        Line (oX - P2X, oY - P2Y)-(oX - P3X, oY - P3Y), _RGB32(0)
        Line (oX - P3X, oY - P3Y)-(oX - P4X, oY - P4Y), _RGB32(0)
        Line (oX - P4X, oY - P4Y)-(oX - P1X, oY - P1Y), _RGB32(0)
        For X = -RenderDistance To RenderDistance: For Z = -RenderDistance To RenderDistance
                tX = -X * CameraAngleCoSine.X - Z * CameraAngleSine.X
                tZ = X * CameraAngleSine.X - Z * CameraAngleCoSine.X
                Select Case LoadedChunksMap(X, Z)
                    Case 0: PSet (oX - tX, oY - tZ), _RGB32(127)
                    Case 1: PSet (oX - tX, oY - tZ), _RGB32(0)
                    Case 2: PSet (oX - tX, oY - tZ), _RGB32(255, 0, 0)
                    Case 3: PSet (oX - tX, oY - tZ), _RGB32(0, 255, 0)
                    Case 4: PSet (oX - tX, oY - tZ), _RGB32(255, 255, 0)
                    Case 5: PSet (oX - tX, oY - tZ), _RGB32(0, 0, 255)
                    Case 6: PSet (oX - tX, oY - tZ), _RGB32(255, 0, 255)
                    Case 7: PSet (oX - tX, oY - tZ), _RGB32(0, 255, 255)
                End Select
        Next Z, X
        $Checking:On
    End If
End Sub
'----------------------------------------------------------------

'Noise Functions
'$Include:'noise.bas'
'----------------------------------------------------------------

Sub LoadChunks
    Static As Integer LoadChunkX, LoadChunkZ
    Dim As _Unsigned _Byte ChunkToLoad
    Static As Integer ChunkX, ChunkZ, Chunk1X, Chunk2X, Chunk1Z, Chunk2Z
    Static As Integer ChunkIndex
    Dim As _Unsigned _Byte LOD
    ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
    Chunk1X = ChunkX - RenderDistance
    Chunk2X = ChunkX + RenderDistance
    Chunk1Z = ChunkZ - RenderDistance
    Chunk2Z = ChunkZ + RenderDistance
    ReDim __LoadedChunks(Chunk1X To Chunk2X, Chunk1Z To Chunk2Z) As _Unsigned Long
    $Checking:Off
    For I = 1 To MAXCHUNKS
        If (Chunk1X <= Chunk(I).X) And (Chunk(I).X <= Chunk2X) And (Chunk1Z <= Chunk(I).Z) And (Chunk(I).Z <= Chunk2Z) Then
            __T~%% = (Chunk(I).LoadedChunkData <> 0 And Chunk(I).LoadedRenderData <> 0) And (Chunk(I).LevelOfDetail + 1)
            __LoadedChunks(Chunk(I).X, Chunk(I).Z) = (__T~%% And __LoadedChunks(Chunk(I).X, Chunk(I).Z) = 0) Or __LoadedChunks(Chunk(I).X, Chunk(I).Z)
            ChunkToLoad = (__T~%% = 0) Or ChunkToLoad
        End If
    Next I
    $Checking:On
    'If ChunkToLoad = 0 Then Exit Sub
    ChunkToLoad = 0
    $Checking:Off
    For R = 0 To RenderDistance
        __C1X = ChunkX - R
        __C2X = ChunkX + R
        __C1Z = ChunkZ - R
        __C2Z = ChunkZ + R
        For X = __C1X To __C2X
            For Z = __C1Z To __C2Z
                If __C1X < X And X < __C2X And __C1Z < Z And Z < __C2Z Then _Continue
                If __LoadedChunks(X, Z) = 0 And ChunkToLoad = 0 Then
                    ChunkToLoad = 1
                    LoadChunkX = X
                    LoadChunkZ = Z
                End If
                LoadedChunksMap(X - ChunkX, Z - ChunkZ) = __LoadedChunks(X, Z)
            Next Z
        Next X
    Next R
    $Checking:On
    If ChunkToLoad = 0 Then Exit Sub
    ChunkLoadingStartTime = Timer(0.001)
    LOD = Min(MaxLevelOfDetail, _SHR(Max(Abs(LoadChunkX - ChunkX), Abs(LoadChunkZ - ChunkZ)), LevelOfDetailChunkMultiplier))
    ChunkIndex = LoadChunkFile(LoadChunkX, LoadChunkZ, LOD)
    If ChunkIndex Then
        $Checking:Off
        ChunkLoadTime = Int(1000 * (Timer(0.001) - ChunkLoadingStartTime))
        ChunkLoadHeight = Chunk(ChunkIndex).MaximumHeight - Chunk(ChunkIndex).MinimumHeight
        'Add to History for graph
        ChunkLoadTimeHistory(1) = ChunkLoadTime
        ChunkLoadHeightHistory(1) = ChunkLoadHeight
        For J = 1 To UBound(ChunkLoadTimeHistory) - 1
            Swap ChunkLoadTimeHistory(J), ChunkLoadTimeHistory(J + 1)
            Swap ChunkLoadHeightHistory(J), ChunkLoadHeightHistory(J + 1)
        Next J
        MaxChunkLoadTime = Max(MaxChunkLoadTime, ChunkLoadTime)
        MaxChunkLoadHeight = Max(MaxChunkLoadHeight, ChunkLoadHeight)
        $Checking:On
    End If
End Sub

Sub UnLoadChunks
    Static CurrentOffset As _Unsigned Integer
    ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
    For I = 0 To 63 'Check for 63 Chunks to UnLoad in 1 call to reduce lag
        CurrentOffset = ClampCycle(LBound(Chunk), CurrentOffset + 1, UBound(Chunk))
        If Chunk(CurrentOffset).LoadedChunkData = 0 Then _Continue
        If InRange(-RenderDistance, Chunk(CurrentOffset).X - ChunkX, RenderDistance) = 0 Or InRange(-RenderDistance, Chunk(CurrentOffset).Z - ChunkZ, RenderDistance) = 0 Then
            $Checking:Off
            Chunk(CurrentOffset).X = 0
            Chunk(CurrentOffset).Z = 0
            Chunk(CurrentOffset).Count = 0
            Chunk(CurrentOffset).TCount = 0
            Chunk(CurrentOffset).ShowCount = 0
            Chunk(CurrentOffset).ShowTCount = 0
            Chunk(CurrentOffset).LoadedChunkData = 0
            Chunk(CurrentOffset).LoadedRenderData = 0
            Chunk(CurrentOffset).LevelOfDetail = 0
            LoadedChunks = LoadedChunks - 1
            $Checking:On
        End If
    Next I
End Sub
Function ChunkLoader (FoundI, CX As Long, CZ As Long, LOD As _Unsigned _Byte)
    Dim As Integer H, X, Y, Z, A, TreeHeight, XX, ZZ
    Dim As _Unsigned _Byte canPlaceBlock, __STEP
    Dim As Long PX, PZ
    If FoundI = 0 Then Exit Function
    $Checking:Off
    Chunk(FoundI).X = CX
    Chunk(FoundI).Z = CZ
    PX = CX * 16
    PZ = CZ * 16
    WipeChunk FoundI
    Chunk(FoundI).MinimumHeight = ChunkHeight
    Chunk(FoundI).MaximumHeight = WaterLevel
    __STEP = _SHL(1, LOD)
    If WorldFlat = 0 Then
        For X = -3 To 20: For Z = -3 To 20
                'H = 250 - 0.125 * Sqr((PX + X) * (PX + X) + (PZ + Z) * (PZ + Z))
                H = getHeight(PX + X, PZ + Z)
                canPlaceBlock = InRange(0, X, 17) And InRange(0, Z, 17)
                If canPlaceBlock Then
                    Chunk(FoundI).MinimumHeight = Min(Chunk(FoundI).MinimumHeight, H - 1)
                    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, H)
                    ChunkData(X, 1, Z, FoundI) = BLOCK_STONE
                    For Y = 2 To Max(H, WaterLevel) - 1
                        UNDERWATER = H < WaterLevel And Y >= H
                        ChunkData(X, Y, Z, FoundI) = IIF(Y < H - 4 And H - 4 > WaterLevel, BLOCK_STONE, IIF(UNDERWATER, BLOCK_WATER, BLOCK_DIRT)) 'IIF(H < WaterLevel And Y < H, IIF(Y < Max(H, WaterLevel) - 2, BLOCK_STONE, BLOCK_DIRT), BLOCK_WATER)
                    Next Y
                    ChunkData(X, Y, Z, FoundI) = IIF(H > WaterLevel, BLOCK_GRASS, BLOCK_WATER)
                    If ChunkData(X, Y, Z, FoundI) = BLOCK_AIR Then _Continue 'No Flying Tree
                End If
                '----------------------------------------------------------------
                If SpawnTrees = 0 Or H <= WaterLevel Or LOD Then _Continue
                If Int(1000 * fractal2(PX + X, PZ + Z, 7, 0, 1)) <> 800 Then _Continue
                TreeHeight = 2 + Int(5 * fractal2(PX + X, PZ + Z, NoiseSmoothness / 4, 0, 2))
                If canPlaceBlock Then
                    For Y = H To H + TreeHeight
                        ChunkData(X, Y, Z, FoundI) = BLOCK_OAK_LOG
                    Next Y
                End If
                A = 4
                For Y = H + TreeHeight To H + TreeHeight + 4
                    A = A - 1
                    For XX = X - A To X + A: For ZZ = Z - A To Z + A
                            If InRange(0, XX, 17) And InRange(0, ZZ, 17) Then
                                ChunkData(XX, Y, ZZ, FoundI) = BLOCK_OAK_LEAVES
                                Chunk(FoundI).MinimumHeight = Min(Chunk(FoundI).MinimumHeight, Y)
                                Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, Y)
                            End If
                    Next ZZ, XX
                Next Y
        Next Z, X
    Else
        Chunk(FoundI).MinimumHeight = 1
        Chunk(FoundI).MaximumHeight = GenerationChunkHeight / 2
        For X = 0 To 17: For Z = 0 To 17
                For Y = 0 To GenerationChunkHeight / 2 - 1
                    ChunkData(X, Y, Z, FoundI) = BLOCK_DIRT
                Next Y
                ChunkData(X, Y, Z, FoundI) = BLOCK_GRASS
                ChunkData(X, 1, Z, FoundI) = BLOCK_STONE
        Next Z, X
    End If
    Chunk(FoundI).LoadedChunkData = -1
    Chunk(FoundI).LevelOfDetail = LOD
    $Checking:On
    ChunkLoader = -1
End Function
Function AmbientOcclusion~%% (X As _Byte, Y As Integer, Z As _Byte, vertexIndex As _Byte, FoundI As _Unsigned Integer, CurrentLight As _Unsigned _Byte) Static
    $Checking:Off
    Dim As _Byte dX, dY, dZ
    Dim As _Byte side1, side2, corner
    Dim As _Byte total
    dX = _SHL(CubeVertices(vertexIndex).X, 1) - 1
    dY = _SHL(CubeVertices(vertexIndex).Y, 1) - 1
    dZ = _SHL(CubeVertices(vertexIndex).Z, 1) - 1
    corner = Sgn(ChunkData(X + dX, Y + dY, Z + dZ, FoundI))
    side1 = Sgn(ChunkData(X + dX, Y + dY, Z, FoundI))
    side2 = Sgn(ChunkData(X, Y + dY, Z + dZ, FoundI))
    total = side1 + side2 + corner + CurrentLight
    total = total + (total - 15) * (total > 15)
    $Checking:On
    AmbientOcclusion = 255 - 17 * total
End Function
Function ChunkReloader (FoundI, CX, CZ, LOD As _Unsigned _Byte) Static
    If FoundI = 0 Then Exit Function
    Dim As _Unsigned Long LV, LTV, I
    Dim As Long PX, PZ
    Dim As _Unsigned Integer X, Y, Z
    Dim As _Unsigned _Byte Block, Visibility, Light, __STEP
    $Checking:Off
    Chunk(FoundI).LoadedRenderData = -1
    LV = (FoundI - 1) * ChunkSectionSize
    LTV = (FoundI - 1) * ChunkSectionSize
    Chunk(FoundI).MinimumHeight = Max(1, Chunk(FoundI).MinimumHeight)
    PX = _SHL(CX, 4)
    PZ = _SHL(CZ, 4)
    __STEP = _SHL(1, LOD)

    'Calculate Lighting
    For X = 0 To 17: For Z = 0 To 17
            __TOGGLE` = 0
            For Y = Chunk(FoundI).MaximumHeight + 1 To Chunk(FoundI).MinimumHeight Step -1
                __TOGGLE` = ChunkData(X, Y, Z, FoundI) Or __TOGGLE`
                ChunkLight(X, Y, Z, FoundI) = 15 And (__TOGGLE` = 0) 'Brightest
            Next Y
    Next Z, X
    For I = 15 To 1 Step -1
        For X = 1 To 16: For Z = 1 To 16
                For Y = Chunk(FoundI).MaximumHeight To Chunk(FoundI).MinimumHeight Step -1
                    If ChunkLight(X, Y, Z, FoundI) Or ChunkData(X, Y, Z, FoundI) Then _Continue
                    If ChunkLight(X + 1, Y, Z, FoundI) = I Or ChunkLight(X - 1, Y, Z, FoundI) = I Or ChunkLight(X, Y + 1, Z, FoundI) = I Or ChunkLight(X, Y - 1, Z, FoundI) = I Or ChunkLight(X, Y, Z + 1, FoundI) = I Or ChunkLight(X, Y, Z - 1, FoundI) = I Then
                        ChunkLight(X, Y, Z, FoundI) = I - 1
                    End If
                Next Y
        Next Z, X
    Next I
    '------------------
    For X = 1 To 16 Step __STEP
        For Z = 1 To 16 Step __STEP
            For Y = Chunk(FoundI).MaximumHeight To Chunk(FoundI).MinimumHeight Step -1
                Block = ChunkData(X, Y, Z, FoundI)
                If Block = BLOCK_AIR Then _Continue
                Select Case LOD
                    Case 0: Visibility = isTransparent(ChunkData(X + 1, Y, Z, FoundI))
                        Visibility = Visibility Or _SHL(isTransparent(ChunkData(X - 1, Y, Z, FoundI)), 1)
                        Visibility = Visibility Or _SHL(isTransparent(ChunkData(X, Y + 1, Z, FoundI)), 2)
                        Visibility = Visibility Or _SHL(isTransparent(ChunkData(X, Y - 1, Z, FoundI)), 3)
                        Visibility = Visibility Or _SHL(isTransparent(ChunkData(X, Y, Z + 1, FoundI)), 4)
                        Visibility = Visibility Or _SHL(isTransparent(ChunkData(X, Y, Z - 1, FoundI)), 5)
                    Case Else: Visibility = 0
                        For XX = X To X + __STEP - 1
                            For ZZ = Z To Z + __STEP - 1
                                Visibility = Visibility Or isTransparent(ChunkData(XX + 1, Y, ZZ, FoundI))
                                Visibility = Visibility Or _SHL(isTransparent(ChunkData(XX - 1, Y, ZZ, FoundI)), 1)
                                Visibility = Visibility Or _SHL(isTransparent(ChunkData(XX, Y + 1, ZZ, FoundI)), 2)
                                Visibility = Visibility Or _SHL(isTransparent(ChunkData(XX, Y - 1, ZZ, FoundI)), 3)
                                Visibility = Visibility Or _SHL(isTransparent(ChunkData(XX, Y, ZZ + 1, FoundI)), 4)
                                Visibility = Visibility Or _SHL(isTransparent(ChunkData(XX, Y, ZZ - 1, FoundI)), 5)
                        Next ZZ, XX
                End Select
                If ChunkData(X, Y + 1, Z, FoundI) = BLOCK_WATER Then
                    If Block = BLOCK_WATER Then
                        Visibility = 0
                    Else
                        If Visibility = 0 Then Visibility = 63
                    End If
                End If

                If isTransparent(Block) Then
                    For I = 0 To 23
                        FACE%% = _SHL(1, _SHR(I, 2))
                        If (FACE%% And Visibility) = 0 Or BlockFaces(Block, _SHR(I, 2) + 1) = -1 Then _Continue
                        Select Case _SHR(I, 2)
                            Case 0: Light = ChunkLight(X + 1, Y, Z, FoundI) - 6
                            Case 1: Light = ChunkLight(X - 1, Y, Z, FoundI) - 6
                            Case 2: Light = ChunkLight(X, Y + 1, Z, FoundI)
                            Case 3: Light = ChunkLight(X, Y - 1, Z, FoundI) - 8
                            Case 4: Light = ChunkLight(X, Y, Z + 1, FoundI) - 4
                            Case 5: Light = ChunkLight(X, Y, Z - 1, FoundI) - 4
                        End Select
                        Light = 15 - (Light - Light * (Light < 0))
                        LTV = LTV + 1
                        TVertices(LTV).X = CubeVertices(I).X * __STEP + X
                        TVertices(LTV).Y = CubeVertices(I).Y + Y
                        TVertices(LTV).Z = CubeVertices(I).Z * __STEP + Z
                        TTexCoords(LTV).X = CubeTexCoords(I).X
                        TTexCoords(LTV).Y = (CubeTexCoords(I).Y + BlockFaces(Block, _SHR(I, 2) + 1)) / TOTALTEXTURES
                        TVertexColors(LTV).X = AmbientOcclusion(X, Y, Z, I, FoundI, Light)
                        TVertexColors(LTV).Y = TVertexColors(LTV).X
                        TVertexColors(LTV).Z = TVertexColors(LTV).X
                        Chunk(FoundI).TCount = Chunk(FoundI).TCount + 1
                    Next I
                Else
                    For I = 0 To 23
                        FACE%% = _SHL(1, _SHR(I, 2))
                        If (FACE%% And Visibility) = 0 Then _Continue
                        Select Case _SHR(I, 2)
                            Case 0: Light = ChunkLight(X + 1, Y, Z, FoundI) - 6
                            Case 1: Light = ChunkLight(X - 1, Y, Z, FoundI) - 6
                            Case 2: Light = ChunkLight(X, Y + 1, Z, FoundI)
                            Case 3: Light = ChunkLight(X, Y - 1, Z, FoundI) - 8
                            Case 4: Light = ChunkLight(X, Y, Z + 1, FoundI) - 4
                            Case 5: Light = ChunkLight(X, Y, Z - 1, FoundI) - 4
                        End Select
                        Light = 15 - (Light - Light * (Light < 0))
                        LV = LV + 1
                        Vertices(LV).X = CubeVertices(I).X * __STEP + X
                        Vertices(LV).Y = CubeVertices(I).Y + Y
                        Vertices(LV).Z = CubeVertices(I).Z * __STEP + Z
                        TexCoords(LV).X = CubeTexCoords(I).X
                        TexCoords(LV).Y = (CubeTexCoords(I).Y + BlockFaces(Block, _SHR(I, 2) + 1)) / TOTALTEXTURES
                        VertexColors(LV).X = AmbientOcclusion(X, Y, Z, I, FoundI, Light)
                        VertexColors(LV).Y = VertexColors(LV).X
                        VertexColors(LV).Z = VertexColors(LV).Y
                        Chunk(FoundI).Count = Chunk(FoundI).Count + 1
                    Next I
                End If
    Next Y, Z, X
    Chunk(FoundI).ShowCount = Chunk(FoundI).Count
    Chunk(FoundI).ShowTCount = Chunk(FoundI).TCount
    Chunk(FoundI).ShowRenderData = -1
    $Checking:On
    ChunkReloader = -1
End Function
'$Include:'terrain.bas'
'$Include:'LoadSaveChunks.bas'
Function LoadImage& (FP$)
    If _FileExists(FP$) Then LoadImage& = _LoadImage(FP$, 32): Exit Function
    If _FileExists(FP$ + ".png") Then LoadImage& = _LoadImage(FP$ + ".png", 32): Exit Function
    If _FileExists(FP$ + ".jpg") Then LoadImage& = _LoadImage(FP$ + ".jpg", 32): Exit Function
    If _FileExists(FP$ + ".jpeg") Then LoadImage& = _LoadImage(FP$ + ".jpeg", 32): Exit Function
    Print "Cannot load "; FP$
End Function
Sub ChunkRelativeCameraPosition (__Camera As Vec3_Float, __CX As _Byte, __CZ As _Byte, __CPX As _Byte, __CPY As _Byte, __CPZ As _Byte)
    __CX = Int(__Camera.X / 16)
    __CZ = Int(__Camera.Z / 16)
    __CPX = Int(__Camera.X - __CX * 16)
    __CPY = Int(__Camera.Y)
    __CPZ = Int(__Camera.Z - __CZ * 16)
End Sub
Function BlockExists (X, Y, Z) Static
    Dim As Integer __CX, __CZ, __CPX, __CPY, __CPZ
    Dim As _Unsigned Integer FoundI: FoundI = 0
    If InRange(1, Y, ChunkHeight) = 0 Then Exit Function
    __CX = Int((X - 1) / 16): __CZ = Int((Z - 1) / 16)
    __CPX = Int(X - __CX * 16): __CPY = Int(Y): __CPZ = Int(Z - __CZ * 16)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = __CX And Chunk(I).Z = __CZ And Chunk(I).LoadedChunkData Then
            FoundI = I
            Exit For
        End If
    Next I
    If FoundI = 0 Then Exit Function
    BlockExists = ChunkData(__CPX, __CPY, __CPZ, FoundI)
End Function
Function isTransparent (B)
    isTransparent = -(B = BLOCK_AIR Or B = BLOCK_WATER)
End Function
Function isBlockFluid (B)
    isBlockFluid = -(B = BLOCK_WATER)
End Function
Function isNotBlock (B)
    isNotBlock = -(B = BLOCK_AIR Or B = BLOCK_WATER)
End Function
'$Include:'Misc.bas'
'$Include:'UI.bas'
Sub PrintString (X As Integer, Y As Integer, S$)
    Dim As _Unsigned Integer A, B, I
    For I = 1 To Len(S$)
        A = Asc(S$, I)
        B = A Mod 16
        A = _SHR(A, 4)
        _PutImage (X + I * FONTWIDTH - FONTWIDTH + 1, Y)-(X + I * FONTWIDTH, Y + FONTHEIGHT - 1), FontImage, , (B * 8, A * 8)-(B * 8 + 7, A * 8 + 7)
    Next I
End Sub
Sub Vec3_FloatToInt (A As Vec3_Float, B As Vec3_Int)
    B.X = Int(A.X)
    B.Y = Int(A.Y)
    B.Z = Int(A.Z)
End Sub
Function Vec2_DotProduct (A As Vec2_Float, B As Vec2_Float)
    Vec2_DotProduct = (A.X * B.X + A.Y * B.Y)
End Function
