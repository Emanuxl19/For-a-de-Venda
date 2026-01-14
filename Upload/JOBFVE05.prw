//Bibliotecas
#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Data       : 08/11/2025                                                                         |
 | Rotina     : JOBFVE05                                                                           |
 | Descricao  : Integracao de Tabelas de Preco (MXSTABPR) para o MaxPedido.                        |
 | Autor      : Emanuel Azevedo                                                                    |
 | versao     : 1.0                                                                                |
 *-------------------------------------------------------------------------------------------------*/

User Function JOBFVE05()
    Local cURI         := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource    := "/TabelasPrecos"
    Local oRest        := FwRest():New(cURI)
    Local aHeader      := {}
    Local cBearerToken := U_JOBFVAUT()
    Local lSucesso     := .F.
    Local cJson        := ""
    Local nRegistros   := 0

      If Select("SX2") <= 0
        RPCSetEnv("06", "02", , , "FAT")
      EndIf
          
    If Empty(cBearerToken)
        ConOut("JOBFVE05 >> Token nao informado. Abortando envio.")
        Return .F.
    EndIf

    cJson := PrecosJson(@nRegistros)

    ConOut("JOBFVE05 >> JSON gerado (primeiros 2000 chars):")
    ConOut(SubStr(cJson, 1, 2000))

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath(cResource)
    oRest:SetPostParams(cJson)

    If oRest:Post(aHeader)
        ConOut("JOBFVE05 >> Tabelas de preco enviadas com sucesso (" + cValToChar(nRegistros) + " registros).")
        ConOut("JOBFVE05 >> HTTP: " + cValToChar(oRest:GetHTTPCode()))
        lSucesso := .T.
    Else
        ConOut("JOBFVE05 >> Erro ao enviar tabelas de preco:" + CRLF + oRest:GetLastError())
        ConOut("JOBFVE05 >> HTTP: " + cValToChar(oRest:GetHTTPCode()))
        ConOut("JOBFVE05 >> Retorno bruto: " + oRest:GetResult())
    EndIf

Return lSucesso

Static Function PrecosJson(nTotal)
    Local aBody      := {}
    Local aPrecos    := {}
    Local cQry       := ""
    Local cProdAnt   := ""
    Local cCodProd   := ""
    Local nFaixa     := 0
    Local nPreco     := 0
    Local nI         := 0
    Local nJ         := 0
    Local cDtIni     := ""
    Local cDtFim     := ""
    Local oItem      := NIL
    Local aFaixaPreco:= {0, 0, 0, 0}  // Precos das 4 faixas
    Local nUltPreco  := 0
    
    Local aRegioes := {"002", "003", "004", "005"}


    // Primeira empresa (06-02) - EMPRESA_EXEMPLO_A
    RPCSetEnv("06", "02", , , "FAT")
    Local cTabDA1 := RetSqlName("DA1")
    Local cTabDA0 := RetSqlName("DA0")
    Local cTabSB1 := RetSqlName("SB1")

    cQry := ""
    cQry += "SELECT " + CRLF
    cQry += "    DA1.DA1_CODPRO AS CODPROD," + CRLF
    cQry += "    DA1.DA1_PRCVEN AS PRECO," + CRLF
    cQry += "    DA0.DA0_DATDE AS DTINICIO," + CRLF
    cQry += "    DA0.DA0_DATATE AS DTFIM," + CRLF
    cQry += "    ISNULL(SB1.B1_PRV1, DA1.DA1_PRCVEN) AS PRECO_BASE," + CRLF
    cQry += "    ROW_NUMBER() OVER (PARTITION BY DA1.DA1_CODPRO ORDER BY DA1.DA1_PRCVEN DESC) AS FAIXA" + CRLF
    cQry += "FROM " + cTabDA1 + " DA1 WITH (NOLOCK)" + CRLF
    cQry += "INNER JOIN " + cTabDA0 + " DA0 WITH (NOLOCK)" + CRLF
    cQry += "    ON DA0.DA0_CODTAB = DA1.DA1_CODTAB" + CRLF
    cQry += "   AND DA0.D_E_L_E_T_ = ' '" + CRLF
    cQry += "LEFT JOIN " + cTabSB1 + " SB1 WITH (NOLOCK)" + CRLF
    cQry += "    ON SB1.B1_COD = DA1.DA1_CODPRO" + CRLF
    cQry += "   AND SB1.B1_FILIAL = '02'" + CRLF
    cQry += "   AND SB1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "WHERE DA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "  AND DA1.DA1_FILIAL = '02'" + CRLF
    cQry += "  AND DA1.DA1_CODTAB = '003'" + CRLF
    cQry += "ORDER BY DA1.DA1_CODPRO, FAIXA" + CRLF

    ConOut("JOBFVE05 >> Query EMPRESA_EXEMPLO_A (4 faixas):")
    ConOut(cQry)

    TCQuery cQry New Alias "TABPRC1"

    If !TABPRC1->(EoF())
        cProdAnt := ""
        aFaixaPreco := {0, 0, 0, 0}
        cDtIni := ""
        cDtFim := ""

        // Primeiro loop: coleta todos os precos por produto/faixa
        While !TABPRC1->(EoF())
            cCodProd := AllTrim(TABPRC1->CODPROD)
            nFaixa   := TABPRC1->FAIXA
            nPreco   := TABPRC1->PRECO

            // Mudou de produto - salva o anterior
            If cCodProd != cProdAnt .And. !Empty(cProdAnt)
                AAdd(aPrecos, {cProdAnt, AClone(aFaixaPreco), cDtIni, cDtFim})
                aFaixaPreco := {0, 0, 0, 0}
            EndIf

            // Armazena preco na faixa (maximo 4)
            If nFaixa >= 1 .And. nFaixa <= 4
                aFaixaPreco[nFaixa] := nPreco
            EndIf

            // Guarda datas do primeiro registro do produto
            If cCodProd != cProdAnt
                cDtIni := F05_FmtDateIso(TABPRC1->DTINICIO)
                cDtFim := F05_FmtDateIso(TABPRC1->DTFIM)
            EndIf

            cProdAnt := cCodProd
            TABPRC1->(DbSkip())
        EndDo

        // Salva ultimo produto
        If !Empty(cProdAnt)
            AAdd(aPrecos, {cProdAnt, AClone(aFaixaPreco), cDtIni, cDtFim})
        EndIf
    EndIf

    TABPRC1->(DbCloseArea())

    ConOut("JOBFVE05 >> Total produtos EMPRESA_EXEMPLO_A: " + cValToChar(Len(aPrecos)))

    // Segundo loop: gera 4 registros por produto (1 para cada regiao)
    For nI := 1 To Len(aPrecos)
        cCodProd    := aPrecos[nI][1]
        aFaixaPreco := aPrecos[nI][2]
        cDtIni      := aPrecos[nI][3]
        cDtFim      := aPrecos[nI][4]

        If Empty(cDtIni)
            cDtIni := "2025-01-01"
        EndIf
        If Empty(cDtFim)
            cDtFim := "2026-12-31"
        EndIf

        nUltPreco := aFaixaPreco[1]
        For nJ := 2 To 4
            If aFaixaPreco[nJ] <= 0
                aFaixaPreco[nJ] := nUltPreco
            Else
                nUltPreco := aFaixaPreco[nJ]
            EndIf
        Next nJ

        For nJ := 1 To 4
            nPreco := aFaixaPreco[nJ]

            If nPreco > 0
                oItem := JsonObject():New()
                oItem["CODPROD"]            := cCodProd
                oItem["NUMREGIAO"]          := aRegioes[nJ]   // 002, 003, 004, 005
                oItem["CODPRACA"]           := aRegioes[nJ]
                oItem["PVENDA"]             := nPreco
                oItem["PVENDA1"]            := nPreco
                oItem["PRECOMINIMOVENDA"]   := Round(nPreco * 0.70, 2)
                oItem["PTABELA"]            := nPreco
                oItem["VLULTENTMES"]        := aFaixaPreco[1]  // Preco base = faixa 1
                oItem["PERDESCMAX"]         := 30
                oItem["PERDESCMAXBALCAO"]   := 30
                oItem["CODST"]              := "1"
                oItem["CALCULARIPI"]        := "N"
                oItem["VLST"]               := 0
                oItem["VLIPI"]              := 0
                oItem["DESCONTAFRETE"]      := "N"
                oItem["DTINICIOVALIDADE"]   := cDtIni
                oItem["DTFIMVALIDADE"]      := cDtFim
                oItem["PRECOREVISTA"]       := nPreco
                oItem["PRECOFAB"]           := nPreco
                oItem["PERDESCSIMPLENAC"]   := 0
                oItem["PRECOMAXCONSUM"]     := 0
                oItem["PRECOMAXCONSUMTAB"]  := 0
                oItem["PERACRESCMAX"]       := 0
                oItem["CALCULARFECPSVENDA"] := "N"

                AAdd(aBody, oItem)
            EndIf
        Next nJ
    Next nI

    ConOut("JOBFVE05 >> Registros EMPRESA_EXEMPLO_A (4 regioes): " + cValToChar(Len(aBody)))

    // Segunda empresa (01-05) - EMPRESA_EXEMPLO_B
    RPCSetEnv("01", "05", , , "FAT")
    cTabDA1 := RetSqlName("DA1")
    cTabDA0 := RetSqlName("DA0")
    cTabSB1 := RetSqlName("SB1")

    cQry := ""
    cQry += "WITH PRECOS AS (" + CRLF
    cQry += "    SELECT DA1.DA1_CODPRO AS CODPROD," + CRLF
    cQry += "           DA1.DA1_PRCVEN AS PRECO," + CRLF
    cQry += "           DA0.DA0_DATDE AS DTINICIO," + CRLF
    cQry += "           DA0.DA0_DATATE AS DTFIM," + CRLF
    cQry += "           ISNULL(SB1.B1_PRV1, DA1.DA1_PRCVEN) AS PRECO_BASE," + CRLF
    cQry += "           ROW_NUMBER() OVER (PARTITION BY DA1.DA1_CODPRO ORDER BY DA1.DA1_PRCVEN DESC) AS RN" + CRLF
    cQry += "      FROM " + cTabDA1 + " DA1 WITH (NOLOCK)" + CRLF
    cQry += "     INNER JOIN " + cTabDA0 + " DA0 WITH (NOLOCK)" + CRLF
    cQry += "        ON DA0.DA0_CODTAB = DA1.DA1_CODTAB" + CRLF
    cQry += "       AND DA0.D_E_L_E_T_ = ' '" + CRLF
    cQry += "      LEFT JOIN " + cTabSB1 + " SB1 WITH (NOLOCK)" + CRLF
    cQry += "        ON SB1.B1_COD = DA1.DA1_CODPRO" + CRLF
    cQry += "       AND SB1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "       AND SB1.B1_FILIAL = '05'" + CRLF
    cQry += "     WHERE DA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "       AND DA1.DA1_FILIAL = '05'" + CRLF
    cQry += "       AND DA1.DA1_CODTAB = '001'" + CRLF
    cQry += ")" + CRLF
    cQry += "SELECT CODPROD, PRECO, DTINICIO, DTFIM, PRECO_BASE" + CRLF
    cQry += "  FROM PRECOS" + CRLF
    cQry += " WHERE RN = 1" + CRLF
    cQry += " ORDER BY CODPROD" + CRLF

    ConOut("JOBFVE05 >> Query EMPRESA_EXEMPLO_B (regiao 001):")
    ConOut(cQry)

    TCQuery cQry New Alias "TABPRC2"

    While !TABPRC2->(EoF())
        cCodProd := AllTrim(TABPRC2->CODPROD)
        nPreco   := TABPRC2->PRECO

        If !Empty(cCodProd) .And. nPreco > 0
            cDtIni := F05_FmtDateIso(TABPRC2->DTINICIO)
            cDtFim := F05_FmtDateIso(TABPRC2->DTFIM)

            If Empty(cDtIni)
                cDtIni := "2025-01-01"
            EndIf
            If Empty(cDtFim)
                cDtFim := "2026-12-31"
            EndIf

            oItem := JsonObject():New()
            oItem["CODPROD"]            := cCodProd
            oItem["NUMREGIAO"]          := "001"   // EMPRESA_EXEMPLO_B
            oItem["CODPRACA"]           := "001"
            oItem["PVENDA"]             := nPreco
            oItem["PVENDA1"]            := nPreco
            oItem["PRECOMINIMOVENDA"]   := Round(nPreco * 0.70, 2)
            oItem["PTABELA"]            := nPreco
            oItem["VLULTENTMES"]        := TABPRC2->PRECO_BASE
            oItem["PERDESCMAX"]         := 30
            oItem["PERDESCMAXBALCAO"]   := 30
            oItem["CODST"]              := "1"
            oItem["CALCULARIPI"]        := "N"
            oItem["VLST"]               := 0
            oItem["VLIPI"]              := 0
            oItem["DESCONTAFRETE"]      := "N"
            oItem["DTINICIOVALIDADE"]   := cDtIni
            oItem["DTFIMVALIDADE"]      := cDtFim
            oItem["PRECOREVISTA"]       := nPreco
            oItem["PRECOFAB"]           := nPreco
            oItem["PERDESCSIMPLENAC"]   := 0
            oItem["PRECOMAXCONSUM"]     := 0
            oItem["PRECOMAXCONSUMTAB"]  := 0
            oItem["PERACRESCMAX"]       := 0
            oItem["CALCULARFECPSVENDA"] := "N"

            AAdd(aBody, oItem)
        EndIf

        TABPRC2->(DbSkip())
    EndDo

    TABPRC2->(DbCloseArea())

    nTotal := Len(aBody)
    ConOut("JOBFVE05 >> Total registros gerados: " + cValToChar(nTotal))

    // Log de exemplo
    If nTotal > 0
        ConOut("JOBFVE05 >> Exemplo primeiro produto EMPRESA_EXEMPLO_A:")
        ConOut("   Regiao 002 (Venda Direta): " + cValToChar(aPrecos[1][2][1]))
        ConOut("   Regiao 003 (Varejo): " + cValToChar(aPrecos[1][2][2]))
        ConOut("   Regiao 004 (Atacado): " + cValToChar(aPrecos[1][2][3]))
        ConOut("   Regiao 005 (Distribuidor): " + cValToChar(aPrecos[1][2][4]))
    EndIf

Return FWJsonSerialize(aBody, .F., .F., .T.)

// Converte string yyyymmdd para yyyy-mm-dd
Static Function F05_FmtDateIso(cData)
    Local cNum := F05_OnlyDigits(AllTrim(cData))

    If Len(cNum) == 8
        Return SubStr(cNum, 1, 4) + "-" + SubStr(cNum, 5, 2) + "-" + SubStr(cNum, 7, 2)
    EndIf

Return ""

// Mantem apenas digitos em uma string
Static Function F05_OnlyDigits(cStr)
    Local cRet := ""
    Local nPos := 0
    Local cChr := ""

    For nPos := 1 To Len(cStr)
        cChr := SubStr(cStr, nPos, 1)
        If cChr >= "0" .And. cChr <= "9"
            cRet += cChr
        EndIf
    Next nPos

Return cRet

// Remove acentos e caracteres especiais comuns
Static Function F05_NormalizeText(cText)
    Local cRet    := AllTrim(cText)
    Local cFrom   := ""
    Local cTo     := "AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn  '''' "
    Local nPos    := 0

    cFrom += Chr(193)+Chr(192)+Chr(195)+Chr(194)+Chr(196)
    cFrom += Chr(225)+Chr(224)+Chr(227)+Chr(226)+Chr(228)
    cFrom += Chr(201)+Chr(200)+Chr(202)+Chr(203)
    cFrom += Chr(233)+Chr(232)+Chr(234)+Chr(235)
    cFrom += Chr(205)+Chr(204)+Chr(206)+Chr(207)
    cFrom += Chr(237)+Chr(236)+Chr(238)+Chr(239)
    cFrom += Chr(211)+Chr(210)+Chr(213)+Chr(212)+Chr(214)
    cFrom += Chr(243)+Chr(242)+Chr(245)+Chr(244)+Chr(246)
    cFrom += Chr(218)+Chr(217)+Chr(219)+Chr(220)
    cFrom += Chr(250)+Chr(249)+Chr(251)+Chr(252)
    cFrom += Chr(199)+Chr(231)
    cFrom += Chr(209)+Chr(241)
    cFrom += Chr(186)+Chr(170)
    cFrom += Chr(180)+Chr(96)+Chr(94)+Chr(126)+Chr(168)

    // remove tabs/CR/LF
    cRet := StrTran(cRet, Chr(9),  " ")
    cRet := StrTran(cRet, Chr(10), " ")
    cRet := StrTran(cRet, Chr(13), " ")

    For nPos := 1 To Len(cFrom)
        cRet := StrTran(cRet, SubStr(cFrom, nPos, 1), SubStr(cTo, nPos, 1))
    Next nPos

Return cRet
