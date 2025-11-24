Sub RebuildChunkDataLoadQueue Static
    Static As Vec3_Long tmpChunksStart, tmpChunksEnd
    Static As Long I, X, Z
    Static ChunkID As _Unsigned Long
    ChunkDataLoadQueue = ""
    RenderDataLoadQueue = ""
    For R = 0 To RenderDistance
        tmpChunksStart.X = PlayerChunk.X - R
        tmpChunksStart.Z = PlayerChunk.Z - R
        tmpChunksEnd.X = PlayerChunk.X + R
        tmpChunksEnd.Z = PlayerChunk.Z + R
        For I = 0 To 3
            Select Case I
                Case 0: Z = tmpChunksStart.Z
                Case 1: X = tmpChunksStart.X
                Case 2: Z = tmpChunksEnd.Z
                Case 3: X = tmpChunksEnd.X: tmpChunksEnd.Z = tmpChunksEnd.Z - 1
            End Select
            Select Case I And 1
                Case 0: For X = tmpChunksStart.X + Sgn(I) To tmpChunksEnd.X
                        ChunkID = getChunkID(X, Z)
                        If Chunks(ChunkID).X <> X Or Chunks(ChunkID).Z <> Z Or Chunks(ChunkID).DataLoaded <> 255 Then
                            ChunkDataLoadQueue = ChunkDataLoadQueue + MKL$(X) + MKL$(Z)
                            If Chunks(ChunkID).DataLoaded = 255 Then
                                Chunks(ChunkID).DataLoaded = 0
                                TotalChunksLoaded = TotalChunksLoaded - 1
                            End If
                        End If
                    Next X
                Case 1: For Z = tmpChunksStart.Z + Sgn(I) To tmpChunksEnd.Z
                        ChunkID = getChunkID(X, Z)
                        If Chunks(ChunkID).X <> X Or Chunks(ChunkID).Z <> Z Or Chunks(ChunkID).DataLoaded <> 255 Then
                            ChunkDataLoadQueue = ChunkDataLoadQueue + MKL$(X) + MKL$(Z)
                            If Chunks(ChunkID).DataLoaded = 255 Then
                                Chunks(ChunkID).DataLoaded = 0
                                TotalChunksLoaded = TotalChunksLoaded - 1
                            End If
                        End If
                    Next Z
            End Select
        Next I
    Next R
    File_Log "Built ChunkLoadQueue:" + Str$(_SHR(Len(ChunkDataLoadQueue), 3))
End Sub
Function getChunkID~& (X As Long, Z As Long) Static
    getChunkID~& = 1 + ModFloor(MaxRenderDistanceX * Z + X, MaxChunks)
End Function
Sub LoadChunk (CX As Long, CZ As Long) Static
    Static As Long PX, PZ, X, Z
    Static As _Unsigned Long ChunkID
    Static As Single Height, dHeight
    Static As _Unsigned _Byte Block, Block_Water, BiomeSelector, TreeLog, TreeLeaves, TreeHeight
    Static As Single Biome
    Static As String * 324 HeightMap
    If Block_Water = 0 Then
        Block_Water = getBlockID("water")
    End If
    ChunkID = getChunkID(CX, CZ)
    PX = CX * 16
    PZ = CZ * 16
    Chunks(ChunkID).TX = PX
    Chunks(ChunkID).TZ = PZ
    Chunks(ChunkID).X = CX
    Chunks(ChunkID).Z = CZ
    Chunks(ChunkID).VerticesCount = 0
    Chunks(ChunkID).TransparentVerticesCount = 0
    TransparentBlocksCount = 0
    ' ChunkLoading
    For X = 0 To 17
        For Z = 0 To 17
            Biome = getBiome!(PX + X, PZ + Z)
            BiomeSelector = Int(Biome)
            Height = getHeight(PX + X, PZ + Z, Biome)
            dHeight = Height - Int(Height)
            Height = Int(Height)
            Asc(HeightMap, X * 18 + Z + 1) = Int(Height)
            For Y = 0 To 257
                Select Case Y
                    Case Is < Height - 2: Block = BiomeBlocks(2, BiomeSelector)
                    Case Height - 2 To Height - 1: Block = BiomeBlocks(1, BiomeSelector)
                    Case Height: If Height = WaterLevel And dHeight < 0.5 Then Block = Block_Water Else Block = BiomeBlocks(0, BiomeSelector)
                    Case Else: Block = 0
                End Select
                If Height <= Y And Y <= WaterLevel And Height <> WaterLevel Then Block = Block_Water
                ChunksData(X, Y, Z, ChunkID).Block = Block
                ChunksData(X, Y, Z, ChunkID).Light = 15
                TransparentBlocksCount = TransparentBlocksCount + isTransparent(Block)
            Next Y
    Next Z, X
    'For X = 0 To 17
    '    For Z = 0 To 17
    '        Biome = getBiome!(PX + X, PZ + Z)
    '        Height = Asc(HeightMap, X * 18 + Z + 1)
    '        If Height <= WaterLevel Then _Continue
    '        If InRange(0.75, fractal2(PX + X, PZ + Z, 16, 0, 5), 0.75) = 0 And InRange(0.75, fractal2(PX + X, PZ + Z, 32, 0, 6), 0.75) = 0 Then _Continue
    '        TreeLog = getBlockID(ListMapGet(BiomesList, 1 + Int(Biome), "tree_log"))
    '        If TreeLog = 0 Then _Continue
    '        TreeLeaves = getBlockID(ListMapGet(BiomesList, 1 + Int(Biome), "tree_leaves"))
    '        TreeHeight = Val(ListMapGet(BiomesList, 1 + Int(Biome), "tree_height_lower_limit"))
    '        TreeHeight = fractal2(PX + X, PZ + Z, 64, 0, 7) * (Val(ListMapGet(BiomesList, 1 + Int(Biome), "tree_height_upper_limit")) - TreeHeight + 1) + TreeHeight
    '        S = Height + 1
    '        E = Height + TreeHeight
    '        For Y = S To E
    '            ChunksData(X, Y, Z, ChunkID).Block = TreeLog
    '        Next Y
    '        For Y = E - 1 to E
    '            For XX = X - 1 To X + 1
    '                For ZZ = Z - 1 To Z + 1
    '                    If XX < 0 Or XX > 17 Or ZZ < 0 Or ZZ > 17 Then _Continue
    '                    If ChunksData(XX, Y, ZZ, ChunkID).Block = 0 Then ChunksData(XX, Y, ZZ, ChunkID).Block = TreeLeaves
    '            Next ZZ, XX
    '        Next Y
    'Next Z, X
    If TransparentBlocksCount = 0 Then Chunks(ChunkID).DataLoaded = 255: Exit Sub
    If SuperFastChunkLoading = 0 Then ' Lighting
        For X = 0 To 17
            For Z = 0 To 17
                __TOGGLE` = 0
                For Y = 257 To 0 Step -1
                    __TOGGLE` = (isTransparent(ChunksData(X, Y, Z, ChunkID).Block) = 0) Or __TOGGLE`
                    ChunksData(X, Y, Z, ChunkID).Light = 15 And (__TOGGLE` = 0 Or (X = 0 Or X = 17 Or Z = 0 Or Z = 17)) Or (12 And FastChunkLoading)
        Next Y, Z, X
    End If
    Chunks(ChunkID).DataLoaded = 253
    File_Log "Chunk Data Loaded(" + _Trim$(Str$(ChunkID)) + "):" + Str$(Chunks(ChunkID).X) + Str$(Chunks(ChunkID).Z)
    RenderDataLoadQueue = RenderDataLoadQueue + MKL$(ChunkID)
End Sub
Sub RenderChunk (ChunkID As _Unsigned Long) Static
    Static As Long X, Y, Z
    Dim As _Unsigned Long VertexID
    Static As _Unsigned Long J, TextureID, TextureOffset
    Static As _Unsigned _Byte Block, Visibility, Face, Light
    J = ChunkID - 1
    VertexID = ChunkDataSize * J
    Chunks(ChunkID).VerticesCount = 0
    Chunks(ChunkID).TransparentVerticesCount = 0
    For Mode = 0 To 1
        For X = 1 To 16
            For Z = 1 To 16
                For Y = 1 To 256
                    Block = ChunksData(X, Y, Z, ChunkID).Block
                    If (Mode = 0 And isTransparent(Block)) Or (Mode = 1 And isTransparent(Block) = 0) Or Block = 0 Then _Continue
                    Visibility = isTransparent(ChunksData(X + 1, Y, Z, ChunkID).Block) Or_
                        _SHL(isTransparent(ChunksData(X - 1, Y, Z, ChunkID).Block), 1) Or_
                        _SHL(isTransparent(ChunksData(X, Y + 1, Z, ChunkID).Block), 2) Or_
                        _SHL(isTransparent(ChunksData(X, Y - 1, Z, ChunkID).Block), 3) Or_
                        _SHL(isTransparent(ChunksData(X, Y, Z + 1, ChunkID).Block), 4) Or_
                        _SHL(isTransparent(ChunksData(X, Y, Z - 1, ChunkID).Block), 5)
                    For I = 0 To 23
                        Face = _SHR(I, 2)
                        If (Visibility And _SHL(1, Face)) = 0 Then _Continue
                        TextureID = Asc(Blocks(Block).Faces, Face + 1)
                        If TextureID = 0 Then _Continue
                        TextureOffset = Textures(TextureID).Y
                        omitFace = omitBlockFace(Block, Face)
                        Select Case Face
                            Case 0: Light = ChunksData(X + 1, Y, Z, ChunkID).Light - 6: If omitFace And Block = ChunksData(X + 1, Y, Z, ChunkID).Block Then _Continue
                            Case 1: Light = ChunksData(X - 1, Y, Z, ChunkID).Light - 6: If omitFace And Block = ChunksData(X - 1, Y, Z, ChunkID).Block Then _Continue
                            Case 2: Light = ChunksData(X, Y + 1, Z, ChunkID).Light: If omitFace And Block = ChunksData(X, Y + 1, Z, ChunkID).Block Then _Continue
                            Case 3: Light = ChunksData(X, Y - 1, Z, ChunkID).Light - 8: If omitFace And Block = ChunksData(X, Y - 1, Z, ChunkID).Block Then _Continue
                            Case 4: Light = ChunksData(X, Y, Z + 1, ChunkID).Light - 4: If omitFace And Block = ChunksData(X, Y, Z + 1, ChunkID).Block Then _Continue
                            Case 5: Light = ChunksData(X, Y, Z - 1, ChunkID).Light - 4: If omitFace And Block = ChunksData(X, Y, Z - 1, ChunkID).Block Then _Continue
                        End Select
                        Vertices(VertexID).X = X + CubeVertices(I).X
                        Vertices(VertexID).Y = Y + CubeVertices(I).Y
                        Vertices(VertexID).Z = Z + CubeVertices(I).Z
                        TextureCoords(VertexID).X = CubeTextureCoords(I).X
                        TextureCoords(VertexID).Y = (CubeTextureCoords(I).Y + TextureOffset) * TextureSize / TextureAtlasHeight
                        Colors(VertexID).X = AmbientOcclusion(X, Y, Z, I, ChunkID, 15 - (Light - Light * (Light < 0)))
                        'Colors(VertexID).X = AmbientOcclusion(X, Y, Z, I, ChunkID, 0)
                        Colors(VertexID).Y = Colors(VertexID).X
                        Colors(VertexID).Z = Colors(VertexID).X
                        Chunks(ChunkID).TransparentVerticesCount = Chunks(ChunkID).TransparentVerticesCount - (Mode = 1)
                        Chunks(ChunkID).VerticesCount = Chunks(ChunkID).VerticesCount - (Mode = 0)
                        VertexID = VertexID + 1
                    Next I
        Next Y, Z, X
        VertexID = VertexID + 1
    Next Mode
    TotalChunksLoaded = TotalChunksLoaded + 1
    File_Log "Render Data Loaded(" + _Trim$(Str$(Chunks(ChunkID).X)) + "," + _Trim$(Str$(Chunks(ChunkID).Z)) + "):" + Str$(Chunks(ChunkID).VerticesCount) + Str$(Chunks(ChunkID).TransparentVerticesCount)
    Chunks(ChunkID).DataLoaded = 255
End Sub
