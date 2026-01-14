#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE17                                                                          |
 | Data       : 03/12/2025                                                                        |
 | Respons�vel: EMANUEL AZEVEDO                                                                   |
 | Descricao  : Calcula e envia descontos por produto (faixas de preco) para o MaxPedido.         |
 | Logica propria (faixas de quantidade fixas).                                                   |
 *-------------------------------------------------------------------------------------------------*/

User Function JOBFVE17()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest         := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .T.

    If Empty(cBearerToken)
        Return .F.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath("/Descontos")
    oRest:SetPostParams(DescontosJson())

    If (oRest:Post(aHeader))
    Else
        lSucesso := .F.
    EndIf

    oRest:SetPath("/DescontosCapas")
    oRest:SetPostParams(DescontosCapasJson())

    If (oRest:Post(aHeader))
    Else
        lSucesso := .F.
    EndIf

    oRest:SetPath("/DescontosItens")
    oRest:SetPostParams(DescontosItensJson())

    If (oRest:Post(aHeader))
    Else
        lSucesso := .F.
    EndIf

Return lSucesso

Static Function DescontosJson()
    Local aBody        := {}
    Local oBody        := NIL
    Local cJson        := ""
    Local cQry         := ""
    Local cCodFilial   := "0602"
    Local cProdAnt     := ""
    Local cCodProd     := ""
    Local nFaixa       := 0
    Local aPrecos      := {}
    Local aPrecProd    := {0, 0, 0, 0}
    Local nPrecoBase   := 0
    Local nPrecoFx     := 0
    Local nPercDesc    := 0
    Local nI           := 0
    Local nJ           := 0

    // Faixas de quantidade (volume)
    Local aTiers := { ;
        {1,     100   }, ;
        {101,   500   }, ;
        {501,   1000  }, ;
        {1001,  999999}  ;
    }

    // Preco base = maior preco por produto (faixa 1)
    // Empresa 06-02 - EMPRESA_EXEMPLO_A
    RPCSetEnv("06", "02", , , "FAT")
    Local cTabDA1 := RetSqlName("DA1")
    Local cTabDA0 := RetSqlName("DA0")

    cQry := ""
    cQry += "SELECT DA1.DA1_CODPRO AS CODPROD," + CRLF
    cQry += "       DA1.DA1_PRCVEN AS PRECO," + CRLF
    cQry += "       ROW_NUMBER() OVER (PARTITION BY DA1.DA1_CODPRO ORDER BY DA1.DA1_PRCVEN DESC) AS FAIXA" + CRLF
    cQry += "  FROM " + cTabDA1 + " DA1 WITH (NOLOCK)" + CRLF
    cQry += " INNER JOIN " + cTabDA0 + " DA0 WITH (NOLOCK)" + CRLF
    cQry += "    ON DA0.DA0_CODTAB = DA1.DA1_CODTAB" + CRLF
    cQry += "   AND DA0.DA0_FILIAL = DA1.DA1_FILIAL" + CRLF
    cQry += "   AND DA0.D_E_L_E_T_ = ' '" + CRLF
    cQry += " WHERE DA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "   AND DA1.DA1_FILIAL = '02'" + CRLF
    cQry += "   AND DA1.DA1_CODTAB = '003'" + CRLF
    cQry += " ORDER BY DA1.DA1_CODPRO, FAIXA" + CRLF

    TCQuery cQry New Alias 'TABDESC'

    If TABDESC->(EoF())
        TABDESC->(DbCloseArea())
        Return "[]"
    EndIf

    While !TABDESC->(EoF())
        cCodProd := AllTrim(TABDESC->CODPROD)
        nFaixa   := TABDESC->FAIXA

        If cCodProd != cProdAnt .And. !Empty(cProdAnt)
            AAdd(aPrecos, {cProdAnt, AClone(aPrecProd)})
            aPrecProd := {0, 0, 0, 0}
        EndIf

        If nFaixa >= 1 .And. nFaixa <= 4
            aPrecProd[nFaixa] := TABDESC->PRECO
        EndIf

        cProdAnt := cCodProd
        TABDESC->(DbSkip())
    EndDo

    If !Empty(cProdAnt)
        AAdd(aPrecos, {cProdAnt, AClone(aPrecProd)})
    EndIf

    TABDESC->(DbCloseArea())

    For nI := 1 To Len(aPrecos)
        cCodProd   := aPrecos[nI][1]
        nPrecoBase := aPrecos[nI][2][1]

        If nPrecoBase <= 0
            Loop
        EndIf

        For nJ := 1 To Len(aTiers)
            nPrecoFx := aPrecos[nI][2][nJ]

             If nPrecoFx <= 0
                nPrecoFx := nPrecoBase
            EndIf

            // Calcula percentual de desconto
            If nJ == 1
                nPercDesc := 0
            Else
                nPercDesc := Round(((nPrecoBase - nPrecoFx) / nPrecoBase) * 100, 4)
            EndIf

            oBody := JsonObject():New()
            oBody["CODDESCONTO"]   := cCodProd + "-F" + AllTrim(cValToChar(nJ))
            oBody["CODFILIAL"]     := cCodFilial
            oBody["CODPROD"]       := cCodProd
            oBody["TIPO"]          := "C"  
            oBody["DTINICIO"]      := "2025-01-01"
            oBody["DTFIM"]         := "2026-12-31"
            oBody["QTINI"]         := aTiers[nJ][1]
            oBody["QTFIM"]         := aTiers[nJ][2]
            oBody["PERCDESC"]      := nPercDesc          
            oBody["PERCDESCFIN"]   := 0          
            oBody["VLRMAXIMO"]     := nPrecoBase    
            oBody["VLRMINIMO"]     := nPrecoFx  
            oBody["ORIGEMPED"]     := "F"       
            oBody["NUMREGIAO"]     := "003"
            oBody["CODSEC"]        := "0001"
            oBody["CODEPTO"]       := "1"
            oBody["TIPODESCONTO"]  := "A"
            oBody["APLICADESCONTO"]:= "S" 
            oBody["PRIORITARIA"]   := "N"

            AAdd(aBody, oBody)
        Next nJ
    Next nI

    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
Return cJson

Static Function DescontosCapasJson()
    Local aBody     := {}
    Local oBody     := NIL
    Local cJson     := ""
    Local cQry      := ""
    Local cCodFilial:= "0602"  // Filial EMPRESA_EXEMPLO_A
    Local cDtIni    := ""
    Local cDtFim    := ""

    // Busca as datas de vigencia da tabela de precos 003
    RPCSetEnv("06", "02", , , "FAT")
    cTabDA0 := RetSqlName("DA0")

    cQry := ""
    cQry += "SELECT DA0.DA0_CODTAB," + CRLF
    cQry += "       DA0.DA0_DESCRI," + CRLF
    cQry += "       DA0.DA0_DATDE," + CRLF
    cQry += "       DA0.DA0_DATATE" + CRLF
    cQry += "  FROM " + cTabDA0 + " DA0 WITH (NOLOCK)" + CRLF
    cQry += " WHERE DA0.D_E_L_E_T_ = ' '" + CRLF
    cQry += "   AND DA0.DA0_FILIAL = '02'" + CRLF
    cQry += "   AND DA0.DA0_CODTAB = '003'" + CRLF


    TCQuery cQry New Alias 'TABCAPA'

    If TABCAPA->(EoF())
        TABCAPA->(DbCloseArea())
        Return "[]"
    EndIf

    // Formata datas
    cDtIni := FmtDtApiStr(AllTrim(TABCAPA->DA0_DATDE))
    cDtFim := FmtDtApiStr(AllTrim(TABCAPA->DA0_DATATE))

    // Se nao tiver data, usa padrao
    If Empty(cDtIni)
        cDtIni := "2025-01-01"
    EndIf
    If Empty(cDtFim)
        cDtFim := "2026-12-31"
    EndIf

    oBody := JsonObject():New()

    // Campos PK
    oBody["CODIGO"]              := "ESCALONADO-EMPRESA_EXEMPLO_A-" + AllTrim(TABCAPA->DA0_CODTAB)
    oBody["DESCRICAO"]           := "Desconto Escalonado - " + AllTrim(TABCAPA->DA0_DESCRI)
    oBody["DTINICIO"]            := cDtIni
    oBody["DTFIM"]               := cDtFim
    oBody["TIPOCAMPANHA"]        := "FPU"
    oBody["TIPODESCONTO"]        := "P"
    oBody["TIPOVALIDACAO"]       := "A"
    oBody["CODFILIAL"]           := cCodFilial
    oBody["TIPOPATROCINIO"]      := ""
    oBody["UTILIZACODPRODPRINC"] := "N"
    oBody["UTILIZACODCLIPRINC"]  := "N"
    oBody["METODOLOGIA"]         := "Desconto progressivo por volume total do pedido. Faixas: 1-100un (0%), 101-500un (~13%), 501-1000un (~21%), +1000un (~25%)"
    oBody["PROPORCIONAL"]        := "N"
    oBody["COMBOCONTINUO"]       := "N"
    oBody["NAODEBITCCRCA"]       := "N"
    oBody["CREDITAPOLITICA"]     := "N"
    oBody["QTDECOMBOCLIENTE"]    := 1000
    oBody["QTDECOMBOUSUR"]       := 1000
    oBody["VALIDAPESO"]          := "N"

    AAdd(aBody, oBody)

    TABCAPA->(DbCloseArea())


    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
Return cJson

Static Function DescontosItensJson()
    Local aBody     := {}
    Local oBody     := NIL
    Local cJson     := ""
    Local cQry      := ""
    Local nSeq      := 0
    Local cCodCampanha := "ESCALONADO-EMPRESA_EXEMPLO_A-003"

    // Faixas de quantidade
    Local aTiers := { ;
        {1,     100   }, ;     // Faixa 1: 1-100 (0%)
        {101,   500   }, ;     // Faixa 2: 101-500 (~13%)
        {501,   1000  }, ;     // Faixa 3: 501-1000 (~21%)
        {1001,  999999}  ;     // Faixa 4: 1001+ (~25%)
    }

    Local nI, nJ      := 0
    Local nPrecoBase  := 0
    Local nPrecoFx    := 0
    Local nPercDesc   := 0
    Local cCodProd    := ""
    Local aPrecos     := {}
    Local aPrecProd   := {0, 0, 0, 0}
    Local cProdAnt    := ""
    Local nFaixa      := 0


    RPCSetEnv("06", "02", , , "FAT")
    cTabDA1 := RetSqlName("DA1")
    cTabDA0 := RetSqlName("DA0")

    cQry := ""
    cQry += "SELECT DA1.DA1_CODPRO AS CODPROD," + CRLF
    cQry += "       DA1.DA1_PRCVEN AS PRECO," + CRLF
    cQry += "       ROW_NUMBER() OVER (PARTITION BY DA1.DA1_CODPRO ORDER BY DA1.DA1_PRCVEN DESC) AS FAIXA" + CRLF
    cQry += "  FROM " + cTabDA1 + " DA1 WITH (NOLOCK)" + CRLF
    cQry += " INNER JOIN " + cTabDA0 + " DA0 WITH (NOLOCK)" + CRLF
    cQry += "    ON DA0.DA0_CODTAB = DA1.DA1_CODTAB" + CRLF
    cQry += "   AND DA0.DA0_FILIAL = DA1.DA1_FILIAL" + CRLF
    cQry += "   AND DA0.D_E_L_E_T_ = ' '" + CRLF
    cQry += " WHERE DA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += " AND DA1.DA1_FILIAL = '02'" + CRLF
    cQry += "   AND DA1.DA1_CODTAB = '003'" + CRLF
    cQry += " ORDER BY DA1.DA1_CODPRO, FAIXA" + CRLF

    TCQuery cQry New Alias 'TABPRECO'

    If TABPRECO->(EoF())
        TABPRECO->(DbCloseArea())
        Return "[]"
    EndIf

    cProdAnt := ""
    aPrecProd := {0, 0, 0, 0}

    While !TABPRECO->(EoF())
        cCodProd := AllTrim(TABPRECO->CODPROD)
        nFaixa   := TABPRECO->FAIXA

        If cCodProd != cProdAnt .And. !Empty(cProdAnt)
            AAdd(aPrecos, {cProdAnt, AClone(aPrecProd)})
            aPrecProd := {0, 0, 0, 0}
        EndIf

        If nFaixa >= 1 .And. nFaixa <= 4
            aPrecProd[nFaixa] := TABPRECO->PRECO
        EndIf

        cProdAnt := cCodProd
        TABPRECO->(DbSkip())
    EndDo

    If !Empty(cProdAnt)
        AAdd(aPrecos, {cProdAnt, AClone(aPrecProd)})
    EndIf

    TABPRECO->(DbCloseArea())

    nSeq := 0

    For nI := 1 To Len(aPrecos)
        cCodProd   := aPrecos[nI][1]
        nPrecoBase := aPrecos[nI][2][1]  // Preco da Faixa 1 (base/mais alto)

        If nPrecoBase <= 0
            Loop
        EndIf

        For nJ := 1 To Len(aTiers)
            nSeq++
            nPrecoFx := aPrecos[nI][2][nJ]

             If nPrecoFx <= 0
                nPrecoFx := nPrecoBase
            EndIf

            // Calcula percentual de desconto
            If nJ == 1
                nPercDesc := 0
            Else
                nPercDesc := Round(((nPrecoBase - nPrecoFx) / nPrecoBase) * 100, 2)
            EndIf
            oBody := JsonObject():New()

            // Campos PK (Chave)
            oBody["CODIGO"]       := cCodCampanha
            oBody["SEQUENCIA"]    := nSeq
            oBody["CODPROD"]      := cCodProd
            oBody["QTMINIMA"]     := aTiers[nJ][1]
            oBody["QTMAXIMA"]     := aTiers[nJ][2]
            oBody["PERDESC"]      := nPercDesc
            oBody["TIPODESCONTO"] := 1
            AAdd(aBody, oBody)
        Next nJ
    Next nI

    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
Return cJson

Static Function FmtDtApi(dData)
    Local cData := ""
    
    If !Empty(dData)
        cData := Str(Year(dData), 4) + "-" + StrZero(Month(dData), 2) + "-" + StrZero(Day(dData), 2)
    EndIf
    
Return cData


Static Function FmtDtApiStr(cData)
    Local cRet := ""
    Local cNum := ""
    Local nPos := 0
    Local cChr := ""

    If Empty(AllTrim(cData))
        Return ""
    EndIf

    // Extrai apenas numeros
    For nPos := 1 To Len(AllTrim(cData))
        cChr := SubStr(AllTrim(cData), nPos, 1)
        If cChr >= "0" .And. cChr <= "9"
            cNum += cChr
        EndIf
    Next nPos

    // Formato YYYYMMDD
    If Len(cNum) == 8
        cRet := SubStr(cNum, 1, 4) + "-" + SubStr(cNum, 5, 2) + "-" + SubStr(cNum, 7, 2)
    EndIf

Return cRet
