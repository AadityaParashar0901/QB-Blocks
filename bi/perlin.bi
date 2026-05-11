perlin2d_total = 0
perlin2d_amplitude = 1
perlin2d_frequency = 1 / 256

For perlin2d_i = 0 To 3

    perlin2d_x = (PX + X) * perlin2d_frequency
    perlin2d_y = (PZ + Z) * perlin2d_frequency

    perlin2d_X0 = Int(perlin2d_x) And 255
    perlin2d_Y0 = Int(perlin2d_y) And 255

    perlin2d_X1 = (perlin2d_X0 + 1) And 255
    perlin2d_Y1 = (perlin2d_Y0 + 1) And 255

    perlin2d_dx = perlin2d_x - Int(perlin2d_x)
    perlin2d_dy = perlin2d_y - Int(perlin2d_y)

    perlin2d_u = perlin2d_dx * perlin2d_dx * perlin2d_dx * (perlin2d_dx * (perlin2d_dx * 6 - 15) + 10)
    perlin2d_v = perlin2d_dy * perlin2d_dy * perlin2d_dy * (perlin2d_dy * (perlin2d_dy * 6 - 15) + 10)

    perlin2d_A = Perm(perlin2d_X0) + perlin2d_Y0
    perlin2d_B = Perm(perlin2d_X1) + perlin2d_Y0

    ' g00
    perlin2d_h = Perm(perlin2d_A) And 7
    Select Case perlin2d_h
        Case 0: perlin2d_g00 = perlin2d_dx + perlin2d_dy
        Case 1: perlin2d_g00 = -perlin2d_dx + perlin2d_dy
        Case 2: perlin2d_g00 = perlin2d_dx - perlin2d_dy
        Case 3: perlin2d_g00 = -perlin2d_dx - perlin2d_dy
        Case 4: perlin2d_g00 = perlin2d_dx
        Case 5: perlin2d_g00 = -perlin2d_dx
        Case 6: perlin2d_g00 = perlin2d_dy
        Case Else: perlin2d_g00 = -perlin2d_dy
    End Select

    ' g10
    perlin2d_h = Perm(perlin2d_B) And 7
    Select Case perlin2d_h
        Case 0: perlin2d_g10 = (perlin2d_dx - 1) + perlin2d_dy
        Case 1: perlin2d_g10 = -(perlin2d_dx - 1) + perlin2d_dy
        Case 2: perlin2d_g10 = (perlin2d_dx - 1) - perlin2d_dy
        Case 3: perlin2d_g10 = -(perlin2d_dx - 1) - perlin2d_dy
        Case 4: perlin2d_g10 = (perlin2d_dx - 1)
        Case 5: perlin2d_g10 = -(perlin2d_dx - 1)
        Case 6: perlin2d_g10 = perlin2d_dy
        Case Else: perlin2d_g10 = -perlin2d_dy
    End Select

    ' g01
    perlin2d_h = Perm(perlin2d_A + 1) And 7
    Select Case perlin2d_h
        Case 0: perlin2d_g01 = perlin2d_dx + (perlin2d_dy - 1)
        Case 1: perlin2d_g01 = -perlin2d_dx + (perlin2d_dy - 1)
        Case 2: perlin2d_g01 = perlin2d_dx - (perlin2d_dy - 1)
        Case 3: perlin2d_g01 = -perlin2d_dx - (perlin2d_dy - 1)
        Case 4: perlin2d_g01 = perlin2d_dx
        Case 5: perlin2d_g01 = -perlin2d_dx
        Case 6: perlin2d_g01 = (perlin2d_dy - 1)
        Case Else: perlin2d_g01 = -(perlin2d_dy - 1)
    End Select

    ' g11
    perlin2d_h = Perm(perlin2d_B + 1) And 7
    Select Case perlin2d_h
        Case 0: perlin2d_g11 = (perlin2d_dx - 1) + (perlin2d_dy - 1)
        Case 1: perlin2d_g11 = -(perlin2d_dx - 1) + (perlin2d_dy - 1)
        Case 2: perlin2d_g11 = (perlin2d_dx - 1) - (perlin2d_dy - 1)
        Case 3: perlin2d_g11 = -(perlin2d_dx - 1) - (perlin2d_dy - 1)
        Case 4: perlin2d_g11 = (perlin2d_dx - 1)
        Case 5: perlin2d_g11 = -(perlin2d_dx - 1)
        Case 6: perlin2d_g11 = (perlin2d_dy - 1)
        Case Else: perlin2d_g11 = -(perlin2d_dy - 1)
    End Select

    perlin2d_ix0 = perlin2d_g00 + perlin2d_u * (perlin2d_g10 - perlin2d_g00)
    perlin2d_ix1 = perlin2d_g01 + perlin2d_u * (perlin2d_g11 - perlin2d_g01)

    perlin2d_total = perlin2d_total + (perlin2d_ix0 + perlin2d_v * (perlin2d_ix1 - perlin2d_ix0)) * perlin2d_amplitude

    perlin2d_amplitude = perlin2d_amplitude * .5
    perlin2d_frequency = perlin2d_frequency * 2

Next

perlin2d_total = perlin2d_total / 1.875
