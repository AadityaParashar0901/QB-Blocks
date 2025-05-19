Function ListStringNew$
    ListStringNew$ = Chr$(1) + MKL$(0)
End Function
Function ListStringFromString$ (ARRAY$)
    LIST$ = Chr$(1) + MKL$(0)
    __LISTLENGTH~& = 0
    For I~& = 1 To Len(ARRAY$)
        BYTE~%% = Asc(ARRAY$, I~&)
        Select Case BYTE~%%
            Case 91: NEST~& = NEST~& + 1
                V$ = V$ + Chr$(BYTE~%%)
            Case 93: NEST~& = NEST~& - 1
                V$ = V$ + Chr$(BYTE~%%)
            Case 44: If NEST~& = 0 Then
                    __LISTLENGTH~& = __LISTLENGTH~& + 1
                    LIST$ = LIST$ + MKI$(Len(V$)) + V$
                    V$ = ""
                Else
                    V$ = V$ + Chr$(BYTE~%%)
                End If
            Case Else:
                V$ = V$ + Chr$(BYTE~%%)
        End Select
    Next I~&
    If Len(V$) Then
        LIST$ = LIST$ + MKI$(Len(V$)) + V$
        __LISTLENGTH~& = __LISTLENGTH~& + 1
        V$ = ""
    End If
    Mid$(LIST$, 2, 4) = MKL$(__LISTLENGTH~&)
    ListStringFromString$ = LIST$
    LIST$ = ""
End Function
Function ListStringFromArray$ (ARRAY() As String, START_INDEX~&, END_INDEX~&)
    K~& = 0
    For I~& = START_INDEX~& To END_INDEX~&
        K~& = K~& + 2 + Len(ARRAY(I~&))
    Next I~&
    LIST$ = Chr$(1) + MKL$(END_INDEX~& - START_INDEX~& + 1) + String$(K~&, 0)
    K~& = 6
    L~% = 0
    For I~& = START_INDEX~& To END_INDEX~&
        L~% = Len(ARRAY(I~&))
        Mid$(LIST$, K~&, 2 + L~%) = MKI$(L~%) + ARRAY(I~&)
        K~& = K~& + L~% + 2
    Next I~&
    ListStringFromArray$ = LIST$
    LIST$ = ""
End Function
Function ListStringPrint$ (LIST$)
    If Len(LIST$) < 5 Then Exit Function
    If Asc(LIST$) <> 1 Then Exit Function
    O = 6: T_OFFSET = 2
    T$ = String$(Len(LIST$) - 4, 0)
    Asc(T$) = 91 '[
    For I = 1 To CVL(Mid$(LIST$, 2, 4)) - 1
        L = CVI(Mid$(LIST$, O, 2))
        Mid$(T$, T_OFFSET, L + 1) = Mid$(LIST$, O + 2, L) + ","
        T_OFFSET = T_OFFSET + L + 1
        O = O + L + 2
    Next I
    L = CVI(Mid$(LIST$, O, 2))
    Mid$(T$, T_OFFSET, L + 1) = Mid$(LIST$, O + 2, L) + "]"
    ListStringPrint$ = Left$(T$, T_OFFSET + L + 1)
End Function
Function ListStringLength~& (LIST$)
    If Len(LIST$) < 5 Then Exit Function
    If Asc(LIST$) <> 1 Then Exit Function
    ListStringLength~& = CVL(Mid$(LIST$, 2, 4))
End Function
Sub ListStringAdd (LIST$, ITEM$)
    If Len(LIST$) < 5 Then Exit Sub
    If Asc(LIST$) <> 1 Then Exit Sub
    LIST$ = Chr$(1) + MKL$(CVL(Mid$(LIST$, 2, 4)) + 1) + Mid$(LIST$, 6) + MKI$(Len(ITEM$)) + ITEM$
End Sub
Function ListStringGet$ (LIST$, POSITION As _Unsigned Long)
    If Len(LIST$) < 5 Then Exit Function
    If Asc(LIST$) <> 1 Then Exit Function
    If CVL(Mid$(LIST$, 2, 4)) < POSITION - 1 Then Exit Function
    O = 6
    For I = 1 To POSITION - 1
        L = CVI(Mid$(LIST$, O, 2))
        O = O + L + 2
    Next I
    ListStringGet$ = Mid$(LIST$, O + 2, CVI(Mid$(LIST$, O, 2)))
End Function
Sub ListStringInsert (LIST$, ITEM$, POSITION As _Unsigned Long)
    If Len(LIST$) < 5 Then Exit Sub
    If Asc(LIST$) <> 1 Then Exit Sub
    If CVL(Mid$(LIST$, 2, 4)) < POSITION - 1 Then Exit Sub
    O = 6
    For I = 1 To POSITION - 1
        L = CVI(Mid$(LIST$, O, 2))
        O = O + L + 2
    Next I
    LIST$ = Chr$(1) + MKL$(CVL(Mid$(LIST$, 2, 4)) + 1) + Mid$(LIST$, 6, O - 6) + MKI$(Len(ITEM$)) + ITEM$ + Mid$(LIST$, O)
End Sub
Sub ListStringDelete (LIST$, POSITION As _Unsigned Long)
    If Len(LIST$) < 5 Then Exit Sub
    If Asc(LIST$) <> 1 Then Exit Sub
    If CVL(Mid$(LIST$, 2, 4)) < POSITION - 1 Then Exit Sub
    O = 6
    For I = 1 To POSITION - 1
        L = CVI(Mid$(LIST$, O, 2))
        O = O + L + 2
    Next I
    LIST$ = Chr$(1) + MKL$(CVL(Mid$(LIST$, 2, 4)) - 1) + Mid$(LIST$, 6, O - 6) + Mid$(LIST$, O + CVI(Mid$(LIST$, O, 2)) + 2)
End Sub
Function ListStringSearch~& (LIST$, ITEM$)
    If Len(LIST$) < 5 Then Exit Function
    If Asc(LIST$) <> 1 Then Exit Function
    O = 6
    For I = 1 To CVL(Mid$(LIST$, 2, 4))
        L = CVI(Mid$(LIST$, O, 2))
        If ITEM$ = Mid$(LIST$, O + 2, L) Then ListStringSearch~& = I: Exit Function
        O = O + L + 2
    Next I
    ListStringSearch~& = 0
End Function
Function ListStringSearchI~& (LIST$, ITEM$)
    If Len(LIST$) < 5 Then Exit Function
    If Asc(LIST$) <> 1 Then Exit Function
    O = 6
    For I = 1 To CVL(Mid$(LIST$, 2, 4))
        L = CVI(Mid$(LIST$, O, 2))
        If _StriCmp(ITEM$, Mid$(LIST$, O + 2, L)) = 0 Then ListStringSearchI~& = I: Exit Function
        O = O + L + 2
    Next I
    ListStringSearchI~& = 0
End Function
Sub ListStringEdit (LIST$, ITEM$, POSITION As _Unsigned Long)
    If Len(LIST$) < 5 Then Exit Sub
    If Asc(LIST$) <> 1 Then Exit Sub
    If CVL(Mid$(LIST$, 2, 4)) < POSITION - 1 Then Exit Sub
    O = 6
    For I = 1 To POSITION - 1
        L = CVI(Mid$(LIST$, O, 2))
        O = O + L + 2
    Next I
    LIST$ = Left$(LIST$, O - 1) + MKI$(Len(ITEM$)) + ITEM$ + Mid$(LIST$, O + CVI(Mid$(LIST$, O, 2)) + 2)
End Sub
Function ListStringAppend$ (LIST1$, LIST2$)
    If Len(LIST1$) < 5 Then Exit Function
    If Len(LIST2$) < 5 Then Exit Function
    If Asc(LIST1$) <> 1 Then Exit Function
    If Asc(LIST2$) <> 1 Then Exit Function
    ListStringAppend$ = Chr$(1) + MKL$(CVL(Mid$(LIST1$, 2, 4)) + CVL(Mid$(LIST2$, 2, 4))) + Mid$(LIST1$, 6) + Mid$(LIST2$, 6)
End Function
