Function Tokenizer$ (L$)
    Dim Token As String
    TokenList$ = ListStringNew$
    For I = 1 To Len(L$)
        Select Case Asc(L$, I)
            Case 9, 10, 13:
            Case 32:
                If Token <> "" Then ListStringAdd TokenList$, Token: Token = ""
            Case 33, 35 To 47, 58 To 64, 91 To 94, 96, 123 To 126
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
