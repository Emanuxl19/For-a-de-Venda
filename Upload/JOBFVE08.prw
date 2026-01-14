#Include "TOTVS.ch"
#Include "TopConn.ch"
/*-------------------------------------------------------------------------------------------------*
 | Data       : 13/11/2025                                                                         |
 | Rotina     : JOBFVE08                                                                           |
 | Responsavel: EMANUEL AZEVEDO                                                                    |
 | Descricao  : Envia usuarios/vendedores (Usuaris) para o MaxPedido via endpoint /Usuaris.        |
 | versao     : 1.1 - Corrigido filtro de filiais para incluir 0602 e 0105                         |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE08()
	Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
	Local cResource     := "/Usuaris"
	Local oRest         := FwRest():New(cURI)
	Local aHeader       := {}
	Local cBearerToken  := U_JOBFVAUT()
	Local lSucesso      := .F.
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
	oRest:SetPostParams(VendedoresJson())

	If (oRest:Post(aHeader))
		ConOut("JOBFVE08 >> Usuaris (Vendedores) criados ou atualizados com sucesso!")
		lSucesso := .T.
	Else
		ConOut("JOBFVE08 >> Erro ao enviar Usuaris/Vendedores:" + CRLF + oRest:GetLastError())
		lSucesso := .F.
	EndIf

Return lSucesso


// Monta JSON com a lista de vendedores (usuarios) a partir das tabelas SA3 e SA3.
Static Function VendedoresJson()
	Local aBody        := {}
	Local oBody        := NIL
	Local cJson        := ""
	Local cQry         := ""
	Local cCodUsur     := ""
	Local cCodFilialMp := ""
	Local cNomeVend    := ""
	Local cFlt         := ""

	// Query unificada para as duas filiais (EMPRESA_EXEMPLO_A e EMPRESA_EXEMPLO_B)
	Local cTab1 := ""
	Local cTab2 := ""

	// Primeira empresa (06-02) - EMPRESA_EXEMPLO_A
	RPCSetEnv("06", "02", , , "FAT")
	cTab1 := RetSqlName("SA3")

	cQry := ""
	cQry += "SELECT " + CRLF
	cQry += "       '06' + SUBSTRING(RTRIM(A3_FILIAL),1,2) + A3_COD AS CODIGO," + CRLF
	cQry += "       '0602' AS FILTOVS," + CRLF
	cQry += "       A3_COD, A3_FILIAL, A3_NOME, A3_NREDUZ, A3_EMAIL, A3_TEL, A3_CGC, A3_MSBLQL, A3_SUPER, A3_EST" + CRLF
	cQry += "FROM " + cTab1 + " SA3" + CRLF
	cQry += "WHERE SA3.D_E_L_E_T_ = ''" + CRLF
	cQry += "  AND SA3.A3_FILIAL IN ('0201', '0602')" + CRLF
	cQry += "UNION ALL" + CRLF

	// Segunda empresa (01-05) - EMPRESA_EXEMPLO_B
	RPCSetEnv("01", "05", , , "FAT")
	cTab2 := RetSqlName("SA3")

	cQry += "SELECT " + CRLF
	cQry += "       '01' + SUBSTRING(RTRIM(A3_FILIAL),1,2) + A3_COD AS CODIGO," + CRLF
	cQry += "       '0105' AS FILTOVS," + CRLF
	cQry += "       A3_COD, A3_FILIAL, A3_NOME, A3_NREDUZ, A3_EMAIL, A3_TEL, A3_CGC, A3_MSBLQL, A3_SUPER, A3_EST" + CRLF
	cQry += "FROM " + cTab2 + " SA3" + CRLF
	cQry += "WHERE SA3.D_E_L_E_T_ = ''" + CRLF
	cQry += "  AND SA3.A3_FILIAL IN ('05', '0105')"

	TCQuery cQry New Alias "TABVEND"

	While ! TABVEND->(EoF())

		cCodUsur     := AllTrim(TABVEND->CODIGO)
        cNomeVend    := NormalizeText(AllTrim(TABVEND->A3_NOME))
		cFlt         := AllTrim(TABVEND->FILTOVS)

		// Defaults
        If Empty(cNomeVend)
            cNomeVend := NormalizeText(IIf(!Empty(AllTrim(TABVEND->A3_NREDUZ)), AllTrim(TABVEND->A3_NREDUZ), cCodUsur))
        EndIf
		
		If Empty(cFlt)
			cFlt := IIf(AllTrim(TABVEND->A3_FILIAL) == "05", "0105", "0602")
		EndIf

		cCodFilialMp := cFlt

		If Empty(cCodUsur) .OR. Empty(cCodFilialMp)

			ConOut("JOBFVE08 >> Vendedor ignorado por campos obrigatorios vazios. " + ;
			       "A3_COD=" + AllTrim(TABVEND->A3_COD) + ;
			       " FILIAL=" + AllTrim(TABVEND->A3_FILIAL))

			TABVEND->(DbSkip())
			Loop
		EndIf

		If VendedorJaAdicionado(aBody, cCodUsur)
			ConOut("JOBFVE08 >> Vendedor " + cCodUsur + " ja adicionado. Ignorando duplicidade.")
			TABVEND->(DbSkip())
			Loop
		EndIf

		If ! FilialVendValida(cCodFilialMp)
			ConOut("JOBFVE08 >> Vendedor " + cCodUsur + ;
			       " com CODFILIAL MaxPedido invalido (" + cCodFilialMp + "). Ignorando.")
			TABVEND->(DbSkip())
			Loop
		EndIf

		oBody := JsonObject():New()

		oBody["CODUSUR"]          := cCodUsur
        oBody["NOME"]             := cNomeVend
        oBody["EMAIL"]            := NormalizeText(AllTrim(TABVEND->A3_EMAIL))
		oBody["TELEFONE1"]        := OnlyNumber(AllTrim(TABVEND->A3_TEL))
		oBody["CGC"]              := OnlyNumber(AllTrim(TABVEND->A3_CGC))
		oBody["BLOQUEIO"]         := "N"
		oBody["ATIVO"]            := "S"
		oBody["CODFILIAL"]        := cCodFilialMp
		oBody["CODSUPERVISOR"]    := "000001"
		oBody["TIPOVEND"]         := "I"
		oBody["TIPOVEND"]      	  := "I"
		oBody["USADEBCREDRCA"]    := "S"
		oBody["PERCACRESFV"]      := 0
		oBody["PERCENT"]          := 0
		oBody["PERCENT2"]         := 0
		oBody["PERMAXVENDA"]      := 0
		oBody["QTPEDPREV"]        := 0
		oBody["VALIDARACRESCDESCPRECOFIXO"] := "N"
		oBody["VLCORENTE"]        := 0
		oBody["VLVENDAMINPED"]    := 0

		aAdd(aBody, oBody)
		TABVEND->(DbSkip())
	EndDo

	TABVEND->(DbCloseArea())

	cJson := FWJsonSerialize(aBody, .F., .F., .T.)

Return cJson
Static Function VendedorJaAdicionado(aBody, cCodUsur)
	Local lFound := .F.
	Local nIdx   := 0

	For nIdx := 1 To Len(aBody)
		If AllTrim(aBody[nIdx]["CODUSUR"]) == AllTrim(cCodUsur)
			lFound := .T.
			Exit
		EndIf
	Next nIdx

Return lFound


// Valida se a filial MaxPedido informada e conhecida/permitida na integracao
Static Function FilialVendValida(cCodFilial)
	Local cFil := Upper(AllTrim(cCodFilial))
	Local aVal := {"0602", "0105"}

Return AScan(aVal, cFil) > 0

Static Function GetMpFil(cFilialTotvs)
	Local cParam    := "MV_MP" + SubStr("0000" + AllTrim(cFilialTotvs), -4)
	Local cCodFil   := ""
	Local cAutoEmp  := "06"
	Local cAutoAmb  := "FAT"

	If Select("SX6") <= 0
		RPCSetEnv(cAutoEmp, , , , cAutoAmb)
	EndIf

	DbSelectArea("SX6")
	DbSetOrder(1) // X6_FILIAL + X6_VAR
	DbGoTop()

	If DbSeek(cFilialTotvs + cParam)
		cCodFil := AllTrim(SX6->X6_CONTEUD)
	EndIf

	If Empty(cCodFil)
		cCodFil := cFilialTotvs
	EndIf

Return cCodFil

Static Function OnlyNumber(cTexto)
    Local cRet := ""
    Local nPos := 0

    For nPos := 1 To Len(cTexto)
		If SubStr(cTexto, nPos, 1) $ "0123456789"
			cRet += SubStr(cTexto, nPos, 1)
        EndIf
    Next nPos
Return cRet

// Normaliza texto removendo acentos e caracteres de controle
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

    // remove tabs/CR/LF
    cRet := StrTran(cRet, Chr(9),  " ")
    cRet := StrTran(cRet, Chr(10), " ")
    cRet := StrTran(cRet, Chr(13), " ")

    // troca acentuados por equivalentes sem acento
    For nPos := 1 To Len(cFrom)
        cRet := StrTran(cRet, SubStr(cFrom, nPos, 1), SubStr(cTo, nPos, 1))
    Next nPos

Return cRet
