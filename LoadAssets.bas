Print "Generating Textures"
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
Dim Shared As _Unsigned Long TOTALTEXTURES, IMAGEHEIGHT

Dim Shared As Long Texture, SunTexture, MoonTexture, CloudTexture, Cross, FontImage
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
Do
    Line Input #1, L$
    If Left$(L$, 2) = "//" Then _Continue
    Select Case L$
        Case "totaltextures"
            Line Input #1, L$
            TOTALTEXTURES = Val(L$)
            IMAGEHEIGHT = TEXTURESIZE * TOTALTEXTURES
            Texture = _NewImage(TEXTURESIZE, IMAGEHEIGHT, 32)
        Case "textures {"
            CurrentTextures = 0
            Do
                Line Input #1, L$
                If Left$(L$, 2) = "//" Then _Continue
                Select Case L$
                    Case "}": Exit Do
                    Case Else: CurrentTexture = CurrentTexture + 1: IMG& = LoadImage("assets/blocks/" + L$)
                        _PutImage (0, (CurrentTexture - 1) * TEXTURESIZE)-(TEXTURESIZE - 1, CurrentTexture * TEXTURESIZE - 1), IMG&, Texture, (0, 0)-(TEXTURESIZE - 1, TEXTURESIZE - 1)
                        _FreeImage IMG&
                End Select
            Loop
        Case "blocks {"
            Dim BlockName As String
            Do
                Line Input #1, L$
                If Left$(L$, 2) = "//" Then _Continue
                Select Case L$
                    Case "}": Exit Do
                    Case Else:
                        Select Case Left$(L$, InStr(L$, " ") - 1)
                            Case "totalblocks"
                                TotalBlocks = Val(Mid$(L$, 13))
                                CurrentBlock = 0
                                Dim Shared As Long BlockFaces(1 To TotalBlocks, 1 To 6)
                            Case "name"
                                BlockName = Mid$(L$, 6)
                                CurrentBlock = CurrentBlock + 1
                            Case "textures"
                                L$ = Mid$(L$, 10)
                                If Left$(L$, 1) = "[" Then
                                    nBlockFace = 0
                                    L$ = Mid$(L$, 2)
                                    Do
                                        nBlockFace = nBlockFace + 1
                                        BlockFaces(CurrentBlock, nBlockFace) = Val(L$) - 1
                                        L$ = Mid$(L$, InStr(L$, ",") + 1)
                                        If nBlockFace = 6 Then Exit Do
                                    Loop
                                Else
                                    For nBlockFace = 1 To 6
                                        BlockFaces(CurrentBlock, nBlockFace) = Val(L$) - 1
                                    Next nBlockFace
                                End If
                        End Select
                End Select
            Loop
        Case "end": Exit Do
    End Select
Loop
Cross = _LoadImage("assets/gui/cross.png", 32)
SunTexture = _LoadImage("assets/environment/sun.png", 32)
MoonTexture = _LoadImage("assets/environment/moon.png", 32)
CloudTexture = _LoadImage("assets/environment/clouds.png", 32)
$If GL Then
    __GL_Generate_Texture = -1: While __GL_Generate_Texture = -1: Wend
$End If
