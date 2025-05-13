Function getHeight% (X As Long, Z As Long) Static
    Dim As Single c, e, pv
    c = fractal2(X, Z, NoiseSmoothness, NoiseComplexity, 0)
    c = IIF(c > 0.75, (25 * (c - 0.75) + 150) / 256, IIF(c > 0.5, (200 * (c - 0.5) + 100) / 256, (100 * c + 50) / 256))
    e = fractal2(X, Z, NoiseSmoothness, NoiseComplexity, 1)
    e = IIF(e > 0.8, (50 - 25 * (e - 0.8)) / 256, IIF(e > 0.75, (100 - 1000 * (e - 0.75)) / 256, IIF(e > 0.5, (125 - 100 * (e - 0.5)) / 256, IIF(e > 0.2, (185 - 200 * (e - 0.2)) / 256, (195 - 50 * e) / 256))))
    pv = fractal2(X, Z, NoiseSmoothness, NoiseComplexity, 2)
    pv = IIF(pv > 0.8, (25 * (pv - 0.8) + 200) / 256, IIF(pv > 0.6, (500 * (pv - 0.6) + 100) / 256, IIF(pv > 0.5, (250 * (pv - 0.5) + 75) / 256, (150 * pv) / 256)))
    getHeight = GenerationChunkHeight * (c + e + pv) / 3
End Function
Function getBiome% (X As Long, Z As Long)
    getBiome = 1 + 5 * fractal2(X, Z, NoiseSmoothness * 4, NoiseComplexity, 6)
End Function
