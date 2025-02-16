RayPos = Camera: RayDir.X = CameraAngleSine.X * CameraAngleCoSine.Y: RayDir.Y = CameraAngleSine.Y: RayDir.Z = -CameraAngleCoSine.X * CameraAngleCoSine.Y: BlockSelected = 0
Vec3_FloatToInt RayPos, RayBlockPos
For I = 1 To 5
    If InRange(1, RayPos.Y, ChunkHeight) Then
        If isTransparent(BlockExists(RayPos.X, RayPos.Y, RayPos.Z)) = 0 Then BlockSelected = -1: Exit For
    End If
    Vec3_FloatToInt RayPos, RayPreviousBlockPos
    RayPos.X = RayPos.X + RayDir.X
    RayPos.Y = RayPos.Y + RayDir.Y
    RayPos.Z = RayPos.Z + RayDir.Z
Next I
Vec3_FloatToInt RayPos, RayBlockPos
If BlockSelected Then
    If _MouseButton(1) And InRange(1, RayBlockPos.Y, ChunkHeight) And Timer(0.01) - LastMouse1Time > 0.25 Then
        SetBlockReloadChunk RayBlockPos.X, RayBlockPos.Y, RayBlockPos.Z, BLOCK_AIR
        LastMouse1Time = Timer(0.01)
    End If
    If _MouseButton(2) And InRange(1, RayPreviousBlockPos.Y, ChunkHeight) And Timer(0.01) - LastMouse2Time > 0.25 Then If (Abs(Camera.X - RayPreviousBlockPos.X) > PlayerObesity Or Abs(Camera.Z - RayPreviousBlockPos.Z) > PlayerObesity) Or Abs(Camera.Y - RayPreviousBlockPos.Y) > PlayerHeight Then
            SetBlockReloadChunk RayPreviousBlockPos.X, RayPreviousBlockPos.Y, RayPreviousBlockPos.Z, SELECTED_BLOCK
            LastMouse2Time = Timer(0.01)
        End If
    End If
End If
SELECTED_BLOCK = Max(1, Min(TOTALBLOCKS, SELECTED_BLOCK + MW + _KeyDown(18432) - _KeyDown(20480) + _KeyDown(19200) - _KeyDown(19712)))
While _KeyDown(18432) Or _KeyDown(20480) Or _KeyDown(19200) Or _KeyDown(19712): _Limit 30: Wend
