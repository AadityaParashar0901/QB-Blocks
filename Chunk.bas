Sub RebuildChunkDataLoadQueue Static ' Used to build the chunk loading queue
    Static As Vec3_Long tmpChunksStart, tmpChunksEnd
    Static As Long I, X, Z
    Static ChunkID As _Unsigned Long
    ChunkDataLoadQueue = ""
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
                        If Chunks(ChunkID).X <> X Or Chunks(ChunkID).Z <> Z Or Chunks(ChunkID).DataLoaded < 253 Then
                            ChunkDataLoadQueue = ChunkDataLoadQueue + MKL$(X) + MKL$(Z)
                            If Chunks(ChunkID).DataLoaded = 255 Then
                                Chunks(ChunkID).DataLoaded = 0
                                TotalChunksLoaded = TotalChunksLoaded - 1
                            End If
                        End If
                    Next X
                Case 1: For Z = tmpChunksStart.Z + Sgn(I) To tmpChunksEnd.Z
                        ChunkID = getChunkID(X, Z)
                        If Chunks(ChunkID).X <> X Or Chunks(ChunkID).Z <> Z Or Chunks(ChunkID).DataLoaded < 253 Then
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
    For R = RenderDistance + 1 To MaxRenderDistance
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
                        TotalChunksLoaded = TotalChunksLoaded + (Chunks(ChunkID).DataLoaded = 255)
                        Chunks(ChunkID).DataLoaded = 0
                    Next X
                Case 1: For Z = tmpChunksStart.Z + Sgn(I) To tmpChunksEnd.Z
                        ChunkID = getChunkID(X, Z)
                        TotalChunksLoaded = TotalChunksLoaded + (Chunks(ChunkID).DataLoaded = 255)
                        Chunks(ChunkID).DataLoaded = 0
                    Next Z
            End Select
        Next I
    Next R
    'File_Log "Built ChunkLoadQueue:" + Str$(_SHR(Len(ChunkDataLoadQueue), 3))
End Sub
Function getChunkID~& (X As Long, Z As Long) Static ' Hash Table approach, faster & enables resuming chunk loading
    getChunkID~& = 1 + ModFloor(MaxRenderDistanceX * Z + X, MaxChunks)
End Function
Sub LoadNextChunk () Static
    Static __Chunk$
    __Chunk$ = Left$(ChunkDataLoadQueue, 8): ChunkDataLoadQueue = Mid$(ChunkDataLoadQueue, 9)
    ST# = Timer(0.001)
    LoadChunk CVL(Left$(__Chunk$, 4)), CVL(Right$(__Chunk$, 4))
    ChunkDataGraphTimer = Mid$(ChunkDataGraphTimer, 4) + MKL$((Timer(0.001) - ST#) * 1000)
End Sub
Sub LoadChunk (CX As Long, CZ As Long) Static ' Load chunk data
    Static As Long PX, PZ, X, Z
    Static As _Unsigned Long ChunkID
    Static As Single Height, dHeight
    Static As _Unsigned _Byte Block, Block_Water, BiomeSelector, TreeLog, TreeLeaves, TreeHeight
    Static As Single Biome
    Static As String * 1296 HeightMap ' Store the heightmap
    Static As String * 384 BiomeMap ' and biomemap
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
    Chunks(ChunkID).MinimumHeight = 256
    Chunks(ChunkID).MaximumHeight = WaterLevel + 1
    Chunks(ChunkID).VerticesCount = 0
    Chunks(ChunkID).TransparentVerticesCount = 0
    TransparentBlocksCount = 0
    TreeX = 0
    TreeZ = 0
    ' ChunkLoading
    For X = 0 To 17
        For Z = 0 To 17
            Biome = getBiome!(PX + X, PZ + Z)
            BiomeSelector = Int(Biome)
            Asc(BiomeMap, X * 18 + Z + 1) = BiomeSelector
            Height = getHeight(PX + X, PZ + Z, Biome)
            Mid$(HeightMap, _SHL(X * 18 + Z + 1, 2) - 3, 4) = MKS$(Height)
            Chunks(ChunkID).MaximumHeight = Max(Height + 1, Chunks(ChunkID).MaximumHeight)
            Chunks(ChunkID).MinimumHeight = Min(Chunks(ChunkID).MinimumHeight, Height - 1)
    Next Z, X
    Chunks(ChunkID).MaximumHeight = Clamp(1, Chunks(ChunkID).MaximumHeight, 256)
    Chunks(ChunkID).MinimumHeight = Clamp(1, Chunks(ChunkID).MinimumHeight, 256)
    For X = 0 To 17
        For Z = 0 To 17
            Height = CVS(Mid$(HeightMap, _SHL(X * 18 + Z + 1, 2) - 3, 4))
            dHeight = Height - Int(Height)
            Height = Int(Height)
            BiomeSelector = Asc(BiomeMap, X * 18 + Z + 1)
            For Y = Chunks(ChunkID).MinimumHeight - 1 To Chunks(ChunkID).MaximumHeight + 1
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
            If fractal2(PX + X, PZ + Z, 16, 0, 5) > 0.8 And TreeX = 0 And TreeZ = 0 Then
                TreeX = X
                TreeZ = Z
            End If
    Next Z, X
    ' Code to Generate Tree
    ' Currently makes splines of trees -> switched to one tree per chunk

    'For X = 0 To 17
    '    For Z = 0 To 17
    X = TreeX
    Z = TreeZ
    For T = 1 To 1
        If InRange(2, X, 15) = 0 Or InRange(2, Z, 15) = 0 Then _Continue
        Biome = Asc(BiomeMap, X * 18 + Z + 1)
        Height = CVS(Mid$(HeightMap, _SHL(X * 18 + Z + 1, 2) - 3, 4))
        If Height <= WaterLevel Then _Continue
        '       If InRange(0.75, fractal2(PX + X, PZ + Z, 16, 0, 5), 0.75) = 0 And InRange(0.75, fractal2(PX + X, PZ + Z, 32, 0, 6), 0.75) = 0 Then _Continue
        TreeLog = getBlockID(ListMapGet(BiomesList, 1 + Int(Biome), "tree_log"))
        If TreeLog = 0 Then _Continue
        TreeLeaves = getBlockID(ListMapGet(BiomesList, 1 + Int(Biome), "tree_leaves"))
        TreeHeight = Val(ListMapGet(BiomesList, 1 + Int(Biome), "tree_height_lower_limit"))
        TreeHeight = fractal2(PX + X, PZ + Z, 64, 0, 7) * (Val(ListMapGet(BiomesList, 1 + Int(Biome), "tree_height_upper_limit")) - TreeHeight + 1) + TreeHeight
        S = Height + 1
        E = Min(Height + TreeHeight, 256)
        Chunks(ChunkID).MaximumHeight = Max(E, Chunks(ChunkID).MaximumHeight)
        For Y = S To E - 1
            ChunksData(X, Y, Z, ChunkID).Block = TreeLog
        Next Y
        For Y = E - 1 to E
            For XX = X - 1 To X + 1
                For ZZ = Z - 1 To Z + 1
                    If XX < 0 Or XX > 17 Or ZZ < 0 Or ZZ > 17 Then _Continue
                    If ChunksData(XX, Y, ZZ, ChunkID).Block = 0 Then ChunksData(XX, Y, ZZ, ChunkID).Block = TreeLeaves: TransparentBlocksCount = TransparentBlocksCount + 1
            Next ZZ, XX
        Next Y
    Next T
    'Next Z, X
    If TransparentBlocksCount = 0 Then Chunks(ChunkID).DataLoaded = 255: Exit Sub
    If SkipLighting = 0 Then ' Lighting
        For X = 0 To 17
            For Z = 0 To 17
                __TOGGLE` = 0
                For Y = 257 To 0 Step -1
                    __TOGGLE` = (isTransparent(ChunksData(X, Y, Z, ChunkID).Block) = 0) Or __TOGGLE`
                    ChunksData(X, Y, Z, ChunkID).Light = 15 And (__TOGGLE` = 0 Or (X = 0 Or X = 17 Or Z = 0 Or Z = 17)) Or (12 And MinimalLighting <> 0)
        Next Y, Z, X
    End If
    If SkipLighting = 0 And MinimalLighting = 0 Then ' need to implement fast Flood Fill Algorithm
        For I = 15 To 1 Step -1
            For X = 1 To 16: For Z = 1 To 16: For Y = 1 To 256
                        If ChunksData(X, Y, Z, ChunkID).Light Or ChunksData(X, Y, Z, ChunkID).Block Then _Continue
                        If ChunksData(X + 1, Y, Z, ChunkID).Light = I Or ChunksData(X - 1, Y, Z, ChunkID).Light = I Or ChunksData(X, Y + 1, Z, ChunkID).Light = I Or ChunksData(X, Y - 1, Z, ChunkID).Light = I Or ChunksData(X, Y, Z + 1, ChunkID).Light = I Or ChunksData(X, Y, Z - 1, ChunkID).Light = I Then
                            ChunksData(X, Y, Z, ChunkID).Light = I - 1
                        End If
        Next Y, Z, X, I
    End If
    Chunks(ChunkID).DataLoaded = 253
    'File_Log "Chunk Data Loaded(" + _Trim$(Str$(ChunkID)) + "):" + Str$(Chunks(ChunkID).X) + Str$(Chunks(ChunkID).Z)
    RenderDataLoadQueue = RenderDataLoadQueue + MKL$(ChunkID)
End Sub
Sub RenderNextChunk () Static
    Static __Chunk$
    __Chunk$ = Left$(RenderDataLoadQueue, 4): RenderDataLoadQueue = Mid$(RenderDataLoadQueue, 5)
    ST# = Timer(0.01)
    RenderChunk CVL(__Chunk$)
    RenderDataGraphTimer = Mid$(RenderDataGraphTimer, 4) + MKL$((Timer(0.01) - ST#) * 1000)
End Sub
Sub RenderChunk (ChunkID As _Unsigned Long) Static ' Add Quads for Rendering
    Static As Long X, Y, Z
    Static As _Unsigned Long VertexID
    Static As _Unsigned Long J, TextureID, TextureOffset
    Static As _Unsigned _Byte Block, Visibility, Face, Light
    Static As Single __TextureHeight: __TextureHeight = TextureSize / TextureAtlasHeight
    If Chunks(ChunkID).DataLoaded < 253 Then Exit Sub
    J = ChunkID - 1
    VertexID = ChunkDataSize * J
    Chunks(ChunkID).VerticesCount = 0
    Chunks(ChunkID).TransparentVerticesCount = 0
    For Mode = 0 To 1
        For X = 1 To 16
            For Z = 1 To 16
                For Y = Chunks(ChunkID).MinimumHeight To Chunks(ChunkID).MaximumHeight
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
                        If (Visibility And _SHL(1, Face)) = 0 Then I = I + 3: _Continue
                        TextureID = Asc(Blocks(Block).Faces, Face + 1)
                        If TextureID = 0 Then I = I + 3: _Continue
                        TextureOffset = Textures(TextureID).Y
                        omitSimilarFace = omitBlockFace(Block, Face)
                        Select Case Face
                            Case 0: Light = ChunksData(X + 1, Y, Z, ChunkID).Light - 6: If omitSimilarFace And Block = ChunksData(X + 1, Y, Z, ChunkID).Block Then I = I + 3: _Continue
                            Case 1: Light = ChunksData(X - 1, Y, Z, ChunkID).Light - 6: If omitSimilarFace And Block = ChunksData(X - 1, Y, Z, ChunkID).Block Then I = I + 3: _Continue
                            Case 2: Light = ChunksData(X, Y + 1, Z, ChunkID).Light: If omitSimilarFace And Block = ChunksData(X, Y + 1, Z, ChunkID).Block Then I = I + 3: _Continue
                            Case 3: Light = ChunksData(X, Y - 1, Z, ChunkID).Light - 8: If omitSimilarFace And Block = ChunksData(X, Y - 1, Z, ChunkID).Block Then I = I + 3: _Continue
                            Case 4: Light = ChunksData(X, Y, Z + 1, ChunkID).Light - 4: If omitSimilarFace And Block = ChunksData(X, Y, Z + 1, ChunkID).Block Then I = I + 3: _Continue
                            Case 5: Light = ChunksData(X, Y, Z - 1, ChunkID).Light - 4: If omitSimilarFace And Block = ChunksData(X, Y, Z - 1, ChunkID).Block Then I = I + 3: _Continue
                        End Select
                        Vertices(VertexID).X = X + CubeVertices(I).X
                        Vertices(VertexID).Y = Y + CubeVertices(I).Y
                        Vertices(VertexID).Z = Z + CubeVertices(I).Z
                        TextureCoords(VertexID).X = CubeTextureCoords(I).X
                        TextureCoords(VertexID).Y = (CubeTextureCoords(I).Y + TextureOffset) * __TextureHeight
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
    'File_Log "Render Data Loaded(" + _Trim$(Str$(Chunks(ChunkID).X)) + "," + _Trim$(Str$(Chunks(ChunkID).Z)) + "):" + Str$(Chunks(ChunkID).VerticesCount) + Str$(Chunks(ChunkID).TransparentVerticesCount)
    Chunks(ChunkID).DataLoaded = 255
End Sub
