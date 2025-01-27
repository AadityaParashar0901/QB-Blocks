$Console
'$Dynamic
$Resize:On

Type Vec2_Float: As Single X, Y: End Type
Type Vec2_Int: As Integer X, Y: End Type
Type Vec3_Byte: As _Byte X, Y, Z: End Type
Type Vec3_Float: As Single X, Y, Z: End Type
Type Vec3_Int: As Integer X, Y, Z: End Type
Type Vec4_Float: As Single X, Y, Z, W: End Type

Type BlockPropertiesType
    As String * 16 Name
    As _Unsigned _Byte Model, isTransparent, isFluid
End Type

Type ChunkType
    As Integer X, Z
    As _Unsigned Long Count, TCount, ShowCount, ShowTCount
    As Integer MinimumHeight, MaximumHeight
    As _Byte LoadedChunkData, LoadedRenderData, ShowRenderData
    As _Offset VerticesOffset, TransparentVerticesOffset
    As _Offset TexCoordsOffset, TransparentTexCoordsOffset
    As _Offset NormalsOffset, TransparentNormalsOffset
End Type

Screen _NewImage(960, 540, 32): _PrintMode _KeepBackground

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
Const GenerationChunkHeight = ChunkHeight
Const WaterLevel = GenerationChunkHeight / 4
Const NoiseSmoothness = 256

Const PlayerHeight = 1.75
Const PlayerObesity = 0.5
'----------------------------------------------------------------
Const FONTWIDTH = 16, FONTHEIGHT = 16
Const ChunkSectionSize = 192 * ChunkHeight
Const ChunkTSectionSize = 256 * ChunkHeight
'----------------------------------------------------------------
Dim Shared TotalChunks As _Unsigned Integer
Const MaxRenderDistance = 16 'Set to 24 if your PC has >= 16GB RAM
Const MAXCHUNKS = (2 * MaxRenderDistance + 1) ^ 2
'----------------------------------------------------------------
Dim Shared TMPCHUNKDATA(0 To 17, 0 To ChunkHeight + 1, 0 To 17) As _Unsigned _Byte
Dim Shared Chunk(1 To MAXCHUNKS) As ChunkType
Dim Shared ChunkData(0 To 17, 0 To ChunkHeight + 1, 0 To 17, 1 To MAXCHUNKS) As _Unsigned _Byte
Dim Shared As Integer ChunkLoadTime, MaxChunkLoadTime
Dim Shared As _Unsigned Long LoadedChunks
Dim Shared CubeVertices(23) As Vec3_Int, CubeTexCoords(23) As Vec2_Float, CubeNormals(23) As Vec3_Byte

Restore CUBEMODEL
For I = 0 To 23
    Read CubeVertices(I).X, CubeVertices(I).Y, CubeVertices(I).Z, CubeTexCoords(I).X, CubeTexCoords(I).Y, CubeNormals(I).X, CubeNormals(I).Y, CubeNormals(I).Z
Next I
'----------------------------------------------------------------
CUBEMODEL:
'$Include:'assets\models\cube'
'----------------------------------------------------------------

MAXVERTICES = MAXCHUNKS * ChunkSectionSize
MAXTVERTICES = MAXCHUNKS * ChunkTSectionSize
Dim Shared ChunkDataSize As _Unsigned Long: ChunkDataSize = Len(TMPCHUNKDATA()) 'To Clear Old ChunkData
Dim Shared Vertices(1 To MAXVERTICES) As Vec3_Float, TexCoords(1 To MAXVERTICES) As Vec2_Float
Dim Shared Normals(1 To MAXVERTICES) As Vec3_Byte

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
Dim Shared SELECTED_BLOCK As Long: SELECTED_BLOCK = 1
'----------------------------------------------------------------
Print "Generating Textures"
Const TOTALTEXTURES = 10
Const BLOCK_AIR = 0
Const BLOCK_GRASS = 1
Const BLOCK_DIRT = 2
Const BLOCK_STONE = 3
Const BLOCK_WATER = 4
Const BLOCK_SAND = 5
Const BLOCK_SANDSTONE = 6
Const BLOCK_SNOW = 7
Const BLOCK_OAK_LOG = 8
Const BLOCK_OAK_LEAVES = 9
Const BLOCK_OAK_PLANKS = 10

Const TEXTURESIZE = 16
Const IMAGEHEIGHT = 6 * TOTALTEXTURES

Dim Shared As Long Texture, SunTexture, MoonTexture, CloudTexture, Cross, FontImage
Texture = _NewImage(TEXTURESIZE * 20, TEXTURESIZE * IMAGEHEIGHT, 32)
FontImage = LoadImage("assets/font/ascii.png")
GUI_ASSETS&(GUI_ASSETS_ID) = _LoadImage("assets/gui/background_loading.png", 32)
_PutImage (0, 0)-(_Width - 1, _Height - 1), GUI_ASSETS&(1)
_Display
Open "assets/gui_assets.list" For Input As #1
Do
    Line Input #1, IMGFILE$
    If IMGFILE$ = "end" Then Exit Do
    GUI_ASSETS_ID = GUI_ASSETS_ID + 1
    GUI_ASSETS&(GUI_ASSETS_ID) = LoadImage("assets/" + _Trim$(IMGFILE$))
Loop
Close #1
Open "assets/assets.list" For Input As #1
I = 0
Do
    Line Input #1, I$
    If Left$(I$, 2) = "//" Then _Continue
    If Left$(I$, 2) = "/*" Then MULTILINECOMMENT = True: _Continue
    If Left$(I$, 2) = "*/" Then MULTILINECOMMENT = False: _Continue
    If MULTILINECOMMENT Then _Continue
    If _Trim$(I$) = "" Then _Continue
    I = I + 1
    If _Trim$(I$) = "/o" Then I$ = L$ Else L$ = I$
    If _Trim$(I$) = "/n" Then
    Else
        IMG& = LoadImage("assets/blocks/" + I$)
        For J = 1 To 20
            _PutImage ((J - 1) * TEXTURESIZE, (I - 1) * TEXTURESIZE)-(J * TEXTURESIZE - 1, I * TEXTURESIZE - 1), IMG&, Texture ', (0, 0)-(TEXTURESIZE - 1, TEXTURESIZE - 1)
        Next J
        _FreeImage IMG&
    End If
    If I >= TOTALTEXTURES * 6 Then Exit Do
Loop
Close #1
Cross = _LoadImage("assets/gui/cross.png", 32)
SunTexture = _LoadImage("assets/environment/sun.png", 32)
MoonTexture = _LoadImage("assets/environment/moon.png", 32)
CloudTexture = _LoadImage("assets/environment/clouds.png", 32)
_Source Texture: _Dest Texture
For I = 1 To 20
    For X = I * TEXTURESIZE To _Width
        For Y = 0 To _Height - 1
            If _Alpha32(Point(X, Y)) = 255 Then PSet (X, Y), _RGBA32(0, 0, 0, 17)
    Next Y, X
Next I
_Source 0: _Dest 0
$If GL Then
    __GL_Generate_Texture = -1: While __GL_Generate_Texture = -1: Wend
$End If

If _DirExists("saves") = 0 Then MkDir "saves"
'----------------------------------------------------------------
'Default Settings
Settings True 'Load Settings if Found
If FOV = 0 Then FOV = 70
If RenderDistance = 0 Then RenderDistance = 8
If FOG = 0 Then FOG = 1
Settings False 'Store Settings
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

Dim Shared Seed As _Unsigned Integer
Dim Shared perm(0 To 65536 * 16 - 1) As Single

If _DirExists("saves/" + WORLDFOLDER$) = 0 Then MkDir "saves/" + WORLDFOLDER$
If _DirExists("saves/" + WORLDFOLDER$ + "/chunks") = 0 Then MkDir "saves/" + WORLDFOLDER$ + "/chunks"
If Len(WorldSeed$) Then Seed = Val(WorldSeed$) / 65536 Else Seed = Rnd * 65536
LoadPlayerData
SavePlayerData
RePERM Seed

'----------------------------------------------------------------
'Show Loading Screen & Load Chunks in an area of MIN ( renderDistance, 4 )
_PutImage (0, 0)-(_Width - 1, _Height - 1), GUI_ASSETS&(2)
PrintString (_Width - FONTWIDTH * Len(T$)) / 2, (_Height - FONTHEIGHT) / 2, "Loading World"
ReDim Shared Chunk(1 To MAXCHUNKS) As ChunkType: LoadedChunks = 0
ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
T$ = "Generating Chunks": TotalChunks = (2 * Min(4, RenderDistance) + 1) ^ 2
For R = 0 To Min(4, RenderDistance): For X = ChunkX - R To ChunkX + R: For Z = ChunkZ - R To ChunkZ + R
            If X > ChunkX - R And X < ChunkX + R And Z > ChunkZ - R And Z < ChunkZ + R Then _Continue
            T = LoadChunkFile(X, Z)
            If _Resize Then Screen _NewImage(_ResizeWidth, _ResizeHeight, 32): _PrintMode _KeepBackground
            _PutImage (0, 0)-(_Width - 1, _Height - 1), GUI_ASSETS&(2)
            PrintString (_Width - FONTWIDTH * Len(T$)) / 2, (_Height - FONTHEIGHT) / 2, T$
            Line (_Width / 2 - 128, (_Height + FONTHEIGHT) / 2)-(_Width / 2 + 128, (_Height + FONTHEIGHT) / 2 + 4), _RGB32(0, 32), BF
            Line (_Width / 2 - 128, (_Height + FONTHEIGHT) / 2)-(_Width / 2 - 128 + 256 * LoadedChunks / TotalChunks, (_Height + FONTHEIGHT) / 2 + 4), _RGB32(0, 127, 255), BF
            _Display
Next Z, X: Next R
TotalChunks = (2 * RenderDistance + 1) ^ 2
'----------------------------------------------------------------

'----------------------------------------------------------------
'Initialize Variables, Timers
Dim Shared As _Unsigned Integer LFPS, GFPS, LFPSCount, GFPSCount: LFPS = 60
FPSCounterTimer = _FreeTimer
On Timer(FPSCounterTimer, 1) GoSub FPSCounter
Timer(FPSCounterTimer) On
GameTickTimer = _FreeTimer
On Timer(GameTickTimer, 1 / 20) GoSub GameTick
Timer(GameTickTimer) On
'    Spiral Variables
LoadChunkX = Int(Camera.X / 16)
LoadChunkZ = Int(Camera.Z / 16)
LoadChunkDirection = 1
LoadChunkLength = 1
'----------------------------------------------------------------

_Title "QB Blocks 4 - " + WORLDFOLDER$
Cls
_MouseHide
_GLRender _Behind
Do
    _Limit 60
    LFPSCount = LFPSCount + 1
    If _WindowHasFocus = 0 Or isPaused = -1 Then
        _MouseShow
        isPaused = -1
        Timer(GameTickTimer) Off
    Else
        _MouseHide
        allowGL = -1
        Timer(GameTickTimer) On
    End If

    If _Resize Then
        Screen _NewImage(_ResizeWidth, _ResizeHeight, 32)
        _PrintMode _KeepBackground
        aspectRatio = _Width / _Height
    End If

    If (LFPSCount Mod ChunkLoadingSpeed) = 0 Then
        If Int(Camera.X / 16) <> ChunkX Or Int(Camera.Z / 16) <> ChunkZ Then 'Reset the Spiral Variables
            LoadChunkLength = 0
            LoadChunkDirection = 1
            LoadChunkX = 0
            LoadChunkZ = 0
            InitialLoadChunkX = 0
            InitialLoadChunkZ = 0
        End If
        ChunkX = Int(Camera.X / 16): ChunkZ = Int(Camera.Z / 16)
        For I = LBound(Chunk) To UBound(Chunk) 'Check for Chunks to UnLoad
            If Chunk(I).LoadedChunkData = 0 Then _Continue
            If InRange(-RenderDistance, Chunk(I).X - ChunkX, RenderDistance) = 0 Or InRange(-RenderDistance, Chunk(I).Z - ChunkZ, RenderDistance) = 0 Then
                Chunk(I).X = 0
                Chunk(I).Z = 0
                Chunk(I).Count = 0
                Chunk(I).TCount = 0
                Chunk(I).ShowCount = 0
                Chunk(I).ShowTCount = 0
                Chunk(I).LoadedChunkData = 0
                Chunk(I).LoadedRenderData = 0
                LoadedChunks = LoadedChunks - 1
                Exit For
            End If
        Next I
        For I = 0 To 63 'Check for 64 continous spiral tile chunks to Load
            ChunkLoadingStartTime = Timer(0.001)
            CL = 0 'if Chunk is loaded
            EXITFOR = 0
            If InRange(-RenderDistance, LoadChunkX, RenderDistance) And InRange(-RenderDistance, LoadChunkZ, RenderDistance) Then CL = LoadChunkFile(ChunkX + LoadChunkX, ChunkZ + LoadChunkZ)
            If CL Then
                EXITFOR = -1
                ChunkLoadTime = Int(1000 * (Timer(0.001) - ChunkLoadingStartTime))
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
    End If

    If isPaused Then 'Pause Menu
        Cls 1, 0
        While _MouseInput: Wend
        If _KeyDown(27) Then
            While _KeyDown(27): Wend
            isPaused = 0
        End If
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

    RayPos = Camera: RayDir.X = CameraAngleSine.X * CameraAngleCoSine.Y: RayDir.Y = CameraAngleSine.Y: RayDir.Z = -CameraAngleCoSine.X * CameraAngleCoSine.Y: BlockSelected = 0
    Vec3_FloatToInt RayPos, RayBlockPos
    For I = 1 To 5
        If InRange(1, RayPos.Y, ChunkHeight) Then
            If isTransparent(BlockExists(RayPos.X, RayPos.Y, RayPos.Z)) = 0 Then BlockSelected = -1: Exit For
        End If
        Vec3_FloatToInt RayPos, RayPreviousBlockPos
        RayPos.X = RayPos.X + RayDir.X
        RayPos.Y = RayPos.Y + RayDir.Y
        RayPos.Z = RayPos.Z + RayDir.Z
    Next I
    Vec3_FloatToInt RayPos, RayBlockPos
    If BlockSelected Then
        If _MouseButton(1) And InRange(1, RayBlockPos.Y, ChunkHeight) And Timer(0.01) - LastMouse1Time > 0.25 Then
            SetBlockReloadChunk RayBlockPos.X, RayBlockPos.Y, RayBlockPos.Z, BLOCK_AIR
            LastMouse1Time = Timer(0.01)
        End If
        If _MouseButton(2) And InRange(1, RayPreviousBlockPos.Y, ChunkHeight) And Timer(0.01) - LastMouse2Time > 0.25 Then If (Abs(Camera.X - RayPreviousBlockPos.X) > PlayerObesity Or Abs(Camera.Z - RayPreviousBlockPos.Z) > PlayerObesity) Or Abs(Camera.Y - RayPreviousBlockPos.Y) > PlayerHeight Then
                SetBlockReloadChunk RayPreviousBlockPos.X, RayPreviousBlockPos.Y, RayPreviousBlockPos.Z, SELECTED_BLOCK
                LastMouse2Time = Timer(0.01)
            End If
        End If
    End If
    SELECTED_BLOCK = Max(1, Min(TOTALTEXTURES, SELECTED_BLOCK + MW + _KeyDown(18432) - _KeyDown(20480) + _KeyDown(19200) - _KeyDown(19712)))
    While _KeyDown(18432) Or _KeyDown(20480) Or _KeyDown(19200) Or _KeyDown(19712): _Limit 30: Wend

    '----------------------------------------------------------------
    'Player Movement
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
    Time = IIF(_KeyDown(84) Or _KeyDown(116), Time + 200, Time)
    If (_KeyDown(70) Or _KeyDown(102)) Then 'F
        While _KeyDown(70) Or _KeyDown(102): _Limit 30: Wend
        FLYMODE = Not FLYMODE
    End If: FLYMODE = IIF(InRange(1, Camera.Y, ChunkHeight) = 0, -1, FLYMODE)
    If _KeyDown(71) Or _KeyDown(103) Then 'G
        While _KeyDown(71) Or _KeyDown(103): _Limit 30: Wend
        FOG = IIF(FOG = 1, -1, 1)
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
Loop
System

FPSCounter:
If GFPSCount Then GFPS = GFPSCount
GFPSCount = 0
If LFPSCount Then LFPS = LFPSCount
LFPSCount = 0
Return

GameTick:
Time = Time + 1
If Time >= 28800 Then Time = 0
HOUR = Time \ 1200
MINUTEPER60 = ((Time \ 20) Mod 60) / 60
PSkyColor = GetSkyColour(HOUR)
NSkyColor = GetSkyColour(HOUR + 1)
SkyColor = _RGB32(interpolate(_Red32(PSkyColor), _Red32(NSkyColor), MINUTEPER60), interpolate(_Green32(PSkyColor), _Green32(NSkyColor), MINUTEPER60), interpolate(_Blue32(PSkyColor), _Blue32(NSkyColor), MINUTEPER60))
SkyColorRed = _Red32(SkyColor)
SkyColorGreen = _Green32(SkyColor)
SkyColorBlue = _Blue32(SkyColor)
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

Sub PlayerMove (Angle As Single, Speed As Single) Static
    Dim As Single dX, dZ
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

        _glClearColor SkyColorRed / 255, SkyColorGreen / 255, SkyColorBlue / 255, 0
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
        _glCullFace _GL_TRUE
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
                _glFogfv _GL_FOG_COLOR, glVec4(SkyColorRed / 255, SkyColorGreen / 255, SkyColorBlue / 255, 1)
                _glFogf _GL_FOG_DENSITY, 0.1
            End If
        End If
        '----------------------------------------------------------------
        _glEnableClientState _GL_VERTEX_ARRAY
        _glEnableClientState _GL_TEXTURE_COORD_ARRAY
        _glEnableClientState _GL_NORMAL_ARRAY
        _glEnable _GL_LIGHTING
        _glEnable _GL_LIGHT0
        SUN_ANGLE! = _D2R(Time / 80 - 180)
        AMBIENT_POWER = IIF(Abs(Cos(SUN_ANGLE!)) > 0.5, Cos(SUN_ANGLE!) ^ 5, 0)
        DIFFUSE_POWER = 4
        SPECULAR_POWER = 5
        _glLightfv _GL_LIGHT0, _GL_AMBIENT, glVec4(AMBIENT_POWER, AMBIENT_POWER * 0.835, AMBIENT_POWER * 0.29, 1)
        _glLightfv _GL_LIGHT0, _GL_DIFFUSE, glVec4(DIFFUSE_POWER, DIFFUSE_POWER * 0.835, DIFFUSE_POWER * 0.29, 1)
        _glLightfv _GL_LIGHT0, _GL_SPECULAR, glVec4(SPECULAR_POWER, SPECULAR_POWER * 0.835, SPECULAR_POWER * 0.29, 1)
        _glLightfv _GL_LIGHT0, _GL_POSITION, glVec4(0, ChunkHeight * 4.5 * Cos(SUN_ANGLE!), ChunkHeight * 4.5 * Sin(SUN_ANGLE!), 1)

        _glEnable _GL_LIGHT1
        _glLightfv _GL_LIGHT1, _GL_AMBIENT, glVec4(1, 1, 1, 1)
        _glLightfv _GL_LIGHT1, _GL_DIFFUSE, glVec4(1, 1, 1, 1)
        _glLightfv _GL_LIGHT1, _GL_SPECULAR, glVec4(1, 1, 1, 1)
        _glLightfv _GL_LIGHT1, _GL_POSITION, glVec4(0, -ChunkHeight * 4.5 * Cos(SUN_ANGLE!), -ChunkHeight * 4.5 * Sin(SUN_ANGLE!), 1)

        _glEnable _GL_LIGHT2
        _glLightfv _GL_LIGHT2, _GL_AMBIENT, glVec4(0.2, 0.2, 0.2, 1)
        _glLightfv _GL_LIGHT2, _GL_DIFFUSE, glVec4(0.8, 0.8, 0.8, 1)
        _glLightfv _GL_LIGHT2, _GL_SPECULAR, glVec4(1, 1, 1, 1)
        _glLightfv _GL_LIGHT2, _GL_POSITION, glVec4(0, ChunkHeight, 0, 1)

        For I = LBound(Chunk) - 1 To MAXCHUNKS - 1
            If Chunk(I + 1).ShowRenderData = 0 Or Chunk(I + 1).ShowCount = 0 Then _Continue
            _glVertexPointer 3, _GL_FLOAT, 0, Chunk(I + 1).VerticesOffset
            _glTexCoordPointer 2, _GL_FLOAT, 0, Chunk(I + 1).TexCoordsOffset
            _glNormalPointer _GL_BYTE, 0, Chunk(I + 1).NormalsOffset
            _glDrawArrays _GL_QUADS, 0, Chunk(I + 1).ShowCount
        Next I
        For I = LBound(Chunk) - 1 To MAXCHUNKS - 1
            If Chunk(I + 1).ShowRenderData = 0 Or Chunk(I + 1).ShowTCount = 0 Then _Continue
            _glVertexPointer 3, _GL_FLOAT, 0, Chunk(I + 1).TransparentVerticesOffset
            _glTexCoordPointer 2, _GL_FLOAT, 0, Chunk(I + 1).TransparentTexCoordsOffset
            _glNormalPointer _GL_BYTE, 0, Chunk(I + 1).TransparentNormalsOffset
            _glDrawArrays _GL_QUADS, 0, Chunk(I + 1).ShowTCount
        Next I
        If BlockSelected Then DrawOutlineBox
        _glDisable _GL_LIGHT2
        _glDisable _GL_LIGHT1
        _glDisable _GL_LIGHT0
        _glDisable _GL_LIGHTING
        _glDisableClientState _GL_VERTEX_ARRAY
        _glDisableClientState _GL_TEXTURE_COORD_ARRAY
        _glDisableClientState _GL_NORMAL_ARRAY
        _glCullFace _GL_FALSE
        '----------------------------------------------------------------
        'Draw Clouds
        _glTranslatef Camera.X, 0, Camera.Z
        _glBindTexture _GL_TEXTURE_2D, CloudTextureHandle
        X = 0: Y = ChunkHeight * 0.8: Z = Time / 40: S = ChunkHeight * 64
        _glBegin _GL_QUADS: For I = 8 To 11
            _glVertex3f X + (CubeVertices(I).X - 0.5) * S, Y + (CubeVertices(I).Y - 0.5), Z + (CubeVertices(I).Z - 0.5) * S
            _glTexCoord2f CubeTexCoords(I).X, CubeTexCoords(I).Y
        Next I: _glEnd
        '----------------------------------------------------------------
        If FOG Then _glDisable _GL_FOG
        _glDisable _GL_TEXTURE_2D
        _glDisable _GL_DEPTH_TEST
        _glDisable _GL_BLEND
        _glFlush
        '----------------------------------------------------------------
        If isPaused = 0 Then 'Info Data
            Cls 2, 0
            Print "FPS(G/L):"; GFPS; "/"; LFPS;: Print "Seed:"; Seed;: Print "Time:"; GameTime$
            If ShowDebugInfo Then
                Print Using "Player Position: ####.## ####.## ####.##"; Camera.X; Camera.Y; Camera.Z
                Print Using "Player Angle: ####.## ###.##"; CameraAngle.X; CameraAngle.Y
                Print "Chunks Loaded:"; LoadedChunks
                ChunkRelativeCameraPosition Camera, CX, CZ, CPX, CPY, CPZ
                Print Using "Chunk Relative Position: #### #### ### #### ###"; CX; CZ, CPX; CPY; CPZ
                Print "Selected Block:"; Int(RayBlockPos.X); Int(RayBlockPos.Y); Int(RayBlockPos.Z)
                Print "Chunk Load Time:"; ChunkLoadTime; ", Max Chunk Load Time:"; MaxChunkLoadTime
            End If
            _PutImage (_Width / 2, _Height / 2), Cross&
            _PutImage (_Width / 2 - TEXTURESIZE, _Height - TEXTURESIZE * 2)-(_Width / 2 + TEXTURESIZE, _Height - 1), Texture, , (0, (SELECTED_BLOCK * 6 - 5) * TEXTURESIZE)-(TEXTURESIZE - 1, (SELECTED_BLOCK * 6 - 4) * TEXTURESIZE - 1)
            _Display
        End If
        GFPSCount = GFPSCount + 1
    End Sub

    Sub DrawOutlineBox
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
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MIN_FILTER, _GL_NEAREST
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

'$Include:'noise.bas'

Function new_fractal2 (CX, CZ, S, O, M)
    new_fractal2 = Abs(1.1 * fractal2(CX, CZ, S, O, M) - 0.1) * 0.9 + 0.1
End Function

Sub WipeChunk (FoundI As _Unsigned Integer)
    Dim M As _MEM
    M = _Mem(_Offset(ChunkData(0, 0, 0, FoundI)), ChunkDataSize)
    _MemFill M, M.OFFSET, M.SIZE, 0 As LONG
    _MemFree M
End Sub

Sub CopyMemory (__S As _Offset, __D As _Offset, __SIZE As _Unsigned Long)
    Dim As _MEM __MS, __MD
    __MS = _Mem(__S, __SIZE)
    __MD = _Mem(__D, __SIZE)
    _MemCopy __MS, __S, __SIZE To __MD, __D
    _MemFree __MS
    _MemFree __MD
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
                H = GenerationChunkHeight * fractal2(PX + X, PZ + Z, NoiseSmoothness, 7, 0)
                canPlaceBlock = InRange(0, X, 17) And InRange(0, Z, 17)
                If canPlaceBlock Then
                    Chunk(FoundI).MinimumHeight = Min(Chunk(FoundI).MinimumHeight, H - 1)
                    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, H)
                    For Y = 1 To Max(H, WaterLevel) - 1
                        ChunkData(X, Y, Z, FoundI) = BLOCK_DIRT
                    Next Y
                    ChunkData(X, Y, Z, FoundI) = IIF(H > WaterLevel, BLOCK_GRASS, BLOCK_WATER)
                End If
                '----------------------------------------------------------------
                If H > WaterLevel And InRange(0.8, fractal2(PX + X, PZ + Z, 2, 7, 1), 0.81) Then
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
                End If
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
    Dim As Vec3_Float TVertices(1 To ChunkTSectionSize), TTexCoords(1 To ChunkTSectionSize)
    Dim As Vec3_Byte TNormals(1 To ChunkTSectionSize)
    LV = (FoundI - 1) * ChunkSectionSize: LTV = 0
    Chunk(FoundI).VerticesOffset = _Offset(Vertices(LV + 1))
    Chunk(FoundI).TexCoordsOffset = _Offset(TexCoords(LV + 1))
    Chunk(FoundI).NormalsOffset = _Offset(Normals(LV + 1))
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
                        TVertices(LTV).X = CubeVertices(I).X + PX + X
                        TVertices(LTV).Y = CubeVertices(I).Y + Y + 0.125 * (Block = BLOCK_WATER)
                        TVertices(LTV).Z = CubeVertices(I).Z + PZ + Z
                        TNormals(LV) = CubeNormals(I)
                        TTexCoords(LTV).X = (CubeTexCoords(I).X + Light * Sgn(FACE%% And 4) + 4 * Sgn(FACE%% And 48) + 6 * Sgn(FACE%% And 3) + 8 * Sgn(FACE%% And 8)) / 20
                        TTexCoords(LTV).Y = (CubeTexCoords(I).Y + _SHR(I, 2) + 6 * Block - 6) / IMAGEHEIGHT
                        Chunk(FoundI).TCount = Chunk(FoundI).TCount + 1
                    Next I
                Else
                    For I = 0 To 23
                        FACE%% = _SHL(1, _SHR(I, 2))
                        If (FACE%% And Visibility) = 0 Then _Continue
                        LV = LV + 1
                        Vertices(LV).X = CubeVertices(I).X + PX + X
                        Vertices(LV).Y = CubeVertices(I).Y + Y
                        Vertices(LV).Z = CubeVertices(I).Z + PZ + Z
                        Normals(LV) = CubeNormals(I)
                        TexCoords(LV).X = (CubeTexCoords(I).X + Light * Sgn(FACE%% And 4) + 4 * Sgn(FACE%% And 48) + 6 * Sgn(FACE%% And 3) + 8 * Sgn(FACE%% And 8)) / 20
                        TexCoords(LV).Y = (CubeTexCoords(I).Y + _SHR(I, 2) + 6 * Block - 6) / IMAGEHEIGHT
                        Chunk(FoundI).Count = Chunk(FoundI).Count + 1
                    Next I
                End If
    Next Y, Z, X
    Chunk(FoundI).ShowCount = Chunk(FoundI).Count
    Chunk(FoundI).ShowTCount = Chunk(FoundI).TCount
    Chunk(FoundI).TransparentVerticesOffset = _Offset(Vertices(LV + 1))
    Chunk(FoundI).TransparentTexCoordsOffset = _Offset(TexCoords(LV + 1))
    Chunk(FoundI).TransparentNormalsOffset = _Offset(Normals(LV + 1))
    CopyMemory _Offset(TVertices()), _Offset(Vertices(LV + 1)), Chunk(FoundI).TCount * 12 'LEN( single ) * 3 as it is Vec3_Float
    CopyMemory _Offset(TTexCoords()), _Offset(TexCoords(LV + 1)), Chunk(FoundI).TCount * 8 'LEN( single ) * 2 as it is Vec2_Float
    CopyMemory _Offset(TNormals()), _Offset(Normals(LV + 1)), Chunk(FoundI).TCount * 3 'LEN( byte ) * 3 as it is Vec3_Byte
    Chunk(FoundI).ShowRenderData = -1
    ChunkReloader = -1
End Function
Sub SetBlockReloadChunk (X As Long, Y As Long, Z As Long, B As _Unsigned _Byte)
    Dim As Integer __CX, __CZ, __CPX, __CPY, __CPZ
    __CX = Int((X - 1) / 16): __CZ = Int((Z - 1) / 16)
    __CPX = Int(X - __CX * 16): __CPY = Int(Y): __CPZ = Int(Z - __CZ * 16)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = __CX And Chunk(I).Z = __CZ And Chunk(I).LoadedChunkData Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Sub
    ChunkData(__CPX, __CPY, __CPZ, FoundI) = B
    If __CPX = 1 Then SetAnotherBlockReloadChunk __CX - 1, __CZ, 17, __CPY, __CPZ, B
    If __CPX = 16 Then SetAnotherBlockReloadChunk __CX + 1, __CZ, 0, __CPY, __CPZ, B
    If __CPZ = 1 Then SetAnotherBlockReloadChunk __CX, __CZ - 1, __CPX, __CPY, 17, B
    If __CPZ = 16 Then SetAnotherBlockReloadChunk __CX, __CZ + 1, __CPX, __CPY, 0, B
    Chunk(FoundI).MinimumHeight = Max(0, Min(Chunk(FoundI).MinimumHeight, __CPY - 1))
    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, __CPY)
    Chunk(FoundI).LoadedRenderData = 0
    Chunk(FoundI).Count = 0
    Chunk(FoundI).TCount = 0
    T = ChunkReloader(FoundI, __CX, __CZ)
    SaveChunkFile __CX, __CZ
End Sub
Sub SetAnotherBlockReloadChunk (__CX As Integer, __CZ As Integer, __CPX As Integer, __CPY As Integer, __CPZ As Integer, B As _Unsigned _Byte)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = __CX And Chunk(I).Z = __CZ And Chunk(I).LoadedChunkData Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Sub
    ChunkData(__CPX, __CPY, __CPZ, FoundI) = B
    Chunk(FoundI).MinimumHeight = Max(0, Min(Chunk(FoundI).MinimumHeight, __CPY - 1))
    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, __CPY)
    Chunk(FoundI).LoadedRenderData = 0
    Chunk(FoundI).Count = 0
    Chunk(FoundI).TCount = 0
    T = ChunkReloader(FoundI, __CX, __CZ)
    SaveChunkFile __CX, __CZ
End Sub
Function LoadChunkFile (CX, CZ)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = CX And Chunk(I).Z = CZ And Chunk(I).LoadedChunkData = -1 Then Exit Function
        If Chunk(I).LoadedChunkData = 0 And FoundI = 0 Then FoundI = I
    Next I
    If FoundI = 0 Then Exit Function
    FILEX = Int(CX / 16): FILEZ = Int(CZ / 16)
    SEEKX = CX - FILEX * 16: SEEKZ = CZ - FILEZ * 16
    SIZE& = Len(Chunk(FoundI)) + Len(TMPCHUNKDATA())
    FILE$ = "saves/" + WORLDFOLDER$ + "/chunks/region_" + TS$(FILEX) + "_" + TS$(FILEZ) + ".chunkdata"
    If _FileExists(FILE$) Then
        F = FreeFile
        Open FILE$ For Binary As #F
        Seek #F, (SEEKX * 16 + SEEKZ) * SIZE& + 1
        Get #F, , Chunk(FoundI)
        If Chunk(FoundI).LoadedChunkData Then
            Get #F, , TMPCHUNKDATA()
            For X = 0 To 17: For Z = 0 To 17: For Y = 0 To ChunkHeight + 1: ChunkData(X, Y, Z, FoundI) = TMPCHUNKDATA(X, Y, Z): Next Y, Z, X
            Close #F
            LoadChunkFile = ChunkReloader(FoundI, CX, CZ)
        Else
            LoadChunkFile = ChunkLoader(FoundI, CX, CZ) And ChunkReloader(FoundI, CX, CZ)
        End If
    Else
        LoadChunkFile = ChunkLoader(FoundI, CX, CZ) And ChunkReloader(FoundI, CX, CZ)
    End If
    LoadedChunks = LoadedChunks + 1
End Function
Sub SaveChunkFile (CX, CZ)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = CX And Chunk(I).Z = CZ And Chunk(I).LoadedChunkData Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Sub
    F = FreeFile
    FILEX = Int(CX / 16): FILEZ = Int(CZ / 16)
    SEEKX = CX - FILEX * 16: SEEKZ = CZ - FILEZ * 16
    SIZE& = Len(Chunk(FoundI)) + Len(TMPCHUNKDATA())
    Open "saves/" + WORLDFOLDER$ + "/chunks/region_" + TS$(FILEX) + "_" + TS$(FILEZ) + ".chunkdata" For Binary As #F
    Seek #F, (SEEKX * 16 + SEEKZ) * SIZE& + 1
    Put #F, , Chunk(FoundI)
    For X = 0 To 17: For Z = 0 To 17: For Y = 0 To ChunkHeight + 1: TMPCHUNKDATA(X, Y, Z) = ChunkData(X, Y, Z, FoundI): Next Y, Z, X
    Put #F, , TMPCHUNKDATA()
    Close #F
End Sub
Sub LoadPlayerData
    Camera.X = 0.5: Camera.Y = GenerationChunkHeight: Camera.Z = 0.5
    CameraAngle.X = 0: CameraAngle.Y = 0
    If _FileExists("saves/" + WORLDFOLDER$ + "/world.dat") = 0 Then Exit Sub
    F = FreeFile
    Open "saves/" + WORLDFOLDER$ + "/world.dat" For Binary As #F
    Get #F, , Seed
    SeedRatio = Seed / 65536
    Get #F, , WorldFlat
    Get #F, , Camera
    Get #F, , CameraAngle
    Get #F, , Time
    Close #F
End Sub
Sub SavePlayerData
    Static SaveTime As Single
    If Timer - SaveTime < 1 Then Exit Sub
    SaveTime = Timer
    F = FreeFile
    Open "saves/" + WORLDFOLDER$ + "/world.dat" For Binary As #F
    Put #F, , Seed
    Put #F, , WorldFlat
    Put #F, , Camera
    Put #F, , CameraAngle
    Put #F, , Time
    Close #F
End Sub
Function LoadImage& (FP$)
    If _FileExists(FP$) Then LoadImage& = _LoadImage(FP$, 32): Exit Function
    If _FileExists(FP$ + ".png") Then LoadImage& = _LoadImage(FP$ + ".png", 32): Exit Function
    If _FileExists(FP$ + ".jpg") Then LoadImage& = _LoadImage(FP$ + ".jpg", 32): Exit Function
    If _FileExists(FP$ + ".jpeg") Then LoadImage& = _LoadImage(FP$ + ".jpeg", 32): Exit Function
    Print "Cannot load "; FP$
End Function
Function TS$ (A)
    TS$ = _Trim$(Str$(A))
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
    BlockExists = IIF(FoundI, ChunkData(__CPX, __CPY, __CPZ, FoundI), 0)
End Function
Sub Settings (__LOAD)
    If __LOAD And _FileExists("saves/settings.dat") = 0 Then Exit Sub
    __F = FreeFile
    Open "saves/settings.dat" For Binary As #__F
    If __LOAD Then
        Get #__F, , FOV
        Get #__F, , RenderDistance
        Get #__F, , FOG
    Else
        Put #__F, , FOV
        Put #__F, , RenderDistance
        Put #__F, , FOG
    End If
    Close #__F
End Sub
Sub Settings_Dialog
    Do
        Cls 1, 0: _Limit 60
        If _Resize Then Screen _NewImage(_ResizeWidth, _ResizeHeight, 32): _PrintMode _KeepBackground
        While _MouseInput: Wend
        Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
        Slider RenderDistance, _Width / 2, _Height * 0.4, "Render Distance", 1, MaxRenderDistance
        TotalChunks = (2 * RenderDistance + 1) ^ 2
        Slider FOV, _Width / 2, _Height * 0.5, "FOV", 70, 110
        If Button(2, _Width / 10, _Height / 10, "") Then Settings False: Exit Do
        _Display
    Loop Until _KeyDown(27)
    While _KeyDown(27): Wend
End Sub
Function Button (T~%%, X As Integer, Y As Integer, S$)
    Select Case T~%%
        Case 1:
            If InRange(X - 200, _MouseX, X + 199) And InRange(Y - 20, _MouseY, Y + 19) Then
                _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(4)
                Button = _MouseButton(1)
                While _MouseButton(1) Or _MouseInput: Wend
            Else
                _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(3)
            End If
            PrintString X - Len(S$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, S$
        Case 9:
            _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(5)
            PrintString X - Len(S$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, S$
        Case 2:
            If InRange(X - 11, _MouseX, X + 11) And InRange(Y - 6, _MouseY, Y + 6) Then
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(15)
                Button = _MouseButton(1)
                While _MouseButton(1) Or _MouseInput: Wend
            Else
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(14)
            End If
        Case 3:
            If InRange(X - 11, _MouseX, X + 11) And InRange(Y - 6, _MouseY, Y + 6) Then
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(17)
                Button = _MouseButton(1)
                While _MouseButton(1) Or _MouseInput: Wend
            Else
                _PutImage (X - 11, Y - 6)-(X + 11, Y + 6), GUI_ASSETS&(16)
            End If
    End Select
End Function
Sub InputBox (X As Integer, Y As Integer, S$, H$, isInFocus As _Unsigned Integer, KeyHit As _Unsigned _Byte)
    _PutImage (X - 200, Y - 10)-(X + 199, Y + 9), GUI_ASSETS&(11)
    If isInFocus And 2 * Timer(0.1) - Int(2 * Timer) > 0.5 Then C$ = "_"
    T$ = Right$(S$, 400 \ FONTWIDTH)
    PrintString X - 200, Y - FONTHEIGHT / 2, T$ + C$
    If Len(T$) = 0 Then PrintString X - Len(H$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, H$
    If isInFocus = 0 Then Exit Sub
    Select Case KeyHit
        Case 8: S$ = Left$(S$, Len(S$) - 1)
        Case 32 To 126: S$ = S$ + Chr$(KeyHit)
    End Select
End Sub
Sub CheckBox (X As Integer, Y As Integer, S$, C As _Unsigned _Byte)
    If C Then
        _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(19)
        If InRange(X - 10, _MouseX, X + 9) And InRange(Y - 10, _MouseY, Y + 9) Then
            _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(21)
            While _MouseButton(1) Or _MouseInput: C = 0: Wend
        End If
    Else
        _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(18)
        If InRange(X - 10, _MouseX, X + 9) And InRange(Y - 10, _MouseY, Y + 9) Then
            _PutImage (X - 10, Y - 10)-(X + 9, Y + 9), GUI_ASSETS&(20)
            While _MouseButton(1) Or _MouseInput: C = -1: Wend
        End If
    End If
    PrintString X + 18, Y - FONTHEIGHT / 2, S$
End Sub
Sub Slider (B As _Unsigned _Byte, X As Integer, Y As Integer, S$, A!, C!)
    T! = (B - A!) / (C! - A!) * 384 - 192
    If InRange(X - 200, _MouseX, X + 199) And InRange(Y - 20, _MouseY, Y + 19) Then
        _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(11)
        _PutImage (X + T - 8, Y - 20)-(X + T + 7, Y + 19), GUI_ASSETS&(13)
        If _MouseButton(1) Then
            B = A! + (_MouseX - X + 192) * (C! - A!) / 384
        End If
    Else
        _PutImage (X - 200, Y - 20)-(X + 199, Y + 19), GUI_ASSETS&(10)
        _PutImage (X + T - 8, Y - 20)-(X + T + 7, Y + 19), GUI_ASSETS&(12)
    End If
    T$ = S$ + ": " + _Trim$(Str$(B))
    PrintString X - Len(T$) * FONTWIDTH / 2, Y - FONTHEIGHT / 2, T$
End Sub
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
