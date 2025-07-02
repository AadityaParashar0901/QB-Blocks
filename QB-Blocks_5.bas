$Color:32
$Console
$Resize:On
'$Dynamic

_Console On

Const LogFile = 1
If LogFile Then Open "log.txt" For Output As #100 'Open Log File

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
Const MaxRenderDistance = 32
Const WaterLevel = 63
'---------------------------
Const MaxRenderDistanceX = MaxRenderDistance + 1
Const MaxRenderDistanceZ = MaxRenderDistance + 1
Const MaxChunks = MaxRenderDistanceX * MaxRenderDistanceZ
Write_Log "Max Chunks: " + _Trim$(Str$(MaxChunks))
Const MaxRenderPipelineSize = MaxChunks * 196608
Const ChunkDataSize = 196608
'    Chunk Size: 16 x 256 x 16
'    in the best case, where all the faces of a chunk are visible: 8 * 128 * 8 blocks
'    for each face (6), each vertex (4) -> 8 * 128 * 8 * 6 * 4 = 196608 (192 KiB)
'    Approx Memory Usage per Chunk (of RenderData ONLY)
'        Vertices: 2 * 3, TextureCoords: 4 * 2, Colors: 1 * 3 => 17
'        17 * 192 -> 3264 KiB = 3.1875 MiB

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, RenderDistance
Fov = 90
Fog = 0
RenderDistance = MaxRenderDistance
'-----------------------------

'--- World Generation Settings ---
Const NoiseSmoothness = 256
'---------------------------------

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
Dim Shared As ChunkData ChunksData(0 To 17, 0 To 257, 0 To 17, 1 To MaxChunks)
Dim Shared As _Unsigned Long TotalChunksLoaded
'    Chunk Loading
Dim As Vec3_Long RenderChunksStart, RenderChunksEnd, LoadChunk
Dim LoadChunk~`, ChunkID As _Unsigned Long
Dim As _Unsigned Long tmpTotalChunksLoaded
Dim As _Unsigned _Byte Visibility
'    Chunk Load Queue
Dim Shared As _Unsigned Long ChunkLoadQueue(0 To 255)
Dim As _Unsigned _Byte NewChunkLoadQueue
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
Dim Shared As Vec3_Long PlayerChunk
Dim Shared As Vec3_Byte PlayerInChunk

'    Clouds
LoadingMessage = "Generating Clouds"
Const MaxCloudVertices = 24 * 1048576
Dim Shared As Vec3_Int CloudVertices(0 To MaxCloudVertices - 1)
Dim Shared As Vec4_Byte CloudColors(0 To MaxCloudVertices - 1)
Dim Shared As _Unsigned Long TotalClouds
'    Sun
'    Moon
'    Sky
Dim Shared As Long SkyColor
Dim Shared SkyColorRed~%%, SkyColorGreen~%%, SkyColorBlue~%%
Dim Shared SkyColorRed!, SkyColorGreen!, SkyColorBlue!
SetSkyColor LightBlue
'--------------------

'--- Screen ---
Dim Shared As Long MainScreen, ScreenWidth, ScreenHeight
ScreenWidth = 960: ScreenHeight = 540
MainScreen = _NewImage(ScreenWidth, ScreenHeight, 32)
Screen MainScreen
Color White, _RGB32(0, 127)
While _Resize: Wend
'--------------

'--- Assets ---
Dim Shared As Long TextureAtlas
Dim Shared As _Unsigned Integer TextureSize, TotalTextures, TotalBlocks
Dim As String FileContents
'    Hash Table for getBlockID
Dim Shared As String BlockHashTable_List(0 To 255)
Dim Shared As _Unsigned Integer BlockHashTable_Length(0 To 255)
Dim Shared As String BlockHashTable_Code(0 To 255)
'$Include:'AssetsParser.bas'
'    Form Hash Table
For I = 1 To TotalBlocks
    Hash~%% = getHash~%%(Blocks(I).Name)
    If BlockHashTable_Length(Hash~%%) = 0 Then BlockHashTable_List(Hash~%%) = ListStringNew$
    ListStringAdd BlockHashTable_List(Hash~%%), Blocks(I).Name
    BlockHashTable_Length(Hash~%%) = BlockHashTable_Length(Hash~%%) + 1
    BlockHashTable_Code(Hash~%%) = BlockHashTable_Code(Hash~%%) + MKI$(I)
    Write_Log "isTransparent(" + Blocks(I).Name + "): " + IIFString(isTransparent(I), "True", "False")
Next I
For I = 0 To 255
    If BlockHashTable_List(I) = "" Then _Continue
    Write_Log "Block Hash Table (" + ByteToHex$(I) + "): " + ListStringPrint(BlockHashTable_List(I))
Next I
'    Create Texture Atlas
Dim Shared TextureAtlasHeight As _Unsigned Long
TextureAtlasHeight = TextureSize * Textures(TotalTextures).Y + _Height(Textures(TotalTextures).Handle)
TextureAtlas = _NewImage(TextureSize, TextureAtlasHeight, 32)
For I = 1 To TotalTextures
    _PutImage (0, TextureSize * Textures(I).Y), Textures(I).Handle, TextureAtlas
    _FreeImage Textures(I).Handle
Next I

GL_CURRENT_STATE = CONST_GL_STATE_CREATE_TEXTURES
While GL_CURRENT_STATE: Wend
'--------------

'--- Noise ---
Dim Shared Seed As _Unsigned Long
Randomize Timer
Seed = _SHL(Rnd * 256, 24) Or _SHL(Rnd * 256, 16) Or _SHL(Rnd * 256, 8) Or _SHL(Rnd * 256, 0)
Clouds 'Initialize Clouds
'-------------

'--- Font ---
Dim Shared Font As String
Font = LoadBitPack("assets/font/ascii.bpc")
'------------

'--- FPS ---
Dim Shared As _Unsigned Integer LFPS, LFPSCount, GFPS, GFPSCount
LFPS = 60
GFPS = 60
Dim As Long FPSCounterTimer
FPSCounterTimer = _FreeTimer
On Timer(FPSCounterTimer, 1) GoSub FPSCounter
'-----------

'--- Start Game ---
Timer(FPSCounterTimer) On
GL_CURRENT_STATE = CONST_GL_STATE_GAMEPLAY
GL_EXTRA_STATE = CONST_GL_STATE_SHOW_FPS

'    Debug
'    -----

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
        End If
    End If
    While _MouseInput
        Select Case GL_CURRENT_STATE
            Case CONST_GL_STATE_PAUSE_MENU
                _MouseShow
            Case CONST_GL_STATE_GAMEPLAY
                _MouseHide
                Player.Angle.X = ClampCycle(0, Player.Angle.X + _MouseMovementX / 8, 360)
                Player.Angle.Y = Clamp(-90, Player.Angle.Y + _MouseMovementY / 4, 90)
                _MouseMove _Width / 2, _Height / 2
        End Select
    Wend
    Select Case GL_CURRENT_STATE
        Case CONST_GL_STATE_STARTUP_MENU
        Case CONST_GL_STATE_PAUSE_MENU
            Select Case _KeyHit
                Case 27: GL_CURRENT_STATE = CONST_GL_STATE_GAMEPLAY
            End Select
        Case CONST_GL_STATE_GAMEPLAY
    End Select
    '--- Chunk Load ---
    $Checking:Off
    LoadChunk~` = 0
    tmpTotalChunksLoaded = 0
    ChunkID = 0
    RenderChunksStart.X = PlayerChunk.X - RenderDistance / 2
    RenderChunksStart.Z = PlayerChunk.Z - RenderDistance / 2
    RenderChunksEnd.X = PlayerChunk.X + RenderDistance / 2
    RenderChunksEnd.Z = PlayerChunk.Z + RenderDistance / 2
    ReDim LoadedChunks(RenderChunksStart.X To RenderChunksEnd.X, RenderChunksStart.Z To RenderChunksEnd.Z) As _Unsigned Long
    For I = 1 To MaxChunks
        If Chunks(I).DataLoaded < 253 Then ChunkID = IIF(ChunkID, ChunkID, I): _Continue
        If InRange(RenderChunksStart.X, Chunks(I).X, RenderChunksEnd.X) And InRange(RenderChunksStart.Z, Chunks(I).Z, RenderChunksEnd.Z) Then 'Mark Chunks (only loaded)
            LoadedChunks(Chunks(I).X, Chunks(I).Z) = I
            tmpTotalChunksLoaded = tmpTotalChunksLoaded + 1
        Else 'Unload Chunks
            Chunks(I).DataLoaded = 0
            Chunks(I).VerticesCount = 0
        End If
    Next I
    TotalChunksLoaded = tmpTotalChunksLoaded
    Dim As Vec3_Long tmpChunksStart, tmpChunksEnd
    For R = 0 To RenderDistance
        tmpChunksStart.X = PlayerChunk.X - R
        tmpChunksEnd.X = PlayerChunk.X + R
        tmpChunksStart.Z = PlayerChunk.Z - R
        tmpChunksEnd.Z = PlayerChunk.Z + R
        For X = tmpChunksStart.X To tmpChunksEnd.X
            For Z = tmpChunksStart.Z To tmpChunksEnd.Z
                If LoadedChunks(X, Z) = 0 Then 'Load Chunk if mark unloaded
                    LoadChunk.X = X
                    LoadChunk.Z = Z
                    LoadChunk~` = 1
                    GoTo __CHUNK_LOAD_EXIT_FOR
                End If
    Next Z, X, R
    __CHUNK_LOAD_EXIT_FOR:
    $Checking:On
    '------------------
    '--- Load Chunks ---
    $Checking:Off
    If LoadChunk~` And ChunkID > 0 Then
        Select Case Chunks(ChunkID).DataLoaded And (Chunks(ChunkID).X = LoadChunk.X And Chunks(ChunkID).Z = LoadChunk.Z)
            Case 0 '    Load Chunk Data
                PX = LoadChunk.X * 16
                PZ = LoadChunk.Z * 16
                Chunks(ChunkID).TX = PX
                Chunks(ChunkID).TZ = PZ
                TransparentBlocksCount = 0
                Dim As Integer Height, SurfaceHeight
                For X = 0 To 17
                    For Z = 0 To 17
                        Height = getHeight~%%(PX + X, PZ + Z)
                        SurfaceHeight = Height - 2
                        For Y = 0 To 257
                            Select Case Y
                                Case Is < SurfaceHeight: Block~%% = getBlockID("stone")
                                Case SurfaceHeight To Height - 1: Block~%% = getBlockID("dirt")
                                Case Height: Block~%% = getBlockID("grass")
                                Case Else: Block~%% = 0
                            End Select
                            If Y <= WaterLevel And Height <= Y Then Block~%% = getBlockID("water")
                            ChunksData(X, Y, Z, ChunkID).Block = Block~%%
                            TransparentBlocksCount = TransparentBlocksCount + isTransparent(Block~%%)
                        Next Y
                Next Z, X
                For X = 0 To 17
                    For Z = 0 To 17
                        Height = getHeight~%%(PX + X, PZ + Z)
                        SurfaceHeight = Height - 2
                        If fractal2(PX + X, PZ + Z, 4, 1, 2) * fractal2(PX + X, PZ + Z, 4, 1, 3) > 0.9 And Height >= WaterLevel - 2 Then
                            TreeHeight = fractal2(PX + X, PZ + Z, 256, 0, 2) * 5 + 2
                            For Y = 1 To TreeHeight
                                ChunksData(X, Y + Height, Z, ChunkID).Block = getBlockID("oak_log")
                            Next Y
                            For XX = X - 1 To X + 1
                                For ZZ = Z - 1 To Z + 1
                                    For Y = 0 To 1
                                        If XX = X And ZZ = Z And Y = 0 Then _Continue
                                        If XX >= 0 And XX <= 17 And ZZ >= 0 And ZZ <= 17 Then
                                            ChunksData(XX, Y + Height + TreeHeight - 1, ZZ, ChunkID).Block = getBlockID("oak_leaves")
                                        End If
                                    Next Y
                            Next ZZ, XX
                        End If
                Next Z, X
                Chunks(ChunkID).X = LoadChunk.X
                Chunks(ChunkID).Z = LoadChunk.Z
                If TransparentBlocksCount = 0 Then Chunks(ChunkID).DataLoaded = 255 Else Chunks(ChunkID).DataLoaded = 1
            Case 1: '    Calculate Light Data
                For X = 0 To 17: For Z = 0 To 17
                        __TOGGLE` = 0
                        For Y = 257 To 0 Step -1
                            __TOGGLE` = (isTransparent(ChunksData(X, Y, Z, ChunkID).Block) = 0) Or __TOGGLE`
                            ChunksData(X, Y, Z, ChunkID).Light = 15 And (__TOGGLE` = 0)
                Next Y, Z, X
                Chunks(ChunkID).DataLoaded = 2
            Case 2 To 16
                I = 17 - Chunks(ChunkID).DataLoaded
                For X = 1 To 16: For Z = 1 To 16: For Y = 1 To 256
                            If ChunksData(X, Y, Z, ChunkID).Light Or ChunksData(X, Y, Z, ChunkID).Block Then _Continue
                            If ChunksData(X + 1, Y, Z, ChunkID).Light = I Or ChunksData(X - 1, Y, Z, ChunkID).Light = I Or ChunksData(X, Y + 1, Z, ChunkID).Light = I Or ChunksData(X, Y - 1, Z, ChunkID).Light = I Or ChunksData(X, Y, Z + 1, ChunkID).Light = I Or ChunksData(X, Y, Z - 1, ChunkID).Light = I Then
                                ChunksData(X, Y, Z, ChunkID).Light = I - 1
                            End If
                Next Y, Z, X
                Chunks(ChunkID).DataLoaded = Chunks(ChunkID).DataLoaded + 1
            Case 17:
                If ChunkLoadQueue(NewChunkLoadQueue) = 0 Then
                    ChunkLoadQueue(NewChunkLoadQueue) = ChunkID
                    Chunks(ChunkID).DataLoaded = 253
                    File_Log "Chunk Data Loaded(" + _Trim$(Str$(ChunkID)) + "):" + Str$(Chunks(ChunkID).X) + Str$(Chunks(ChunkID).Z)
                End If
                NewChunkLoadQueue = NewChunkLoadQueue + 1
        End Select
    End If
    $Checking:On
    '-------------------
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
    Clouds
End Sub
Sub Clouds Static
    Static As Long CloudX, CloudZ
    Static FirstRun As _Unsigned _Byte
    Static As _Unsigned _Bit * 20 CloudOffset, CloudsCurrentOffset
    Static As _Unsigned _Byte OmitFace
    If FirstRun = 0 Then
        FirstRun = -1
        CloudX = -512
        CloudZ = -512
        TotalClouds = 0
        Do
            Select Case fractal2(CloudX - 128, CloudZ - 128, 16, 3, 7)
                Case 0.1 To 0.4
                    For I = 12 To 15
                        CloudVertices(CloudsCurrentOffset).X = _SHL(CloudX + CubeVertices(I).X, 1)
                        CloudVertices(CloudsCurrentOffset).Y = 384 + CubeVertices(I).Y
                        CloudVertices(CloudsCurrentOffset).Z = _SHL(CloudZ + CubeVertices(I).Z, 1)
                        CloudColors(CloudsCurrentOffset).X = 255
                        CloudColors(CloudsCurrentOffset).Y = 255
                        CloudColors(CloudsCurrentOffset).Z = 255
                        CloudColors(CloudsCurrentOffset).W = 127
                        CloudsCurrentOffset = CloudsCurrentOffset + 1
                    Next I
                Case 0.7 To 0.9
                    For I = 12 To 15
                        CloudVertices(CloudsCurrentOffset).X = _SHL(CloudX + CubeVertices(I).X, 1)
                        CloudVertices(CloudsCurrentOffset).Y = 320 + CubeVertices(I).Y
                        CloudVertices(CloudsCurrentOffset).Z = _SHL(CloudZ + CubeVertices(I).Z, 1)
                        CloudColors(CloudsCurrentOffset).X = 223
                        CloudColors(CloudsCurrentOffset).Y = 223
                        CloudColors(CloudsCurrentOffset).Z = 223
                        CloudColors(CloudsCurrentOffset).W = 127
                        CloudsCurrentOffset = CloudsCurrentOffset + 1
                    Next I
            End Select
            TotalClouds = Max(CloudsCurrentOffset, TotalClouds)
            CloudX = CloudX + 1
            If CloudX >= 512 Then CloudX = -512: CloudZ = CloudZ + 1
            If CloudZ >= 512 Then CloudZ = -512: CloudsCurrentOffset = 0
        Loop While CloudX <> -512 Or CloudZ <> -512
    End If
End Sub
Sub SetSkyColor (Colour&)
    SkyColorRed~%% = SkyColorRed~%% + Sgn(_Red32(Colour&) - SkyColorRed~%%)
    SkyColorGreen~%% = SkyColorGreen~%% + Sgn(_Green32(Colour&) - SkyColorGreen~%%)
    SkyColorBlue~%% = SkyColorBlue~%% + Sgn(_Blue32(Colour&) - SkyColorBlue~%%)
    SkyColor = _RGB32(SkyColorRed~%%, SkyColorGreen~%%, SkyColorBlue~%%)
    SkyColorRed! = SkyColorRed~%% / 255
    SkyColorGreen! = SkyColorGreen~%% / 255
    SkyColorBlue! = SkyColorBlue~%% / 255
End Sub
Sub _GL
    Static As Long GL_TextureAtlas_Handle
    Static As _Unsigned Long tmpChunksVisible, tmpQuadsVisible: tmpChunksVisible = 0: tmpQuadsVisible = 0
    Static As _Unsigned Long ChunksVisible, QuadsVisible
    Static As Long I, J
    Static As _Unsigned _Byte NewFov, Zoom
    Static As Single CloudsTranslateZ, TransparentTranslateY
    Dim VertexID As _Unsigned Long
    On Error GoTo GLErrHandler
    Select Case GL_CURRENT_STATE
        Case CONST_GL_STATE_GAMEPLAY
            While _MouseInput
                _MouseHide
                Player.Angle.X = ClampCycle(0, Player.Angle.X + _MouseMovementX / 8, 360)
                Player.Angle.Y = Clamp(-90, Player.Angle.Y + _MouseMovementY / 4, 90)
                _MouseMove _Width / 2, _Height / 2
            Wend
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
            End Select
            '----------------
            '--- Chunk Coordinates ---
            PlayerChunk.X = _SHR(Camera.Position.X, 4): PlayerChunk.Y = _SHR(Camera.Position.Y, 8): PlayerChunk.Z = _SHR(Camera.Position.Z, 4)
            PlayerInChunk.X = Int(Camera.Position.X - _SHL(PlayerChunkX, 4)): PlayerInChunk.Y = Int(Camera.Position.Y - _SHL(PlayerChunkY, 8)): PlayerInChunk.Z = Int(Camera.Position.Z - _SHL(PlayerChunkZ, 4))
            '-------------------------
    End Select
    Select Case GL_CURRENT_STATE
        Case 0
        Case CONST_GL_STATE_CREATE_TEXTURES
            Write_Log "Generating GL Textures"
            GL_Generate_Texture GL_TextureAtlas_Handle, TextureAtlas
            CloudsTranslateZ = -256
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
            '_glDisable _GL_MULTISAMPLE

            _glEnable _GL_DEPTH_TEST
            _glEnable _GL_CULL_FACE
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
            _gluPerspective NewFov, ScreenWidth / ScreenHeight, 0.1, 4096
            _glMatrixMode _GL_MODELVIEW
            _glCullFace _GL_BACK
            If Fog Then
                _glEnable _GL_FOG
                _glFogi _GL_FOG_MODE, _GL_LINEAR
                _glFogf _GL_FOG_END, 1024
                _glFogf _GL_FOG_START, 8 * RenderDistance
                _glFogfv _GL_FOG_COLOR, glVec4(SkyColorRed!, SkyColorGreen!, SkyColorBlue!, 1)
                _glFogf _GL_FOG_DENSITY, 1
            End If

            _glEnable _GL_TEXTURE_2D
            _glBindTexture _GL_TEXTURE_2D, GL_TextureAtlas_Handle
            _glEnableClientState _GL_VERTEX_ARRAY
            _glEnableClientState _GL_TEXTURE_COORD_ARRAY
            _glEnableClientState _GL_COLOR_ARRAY
            tmpChunksVisible = 0
            tmpQuadsVisible = 0
            For I = 1 To MaxChunks
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
            TransparentTranslateY = ClampCycle(0, TransparentTranslateY + 0.01, _Pi)
            _glTranslatef 0, -Sin(TransparentTranslateY) * 0.1, 0
            For I = 1 To MaxChunks
                tmpChunksVisible = tmpChunksVisible - ((Chunks(I).TransparentVerticesCount Or Chunks(I).VerticesCount) > 0) And (Chunks(I).DataLoaded = 255)
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
            _glTranslatef 0, Sin(TransparentTranslateY) * 0.1, 0
            ChunksVisible = tmpChunksVisible
            QuadsVisible = tmpQuadsVisible
            _glDisableClientState _GL_COLOR_ARRAY
            _glDisableClientState _GL_TEXTURE_COORD_ARRAY
            _glDisableClientState _GL_VERTEX_ARRAY
            _glDisable _GL_TEXTURE_2D

            _glPopMatrix
            _glTranslatef 0, -Camera.Position.Y, CloudsTranslateZ
            CloudsTranslateZ = ClampCycle(-256, CloudsTranslateZ + 0.02, 256)
            _glEnableClientState _GL_VERTEX_ARRAY
            _glEnableClientState _GL_COLOR_ARRAY
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(CloudVertices(0))
            _glColorPointer 4, _GL_UNSIGNED_BYTE, 0, _Offset(CloudColors(0))
            _glDrawArrays _GL_QUADS, 0, TotalClouds
            _glDisableClientState _GL_COLOR_ARRAY
            _glDisableClientState _GL_VERTEX_ARRAY

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
            PrintString 0, 16, "Player Position:" + Str$(Player.Position.X) + Str$(Player.Position.Y) + Str$(Player.Position.Z), White
            PrintString 0, 32, "Player Angle:" + Str$(Player.Angle.X) + Str$(Player.Angle.Y), White
            If GL_EXTRA_STATE = CONST_GL_STATE_SHOW_DEBUG_MENU Then
                PrintString 0, 48, "Total Chunks Loaded:" + Str$(TotalChunksLoaded) + ", Visible:" + Str$(ChunksVisible), White
                PrintString 0, 64, "Quads Visible:" + Str$(QuadsVisible), White
                PrintString 0, 80, "Total Clouds:" + Str$(_SHR(TotalClouds, 2)), White
            End If
            If GL_CURRENT_STATE = CONST_GL_STATE_PAUSE_MENU Then Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
            _Display
    End Select
    'Load Chunk Render Data
    Dim As _Unsigned Long ChunkID
    For I = 0 To 255
        If ChunkLoadQueue(I) = 0 Then _Continue
        ChunkID = ChunkLoadQueue(I)
        Select Case Chunks(ChunkID).DataLoaded
            Case 253, 254: '    Load Opaque Render Data
                Dim Mode As _Unsigned _Byte
                Mode = Chunks(ChunkID).DataLoaded
                If Mode = 253 Then
                    VertexID = ChunkDataSize * (ChunkID - 1)
                    Chunks(ChunkID).VerticesCount = 0
                Else
                    VertexID = ChunkDataSize * (ChunkID - 1) + Chunks(ChunkID).VerticesCount + 1
                    Chunks(ChunkID).TransparentVerticesCount = 0
                End If
                For X = 1 To 16
                    For Y = 1 To 256
                        For Z = 1 To 16
                            CurrentBlock = ChunksData(X, Y, Z, ChunkID).Block
                            If (Mode = 253 And isTransparent(CurrentBlock)) Or (Mode = 254 And isTransparent(CurrentBlock) = 0) Or CurrentBlock = 0 Then _Continue
                            Visibility = isTransparent(ChunksData(X + 1, Y, Z, ChunkID).Block) Or_
                                 _SHL(isTransparent(ChunksData(X - 1, Y, Z, ChunkID).Block), 1) Or_
                                 _SHL(isTransparent(ChunksData(X, Y + 1, Z, ChunkID).Block), 2) Or_
                                 _SHL(isTransparent(ChunksData(X, Y - 1, Z, ChunkID).Block), 3) Or_
                                 _SHL(isTransparent(ChunksData(X, Y, Z + 1, ChunkID).Block), 4) Or_
                                 _SHL(isTransparent(ChunksData(X, Y, Z - 1, ChunkID).Block), 5)
                            Dim As _Unsigned _Byte Face
                            For I = 0 To 23
                                Face = _SHR(I, 2)
                                If (Visibility And _SHL(1, Face)) = 0 Then _Continue
                                TextureID = Asc(Blocks(CurrentBlock).Faces, Face + 1)
                                If TextureID = 0 Then _Continue
                                TextureOffset = Textures(TextureID).Y
                                omitFace = omitBlockFace(CurrentBlock, Face)
                                Select Case Face
                                    Case 0: Light = ChunksData(X + 1, Y, Z, ChunkID).Light - 6: If omitFace And CurrentBlock = ChunksData(X + 1, Y, Z, ChunkID).Block Then _Continue
                                    Case 1: Light = ChunksData(X - 1, Y, Z, ChunkID).Light - 6: If omitFace And CurrentBlock = ChunksData(X - 1, Y, Z, ChunkID).Block Then _Continue
                                    Case 2: Light = ChunksData(X, Y + 1, Z, ChunkID).Light: If omitFace And CurrentBlock = ChunksData(X, Y + 1, Z, ChunkID).Block Then _Continue
                                    Case 3: Light = ChunksData(X, Y - 1, Z, ChunkID).Light - 8: If omitFace And CurrentBlock = ChunksData(X, Y - 1, Z, ChunkID).Block Then _Continue
                                    Case 4: Light = ChunksData(X, Y, Z + 1, ChunkID).Light - 4: If omitFace And CurrentBlock = ChunksData(X, Y, Z + 1, ChunkID).Block Then _Continue
                                    Case 5: Light = ChunksData(X, Y, Z - 1, ChunkID).Light - 4: If omitFace And CurrentBlock = ChunksData(X, Y, Z - 1, ChunkID).Block Then _Continue
                                End Select
                                Vertices(VertexID).X = X + CubeVertices(I).X
                                Vertices(VertexID).Y = Y + CubeVertices(I).Y
                                Vertices(VertexID).Z = Z + CubeVertices(I).Z
                                TextureCoords(VertexID).X = CubeTextureCoords(I).X
                                TextureCoords(VertexID).Y = (CubeTextureCoords(I).Y + TextureOffset) * TextureSize / TextureAtlasHeight
                                Colors(VertexID).X = AmbientOcclusion(X, Y, Z, I, ChunkID, 15 - (Light - Light * (Light < 0)))
                                'Colors(VertexID).X = AmbientOcclusion(X, Y, Z, I, ChunkID, 0)
                                Colors(VertexID).Y = Colors(VertexID).X
                                Colors(VertexID).Z = Colors(VertexID).X
                                Chunks(ChunkID).TransparentVerticesCount = Chunks(ChunkID).TransparentVerticesCount - (Mode = 254)
                                Chunks(ChunkID).VerticesCount = Chunks(ChunkID).VerticesCount - (Mode = 253)
                                VertexID = VertexID + 1
                            Next I
                Next Z, Y, X
                If Mode = 254 Then
                    File_Log "Render Data Loaded:" + Str$(Chunks(ChunkID).VerticesCount) + Str$(Chunks(ChunkID).TransparentVerticesCount)
                    TotalChunksLoaded = TotalChunksLoaded + 1
                End If
                Chunks(ChunkID).DataLoaded = Mode + 1
                ChunkLoadQueue(I) = 0
                Exit For
            Case Else
        End Select
    Next I
    GFPSCount = GFPSCount + 1
End Sub
Function glVec4%& (X!, Y!, Z!, W!)
    VEC4(0) = X!: VEC4(1) = Y!: VEC4(2) = Z!: VEC4(3) = W!
    glVec4%& = _Offset(VEC4())
End Function
Function AmbientOcclusion~%% (X As _Byte, Y As Integer, Z As _Byte, vertexIndex As _Byte, ChunkID As _Unsigned Integer, CurrentLight As _Unsigned _Byte) Static
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
Function getHash~%% (T$) Static
    Dim As _Unsigned Long I
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
Function getBlockID~% (BlockName$) Static
    Hash~%% = getHash~%%(BlockName$)
    If BlockHashTable_Length(Hash~%%) = 1 Then getBlockID~% = CVI(BlockHashTable_Code(Hash~%%)): Exit Function
    Search~% = ListStringSearch(BlockHashTable_List(Hash~%%), BlockName$)
    If Search~% = 0 Then Write_Log "[getBlockID(" + BlockName$ + ")]: Error: Block not found!": Exit Function
    getBlockID~% = CVI(Mid$(BlockHashTable_Code(Hash~%%), 2 * Search~% - 1, 2))
End Function
Function getHeight~%% (X As Long, Z As Long) Static
    Dim As _Unsigned Integer SX, SZ
    SX = Seed: SZ = _SHR(Seed, 16)
    L! = fractal2(X - SX, Z - SZ, 256, 0, 0)
    H! = fractal2(X - SX, Z - SZ, 64, 2, 1)
    I! = fractal2(X - SX, Z - SZ, 256, 0, 2)
    N! = interpolate(L!, H!, I!)
    getHeight~%% = N! * 256
End Function
Function LoadAsset& (FILE$)
    If _FileExists("assets/blocks/" + FILE$ + ".png") Then LoadAsset& = _LoadImage("assets/blocks/" + FILE$ + ".png", 32): Exit Function
    Write_Log "Cannot Load: " + FILE$
End Function
Sub Write_Log (Log$)
    If Asc(Log$, 1) = 1 Then T$ = ListStringPrint(Log$) Else T$ = Log$
    _Echo T$
    If LogFile Then Print #100, T$
End Sub
Sub File_Log (Log$)
    If Asc(Log$, 1) = 1 Then T$ = ListStringPrint(Log$) Else T$ = Log$
    If LogFile Then Print #100, T$
End Sub
Sub PrintString (X As Integer, Y As Integer, T$, Colour As Long) Static
    Dim As _Unsigned Long I
    For I = 1 To Len(T$)
        B~%% = Asc(T$, I)
        __Y~% = _SHR(B~%%, 4)
        __X~% = B~%% - _SHL(__Y~%, 4)
        DrawBitPackPart Font, X + (I - 1) * 16, Y, Colour, _SHL(__X~%, 4), _SHL(__Y~%, 4), _SHL(__X~%, 4) + 15, _SHL(__Y~%, 4) + 15
    Next I
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
'-----------------
Function IIFString$ (A~%%, B$, C$)
    If A~%% Then IIFString$ = B$ Else IIFString$ = C$
End Function
