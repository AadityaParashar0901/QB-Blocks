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

TMPTexture = _NewImage(64, 64, 32)
_Dest TMPTexture
For X = 0 To 63
    For Y = 0 To 63
        If X Xor Y Then PSet (X, Y), _RGB32(0, 127, 255) Else PSet (X, Y), _RGB32(255, 127, 0)
Next Y, X
_Dest 0

Texture = _CopyImage(TMPTexture, 32)
_FreeImage TMPTexture
While Texture: Wend

Dim Shared As _Unsigned Integer LFPS, GFPS, LFPSCount, GFPSCount: LFPS = 60

F = _FreeTimer
On Timer(F, 1) GoSub FPSCounter
Timer(F) On

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
    _glBegin _GL_QUADS
    _glVertex3f -2, 2, 0
    _glTexCoord2f 0, 1
    _glVertex3f -2, -2, 0
    _glTexCoord2f 0, 0
    _glVertex3f 2, -2, 0
    _glTexCoord2f 1, 0
    _glVertex3f 2, 2, 0
    _glTexCoord2f 1, 1
    _glEnd
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
