#Include "TOTVS.ch"
#Include "Topconn.ch"

/*------------------------------------------------------------------------------------------------*
 | Data       : 15/12/2025                                                                        |
 | Rotina     : JOBFVE20                                                                          |
 | Responsavel: EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia ClientesPorVendedores para o MaxPedido (endpoint /ClientesPorVendedores).   |
 | Versao     : 1.0                                                                               |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE20()

    Local cURI     := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local aHeader  := {}
    Local cToken   := ""
    Local lSucesso := .F.

    // INICIALIZACAO CONDICIONAL - Só executa se ambiente não estiver preparado
     If Select("SX2") <= 0
        RPCSetEnv("06", "02", , , "FAT")
    EndIf

    cToken := U_JOBFVAUT()
    If Empty(cToken)
        Return .F.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cToken)

    lSucesso := EnviaClientesPorVendedores0105(cURI, aHeader)

Return lSucesso

Static Function _GetCfg()
    Local aCfg := {}
    // {CODFILMAX, SA1, SA3, FILIAL_SA1, FILIAL_SA3}
    AAdd(aCfg, {"0602", "SA1", "SA3", "02", "02"})
    AAdd(aCfg, {"0105", "SA1", "SA3", "05", "05"})
Return aCfg

Static Function EnviaClientesPorVendedores(cURI, aHeader)
   
    Local aCfg      := _GetCfg()
    Local oRest     := NIL
    Local cQry      := ""
    Local cAls      := GetNextAlias()
    Local aBatch    := {}
    Local oBody     := NIL
    Local nBatchMax := 2000
    Local lOK       := .T.
    Local nI        := 0
    Local nTotal    := 0


    // Monta query com UNION ALL para todas as filiais
    For nI := 1 To Len(aCfg)
    cQry += IIf(!Empty(cQry), " UNION ALL ", "")
    cQry := "SELECT " + CRLF
    cQry += "    '01' + SUBSTRING(RTRIM(SA3.A3_FILIAL),1,2) + RTRIM(SA3.A3_COD) AS CODUSUR," + CRLF
    cQry += "    '01' + SUBSTRING(RTRIM(SA1.A1_FILIAL),1,2) + SA1.A1_COD + SA1.A1_LOJA AS CODCLI" + CRLF
    cQry += "FROM SA1 SA1 WITH (NOLOCK)" + CRLF
    cQry += "CROSS JOIN SA3 SA3 WITH (NOLOCK)" + CRLF
    cQry += "WHERE SA1.D_E_L_E_T_ = ' ' " + CRLF
    cQry += "  AND SA1.A1_FILIAL = '05' " + CRLF
    cQry += "  AND SA1.A1_MSBLQL <> '1' " + CRLF
    cQry += "  AND SA3.D_E_L_E_T_ = ' ' " + CRLF
    cQry += "  AND SA3.A3_FILIAL = '05' " + CRLF
    cQry += "  AND SA3.A3_MSBLQL <> '1' " + CRLF
   Next nI

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())

        oBody := JsonObject():New()
        oBody["CODUSUR"] := AllTrim((cAls)->CODUSUR)
        oBody["CODCLI"]  := AllTrim((cAls)->CODCLI)

        If !Empty(oBody["CODUSUR"]) .And. !Empty(oBody["CODCLI"])
            AAdd(aBatch, oBody)
        EndIf

         // Envia em lotes para evitar payload gigante
        If Len(aBatch) >= nBatchMax
            lOK := PostBatchClientesPorVendedores(oRest, aHeader, aBatch)
            aBatch := {}
            If !lOK
                Exit
            EndIf
        EndIf

        (cAls)->(DbSkip())
    EndDo

    // Envia lote restante
    If lOK .And. Len(aBatch) > 0
        lOK := PostBatch(oRest, aHeader, aBatch)
        nTotal += Len(aBatch)
    EndIf

    (cAls)->(DbCloseArea())

    ConOut("JOBFVE20 >> Total ClientesPorVendedores enviados: " + cValToChar(nTotal) + " - " + IIf(lOK, "OK", "ERRO"))

Return lOK


Static Function PostBatch(oRest, aHeader, aBatch)
    Local cJson := ""
    Local lOK   := .F.

    cJson := FWJsonSerialize(aBatch, .F., .F., .T.)
    If Empty(cJson) .Or. cJson == "[]"
        Return .T.
    EndIf

    oRest:SetPath("/ClientesPorVendedores")
    oRest:SetPostParams(cJson)

    lOK := oRest:Post(aHeader)

    If !lOK
        ConOut("JOBFVE20 >> ERRO no POST: " + oRest:GetLastError())
    EndIf

Return lOK
