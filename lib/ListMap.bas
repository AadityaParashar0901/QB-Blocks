Function ListMapNew$ Static
    ListMapNew$ = Chr$(10) + ListStringNew$
End Function
Sub ListMapAdd (__ListMap$, __Key$, __Value$) Static
    If Len(__ListMap$) < 6 Then Exit Sub
    If Asc(__ListMap$) <> 10 Then Exit Sub
    __List$ = Mid$(__ListMap$, 2)
    __Map$ = MapNew$
    MapSetKey __Map$, __Key$, __Value$
    ListStringAdd __List$, __Map$
    __ListMap$ = Chr$(10) + __List$
End Sub
Function ListMapGet$ (__ListMap$, __Position~&, __Key$) Static
    If Len(__ListMap$) < 6 Then Exit Function
    If Asc(__ListMap$) <> 10 Then Exit Function
    __List$ = Mid$(__ListMap$, 2)
    __Map$ = ListStringGet(__List$, __Position~&)
    ListMapGet$ = MapGetKey(__Map$, __Key$)
End Function
Function ListMapGetKeyList$ (__ListMap$, __Position~&) Static
    If Len(__ListMap$) < 6 Then Exit Function
    If Asc(__ListMap$) <> 10 Then Exit Function
    __List$ = Mid$(__ListMap$, 2)
    __Map$ = ListStringGet(__List$, __Position~&)
    ListMapGetKeyList$ = MapGetKeyList$(__Map$)
End Function
Sub ListMapAddMap (__ListMap$, __Map$) Static
    If Len(__ListMap$) < 6 Then Exit Sub
    If Asc(__ListMap$) <> 10 Then Exit Sub
    __List$ = Mid$(__ListMap$, 2)
    ListStringAdd __List$, __Map$
    __ListMap$ = Chr$(10) + __List$
End Sub
Sub ListMapDelete (__ListMap$, __Position~&) Static
    If Len(__ListMap$) < 6 Then Exit Sub
    If Asc(__ListMap$) <> 10 Then Exit Sub
    __List$ = Mid$(__ListMap$, 2)
    ListStringDelete __List$, __Position~&
    __ListMap$ = Chr$(10) + __List$
End Sub
Function ListMapPrint$ (__ListMap$) Static
    If Len(__ListMap$) < 6 Then Exit Function
    If Asc(__ListMap$) <> 10 Then Exit Function
    __List$ = Mid$(__ListMap$, 2)
    __O$ = "["
    For __I~& = 1 To ListStringLength(__List$)
        __O$ = __O$ + MapPrint$(ListStringGet(__List$, __I~&))
        If __I~& < ListStringLength(__List$) Then __O$ = __O$ + ","
    Next __I~&
    ListMapPrint$ = __O$ + "]"
End Function
Function ListMapLength~& (__ListMap$) Static
    If Len(__ListMap$) < 6 Then ListMapLength~& = 0: Exit Function
    If Asc(__ListMap$) <> 10 Then ListMapLength~& = 0: Exit Function
    ListMapLength~& = CVL(Mid$(__ListMap$, 3, 4))
End Function
