#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE15                                                                          | 
 | Data       : 25/11/2025                                                                        |
 | Autor      : EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envio de PlanosPagamentos para o MaxPedido                                        |
 | Versao     : 1.9 - Corrigido PlagPagCliJson para vincular todos os planos ao cliente           |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE15()
    Local cURI   := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest  := NIL
    Local aHead  := {}
    Local cToken := ""
    Local cJson  := ""
    Local lSuc1  := .F.
    Local lSuc2  := .F.
    Local lSuc3  := .F.
    Local lSuc4  := .F.
    Local lSuc5  := .F.

    // verifica se � necess�rio inicializar o ambiente
If Select("SX2") <= 0
    RPCSetEnv("06", "02", , , "FAT")
EndIf

    cToken := U_JOBFVAUT()

    If Empty(cToken)
        Return .F.
    EndIf

    AAdd(aHead, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHead, "Accept: application/json")
    AAdd(aHead, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHead, "Authorization: Bearer " + cToken)

    // 1. PlanosPagamentos
    cJson := PlagPagJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/PlanosPagamentos")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc1 := .T.
        EndIf
    EndIf

    // 2. PlanosPagamentosFiliais
    cJson := PlagPagFilJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/PlanosPagamentosFiliais")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc2 := .T.
        EndIf
    EndIf

    // 3. PlanosPagamentosClientes - CROSS JOIN cliente x planos
    cJson := PlagPagCliJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/PlanosPagamentosClientes")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc3 := .T.
        EndIf
    EndIf

    // 4. PlanosPagamentosProdutos
    cJson := PlagPagPrdJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/PlanosPagamentosProdutos")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc4 := .T.
        EndIf
    EndIf

    // 5. PlanosPagamentosRegioes
    cJson := PlagPagRegJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/PlanosPagamentosRegioes")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc5 := .T.
        EndIf
    EndIf

Return (lSuc1 .And. lSuc2 .And. lSuc3 .And. lSuc4 .And. lSuc5)

Static Function _GetCfg()
    Local aCfg := {}
    Local cTabSA1_1 := ""
    Local cTabSE4_1 := ""
    Local cTabSA1_2 := ""
    Local cTabSE4_2 := ""

    // Primeira empresa (06-02)
    RPCSetEnv("06", "02", , , "FAT")
    cTabSA1_1 := RetSqlName("SA1")
    cTabSE4_1 := RetSqlName("SE4")

    // Segunda empresa (01-05)
    RPCSetEnv("01", "05", , , "FAT")
    cTabSA1_2 := RetSqlName("SA1")
    cTabSE4_2 := RetSqlName("SE4")

    // {CODFILMAX, SA1, SE4, FILIAL_SA1, FILIAL_SE4, REGIOES}
    AAdd(aCfg, {"0602", cTabSA1_1, cTabSE4_1, "02", "0201", {"002","003","004","005"}})
    AAdd(aCfg, {"0105", cTabSA1_2, cTabSE4_2, "05", "0501", {"001"}})
Return aCfg

Static Function _GetCfgPrd()
    Local aCfg := {}
    Local cTabSB1_1 := ""
    Local cTabSE4_1 := ""
    Local cTabSB1_2 := ""
    Local cTabSE4_2 := ""

    // Primeira empresa (06-02)
    RPCSetEnv("06", "02", , , "FAT")
    cTabSB1_1 := RetSqlName("SB1")
    cTabSE4_1 := RetSqlName("SE4")

    // Segunda empresa (01-05)
    RPCSetEnv("01", "05", , , "FAT")
    cTabSB1_2 := RetSqlName("SB1")
    cTabSE4_2 := RetSqlName("SE4")

    // {CODFILMAX, SB1, SE4, FILIAL_SB1, FILIAL_SE4, TIPO_PROD}
    AAdd(aCfg, {"0602", cTabSB1_1, cTabSE4_1, "02", "0201", "PA"})
    AAdd(aCfg, {"0105", cTabSB1_2, cTabSE4_2, "05", "0501", "ME"})
Return aCfg

Static Function PlagPagJson()
    Local aCfg  := _GetCfg()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0
    Local nPrz  := 0
    Local nPrz1 := 0

    For nI := 1 To Len(aCfg)
        cQry += IIf(!Empty(cQry), " UNION ALL ", "")
        cQry += "SELECT "
        cQry += "'" + aCfg[nI][1] + "' AS CODFIL,"
        cQry += "RTRIM(E4_CODIGO) AS CODCOND,"
        cQry += "RTRIM(E4_COND) AS COND,"
        cQry += "RTRIM(E4_DESCRI) AS DESCR "
        cQry += "FROM " + aCfg[nI][3] + " WITH (NOLOCK) "
        cQry += "WHERE D_E_L_E_T_ = ' ' "
        cQry += "AND E4_FILIAL = '" + aCfg[nI][5] + "' "
        cQry += "AND E4_TIPO = '1' "
    Next nI

    cQry += "ORDER BY CODFIL, CODCOND"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        nPrz  := CalcPrz(AllTrim((cAls)->COND))
        nPrz1 := CalcPrz1(AllTrim((cAls)->COND))

        oRow := JsonObject():New()
        oRow["CODPLPAG"]    := AllTrim((cAls)->CODCOND)
        oRow["DESCRICAO"]   := AllTrim((cAls)->DESCR)
        oRow["NUMDIAS"]     := nPrz
        oRow["NUMPR"]       := 1
        oRow["PERTXFIM"]    := 0
        oRow["VENDABK"]     := "S"
        oRow["VLMINPEDIDO"] := 0
        oRow["PRAZO1"]      := nPrz1
        oRow["TIPOPRAZO"]   := "N"
        oRow["TIPOVENDA"]   := "VP"

        If !Empty(oRow["CODPLPAG"]) .And. !Empty(oRow["DESCRICAO"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"

Static Function PlagPagFilJson()
    Local aCfg  := _GetCfg()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0

    For nI := 1 To Len(aCfg)
        cQry += IIf(!Empty(cQry), " UNION ALL ", "")
        cQry += "SELECT "
        cQry += "'" + aCfg[nI][1] + "' AS CODFIL,"
        cQry += "RTRIM(E4_CODIGO) AS CODCOND "
        cQry += "FROM " + aCfg[nI][3] + " WITH (NOLOCK) "
        cQry += "WHERE D_E_L_E_T_ = ' ' "
        cQry += "AND E4_FILIAL = '" + aCfg[nI][5] + "' "
        cQry += "AND E4_TIPO = '1' "
    Next nI

    cQry += "ORDER BY CODFIL, CODCOND"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODPLPAG"]  := AllTrim((cAls)->CODCOND)
        oRow["CODFILIAL"] := AllTrim((cAls)->CODFIL)

        If !Empty(oRow["CODPLPAG"]) .And. !Empty(oRow["CODFILIAL"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"


Static Function PlagPagCliJson()
    Local aCfg  := _GetCfg()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0

    For nI := 1 To Len(aCfg)
        cQry += IIf(!Empty(cQry), " UNION ALL ", "")
        cQry += "SELECT "
        cQry += "RTRIM(SE4.E4_CODIGO) AS CODPAG,"
        cQry += "'" + aCfg[nI][1] + "' + RTRIM(SA1.A1_COD) + RTRIM(SA1.A1_LOJA) AS CODCLI "
        cQry += "FROM " + aCfg[nI][2] + " SA1 WITH (NOLOCK) "
        cQry += "CROSS JOIN " + aCfg[nI][3] + " SE4 WITH (NOLOCK) "
        cQry += "WHERE SA1.D_E_L_E_T_ = ' ' "
        cQry += "AND SE4.D_E_L_E_T_ = ' ' "
        cQry += "AND SA1.A1_FILIAL LIKE '" + aCfg[nI][4] + "%' "
        cQry += "AND SA1.A1_MSBLQL <> '1' "
        cQry += "AND SE4.E4_FILIAL = '" + aCfg[nI][5] + "' "
        cQry += "AND SE4.E4_TIPO = '1' "
    Next nI

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODPLPAG"] := AllTrim((cAls)->CODPAG)
        oRow["CODCLI"]   := AllTrim((cAls)->CODCLI)

        If !Empty(oRow["CODPLPAG"]) .And. !Empty(oRow["CODCLI"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"

Static Function PlagPagPrdJson()
    Local aCfg  := _GetCfgPrd()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0

    For nI := 1 To Len(aCfg)
        cQry += IIf(!Empty(cQry), " UNION ALL ", "")
        cQry += "SELECT "
        cQry += "'" + aCfg[nI][1] + "' AS CODFIL,"
        cQry += "RTRIM(SB1.B1_COD) AS CODPRD,"
        cQry += "RTRIM(SE4.E4_CODIGO) AS CODPAG "
        cQry += "FROM " + aCfg[nI][2] + " SB1 WITH (NOLOCK) "
        cQry += "CROSS JOIN " + aCfg[nI][3] + " SE4 WITH (NOLOCK) "
        cQry += "WHERE SB1.D_E_L_E_T_ = ' ' "
        cQry += "AND SB1.B1_FILIAL = '" + aCfg[nI][4] + "' "
        cQry += "AND SB1.B1_TIPO = '" + aCfg[nI][6] + "' "
        cQry += "AND SE4.D_E_L_E_T_ = ' ' "
        cQry += "AND SE4.E4_FILIAL = '" + aCfg[nI][5] + "' "
        cQry += "AND SE4.E4_TIPO = '1' "
    Next nI

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODFILIAL"] := AllTrim((cAls)->CODFIL)
        oRow["CODPROD"]   := AllTrim((cAls)->CODPRD)
        oRow["DTINICIAL"] := NIL
        oRow["DTFINAL"]   := NIL
        oRow["CODPLPAG"]  := AllTrim((cAls)->CODPAG)

        If !Empty(oRow["CODFILIAL"]) .And. !Empty(oRow["CODPROD"]) .And. !Empty(oRow["CODPLPAG"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"

Static Function PlagPagRegJson()
    Local aCfg  := _GetCfg()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0
    Local nR    := 0

    For nI := 1 To Len(aCfg)
        For nR := 1 To Len(aCfg[nI][6])
            cQry += IIf(!Empty(cQry), " UNION ALL ", "")
            cQry += "SELECT "
            cQry += "'" + aCfg[nI][1] + "' + RTRIM(SA1.A1_COD) + RTRIM(SA1.A1_LOJA) AS CODCLI,"
            cQry += "'" + aCfg[nI][6][nR] + "' AS NUMREG,"
            cQry += "RTRIM(SE4.E4_CODIGO) AS CODPAG "
            cQry += "FROM " + aCfg[nI][2] + " SA1 WITH (NOLOCK) "
            cQry += "CROSS JOIN " + aCfg[nI][3] + " SE4 WITH (NOLOCK) "
            cQry += "WHERE SA1.D_E_L_E_T_ = ' ' "
            cQry += "AND SE4.D_E_L_E_T_ = ' ' "
            cQry += "AND SA1.A1_FILIAL LIKE '" + aCfg[nI][4] + "%' "
            cQry += "AND SA1.A1_MSBLQL <> '1' "
            cQry += "AND SE4.E4_FILIAL = '" + aCfg[nI][5] + "' "
            cQry += "AND SE4.E4_TIPO = '1' "
        Next nR
    Next nI

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODCLI"]    := AllTrim((cAls)->CODCLI)
        oRow["NUMREGIAO"] := AllTrim((cAls)->NUMREG)
        oRow["CODPLPAG"]  := AllTrim((cAls)->CODPAG)

        If !Empty(oRow["CODCLI"]) .And. !Empty(oRow["NUMREGIAO"]) .And. !Empty(oRow["CODPLPAG"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"

// Calcula prazo medio (para NUMDIAS)
Static Function CalcPrz(cCond)
    Local aPrz := {}
    Local nTot := 0
    Local nI   := 0

    cCond := AllTrim(cCond)
    If Empty(cCond)
        Return 0
    EndIf

    If At("/", cCond) == 0
        Return Val(cCond)
    EndIf

    aPrz := StrTokArr(cCond, "/")
    If Len(aPrz) == 0
        Return 0
    EndIf

    For nI := 1 To Len(aPrz)
        nTot += Val(AllTrim(aPrz[nI]))
    Next nI

Return Round(nTot / Len(aPrz), 0)

// Retorna primeiro prazo (para PRAZO1)
Static Function CalcPrz1(cCond)
    Local aPrz := {}

    cCond := AllTrim(cCond)
    If Empty(cCond)
        Return 0
    EndIf

    If At("/", cCond) == 0
        Return Val(cCond)
    EndIf

    aPrz := StrTokArr(cCond, "/")
    If Len(aPrz) == 0
        Return 0
    EndIf

Return Val(AllTrim(aPrz[1]))
