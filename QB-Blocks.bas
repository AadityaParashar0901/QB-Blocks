$Color:32
$Console
$Resize:On
'$Dynamic

_Console On

Const LogFile = 1
If LogFile Then Open "log.txt" For Output Lock Write As #100 'Open Log File

'--- Libraries ---
Const BufferSize = 1024
'$Include:'lib/LongBuffer.bi'
'-----------------
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
Const GameVersion = 6.0

Const MaxThreads = 3
' Thread 1, 2: Chunk Generation
' Thread 3: Vertex Buffer Generation
Const MaxJobsPerThread = 16 ' crashes if high, stable = 4 ~ 16

$Let REPORTERROR = 0
Const MaxRenderDistance = 16
Const WaterLevel = 64
Const UseDefaultFont = -1
Const Show_Chunk_Time_Graph = 1
'---------------------------
Const MaxRenderDistanceX = 2 * MaxRenderDistance + 1
Const MaxRenderDistanceZ = 2 * MaxRenderDistance + 1
Const MaxChunks = MaxRenderDistanceX * MaxRenderDistanceZ
Write_Log "Max Chunks: " + _Trim$(Str$(MaxChunks))
Const ChunkDataSize = 16384
Const MaxRenderPipelineSize = MaxChunks * ChunkDataSize

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, Fps, RenderDistance, Clouds
Fov = 90
Fog = 0
Fps = 60 ' _FPS
Clouds = 0
RenderDistance = 8
'-----------------------------

'--- World Generation Settings ---
Const CloudsHeight = 384
'---------------------------------

'--- Debug & Error Handlers ---
Dim Shared As _Unsigned Integer LastError
'------------------------------

'--- GL ---
Dim Shared As _Unsigned _Byte GL_CURRENT_STATE, GL_EXTRA_STATE
Const CONST_GL_STATE_Create_Textures = 1
Const CONST_GL_STATE_Startup_Menu = 2
Const CONST_GL_STATE_Pause_Menu = 3
Const CONST_GL_STATE_Gameplay = 4
Const CONST_GL_STATE_Free_Assets = 5
Const CONST_GL_STATE_Show_FPS = 6
Const CONST_GL_STATE_Show_Debug_Menu = 7
Const CONST_GL_STATE_Show_Loading_Menu = 8
Dim Shared As String GL_Loading_Menu_Message
Dim Shared As _Unsigned _Byte DrawZero
DrawZero = -1
Dim Shared As _Unsigned _Byte GiveWorkToThread
GiveWorkToThread = -1

_GLRender _Behind

' All Quads Rendering Data
Dim Shared As Vec3_Float Zero_Vertices(0 To MaxRenderPipelineSize - 1), One_Vertices(0 To MaxRenderPipelineSize - 1)
Dim Shared As Vec2_Float Zero_TextureCoords(0 To MaxRenderPipelineSize - 1), One_TextureCoords(0 To MaxRenderPipelineSize - 1)
Dim Shared As Vec3_Byte Zero_Colors(0 To MaxRenderPipelineSize - 1), One_Colors(0 To MaxRenderPipelineSize - 1)
Dim Shared As _Unsigned Long Zero_TotalChunks, Zero_TotalVertices, One_TotalChunks, One_TotalVertices
Dim Shared As _Unsigned Long Zero_TotalTransparentVertices, One_TotalTransparentVertices

Dim Shared CubeVertices(0 To 23) As Vec3_Byte
Dim Shared CubeTextureCoords(0 To 23) As Vec2_Float
Restore CubeModel
For I = 0 To 23
    Read CubeVertices(I).X, CubeVertices(I).Y, CubeVertices(I).Z
    Read CubeTextureCoords(I).X, CubeTextureCoords(I).Y
Next I

Dim Shared VEC4(3) As Single
'----------

'--- Chunks ---
Type Chunk
    As Long X, Z, TX, TZ
    As _Unsigned _Byte DataLoaded
    As _Unsigned Integer VerticesCount, TransparentVerticesCount, MinimumHeight, MaximumHeight
    As _Unsigned _Byte dirtyBit_AirBlock(0 to 31), dirtyBit_TransparentBlock(0 to 31), dirtyBit_SolidBlock(0 to 31)
    As _Unsigned _Byte Blocks(0 to 17, 0 to 257, 0 to 17)
    As Vec3_Byte Vertices(0 to chunkdatasize)
    As _Unsigned _Byte Textures(0 to chunkdatasize), TextureOffsets(0 to chunkdatasize)
    As _Unsigned _Byte Colors(0 to chunkdatasize) ' Current unsigned byte because it is grayscale
End Type
Dim Shared As Chunk Chunks(1 To MaxChunks)
Write_Log "Size of Chunks Array: " + _ToStr$(Len(Chunks(0))) + " of " + _ToStr$(Len(Chunks()))
Dim Shared As _Unsigned Long TotalChunksLoaded
'$Include:'multi_threading\multi_threading.bi'

Dim Shared As LongBuffer Queue_ChunkLoad
Dim Shared As _Byte NeedToBuild_ChunkQueue, RebuildAllChunks

Dim Shared As String * 256 GraphTimer
Const GraphTimerConstant = 1
'--------------

'--- Player ---
Dim Shared As Entity Player
Player.Speed = 4
Player.MaxHealth = 10
Player.Health = Player.MaxHealth
Player.Angle.Y = 90
Player.Position.Y = 256
'--------------

'--- Camera & Sky ---
Type Camera
    As Vec3_Float Position, FinalPosition
End Type
Dim Shared As Camera Camera
Dim Shared As _Unsigned _Byte CinematicCamera
Dim Shared As Vec3_Long oldPlayerChunk, PlayerChunk
Dim Shared As Vec3_Byte PlayerInChunk

Dim Shared As Vec3_Long CloudVertices(0 To 262144)
Dim Shared As Vec4_Byte CloudColors(0 To 262144)
Dim Shared As _Unsigned Long TotalClouds

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
While _ScreenExists = 0: Wend
Color White, _RGB32(0, 127)
While _Resize: Wend
GL_EXTRA_STATE = CONST_GL_STATE_Show_Loading_Menu
'--------------

'--- Assets ---
GL_Loading_Menu_Message = "Loading Assets"
'$Include:'Assets.bi' ' Parse assets.list file and load assets
Dim Shared As _Unsigned _Byte Block_Water
Block_Water = getBlockID("water")
'--------------

'--- Biomes ---
GL_Loading_Menu_Message = "Loading Biome Data"
'$Include: 'Biomes.bi' ' Parse biomes.list file and load biomes & properties
Const Biome_Default = 4
'--------------

'--- Noise ---
Dim Shared Seed As _Unsigned Long
Randomize Timer
If _CommandCount Then ' load seed
    Seed = Val("&H" + Command$)
Else ' or generate seed
    Seed = _ShL(Rnd * 256, 24) Or _ShL(Rnd * 256, 16) Or _ShL(Rnd * 256, 8) Or _ShL(Rnd * 256, 0)
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
LFPS = 60: GFPS = 60
Dim As Long FPSCounterTimer
FPSCounterTimer = _FreeTimer
On Timer(FPSCounterTimer, 1) GoSub FPSCounter
'-----------

'--- Start Game ---
GL_Loading_Menu_Message = "Building Chunks"
Build_ChunkQueue
GL_Loading_Menu_Message = "Starting Game"
'$Include:'multi_threading\invoke_all_threads.bi'
Build_Clouds
Timer(FPSCounterTimer) On
GL_CURRENT_STATE = CONST_GL_STATE_Gameplay
GL_EXTRA_STATE = CONST_GL_STATE_Show_Debug_Menu
_FPS Fps
Do
    $If REPORTERROR Then
        On Error GoTo ErrHandler
    $End If
    _Limit 240
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
    If NeedToBuild_ChunkQueue Then
        NeedToBuild_ChunkQueue = 0
        Build_ChunkQueue
    End If
    If RebuildAllChunks Then
        RebuildAllChunks = 0
        Write_Log "Rebuilding All Chunks"
        For id = 1 To 3
            While Workers(id).Start: Wend
            Workers(id).Jobs = 0
            Workers(id).Finished = 0
        Next id
        For I = 1 To MaxChunks
            Chunks(I).VerticesCount = 0
            Chunks(I).TransparentVerticesCount = 0
            Chunks(I).DataLoaded = 0
        Next I
        TotalChunksLoaded = 0
        LongBuffer_Clear Queue_ChunkLoad
        Build_ChunkQueue
    End If
    If GiveWorkToThread And Workers(3).Start = 0 And Workers(3).Finished = 0 Then
        If Queue_ChunkLoad.Size > 0 Then
            For id = 1 To 2
                If Workers(id).Start Or Workers(id).Finished Then _Continue
                lockThread id
                Workers(id).Jobs = 0
                Workers(id).Freeze = 0
                For I = 0 To MaxJobsPerThread - 1
                    If Queue_ChunkLoad.Size = 0 Then Exit For
                    Workers(id).ChunkId(I) = LongBuffer_Pop(Queue_ChunkLoad)
                    Workers(id).Jobs = Workers(id).Jobs + 1
                Next I
                Workers(id).Start = 1
                WorkerStatus(id) = 1
                unlockThread id
                Exit For
            Next id
        End If
    End If
    If Queue_ChunkLoad.Size = 0 Then
        For id = 1 To 2
            If Workers(id).Start Or Workers(id).Finished Then _Continue
            lockThread id
            Workers(id).Freeze = -1
            WorkerStatus(id) = 3
            unlockThread id
        Next id
    End If
    For id = 1 To 2 ' Collector
        If Workers(id).Start Then _Continue
        Select Case Workers(id).Finished
            Case 1: GraphTimer = Mid$(GraphTimer, 2) + Chr$(_Clamp(0, Workers(id).TimeTook * 1024 / GraphTimerConstant, 255))
            Case Else: _Continue
        End Select
        Workers(id).Finished = 0
        WorkerStatus(id) = 0
        NeedToChangeDraw = -1
    Next id
    If NeedToChangeDraw And Workers(3).Start = 0 And Workers(3).Finished = 0 Then
        NeedToChangeDraw = 0
        Workers(3).Start = 2
        WorkerStatus(3) = 2
    End If
    If Workers(3).Finished = 2 Then
        DrawZero = Not DrawZero
        Workers(3).Finished = 0
        WorkerStatus(3) = 3
    End If

    If _Exit Then Exit Do
    LFPSCount = LFPSCount + 1
Loop
'------------------
'--- Free Assets ---
GL_CURRENT_STATE = CONST_GL_STATE_Free_Assets
While GL_CURRENT_STATE: Wend
'-------------------
'--- Exit Threads ---
'$Include:'multi_threading\terminate_threads.bi'
'--------------------
If LogFile Then Close #100 'Close Log File
System

'$Include:'FPSCounter.bi'
'$Include:'ErrHandlers.bi'
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
    RenderDistance = _Clamp(1, __NewRenderDistance&, MaxRenderDistance)
    Build_ChunkQueue
End Sub

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
'--- Start of GL Code ---
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

Sub _GL Static
    Static As Long GL_TextureAtlas_Handle
    Static As _Unsigned Long tmpChunksVisible, tmpQuadsVisible: tmpChunksVisible = 0: tmpQuadsVisible = 0
    Static As _Unsigned Long ChunksVisible, QuadsVisible
    Static As Long I
    Static As _Unsigned _Byte NewFov, Zoom
    Static WorkerStatusString$
    $If REPORTERROR Then
        On Error GoTo GLErrHandler
    $End If
    Select Case GL_CURRENT_STATE
        Case CONST_GL_STATE_Pause_Menu
            _MouseShow
            While _MouseInput: Wend
            Select Case _KeyHit
                Case 27: GL_CURRENT_STATE = CONST_GL_STATE_Gameplay
            End Select
        Case CONST_GL_STATE_Gameplay
            SimulateCamera
            '--- Keyboard Movement ---
            If _KeyDown(87) Or _KeyDown(119) Then MoveEntity Player, Player.Angle.X - 90, Player.Speed / GFPS
            If _KeyDown(83) Or _KeyDown(115) Then MoveEntity Player, Player.Angle.X + 90, Player.Speed / GFPS
            If _KeyDown(65) Or _KeyDown(97) Then MoveEntity Player, Player.Angle.X - 180, Player.Speed / GFPS
            If _KeyDown(68) Or _KeyDown(100) Then MoveEntity Player, Player.Angle.X, Player.Speed / GFPS
            Zoom = (_KeyDown(67) Or _KeyDown(99)) And 1
            If _KeyDown(32) Then Player.Position.Y = Player.Position.Y + 4 * Player.Speed / GFPS
            If _KeyDown(100304) Then Player.Position.Y = Player.Position.Y - 4 * Player.Speed / GFPS
            If _KeyDown(100306) Then Player.Speed = 64 Else Player.Speed = 4
            Select Case _KeyHit
                Case 27 ' Esc
                    GL_CURRENT_STATE = CONST_GL_STATE_Pause_Menu
                Case 91 ' [
                    UpdateRenderDistance RenderDistance - 1
                Case 93 ' ]
                    UpdateRenderDistance RenderDistance + 1
                Case 71, 103 ' G
                    Fog = Not Fog
                Case 77, 109 ' M
                    GiveWorkToThread = Not GiveWorkToThread
                Case 82, 114 ' R
                    RebuildAllChunks = -1
                Case 15616 ' F3
                    GL_EXTRA_STATE = _IIf(GL_EXTRA_STATE <> CONST_GL_STATE_Show_FPS, CONST_GL_STATE_Show_FPS, CONST_GL_STATE_Show_Debug_Menu)
            End Select
            '------------------------
            '--- Chunk Coordinates ---
            oldPlayerChunk = PlayerChunk
            PlayerChunk.X = _ShR(Camera.Position.X, 4)
            PlayerChunk.Y = _ShR(Camera.Position.Y, 8)
            PlayerChunk.Z = _ShR(Camera.Position.Z, 4)
            PlayerInChunk.X = Int(Camera.Position.X - _ShL(PlayerChunk.X, 4))
            PlayerInChunk.Y = Int(Camera.Position.Y - _ShL(PlayerChunk.Y, 8))
            PlayerInChunk.Z = Int(Camera.Position.Z - _ShL(PlayerChunk.Z, 4))
            If oldPlayerChunk.X <> PlayerChunk.X Or oldPlayerChunk.Z <> PlayerChunk.Z Then NeedToBuild_ChunkQueue = -1
            '-------------------------
            '--- Mouse Movement ---
            While _MouseInput
                _MouseHide
                Player.Angle.X = ClampCycle(0, Player.Angle.X + _MouseMovementX / 8, 359.875)
                Player.Angle.Y = _Clamp(-90, Player.Angle.Y + _MouseMovementY / 4, 90)
                _MouseMove _Width / 2, _Height / 2
            Wend
            '----------------------
    End Select
    Select Case GL_CURRENT_STATE
        Case 0
        Case CONST_GL_STATE_Create_Textures
            Write_Log "Generating GL Textures"
            GL_Generate_Texture GL_TextureAtlas_Handle, TextureAtlas
            NewFov = Fov
            GL_CURRENT_STATE = 0
        Case CONST_GL_STATE_Startup_Menu

        Case CONST_GL_STATE_Pause_Menu, CONST_GL_STATE_Gameplay
            _glViewport 0, 0, _Width - 1, _Height - 1
            _glEnable _GL_BLEND

            _glEnable _GL_LINE_SMOOTH
            _glEnable _GL_POLYGON_SMOOTH
            _glEnable _GL_POINT_SMOOTH
            _glDisable _GL_MULTISAMPLE

            _glEnable _GL_DEPTH_TEST
            _glEnable _GL_CULL_FACE
            _glClearColor SkyColorRed!, SkyColorGreen!, SkyColorBlue!, 1
            _glClear _GL_DEPTH_BUFFER_BIT Or _GL_COLOR_BUFFER_BIT
            _glRotatef Player.Angle.Y, 1, 0, 0
            _glRotatef Player.Angle.X, 0, 1, 0
            _glPushMatrix

            _glTranslatef -Camera.Position.X, -Camera.Position.Y, -Camera.Position.Z
            _glMatrixMode _GL_PROJECTION
            _glLoadIdentity
            NewFov = NewFov + Sgn(Fov - Zoom * (Fov - 30) - NewFov)
            _gluPerspective NewFov, ScreenWidth / ScreenHeight, 0.1, 1024
            _glMatrixMode _GL_MODELVIEW
            _glCullFace _GL_BACK

            If Fog Then
                _glEnable _GL_FOG
                _glFogi _GL_FOG_MODE, _GL_LINEAR
                _glFogf _GL_FOG_END, _Max(Camera.Position.Y, 512)
                _glFogf _GL_FOG_START, 16
                _glFogfv _GL_FOG_COLOR, glVec4(SkyColorRed!, SkyColorGreen!, SkyColorBlue!, 1)
                _glFogf _GL_FOG_DENSITY, 1
            End If
            If Camera.Position.Y < CloudsHeight Then DrawClouds

            _glEnable _GL_TEXTURE_2D
            _glBindTexture _GL_TEXTURE_2D, GL_TextureAtlas_Handle
            _glEnableClientState _GL_VERTEX_ARRAY
            _glEnableClientState _GL_TEXTURE_COORD_ARRAY
            _glEnableClientState _GL_COLOR_ARRAY

            If DrawZero Then
                _glVertexPointer 3, _GL_FLOAT, 0, _Offset(Zero_Vertices(0))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(Zero_TextureCoords(0))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(Zero_Colors(0))
                _glDrawArrays _GL_QUADS, 0, Zero_TotalVertices
                _glVertexPointer 3, _GL_FLOAT, 0, _Offset(Zero_Vertices(Zero_TotalVertices))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(Zero_TextureCoords(Zero_TotalVertices))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(Zero_Colors(Zero_TotalVertices))
                _glDrawArrays _GL_QUADS, 0, Zero_TotalTransparentVertices
                ChunksVisible = Zero_TotalChunks
                QuadsVisible = _ShR(Zero_TotalVertices + Zero_TotalTransparentVertices, 2)
            Else
                _glVertexPointer 3, _GL_FLOAT, 0, _Offset(One_Vertices(0))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(One_TextureCoords(0))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(One_Colors(0))
                _glDrawArrays _GL_QUADS, 0, One_TotalVertices
                _glVertexPointer 3, _GL_FLOAT, 0, _Offset(One_Vertices(One_TotalVertices))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(One_TextureCoords(One_TotalVertices))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(One_Colors(One_TotalVertices))
                _glDrawArrays _GL_QUADS, 0, One_TotalTransparentVertices
                ChunksVisible = One_TotalChunks
                QuadsVisible = _ShR(One_TotalVertices + One_TotalTransparentVertices, 2)
            End If
            _glDisableClientState _GL_COLOR_ARRAY
            _glDisableClientState _GL_TEXTURE_COORD_ARRAY
            _glDisableClientState _GL_VERTEX_ARRAY

            _glDisable _GL_TEXTURE_2D
            If Camera.Position.Y >= CloudsHeight Then DrawClouds
            _glDisable _GL_CULL_FACE

            _glPopMatrix

            If Fog Then _glDisable _GL_FOG
            _glDisable _GL_DEPTH_TEST
            _glDisable _GL_BLEND
            _glFlush

        Case CONST_GL_STATE_Free_Assets
            Write_Log "Freeing GL Textures"
            _glDeleteTextures 1, _Offset(GL_TextureAtlas_Handle)
            GL_CURRENT_STATE = 0

    End Select
    Cls , 0
    Select Case GL_EXTRA_STATE
        Case CONST_GL_STATE_Show_Loading_Menu
            PrintString ScreenWidth / 2 - 8 * Len(LoadingMessage), ScreenHeight / 2 - 8, GL_Loading_Menu_Message, White
            _Display

        Case CONST_GL_STATE_Show_FPS, CONST_GL_STATE_Show_Debug_Menu
            PrintString 0, 0, "FPS (G/L):" + Str$(GFPS) + "," + Str$(LFPS), White
            PrintString 0, 16, "Player Position:" + Str$(Player.Position.X) + Str$(Player.Position.Y) + Str$(Player.Position.Z) + ", Player Angle:" + Str$(Player.Angle.X) + Str$(Player.Angle.Y), White
            PrintString 0, 32, "Game Time:" + Str$(GameTime), White
            If GL_EXTRA_STATE = CONST_GL_STATE_Show_Debug_Menu Then
                PrintString 0, 48, "Render Distance: " + Str$(RenderDistance) + ", Total Chunks Loaded:" + Str$(TotalChunksLoaded) + ", Chunks Visible:" + Str$(ChunksVisible), LightBlue
                PrintString 0, 64, "Quads Visible:" + Str$(QuadsVisible) + ", Avg/Chunk:" + Str$(Int(QuadsVisible / TotalChunksLoaded)), LightBlue
                PrintString 0, 80, "Queue Size:" + Str$(Queue_ChunkLoad.Size), LightBlue
                PrintString 0, 96, "Total Clouds:" + Str$(TotalClouds), LightGreen
                If Len(WorkerStatusString$) = 0 Then WorkerStatusString$ = String$(MaxThreads, 32)
                __I = 0: For I = LBound(WorkerStatus) To UBound(WorkerStatus)
                    __I = __I + 1: Select Case WorkerStatus(I)
                        Case 1: Asc(WorkerStatusString$, __I) = 71
                        Case 2: Asc(WorkerStatusString$, __I) = 82
                        Case 3: Asc(WorkerStatusString$, __I) = 70
                    End Select
                Next I
                PrintString 0, 112, "Threads: " + WorkerStatusString$, White
                If Show_Chunk_Time_Graph Then
                    Line (16, _Height - 68)-(271, _Height - 5), _RGB32(0, 63), BF
                    For I = 1 To 256
                        Line (I + 15, _Height - 5)-(I + 15, _Max(_Height - 70, _Height - 5 - Asc(GraphTimer, I))), -1, BF
                    Next I
                    PrintString 0, _Height - 68, _ToStr$(GraphTimerConstant), -1
                End If
            End If
            If GL_CURRENT_STATE = CONST_GL_STATE_Pause_Menu Then Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
            _Display

    End Select
    GFPSCount = GFPSCount + 1
End Sub
Function glVec4%& (X!, Y!, Z!, W!)
    VEC4(0) = X!: VEC4(1) = Y!: VEC4(2) = Z!: VEC4(3) = W!
    glVec4%& = _Offset(VEC4())
End Function
'--- End of GL Code ---
'$Include:'Chunk.bm'
Sub workerThread (id As Long)
    Dim As Single ST, Height, dHeight, __TextureHeight
    Dim As Long I, CX, CZ, PX, PZ, X, Z, Y, Y_1, J
    Dim As _Unsigned Long ChunkId, VertexId, TextureId, TextureOffset, TransparentBlocksCount
    Dim As _Unsigned _Byte Block, LayerCombination, isAirBlock, isTransparentBlock, Mode, Visibility, Face, Light, omitSimilarFace, CurrentLayer, BelowLayer, AboveLayer
    Dim am#, tot#, m#, sc#, __x&, __z&, io%%, tx!, ty!, fx&, fy&, dx!, dy!, fx1&, fy1&, h&, i1!, i2!
    Dim As _Byte AO_dX, AO_dY, AO_dZ, AO_t
    $Checking:Off

    __TextureHeight = TextureSize / TextureAtlasHeight
    Workers(id).id = id
    Do
        If Workers(id).Start = 1 Then
            lockThread id
            ST = Timer(0.01)
            For jobId = 0 To Workers(id).Jobs - 1
                ChunkId = Workers(id).ChunkId(jobId)

                Select Case Chunks(ChunkId).DataLoaded
                    Case 253 To 255
                        Workers(id).Start = 0
                        Workers(id).TimeTook = Timer(0.01) - ST
                        Workers(id).Finished = 1
                        unlockThread id
                        _Continue
                End Select
                CX = Chunks(ChunkId).X
                CZ = Chunks(ChunkId).Z
                PX = CX * 16
                PZ = CZ * 16
                Chunks(ChunkId).TX = PX
                Chunks(ChunkId).TZ = PZ
                Chunks(ChunkId).MinimumHeight = 256
                Chunks(ChunkId).MaximumHeight = WaterLevel + 1
                TransparentBlocksCount = 0
                For X = 0 To 17
                    For Z = 0 To 17

                        am# = 1: tot# = 0: m# = 0: sc# = 1 / 256
                        __x& = PX + X - _ShR(Seed, 16): __z& = PZ + Z - (Seed And 65535)
                        For io%% = 0 To 3
                            tx! = __x& * sc#: ty! = __z& * sc#: fx& = Int(tx!): fy& = Int(ty!)
                            dx! = tx! - fx&: dx! = dx! * dx! * (3 - 2 * dx!): dy! = ty! - fy&: dy! = dy! * dy! * (3 - 2 * dy!): fx1& = fx& + 1: fy1& = fy& + 1

                            h& = fx& * 73856093 Xor fy& * 19349663 Xor Seed * 193: h& = (h& Xor _ShR(h&, 13)) * 60493: h& = h& Xor _ShR(h&, 16): n00! = (h& And 2147483647) / 2147483647
                            h& = fx1& * 73856093 Xor fy& * 19349663 Xor Seed * 193: h& = (h& Xor _ShR(h&, 13)) * 60493: h& = h& Xor _ShR(h&, 16): n10! = (h& And 2147483647) / 2147483647
                            h& = fx& * 73856093 Xor fy1& * 19349663 Xor Seed * 193: h& = (h& Xor _ShR(h&, 13)) * 60493: h& = h& Xor _ShR(h&, 16): n01! = (h& And 2147483647) / 2147483647
                            h& = fx1& * 73856093 Xor fy1& * 19349663 Xor Seed * 193: h& = (h& Xor _ShR(h&, 13)) * 60493: h& = h& Xor _ShR(h&, 16): n11! = (h& And 2147483647) / 2147483647

                            i1! = n00! + (n10! - n00!) * dx!: i2! = n01! + (n11! - n01!) * dx!
                            tot# = tot# + am# * (i1! + (i2! - i1!) * dy!)
                            m# = m# + am#: am# = am# * .5: sc# = sc# * 2
                        Next
                        Height = tot# / m# * 64 + 32
                        Height = _Clamp(1, 1 + Height, 256)

                        Chunks(ChunkId).MaximumHeight = _Max(Height + 1, Chunks(ChunkId).MaximumHeight)
                        Chunks(ChunkId).MinimumHeight = _Min(Chunks(ChunkId).MinimumHeight, Height - 2)
                        dHeight = Height - Int(Height)
                        Height = Int(Height)
                        For Y = _Max(1, Chunks(ChunkId).MinimumHeight - 1) To _Min(Chunks(ChunkId).MaximumHeight + 1, 256)
                            Select Case Y
                                Case Is < Height - 2: Block = BiomeBlocks(2, Biome_Default)
                                Case Height - 2 To Height - 1: Block = BiomeBlocks(1, Biome_Default)
                                Case Height: If Height = WaterLevel And dHeight < 0.5 Then Block = Block_Water Else Block = BiomeBlocks(0, Biome_Default)
                                Case Else: Block = 0
                            End Select
                            If Height <= Y And Y <= WaterLevel And Height <> WaterLevel Then Block = Block_Water
                            isAirBlock = _IIf(Block, 0, 1)
                            isTransparentBlock = isTransparent(Block)
                            Y_1 = Y - 1
                            If Y_1 >= 0 And Y_1 <= 255 Then
                                Chunks(ChunkId).dirtyBit_AirBlock(_ShR(Y_1, 3)) = Chunks(ChunkId).dirtyBit_AirBlock(_ShR(Y_1, 3)) Or _ShL(isAirBlock, Y_1 And 7)
                                Chunks(ChunkId).dirtyBit_TransparentBlock(_ShR(Y_1, 3)) = Chunks(ChunkId).dirtyBit_TransparentBlock(_ShR(Y_1, 3)) Or _ShL(isTransparentBlock And (Block <> 0), Y_1 And 7)
                                Chunks(ChunkId).dirtyBit_SolidBlock(_ShR(Y_1, 3)) = Chunks(ChunkId).dirtyBit_SolidBlock(_ShR(Y_1, 3)) Or _ShL(1 - (isAirBlock Or isTransparentBlock), Y_1 And 7)
                            End If
                            If X >= 0 And X <= 17 And Z >= 0 And Z <= 17 And Y >= 0 And Y <= 257 Then Chunks(ChunkId).Blocks(X, Y, Z) = Block
                            TransparentBlocksCount = TransparentBlocksCount + isTransparentBlock
                        Next Y
                Next Z, X
                Chunks(ChunkId).MaximumHeight = _Clamp(1, Chunks(ChunkId).MaximumHeight, 256)
                Chunks(ChunkId).MinimumHeight = _Clamp(1, Chunks(ChunkId).MinimumHeight, 256)
                If TransparentBlocksCount = 0 Then Chunks(ChunkId).DataLoaded = 255: _Continue

                VertexId = 0
                Chunks(ChunkId).VerticesCount = 0
                Chunks(ChunkId).TransparentVerticesCount = 0
                For Mode = 0 To 1
                    For Y = Chunks(ChunkId).MinimumHeight To Chunks(ChunkId).MaximumHeight
                        Y_1 = Y - 1
                        CurrentLayer = _ShL(-_ReadBit(Chunks(ChunkId).dirtyBit_AirBlock(_ShR(Y_1, 3)), Y_1 And 7), 2) Or _ShL(-_ReadBit(Chunks(ChunkId).dirtyBit_TransparentBlock(_ShR(Y_1, 3)), Y_1 And 7), 1) Or -_ReadBit(Chunks(ChunkId).dirtyBit_SolidBlock(_ShR(Y_1, 3)), Y_1 And 7)
                        If Y > 1 Then
                            Y_1 = Y - 2
                            BelowLayer = _ShL(-_ReadBit(Chunks(ChunkId).dirtyBit_AirBlock(_ShR(Y_1, 3)), Y_1 And 7), 2) Or _ShL(-_ReadBit(Chunks(ChunkId).dirtyBit_TransparentBlock(_ShR(Y_1, 3)), Y_1 And 7), 1) Or -_ReadBit(Chunks(ChunkId).dirtyBit_SolidBlock(_ShR(Y_1, 3)), Y_1 And 7)
                        Else BelowLayer = 0
                        End If
                        If Y < 256 Then
                            Y_1 = Y
                            AboveLayer = _ShL(-_ReadBit(Chunks(ChunkId).dirtyBit_AirBlock(_ShR(Y_1, 3)), Y_1 And 7), 2) Or _ShL(-_ReadBit(Chunks(ChunkId).dirtyBit_TransparentBlock(_ShR(Y_1, 3)), Y_1 And 7), 1) Or -_ReadBit(Chunks(ChunkId).dirtyBit_SolidBlock(_ShR(Y_1, 3)), Y_1 And 7)
                        Else AboveLayer = 0
                        End If
                        LayerCombination = CurrentLayer Or BelowLayer Or AboveLayer
                        If LayerCombination < 3 Then _Continue
                        For X = 1 To 16
                            For Z = 1 To 16
                                Block = Chunks(ChunkId).Blocks(X, Y, Z)
                                If (Mode = 0 And isTransparent(Block)) Or (Mode = 1 And isTransparent(Block) = 0) Or Block = 0 Then _Continue
                                Visibility = isTransparent(Chunks(ChunkId).Blocks(X + 1, Y, Z)) Or _ShL(isTransparent(Chunks(ChunkId).Blocks(X - 1, Y, Z)), 1) Or _ShL(isTransparent(Chunks(ChunkId).Blocks(X, Y + 1, Z)), 2) Or _ShL(isTransparent(Chunks(ChunkId).Blocks(X, Y - 1, Z)), 3) Or _ShL(isTransparent(Chunks(ChunkId).Blocks(X, Y, Z + 1)), 4) Or _ShL(isTransparent(Chunks(ChunkId).Blocks(X, Y, Z - 1)), 5)
                                If Visibility = 0 Then _Continue
                                If VertexId + 24 >= ChunkDataSize Then Exit For
                                For I = 0 To 23
                                    Face = _ShR(I, 2)
                                    If (Visibility And _ShL(1, Face)) = 0 Then I = I + 3: _Continue
                                    TextureId = Blocks(Block).Faces(Face)
                                    If TextureId = 0 Then I = I + 3: _Continue
                                    TextureOffset = Textures(TextureId).Y
                                    If (I And 3) = 0 Then
                                        omitSimilarFace = omitBlockFace(Block, Face)
                                        Select Case Face
                                            Case 0: Light = 9: If omitSimilarFace And Block = Chunks(ChunkId).Blocks(X + 1, Y, Z) Then I = I + 3: _Continue
                                            Case 1: Light = 9: If omitSimilarFace And Block = Chunks(ChunkId).Blocks(X - 1, Y, Z) Then I = I + 3: _Continue
                                            Case 2: Light = 15: If omitSimilarFace And Block = Chunks(ChunkId).Blocks(X, Y + 1, Z) Then I = I + 3: _Continue
                                            Case 3: Light = 7: If omitSimilarFace And Block = Chunks(ChunkId).Blocks(X, Y - 1, Z) Then I = I + 3: _Continue
                                            Case 4: Light = 11: If omitSimilarFace And Block = Chunks(ChunkId).Blocks(X, Y, Z + 1) Then I = I + 3: _Continue
                                            Case 5: Light = 11: If omitSimilarFace And Block = Chunks(ChunkId).Blocks(X, Y, Z - 1) Then I = I + 3: _Continue
                                        End Select
                                    End If
                                    Chunks(ChunkId).Vertices(VertexId).X = X + CubeVertices(I).X
                                    Chunks(ChunkId).Vertices(VertexId).Y = Y + CubeVertices(I).Y
                                    Chunks(ChunkId).Vertices(VertexId).Z = Z + CubeVertices(I).Z
                                    Chunks(ChunkId).TextureOffsets(VertexId) = TextureOffset
                                    Chunks(ChunkId).Textures(VertexId) = I
                                    AO_dX = _ShL(CubeVertices(I).X, 1) - 1: AO_dY = _ShL(CubeVertices(I).Y, 1) - 1: AO_dZ = _ShL(CubeVertices(I).Z, 1) - 1: AO_t = Sgn(Chunks(ChunkId).Blocks(X + AO_dX, Y + AO_dY, Z + AO_dZ)) + Sgn(Chunks(ChunkId).Blocks(X + AO_dX, Y + AO_dY, Z)) + Sgn(Chunks(ChunkId).Blocks(X, Y + AO_dY, Z + AO_dZ)) + _Clamp(0, 15 - Light, 15)
                                    Chunks(ChunkId).Colors(VertexId) = 255 - 15 * _Clamp(15 - Light, AO_t, 15)
                                    Chunks(ChunkId).TransparentVerticesCount = Chunks(ChunkId).TransparentVerticesCount - (Mode = 1)
                                    Chunks(ChunkId).VerticesCount = Chunks(ChunkId).VerticesCount - (Mode = 0)
                                    VertexId = VertexId + 1
                                Next I
                    Next Z, X, Y
                Next Mode
                TotalChunksLoaded = TotalChunksLoaded + 1
                Chunks(ChunkId).DataLoaded = 255
            Next jobId

            Workers(id).Start = 0
            Workers(id).TimeTook = Timer(0.01) - ST
            Workers(id).Finished = 1
            unlockThread id

        ElseIf Workers(id).Start = 2 Then
            ST = Timer(0.01)
            If DrawZero Then ' need to build one
                One_TotalVertices = 0
                One_TotalTransparentVertices = 0
                One_TotalChunks = 0
                For I = 1 To MaxChunks
                    If Chunks(I).DataLoaded < 255 Then _Continue
                    PX = Chunks(I).TX
                    PZ = Chunks(I).TZ
                    For VertexId = 0 To Chunks(I).VerticesCount - 1
                        One_Vertices(One_TotalVertices).X = PX + Chunks(I).Vertices(VertexId).X
                        One_Vertices(One_TotalVertices).Y = Chunks(I).Vertices(VertexId).Y
                        One_Vertices(One_TotalVertices).Z = PZ + Chunks(I).Vertices(VertexId).Z
                        One_TextureCoords(One_TotalVertices).X = CubeTextureCoords(Chunks(I).Textures(VertexId)).X
                        One_TextureCoords(One_TotalVertices).Y = (CubeTextureCoords(Chunks(I).Textures(VertexId)).Y + Chunks(I).TextureOffsets(VertexId)) * __TextureHeight
                        One_Colors(One_TotalVertices).X = Chunks(I).Colors(VertexId)
                        One_Colors(One_TotalVertices).Y = Chunks(I).Colors(VertexId)
                        One_Colors(One_TotalVertices).Z = Chunks(I).Colors(VertexId)
                        One_TotalVertices = One_TotalVertices + 1
                    Next VertexId
                    One_TotalChunks = One_TotalChunks + 1
                Next I
                For I = 1 To MaxChunks
                    If Chunks(I).DataLoaded < 255 Then _Continue
                    PX = Chunks(I).TX
                    PZ = Chunks(I).TZ
                    J = One_TotalVertices + One_TotalTransparentVertices
                    For VertexId = Chunks(I).VerticesCount To Chunks(I).TransparentVerticesCount - 1 + Chunks(I).VerticesCount
                        One_Vertices(J).X = PX + Chunks(I).Vertices(VertexId).X
                        One_Vertices(J).Y = Chunks(I).Vertices(VertexId).Y
                        One_Vertices(J).Z = PZ + Chunks(I).Vertices(VertexId).Z
                        One_TextureCoords(J).X = CubeTextureCoords(Chunks(I).Textures(VertexId)).X
                        One_TextureCoords(J).Y = (CubeTextureCoords(Chunks(I).Textures(VertexId)).Y + Chunks(I).TextureOffsets(VertexId)) * __TextureHeight
                        One_Colors(J).X = Chunks(I).Colors(VertexId)
                        One_Colors(J).Y = Chunks(I).Colors(VertexId)
                        One_Colors(J).Z = Chunks(I).Colors(VertexId)
                        J = J + 1
                    Next VertexId
                    One_TotalTransparentVertices = J - One_TotalVertices
                Next I
            Else ' need to build zero
                Zero_TotalVertices = 0
                Zero_TotalTransparentVertices = 0
                Zero_TotalChunks = 0
                For I = 1 To MaxChunks
                    If Chunks(I).DataLoaded < 255 Then _Continue
                    PX = Chunks(I).TX
                    PZ = Chunks(I).TZ
                    For VertexId = 0 To Chunks(I).VerticesCount - 1
                        Zero_Vertices(Zero_TotalVertices).X = PX + Chunks(I).Vertices(VertexId).X
                        Zero_Vertices(Zero_TotalVertices).Y = Chunks(I).Vertices(VertexId).Y
                        Zero_Vertices(Zero_TotalVertices).Z = PZ + Chunks(I).Vertices(VertexId).Z
                        Zero_TextureCoords(Zero_TotalVertices).X = CubeTextureCoords(Chunks(I).Textures(VertexId)).X
                        Zero_TextureCoords(Zero_TotalVertices).Y = (CubeTextureCoords(Chunks(I).Textures(VertexId)).Y + Chunks(I).TextureOffsets(VertexId)) * __TextureHeight
                        Zero_Colors(Zero_TotalVertices).X = Chunks(I).Colors(VertexId)
                        Zero_Colors(Zero_TotalVertices).Y = Chunks(I).Colors(VertexId)
                        Zero_Colors(Zero_TotalVertices).Z = Chunks(I).Colors(VertexId)
                        Zero_TotalVertices = Zero_TotalVertices + 1
                    Next VertexId
                    Zero_TotalChunks = Zero_TotalChunks + 1
                Next I
                For I = 1 To MaxChunks
                    If Chunks(I).DataLoaded < 255 Then _Continue
                    PX = Chunks(I).TX
                    PZ = Chunks(I).TZ
                    J = Zero_TotalVertices + Zero_TotalTransparentVertices
                    For VertexId = Chunks(I).VerticesCount To Chunks(I).TransparentVerticesCount - 1 + Chunks(I).VerticesCount
                        Zero_Vertices(J).X = PX + Chunks(I).Vertices(VertexId).X
                        Zero_Vertices(J).Y = Chunks(I).Vertices(VertexId).Y
                        Zero_Vertices(J).Z = PZ + Chunks(I).Vertices(VertexId).Z
                        Zero_TextureCoords(J).X = CubeTextureCoords(Chunks(I).Textures(VertexId)).X
                        Zero_TextureCoords(J).Y = (CubeTextureCoords(Chunks(I).Textures(VertexId)).Y + Chunks(I).TextureOffsets(VertexId)) * __TextureHeight
                        Zero_Colors(J).X = Chunks(I).Colors(VertexId)
                        Zero_Colors(J).Y = Chunks(I).Colors(VertexId)
                        Zero_Colors(J).Z = Chunks(I).Colors(VertexId)
                        J = J + 1
                    Next VertexId
                    Zero_TotalTransparentVertices = J - Zero_TotalVertices
                Next I
            End If
            lockThread id
            Workers(id).Start = 0
            Workers(id).TimeTook = Timer(0.01) - ST
            Workers(id).Finished = 2
            unlockThread id

        ElseIf Workers(id).Freeze Then
            _Delay 0.1
        End If
    Loop Until Workers(id).Quit
    exitThread
    $Checking:On
End Sub

'--- Block Hash Table ---
Function getHash~%% (T$)
    Dim I As _Unsigned Long, B~%%
    B~%% = Asc(T$)
    For I = 2 To Len(T$) - 1
        B~%% = B~%% + Asc(T$, I)
        If I And 1 Then
            B~%% = _ShL(B~%%, 1)
        Else
            B~%% = _ShR(B~%%, 1) Xor (B~%% And 1)
        End If
    Next I
    getHash~%% = B~%% + Asc(T$, I)
End Function
Function getBlockID~% (BlockName$)
    Dim Hash~%%, Search~%
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
'------------------------


'--- Helper Function & Libraries ---
'$Include:'Assets.bm'
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
    GL_CURRENT_STATE = CONST_GL_STATE_Free_Assets
    While GL_CURRENT_STATE: Wend
    If LogFile Then Close #100 'Close Log File
    Shell "start notepad log.txt"
    System
End Sub
'---------------

Sub PrintString (X As Integer, Y As Integer, T$, Colour As Long)
    Dim As _Unsigned Long I
    If _Dest = _Console Then Exit Sub
    If UseDefaultFont Then
        Color Colour
        _PrintString (X, Y), T$
    Else
        For I = 1 To Len(T$)
            B~%% = Asc(T$, I)
            __Y~% = _ShR(B~%%, 4)
            __X~% = B~%% - _ShL(__Y~%, 4)
            DrawBitPackPart Font, X + (I - 1) * 16, Y, Colour, _ShL(__X~%, 4), _ShL(__Y~%, 4), _ShL(__X~%, 4) + 15, _ShL(__Y~%, 4) + 15
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
'$Include:'lib/LongBuffer.bm'
'-----------------

Function RemoveDoubleQuotes$ (__S$) ' used by AssetsParser.bas
    If Asc(__S$, 1) = 34 And Asc(__S$, Len(__S$)) = 34 Then
        RemoveDoubleQuotes$ = Mid$(__S$, 2, Len(__S$) - 2)
    Else
        RemoveDoubleQuotes$ = __S$
    End If
End Function
Function GetColorAtPosition& (IMG&, X&, Y&) Static ' Used for generating Clouds
    __S& = _Source
    _Source IMG&
    GetColorAtPosition = Point(ClampCycle(0, X&, _Width(IMG&) - 1), ClampCycle(0, Y&, _Height(IMG&) - 1))
    _Source __S&
End Function
