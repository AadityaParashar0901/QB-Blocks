$Console
'$Dynamic
$Resize:On

Type Vec2_Float: As Single X, Y: End Type
Type Vec2_Int: As Integer X, Y: End Type
Type Vec3_Float: As Single X, Y, Z: End Type
Type Vec3_Int: As Integer X, Y, Z: End Type

Type BlockPropertiesType
    As String * 16 Name
    As _Unsigned _Byte Model, isTransparent, isFluid
End Type

Type ChunkType
    As Integer X, Z
    As _Unsigned Long Count, TCount, ShowCount, ShowTCount
    As Integer MinimumHeight, MaximumHeight
    As _Byte LoadedChunkData, LoadedRenderData, ShowRenderData
End Type

Screen _NewImage(960, 540, 32)
Color _RGB32(255, 255, 255), _RGB32(0, 127)

Do Until _ScreenExists: Loop
Do While _Resize: Loop

_Title "QB Blocks 4"

Randomize Timer
Const True = -1, False = 0
Const ChunkLoadingSpeed = 1 '1(Min) -> Fastest, 60(Max) -> Slowest
$Let GL = -1

Dim Shared As _Bit FLYMODE, ZOOM, ShowDebugInfo, isPaused
Dim Shared As _Byte FOV, FOG, RenderDistance

Dim Shared GUI_ASSETS&(1 To 21), GUI_ASSETS_ID: GUI_ASSETS_ID = 1
Dim Shared WORLDFOLDER$, WorldFlat As _Unsigned _Byte

'----------------------------------------------------------------
'Things You Can Change to compare performance
Const ChunkHeight = 256
Const GenerationChunkHeight = 256
Const WaterLevel = GenerationChunkHeight / 4
Const NoiseSmoothness = 128
Const Noise3D = 0 '0 OR 1 ONLY

Const PlayerHeight = 1.75
Const PlayerObesity = 0.5
'----------------------------------------------------------------
'DO NOT CHANGE THIS PLEASE
Const FONTWIDTH = 16, FONTHEIGHT = 16
Const ChunkSectionSize = 192 * ChunkHeight
Const ChunkTSectionSize = 256 * ChunkHeight
'----------------------------------------------------------------
Dim Shared TotalChunks As _Unsigned Integer
Const MaxRenderDistance = 16 'Setting to 32 will require you to have > 13.5 GiB Memory
'Formula for Memory Consumption: total_memory = ((2 * MaxRenderDistance + 1) ^ 2) * 30 * 112 KiB
'You can decrease the ChunkHeight to increase this
Const MAXCHUNKS = (2 * MaxRenderDistance + 1) ^ 2
'----------------------------------------------------------------
Dim Shared TMPCHUNKDATA(0 To 17, 0 To ChunkHeight + 1, 0 To 17) As _Unsigned _Byte 'To copy one chunk data for loading and saving Chunks
Dim Shared Chunk(1 To MAXCHUNKS) As ChunkType 'To store all Chunk Info
Dim Shared ChunkData(0 To 17, 0 To ChunkHeight + 1, 0 To 17, 1 To MAXCHUNKS) As _Unsigned _Byte 'All Chunk Data -> Stores the block ID at the position
Dim Shared As Integer ChunkLoadTime, MaxChunkLoadTime, ChunkLoadTimeHistory(1 To 80) 'To calculate chunk loading lag
Dim Shared As _Unsigned Long LoadedChunks
Dim Shared CubeVertices(23) As Vec3_Int, CubeTexCoords(23) As Vec2_Float
Restore CUBEMODEL
For I = 0 To 23
    Read CubeVertices(I).X, CubeVertices(I).Y, CubeVertices(I).Z, CubeTexCoords(I).X, CubeTexCoords(I).Y
Next I
'----------------------------------------------------------------
CUBEMODEL:
'$Include:'assets\models\cube'
'----------------------------------------------------------------
MAXVERTICES = MAXCHUNKS * ChunkSectionSize
MAXTVERTICES = MAXCHUNKS * ChunkTSectionSize
Dim Shared ChunkDataSize As _Unsigned Long: ChunkDataSize = Len(TMPCHUNKDATA()) 'To Clear Old ChunkData
Dim Shared Vertices(1 To MAXVERTICES) As Vec3_Int, TexCoords(1 To MAXVERTICES) As Vec2_Float
Dim Shared TVertices(1 To MAXTVERTICES) As Vec3_Int, TTexCoords(1 To MAXTVERTICES) As Vec2_Float

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
Dim Shared SELECTED_BLOCK As Long: SELECTED_BLOCK = 1
Dim Shared LINEDESIGNINTEGER As _Unsigned Integer: LINEDESIGNINTEGER = 1 'Graph Border
'----------------------------------------------------------------
'$Include:'LoadAssets.bas'
If _DirExists("saves") = 0 Then MkDir "saves"
'----------------------------------------------------------------
'Default Settings
Settings True
If FOV = 0 Then FOV = 70
If RenderDistance = 0 Then RenderDistance = 8
If FOG = 0 Then FOG = 1
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
Dim Shared perm(0 To 65536 * 7 - 1) As Single

If _DirExists("saves/" + WORLDFOLDER$) = 0 Then MkDir "saves/" + WORLDFOLDER$
If _DirExists("saves/" + WORLDFOLDER$ + "/chunks") = 0 Then MkDir "saves/" + WORLDFOLDER$ + "/chunks"
If Len(WorldSeed$) Then SeedRatio = Val(WorldSeed$) / 65536 Else SeedRatio = Rnd
LoadPlayerData
SavePlayerData
Seed = SeedRatio * 65536
RePERM Seed
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
            T = LoadChunkFile(X, Z)
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
LoadChunkX = Int(Camera.X / 16) 'Spiral Chunk Loading Variables
LoadChunkZ = Int(Camera.Z / 16)
LoadChunkDirection = 1
LoadChunkLength = 1
'----------------------------------------------------------------

isPaused = 0
_MouseHide
Do
    _Limit 60
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

    If (LFPSCount Mod (ChunkLoadingSpeed * (1 + Noise3D))) = 0 Then 'Cause 3D Noise is slower to generate
        If Int(Camera.X / 16) <> ChunkX Or Int(Camera.Z / 16) <> ChunkZ Then 'Reset the Spiral Variables
            LoadChunkLength = 0
            LoadChunkDirection = 1
            LoadChunkX = 0
            LoadChunkZ = 0
            InitialLoadChunkX = 0
            InitialLoadChunkZ = 0
        End If
        UnLoadChunks
        '----------------------------------------------------------------
        'Load Chunks
        ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
        For I = 0 To 63 'Check for 63 continous spiral tile chunks to Load
            ChunkLoadingStartTime = Timer(0.001)
            CL = 0 'if Chunk is loaded
            EXITFOR = 0
            If InRange(-RenderDistance, LoadChunkX, RenderDistance) And InRange(-RenderDistance, LoadChunkZ, RenderDistance) Then CL = LoadChunkFile(ChunkX + LoadChunkX, ChunkZ + LoadChunkZ)
            If CL Then
                EXITFOR = -1
                ChunkLoadTime = Int(1000 * (Timer(0.001) - ChunkLoadingStartTime))
                'Add to History for graph
                For J = 1 To UBound(ChunkLoadTimeHistory) - 1
                    Swap ChunkLoadTimeHistory(J), ChunkLoadTimeHistory(J + 1)
                Next J
                ChunkLoadTimeHistory(UBound(ChunkLoadTimeHistory)) = ChunkLoadTime
                MaxChunkLoadTime = Max(MaxChunkLoadTime, ChunkLoadTime)
            End If
            E = 0: Select Case LoadChunkDirection
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
        '----------------------------------------------------------------
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
    'Player Camera Angle
    MW = 0: While _MouseInput
        CameraAngle.X = CameraAngle.X + _MouseMovementX / 8
        CameraAngle.Y = CameraAngle.Y - _MouseMovementY / 8
        CameraAngle.Y = Clamp(-90, CameraAngle.Y, 90)
        CameraAngle.X = ClampCycle(-180, CameraAngle.X, 180)
        CameraAngleSine.X = Sin(_D2R(CameraAngle.X)): CameraAngleSine.Y = Sin(_D2R(CameraAngle.Y))
        CameraAngleCoSine.X = Cos(_D2R(CameraAngle.X)): CameraAngleCoSine.Y = Cos(_D2R(CameraAngle.Y))
        MW = Sgn(MW + _MouseWheel)
        _MouseMove _Width / 2, _Height / 2
    Wend

    'Player Block Selection
    '$Include:'SelectBlock.bas'
    '----------------------------------------------------------------
    'Player Movement
    '$Include:'Movement.bas'
    '----------------------------------------------------------------
Loop
System

FPSCounter:
If GFPSCount Then GFPS = GFPSCount
GFPSCount = 0
If LFPSCount Then LFPS = LFPSCount
LFPSCount = 0
Return

'----------------------------------------------------------------
'Game Tick
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
'----------------------------------------------------------------

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
        Dim As _Byte CX, CZ, CPX, CPY, CPZ
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
        _glEnableClientState _GL_VERTEX_ARRAY
        _glEnableClientState _GL_TEXTURE_COORD_ARRAY
        For I = LBound(Chunk) - 1 To MAXCHUNKS - 1 'Display Opaque Blocks in Chunks
            If Chunk(I + 1).ShowRenderData = 0 Or Chunk(I + 1).ShowCount = 0 Then _Continue
            _glTranslatef Chunk(I + 1).X * 16, 0, Chunk(I + 1).Z * 16
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(I * ChunkSectionSize + 1))
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TexCoords(I * ChunkSectionSize + 1))
            _glDrawArrays _GL_QUADS, 0, Chunk(I + 1).ShowCount
            _glTranslatef -Chunk(I + 1).X * 16, 0, -Chunk(I + 1).Z * 16
        Next I
        For I = LBound(Chunk) - 1 To MAXCHUNKS - 1 'Display Translucent Blocks in Chunks
            If Chunk(I + 1).ShowRenderData = 0 Or Chunk(I + 1).ShowTCount = 0 Then _Continue
            _glTranslatef Chunk(I + 1).X * 16, 0, Chunk(I + 1).Z * 16
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(TVertices(I * ChunkSectionSize + 1))
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TTexCoords(I * ChunkSectionSize + 1))
            _glDrawArrays _GL_QUADS, 0, Chunk(I + 1).ShowTCount
            _glTranslatef -Chunk(I + 1).X * 16, 0, -Chunk(I + 1).Z * 16
        Next I
        If FOG > 0 Then _glDisable _GL_FOG
        _glDisableClientState _GL_VERTEX_ARRAY
        _glDisableClientState _GL_TEXTURE_COORD_ARRAY
        '----------------------------------------------------------------
        'Draw Clouds
        _glTranslatef Camera.X, 0, Camera.Z
        _glBindTexture _GL_TEXTURE_2D, CloudTextureHandle
        X = 0: Y = ChunkHeight * 0.8: Z = Time / 20: S = ChunkHeight * 64
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
            _PutImage (_Width / 2 - TEXTURESIZE, _Height - TEXTURESIZE * 2)-(_Width / 2 + TEXTURESIZE, _Height - 1), Texture, , (0, (SELECTED_BLOCK * 6 - 5) * TEXTURESIZE)-(TEXTURESIZE - 1, (SELECTED_BLOCK * 6 - 4) * TEXTURESIZE - 1)
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
    Print "FPS(G/L):"; GFPS; "/"; LFPS;: Print "Seed:"; Seed;: Print "Time:"; GameTime$
    If ShowDebugInfo Then
        Print Using "Player Position: ####.## ####.## ####.##"; Camera.X; Camera.Y; Camera.Z
        Print Using "Player Angle: ####.## ###.##"; CameraAngle.X; CameraAngle.Y
        Print "Chunks Loaded:"; LoadedChunks
        ChunkRelativeCameraPosition Camera, CX, CZ, CPX, CPY, CPZ
        Print Using "Chunk Relative Position: #### #### ### #### ###"; CX; CZ, CPX; CPY; CPZ
        Print "Selected Block:"; Int(RayBlockPos.X); Int(RayBlockPos.Y); Int(RayBlockPos.Z)
        Print "Chunk Load Time:"; ChunkLoadTime; ", Max Chunk Load Time:"; MaxChunkLoadTime
        Line (_Width - 329, 7)-(_Width - 7, 73), _RGB32(255), B , LINEDESIGNINTEGER
        Line (_Width - 328, 8)-(_Width - 8, 72), _RGB32(0, 127), BF
        Line (_Width - 328, 72 - 1024 / MaxChunkLoadTime)-(_Width - 8, 72 - 1024 / MaxChunkLoadTime), _RGB32(255)
        For I = 1 To UBound(ChunkLoadTimeHistory) - 1
            Line (_Width - 328 + I * 4, 72 - 64 * ChunkLoadTimeHistory(I) / MaxChunkLoadTime)-(_Width - 324 + I * 4, 72 - 64 * ChunkLoadTimeHistory(I + 1) / MaxChunkLoadTime), _RGB32(255)
        Next I
    End If
End Sub

'----------------------------------------------------------------
'Noise Functions
'$Include:'noise.bas'
Function new_fractal2 (CX, CZ, S, O, M)
    new_fractal2 = Abs(1.1 * fractal2(CX, CZ, S, O, M) - 0.1) * 0.9 + 0.1
End Function
'----------------------------------------------------------------
Sub UnLoadChunks
    Static CurrentOffset As _Unsigned Integer
    ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
    For I = 0 To 63 'Check for Chunks to UnLoad
        CurrentOffset = ClampCycle(LBound(Chunk), CurrentOffset + 1, UBound(Chunk))
        If Chunk(CurrentOffset).LoadedChunkData = 0 Then _Continue
        If InRange(-RenderDistance, Chunk(CurrentOffset).X - ChunkX, RenderDistance) = 0 Or InRange(-RenderDistance, Chunk(CurrentOffset).Z - ChunkZ, RenderDistance) = 0 Then
            Chunk(CurrentOffset).X = 0
            Chunk(CurrentOffset).Z = 0
            Chunk(CurrentOffset).Count = 0
            Chunk(CurrentOffset).TCount = 0
            Chunk(CurrentOffset).ShowCount = 0
            Chunk(CurrentOffset).ShowTCount = 0
            Chunk(CurrentOffset).LoadedChunkData = 0
            Chunk(CurrentOffset).LoadedRenderData = 0
            LoadedChunks = LoadedChunks - 1
        End If
    Next I
End Sub
Function ChunkLoader (FoundI, CX As Long, CZ As Long)
    Dim As Integer H, X, Y, Z, A, TreeHeight, XX, ZZ
    Dim As _Unsigned _Byte canPlaceBlock
    Dim As Long PX, PZ
    If FoundI = 0 Then Exit Function
    Chunk(FoundI).X = CX
    Chunk(FoundI).Z = CZ
    WipeChunk FoundI
    Chunk(FoundI).MinimumHeight = ChunkHeight
    Chunk(FoundI).MaximumHeight = WaterLevel
    If WorldFlat = 0 Then
        For X = -3 To 20: For Z = -3 To 20
                PX = CX * 16
                PZ = CZ * 16
                H = getHeight(PX + X, PZ + Z)
                Biome = getBiome(PX + X, PZ + Z)
                Select Case Biome
                    Case 1: BIOME_SURFACE_BLOCK = BLOCK_STONE
                        BIOME_UNDERGROUND_BLOCK = BLOCK_STONE
                    Case 2: BIOME_SURFACE_BLOCK = BLOCK_SAND
                        BIOME_UNDERGROUND_BLOCK = BLOCK_SANDSTONE
                    Case 3: BIOME_SURFACE_BLOCK = BLOCK_DIRT
                        BIOME_UNDERGROUND_BLOCK = BLOCK_DIRT
                    Case 4: BIOME_SURFACE_BLOCK = BLOCK_GRASS
                        BIOME_UNDERGROUND_BLOCK = BLOCK_DIRT
                    Case 5: BIOME_SURFACE_BLOCK = BLOCK_SNOW
                        BIOME_UNDERGROUND_BLOCK = BLOCK_DIRT
                End Select
                canPlaceBlock = InRange(0, X, 17) And InRange(0, Z, 17)
                If canPlaceBlock Then
                    Chunk(FoundI).MinimumHeight = IIF(Noise3D, 1, Min(Chunk(FoundI).MinimumHeight, H - 1))
                    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, H)
                    ChunkData(X, 1, Z, FoundI) = BLOCK_STONE
                    For Y = 2 To Max(H, WaterLevel) - 1
                        UNDERWATER = H < WaterLevel And Y >= H
                        If Noise3D Then
                            If fractal3(PX + X, Y, PZ + Z, NoiseSmoothness, 0, 1) > 0.1 Then ChunkData(X, Y, Z, FoundI) = IIF(Y < Max(H, WaterLevel) - 2, BLOCK_STONE, IIF(UNDERWATER, BLOCK_WATER, BIOME_UNDERGROUND_BLOCK))
                        Else
                            ChunkData(X, Y, Z, FoundI) = IIF(Y < Max(H, WaterLevel) - 2, BLOCK_STONE, IIF(UNDERWATER, BLOCK_WATER, BIOME_UNDERGROUND_BLOCK)) 'IIF(H < WaterLevel And Y < H, IIF(Y < Max(H, WaterLevel) - 2, BLOCK_STONE, BLOCK_DIRT), BLOCK_WATER)
                        End If
                    Next Y
                    If Noise3D Then
                        If fractal3(PX + X, Y, PZ + Z, NoiseSmoothness, 0, 1) > 0.1 Then ChunkData(X, Y, Z, FoundI) = IIF(H > WaterLevel, BIOME_SURFACE_BLOCK, BLOCK_WATER)
                    Else
                        ChunkData(X, Y, Z, FoundI) = IIF(H > WaterLevel, BIOME_SURFACE_BLOCK, BLOCK_WATER)
                    End If
                    If ChunkData(X, Y, Z, FoundI) = BLOCK_AIR Then _Continue 'No Flying Tree
                End If
                '----------------------------------------------------------------
                If Biome < 4 Then _Continue
                If H <= WaterLevel Then _Continue
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
    ChunkLoader = -1
End Function
Function ChunkReloader (FoundI, CX, CZ)
    If FoundI = 0 Then Exit Function
    Chunk(FoundI).LoadedRenderData = -1
    Dim As _Unsigned Long LV, LTV
    Dim As Long PX, PZ
    Dim As _Unsigned Integer X, Y, Z
    Dim As _Unsigned _Byte Block, Visibility, Light
    LV = (FoundI - 1) * ChunkSectionSize
    LTV = (FoundI - 1) * ChunkSectionSize
    Chunk(FoundI).MinimumHeight = Max(1, Chunk(FoundI).MinimumHeight)
    PX = CX * 16
    PZ = CZ * 16
    For X = 1 To 16
        For Z = 1 To 16
            For Y = Chunk(FoundI).MinimumHeight To Chunk(FoundI).MaximumHeight
                Block = ChunkData(X, Y, Z, FoundI)
                If Block = BLOCK_AIR Then _Continue
                Visibility = isTransparent(ChunkData(X + 1, Y, Z, FoundI)) + 2 * isTransparent(ChunkData(X - 1, Y, Z, FoundI)) + 4 * isTransparent(ChunkData(X, Y + 1, Z, FoundI)) + 8 * isTransparent(ChunkData(X, Y - 1, Z, FoundI)) + 16 * isTransparent(ChunkData(X, Y, Z + 1, FoundI)) + 32 * isTransparent(ChunkData(X, Y, Z - 1, FoundI))
                If ChunkData(X, Y + 1, Z, FoundI) = BLOCK_WATER Then
                    If Block = BLOCK_WATER Then
                        Visibility = 0
                    Else
                        If Visibility = 0 Then Visibility = 63
                    End If
                End If
                Light = 0
                For YY = Y + 1 To Chunk(FoundI).MaximumHeight
                    If ChunkData(X, YY, Z, FoundI) Then Light = 5: Exit For
                Next YY
                If isTransparent(Block) Then
                    For I = 0 To 23
                        FACE%% = _SHL(1, _SHR(I, 2))
                        If (FACE%% And Visibility) = 0 Then _Continue
                        If Block = BLOCK_WATER Then If FACE%% <> 4 Then _Continue
                        LTV = LTV + 1
                        TVertices(LTV).X = CubeVertices(I).X + X
                        TVertices(LTV).Y = CubeVertices(I).Y + Y
                        TVertices(LTV).Z = CubeVertices(I).Z + Z
                        TTexCoords(LTV).X = (CubeTexCoords(I).X + Light * Sgn(FACE%% And 4) + 4 * Sgn(FACE%% And 48) + 6 * Sgn(FACE%% And 3) + 8 * Sgn(FACE%% And 8)) / 20
                        TTexCoords(LTV).Y = (CubeTexCoords(I).Y + _SHR(I, 2) + 6 * Block - 6) / IMAGEHEIGHT
                        Chunk(FoundI).TCount = Chunk(FoundI).TCount + 1
                    Next I
                Else
                    For I = 0 To 23
                        FACE%% = _SHL(1, _SHR(I, 2))
                        If (FACE%% And Visibility) = 0 Then _Continue
                        LV = LV + 1
                        Vertices(LV).X = CubeVertices(I).X + X
                        Vertices(LV).Y = CubeVertices(I).Y + Y
                        Vertices(LV).Z = CubeVertices(I).Z + Z
                        TexCoords(LV).X = (CubeTexCoords(I).X + Light * Sgn(FACE%% And 4) + 4 * Sgn(FACE%% And 48) + 6 * Sgn(FACE%% And 3) + 8 * Sgn(FACE%% And 8)) / 20
                        TexCoords(LV).Y = (CubeTexCoords(I).Y + _SHR(I, 2) + 6 * Block - 6) / IMAGEHEIGHT
                        Chunk(FoundI).Count = Chunk(FoundI).Count + 1
                    Next I
                End If
    Next Y, Z, X
    Chunk(FoundI).ShowCount = Chunk(FoundI).Count
    Chunk(FoundI).ShowTCount = Chunk(FoundI).TCount
    Chunk(FoundI).ShowRenderData = -1
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
    __CX = Int((__Camera.X - 1) / 16)
    __CZ = Int((__Camera.Z - 1) / 16)
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
