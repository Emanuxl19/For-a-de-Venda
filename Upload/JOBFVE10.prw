#Include "TOTVS.ch"
#Include "Topconn.ch"

/*------------------------------------------------------------------------------------------------*
 | Data       : 13/11/2025                                                                        |
 | Rotina     : JOBFVE10                                                                          |
 | Responsável: EMANUEL AZEVEDO                                                                   |
 | Descrição  : Rotina para sincronizar Estoques para o sistema MaxPedido via POST.               |
 |              Busca dados da tabela MAXSCOB e envia para o endpoint /Estoques.                  |
 | versão     : 1.0                                                                               |
 | Histórico  :                                                                                   |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE10()
	Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
	Local cResource     := "/Estoques"
	Local oRest         := FwRest():New(cURI)
	Local aHeader       := {}
	Local cBearerToken  := U_JOBFVAUT()
	Local lSucesso      := .F.
	Local cAutoEmp      := "06"
	Local cAutoAmb      := "FAT"
	Local aPayload      := {}
	Local cJsonEst      := ""
	Local nQtEst        := 0

	If Select("SX2") <= 0
		RPCSetEnv(cAutoEmp, , , , cAutoAmb)
	EndIf

	If Empty(cBearerToken)
		ConOut("JOBFVE10 >> Token não informado. Abortando envio.")
		Return .F.
	EndIf

	aPayload := EstoquesPayload()
	cJsonEst := aPayload[1]
	nQtEst   := aPayload[2]

	If nQtEst == 0
		ConOut("JOBFVE10 >> Nenhum estoque encontrado para envio.")
		Return .T.
	EndIf

	AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
	AAdd(aHeader, "Accept: application/json")
	AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
	AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

	oRest:SetPath(cResource)
	oRest:SetPostParams(cJsonEst)

	If (oRest:Post(aHeader))
		ConOut("JOBFVE10 >> /Estoques atualizados com sucesso (" + cValToChar(nQtEst) + " registros).")
		lSucesso := .T.
	Else
		ConOut("JOBFVE10 >> Erro ao enviar /Estoques: " + CRLF + oRest:GetLastError())
	EndIf

Return lSucesso


Static Function EstoquesPayload()
    Local aBody      := {}
    Local cJson      := ""
    // cConfig: { FilialSB1, TipoProduto, FilialMPDefault, FilialTotvs, GrupoEmp }
    Local aConfig    := { ;
        { "02", "PA", "0602", "0201", "06" }, ; // EMPRESA_EXEMPLO_A (grp 06, fil 02)
        { "05", "ME", "0105", "0501", "01" }   ; // EMPRESA_EXEMPLO_B (grp 01, fil 05)
    }
    Local nCfg       := 0
    Local cSB2       := ""
    Local cSB1       := ""
    Local cFilialSB1 := ""
    Local cTipoProd  := ""
    Local cFilTotvs  := ""
    Local cFilMp     := ""
    Local cQry       := ""
    Local cGrpEmp    := ""
    Local oBodyEst   := NIL

    // Executa cada configuracao separadamente e acumula no JSON
    For nCfg := 1 To Len(aConfig)
        cFilialSB1 := aConfig[nCfg][1]
        cTipoProd  := aConfig[nCfg][2]
        cFilMp     := aConfig[nCfg][3]
        cFilTotvs  := aConfig[nCfg][4]
        cGrpEmp    := aConfig[nCfg][5]

        // Ambiente sempre FAT, variando grupo/filial conforme config
        RPCSetEnv(cGrpEmp, cFilialSB1, , , "FAT")

        // Obt�m nomes corretos das tabelas conforme a empresa
        cSB2 := RetSqlName("SB2")
        cSB1 := RetSqlName("SB1")

            // Consulta estoque
            cQry  := " SELECT '" + cFilMp + "' AS CODFILIAL_MP," + CRLF
            cQry += "        SB2.B2_COD AS B1_COD," + CRLF
            cQry += "        SB1.B1_DESC," + CRLF
            cQry += "        SB1.B1_UM," + CRLF
            cQry += "        SB1.B1_PRV1," + CRLF
            cQry += "        SB1.B1_FILIAL," + CRLF
            cQry += "        SB2.B2_LOCAL," + CRLF
            cQry += "        SB2.B2_QATU," + CRLF
            cQry += "        SB2.B2_VATU1," + CRLF
            cQry += "        SUBSTRING(SB2.B2_USAI,7,2) + '/' + SUBSTRING(SB2.B2_USAI,5,2) + '/' + SUBSTRING(SB2.B2_USAI,1,4) AS B2_USAI," + CRLF
            cQry += "        SB2.B2_LOCALIZ," + CRLF
            cQry += "        SUBSTRING(SB2.B2_DINVENT,7,2) + '/' + SUBSTRING(SB2.B2_DINVENT,5,2) + '/' + SUBSTRING(SB2.B2_DINVENT,1,4) AS B2_DINVENT," + CRLF
            cQry += "        SUBSTRING(SB2.B2_DMOV,7,2) + '/' + SUBSTRING(SB2.B2_DMOV,5,2) + '/' + SUBSTRING(SB2.B2_DMOV,1,4) AS B2_DMOV," + CRLF
            cQry += "        SB2.B2_HMOV" + CRLF
            cQry += "   FROM " + cSB2 + " SB2" + CRLF
            cQry += "   INNER JOIN " + cSB1 + " SB1 ON SB1.B1_COD = SB2.B2_COD AND SB1.B1_FILIAL = '"+cFilialSB1+"'" + CRLF
            cQry += "        AND SB1.D_E_L_E_T_ = ''" + CRLF
            cQry += "  WHERE SB2.D_E_L_E_T_ = ''" + CRLF
            cQry += "    AND SB2.B2_FILIAL = '"+cFilTotvs+"'" + CRLF
            cQry += "    AND SB1.B1_TIPO   = '"+cTipoProd+"'"

        TCQuery cQry New Alias "TABEST"

        While ! TABEST->(EoF())
            If Empty(AllTrim(TABEST->CODFILIAL_MP)) .Or. Empty(AllTrim(TABEST->B1_COD))
                TABEST->(DbSkip())
                Loop
            EndIf

            oBodyEst := JsonObject():New()

            oBodyEst["CODFILIAL"]             := AllTrim(TABEST->CODFILIAL_MP)
            oBodyEst["CODPROD"]               := AllTrim(TABEST->B1_COD)
            oBodyEst["QTESTGER"]              := TABEST->B2_QATU
            oBodyEst["QTBLOQUEADA"]           := 0
            oBodyEst["QTRESERV"]              := 0
            oBodyEst["QTPENDENTE"]            := 0
            oBodyEst["VALORULTENT"]           := TABEST->B2_VATU1
            oBodyEst["VALULTENT"]             := TABEST->B2_VATU1
            oBodyEst["QTLOJA"]                := TABEST->B2_QATU
            oBodyEst["DESCRICAO_PRODUTO"]     := AllTrim(TABEST->B1_DESC)
            oBodyEst["UNIDADE_PRODUTO"]       := AllTrim(TABEST->B1_UM)
            oBodyEst["PRECO_REFERENCIA"]      := TABEST->B1_PRV1
            oBodyEst["FILIAL_PRODUTO"]        := AllTrim(TABEST->B1_FILIAL)
            oBodyEst["LOCAL_ARMAZEM"]         := AllTrim(TABEST->B2_LOCAL)
            oBodyEst["CUSTOREP"]              := 1
            oBodyEst["CUSTOREAL"]             := 1
            oBodyEst["CUSTOFIN"]              := 1
            oBodyEst["QTMAXPEDVENDA"]         := 1
            oBodyEst["QTMINIMAATACADO"]       := 1
            oBodyEst["PROIBIDAVENDA"]         := "N"
            oBodyEst["UTILIZAQTDEUPMULTIPLA"] := "N"

            If !Empty(AllTrim(TABEST->B2_DINVENT))
                oBodyEst["DTULTINV"] := AllTrim(TABEST->B2_DINVENT)
            EndIf

            If !Empty(AllTrim(TABEST->B2_DMOV))
                oBodyEst["DTULTMOV"] := AllTrim(TABEST->B2_DMOV)
            EndIf

            If !Empty(AllTrim(TABEST->B2_USAI))
                oBodyEst["DTULTSAI"] := AllTrim(TABEST->B2_USAI)
            EndIf

            If !Empty(AllTrim(TABEST->B2_LOCALIZ))
                oBodyEst["LOCALIZACAO"] := AllTrim(TABEST->B2_LOCALIZ)
            EndIf

            If !Empty(AllTrim(TABEST->B2_HMOV))
                oBodyEst["HORARIO_MOVIMENTO"] := AllTrim(TABEST->B2_HMOV)
            EndIf

            aAdd(aBody, oBodyEst)
            TABEST->(DbSkip())
        EndDo

        TABEST->(DbCloseArea())
    Next nCfg

    cJson := FWJsonSerialize(aBody, .F., .F., .T.)

Return { cJson, Len(aBody) }
