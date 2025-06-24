Sub GL_Generate_Texture (Handle As Long, Image As Long)
    Dim M As _MEM
    _glGenTextures 1, _Offset(Handle)
    _glBindTexture _GL_TEXTURE_2D, Handle
    M = _MemImage(Image)
    _glTexImage2D _GL_TEXTURE_2D, 0, _GL_RGBA, _Width(Image), _Height(Image), 0, _GL_BGRA_EXT, _GL_UNSIGNED_BYTE, M.OFFSET
    _MemFree M
    _FreeImage Image
    Image = 0
    _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MIN_FILTER, _GL_LINEAR
    _glTexParameteri _GL_TEXTURE_2D, _GL_TEXTURE_MAG_FILTER, _GL_NEAREST
End Sub
