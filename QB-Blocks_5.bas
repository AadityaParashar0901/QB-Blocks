$Console
$Resize:On
'$Dynamic

_Console On

DefLng A-Z

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
'---------------------------
Const MaxChunks = MaxRenderDistance * MaxRenderDistance * MaxRenderDistance
Const MaxRenderPipelineSize = MaxChunks * 12288
'    Chunk Size: 16 x 16 x 16
'    in the best case, where all the faces of a chunk are visible: 8 * 8 * 8 blocks
'    for each face (6), each vertex (4) -> 8 * 8 * 8 * 6 * 4 = 12288
'    Approx Memory Usage per Chunk
'        Vertices: 2 * 3, TextureCoords: 4 * 2, Colors: 4 * 3 => 26
'        26 * 12288 / 1024 -> 312 KiB

'--- Game Default Settings ---
Dim Shared As _Unsigned _Byte Fov, Fog, RenderDistance
Fov = 70
Fog = -1
RenderDistance = 8
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
Dim Shared Colors(0 To MaxRenderPipelineSize - 1) As Vec3_Float
Restore CubeModel
For I = 0 To 23
    Read Vertices(I).X, Vertices(I).Y, Vertices(I).Z
    Read TextureCoords(I).X, TextureCoords(I).Y
    Colors(I).X = 1: Colors(I).Y = 1: Colors(I).Z = 1
Next I
'----------

'--- Chunks ---
Type Chunk
    As _Unsigned _Byte ChunkDataLoaded, RenderDataLoaded
    As _Unsigned _Byte VerticesCount, TransparentVerticesCount
End Type
Dim Shared As Chunk Chunks(1 To MaxChunks)
Type ChunkData
    As _Unsigned _Byte Block, State, Visibility, Face
End Type
Dim Shared As ChunkData ChunksData(1 To MaxChunks)

Const ChunkLoadQueueSize = 1024
Dim Shared As _Unsigned Integer ChunkLoadQueue(0 To ChunkLoadQueueSize - 1)
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
Color _RGB32(255), _RGB32(0, 127)
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
Font$ = LoadBitPack("assets/font/ascii.bpc")
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
Do
    On Error GoTo ErrHandler
    _Limit 60
    If _Resize Then
        tmpScreenWidth = _ResizeWidth
        tmpScreenHeight = _ResizeHeight
        If tmpScreenWidth > 0 And tmpScreenHeight > 0 Then
            Screen _NewImage(tmpScreenWidth, tmpScreenHeight, 32)
            Color _RGB32(255), _RGB32(0, 127)
        End If
    End If
    While _MouseInput
        Select Case GL_CURRENT_STATE
            Case CONST_GL_STATE_GAMEPLAY
                _MouseHide
                Player.Angle.X = ClampCycle(0, Player.Angle.X + _MouseMovementX, 360)
                Player.Angle.Y = Clamp(-90, Player.Angle.Y + _MouseMovementY, 90)
                _MouseMove _Width / 2, _Height / 2
        End Select
    Wend
    Select Case GL_CURRENT_STATE
        Case CONST_GL_STATE_STARTUP_MENU

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
            '--- Load Chunks ---
            If ChunkLoadQueue(CurrentChunkLoadQueuePointer) Then

            Else
                CurrentChunkLoadQueuePointer = CurrentChunkLoadQueuePointer + 1
            End If
            '-------------------
    End Select
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
            _glTranslatef 0, 0, -5
            _glRotatef Player.Angle.Y, 1, 0, 0
            _glRotatef Player.Angle.X, 0, 1, 0
            _glTranslatef -Camera.Position.X, -Camera.Position.Y, -Camera.Position.Z
            _glMatrixMode _GL_PROJECTION
            _glLoadIdentity
            _gluPerspective Fov, _Width / _Height, 0.1, 1024
            _glMatrixMode _GL_MODELVIEW
            _glEnable _GL_TEXTURE_2D
            _glBindTexture _GL_TEXTURE_2D, GL_TextureAtlas_Handle
            _glEnableClientState _GL_VERTEX_ARRAY
            _glEnableClientState _GL_TEXTURE_COORD_ARRAY
            _glEnableClientState _GL_COLOR_ARRAY
            _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices())
            _glTexCoordPointer 2, _GL_FLOAT, 0, _Offset(TextureCoords())
            _glColorPointer 3, _GL_FLOAT, 0, _Offset(Colors())
            _glDrawArrays _GL_QUADS, 0, 24
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
            _PrintString (0, 0), "FPS (G/L):" + Str$(GFPS) + "," + Str$(LFPS)
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
'--- Libraries ---
'$Include:'lib\GL_Generate_Texture.bas'
'$Include:'lib\Tokenizer.bas'
'$Include:'lib\bitpack_image.bm'
'$Include:'lib\clamp.bm'
'$Include:'lib\iif.bm'
'$Include:'lib\inrange.bm'
'$Include:'lib\interpolate.bm'
'$Include:'lib\max.bm'
'$Include:'lib\min.bm'
'$Include:'lib\modfloor.bm'
'$Include:'lib\transitangle.bm'
'-----------------
