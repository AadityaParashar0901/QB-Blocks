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
'$Include:'bi/Vectors.bi'
Type Entity
    As Vec3_Float Position
    Velocity As Vec3_Float: Speed As Single
    As Vec2_Float Angle
    As Single Health, MaxHealth
End Type
'------------

'--- Game Build Settings ---
Const GameVersion = 6.2

Const MaxThreads = 2
Const MaxJobsPerThread = 4

$Let REPORTERROR = 0
Const MaxRenderDistance = 16
Const WaterLevel = 64
Const UseDefaultFont = -1
Const Show_Chunk_Time_Graph = 1
'---------------------------
Const MaxChunks = (2 * MaxRenderDistance + 1) ^ 2
Write_Log "Max Chunks: " + _Trim$(Str$(MaxChunks))
Const ChunkDataSize = 16384
Const MaxRenderPipelineSize = MaxChunks * ChunkDataSize

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, Fps, RenderDistance, Clouds
Fov = 90
Fog = 0
Fps = 60 ' _FPS
Clouds = 0
RenderDistance = 15
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
Type GLProgressInfo
    As _Unsigned _Byte Enable
    As _Unsigned Long Current, Total
End Type
Dim Shared GL_Loading_Menu_Progress As GLProgressInfo
Dim Shared As _Unsigned _Byte GiveWorkToThread

_GLRender _Behind

' All Quads Rendering Data
Const BufferPipelineSize = MaxRenderPipelineSize - 1
Dim Shared As Vec3_Int RingBufferVertices(0 To BufferPipelineSize, 0 To 1)
Dim Shared As Vec2_Float RingBufferTextureCoords(0 To BufferPipelineSize, 0 To 1)
Dim Shared As Vec3_Byte RingBufferColors(0 To BufferPipelineSize, 0 To 1)
Dim Shared As _Unsigned Long RingBufferOpaque(0 To 1, 0 To MaxRenderDistance), RingBufferTransparent(0 To 1, 0 To MaxRenderDistance)
Dim Shared As _Unsigned Long RingBufferChunks(0 To 1, 0 To MaxRenderDistance), RingBufferOffsets(0 To MaxRenderDistance)
Dim Shared As _Unsigned _Byte CurrentBuffer(0 To MaxRenderDistance)
For I = 0 To MaxRenderDistance
    RingBufferOffsets(I) = (I * 2 + 1) ^ 2 * ChunkDataSize
Next I

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
Const ChunkPipelineSize = 16383
Type Chunk
    As Long X, Z, TX, TZ
    As _Unsigned _Byte State
    As _Unsigned Integer VerticesCount, TransparentVerticesCount, MinimumHeight, MaximumHeight
    As _Unsigned _Byte dirtyBit_AirBlock(0 to 31), dirtyBit_TransparentBlock(0 to 31), dirtyBit_SolidBlock(0 to 31)
    As _Unsigned _Byte Blocks(0 to 15, 0 to 255, 0 to 15)
    As Single Height(0 to 15, 0 to 15)
    As Vec3_Int Vertices(0 to chunkpipelinesize)
    As _Unsigned _Byte Textures(0 to chunkpipelinesize), TextureOffsets(0 to chunkpipelinesize)
    As _Unsigned _Byte Colors(0 to chunkpipelinesize) ' Current unsigned byte because it is grayscale
End Type

Dim Shared Chunks(0, 0) As Chunk, ChunksStart As Vec3_Long, ChunksEnd As Vec3_Long
Dim Shared As _Unsigned Long TotalChunksLoaded
Write_Log "Size of a Chunk: " + _ToStr$(Len(Chunks()))
'$Include:'multi_threading\multi_threading.bi'
Const CHUNK_STATE_Empty = 0
Const CHUNK_STATE_HeightMap = 1
Const CHUNK_STATE_Blocks = 2
Const CHUNK_STATE_Mesh = 3
Const CHUNK_STATE_Buffer = 4
Function WorkerStates$ (I As _Unsigned _Byte)
    Select Case I
        Case CHUNK_STATE_Empty: WorkerStates$ = "Empty"
        Case CHUNK_STATE_HeightMap: WorkerStates$ = "Height"
        Case CHUNK_STATE_Blocks: WorkerStates$ = "Blocks"
        Case CHUNK_STATE_Mesh: WorkerStates$ = "Mesh"
        Case CHUNK_STATE_Buffer: WorkerStates$ = "Buffer"
        Case Else: WorkerStates$ = "Invalid"
    End Select
End Function

Dim Shared As _Byte NeedToBuild_ChunkQueue, RebuildAllChunks, CanBuild_ChunkQueue
CanBuild_ChunkQueue = 0

Dim Shared As String * 256 GraphTimer
Const GraphTimerConstant = 4
Dim Shared As String * 256 GraphColor
'--------------

'--- Rings ---
Type Ring
    As LongBuffer Queue_X, Queue_Z
    As _Unsigned _Byte Progress, State, Busy, ChangeBuffer
End Type
Dim Shared As Ring Rings(0 To MaxRenderDistance)
'-------------

'--- Sky ---
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
ScreenWidth = 1024: ScreenHeight = 640
MainScreen = _NewImage(ScreenWidth, ScreenHeight, 32)
Screen MainScreen
While _ScreenExists = 0: Wend
Color White, _RGB32(0, 127)
While _Resize: Wend
GL_EXTRA_STATE = CONST_GL_STATE_Show_Loading_Menu
'--------------

'--- Assets ---
GL_Loading_Menu_Message = "Loading Assets"
'$Include:'bi/Assets.bi' ' Parse assets.list file and load assets
Dim Shared As _Unsigned _Byte Block_Water
Block_Water = getBlockID("water")
'--------------

'--- Biomes ---
GL_Loading_Menu_Message = "Loading Biome Data"
'$Include: 'bi/Biomes.bi' ' Parse biomes.list file and load biomes & properties
Const Biome_Default = 4
'--------------

'--- Player & Camera ---
Dim Shared As Entity Player
Player.Speed = 4
Player.MaxHealth = 10
Player.Health = Player.MaxHealth
Player.Angle.Y = 90
Player.Position.Y = 256

Type Camera
    As Vec3_Float Position, FinalPosition
End Type
Dim Shared As Camera Camera
Dim Shared As _Unsigned _Byte CinematicCamera
Dim Shared As Vec3_Long oldPlayerChunk, PlayerChunk
Dim Shared As Vec3_Byte PlayerInChunk
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
'$Include:'lib\perlin\perlin.bi'
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
    If RebuildAllChunks Then
        RebuildAllChunks = 0
        Write_Log "Rebuilding All Chunks"
        For id = 1 To MaxThreads
            While Workers(id).Start: Wend
            Workers(id).Jobs = 0
            Workers(id).Finished = 0
        Next id
        For X = ChunksStart.X To ChunksEnd.X
            For Z = ChunksStart.Z To ChunksEnd.Z
                Chunks(X, Z).VerticesCount = 0
                Chunks(X, Z).TransparentVerticesCount = 0
                Chunks(X, Z).State = 0
        Next Z, X
        TotalChunksLoaded = 0
        For I = 0 To MaxRenderDistance
            LongBuffer_Clear Rings(I).Queue_X
            LongBuffer_Clear Rings(I).Queue_Z
        Next I
        NeedToBuild_ChunkQueue = -1
    End If
    If NeedToBuild_ChunkQueue Then
        NeedToBuild_ChunkQueue = 0
        Build_ChunkQueue
        For RingId = 0 To RenderDistance
            Rings(RingId).ChangeBuffer = -1
        Next RingId
    End If

    If GiveWorkToThread Then
        For RingId = 0 To RenderDistance ' Dispatcher
            If RingId <= RenderDistance _AndAlso Rings(RingId).State < CHUNK_STATE_Buffer _AndAlso Rings(RingId).Queue_X.Size > 0 Then
                For id = 1 To MaxThreads
                    If Rings(RingId).State = CHUNK_STATE_Mesh And id > 1 Then Exit For
                    If Workers(id).Start Or Workers(id).Finished Then _Continue
                    lockThread id
                    Workers(id).Jobs = 0
                    Workers(id).Freeze = 0
                    For I = 0 To MaxJobsPerThread - 1
                        If Rings(RingId).Progress = 0 Or Rings(RingId).Queue_X.Size = 0 Then Exit For
                        Workers(id).ChunksX(I) = LongBuffer_Pop(Rings(RingId).Queue_X)
                        Workers(id).ChunksZ(I) = LongBuffer_Pop(Rings(RingId).Queue_Z)
                        Workers(id).Jobs = Workers(id).Jobs + 1
                        Rings(RingId).Progress = Rings(RingId).Progress - 1
                    Next I
                    Workers(id).RingId = RingId
                    Workers(id).CanChangeState = Rings(RingId).Progress = 0
                    Workers(id).Buffer = _IIf(Rings(RingId).ChangeBuffer, 1 - CurrentBuffer(RingId), CurrentBuffer(RingId))
                    WorkerStatus(id) = Rings(RingId).State + 1
                    Workers(id).Start = Rings(RingId).State + 1
                    unlockThread id
                    Rings(RingId).Busy = -1
                    Exit For
                Next id
            End If
        Next RingId
    End If
    For id = 1 To MaxThreads ' Collector
        If Workers(id).Start _OrElse Workers(id).Finished = 0 Then _Continue
        RingId = Workers(id).RingId
        Select Case Workers(id).Finished
            Case CHUNK_STATE_Empty To CHUNK_STATE_Mesh
                GraphTimer = Mid$(GraphTimer, 2) + Chr$(_Clamp(0, Workers(id).TimeTook * 1000 / GraphTimerConstant, 255))
                GraphColor = Mid$(GraphColor, 2) + Chr$(_Clamp(0, Workers(id).Finished, 255))
                If Workers(id).Jobs And Rings(RingId).State < CHUNK_STATE_Buffer Then
                    For jobId = 0 To Workers(id).Jobs - 1
                        LongBuffer_Push Rings(RingId).Queue_X, Workers(id).ChunksX(jobId)
                        LongBuffer_Push Rings(RingId).Queue_Z, Workers(id).ChunksZ(jobId)
                    Next jobId
                End If

            Case CHUNK_STATE_Buffer: If Workers(id).CanChangeState = 0 Or Rings(RingId).ChangeBuffer = 0 Then Exit Select
                CurrentBuffer(RingId) = 1 - CurrentBuffer(RingId)
                OldBuffer = 1 - CurrentBuffer(RingId)
                RingBufferOpaque(OldBuffer, RingId) = 0: RingBufferChunks(OldBuffer, RingId) = 0
                Rings(RingId).ChangeBuffer = 0

            Case Else: _Continue

        End Select
        If Workers(id).CanChangeState Then Rings(RingId).State = Workers(id).Finished: Rings(RingId).Progress = Rings(RingId).Queue_X.Size
        Workers(id).Finished = 0
        Rings(RingId).Busy = 0
        Workers(id).RingId = 0
        WorkerStatus(id) = 0
    Next id

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

'$Include:'bi/FPSCounter.bi'
'$Include:'bi/ErrHandlers.bi'
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

'$Include:'bi/Clouds.bi'

'--- Start of GL Code ---
Sub _GL Static
    Static As Long GL_TextureAtlas_Handle
    Static As _Unsigned Long tmpChunksVisible, tmpQuadsVisible: tmpChunksVisible = 0: tmpQuadsVisible = 0
    Static As _Unsigned Long ChunksVisible, QuadsVisible
    Static As Long I, __I
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
                Case 78, 110 ' N
                    CanBuild_ChunkQueue = Not CanBuild_ChunkQueue
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
            If oldPlayerChunk.X <> PlayerChunk.X Or oldPlayerChunk.Z <> PlayerChunk.Z Then NeedToBuild_ChunkQueue = CanBuild_ChunkQueue
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

            tmpChunksVisible = 0
            tmpQuadsVisible = 0
            For I = 0 To RenderDistance
                _glVertexPointer 3, _GL_SHORT, 0, _Offset(RingBufferVertices(RingBufferOffsets(I), CurrentBuffer(I)))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(RingBufferTextureCoords(RingBufferOffsets(I), CurrentBuffer(I)))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(RingBufferColors(RingBufferOffsets(I), CurrentBuffer(I)))
                _glDrawArrays _GL_QUADS, 0, RingBufferOpaque(CurrentBuffer(I), I)

                tmpChunksVisible = tmpChunksVisible + RingBufferChunks(CurrentBuffer(I), I)
                tmpQuadsVisible = tmpQuadsVisible + _ShR(RingBufferOpaque(CurrentBuffer(I), I), 2)
            Next I
            ChunksVisible = tmpChunksVisible
            QuadsVisible = tmpQuadsVisible
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
            PrintString (ScreenWidth - _PrintWidth(GL_Loading_Menu_Message)) / 2, (ScreenHeight - _FontHeight) / 2, GL_Loading_Menu_Message, White
            If GL_Loading_Menu_Progress.Enable Then
                P! = GL_Loading_Menu_Progress.Current / GL_Loading_Menu_Progress.Total
                ProgressWidth = _Max(ScreenWidth * 0.4, 100)
                ProgressX = (ScreenWidth - ProgressWidth) / 2
                ProgressY = ScreenHeight / 2 + _FontHeight
                Line (ProgressX - 1, ProgressY - 1)-(ProgressX + ProgressWidth + 1, ProgressY + 5), -1, B
                Line (ProgressX, ProgressY)-(ProgressX + ProgressWidth * P!, ProgressY + 4), _RGB32(0, 255, 0), BF
            End If
            _Display

        Case CONST_GL_STATE_Show_FPS, CONST_GL_STATE_Show_Debug_Menu
            PrintString 0, 0, "FPS (G/L):" + Str$(GFPS) + "," + Str$(LFPS), White
            PrintString 0, 16, "Player Position:" + Str$(Player.Position.X) + Str$(Player.Position.Y) + Str$(Player.Position.Z) + ", Player Angle:" + Str$(Player.Angle.X) + Str$(Player.Angle.Y), White
            PrintString 0, 32, "Game Time:" + Str$(GameTime), White

            If GL_EXTRA_STATE = CONST_GL_STATE_Show_Debug_Menu Then
                PrintString 0, 48, "Render Distance: " + Str$(RenderDistance) + ", Total Chunks Loaded:" + Str$(TotalChunksLoaded) + ", Chunks Visible:" + Str$(ChunksVisible), LightBlue
                PrintString 0, 64, "Quads Visible:" + Str$(QuadsVisible) + ", Avg/Chunk: " + _IIf(TotalChunksLoaded, _ToStr$(Int(QuadsVisible / TotalChunksLoaded)), "NAN"), LightBlue
                PrintString 0, 80, "Queue Size:", LightBlue

                __I = 14: For I = 0 To RenderDistance
                    PrintString __I * 8, 80, _ToStr$(Rings(I).Queue_X.Size), _IIf(CurrentBuffer(I), _RGB32(255, 0, 0), LightBlue)
                    __I = __I + Len(_ToStr$(Rings(I).Queue_X.Size)) + 1
                Next I

                PrintString 0, 96, "Total Clouds:" + Str$(TotalClouds), LightGreen

                WorkerStatusString$ = "": For I = LBound(WorkerStatus) To UBound(WorkerStatus)
                    WorkerStatusString$ = WorkerStatusString$ + " " + WorkerStates$(WorkerStatus(I))
                Next I
                PrintString 0, 112, "Threads:" + WorkerStatusString$, White

                PrintString 0, 128, _IIf(CanBuild_ChunkQueue, "Can build Chunk Queue", ""), _IIf(NeedToBuild_ChunkQueue, Pink, LightBlue)

                If Show_Chunk_Time_Graph Then
                    Line (16, _Height - 68)-(271, _Height - 5), _RGB32(0, 63), BF
                    For I = 1 To 256
                        __I = Asc(GraphColor, I)
                        __I = _RGB32(_IIf(_ReadBit(__I, 2), 255, 0), _IIf(_ReadBit(__I, 1), 255, 0), _IIf(_ReadBit(__I, 0), 255, 0))
                        Line (I + 15, _Height - 5)-(I + 15, _Max(_Height - 70, _Height - 5 - Asc(GraphTimer, I))), __I, BF
                    Next I
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

'--- Chunk Management ---
'$Include:'Chunk.bm'
Sub workerThread (id As Long)
    Dim As Single ST
    Dim As _Unsigned Integer JobId, RingId
    Dim As Long I, CX, CZ, PX, PZ, X, Y, Z
    Dim As _Unsigned Long RingVertexId, VertexId
    Dim As _Unsigned _Byte NewBuffer
    Dim As Single __TextureHeight, Height
    $Checking:Off

    __TextureHeight = TextureSize / TextureAtlasHeight
    Workers(id).id = id
    Do Until Workers(id).Quit
        If Workers(id).Freeze Then
            _Delay 0.1
            _Continue
        End If
        Select Case Workers(id).Start
            Case CHUNK_STATE_HeightMap
                Dim As Integer perlin2d_i, perlin2d_X0, perlin2d_Y0, perlin2d_X1, perlin2d_Y1, perlin2d_A, perlin2d_B, perlin2d_h
                Dim As Single perlin2d_x, perlin2d_y, perlin2d_dx, perlin2d_dy, perlin2d_u, perlin2d_v, perlin2d_g00, perlin2d_g10, perlin2d_g01, perlin2d_g11, perlin2d_ix0, perlin2d_ix1
                Dim As Single perlin2d_total, perlin2d_amplitude, perlin2d_frequency

                lockThread id
                ST = Timer(0.01)
                For JobId = 0 To Workers(id).Jobs - 1
                    CX = Workers(id).ChunksX(JobId)
                    CZ = Workers(id).ChunksZ(JobId)
                    If Chunks(CX, CZ).State = CHUNK_STATE_HeightMap Then _Continue
                    PX = CX * 16
                    PZ = CZ * 16
                    Chunks(CX, CZ).TX = PX
                    Chunks(CX, CZ).TZ = PZ
                    Chunks(CX, CZ).MinimumHeight = 255
                    Chunks(CX, CZ).MaximumHeight = WaterLevel
                    For X = 0 To 15: For Z = 0 To 15
                            '$Include:'bi/perlin.bi'
                            Chunks(CX, CZ).Height(X, Z) = 96 + perlin2d_total * 64
                    Next Z, X
                    Chunks(CX, CZ).State = CHUNK_STATE_HeightMap
                Next JobId

                Workers(id).Start = 0
                Workers(id).TimeTook = Timer(0.01) - ST
                Workers(id).Finished = CHUNK_STATE_HeightMap
                unlockThread id

            Case CHUNK_STATE_Blocks
                lockThread id
                ST = Timer(0.01)

                For JobId = 0 To Workers(id).Jobs - 1
                    CX = Workers(id).ChunksX(JobId)
                    CZ = Workers(id).ChunksZ(JobId)
                    If Chunks(CX, CZ).State = CHUNK_STATE_Blocks Then _Continue
                    For X = 0 To 15: For Z = 0 To 15
                            Height = Chunks(CX, CZ).Height(X, Z)
                            Chunks(CX, CZ).MaximumHeight = _Max(Height + 1, Chunks(CX, CZ).MaximumHeight)
                            Chunks(CX, CZ).MinimumHeight = _Min(Chunks(CX, CZ).MinimumHeight, Height - 2)
                            dHeight = Height - Int(Height)
                            Height = Int(Height)

                            Y0 = _Max(0, Chunks(CX, CZ).MinimumHeight - 1)
                            Y1 = _Min(Chunks(CX, CZ).MaximumHeight + 1, 255)

                            ' Underground
                            For Y = 0 To Height: Block = BiomeBlocks(_IIf(Y < Height - 2, 2, _IIf(Y = Height, 0, 1)), Biome_Default)
                                Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y, 3)) = _SetBit(Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y, 3)), Y And 7)
                                Chunks(CX, CZ).Blocks(X, Y, Z) = Block
                            Next Y
                            'Chunks(CX, CZ).Blocks(X, 0, Z) = getBlockID("bedrock")

                            ' Water Level
                            For Y = Height To WaterLevel: Block = _IIf(dHeight < 0.5, Block_Water, BiomeBlocks(0, Biome_Default))
                                isTransparentBlock = _IIf(Block = Block_Water, 1, 0)
                                Chunks(CX, CZ).dirtyBit_TransparentBlock(_ShR(Y, 3)) = Chunks(CX, CZ).dirtyBit_TransparentBlock(_ShR(Y, 3)) Or _ShL(isTransparentBlock And (Block <> 0), Y And 7)
                                Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y, 3)) = Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y, 3)) Or _ShL(1 - isTransparentBlock, Y And 7)
                                Chunks(CX, CZ).Blocks(X, Y, Z) = Block
                                TransparentBlocksCount = TransparentBlocksCount + 1
                            Next Y

                            ' Above Height
                            Block = 0: For Y = _Max(Height, WaterLevel) + 1 To 255
                                Chunks(CX, CZ).dirtyBit_AirBlock(_ShR(Y, 3)) = _SetBit(Chunks(CX, CZ).dirtyBit_AirBlock(_ShR(Y, 3)), Y And 7)
                                Chunks(CX, CZ).Blocks(X, Y, Z) = Block
                            Next Y
                            TransparentBlocksCount = TransparentBlocksCount + Y1 - _Max(Height, WaterLevel)
                    Next Z, X
                    Chunks(CX, CZ).MinimumHeight = _Clamp(0, Chunks(CX, CZ).MinimumHeight, 255)
                    Chunks(CX, CZ).MaximumHeight = _Clamp(0, Chunks(CX, CZ).MaximumHeight, 255)
                    Chunks(CX, CZ).State = CHUNK_STATE_Blocks
                Next JobId

                Workers(id).Start = 0
                Workers(id).TimeTook = Timer(0.01) - ST
                Workers(id).Finished = CHUNK_STATE_Blocks
                unlockThread id

            Case CHUNK_STATE_Mesh
                ST = Timer(0.01)

                For JobId = 0 To Workers(id).Jobs - 1
                    CX = Workers(id).ChunksX(JobId)
                    CZ = Workers(id).ChunksZ(JobId)
                    If Chunks(CX, CZ).State = CHUNK_STATE_Mesh Then _Continue
                    VertexId = 0
                    Chunks(CX, CZ).TransparentVerticesCount = 0
                    Chunks(CX, CZ).VerticesCount = 0
                    For Mode = 0 To 1
                        For Y = Chunks(CX, CZ).MinimumHeight To Chunks(CX, CZ).MaximumHeight
                            CurrentLayer = _ShL(-_ReadBit(Chunks(CX, CZ).dirtyBit_AirBlock(_ShR(Y, 3)), Y And 7), 2) Or _ShL(-_ReadBit(Chunks(CX, CZ).dirtyBit_TransparentBlock(_ShR(Y, 3)), Y And 7), 1) Or -_ReadBit(Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y, 3)), Y And 7)
                            If Y > 1 Then
                                Y_1 = Y - 1
                                BelowLayer = _ShL(-_ReadBit(Chunks(CX, CZ).dirtyBit_AirBlock(_ShR(Y_1, 3)), Y_1 And 7), 2) Or _ShL(-_ReadBit(Chunks(CX, CZ).dirtyBit_TransparentBlock(_ShR(Y_1, 3)), Y_1 And 7), 1) Or -_ReadBit(Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y_1, 3)), Y_1 And 7)
                            Else BelowLayer = 0
                            End If
                            If Y < 255 Then
                                Y_1 = Y + 1
                                AboveLayer = _ShL(-_ReadBit(Chunks(CX, CZ).dirtyBit_AirBlock(_ShR(Y_1, 3)), Y_1 And 7), 2) Or _ShL(-_ReadBit(Chunks(CX, CZ).dirtyBit_TransparentBlock(_ShR(Y_1, 3)), Y_1 And 7), 1) Or -_ReadBit(Chunks(CX, CZ).dirtyBit_SolidBlock(_ShR(Y_1, 3)), Y_1 And 7)
                            Else AboveLayer = 0
                            End If
                            LayerCombination = CurrentLayer Or BelowLayer Or AboveLayer
                            If LayerCombination < 3 Then _Continue
                            For X = 0 To 15: For Z = 0 To 15
                                    Block = Chunks(CX, CZ).Blocks(X, Y, Z)
                                    If (Mode = 0 And isTransparent(Block)) Or (Mode = 1 And isTransparent(Block) = 0) Or Block = 0 Then _Continue
                                    Visibility = isTransparent(Chunks(CX + Int((X + 1) / 16), CZ).Blocks((X + 1) And 15, Y And 255, Z And 15))
                                    Visibility = Visibility Or _ShL(isTransparent(Chunks(CX + Int((X - 1) / 16), CZ).Blocks((X - 1) And 15, Y And 255, Z And 15)), 1)
                                    Visibility = Visibility Or _ShL(isTransparent(Chunks(CX, CZ).Blocks(X And 15, (Y + 1) And 255, Z And 15)), 2)
                                    Visibility = Visibility Or _ShL(isTransparent(Chunks(CX, CZ).Blocks(X And 15, (Y - 1) And 255, Z And 15)), 3)
                                    Visibility = Visibility Or _ShL(isTransparent(Chunks(CX, CZ + Int((Z + 1) / 16)).Blocks(X And 15, Y And 255, (Z + 1) And 15)), 4)
                                    Visibility = Visibility Or _ShL(isTransparent(Chunks(CX, CZ + Int((Z - 1) / 16)).Blocks(X And 15, Y And 255, (Z - 1) And 15)), 5)
                                    If Visibility = 0 Then _Continue
                                    If VertexId + 24 >= ChunkPipelineSize Then Exit For
                                    For I = 0 To 23
                                        If (I And 3) = 0 Then
                                            Face = _ShR(I, 2)
                                            If _ReadBit(Visibility, Face) = 0 Then I = I + 3: _Continue
                                            TextureID = Blocks(Block).Faces(Face)
                                            If TextureID = 0 Then I = I + 3: _Continue
                                            TextureOffset = Textures(TextureID).Y
                                            omitSimilarFace = omitBlockFace(Block, Face)
                                            Select Case Face
                                                Case 0: Light = 9: If omitSimilarFace _AndAlso Block = Chunks(CX + Int((X + 1) / 16), CZ).Blocks((X + 1) And 15, Y And 255, Z And 15) Then I = I + 3: _Continue
                                                Case 1: Light = 9: If omitSimilarFace _AndAlso Block = Chunks(CX + Int((X - 1) / 16), CZ).Blocks((X - 1) And 15, Y And 255, Z And 15) Then I = I + 3: _Continue
                                                Case 2: Light = 15: If omitSimilarFace _AndAlso Block = Chunks(CX, CZ).Blocks(X And 15, (Y + 1) And 255, Z And 15) Then I = I + 3: _Continue
                                                Case 3: Light = 7: If omitSimilarFace _AndAlso Block = Chunks(CX, CZ).Blocks(X And 15, (Y - 1) And 255, Z And 15) Then I = I + 3: _Continue
                                                Case 4: Light = 11: If omitSimilarFace _AndAlso Block = Chunks(CX, CZ + Int((Z + 1) / 16)).Blocks(X And 15, Y And 255, (Z + 1) And 15) Then I = I + 3: _Continue
                                                Case 5: Light = 11: If omitSimilarFace _AndAlso Block = Chunks(CX, CZ + Int((Z - 1) / 16)).Blocks(X And 15, Y And 255, (Z - 1) And 15) Then I = I + 3: _Continue
                                            End Select
                                        End If
                                        Chunks(CX, CZ).Vertices(VertexId).X = X + CubeVertices(I).X
                                        Chunks(CX, CZ).Vertices(VertexId).Y = Y + CubeVertices(I).Y
                                        Chunks(CX, CZ).Vertices(VertexId).Z = Z + CubeVertices(I).Z
                                        Chunks(CX, CZ).Textures(VertexId) = I
                                        Chunks(CX, CZ).TextureOffsets(VertexId) = TextureOffset
                                        'AO_dX = _ShL(CubeVertices(I).X, 1) - 1
                                        'AO_dY = _ShL(CubeVertices(I).Y, 1) - 1
                                        'AO_dZ = _ShL(CubeVertices(I).Z, 1) - 1
                                        'AO_t = Sgn(Chunks(CX, CZ).Blocks(X + AO_dX, Y + AO_dY, Z + AO_dZ)) + Sgn(Chunks(CX, CZ).Blocks(X + AO_dX, Y + AO_dY, Z)) + Sgn(Chunks(CX, CZ).Blocks(X, Y + AO_dY, Z + AO_dZ)) + _Clamp(0, 15 - Light, 15)
                                        Chunks(CX, CZ).Colors(VertexId) = 255 - 15 * _Clamp(15 - Light, AO_t, 15)
                                        Chunks(CX, CZ).TransparentVerticesCount = Chunks(CX, CZ).TransparentVerticesCount + _IIf(Mode, 1, 0)
                                        Chunks(CX, CZ).VerticesCount = Chunks(CX, CZ).VerticesCount + _IIf(Mode, 0, 1)
                                        VertexId = VertexId + 1
                                    Next I
                            Next Z, X
                    Next Y, Mode
                    Chunks(CX, CZ).State = CHUNK_STATE_Mesh
                Next JobId

                lockThread id
                Workers(id).Start = 0
                Workers(id).TimeTook = Timer(0.01) - ST
                Workers(id).Finished = CHUNK_STATE_Mesh
                unlockThread id

            Case CHUNK_STATE_Buffer
                lockThread id
                ST = Timer(0.01)

                RingId = Workers(id).RingId
                NewBuffer = Workers(id).Buffer
                RingVertexId = RingBufferOpaque(NewBuffer, RingId) + RingBufferOffsets(RingId)
                For JobId = 0 To Workers(id).Jobs - 1
                    CX = Workers(id).ChunksX(JobId)
                    CZ = Workers(id).ChunksZ(JobId)
                    PX = Chunks(CX, CZ).TX
                    PZ = Chunks(CX, CZ).TZ
                    For VertexId = 0 To Chunks(CX, CZ).VerticesCount - 1
                        RingBufferVertices(RingVertexId, NewBuffer).X = PX + Chunks(CX, CZ).Vertices(VertexId).X
                        RingBufferVertices(RingVertexId, NewBuffer).Y = Chunks(CX, CZ).Vertices(VertexId).Y
                        RingBufferVertices(RingVertexId, NewBuffer).Z = PZ + Chunks(CX, CZ).Vertices(VertexId).Z
                        RingBufferTextureCoords(RingVertexId, NewBuffer).X = CubeTextureCoords(Chunks(CX, CZ).Textures(VertexId)).X
                        RingBufferTextureCoords(RingVertexId, NewBuffer).Y = (CubeTextureCoords(Chunks(CX, CZ).Textures(VertexId)).Y + Chunks(CX, CZ).TextureOffsets(VertexId)) * __TextureHeight
                        RingBufferColors(RingVertexId, NewBuffer).X = Chunks(CX, CZ).Colors(VertexId)
                        RingBufferColors(RingVertexId, NewBuffer).Y = Chunks(CX, CZ).Colors(VertexId)
                        RingBufferColors(RingVertexId, NewBuffer).Z = Chunks(CX, CZ).Colors(VertexId)
                        RingVertexId = RingVertexId + 1
                        RingBufferOpaque(NewBuffer, RingId) = RingBufferOpaque(NewBuffer, RingId) + 1
                    Next VertexId
                    RingBufferChunks(NewBuffer, RingId) = RingBufferChunks(NewBuffer, RingId) + 1
                    Chunks(CX, CZ).State = CHUNK_STATE_Buffer
                Next JobId

                Workers(id).Start = 0
                Workers(id).TimeTook = Timer(0.01) - ST
                Workers(id).Finished = CHUNK_STATE_Buffer
                unlockThread id

        End Select
    Loop
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
'$Include:'lib/perlin/perlin.bm'
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
