Dim Shared As Long TextureAtlas
Dim Shared As _Unsigned Integer TextureSize, TotalTextures, TotalBlocks
Dim As String FileContents
'    Hash Table for getBlockID
Dim Shared As String BlockHashTable_List(0 To 255)
Dim Shared As _Unsigned Integer BlockHashTable_Length(0 To 255)
Dim Shared As String BlockHashTable_Code(0 To 255)
'AssetsParser
Open "assets\assets.list" For Binary As #1
FileContents = String$(LOF(1), 0)
Get #1, , FileContents
Close #1
FileContents = Tokenizer$(FileContents)
Write_Log "Assets: " + ListStringPrint(FileContents)
CurrentMode = 0
For I = 1 To ListStringLength(FileContents)
    CurrentListElement$ = ListStringGet(FileContents, I)
    Select Case CurrentMode
        Case 0: Select Case CurrentListElement$
                Case "texture_size": I = I + 2
                    TextureSize = Val(ListStringGet(FileContents, I))
                    Write_Log "Texture Size:" + Str$(TextureSize)
                Case "textures": CurrentMode = 1: I = I + 1
                    Type TextureData
                        As String Name
                        As Long Handle
                        As _Unsigned _Byte AnimationFrames
                        As _Unsigned Integer Y
                    End Type
                    ReDim Shared Textures(0) As TextureData
                    CurrentTextureID = 0: TextureMode = 0
                    Y~% = 0
                Case "blocks": CurrentMode = 2: I = I + 1
                    Type BlockData
                        As String Name
                        As String * 6 Faces
                        As _Unsigned _Byte Transparent
                    End Type
                    ReDim Shared Blocks(0) As BlockData
                    ReDim Shared isTransparent(0) As _Unsigned _Bit
                    ReDim Shared omitBlockFace(0, 0 To 5) As _Unsigned _Bit
                    isTransparent(0) = 1
                    omitBlockFace(0, 0) = 1
                    omitBlockFace(0, 1) = 1
                    omitBlockFace(0, 2) = 1
                    omitBlockFace(0, 3) = 1
                    omitBlockFace(0, 4) = 1
                    omitBlockFace(0, 5) = 1
                    CurrentBlockID = 0: BlockMode = 0
                Case ";"
            End Select
        Case 1
            Select Case CurrentListElement$
                Case ";": TextureMode = 0
                Case "}": If TextureMode = 0 Then CurrentMode = 0
                Case ","
                Case "animate": I = I + 2: Textures(CurrentTextureID).AnimationFrames = Val(ListStringGet(FileContents, I))
                    Y~% = Y~% + Textures(CurrentTextureID).AnimationFrames - 1
                Case Else: Write_Log "Loading Texture(" + ByteToHex$(CurrentTextureID) + "): " + CurrentListElement$
                    If TextureMode Then _Continue
                    CurrentTextureID = CurrentTextureID + 1: TextureMode = 1
                    ReDim _Preserve Shared Textures(1 To CurrentTextureID) As TextureData
                    Textures(CurrentTextureID).Handle = LoadAsset(CurrentListElement$)
                    Textures(CurrentTextureID).Y = Y~%
                    Y~% = Y~% + 1
                    Textures(CurrentTextureID).Name = CurrentListElement$
                    TextureMode = 1
            End Select
        Case 2
            Select Case CurrentListElement$
                Case ";": BlockMode = 0
                Case "}": If BlockMode = 0 Then CurrentMode = 0
                Case "name": I = I + 2
                    CurrentBlockID = CurrentBlockID + 1
                    ReDim _Preserve Shared Blocks(1 To CurrentBlockID) As BlockData
                    ReDim _Preserve Shared isTransparent(0 To CurrentBlockID) As _Unsigned _Bit
                    ReDim _Preserve Shared omitBlockFace(0 To CurrentBlockID, 0 To 5) As _Unsigned _Bit
                    Blocks(CurrentBlockID).Name = RemoveDoubleQoutes$(ListStringGet(FileContents, I))
                    BlockMode = 1
                    Write_Log "Block Name(" + ByteToHex$(CurrentBlockID) + "): " + Blocks(CurrentBlockID).Name
                Case "textures": If BlockMode = 0 Then _Continue
                    I = I + 2
                    Select Case ListStringGet(FileContents, I)
                        Case "[": For J = 1 To 6
                                Asc(Blocks(CurrentBlockID).Faces, J) = Val(ListStringGet(FileContents, I + J * 2 - 1))
                            Next J
                            I = I + 11
                        Case Else
                            Blocks(CurrentBlockID).Faces = String$(6, Val(ListStringGet(FileContents, I)))
                    End Select
                    Write_Log "Block Textures: " + Str$(Asc(Blocks(CurrentBlockID).Faces, 1)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 2)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 3)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 4)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 5)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 6))
                Case "transparent": If BlockMode = 0 Then _Continue
                    Blocks(CurrentBlockID).Transparent = -1
                    isTransparent(CurrentBlockID) = 1
                    Write_Log "Block is transparent"
                Case "omit": If BlockMode = 0 Then _Continue
                    Select Case ListStringGet(FileContents, I + 2)
                        Case "[": I = I + 2: For J = 0 To 5
                                omitBlockFace(CurrentBlockID, J) = Val(ListStringGet(FileContents, I + J * 2 + 1))
                            Next J
                            I = I + 11
                        Case Else
                            For J = 0 To 5: omitBlockFace(CurrentBlockID, J) = 1: Next J
                    End Select
                    Write_Log "Omit Block Face: " + Str$(omitBlockFace(CurrentBlockID, 0)) + Str$(omitBlockFace(CurrentBlockID, 1)) + Str$(omitBlockFace(CurrentBlockID, 2)) + Str$(omitBlockFace(CurrentBlockID, 3)) + Str$(omitBlockFace(CurrentBlockID, 4)) + Str$(omitBlockFace(CurrentBlockID, 5))
            End Select
    End Select
Next I
TotalTextures = UBound(Textures): Write_Log "Total Textures:" + Str$(TotalTextures)
TotalBlocks = UBound(Blocks): Write_Log "Total Blocks:" + Str$(TotalBlocks)
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
_Dest TextureAtlas: Cls , &HFF000000: _Dest 0
For I = 1 To TotalTextures
    _PutImage (0, TextureSize * Textures(I).Y), Textures(I).Handle, TextureAtlas
    _FreeImage Textures(I).Handle
Next I

GL_CURRENT_STATE = CONST_GL_STATE_CREATE_TEXTURES
While GL_CURRENT_STATE: Wend
