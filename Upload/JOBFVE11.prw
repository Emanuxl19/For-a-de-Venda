#Include "TOTVS.ch"
#Include "TopConn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE11                                                                          |
 | Data       : 15/11/2025                                                                        |
 | Respons�vel: EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia Cobrancas, CobrancasClientes e CobrancasPlanosPagamentos para o MaxPedido   |
 | Versao     : 1.1 - Adicionado CobrancasClientes e CobrancasPlanosPagamentos                    |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE11()
    Local cURI   := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest  := NIL
    Local aHead  := {}
    Local cToken := ""
    Local cJson  := ""
    Local lSuc1  := .F.
    Local lSuc2  := .F.
    Local lSuc3  := .F.

    // INICIALIZACAO OBRIGATORIA PARA JOB
    RPCSetEnv("06", "02", , , "FAT")

    cToken := U_JOBFVAUT()

    If Empty(cToken)
        Return .F.
    EndIf

    AAdd(aHead, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHead, "Accept: application/json")
    AAdd(aHead, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHead, "Authorization: Bearer " + cToken)

    // 1. Cobrancas
    cJson := CobJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/Cobrancas")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc1 := .T.
        EndIf
    EndIf

    // 2. CobrancasClientes
    cJson := CobCliJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/CobrancasClientes")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc2 := .T.
        EndIf
    EndIf

    // 3. CobrancasPlanosPagamentos
    cJson := CobPlagJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/CobrancasPlanosPagamentos")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHead)
            lSuc3 := .T.
        EndIf
    EndIf

Return (lSuc1 .And. lSuc2 .And. lSuc3)

Static Function _GetCfg()
    Local aCfg := {}
    Local cTabSA1_1 := ""
    Local cTabSE4_1 := ""
    Local cTabSX5_1 := ""
    Local cTabSA1_2 := ""
    Local cTabSE4_2 := ""
    Local cTabSX5_2 := ""

    // Primeira empresa (06-02)
    RPCSetEnv("06", "02", , , "FAT")
    cTabSA1_1 := RetSqlName("SA1")
    cTabSE4_1 := RetSqlName("SE4")
    cTabSX5_1 := RetSqlName("SX5")

    // Segunda empresa (01-05)
    RPCSetEnv("01", "05", , , "FAT")
    cTabSA1_2 := RetSqlName("SA1")
    cTabSE4_2 := RetSqlName("SE4")
    cTabSX5_2 := RetSqlName("SX5")

    // {CODFILMAX, SA1, SE4, SX5, FILIAL_SA1, FILIAL_SE4}
    AAdd(aCfg, {"0602", cTabSA1_1, cTabSE4_1, cTabSX5_1, "02", "0201"})
    AAdd(aCfg, {"0105", cTabSA1_2, cTabSE4_2, cTabSX5_2, "05", "0501"})
Return aCfg

Static Function CobJson()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local cTabSX5 := ""

    // Usa empresa 06-02 para buscar tabela SX5
    RPCSetEnv("06", "02", , , "FAT")
    cTabSX5 := RetSqlName("SX5")

    cQry := "SELECT "
    cQry += "RTRIM(X5_CHAVE) AS CODIGO,"
    cQry += "RTRIM(X5_DESCRI) AS DESCRICAO,"
    cQry += "CASE WHEN X5_CHAVE IN ('BOL') THEN 'S' ELSE 'N' END AS IS_BOLETO,"
    cQry += "CASE WHEN X5_CHAVE IN ('CC','CD','CLJ') THEN 'S' ELSE 'N' END AS IS_CARTAO,"
    cQry += "CASE WHEN X5_CHAVE IN ('R$','DIN','PX','PE','CD','DB') THEN 'VV' ELSE 'VP' END AS TIPO_VENDA,"
    cQry += "CASE "
    cQry += "WHEN X5_CHAVE = 'BOL' THEN 'B' "
    cQry += "WHEN X5_CHAVE IN ('CC','CD','CLJ') THEN 'C' "
    cQry += "WHEN X5_CHAVE = 'CH' THEN 'CH' "
    cQry += "WHEN X5_CHAVE IN ('R$','DIN') THEN 'D' "
    cQry += "WHEN X5_CHAVE IN ('PX','PE','DB') THEN 'T' "
    cQry += "WHEN X5_CHAVE IN ('FA','CR','CO') THEN 'DU' "
    cQry += "ELSE 'OU' END AS TIPO_MAXIMA "
    cQry += "FROM " + cTabSX5 + " WITH (NOLOCK) "
    cQry += "WHERE D_E_L_E_T_ = ' ' "
    cQry += "AND X5_TABELA = '24' "
    cQry += "AND X5_FILIAL = '' "
    cQry += "ORDER BY X5_CHAVE"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODCOB"]          := AllTrim((cAls)->CODIGO)
        oRow["COBRANCA"]        := AllTrim((cAls)->DESCRICAO)
        oRow["BOLETO"]          := AllTrim((cAls)->IS_BOLETO)
        oRow["CARTAO"]          := AllTrim((cAls)->IS_CARTAO)
        oRow["TIPOVENDA"]       := AllTrim((cAls)->TIPO_VENDA)
        oRow["TIPOCOBRANCA"]    := AllTrim((cAls)->TIPO_MAXIMA)
        oRow["NIVELVENDA"]      := 1
        oRow["PRAZOMAXIMOVENDA"]:= 999
        oRow["TXJUROS"]         := 0
        oRow["PERCMULTA"]       := 0

        If !Empty(oRow["CODCOB"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"


Static Function CobCliJson()
    Local aCfg  := _GetCfg()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0

    For nI := 1 To Len(aCfg)
        cQry += IIf(!Empty(cQry), " UNION ALL ", "")
        cQry += "SELECT "
        cQry += "RTRIM(SX5.X5_CHAVE) AS CODCOB,"
        cQry += "'" + aCfg[nI][1] + "' + RTRIM(SA1.A1_COD) + RTRIM(SA1.A1_LOJA) AS CODCLI "
        cQry += "FROM " + aCfg[nI][2] + " SA1 WITH (NOLOCK) "
        cQry += "CROSS JOIN " + aCfg[nI][4] + " SX5 WITH (NOLOCK) "
        cQry += "WHERE SA1.D_E_L_E_T_ = ' ' "
        cQry += "AND SA1.A1_FILIAL LIKE '" + aCfg[nI][5] + "%' "
        cQry += "AND SA1.A1_MSBLQL <> '1' "
        cQry += "AND SX5.D_E_L_E_T_ = ' ' "
        cQry += "AND SX5.X5_TABELA = '24' "
        cQry += "AND SX5.X5_FILIAL = '' "
    Next nI

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODCOB"] := AllTrim((cAls)->CODCOB)
        oRow["CODCLI"] := AllTrim((cAls)->CODCLI)

        If !Empty(oRow["CODCOB"]) .And. !Empty(oRow["CODCLI"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"

Static Function CobPlagJson()
    Local aCfg  := _GetCfg()
    Local aBody := {}
    Local oRow  := NIL
    Local cQry  := ""
    Local cAls  := GetNextAlias()
    Local nI    := 0

    For nI := 1 To Len(aCfg)
        cQry += IIf(!Empty(cQry), " UNION ALL ", "")
        cQry += "SELECT DISTINCT "
        cQry += "RTRIM(SX5.X5_CHAVE) AS CODCOB,"
        cQry += "RTRIM(SE4.E4_CODIGO) AS CODPLPAG "
        cQry += "FROM " + aCfg[nI][3] + " SE4 WITH (NOLOCK) "
        cQry += "CROSS JOIN " + aCfg[nI][4] + " SX5 WITH (NOLOCK) "
        cQry += "WHERE SE4.D_E_L_E_T_ = ' ' "
        cQry += "AND SE4.E4_FILIAL = '" + aCfg[nI][6] + "' "
        cQry += "AND SE4.E4_TIPO = '1' "
        cQry += "AND SX5.D_E_L_E_T_ = ' ' "
        cQry += "AND SX5.X5_TABELA = '24' "
        cQry += "AND SX5.X5_FILIAL = '' "
    Next nI

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oRow := JsonObject():New()
        oRow["CODCOB"]   := AllTrim((cAls)->CODCOB)
        oRow["CODPLPAG"] := AllTrim((cAls)->CODPLPAG)

        If !Empty(oRow["CODCOB"]) .And. !Empty(oRow["CODPLPAG"])
            AAdd(aBody, oRow)
        EndIf

        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    If Len(aBody) > 0
        Return FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

Return "[]"
