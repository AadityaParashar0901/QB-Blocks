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
Texture = _NewImage(TEXTURESIZE, TEXTURESIZE * IMAGEHEIGHT, 32)
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
        _PutImage (0, (I - 1) * TEXTURESIZE)-(TEXTURESIZE - 1, I * TEXTURESIZE - 1), IMG&, Texture
        _FreeImage IMG&
    End If
    If I >= TOTALTEXTURES * 6 Then Exit Do
Loop
Close #1
Cross = _LoadImage("assets/gui/cross.png", 32)
SunTexture = _LoadImage("assets/environment/sun.png", 32)
MoonTexture = _LoadImage("assets/environment/moon.png", 32)
CloudTexture = _LoadImage("assets/environment/clouds.png", 32)
$If GL Then
    __GL_Generate_Texture = -1: While __GL_Generate_Texture = -1: Wend
$End If
