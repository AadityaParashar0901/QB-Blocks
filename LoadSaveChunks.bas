Sub SetBlockReloadChunk (X As Long, Y As Long, Z As Long, B As _Unsigned _Byte)
    Dim As Integer __CX, __CZ, __CPX, __CPY, __CPZ
    __CX = Int((X - 1) / 16): __CZ = Int((Z - 1) / 16)
    __CPX = Int(X - __CX * 16): __CPY = Int(Y): __CPZ = Int(Z - __CZ * 16)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = __CX And Chunk(I).Z = __CZ And Chunk(I).LoadedChunkData Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Sub
    ChunkData(__CPX, __CPY, __CPZ, FoundI) = B
    If __CPX = 1 Then SetAnotherBlockReloadChunk __CX - 1, __CZ, 17, __CPY, __CPZ, B
    If __CPX = 16 Then SetAnotherBlockReloadChunk __CX + 1, __CZ, 0, __CPY, __CPZ, B
    If __CPZ = 1 Then SetAnotherBlockReloadChunk __CX, __CZ - 1, __CPX, __CPY, 17, B
    If __CPZ = 16 Then SetAnotherBlockReloadChunk __CX, __CZ + 1, __CPX, __CPY, 0, B
    Chunk(FoundI).MinimumHeight = Max(0, Min(Chunk(FoundI).MinimumHeight, __CPY - 1))
    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, __CPY)
    Chunk(FoundI).LoadedRenderData = 0
    Chunk(FoundI).Count = 0
    Chunk(FoundI).TCount = 0
    T = ChunkReloader(FoundI, __CX, __CZ)
    SaveChunkFile __CX, __CZ
End Sub
Sub SetAnotherBlockReloadChunk (__CX As Integer, __CZ As Integer, __CPX As Integer, __CPY As Integer, __CPZ As Integer, B As _Unsigned _Byte)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = __CX And Chunk(I).Z = __CZ And Chunk(I).LoadedChunkData Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Sub
    ChunkData(__CPX, __CPY, __CPZ, FoundI) = B
    Chunk(FoundI).MinimumHeight = Max(0, Min(Chunk(FoundI).MinimumHeight, __CPY - 1))
    Chunk(FoundI).MaximumHeight = Max(Chunk(FoundI).MaximumHeight, __CPY)
    Chunk(FoundI).LoadedRenderData = 0
    Chunk(FoundI).Count = 0
    Chunk(FoundI).TCount = 0
    T = ChunkReloader(FoundI, __CX, __CZ)
    SaveChunkFile __CX, __CZ
End Sub

Sub WipeChunk (FoundI As _Unsigned Integer)
    Dim M As _MEM
    M = _Mem(_Offset(ChunkData(0, 0, 0, FoundI)), ChunkDataSize)
    _MemFill M, M.OFFSET, M.SIZE, 0 As LONG
    _MemFree M
End Sub

Function LoadChunkFile (CX, CZ)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = CX And Chunk(I).Z = CZ And Chunk(I).LoadedChunkData = -1 Then Exit Function
        If Chunk(I).LoadedChunkData = 0 And FoundI = 0 Then FoundI = I
    Next I
    If FoundI = 0 Then Exit Function
    FILEX = Int(CX / 16): FILEZ = Int(CZ / 16)
    SEEKX = CX - FILEX * 16: SEEKZ = CZ - FILEZ * 16
    SIZE& = Len(Chunk(FoundI)) + Len(TMPCHUNKDATA())
    FILE$ = "saves/" + WORLDFOLDER$ + "/chunks/region_" + TS$(FILEX) + "_" + TS$(FILEZ) + ".chunkdata"
    If _FileExists(FILE$) Then
        F = FreeFile
        Open FILE$ For Binary As #F
        Seek #F, (SEEKX * 16 + SEEKZ) * SIZE& + 1
        Get #F, , Chunk(FoundI)
        If Chunk(FoundI).LoadedChunkData Then
            Get #F, , TMPCHUNKDATA()
            For X = 0 To 17: For Z = 0 To 17: For Y = 0 To ChunkHeight + 1: ChunkData(X, Y, Z, FoundI) = TMPCHUNKDATA(X, Y, Z): Next Y, Z, X
            Close #F
            LoadChunkFile = ChunkReloader(FoundI, CX, CZ)
        Else
            LoadChunkFile = ChunkLoader(FoundI, CX, CZ) And ChunkReloader(FoundI, CX, CZ)
        End If
    Else
        LoadChunkFile = ChunkLoader(FoundI, CX, CZ) And ChunkReloader(FoundI, CX, CZ)
    End If
    LoadedChunks = LoadedChunks + 1
End Function
Sub SaveChunkFile (CX, CZ)
    For I = LBound(Chunk) To UBound(Chunk)
        If Chunk(I).X = CX And Chunk(I).Z = CZ And Chunk(I).LoadedChunkData Then FoundI = I: Exit For
    Next I
    If FoundI = 0 Then Exit Sub
    F = FreeFile
    FILEX = Int(CX / 16): FILEZ = Int(CZ / 16)
    SEEKX = CX - FILEX * 16: SEEKZ = CZ - FILEZ * 16
    SIZE& = Len(Chunk(FoundI)) + Len(TMPCHUNKDATA())
    Open "saves/" + WORLDFOLDER$ + "/chunks/region_" + TS$(FILEX) + "_" + TS$(FILEZ) + ".chunkdata" For Binary As #F
    Seek #F, (SEEKX * 16 + SEEKZ) * SIZE& + 1
    Put #F, , Chunk(FoundI)
    For X = 0 To 17: For Z = 0 To 17: For Y = 0 To ChunkHeight + 1: TMPCHUNKDATA(X, Y, Z) = ChunkData(X, Y, Z, FoundI): Next Y, Z, X
    Put #F, , TMPCHUNKDATA()
    Close #F
End Sub
Sub LoadPlayerData
    Camera.X = 0.5: Camera.Y = GenerationChunkHeight: Camera.Z = 0.5
    CameraAngle.X = 0: CameraAngle.Y = 0
    If _FileExists("saves/" + WORLDFOLDER$ + "/world.dat") = 0 Then Exit Sub
    F = FreeFile
    Open "saves/" + WORLDFOLDER$ + "/world.dat" For Binary As #F
    Get #F, , Seed
    SeedRatio = Seed / 65536
    Get #F, , WorldFlat
    Get #F, , Camera
    Get #F, , CameraAngle
    Get #F, , Time
    Close #F
End Sub
Sub SavePlayerData
    Static SaveTime As Single
    If Timer - SaveTime < 1 Then Exit Sub
    SaveTime = Timer
    F = FreeFile
    Open "saves/" + WORLDFOLDER$ + "/world.dat" For Binary As #F
    Put #F, , Seed
    Put #F, , WorldFlat
    Put #F, , Camera
    Put #F, , CameraAngle
    Put #F, , Time
    Close #F
End Sub
Sub Settings (__LOAD)
    If __LOAD And _FileExists("saves/settings.dat") = 0 Then Exit Sub
    __F = FreeFile
    Open "saves/settings.dat" For Binary As #__F
    If __LOAD Then
        Get #__F, , FOV
        Get #__F, , RenderDistance
        Get #__F, , FOG
    Else
        Put #__F, , FOV
        Put #__F, , RenderDistance
        Put #__F, , FOG
    End If
    Close #__F
End Sub
Sub Settings_Dialog
    Do
        Cls 1, 0: _Limit 60
        If _Resize Then Screen _NewImage(_ResizeWidth, _ResizeHeight, 32): _PrintMode _KeepBackground
        While _MouseInput: Wend
        Line (0, 0)-(_Width - 1, _Height - 1), _RGB32(0, 127), BF
        Slider RenderDistance, _Width / 2, _Height * 0.4, "Render Distance", 1, MaxRenderDistance
        TotalChunks = (2 * RenderDistance + 1) ^ 2
        Slider FOV, _Width / 2, _Height * 0.5, "FOV", 70, 110
        If Button(2, _Width / 10, _Height / 10, "") Then Settings False: Exit Do
        _Display
    Loop Until _KeyDown(27)
    While _KeyDown(27): Wend
End Sub
