#Include "TOTVS.ch"
#Include "Topconn.ch"

/*------------------------------------------------------------------------------------------------*
 | Data       : 08/11/2025                                                                        |
 | Rotina     : JOBFVE04                                                                          |
 | Responsavel: EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia Clientes para o MaxPedido (endpoint /Clientes).                             |
 | Versao     : 1.3 - Removido CODCOB e CODPLPAG fixos para permitir escolha no app               |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE04()

    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource     := "/Clientes" 
    Local cResourceReg  := "/ClientesRegioes"
    Local oRest         := FwRest():New(cURI)
    Local oRestReg      := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .F.
    Local lSucessoReg   := .F.
    Local cAutoEmp      := "06"
    Local cAutoAmb      := "FAT"

    If Select("SX2") <= 0
        RPCSetEnv(cAutoEmp, , , , cAutoAmb)
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath(cResource)
    oRest:SetPostParams(ClientesJson())
    oRestReg:SetPath(cResourceReg)
    oRestReg:SetPostParams(ClientesRegioesJson())

    If (oRest:Post(aHeader))
        ConOut("JOBFVE04 >> Clientes enviados com sucesso!")
        lSucesso := .T.
    Else
        ConOut("JOBFVE04 >> Erro ao enviar Clientes:" + CRLF + oRest:GetLastError())
        lSucesso := .F.
    EndIf

    If (oRestReg:Post(aHeader))
        ConOut("JOBFVE04 >> ClientesRegioes enviados com sucesso.")
        lSucessoReg := .T.
    Else
        ConOut("JOBFVE04 >> Erro ao enviar ClientesRegioes:" + CRLF + oRestReg:GetLastError())
        lSucessoReg := .F.
    EndIf

    lSucesso := lSucesso .And. lSucessoReg
Return lSucesso

Static Function ClientesJson()
    Local aBody := {}
    Local oBody
    Local cQry := ""
    Local cCodVend := ""
    Local cFilCli := ""
    Local cTab1 := ""
    Local cTab2 := ""

    // Primeira empresa (06-02) - EMPRESA_EXEMPLO_A
    RPCSetEnv("06", "02", , , "FAT")
    cTab1 := RetSqlName("SA1")
    cTab2 := RetSqlName("SA3")

    cQry := " SELECT '0602' AS FILIAL," + CRLF
    cQry += "        '06' + SUBSTRING(LTRIM(RTRIM(SA1.A1_FILIAL)),1,2) + SA1.A1_COD + SA1.A1_LOJA AS CODCLI," + CRLF
    cQry += "        SA1.A1_FILIAL AS FILIALSA1," + CRLF
    cQry += "        SA1.A1_NOME, SA1.A1_PESSOA, SA1.A1_END, SA1.A1_NREDUZ, SA1.A1_BAIRRO,'1' AS ATIVIDADE," + CRLF
    cQry += "        SA1.A1_EST, SA1.A1_CODMUN, SA1.A1_MUN, SA1.A1_DDD, SA1.A1_TEL, SA1.A1_CEP, SA1.A1_CGC, SA1.A1_INSCR," + CRLF
    cQry += "        SA1.A1_VEND, SA3.A3_FILIAL AS FILIALVEN, SA3.A3_COD AS CODVEND, SA3.A3_NOME AS NOME_VEND," + CRLF
    cQry += "        SA1.A1_TRANSP, SA1.A1_COND, SA1.A1_CNAE, SA1.A1_EMAIL, SA1.A1_TABELA" + CRLF
    cQry += "   FROM " + cTab1 + " SA1 WITH (NOLOCK)" + CRLF
    cQry += "   LEFT JOIN " + cTab2 + " SA3 WITH (NOLOCK)" + CRLF
    cQry += "          ON SA3.D_E_L_E_T_ = ' '" + CRLF
    cQry += "         AND SA3.A3_FILIAL LIKE '02%'" + CRLF
    cQry += "         AND SA3.A3_COD = SA1.A1_VEND" + CRLF
    cQry += "  WHERE SA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "    AND SA1.A1_FILIAL LIKE '02%'" + CRLF
    cQry += " UNION ALL" + CRLF

    // Segunda empresa (01-05) - EMPRESA_EXEMPLO_B
    RPCSetEnv("01", "05", , , "FAT")
    cTab1 := RetSqlName("SA1")
    cTab2 := RetSqlName("SA3")

    cQry += " SELECT '0105' AS FILIAL," + CRLF
    cQry += "        '01' + SUBSTRING(LTRIM(RTRIM(SA1.A1_FILIAL)),1,2) + SA1.A1_COD + SA1.A1_LOJA AS CODCLI," + CRLF
    cQry += "        SA1.A1_FILIAL AS FILIALSA1," + CRLF
    cQry += "        SA1.A1_NOME, SA1.A1_PESSOA, SA1.A1_END, SA1.A1_NREDUZ, SA1.A1_BAIRRO,'1' AS ATIVIDADE," + CRLF
    cQry += "        SA1.A1_EST, SA1.A1_CODMUN, SA1.A1_MUN, SA1.A1_DDD, SA1.A1_TEL, SA1.A1_CEP, SA1.A1_CGC, SA1.A1_INSCR," + CRLF
    cQry += "        SA1.A1_VEND, SA3.A3_FILIAL AS FILIALVEN, SA3.A3_COD AS CODVEND, SA3.A3_NOME AS NOME_VEND," + CRLF
    cQry += "        SA1.A1_TRANSP, SA1.A1_COND, SA1.A1_CNAE, SA1.A1_EMAIL, SA1.A1_TABELA" + CRLF
    cQry += "   FROM " + cTab1 + " SA1 WITH (NOLOCK)" + CRLF
    cQry += "   LEFT JOIN " + cTab2 + " SA3 WITH (NOLOCK)" + CRLF
    cQry += "          ON SA3.D_E_L_E_T_ = ' '" + CRLF
    cQry += "         AND SA3.A3_FILIAL LIKE '05%'" + CRLF
    cQry += "         AND SA3.A3_COD = SA1.A1_VEND" + CRLF
    cQry += "  WHERE SA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "    AND SA1.A1_FILIAL LIKE '05%'" + CRLF

    TCQuery cQry New Alias 'TABTEMP'
    
    While ! TABTEMP->(EoF())
        cCodVend := AllTrim(TABTEMP->CODVEND)
        cFilCli := AllTrim(TABTEMP->FILIAL)
        
        If ! Empty(cCodVend) .And. ! Empty(AllTrim(TABTEMP->FILIALVEN))
            cCodVend := IIf(cFilCli == "0602", "06", "01") + ;
                        SubStr(AllTrim(TABTEMP->FILIALVEN), 1, 2) + ;
                        cCodVend
        Else
            cCodVend := "1"
        EndIf

        oBody := JsonObject():New()
        oBody["BAIRROENT"]       := NormalizeText(TABTEMP->A1_BAIRRO)
        oBody["BLOQUEIO"]        := "N"
        oBody["CALCULAST"]       := "S"
        oBody["CEPENT"]          := AllTrim(TABTEMP->A1_CEP)
        oBody["CGCENT"]          := AllTrim(TABTEMP->A1_CGC)
        oBody["CLIENTE"]         := NormalizeText(TABTEMP->A1_NOME)
        oBody["CODATV1"]         := TABTEMP->ATIVIDADE
        oBody["CODCIDADE"]       := AllTrim(TABTEMP->A1_CODMUN)
        oBody["CODCLI"]          := AllTrim(TABTEMP->CODCLI)
        oBody["CODFUNCULTALTER"] := ""
        oBody["CODPRACA"]        := GetPraca(TABTEMP->FILIAL, TABTEMP->A1_TABELA)
        oBody["CODROTA"]         := ""
        oBody["CODUSUR1"]        := cCodVend
        oBody["CODUSUR2"]        := cCodVend
        oBody["CONDVENDA1"]      := "S"
        oBody["CONDVENDA11"]     := "S"
        oBody["CONDVENDA13"]     := "S"
        oBody["CONDVENDA14"]     := "S"
        oBody["CONDVENDA20"]     := "S"
        oBody["CONDVENDA5"]      := "S"
        oBody["CONDVENDA7"]      := "S"
        oBody["CONDVENDA8"]      := "S"
        oBody["CONDVENDA9"]      := "S"
        oBody["CONDVENDA24"]     := "S"
        oBody["CONDVENDA4"]      := "N"
        oBody["CONSUMIDORFINAL"] := IIF(TABTEMP->A1_PESSOA == "F","S","N")
        oBody["CONTRIBUINTE"]    := "N"
        oBody["EMAIL"]           := NormalizeText(TABTEMP->A1_EMAIL)
        oBody["EMAILNFE"]        := NormalizeText(TABTEMP->A1_EMAIL)
        oBody["ENDERENT"]        := NormalizeText(TABTEMP->A1_END)
        oBody["ESTENT"]          := AllTrim(TABTEMP->A1_EST)
        oBody["FANTASIA"]        := NormalizeText(TABTEMP->A1_NREDUZ)
        oBody["IEENT"]           := AllTrim(TABTEMP->A1_INSCR)
        oBody["ISENTOIPI"]       := "S"
        oBody["MUNICENT"]        := NormalizeText(TABTEMP->A1_MUN)
        oBody["NUMEROENT"]       := "000"
        oBody["TELENT"]          := AllTrim(TABTEMP->A1_TEL)
        oBody["TIPOFJ"]          := AllTrim(TABTEMP->A1_PESSOA)
        oBody["USADEBCREDRCA"]   := "N"
        oBody["VALIDARMULTIPLOVENDA"]  := "S"
        oBody["CODFILIALNF"]           := cFilCli
        oBody["BLOQUEIODEFINITIVO"]    := "N"

        aAdd(aBody, oBody)
        TABTEMP->(DbSkip())
    EndDo
    TABTEMP->(DbCloseArea())

Return FWJsonSerialize(aBody, .F., .F., .T.)

Static Function ClientesRegioesJson()
    Local aBody := {}
    Local oBody
    Local cQry  := ""
    Local cCodCli := ""
    Local cNumRegiao := ""
    Local cTab1 := ""

    // Primeira empresa (06-02) - EMPRESA_EXEMPLO_A
    RPCSetEnv("06", "02", , , "FAT")
    cTab1 := RetSqlName("SA1")

    cQry := ""
    cQry += "SELECT " + CRLF
    cQry += "       '06' + SUBSTRING(LTRIM(RTRIM(SA1.A1_FILIAL)),1,2) + SA1.A1_COD + SA1.A1_LOJA AS CODCLI," + CRLF
    cQry += "       SA1.A1_TABELA," + CRLF
    cQry += "       '0602' AS FILIAL" + CRLF
    cQry += "  FROM " + cTab1 + " SA1 WITH (NOLOCK)" + CRLF
    cQry += " WHERE SA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "   AND SA1.A1_FILIAL LIKE '02%'" + CRLF
    cQry += " UNION ALL" + CRLF

    // Segunda empresa (01-05) - EMPRESA_EXEMPLO_B
    RPCSetEnv("01", "05", , , "FAT")
    cTab1 := RetSqlName("SA1")

    cQry += "SELECT " + CRLF
    cQry += "       '01' + SUBSTRING(LTRIM(RTRIM(SA1.A1_FILIAL)),1,2) + SA1.A1_COD + SA1.A1_LOJA AS CODCLI," + CRLF
    cQry += "       SA1.A1_TABELA," + CRLF
    cQry += "       '0105' AS FILIAL" + CRLF
    cQry += "  FROM " + cTab1 + " SA1 WITH (NOLOCK)" + CRLF
    cQry += " WHERE SA1.D_E_L_E_T_ = ' '" + CRLF
    cQry += "   AND SA1.A1_FILIAL LIKE '05%'" + CRLF

    TCQuery cQry New Alias 'TABCLIREG'

    While ! TABCLIREG->(EoF())
        cCodCli := AllTrim(TABCLIREG->CODCLI)
        cNumRegiao := GetNumRegiao(TABCLIREG->FILIAL, TABCLIREG->A1_TABELA)

        If !Empty(cCodCli) .AND. !Empty(cNumRegiao)
            oBody := JsonObject():New()
            oBody["CODCLI"]     := cCodCli
            oBody["NUMREGIAO"]  := cNumRegiao
            oBody["PERDESCMAX"] := 0
            oBody["VDEFAULT"]   := "S"
            aAdd(aBody, oBody)

            oBody := JsonObject():New()
            oBody["CODCLI"]     := cCodCli
            oBody["NUMREGIAO"]  := "002"
            oBody["PERDESCMAX"] := 0
            oBody["VDEFAULT"]   := "S"
            AAdd(aBody, oBody)

            oBody := JsonObject():New()
            oBody["CODCLI"]     := cCodCli
            oBody["NUMREGIAO"]  := "003"
            oBody["PERDESCMAX"] := 0
            oBody["VDEFAULT"]   := "N"
            AAdd(aBody, oBody)

            oBody := JsonObject():New()
            oBody["CODCLI"]     := cCodCli
            oBody["NUMREGIAO"]  := "004"
            oBody["PERDESCMAX"] := 0
            oBody["VDEFAULT"]   := "N"
            AAdd(aBody, oBody)

            oBody := JsonObject():New()
            oBody["CODCLI"]     := cCodCli
            oBody["NUMREGIAO"]  := "005"
            oBody["PERDESCMAX"] := 0
            oBody["VDEFAULT"]   := "N"
            AAdd(aBody, oBody)
        EndIf

        TABCLIREG->(DbSkip())
    EndDo

    TABCLIREG->(DbCloseArea())

Return FWJsonSerialize(aBody, .F., .F., .T.)

Static Function GetPraca(cFilialMP, cTabela)
    Local cFil := AllTrim(cFilialMP)
    Local cPra := AllTrim(cTabela)

    If cFil == "0105"
        Return "001"
    ElseIf cFil == "0602"
        Return "003"
    EndIf

    If Empty(cPra)
        cPra := "001"
    EndIf
Return cPra

Static Function GetNumRegiao(cFilialMP, cTabela)
    Local cFil := AllTrim(cFilialMP)
    Local cTab := AllTrim(cTabela)
    Local cNumReg := ""

    If cFil == "0105"
        cNumReg := "001"
    ElseIf cFil == "0602"
        cNumReg := "003"
    Else
        cNumReg := "001"
    EndIf

    If !Empty(cTab)
        cNumReg := cTab
    EndIf

Return cNumReg

Static Function NormalizeText(cText)
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

    cRet := StrTran(cRet, Chr(9),  " ")
    cRet := StrTran(cRet, Chr(10), " ")
    cRet := StrTran(cRet, Chr(13), " ")

    For nPos := 1 To Len(cFrom)
        cRet := StrTran(cRet, SubStr(cFrom, nPos, 1), SubStr(cTo, nPos, 1))
    Next nPos

Return cRet
