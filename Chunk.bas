Sub RebuildChunkDataLoadQueue Static ' Used to build the chunk loading queue
    Static As Vec3_Long tmpChunksStart, tmpChunksEnd
    Static As Long I, X, Z
    Static ChunkID As _Unsigned Long
    ChunkDataLoadQueue = ""
    ' Build Queues
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
                        IsDifferentChunk = Chunks(ChunkID).X <> X Or Chunks(ChunkID).Z <> Z
                        If IsDifferentChunk Or Chunks(ChunkID).DataLoaded < 253 Then
                            ChunkDataLoadQueue = ChunkDataLoadQueue + MKL$(X) + MKL$(Z)
                            If Chunks(ChunkID).DataLoaded = 255 Then
                                Chunks(ChunkID).DataLoaded = 0
                                TotalChunksLoaded = TotalChunksLoaded - 1
                            End If
                            If IsDifferentChunk Then WipeChunk ChunkID
                        End If
                    Next X
                Case 1: For Z = tmpChunksStart.Z + Sgn(I) To tmpChunksEnd.Z
                        ChunkID = getChunkID(X, Z)
                        IsDifferentChunk = Chunks(ChunkID).X <> X Or Chunks(ChunkID).Z <> Z
                        If IsDifferentChunk Or Chunks(ChunkID).DataLoaded < 253 Then
                            ChunkDataLoadQueue = ChunkDataLoadQueue + MKL$(X) + MKL$(Z)
                            If Chunks(ChunkID).DataLoaded = 255 Then
                                Chunks(ChunkID).DataLoaded = 0
                                TotalChunksLoaded = TotalChunksLoaded - 1
                            End If
                            If IsDifferentChunk Then WipeChunk ChunkID
                        End If
                    Next Z
            End Select
        Next I
    Next R
    ' Clear Chunks outside the render distance
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
    ChunkDataGraphTimer = Mid$(ChunkDataGraphTimer, 2) + Chr$(Clamp(0, (Timer(0.01) - ST#) * 1024 / ChunkDataGraphTimerConstant, 255))
End Sub
Sub LoadChunk (CX As Long, CZ As Long) Static ' Load chunk data
    Static As Long PX, PZ, X, Z, Y, Y_1
    Static As _Unsigned Long ChunkID
    Static As Single Height, dHeight
    Static As _Unsigned _Byte Block, Block_Water, BiomeSelector, TreeLog, TreeLeaves, TreeHeight
    Static As Single Biome
    Static As String * 1296 HeightMap ' Store the heightmap
    Static As String * 384 BiomeMap ' and biomemap
    Static As _Unsigned _Byte isAirBlock, isTransparentBlock
    If Block_Water = 0 Then
        Block_Water = getBlockID("water")
    End If
    ChunkID = getChunkID(CX, CZ)
    If Chunks(ChunkID).X = CX And Chunks(ChunkID).Z = CZ Then
        Select Case Chunks(ChunkID).DataLoaded
            Case 255: Exit Sub
            Case 253: If Instr(RenderDataLoadQueue, MKL$(ChunkID)) = 0 Then RenderDataLoadQueue = RenderDataLoadQueue + MKL$(ChunkID)
                Exit Sub
        End Select
    End If
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
    Chunks(ChunkID).dirtyBit_AirBlock = String$(32, 0)
    Chunks(ChunkID).dirtyBit_TransparentBlock = String$(32, 0)
    Chunks(ChunkID).dirtyBit_SolidBlock = String$(32, 0)
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
            Chunks(ChunkID).MinimumHeight = Min(Chunks(ChunkID).MinimumHeight, Height - 2)
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
                isAirBlock = Block = 0
                isTransparentBlock = isTransparent(Block)
                Y_1 = Y + 7 ' 8 - 1
                If Y_1 >= 8 And Y_1 <= 264 Then
                    Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) Or _SHL(isAirBlock, Y_1 And 7)
                    Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)) Or _SHL(isTransparentBlock And (Block <> 0), Y_1 And 7)
                    Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)) Or _SHL(1 - (isAirBlock Or isTransparentBlock), Y_1 And 7)
                End If
                ChunksData(X, Y, Z, ChunkID).Block = Block
                ChunksData(X, Y, Z, ChunkID).Light = 15
                TransparentBlocksCount = TransparentBlocksCount + isTransparentBlock
            Next Y
            If fractal2(PX + X, PZ + Z, 16, 0, 5) > 0.8 And TreeX = 0 And TreeZ = 0 Then
                TreeX = X
                TreeZ = Z
            End If
    Next Z, X
    ' Code to Generate Tree - By ChatGPT
    '----------------------------------------------------------------------------------------------------------------------------------------------------------
    ' Known bugs:
    '     Goes through chunk borders
    '     Some parts (mostly top) are not counted for rendering
    X = TreeX
    Z = TreeZ
    If InRange(2, X, 15) And InRange(2, Z, 15) Then
        Biome = Asc(BiomeMap, X * 18 + Z + 1)
        Height = CVS(Mid$(HeightMap, _SHL(X * 18 + Z + 1, 2) - 3, 4))
        If Height > WaterLevel Then
	    TreeLog = getBlockID(ListMapGet(BiomesList, 1 + Int(Biome), "tree_log"))
            If TreeLog Then
                TreeLeaves = getBlockID(ListMapGet(BiomesList, 1 + Int(Biome), "tree_leaves"))
	        ' deterministic noise
                n! = fractal2(PX + X, PZ + Z, 64, 0, 7)
		TreeHeight = Val(ListMapGet(BiomesList, 1 + Int(Biome), "tree_height_lower_limit"))
                TreeHeight = n! * (Val(ListMapGet(BiomesList, 1 + Int(Biome), "tree_height_upper_limit")) - TreeHeight + 1) + TreeHeight
		bend! = (n! - 0.5) * 0.6
                branchChance! = 0.2 + n! * 0.3
                leafR = 2 + n! * 3
    		xOff! = 0
		zOff! = 0
		S = Height + 1
                E = Min(Height + TreeHeight, 256)
		maxTreeY = E + leafR + 2
		Chunks(ChunkID).MaximumHeight = Max(maxTreeY, Chunks(ChunkID).MaximumHeight)
		For Y = S To E
		' trunk bending using noise
                    drift! = fractal2(PX + X + Y, PZ + Z - Y, 8, 0, 5) - 0.5
                    xOff! = xOff! + drift! * bend!
                    zOff! = zOff! - drift! * bend!
		    TX = X + Int(xOff!)
                    TZ = Z + Int(zOff!)
		    If TX >= 0 And TX <= 17 And TZ >= 0 And TZ <= 17 Then
                        ChunksData(TX, Y, TZ, ChunkID).Block = TreeLog
			Y_1 = Y + 7
                        Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)) Or _SHL(1, Y_1 And 7)
                    End If
		    ' branch (inline, no function)
                    branchNoise! = fractal2(PX + X + Y, PZ + Z + Y, 16, 0, 6)
		    If branchNoise! > (1 - branchChance!) And Y > S + TreeHeight * 0.3 Then
			dir! = branchNoise! * 6.28
                        dx! = Cos(dir!)
                        dz! = Sin(dir!)
			bx! = xOff!
                        bz! = zOff!
                        by! = Y
			branchLen = 2 + branchNoise! * 3
			For i = 1 To branchLen
                            bx! = bx! + dx!
                            bz! = bz! + dz!
                            by! = by! + 0.5
			    TX = X + Int(bx!)
                            TZ = Z + Int(bz!)
			    If TX >= 0 And TX <= 17 And TZ >= 0 And TZ <= 17 Then
				TY = Int(by!)
				ChunksData(TX, TY, TZ, ChunkID).Block = TreeLog
				Y_1 = TY + 7
				' solid = 1
				Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)) Or _SHL(1, Y_1 And 7)
				' air = 0
				'Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) And Not _SHL(1, Y_1 And 7)
                            End If
                        Next i
			' leaves at branch end (blob)
                        For lx = -leafR To leafR
			    For ly = -leafR To leafR
				For lz = -leafR To leafR
				    dist = lx * lx + ly * ly + lz * lz
				    leafNoise! = fractal2(PX + X + lx, PZ + Z + lz, 8, 0, 5)
				    If dist < leafR * leafR * (0.7 + leafNoise! * 0.6) Then
					TX = X + Int(bx!) + lx
					TY = Int(by!) + ly
					TZ = Z + Int(bz!) + lz
					If TY > maxTreeY Then maxTreeY = TY
					If TX >= 0 And TX <= 17 And TZ >= 0 And TZ <= 17 Then
					    If ChunksData(TX, TY, TZ, ChunkID).Block = 0 Then
						ChunksData(TX, TY, TZ, ChunkID).Block = TreeLeaves
						Y_1 = TY + 7
						' transparent = 1
						Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)) = _
						Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)) Or _SHL(1, Y_1 And 7)
						' air = 0 (clear bit)
						'Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) And Not _SHL(1, Y_1 And 7)
						TransparentBlocksCount = TransparentBlocksCount + 1
					    End If
					End If
				    End If
			Next lz, ly, lx
                    End If
		Next Y
		' top leaf blob (main canopy)
                For lx = -leafR To leafR
		    For ly = -leafR To leafR
			For lz = -leafR To leafR
			    dist = lx * lx + ly * ly + lz * lz
			    leafNoise! = fractal2(PX + X + lx, PZ + Z + lz, 8, 0, 5)
			    If dist < leafR * leafR * (0.8 + leafNoise! * 0.4) Then
				TX = X + Int(xOff!) + lx
				TY = E + ly
				TZ = Z + Int(zOff!) + lz
				If TY > maxTreeY Then maxTreeY = TY
				If TX >= 0 And TX <= 17 And TZ >= 0 And TZ <= 17 Then
				    If ChunksData(TX, TY, TZ, ChunkID).Block = 0 Then
					ChunksData(TX, TY, TZ, ChunkID).Block = TreeLeaves
					Y_1 = TY + 7
					' transparent = 1
					Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)) = _
					Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)) Or _SHL(1, Y_1 And 7)
					' air = 0 (clear bit)
					'Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) = Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)) And Not _SHL(1, Y_1 And 7)
					TransparentBlocksCount = TransparentBlocksCount + 1
				    End If
				End If
			    End If
		Next lz, ly, lx
	    End If
        End If
    End If
    Chunks(ChunkID).MaximumHeight = Max(maxTreeY, Chunks(ChunkID).MaximumHeight)
    '----------------------------------------------------------------------------------------------------------------------------------------------------------

    If TransparentBlocksCount = 0 Then Chunks(ChunkID).DataLoaded = 255: Exit Sub
    If SkipLighting = 0 Then ' Lighting
        For X = 0 To 17
            For Z = 0 To 17
                __TOGGLE` = 0
                For Y = Chunks(ChunkID).MaximumHeight + 1 To Chunks(ChunkID).MinimumHeight - 1 Step -1
                    __TOGGLE` = (isTransparent(ChunksData(X, Y, Z, ChunkID).Block) = 0) Or __TOGGLE`
                    ChunksData(X, Y, Z, ChunkID).Light = 15 And (__TOGGLE` = 0 Or (X = 0 Or X = 17 Or Z = 0 Or Z = 17)) Or (12 And MinimalLighting <> 0)
        Next Y, Z, X
    End If
    If SkipLighting = 0 And MinimalLighting = 0 Then ' need to implement fast Flood Fill Algorithm
        For I = 15 To 1 Step -1
            For X = 1 To 16: For Z = 1 To 16: For Y = Chunks(ChunkID).MinimumHeight - 1 To Chunks(ChunkID).MaximumHeight + 1
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
    RenderDataGraphTimer = Mid$(RenderDataGraphTimer, 2) + Chr$(Clamp(0, (Timer(0.01) - ST#) * 1024 / RenderDataGraphTimerConstant, 255))
End Sub
Sub RenderChunk (ChunkID As _Unsigned Long) Static ' Add Quads for Rendering
    Static As Long X, Y, Z, Y_1
    Static As _Unsigned Long VertexID
    Static As _Unsigned Long J, TextureID, TextureOffset
    Static As _Unsigned _Byte Block, Visibility, Face, Light
    Static As Single __TextureHeight: __TextureHeight = TextureSize / TextureAtlasHeight
    Static As _Unsigned _Byte CurrentLayer, BelowLayer, AboveLayer, CombinationLayer
    If Chunks(ChunkID).DataLoaded < 253 Then Exit Sub
    If Chunks(ChunkID).DataLoaded = 255 Then Exit Sub
    J = ChunkID - 1
    VertexID = ChunkDataSize * J
    Chunks(ChunkID).VerticesCount = 0
    Chunks(ChunkID).TransparentVerticesCount = 0
    For Mode = 0 To 1
        For Y = Chunks(ChunkID).MinimumHeight To Chunks(ChunkID).MaximumHeight
            Y_1 = Y + 7
            CurrentLayer = _SHL(-_ReadBit(Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)), Y_1 And 7), 2) Or_
                _SHL(-_ReadBit(Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)), Y_1 And 7), 1) Or_
                -_ReadBit(Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)), Y_1 And 7)
            If Y_1 > 0 Then
                Y_1 = Y + 6
                BelowLayer = _SHL(-_ReadBit(Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)), Y_1 And 7), 2) Or_
                    _SHL(-_ReadBit(Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)), Y_1 And 7), 1) Or_
                    -_ReadBit(Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)), Y_1 And 7)
            Else BelowLayer = 0
            End If
            If Y_1 < 255 Then
                Y_1 = Y + 8
                AboveLayer = _SHL(-_ReadBit(Asc(Chunks(ChunkID).dirtyBit_AirBlock, _SHR(Y_1, 3)), Y_1 And 7), 2) Or_
                    _SHL(-_ReadBit(Asc(Chunks(ChunkID).dirtyBit_TransparentBlock, _SHR(Y_1, 3)), Y_1 And 7), 1) Or_
                    -_ReadBit(Asc(Chunks(ChunkID).dirtyBit_SolidBlock, _SHR(Y_1, 3)), Y_1 And 7)
            Else AboveLayer = 0
            End If
            LayerCombination = CurrentLayer Or BelowLayer Or AboveLayer
            If LayerCombination < 3 Then _Continue
            For X = 1 To 16
                For Z = 1 To 16
                    Block = ChunksData(X, Y, Z, ChunkID).Block
                    If (Mode = 0 And isTransparent(Block)) Or (Mode = 1 And isTransparent(Block) = 0) Or Block = 0 Then _Continue
                    Visibility = isTransparent(ChunksData(X + 1, Y, Z, ChunkID).Block) Or_
                        _SHL(isTransparent(ChunksData(X - 1, Y, Z, ChunkID).Block), 1) Or_
                        _SHL(isTransparent(ChunksData(X, Y + 1, Z, ChunkID).Block), 2) Or_
                        _SHL(isTransparent(ChunksData(X, Y - 1, Z, ChunkID).Block), 3) Or_
                        _SHL(isTransparent(ChunksData(X, Y, Z + 1, ChunkID).Block), 4) Or_
                        _SHL(isTransparent(ChunksData(X, Y, Z - 1, ChunkID).Block), 5)
                    If Visibility = 0 Then _Continue
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
        Next Z, X, Y
        VertexID = VertexID + 1
    Next Mode
    TotalChunksLoaded = TotalChunksLoaded + 1
    'File_Log "Render Data Loaded(" + _Trim$(Str$(Chunks(ChunkID).X)) + "," + _Trim$(Str$(Chunks(ChunkID).Z)) + "):" + Str$(Chunks(ChunkID).VerticesCount) + Str$(Chunks(ChunkID).TransparentVerticesCount)
    Chunks(ChunkID).DataLoaded = 255
End Sub
Sub WipeChunk (ChunkID As _Unsigned Long) Static
    Static M As _MEM
    M = _Mem(_Offset(ChunksData(0, 0, 0, ChunkID)), 167184)
    _MemFill M, M.OFFSET, M.SIZE, 0 As _BYTE
    _MemFree M
End Sub
Function AmbientOcclusion~%% (X As _Byte, Y As Integer, Z As _Byte, vertexIndex As _Byte, ChunkID As _Unsigned Integer, CurrentLight As _Unsigned _Byte) Static ' used to calculate block lighting
    'Adapted from QB-Blocks_4
    $Checking:Off
    Dim As _Byte dX, dY, dZ
    Dim As _Byte side1, side2, corner
    Dim As _Byte total
    dX = _ShL(CubeVertices(vertexIndex).X, 1) - 1
    dY = _ShL(CubeVertices(vertexIndex).Y, 1) - 1
    dZ = _ShL(CubeVertices(vertexIndex).Z, 1) - 1
    corner = Sgn(ChunksData(X + dX, Y + dY, Z + dZ, ChunkID).Block)
    side1 = Sgn(ChunksData(X + dX, Y + dY, Z, ChunkID).Block)
    side2 = Sgn(ChunksData(X, Y + dY, Z + dZ, ChunkID).Block)
    total = side1 + side2 + corner + CurrentLight
    total = total + (total - 15) * (total > 15)
    $Checking:On
    AmbientOcclusion = 255 - 15 * total
End Function
