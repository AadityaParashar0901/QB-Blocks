'BiomesParser
Dim Shared As String BiomesList
BiomesList = ListMapNew$
Open "assets\biomes.list" For Binary As #1
FileContents = String$(LOF(1), 0)
Get #1, , FileContents
Close #1
FileContents = Tokenizer$(FileContents)
CurrentMode = 0
For I = 1 To ListStringLength(FileContents)
    CurrentListElement$ = ListStringGet(FileContents, I)
    Select Case CurrentMode
        Case 0: Select Case CurrentListElement$
                Case "biomes": CurrentMode = 1: I = I + 1
            End Select
        Case 1: Select Case CurrentListElement$
                Case "name": I = I + 2
                    Biome$ = MapNew$
                    MapSetKey Biome$, "name", RemoveDoubleQuotes$(ListStringGet(FileContents, I))
                Case "surface_block", "under_surface_block", "underground_block", "height_bias", "excited_height_bias", "biome_smoothness", "tree_log", "tree_leaves": I = I + 2
                    MapSetKey Biome$, CurrentListElement$, RemoveDoubleQuotes$(ListStringGet(FileContents, I))
                Case "tree_height": I = I + 2
                    MapSetKey Biome$, "tree_height_lower_limit", ListStringGet(FileContents, I)
                    If ListStringGet(FileContents, I + 1) = "~" Then
                        I = I + 2
                        T$ = ListStringGet(FileContents, I)
                        MapSetKey Biome$, "tree_height_upper_limit", ListStringGet(FileContents, I)
                    End If
                Case ","
                Case ";": ListMapAddMap BiomesList, Biome$
                Case "}": CurrentMode = 0
            End Select
    End Select
Next I
Write_Log "Biomes: " + ListMapPrint(BiomesList)
Dim Shared TotalBiomes As _Unsigned Integer
TotalBiomes = ListMapLength(BiomesList)
Write_Log "Total Biomes = " + Hex$(TotalBiomes)
Dim Shared As _Unsigned _Byte BiomeBlocks(0 To 2, 0 To TotalBiomes - 1)
Dim Shared As _Unsigned Integer BiomeHeightBias(0 To TotalBiomes)
Dim Shared As _Unsigned Integer BiomeExcitedHeightBias(0 To TotalBiomes)
Dim Shared As _Unsigned Integer BiomeSmoothness(0 To TotalBiomes)
Write_Log "Biome Properties:"
For I = 0 To TotalBiomes - 1
    BiomeBlocks(0, I) = getBlockID(ListMapGet(BiomesList, I + 1, "surface_block"))
    BiomeBlocks(1, I) = getBlockID(ListMapGet(BiomesList, I + 1, "under_surface_block"))
    BiomeBlocks(2, I) = getBlockID(ListMapGet(BiomesList, I + 1, "underground_block"))
    BiomeHeightBias(I) = Val(ListMapGet(BiomesList, I + 1, "height_bias"))
    BiomeExcitedHeightBias(I) = Val(ListMapGet(BiomesList, I + 1, "excited_height_bias"))
    BiomeSmoothness(I) = Val(ListMapGet(BiomesList, I + 1, "biome_smoothness"))
    Write_Log ListMapGet(BiomesList, I + 1, "name") + ": " + Str$(BiomeHeightBias(I)) + Str$(BiomeExcitedHeightBias(I)) + Str$(BiomeSmoothness(I))
Next I
BiomeHeightBias(I) = BiomeHeightBias(I - 1)
BiomeExcitedHeightBias(I) = BiomeExcitedHeightBias(I - 1)
BiomeSmoothness(I) = BiomeSmoothness(I - 1)
