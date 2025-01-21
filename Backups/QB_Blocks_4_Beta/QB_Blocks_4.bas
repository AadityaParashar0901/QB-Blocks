$Resize:On
'$Dynamic

Type Vec2_Int
    As Integer X, Y
End Type
Type Vec2_Float
    As Single X, Y
End Type
Type Vec3_Int
    As Integer X, Y, Z
End Type
Type Vec3_Float
    As Single X, Y, Z
End Type
Type Player
    As Vec3_Float Position, Angle
    As _Unsigned Integer Health, MaxHealth
    As Long XP
    As _Byte isFlying, isSprinting
    As Single MoveSpeed, SprintSpeed, FlySpeed, FlySprintSpeed
End Type

Screen _NewImage(960, 540, 32)
_PrintMode _KeepBackground
_Title "QB Blocks 4"

$Let GL = -1

Dim Shared Texture As Long, allowGL As _Bit
Dim Shared Player As Player
Player.Health = 10: Player.MaxHealth = 10
Player.XP = 0
Player.isFlying = -1
Player.isSprinting = -1
Player.MoveSpeed = 4
Player.SprintSpeed = 6
Player.FlySpeed = 16
Player.FlySprintSpeed = 64

TMPTexture = _LoadImage("assets\texture_atlas.png", 32)

Texture = _CopyImage(TMPTexture, 32)
_FreeImage TMPTexture
While Texture: Wend

Dim Shared As _Unsigned Integer LFPS, GFPS, LFPSCount, GFPSCount: LFPS = 60

F = _FreeTimer
On Timer(F, 1) GoSub FPSCounter
Timer(F) On

Const MAXVERTICES = 1024
Dim Shared CubeModel(0 To 23) As Vec3_Int, CubeTexture(0 To 23) As Vec2_Float
Dim Shared As Vec3_Int Vertices(0 To MAXVERTICES - 1)
Dim Shared As Vec2_Float TexCoords(0 To MAXVERTICES - 1)

Restore CubeModel
For I = 0 To 23
    Read CubeModel(I).X, CubeModel(I).Y, CubeModel(I).Z, CubeTexture(I).X, CubeTexture(I).Y
    Vertices(I) = CubeModel(I)
    CubeTexture(I).X = CubeTexture(I).X / 16
    CubeTexture(I).Y = CubeTexture(I).Y / 16
    TexCoords(I) = CubeTexture(I)
Next I
CubeModel:
''$Include:'assets\models\cube.tedi'

Cls
_GLRender _Behind
allowGL = -1
Do
    _Limit 60
    LFPSCount = LFPSCount + 1
    If _Resize Then
        Screen _NewImage(_ResizeWidth, _ResizeHeight, 32)
        _PrintMode _KeepBackground
    End If
    Cls 2, 0
    Print "FPS (G/L):"; GFPS; "/"; LFPS
    _Display
Loop Until Inp(&H60) = 1
System

FPSCounter:
If LFPSCount Then LFPS = LFPSCount
LFPSCount = 0
GFPS = GFPSCount
GFPSCount = 0
Return
$If GL Then
    Sub _GL
        Static As Long TextureHandle
        If Texture < -1 Then GL_Generate_Texture TextureHandle, Texture
        If allowGL = 0 Then Exit Sub

        _glViewport 0, 0, _Width - 1, _Height - 1
        _glEnable _GL_DEPTH_TEST
        _glClearColor 0, 0, 0, 0
        _glClear _GL_DEPTH_BUFFER_BIT Or _GL_COLOR_BUFFER_BIT
        _glTranslatef 0, 0, -5
        _glRotatef Timer, 1, 0, 0
        _glRotatef 10 * Timer, 0, 1, 0
        _glMatrixMode _GL_PROJECTION
        _glLoadIdentity
        _gluPerspective 70, _Width / _Height, 0.1, 256
        _glMatrixMode _GL_MODELVIEW
        _glEnable _GL_TEXTURE_2D
        _glBindTexture _GL_TEXTURE_2D, TextureHandle
        _glEnableClientState _GL_VERTEX_ARRAY
        _glEnableClientState _GL_TEXTURE_COORD_ARRAY
        _glVertexPointer 3, _GL_SHORT, 0, _Offset(Vertices(0))
        _glTexCoordPointer 2, _GL_SHORT, 0, _Offset(TexCoords(0))
        _glDrawArrays _GL_QUADS, 0, 24
        _glDisableClientState _GL_TEXTURE_COORD_ARRAY
        _glDisableClientState _GL_VERTEX_ARRAY
        _glDisable _GL_TEXTURE_2D
        _glDisable _GL_DEPTH_TEST
        _glFlush
        GFPSCount = GFPSCount + 1
    End Sub
    Sub GL_Generate_Texture (Handle As Long, Image As Long)
        Dim M As _MEM
        _glGenTextures 1, _Offset(Handle)
        _glBindTexture _GL_TEXTURE_2D, Handle
        M = _MemImage(Image)
        _glTexImage2D _GL_TEXTURE_2D, 0, _GL_RGBA, _Width(Image), _Height(Image), 0, _GL_BGRA_EXT, _GL_UNSIGNED_BYTE, M.OFFSET
        _MemFree M
        _FreeImage Image
        Image = 0
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MIN_FILTER, _GL_NEAREST
        _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MAG_FILTER, _GL_NEAREST
    End Sub
$End If
