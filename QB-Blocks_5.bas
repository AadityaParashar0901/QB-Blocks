$Color:32
$Console
$Resize:On
'$Dynamic

_Console On

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
Const WaterLevel = 63
'---------------------------
Const MaxRenderDistanceX = MaxRenderDistance + 1
Const MaxRenderDistanceY = -(MaxRenderDistance <= 8) * (MaxRenderDistance + 1) - (MaxRenderDistance > 8) * 9
Const MaxRenderDistanceZ = MaxRenderDistance + 1
Const MaxChunks = MaxRenderDistance * MaxRenderDistance * MaxRenderDistance
Const MaxRenderPipelineSize = MaxChunks * 12288
Const ChunkDataSize = 12288
'    Chunk Size: 16 x 16 x 16
'    in the best case, where all the faces of a chunk are visible: 8 * 8 * 8 blocks
'    for each face (6), each vertex (4) -> 8 * 8 * 8 * 6 * 4 = 12288
'    Approx Memory Usage per Chunk (of RenderData ONLY)
'        Vertices: 2 * 3, TextureCoords: 4 * 2, Colors: 1 * 3 => 14
'        17 * 12288 / 1024 -> 204 KiB
'    Calculated: RenderDistance | Total Memory Usage
'                      16       |        518 MiB (0.50 GiB)
'                      24       |       1120 MiB (1.09 GiB)
'                      32       |       1952 MiB (1.90 GiB)

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, RenderDistance
Dim Shared As _Unsigned _Byte RenderDistanceX, RenderDistanceY, RenderDistanceZ
Fov = 70
Fog = -1
RenderDistance = 8
RenderDistanceX = RenderDistance
RenderDistanceY = Min(RenderDistance, 8)
RenderDistanceZ = RenderDistance
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
'----------

'--- Chunks ---
Type Chunk
    As _Unsigned _Byte DataLoaded 'bits: 1 - Chunk, 0 - Render
    As _Unsigned Integer VerticesCount, TransparentVerticesCount
End Type
Dim Shared As Chunk Chunks(1 To MaxChunks)
Type ChunkData
    As _Unsigned _Byte Block, State, Visibility, Face, Light
End Type
Dim Shared As ChunkData ChunksData(0 To 17, 0 To 17, 0 To 17, 1 To MaxChunks)

Const ChunkLoadQueueSize = 1024
Type ChunkLoadQueue
    As _Unsigned Integer ChunkID
    As Long X, Y, Z
End Type
Dim Shared As ChunkLoadQueue ChunkLoadQueue(0 To ChunkLoadQueueSize - 1)
Dim Shared As _Unsigned _Bit * 10 NewChunkLoadQueuePointer, CurrentChunkLoadQueuePointer
'--------------

'--- Player ---
Dim Shared As Entity Player
'    Initialize Player
Player.Speed = 4
Player.MaxHealth = 10
Player.Health = Player.MaxHealth
'--------------

'--- Camera & Sky ---
'    Camera
Type Camera
    As Vec3_Float Position, FinalPosition
End Type
Dim Shared As Camera Camera
Dim Shared As _Unsigned _Byte CinematicCamera
'    Clouds
'    Sun
'    Moon
'    Sky
Dim Shared As Long SkyColor
Dim Shared SkyColorRed~%%, SkyColorGreen~%%, SkyColorBlue~%%
Dim Shared SkyColorRed!, SkyColorGreen!, SkyColorBlue!
SkyColor = _RGB32(0, 127, 255)
SkyColorRed~%% = _Red32(SkyColor)
SkyColorGreen~%% = _Green32(SkyColor)
SkyColorBlue~%% = _Blue32(SkyColor)
SkyColorRed! = SkyColorRed~%% / 255
SkyColorGreen! = SkyColorGreen~%% / 255
SkyColorBlue! = SkyColorBlue~%% / 255
'--------------------

'--- Screen ---
Screen _NewImage(640, 480, 32)
Color White, _RGB32(0, 127)
While _Resize: Wend
'--------------

'--- Assets ---
Dim Shared As Long TextureAtlas
Dim Shared As _Unsigned Integer TextureSize, TotalTextures, TotalBlocks
Dim As String FileContents
'$Include:'AssetsParser.bas'
TextureAtlas = _NewImage(TextureSize, TotalTextures * TextureSize, 32)
For I = 1 To TotalTextures
    _PutImage (0, (I - 1) * TextureSize)-(TextureSize - 1, I * TextureSize - 1), Textures(I), TextureAtlas
    _FreeImage Textures(I)
Next I
GL_CURRENT_STATE = CONST_GL_STATE_CREATE_TEXTURES
While GL_CURRENT_STATE: Wend
'--------------

'--- Font ---
Dim Shared Font As String
Font = LoadBitPack("assets/font/ascii.bpc")
'------------

'--- FPS ---
Dim Shared As _Unsigned Integer LFPS, LFPSCount, GFPS, GFPSCount
Dim As Long FPSCounterTimer
FPSCounterTimer = _FreeTimer
On Timer(FPSCounterTimer, 1) GoSub FPSCounter
Timer(FPSCounterTimer) On
'-----------

'--- Start Game ---
GL_CURRENT_STATE = CONST_GL_STATE_GAMEPLAY
GL_EXTRA_STATE = CONST_GL_STATE_SHOW_FPS

'    Debug
ChunkLoadQueue(0).ChunkID = 1
ChunkLoadQueue(0).X = 0
ChunkLoadQueue(0).Y = 0
ChunkLoadQueue(0).Z = 0
'    -----

Do
    On Error GoTo ErrHandler
    _Limit 60
    If _Resize Then
        tmpScreenWidth = _ResizeWidth
        tmpScreenHeight = _ResizeHeight
        If tmpScreenWidth > 0 And tmpScreenHeight > 0 Then
            Screen _NewImage(tmpScreenWidth, tmpScreenHeight, 32)
            Color White, _RGB32(0, 127)
        End If
    End If
    While _MouseInput
        Select Case GL_CURRENT_STATE
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
        Case CONST_GL_STATE_GAMEPLAY
            SimulateCamera
            '--- Movement ---
            If _KeyDown(87) Or _KeyDown(119) Then MoveEntity Player, Player.Angle.X - 90, Player.Speed / LFPS
            If _KeyDown(83) Or _KeyDown(115) Then MoveEntity Player, Player.Angle.X + 90, Player.Speed / LFPS
            If _KeyDown(65) Or _KeyDown(97) Then MoveEntity Player, Player.Angle.X - 180, Player.Speed / LFPS
            If _KeyDown(68) Or _KeyDown(100) Then MoveEntity Player, Player.Angle.X, Player.Speed / LFPS
            If _KeyDown(32) Then Player.Position.Y = Player.Position.Y + Player.Speed / LFPS
            If _KeyDown(100304) Then Player.Position.Y = Player.Position.Y - Player.Speed / LFPS
            If _KeyDown(100306) Then Player.Speed = 64 Else Player.Speed = 4
            Select Case _KeyHit
                Case 27: Exit Do 'GL_CURRENT_STATE = CONST_GL_STATE_PAUSE_MENU
            End Select
            '----------------
            '--- Chunk Coordinates ---
            Dim Shared As Vec3_Long PlayerChunk, oldPlayerChunk
            Dim Shared As Vec3_Byte PlayerInChunk, oldPlayerInChunk
            PlayerChunk.X = _SHR(Camera.Position.X, 4)
            PlayerChunk.Y = _SHR(Camera.Position.Y, 4)
            PlayerChunk.Z = _SHR(Camera.Position.Z, 4)
            PlayerInChunk.X = Int(Camera.Position.X - _SHL(PlayerChunkX, 4))
            PlayerInChunk.Y = Int(Camera.Position.Y - _SHL(PlayerChunkY, 4))
            PlayerInChunk.Z = Int(Camera.Position.Z - _SHL(PlayerChunkZ, 4))
            '-------------------------
    End Select
    '--- Load Chunks ---
    If ChunkLoadQueue(CurrentChunkLoadQueuePointer).ChunkID Then
        ChunkID = ChunkLoadQueue(CurrentChunkLoadQueuePointer).ChunkID
        PX = ChunkLoadQueue(CurrentChunkLoadQueuePointer).X * 16
        PY = ChunkLoadQueue(CurrentChunkLoadQueuePointer).Y * 16
        PZ = ChunkLoadQueue(CurrentChunkLoadQueuePointer).Z * 16
        Select Case Chunks(ChunkID).DataLoaded
            Case 0 'Load Chunk Data
                For X = 0 To 17
                    For Y = 0 To 17
                        For Z = 0 To 17
                            Select Case PY + Y
                                Case 8: ChunksData(X, Y, Z, ChunkID).Block = 1
                                Case Is < 8: ChunksData(X, Y, Z, ChunkID).Block = 2
                                Case Else: ChunksData(X, Y, Z, ChunkID).Block = 0
                            End Select
                Next Z, Y, X
                Write_Log "Chunk Data Loaded"
                Chunks(ChunkID).DataLoaded = Chunks(ChunkID).DataLoaded Or 2
            Case 2 'Load Render Data
                VertexID = ChunkDataSize * (ChunkID - 1)
                Chunks(ChunkID).VerticesCount = 0
                For X = 1 To 16
                    For Y = 1 To 16
                        For Z = 1 To 16
                            CurrentBlock = ChunksData(X, Y, Z, ChunkID).Block
                            If CurrentBlock = 0 Then _Continue
                            ChunksData(X, Y, Z, ChunkID).Visibility = isTransparent(ChunksData(X + 1, Y, Z, ChunkID).Block) Or _SHL(isTransparent(ChunksData(X - 1, Y, Z, ChunkID).Block), 1) Or _SHL(isTransparent(ChunksData(X, Y + 1, Z, ChunkID).Block), 2) Or _SHL(isTransparent(ChunksData(X, Y - 1, Z, ChunkID).Block), 3) Or _SHL(isTransparent(ChunksData(X, Y, Z + 1, ChunkID).Block), 4) Or _SHL(isTransparent(ChunksData(X, Y, Z - 1, ChunkID).Block), 5)
                            Dim As _Unsigned _Byte Face
                            For I = 0 To 23
                                Face = _SHL(1, _SHR(I, 2))
                                If (ChunksData(X, Y, Z, ChunkID).Visibility And Face) = 0 Then _Continue
                                TextureID = Asc(Blocks(CurrentBlock).Faces, _SHR(I, 2) + 1) - 1
                                Vertices(VertexID).X = X + CubeVertices(I).X
                                Vertices(VertexID).Y = Y + CubeVertices(I).Y
                                Vertices(VertexID).Z = Z + CubeVertices(I).Z
                                TextureCoords(VertexID).X = CubeTextureCoords(I).X
                                TextureCoords(VertexID).Y = (CubeTextureCoords(I).Y + TextureID) / TotalTextures
                                Colors(VertexID).X = 255
                                Colors(VertexID).Y = Colors(VertexID).X
                                Colors(VertexID).Z = Colors(VertexID).X
                                Chunks(ChunkID).VerticesCount = Chunks(ChunkID).VerticesCount + 1
                                VertexID = VertexID + 1
                            Next I
                Next Z, Y, X
                Write_Log "Render Data Loaded:" + Str$(Chunks(ChunkID).VerticesCount)
                Chunks(ChunkID).DataLoaded = Chunks(ChunkID).DataLoaded Or 1
            Case 3: ChunkLoadQueue(CurrentChunkLoadQueuePointer).ChunkID = 0
                CurrentChunkLoadQueuePointer = CurrentChunkLoadQueuePointer + 1
        End Select
    Else
        CurrentChunkLoadQueuePointer = CurrentChunkLoadQueuePointer + 1
    End If
    '-------------------
    If _Exit Then Exit Do
    LFPSCount = LFPSCount + 1
Loop
'------------------
'--- Free Assets ---
GL_CURRENT_STATE = CONST_GL_STATE_FREE_ASSETS
While GL_CURRENT_STATE: Wend
System
'-------------------

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
End Sub
Sub _GL
    Static As Long GL_TextureAtlas_Handle
    On Error GoTo GLErrHandler
    Select Case GL_CURRENT_STATE
        Case 0
        Case CONST_GL_STATE_CREATE_TEXTURES
            Write_Log "Generating GL Textures"
            GL_Generate_Texture GL_TextureAtlas_Handle, TextureAtlas
            GL_CURRENT_STATE = 0
        Case CONST_GL_STATE_STARTUP_MENU

        Case CONST_GL_STATE_GAMEPLAY
            _glViewport 0, 0, _Width - 1, _Height - 1
            _glEnable _GL_DEPTH_TEST
            _glClearColor SkyColorRed!, SkyColorGreen!, SkyColorBlue!, 1
            _glClear _GL_DEPTH_BUFFER_BIT Or _GL_COLOR_BUFFER_BIT
            _glTranslatef 0, 0, 0
            _glRotatef Player.Angle.Y, 1, 0, 0
            _glRotatef Player.Angle.X, 0, 1, 0
            _glTranslatef -Camera.Position.X, -Camera.Position.Y, -Camera.Position.Z
            _glMatrixMode _GL_PROJECTION
            _glLoadIdentity
            _gluPerspective Fov, _Width / _Height, 0.01, 1024
            _glMatrixMode _GL_MODELVIEW
            _glEnable _GL_TEXTURE_2D
            _glBindTexture _GL_TEXTURE_2D, GL_TextureAtlas_Handle
            _glEnableClientState _GL_VERTEX_ARRAY
            _glEnableClientState _GL_TEXTURE_COORD_ARRAY
            _glEnableClientState _GL_COLOR_ARRAY
            For I = 1 To MaxChunks
                If Chunks(I).VerticesCount = 0 And (Chunks(I).DataLoaded And 1) = 0 Then _Continue
                J = I - 1
                _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(ChunkDataSize * J))
                _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TextureCoords(ChunkDataSize * J))
                _glColorPointer 3, _GL_UNSIGNED_BYTE, 0, _Offset(Colors(ChunkDataSize * J))
                _glDrawArrays _GL_QUADS, 0, Chunks(I).VerticesCount
            Next I
            _glDisableClientState _GL_COLOR_ARRAY
            _glDisableClientState _GL_TEXTURE_COORD_ARRAY
            _glDisableClientState _GL_VERTEX_ARRAY
            _glDisable _GL_TEXTURE_2D
            _glDisable _GL_DEPTH_TEST
            _glFlush
        Case CONST_GL_STATE_FREE_ASSETS
            Write_Log "Freeing GL Textures"
            _glDeleteTextures 1, _Offset(GL_TextureAtlas_Handle)
            GL_CURRENT_STATE = 0
    End Select
    Select Case GL_EXTRA_STATE
        Case CONST_GL_STATE_SHOW_FPS
            Cls 2, 0
            PrintString 0, 0, "FPS (G/L):" + Str$(GFPS) + "," + Str$(LFPS), White
            PrintString 0, 16, "Player Position:" + Str$(Player.Position.X) + Str$(Player.Position.Y) + Str$(Player.Position.Z), White
            PrintString 0, 32, "Player Angle:" + Str$(Player.Angle.X) + Str$(Player.Angle.Y), White
            _Display
    End Select
    GFPSCount = GFPSCount + 1
End Sub
Function LoadAsset& (FILE$)
    If _FileExists("assets/blocks/" + FILE$ + ".png") Then LoadAsset& = _LoadImage("assets/blocks/" + FILE$ + ".png", 32)
End Function
Sub Write_Log (Log$)
    If Asc(Log$, 1) = 1 Then _Echo ListStringPrint(Log$) Else _Echo Log$
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
'$Include:'lib\GL_Generate_Texture.bas'
'$Include:'lib\Tokenizer.bas'
'$Include:'lib\LoadBitPack.bm'
'$Include:'lib\DrawBitPackPart.bm'
'$Include:'lib\clamp.bm'
'$Include:'lib\iif.bm'
'$Include:'lib\inrange.bm'
'$Include:'lib\interpolate.bm'
'$Include:'lib\max.bm'
'$Include:'lib\min.bm'
'$Include:'lib\modfloor.bm'
'$Include:'lib\transitangle.bm'
'-----------------
