$Color:32
$Console
$Resize:On
'$Dynamic

_Console On

Const LogFile = 1
If LogFile Then Open "log.txt" For Output Lock Write As #100 'Open Log File

'--- Type ---
'$Include:'Vectors.bi'
Type Entity
    As Vec3_Float Position
    Velocity As Vec3_Float: Speed As Single
    As Vec2_Float Angle
    As Single Health, MaxHealth
End Type
'------------

'--- Game Build Settings ---
Const MaxRenderDistance = 16
Const WaterLevel = 64
Const MinimalLighting = -1 ' Fast Lighting
Const SkipLighting = -1 ' Disables Lighting
Const GL_Chunk_Rendering = 0 ' Moves Chunk Rendering to GL Thread, 3 times Faster, Bad for less render distance (or while you're playing)
Const UseDefaultFont = -1
'---------------------------
Const MaxRenderDistanceX = 2 * MaxRenderDistance + 1
Const MaxRenderDistanceZ = 2 * MaxRenderDistance + 1
Const MaxChunks = MaxRenderDistanceX * MaxRenderDistanceZ
Write_Log "Max Chunks: " + _Trim$(Str$(MaxChunks))
Const ChunkDataSize = 4096 ' Since 4096 is the maximum stable count, else 196608
'                            Also, 4096 supports more render distance (upto 96!)
Const MaxRenderPipelineSize = MaxChunks * ChunkDataSize
'    Chunk Size: 16 x 256 x 16
'    in the best case, where all the faces of a chunk are visible: 8 * 128 * 8 blocks
'    for each face (6), each vertex (4) -> 8 * 128 * 8 * 6 * 4 = 196608 (192 KiB)
'    Approx Memory Usage per Chunk (of RenderData ONLY)
'        Vertices: 2 * 3, TextureCoords: 4 * 2, Colors: 1 * 3 => 17
'        17 * 192 -> 3264 KiB = 3.1875 MiB
'        Updated: 17 * 4 -> 68 KiB

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, Fps, RenderDistance
Fov = 90
Fog = -1
Fps = 48 ' _FPS
RenderDistance = 12
'-----------------------------

'--- World Generation Settings ---
Const BiomeSizeFactor = 256
Const CloudsHeight = 384
'---------------------------------

'--- Debug & Error Handlers ---
Dim Shared As _Unsigned Integer LastError
Const Debug_Menu_Show_Terrain_Info = 0 ' Fast
'------------------------------

'--- GL ---
Dim Shared As _Unsigned _Byte GL_CURRENT_STATE, GL_EXTRA_STATE
Const CONST_GL_STATE_CREATE_TEXTURES = 1
Const CONST_GL_STATE_STARTUP_MENU = 2
Const CONST_GL_STATE_PAUSE_MENU = 3
Const CONST_GL_STATE_GAMEPLAY = 4
Const CONST_GL_STATE_FREE_ASSETS = 5
Const CONST_GL_STATE_SHOW_FPS = 6
Const CONST_GL_STATE_SHOW_DEBUG_MENU = 7
Const CONST_GL_STATE_SHOW_LOADING_MENU = 8
Dim Shared As String LoadingMessage
GL_EXTRA_STATE = CONST_GL_STATE_SHOW_LOADING_MENU

_GLRender _Behind

' All Quads Rendering Data (Divided for Individual Chunks)
Dim Shared Vertices(0 To MaxRenderPipelineSize - 1) As Vec3_Int
Dim Shared TextureCoords(0 To MaxRenderPipelineSize - 1) As Vec2_Float
Dim Shared Colors(0 To MaxRenderPipelineSize - 1) As Vec3_Byte

Dim Shared CubeVertices(0 To 23) As Vec3_Byte
Dim Shared CubeTextureCoords(0 To 23) As Vec2_Float
Restore CubeModel
For I = 0 To 23
    Read CubeVertices(I).X, CubeVertices(I).Y, CubeVertices(I).Z
    Read CubeTextureCoords(I).X, CubeTextureCoords(I).Y
Next I

Dim Shared VEC4(3) As Single 'for glVec4
'----------

'--- Chunks ---
Type Chunk
    As Long X, Z, TX, TZ
    As _Unsigned _Byte DataLoaded
    As _Unsigned Integer VerticesCount, TransparentVerticesCount
End Type
Dim Shared As Chunk Chunks(1 To MaxChunks)
Type ChunkData
    As _Unsigned _Byte Block, Light
End Type
Dim Shared As ChunkData ChunksData(0 To 17, 0 To 257, 0 To 17, 1 To MaxChunks) ' used to store Chunk Blocks, Lighting
Dim Shared As _Unsigned Long TotalChunksLoaded
'    Chunk Data, Render Data Load Queue
Dim Shared As String ChunkDataLoadQueue, RenderDataLoadQueue
'--------------

'--- Player ---
Dim Shared As Entity Player
'    Initialize Player
Player.Speed = 4
Player.MaxHealth = 10
Player.Health = Player.MaxHealth
Player.Position.Y = 256
'--------------

'--- Camera & Sky ---
'    Camera
Type Camera
    As Vec3_Float Position, FinalPosition
End Type
Dim Shared As Camera Camera
Dim Shared As _Unsigned _Byte CinematicCamera
Dim Shared As Vec3_Long oldPlayerChunk, PlayerChunk ' used to calculate the chunk in which the player is
Dim Shared As Vec3_Byte PlayerInChunk

'    Clouds
Dim Shared As Vec3_Long CloudVertices(0 To 131071)
Dim Shared As Vec4_Byte CloudColors(0 To 131071)
Dim Shared As _Unsigned Long TotalClouds
'    Sun, Moon
Dim Shared As Vec3_Int SunVertices(0 To 23), MoonVertices(0 To 23)
Dim Shared As Vec3_Byte SunColors(0 To 23), MoonColors(0 To 23)
'    Stars
Dim Shared As Vec3_Long StarsVertices(0 To 65535)
Dim Shared As Vec3_Byte StarsColors(0 To 65535)
Dim Shared As _Unsigned Long TotalStars
'    Sky
Dim Shared As Long SkyColor
Dim Shared SkyColorRed~%%, SkyColorGreen~%%, SkyColorBlue~%%
Dim Shared SkyColorRed!, SkyColorGreen!, SkyColorBlue!
SetSkyColor LightBlue
'--------------------

'--- Game Time ---
Dim Shared GameTime As Single
'-----------------

'--- Screen ---
Dim Shared As Long MainScreen, ScreenWidth, ScreenHeight
ScreenWidth = 960: ScreenHeight = 540
MainScreen = _NewImage(ScreenWidth, ScreenHeight, 32)
Screen MainScreen
Color White, _RGB32(0, 127)
While _Resize: Wend
'--------------

'--- Assets ---
'$Include:'AssetsParser.bas' ' Parse assets.list file and load assets
'--------------

'--- Biomes ---
'$Include:'BiomesParser.bas' ' Parse biomes.list file and load biomes & properties
'--------------

'--- Noise ---
Dim Shared Seed As _Unsigned Long
Randomize Timer
If _CommandCount Then ' load seed
    Seed = Val("&H" + Command$)
Else ' or generate seed
    Seed = _SHL(Rnd * 256, 24) Or _SHL(Rnd * 256, 16) Or _SHL(Rnd * 256, 8) Or _SHL(Rnd * 256, 0)
End If
Write_Log "Seed: " + Hex$(Seed) + "h"
'-------------

'--- Font ---
Dim Shared Font As String, DefaultFont As Long
Font = LoadBitPack("assets/font/ascii.bpc")
DefaultFont = _LoadFont("assets/font/JetBrainsMono-Regular.ttf", 16)
If DefaultFont > 0 Then _Font DefaultFont
'------------

'--- FPS ---
Dim Shared As _Unsigned Integer LFPS, LFPSCount, GFPS, GFPSCount
LFPS = 60: GFPS = 60 ' Set to 60, to prevent zero division error at the beginning
Dim As Long FPSCounterTimer
FPSCounterTimer = _FreeTimer
On Timer(FPSCounterTimer, 1) GoSub FPSCounter
'-----------

'--- Start Game ---
RebuildChunkDataLoadQueue ' Build the Chunk Loading Queue
BuildCloudsStarsSunMoon ' Build the Clouds
Timer(FPSCounterTimer) On
GL_CURRENT_STATE = CONST_GL_STATE_GAMEPLAY
GL_EXTRA_STATE = CONST_GL_STATE_SHOW_FPS
_FPS Fps

Do
    On Error GoTo ErrHandler
    _Limit 60
    If _Resize Then
        tmpScreenWidth = _ResizeWidth
        tmpScreenHeight = _ResizeHeight
        If tmpScreenWidth > 0 And tmpScreenHeight > 0 Then
            ScreenWidth = tmpScreenWidth
            ScreenHeight = tmpScreenHeight
            tmpScreen& = MainScreen
            MainScreen = _NewImage(ScreenWidth, ScreenHeight, 32)
            Screen MainScreen
            _FreeImage tmpScreen&
            _GLRender _Behind
            Color White, _RGB32(0, 127)
            If DefaultFont > 0 Then _Font DefaultFont
        End If
    End If

    If Len(ChunkDataLoadQueue) Then
        LoadNextChunk
    End If
    If GL_Chunk_Rendering = 0 And Len(RenderDataLoadQueue) Then
        RenderNextChunk
    End If

    If _Exit Then Exit Do
    LFPSCount = LFPSCount + 1
Loop
'------------------
'--- Free Assets ---
GL_CURRENT_STATE = CONST_GL_STATE_FREE_ASSETS
While GL_CURRENT_STATE: Wend
'-------------------
If LogFile Then Close #100 'Close Log File
System

'$Include:'FPSCounter.bas'
'$Include:'ErrHandlers.bas'
CubeModel: '$Include:'assets/models/cube.txt'
Sub MoveEntity (Entity As Entity, Angle!, Speed!)
    Entity.Position.X = Entity.Position.X + Cos(_D2R(Angle!)) * Speed!
    Entity.Position.Z = Entity.Position.Z + Sin(_D2R(Angle!)) * Speed!
End Sub
Sub SimulateCamera
    If CinematicCamera Then
        Camera.Position.X = Camera.Position.X + (Player.Position.X - Camera.Position.X) / 8
        Camera.Position.Y = Camera.Position.Y + (Player.Position.Y - Camera.Position.Y) / 8
        Camera.Position.Z = Camera.Position.Z + (Player.Position.Z - Camera.Position.Z) / 8
    Else
        Camera.Position = Player.Position
    End If
    SetSkyColor _RGB32(0, 127, 255)
End Sub
Sub SetSkyColor (Colour&) Static
    SkyColorRed~%% = SkyColorRed~%% + (_Red32(Colour&) - SkyColorRed~%%)
    SkyColorGreen~%% = SkyColorGreen~%% + (_Green32(Colour&) - SkyColorGreen~%%)
    SkyColorBlue~%% = SkyColorBlue~%% + (_Blue32(Colour&) - SkyColorBlue~%%)
    SkyColor = _RGB32(SkyColorRed~%%, SkyColorGreen~%%, SkyColorBlue~%%)
    SkyColorRed! = SkyColorRed~%% / 255
    SkyColorGreen! = SkyColorGreen~%% / 255
    SkyColorBlue! = SkyColorBlue~%% / 255
End Sub
Sub UpdateRenderDistance (__NewRenderDistance&)
    RenderDistance = Clamp(1, __NewRenderDistance&, MaxRenderDistance)
    RebuildChunkDataLoadQueue
End Sub
Sub BuildCloudsStarsSunMoon Static
    Static CloudsImage As Long
    Static __X, __Z, __P&, __I%
    ' Generate Clouds
    CloudsImage = _LoadImage("assets/environment/clouds.png", 32)
    _Source CloudsImage
    TotalClouds = 0
    For __X = 0 To _Width(CloudsImage) - 1
        For __Z = 0 To _Height(CloudsImage) - 1
            __P& = Point(__X, __Z)
            If __P& = &HFFFFFFFF Then
                For __I% = 12 To 15
                    CloudVertices(TotalClouds).X = _SHL(__X - 128 + CubeVertices(__I%).X, 5)
                    CloudVertices(TotalClouds).Y = CloudsHeight + CubeVertices(__I%).Y
                    CloudVertices(TotalClouds).Z = _SHL(__Z - 128 + CubeVertices(__I%).Z, 5)
                    CloudColors(TotalClouds).X = 255
                    CloudColors(TotalClouds).Y = 255
                    CloudColors(TotalClouds).Z = 255
                    CloudColors(TotalClouds).W = 127
                    TotalClouds = TotalClouds + 1
                Next __I%
            End If
    Next __Z, __X
    _Source 0
    _FreeImage CloudsImage
    ' Generate Stars
    For __X = 0 To 255
        For __I% = 0 To 23
            StarsVertices(TotalStars).X = (Rnd - 0.5) * 12288 + CubeVertices(__I%).X
            StarsVertices(TotalStars).Y = (Rnd - 0.5) * 12288 + CubeVertices(__I%).Y
            StarsVertices(TotalStars).Z = (Rnd - 0.5) * 12288 + CubeVertices(__I%).Z
            StarsColors(TotalStars).X = 0: StarsColors(TotalStars).Y = 127: StarsColors(TotalStars).Z = 255
            TotalStars = TotalStars + 1
    Next __I%, __X
    ' Generate Sun & Moon
    For __I% = 0 To 23
        SunVertices(__I%).X = (CubeVertices(__I%).X - 0.5) * 4096
        SunVertices(__I%).Y = (CubeVertices(__I%).Y - 0.5) * 4096
        SunVertices(__I%).Z = (CubeVertices(__I%).Z - 0.5) * 4096 - 8192
        SunColors(__I%).X = 255: SunColors(__I%).Y = 191: SunColors(__I%).Z = 0
        MoonVertices(__I%).X = (CubeVertices(__I%).X - 0.5) * 256
        MoonVertices(__I%).Y = (CubeVertices(__I%).Y - 0.5) * 256
        MoonVertices(__I%).Z = (CubeVertices(__I%).Z - 0.5) * 256 + 4096
        MoonColors(__I%).X = 223: MoonColors(__I%).Y = 223: MoonColors(__I%).Z = 255
    Next __I%
End Sub
Sub ShowCloudsStarsSunMoon Static
    Static CloudTranslateX

    _glPushMatrix

    _glTranslatef Camera.Position.X, Camera.Position.Y, Camera.Position.Z

    _glRotatef GameTime / 4, 1, 0, 0

    _glEnableClientState _GL_VERTEX_ARRAY
    _glEnableClientState _GL_COLOR_ARRAY
    '    Stars - only in night time
    If GameTime >= 720 Then
        _glVertexPointer 3, _GL_INT, 0, _Offset(StarsVertices(0))
        _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(StarsColors(0))
        _glDrawArrays _GL_POINTS, 0, TotalStars
    End If
    '    Sun
    _glVertexPointer 3, _GL_SHORT, 0, _Offset(SunVertices(0))
    _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(SunColors(0))
    _glDrawArrays _GL_QUADS, 0, 24
    '    Moon
    _glVertexPointer 3, _GL_SHORT, 0, _Offset(MoonVertices(0))
    _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(MoonColors(0))
    _glDrawArrays _GL_QUADS, 0, 24

    _glRotatef -GameTime / 4, 1, 0, 0

    '    Draw Clouds
    _glTranslatef CloudTranslateX, -Camera.Position.Y, 0
    _glVertexPointer 3, _GL_INT, 0, _Offset(CloudVertices(0))
    _glColorPointer 4, _GL_UNSIGNED_BYTE, 0, _Offset(CloudColors(0))
    _glDrawArrays _GL_QUADS, 0, TotalClouds
    _glTranslatef -CloudTranslateX, Camera.Position.Y, 0
    CloudTranslateX = ClampCycle(-128, CloudTranslateX + 1 / GFPS, 128)
    _glDisableClientState _GL_COLOR_ARRAY
    _glDisableClientState _GL_VERTEX_ARRAY

    _glPopMatrix

    If GL_CURRENT_STATE = CONST_GL_STATE_GAMEPLAY Then GameTime = ClampCycle(0, GameTime + 1 / GFPS - (_KeyDown(84) Or _KeyDown(116)), 1439)
End Sub
Sub _GL Static
    Static As Long GL_TextureAtlas_Handle
    Static As _Unsigned Long tmpChunksVisible, tmpQuadsVisible: tmpChunksVisible = 0: tmpQuadsVisible = 0
    Static As _Unsigned Long ChunksVisible, QuadsVisible
    Static As Long I, J
    Static As _Unsigned _Byte NewFov, Zoom
    Static As Single TransparentTranslateY
    On Error GoTo GLErrHandler
    Select Case GL_CURRENT_STATE
        Case CONST_GL_STATE_PAUSE_MENU
            _MouseShow
            While _MouseInput: Wend
            Select Case _KeyHit
                Case 27: GL_CURRENT_STATE = CONST_GL_STATE_GAMEPLAY
            End Select
        Case CONST_GL_STATE_GAMEPLAY
            SimulateCamera
            '--- Movement ---
            If _KeyDown(87) Or _KeyDown(119) Then MoveEntity Player, Player.Angle.X - 90, Player.Speed / GFPS
            If _KeyDown(83) Or _KeyDown(115) Then MoveEntity Player, Player.Angle.X + 90, Player.Speed / GFPS
            If _KeyDown(65) Or _KeyDown(97) Then MoveEntity Player, Player.Angle.X - 180, Player.Speed / GFPS
            If _KeyDown(68) Or _KeyDown(100) Then MoveEntity Player, Player.Angle.X, Player.Speed / GFPS
            Zoom = (_KeyDown(67) Or _KeyDown(99)) And 1
            If _KeyDown(32) Then Player.Position.Y = Player.Position.Y + Player.Speed / GFPS
            If _KeyDown(100304) Then Player.Position.Y = Player.Position.Y - Player.Speed / GFPS
            If _KeyDown(100306) Then Player.Speed = 64 Else Player.Speed = 4
            Select Case _KeyHit
                Case 27: GL_CURRENT_STATE = CONST_GL_STATE_PAUSE_MENU
                Case 15616: GL_EXTRA_STATE = IIF(GL_EXTRA_STATE <> CONST_GL_STATE_SHOW_FPS, CONST_GL_STATE_SHOW_FPS, CONST_GL_STATE_SHOW_DEBUG_MENU)
                    'Case 70, 102: UpdateRenderDistance RenderDistance + 2 * _KeyDown(100304) + 1 ' Update Render Distance with F, Shift + F, has bugs
            End Select
            '----------------
            '--- Chunk Coordinates ---
            oldPlayerChunk = PlayerChunk
            PlayerChunk.X = _SHR(Camera.Position.X, 4)
            PlayerChunk.Y = _SHR(Camera.Position.Y, 8)
            PlayerChunk.Z = _SHR(Camera.Position.Z, 4)
            PlayerInChunk.X = Int(Camera.Position.X - _SHL(PlayerChunkX, 4))
            PlayerInChunk.Y = Int(Camera.Position.Y - _SHL(PlayerChunkY, 8))
            PlayerInChunk.Z = Int(Camera.Position.Z - _SHL(PlayerChunkZ, 4))
            If oldPlayerChunk.X <> PlayerChunk.X Or oldPlayerChunk.Z <> PlayerChunk.Z Then RebuildChunkDataLoadQueue
            '-------------------------
            While _MouseInput
                _MouseHide
                Player.Angle.X = ClampCycle(0, Player.Angle.X + _MouseMovementX / 8, 360)
                Player.Angle.Y = Clamp(-90, Player.Angle.Y + _MouseMovementY / 4, 90)
                _MouseMove _Width / 2, _Height / 2
            Wend
    End Select
    Select Case GL_CURRENT_STATE
        Case 0
        Case CONST_GL_STATE_CREATE_TEXTURES
            Write_Log "Generating GL Textures"
            GL_Generate_Texture GL_TextureAtlas_Handle, TextureAtlas
            NewFov = Fov
            GL_CURRENT_STATE = 0
        Case CONST_GL_STATE_STARTUP_MENU

        Case CONST_GL_STATE_PAUSE_MENU, CONST_GL_STATE_GAMEPLAY
            _glViewport 0, 0, _Width - 1, _Height - 1
            _glEnable _GL_BLEND

            'For Anti Aliasing
            _glEnable _GL_LINE_SMOOTH
            _glEnable _GL_POLYGON_SMOOTH
            _glEnable _GL_POINT_SMOOTH
            _glDisable _GL_MULTISAMPLE ' no mixing of texture colors when a quad is far

            _glEnable _GL_DEPTH_TEST
            _glEnable _GL_CULL_FACE ' for performance
            _glClearColor SkyColorRed!, SkyColorGreen!, SkyColorBlue!, 1
            _glClear _GL_DEPTH_BUFFER_BIT Or _GL_COLOR_BUFFER_BIT
            '_glTranslatef 0, 0, -0.25
            _glRotatef Player.Angle.Y, 1, 0, 0
            _glRotatef Player.Angle.X, 0, 1, 0
            _glPushMatrix

            _glTranslatef -Camera.Position.X, -Camera.Position.Y, -Camera.Position.Z
            _glMatrixMode _GL_PROJECTION
            _glLoadIdentity
            NewFov = NewFov + Sgn(Fov - Zoom * (Fov - 30) - NewFov)
            _gluPerspective NewFov, ScreenWidth / ScreenHeight, 0.1, 16384
            _glMatrixMode _GL_MODELVIEW
            _glCullFace _GL_BACK

            ShowCloudsStarsSunMoon

            If Fog Then
                _glEnable _GL_FOG
                _glFogi _GL_FOG_MODE, _GL_LINEAR
                _glFogf _GL_FOG_END, Max(Y, 256)
                _glFogf _GL_FOG_START, 16
                _glFogfv _GL_FOG_COLOR, glVec4(SkyColorRed!, SkyColorGreen!, SkyColorBlue!, 1)
                _glFogf _GL_FOG_DENSITY, 10
            End If

            _glEnable _GL_TEXTURE_2D
            _glBindTexture _GL_TEXTURE_2D, GL_TextureAtlas_Handle
            _glEnableClientState _GL_VERTEX_ARRAY
            _glEnableClientState _GL_TEXTURE_COORD_ARRAY
            _glEnableClientState _GL_COLOR_ARRAY
            tmpChunksVisible = 0
            tmpQuadsVisible = 0
            For I = 1 To MaxChunks ' Render Chunks which are loaded completely
                If Chunks(I).VerticesCount = 0 Or Chunks(I).DataLoaded <> 255 Then _Continue
                J = (I - 1) * ChunkDataSize
                _glPushMatrix
                _glTranslatef Chunks(I).TX, 0, Chunks(I).TZ
                _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(J))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TextureCoords(J))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(Colors(J))
                _glDrawArrays _GL_QUADS, 0, Chunks(I).VerticesCount
                _glPopMatrix
                tmpQuadsVisible = tmpQuadsVisible + _SHR(Chunks(I).VerticesCount, 2)
            Next I
            TransparentTranslateY = ClampCycle(0, TransparentTranslateY + 0.01, _Pi(2))
            _glTranslatef 0, -0.15 - Sin(TransparentTranslateY) * 0.1, 0 ' Translate for water animation
            For I = 1 To MaxChunks ' Render Transparent Quads from Chunks
                tmpChunksVisible = tmpChunksVisible + IIF((Chunks(I).TransparentVerticesCount Or Chunks(I).VerticesCount) And (Chunks(I).DataLoaded = 255), 1, 0)
                If Chunks(I).TransparentVerticesCount = 0 Or Chunks(I).DataLoaded <> 255 Then _Continue
                J = (I - 1) * ChunkDataSize + Chunks(I).VerticesCount + 1
                _glPushMatrix
                _glTranslatef Chunks(I).TX, 0, Chunks(I).TZ
                _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(J))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TextureCoords(J))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(Colors(J))
                _glDrawArrays _GL_QUADS, 0, Chunks(I).TransparentVerticesCount
                _glPopMatrix
                tmpQuadsVisible = tmpQuadsVisible + _SHR(Chunks(I).TransparentVerticesCount, 2)
            Next I
            _glTranslatef 0, -0.15 + Sin(TransparentTranslateY) * 0.1, 0
            ChunksVisible = tmpChunksVisible
            QuadsVisible = tmpQuadsVisible
            _glDisableClientState _GL_COLOR_ARRAY
            _glDisableClientState _GL_TEXTURE_COORD_ARRAY
            _glDisableClientState _GL_VERTEX_ARRAY
            _glDisable _GL_TEXTURE_2D
            _glDisable _GL_CULL_FACE

            _glPopMatrix

            If Fog Then _glDisable _GL_FOG
            _glDisable _GL_DEPTH_TEST
            _glDisable _GL_BLEND
            _glFlush
        Case CONST_GL_STATE_FREE_ASSETS
            Write_Log "Freeing GL Textures"
            _glDeleteTextures 1, _Offset(GL_TextureAtlas_Handle)
            GL_CURRENT_STATE = 0
    End Select
    Cls , 0
    Select Case GL_EXTRA_STATE
        Case CONST_GL_STATE_SHOW_LOADING_MENU
            PrintString ScreenWidth / 2 - 8 * Len(LoadingMessage), ScreenHeight / 2 - 8, LoadingMessage, White
            _Display
        Case CONST_GL_STATE_SHOW_FPS, CONST_GL_STATE_SHOW_DEBUG_MENU
            PrintString 0, 0, "FPS (G/L):" + Str$(GFPS) + "," + Str$(LFPS), White
            PrintString 0, 16, "Player Position:" + Str$(Player.Position.X) + Str$(Player.Position.Y) + Str$(Player.Position.Z) + ", Player Angle:" + Str$(Player.Angle.X) + Str$(Player.Angle.Y), White
            PrintString 0, 32, "Game Time:" + Str$(GameTime), White
            If GL_EXTRA_STATE = CONST_GL_STATE_SHOW_DEBUG_MENU Then
                PrintString 0, 48, "Render Distance: " + Str$(RenderDistance) + ", Total Chunks Loaded:" + Str$(TotalChunksLoaded) + ", Visible:" + Str$(ChunksVisible), LightBlue
                PrintString 0, 64, "Quads Visible:" + Str$(QuadsVisible) + ", Avg/Chunk:" + Str$(Int(QuadsVisible / TotalChunksLoaded)), LightBlue
                PrintString 0, 80, "Queue Size:" + Str$(_SHR(Len(ChunkDataLoadQueue), 3)) + "," + Str$(_SHR(Len(RenderDataLoadQueue), 2)), LightBlue
                If Debug_Menu_Show_Terrain_Info Then
                    PrintString 0, 96, "Terrain", Green
                    Biome! = getBiome(Player.Position.X, Player.Position.Z)
                    Biome1~%% = Int(Biome!)
                    Biome2~%% = Biome1~%% + 1
                    dBiome! = Biome! - Int(Biome!)
                    GroundHeightBias! = interpolate(BiomeHeightBias(Biome1~%%), BiomeHeightBias(Biome2~%%), dBiome!)
                    ExcitedHeightBias! = interpolate(BiomeExcitedHeightBias(Biome1~%%), BiomeExcitedHeightBias(Biome2~%%), dBiome!)
                    BiomeSmoothness! = interpolate(BiomeSmoothness(Biome1~%%), BiomeSmoothness(Biome2~%%), dBiome!)
                    PrintString 16, 112, "Biome: " + ListMapGet(BiomesList, Biome2~%%, "name"), Green
                    PrintString 16, 128, "Ground Height Bias:" + Str$(GroundHeightBias!), Green
                    PrintString 16, 144, "Excited Height Bias:" + Str$(ExcitedHeightBias!), Green
                    PrintString 16, 160, "Biome Smoothness:" + Str$(BiomeSmoothness!), Green
                End If
            End If
            If GL_CURRENT_STATE = CONST_GL_STATE_PAUSE_MENU Then Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
            _Display
    End Select
    If GL_Chunk_Rendering And Len(RenderDataLoadQueue) Then
        RenderNextChunk
    End If
    GFPSCount = GFPSCount + 1
End Sub
Function glVec4%& (X!, Y!, Z!, W!)
    VEC4(0) = X!: VEC4(1) = Y!: VEC4(2) = Z!: VEC4(3) = W!
    glVec4%& = _Offset(VEC4())
End Function
'$Include:'Chunk.bas' 'Contains Code to load ChunkData and Render Chunks
Function AmbientOcclusion~%% (X As _Byte, Y As Integer, Z As _Byte, vertexIndex As _Byte, ChunkID As _Unsigned Integer, CurrentLight As _Unsigned _Byte) Static ' used to calculate block lighting
    'Adapted from QB-Blocks_4
    $Checking:Off
    Dim As _Byte dX, dY, dZ
    Dim As _Byte side1, side2, corner
    Dim As _Byte total
    dX = _SHL(CubeVertices(vertexIndex).X, 1) - 1
    dY = _SHL(CubeVertices(vertexIndex).Y, 1) - 1
    dZ = _SHL(CubeVertices(vertexIndex).Z, 1) - 1
    corner = Sgn(ChunksData(X + dX, Y + dY, Z + dZ, ChunkID).Block)
    side1 = Sgn(ChunksData(X + dX, Y + dY, Z, ChunkID).Block)
    side2 = Sgn(ChunksData(X, Y + dY, Z + dZ, ChunkID).Block)
    total = side1 + side2 + corner + CurrentLight
    total = total + (total - 15) * (total > 15)
    $Checking:On
    AmbientOcclusion = 255 - 15 * total
End Function
Function getHash~%% (T$) Static ' hash function for the blocks hash table
    Static As _Unsigned Long I
    B~%% = Asc(T$)
    For I = 2 To Len(T$) - 1
        B~%% = B~%% + Asc(T$, I)
        If I And 1 Then
            B~%% = _SHL(B~%%, 1)
        Else
            B~%% = _SHR(B~%%, 1) Xor (B~%% And 1)
        End If
    Next I
    getHash~%% = B~%% + Asc(T$, I)
End Function
Function getBlockID~% (BlockName$) Static ' returns the block id from the hash table
    Static Hash~%%, Search~%
    If Len(BlockName$) = 0 Then
        getBlockID~% = 0
        Exit Function
    End If
    Hash~%% = getHash~%%(BlockName$)
    If BlockHashTable_Length(Hash~%%) = 1 Then getBlockID~% = CVI(BlockHashTable_Code(Hash~%%)): Exit Function
    Search~% = ListStringSearch(BlockHashTable_List(Hash~%%), BlockName$)
    If Search~% = 0 Then Write_Log "[getBlockID(" + BlockName$ + ")]: Error: Block not found!": Exit Function
    getBlockID~% = CVI(Mid$(BlockHashTable_Code(Hash~%%), 2 * Search~% - 1, 2))
End Function
Function getHeight! (X As Long, Z As Long, Biome As Single) Static ' returns the height of a position, used by chunk loader, has bugs
    Static As Integer SX, SZ
    Static As Long PX, PZ
    Static Biome1~%%, Biome2~%%, dBiome!
    Static GroundHeightBias!, ExcitedHeightBias!, BiomeSmoothness!, GroundHeight!, ExcitedHeight!
    Static gH!, old_gH!
    SX = _SHR(Seed, 16): SZ = Seed And 65535
    PX = X - SX: PZ = Z - SZ
    Biome1~%% = Int(Biome)
    Biome2~%% = Biome1~%% + 1
    dBiome! = Biome - Int(Biome)
    GroundHeightBias! = interpolate(BiomeHeightBias(Biome1~%%), BiomeHeightBias(Biome2~%%), dBiome!) ' interpolate between changing biomes for smooth values
    ExcitedHeightBias! = interpolate(BiomeExcitedHeightBias(Biome1~%%), BiomeExcitedHeightBias(Biome2~%%), dBiome!)
    'BiomeSmoothness! = interpolate(BiomeSmoothness(Biome1~%%), BiomeSmoothness(Biome2~%%), dBiome!)
    'BiomeSmoothness! is not currently in use
    GroundHeight! = fractal2(PX, PZ, 256, 0, 0) * GroundHeightBias!
    ExcitedHeight! = fractal2(PX, PZ, 64, 3, 1) ' BiomeSmoothness!
    gH! = (GroundHeight! + ExcitedHeight! * ExcitedHeight! * ExcitedHeightBias!) / 2
    If gH! > 256 Then getHeight! = old_gH! Else getHeight! = gH! ' for bugs
    old_gH! = gH!
End Function
Function getBiome! (X As Long, Z As Long) Static ' used to get the biome
    Static As Integer SX, SZ
    Static As Long PX, PZ
    SX = _SHR(Seed, 16): SZ = Seed And 65535
    PX = X - SX: PZ = Z - SZ
    getBiome! = fractal2(PX, PZ, BiomeSizeFactor, 0, 2) * TotalBiomes
End Function
Function LoadAsset& (FILE$)
    ValidFolders$ = ListStringFromString("assets/blocks/,assets/flowers/")
    For I = 1 To ListStringLength(ValidFolders$)
        If _FileExists(ListStringGet(ValidFolders$, I) + FILE$ + ".png") Then LoadAsset& = _LoadImage(ListStringGet(ValidFolders$, I) + FILE$ + ".png", 32): Exit Function
    Next I
    Write_Log "Cannot Load: " + FILE$
End Function
'--- Logging ---
Sub Write_Log (Log$)
    If Asc(Log$, 1) = 1 Then T$ = ListStringPrint(Log$) Else T$ = Log$
    _Echo T$
    If LogFile Then Print #100, T$
End Sub
Sub File_Log (Log$)
    If Asc(Log$, 1) = 1 Then T$ = ListStringPrint(Log$) Else T$ = Log$
    If LogFile Then Print #100, T$
End Sub
Sub CriticalError (__E$)
    Write_Log __E$
    GL_CURRENT_STATE = CONST_GL_STATE_FREE_ASSETS
    While GL_CURRENT_STATE: Wend
    If LogFile Then Close #100 'Close Log File
    Shell "start notepad log.txt"
    System
End Sub
'---------------
Sub PrintString (X As Integer, Y As Integer, T$, Colour As Long) Static
    Dim As _Unsigned Long I
    If UseDefaultFont Then
        Color Colour: _PrintString (X, Y), T$
    Else
        For I = 1 To Len(T$)
            B~%% = Asc(T$, I)
            __Y~% = _SHR(B~%%, 4)
            __X~% = B~%% - _SHL(__Y~%, 4)
            DrawBitPackPart Font, X + (I - 1) * 16, Y, Colour, _SHL(__X~%, 4), _SHL(__Y~%, 4), _SHL(__X~%, 4) + 15, _SHL(__Y~%, 4) + 15
        Next I
    End If
End Sub
'--- Libraries ---
'$Include:'lib/noise.bm'
'$Include:'lib/GL_Generate_Texture.bas'
'$Include:'lib/Tokenizer.bas'
'$Include:'lib/LoadBitPack.bm'
'$Include:'lib/DrawBitPackPart.bm'
'$Include:'lib/clamp.bm'
'$Include:'lib/iif.bm'
'$Include:'lib/inrange.bm'
'$Include:'lib/interpolate.bm'
'$Include:'lib/max.bm'
'$Include:'lib/min.bm'
'$Include:'lib/modfloor.bm'
'$Include:'lib/transitangle.bm'
'$Include:'lib/hex.bm'
'$Include:'lib/fade.bm'
'$Include:'lib/ListMap.bas'
'$Include:'lib/Map.bas'
'-----------------
Function IIFString$ (A~%%, B$, C$)
    If A~%% Then IIFString$ = B$ Else IIFString$ = C$
End Function
Function RemoveDoubleQuotes$ (__S$)
    If Asc(__S$, 1) = 34 And Asc(__S$, Len(__S$)) = 34 Then
        RemoveDoubleQuotes$ = Mid$(__S$, 2, Len(__S$) - 2)
    Else
        RemoveDoubleQuotes$ = __S$
    End If
End Function
