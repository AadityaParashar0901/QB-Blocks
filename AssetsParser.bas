Open "assets\assets.list" For Binary As #1
FileContents = String$(LOF(1), 0)
Get #1, , FileContents
Close #1
FileContents = Tokenizer$(FileContents)
Write_Log FileContents
CurrentMode = 0
For I = 1 To ListStringLength(FileContents)
    CurrentListElement$ = ListStringGet(FileContents, I)
    Select Case CurrentMode
        Case 0: Select Case CurrentListElement$
                Case "texture_size": I = I + 2
                    TextureSize = Val(ListStringGet(FileContents, I))
                    Write_Log "Texture Size:" + Str$(TextureSize)
                Case "total_textures": I = I + 2
                    TotalTextures = Val(ListStringGet(FileContents, I))
                    ReDim Textures(1 To TotalTextures)
                    CurrentTextureID = 1
                    Write_Log "Total Textures:" + Str$(TotalTextures)
                Case "total_blocks": I = I + 2
                    Type BlockData
                        As String * 10 Name
                        As String * 6 Faces
                    End Type
                    TotalBlocks = Val(ListStringGet(FileContents, I))
                    ReDim Blocks(1 To TotalBlocks) As BlockData
                    CurrentBlockID = 1
                    Write_Log "Total Blocks:" + Str$(TotalBlocks)
                Case "textures": CurrentMode = 1: I = I + 1
                Case "blocks": CurrentMode = 2: I = I + 1
                Case ";"
            End Select
        Case 1: Select Case CurrentListElement$
                Case ";": CurrentTextureID = CurrentTextureID + 1
                Case "}": CurrentMode = 0
                Case Else: Write_Log "Loading Texture: " + CurrentListElement$: Textures(CurrentTextureID) = LoadAsset(CurrentListElement$)
            End Select
        Case 2: Select Case CurrentListElement$
                Case ";": CurrentBlockID = CurrentBlockID + 1
                Case ","
                Case "}": CurrentMode = 0
                Case "name": I = I + 2
                    Blocks(CurrentBlockID).Name = ListStringGet(FileContents, I)
                    Write_Log "Block Name: " + Blocks(CurrentBlockID).Name
                Case "textures": I = I + 2
                    Select Case ListStringGet(FileContents, I)
                        Case "[": For J = 1 To 6
                                Asc(Blocks(CurrentBlockID).Faces, J) = Val(ListStringGet(FileContents, I + J * 2 - 1))
                            Next J
                            I = I + 11
                        Case Else
                            Blocks(CurrentBlockID).Faces = String$(6, Val(ListStringGet(FileContents, I)))
                    End Select
                    Write_Log "Blocks Textures: " + Str$(Asc(Blocks(CurrentBlockID).Faces, 1)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 2)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 3)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 4)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 5)) + Str$(Asc(Blocks(CurrentBlockID).Faces, 6))
            End Select
    End Select
Next I
