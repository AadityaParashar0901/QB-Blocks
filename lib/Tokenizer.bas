Function Tokenizer$ (L$)
    Dim Token As String, CommentMode As _Unsigned _Byte
    TokenList$ = ListStringNew$
    For I = 1 To Len(L$)
        If CommentMode Then
            If Asc(L$, I) = 35 Then CommentMode = 0
            _Continue
        End If
        Select Case Asc(L$, I)
            Case 35: CommentMode = -1: _Continue
            Case 9, 10, 13:
            Case 32: If Token <> "" Then ListStringAdd TokenList$, Token: Token = ""
            Case 33, 36 To 47, 58 To 64, 91 To 94, 96, 123 To 126
                If Token <> "" Then ListStringAdd TokenList$, Token: Token = ""
                Token = Mid$(L$, I, 1)
                ListStringAdd TokenList$, Token
                Token = ""
            Case Else: Token = Token + Mid$(L$, I, 1)
        End Select
    Next I
    If Token <> "" Then
        ListStringAdd TokenList$, Token
    End If
    Token = ""
    Tokenizer$ = TokenList$
End Function
'$Include:'ListString.bas'
