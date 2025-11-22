'BiomesParser
Dim As String BiomesList
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
                    MapSetKey Biome$, "name", RemoveDoubleQoutes$(ListStringGet(FileContents, I))
                Case "tree_log": I = I + 2
                    MapSetKey Biome$, "tree_log", RemoveDoubleQoutes$(ListStringGet(FileContents, I))
                Case "tree_leaves": I = I + 2
                    MapSetKey Biome$, "tree_leaves", RemoveDoubleQoutes$(ListStringGet(FileContents, I))
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
