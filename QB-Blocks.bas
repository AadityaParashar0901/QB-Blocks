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

Const MaxRenderDistance = 32
Const WaterLevel = 64
Const UseDefaultFont = -1
'---------------------------
Const MaxRenderDistanceX = 2 * MaxRenderDistance + 1
Const MaxRenderDistanceZ = 2 * MaxRenderDistance + 1
Const MaxChunks = MaxRenderDistanceX * MaxRenderDistanceZ
Write_Log "Max Chunks: " + _Trim$(Str$(MaxChunks))
Const ChunkDataSize = 16384
Const MaxRenderPipelineSize = MaxChunks * ChunkDataSize

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, Fps, RenderDistance
Fov = 90
Fog = -1
Fps = 60 ' _FPS
RenderDistance = 16
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
Const CONST_GL_STATE_GamePlay = 4
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

_GLRender _Behind

Type Ring
    As Vec3_Float Vertices(0 To 802815)
    As Vec2_Float TextureCoords(0 To 802815)
    As Vec3_Byte Colors(0 To 802815)
    As _Unsigned Long TotalVertices
End Type
Dim Shared As Ring Rings(0 To RenderDistance \ 8)
Dim Shared As Ring TransparentRings(0 To RenderDistance \ 8)

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
    As _Unsigned _Byte DataLoaded, LOD
    As _Unsigned Integer VerticesCount, TransparentVerticesCount, MinimumHeight, MaximumHeight
    As _Unsigned _Byte dirtyBit_AirBlock(0 to 31), dirtyBit_TransparentBlock(0 to 31), dirtyBit_SolidBlock(0 to 31)
    As _Unsigned _Byte Blocks(0 to 17, 0 to 257, 0 to 17)
End Type
Dim Shared As Chunk Chunks(1 To MaxChunks)
Dim Shared As _Unsigned Long TotalChunksLoaded

Dim Shared As _Unsigned _Byte GlobalHeightMap(-RenderDistance * 16 To RenderDistance * 16, -RenderDistance * 16 To RenderDistance * 16)

Dim Shared As LongBuffer Queue_ChunkLoad, Queue_RenderLoad
Dim Shared As _Byte NeedToBuild_ChunkQueue
Dim Shared As LongBuffer CompletedChunks

Dim Shared As String * 256 ChunkDataGraphTimer, RenderDataGraphTimer
Const ChunkDataGraphTimerConstant = 4
Const RenderDataGraphTimerConstant = 4
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
GL_Loading_Menu_Message = "Loading Chunks"
GL_Loading_Menu_Progress.Enable = -1
GL_Loading_Menu_Progress.Total = Queue_ChunkLoad.Size
While Queue_ChunkLoad.Size Or Queue_RenderLoad.Size
    GL_Loading_Menu_Progress.Current = GL_Loading_Menu_Progress.Total - Queue_ChunkLoad.Size
    If Queue_ChunkLoad.Size Then LoadNextChunk
    If Queue_RenderLoad.Size Then RenderNextChunk
Wend
GL_Loading_Menu_Progress.Enable = 0
GL_Loading_Menu_Message = "Starting Game"
Build_Clouds
Timer(FPSCounterTimer) On
GL_CURRENT_STATE = CONST_GL_STATE_GamePlay
GL_EXTRA_STATE = CONST_GL_STATE_Show_Debug_Menu
_FPS Fps
Do
    On Error GoTo ErrHandler
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
    If Queue_ChunkLoad.Size Then
        LoadNextChunk
    End If
    If Queue_RenderLoad.Size Then
        RenderNextChunk
    End If

    If _Exit Then Exit Do
    LFPSCount = LFPSCount + 1
Loop
'------------------
'--- Free Assets ---
GL_CURRENT_STATE = CONST_GL_STATE_Free_Assets
While GL_CURRENT_STATE: Wend
'-------------------
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
                CloudColors(TotalClouds).X = 255: CloudColors(TotalClouds).Y = 255: CloudColors(TotalClouds).Z = 255: CloudColors(TotalClouds).W = 127 ' _RGBA(255, 255, 255, 127)
                TotalClouds = TotalClouds + 1
            Next __I%
    Next __Z, __X
    _FreeImage CloudsImage
End Sub
'--- Start of GL Code ---
Sub DrawClouds
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
    If GL_CURRENT_STATE = CONST_GL_STATE_GamePlay Then GameTime = ClampCycle(0, GameTime + 1 / GFPS - (_KeyDown(84) Or _KeyDown(116)), 1439)
End Sub

Sub _GL Static
    Static As Long GL_TextureAtlas_Handle
    Static As _Unsigned Long tmpChunksVisible, tmpQuadsVisible: tmpChunksVisible = 0: tmpQuadsVisible = 0
    Static As _Unsigned Long ChunksVisible, QuadsVisible
    Static As Long I
    Static As _Unsigned _Byte NewFov, Zoom
    Static As Single TransparentTranslateY
    On Error GoTo GLErrHandler
    Select Case GL_CURRENT_STATE
        Case CONST_GL_STATE_Pause_Menu
            _MouseShow
            While _MouseInput: Wend
            Select Case _KeyHit
                Case 27: GL_CURRENT_STATE = CONST_GL_STATE_GamePlay
            End Select
        Case CONST_GL_STATE_GamePlay
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
                Case 71, 103 ' G
                    Fog = Not Fog
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

        Case CONST_GL_STATE_GamePlay
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
            '--- Render Chunks' Opaque Render Data ---
            For __I = 0 To UBound(Rings)
                _glVertexPointer 3, _GL_FLOAT, 0, _Offset(Rings(__I).Vertices())
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(Rings(__I).TextureCoords())
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(Rings(__I).Colors())
                _glDrawArrays _GL_QUADS, 0, Rings(__I).TotalVertices
                tmpQuadsVisible = tmpQuadsVisible + _ShR(Rings(__I).TotalVertices, 2)
            Next __I
            '-----------------------------------------

            '--- Render Chunks' Transparent Render Data ---
            TransparentTranslateY = ClampCycle(0, TransparentTranslateY + 0.01, _Pi(2))
            _glPushMatrix
            _glTranslatef 0, -0.15 - Sin(TransparentTranslateY) * 0.1, 0
            For I = 0 To UBound(TransparentRings)
                _glVertexPointer 3, _GL_FLOAT, 0, _Offset(TransparentRings(I).Vertices())
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TransparentRings(I).TextureCoords())
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(TransparentRings(I).Colors())
                _glDrawArrays _GL_QUADS, 0, TransparentRings(I).TotalVertices
                tmpQuadsVisible = tmpQuadsVisible + _ShR(TransparentRings(I).TotalVertices, 2)
            Next I
            _glPopMatrix
            '----------------------------------------------
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
                PrintString 0, 64, "Quads Visible:" + Str$(QuadsVisible) + ", Avg/Chunk:" + Str$(Int(QuadsVisible / TotalChunksLoaded)), LightBlue
                PrintString 0, 80, "Queue Size:" + Str$(Queue_ChunkLoad.Size) + "," + Str$(Queue_RenderLoad.Size), LightBlue
                PrintString 0, 96, "Total Clouds:" + Str$(TotalClouds), LightGreen
                Line (16, _Height - 68)-(271, _Height - 5), _RGB32(0, 223), BF
                For I = 1 To 256
                    Line (I + 15, _Height - 5)-(I + 15, _Max(_Height - 70, _Height - 5 - Asc(ChunkDataGraphTimer, I))), _RGB32(0, 255, 0, 127), BF
                    Line (I + 15, _Height - 5)-(I + 15, _Max(_Height - 70, _Height - 5 - Asc(RenderDataGraphTimer, I))), _RGB32(255, 0, 0, 127), BF
                Next I
                PrintString 16, _Height - 64, "Chunk:" + Str$(ChunkDataGraphTimerConstant), _RGB32(0, 255, 0)
                PrintString 16, _Height - 48, "Render:" + Str$(RenderDataGraphTimerConstant), _RGB32(255, 0, 0)
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

'--- Terrain ---
Function getHeight~%% (X As Long, Z As Long)
    Dim As Integer SX, SZ
    Dim As Long PX, PZ
    SX = _ShR(Seed, 16): SZ = Seed And 65535
    PX = X - SX: PZ = Z - SZ
    getHeight~%% = _Clamp(1, 33 + fractal2(PX, PZ, 64, 3, 0) * 64, 256)
End Function
'--------------


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

Sub PrintString (X As Integer, Y As Integer, T$, Colour As Long) Static
    Dim As _Unsigned Long I
    If UseDefaultFont Then
        Color Colour: _PrintString (X, Y), T$
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
