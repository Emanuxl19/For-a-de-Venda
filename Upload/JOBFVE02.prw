#Include "TOTVS.ch"
#Include "Topconn.ch"
/*------------------------------------------------------------------------------------------------*
 | Data       : 07/11/2025                                                                        |
 | Rotina     : JOBFVE02                                                                          |
 | Responsável: EMANUEL AZEVEDO                                                                   |
 | Descrição  : Rotina para do Endpoint no método POST dos Fornecedores para o sistema MaxPedido. | 
 |                                                                                                |
 | versão     : 1.0                                                                               |
 | Histórico  :                                                                                   | 
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE02()

    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource     := "/Fornecedores"
    Local oRest         := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .F.

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath(cResource)
    oRest:SetPostParams(FornecJson())

    If (oRest:Post(aHeader))
        ConOut("Fornecedores criados com sucesso!")
        lSucesso := .T.
    Else
        ConOut("Erro ao enviar fornecedores:" + CRLF + oRest:GetLastError())
        lSucesso := .F.
    EndIf

    Return lSucesso

Static Function FornecJson()
        Local aBody := {}
        Local oBody := NIL
        Local cJson := ""

        oBody := JsonObject():New()
        oBody["CODFORNEC"]       := "FOR001"
        oBody["FORNECEDOR"]      := "EMPRESA_EXEMPLO_A"
        oBody["FANTASIA"]        := "FANTASIA_EXEMPLO_A"
        oBody["CGC"]             := OnlyNumber("00000000000000")
        oBody["CIDADE"]          := "CIDADE_EXEMPLO_A"
        oBody["CODDISTRIB"]      := "01"
        oBody["CODFILIAL"]       := "0602"
        oBody["BAIRRO"]          := "BAIRRO_EXEMPLO_A"
        oBody["ENDER"]           := "ENDERECO_EXEMPLO_A"
        oBody["ESTADO"]          := "AM"
        oBody["BLOQUEIO"]        := "N"
        oBody["EREDESPACHO"]     := "N"
        oBody["ESTRATEGICO"]     := "N"
        oBody["EXIGEREDESPACHO"] := "N"
        oBody["TELFAB"]          := OnlyNumber("00000000000")
        oBody["REVENDA"]         := "S"
        AAdd(aBody, oBody)

        oBody := JsonObject():New()
        oBody["CODFORNEC"]       := "FOR002"
        oBody["FORNECEDOR"]      := "EMPRESA_EXEMPLO_B"
        oBody["FANTASIA"]        := "FANTASIA_EXEMPLO_B"
        oBody["CGC"]             := OnlyNumber("00000000000000")
        oBody["CIDADE"]          := "CIDADE_EXEMPLO_B"
        oBody["CODDISTRIB"]      := "01"
        oBody["CODFILIAL"]       := "0105"
        oBody["BAIRRO"]          := "BAIRRO_EXEMPLO_B"
        oBody["ENDER"]           := "ENDERECO_EXEMPLO_B"
        oBody["ESTADO"]          := "AM"
        oBody["BLOQUEIO"]        := "N"
        oBody["EREDESPACHO"]     := "N"
        oBody["ESTRATEGICO"]     := "N"
        oBody["EXIGEREDESPACHO"] := "N"
        oBody["TELFAB"]          := OnlyNumber("00000000000")
        oBody["REVENDA"]         := "S"
        AAdd(aBody, oBody)

        cJson := FWJsonSerialize(aBody, .F., .F., .T.)

    Return cJson

Static Function GetMpFil(cFilialTotvs, cDefault)
    Local cParam := ""
    Local cValor := cDefault

    cParam := "MV_MP" + Right("0000" + AllTrim(cFilialTotvs), 4)

    DbSelectArea("SX6")
    DbSetOrder(1)

    If DbSeek(cFilialTotvs + cParam)
        cValor := AllTrim(SX6->X6_CONTEUD)
    EndIf

    If Empty(cValor)
        cValor := cDefault
    EndIf

Return cValor

Static Function ResolveFieldName(aColumns, aCandidates, lRequired, cTable)
    Local cFound   := ""
    Local nIdxCand := 0
    Local cTarget  := ""
    Local nPos     := 0

    For nIdxCand := 1 To Len(aCandidates)
        cTarget := Upper(AllTrim(aCandidates[nIdxCand]))
        nPos    := AScan(aColumns, {|c| c == cTarget})

        If nPos > 0
            cFound := aColumns[nPos]
            Exit
        EndIf
    Next nIdxCand

    If Empty(cFound) .And. lRequired
        ConOut("JOBFVE02 >> Campo não encontrado em " + cTable + ": " + aCandidates[1])
    EndIf

Return cFound

Static Function GetTableColumns(cTable)
    Static aCache := {}
    Local cKey    := Upper(AllTrim(cTable))
    Local nDot    := At(".", cKey)
    Local nIdx    := 0
    Local cSql    := ""
    Local aCols   := {}

    If nDot > 0
        cKey := SubStr(cKey, nDot + 1)
    EndIf

    nIdx := AScan(aCache, {|a| a[1] == cKey})

    If nIdx == 0
        cSql  := " SELECT UPPER(COLUMN_NAME) AS COLUMN_NAME" + CRLF
        cSql += "   FROM INFORMATION_SCHEMA.COLUMNS" + CRLF
        cSql += "  WHERE UPPER(TABLE_NAME) = '" + cKey + "'"

        TCQuery cSql New Alias "TABCOL"

        If Select("TABCOL") > 0
            While ! TABCOL->(EoF())
                AAdd(aCols, AllTrim(TABCOL->COLUMN_NAME))
                TABCOL->(DbSkip())
            EndDo

            TABCOL->(DbCloseArea())
        EndIf

        AAdd(aCache, { cKey, aCols })
        nIdx := Len(aCache)
    EndIf

Return aCache[nIdx][2]

Static Function OnlyNumber(cTexto)
    Local cRet := ""
    Local nPos := 0

    For nPos := 1 To Len(cTexto)
        If SubStr(cTexto, nPos, 1) $ "0123456789"
            cRet += SubStr(cTexto, nPos, 1)
        EndIf
    Next nPos

Return cRet


