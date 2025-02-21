Function getHeight (X&, Z&)
    getHeight = GenerationChunkHeight * (continentalness(X&, Z&) + erosion(X&, Z&) + peaks_valleys(X&, Z&)) / 3
End Function
Function getBiome% (X As Long, Z As Long)
    getBiome = 1 + 5 * fractal2(X, Z, NoiseSmoothness * 4, NoiseComplexity, 6)
End Function
Function continentalness (X As Long, Z As Long)
    Dim As Single c
    c = fractal2(X, Z, NoiseSmoothness, NoiseComplexity, 0)
    continentalness = IIF(c > 0.75, (25 * (c - 0.75) + 150) / 256, IIF(c > 0.5, (200 * (c - 0.5) + 100) / 256, (100 * c + 50) / 256))
End Function
Function erosion (X As Long, Z As Long)
    Dim As Single e
    e = fractal2(X, Z, NoiseSmoothness, NoiseComplexity, 1)
    erosion = IIF(e > 0.8, (50 - 25 * (e - 0.8)) / 256, IIF(e > 0.75, (100 - 1000 * (e - 0.75)) / 256, IIF(e > 0.5, (125 - 100 * (e - 0.5)) / 256, IIF(e > 0.2, (185 - 200 * (e - 0.2)) / 256, (195 - 50 * e) / 256))))
End Function
Function peaks_valleys (X As Long, Z As Long)
    Dim As Single pv
    pv = fractal2(X, Z, noisesmoothness, NoiseComplexity, 2)
    peaks_valleys = IIF(pv > 0.8, (25 * (pv - 0.8) + 200) / 256, IIF(pv > 0.6, (500 * (pv - 0.6) + 100) / 256, IIF(pv > 0.5, (250 * (pv - 0.5) + 75) / 256, (150 * pv) / 256)))
End Function
