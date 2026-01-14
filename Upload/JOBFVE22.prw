#include "Totvs.ch"
#include "Topconn.ch"
/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE21                                                                           |
 | Descricao  :  Integra Notas Fiscais de Devolucao (Entrada) com MaxPedido                        |
 | Data       : 07/01/2026                                                                         |
 | Responsavel: EMANUEL AZEVEDO                                                                    |     
 | Endpoints  : /Devolucoes, /Nfent, /EstornoComissao, /NotasSaidaItens                            |
 | Versao     : 1.0                                                                                |
 *-------------------------------------------------------------------------------------------------*/

 User Function JOBFVE22()
    Local cURI         := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest        := NIL
    Local aHeader      := {}
    Local cBearerToken := ""
    Local lSucesso     := .T.
    Local cJson        := ""

    // INICIALIZACAO CONDICIONAL - Só executa se ambiente não estiver preparado
    If Select("SX2") <= 0
        RPCSetEnv("06", "02", , , "FAT")
    EndIf

    cBearerToken := U_JOBFVAUT()

    If Empty(cBearerToken)
        ConOut("JOBFVE22 >> Token vazio. Abortando.")
        Return .F.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    // 1. POST /Devolucoes - Motivos de Devolucao
    cJson := DevolucoesJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/Devolucoes")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHeader)
            ConOut("JOBFVE22 >> /Devolucoes enviado com sucesso!")
        Else
            ConOut("JOBFVE22 >> Erro ao enviar /Devolucoes: " + oRest:GetLastError())
            lSucesso := .F.
        EndIf
    EndIf

    // 2. POST /Nfent - Cabecalho NF Entrada/Devolucao
    cJson := NfentJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/Nfent")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHeader)
            ConOut("JOBFVE22 >> /Nfent enviado com sucesso!")
        Else
            ConOut("JOBFVE22 >> Erro ao enviar /Nfent: " + oRest:GetLastError())
            lSucesso := .F.
        EndIf
    EndIf

    // 3. POST /EstornoComissao - Vinculo NF Devolucao x NF Saida
    cJson := EstornoComissaoJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/EstornoComissao")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHeader)
            ConOut("JOBFVE22 >> /EstornoComissao enviado com sucesso!")
        Else
            ConOut("JOBFVE22 >> Erro ao enviar /EstornoComissao: " + oRest:GetLastError())
            lSucesso := .F.
        EndIf
    EndIf

    // 4. POST /NotasSaidaItens - Itens de NF Entrada/Devolucao
    cJson := NfentItensJson()
    If !Empty(cJson) .And. cJson <> "[]"
        oRest := FwRest():New(cURI)
        oRest:SetPath("/NotasSaidaItens")
        oRest:SetPostParams(cJson)
        If oRest:Post(aHeader)
            ConOut("JOBFVE22 >> /NotasSaidaItens enviado com sucesso!")
        Else
            ConOut("JOBFVE22 >> Erro ao enviar /NotasSaidaItens: " + oRest:GetLastError())
            lSucesso := .F.
        EndIf
    EndIf

    ConOut("JOBFVE22 >> Finalizado - " + IIf(lSucesso, "OK", "COM ERROS"))

Return lSucesso


// Endpoint: POST /Devolucoes - Motivos de Devolucao (ERP_MXSTABDEV)
Static Function DevolucoesJson()
    Local aBody := {}
    Local oBody := NIL
    Local cJson := ""
    Local cQry  := ""
    Local cAls  := GetNextAlias()

    // Query UNION ALL para ambas as filiais
    cQry := ""
    cQry += "SELECT '0602' AS CODFIL, X5_CHAVE AS CODDEVOL, X5_DESCRI AS MOTIVO "
    cQry += "FROM SX5060 WITH(NOLOCK) "
    cQry += "WHERE D_E_L_E_T_ = ' ' AND X5_TABELA = 'DJ' "
    cQry += "UNION ALL "
    cQry += "SELECT '0105' AS CODFIL, X5_CHAVE AS CODDEVOL, X5_DESCRI AS MOTIVO "
    cQry += "FROM SX5010 WITH(NOLOCK) "
    cQry += "WHERE D_E_L_E_T_ = ' ' AND X5_TABELA = 'DJ' "
    cQry += "ORDER BY CODFIL, CODDEVOL"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oBody := JsonObject():New()
        oBody["CODDEVOL"] := AllTrim((cAls)->CODFIL) + AllTrim((cAls)->CODDEVOL)
        oBody["TIPO"]     := "ED"
        oBody["MOTIVO"]   := AllTrim((cAls)->MOTIVO)

        AAdd(aBody, oBody)
        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    // Se nao encontrou motivos, envia ao menos um padrao por filial
    If Len(aBody) == 0
        oBody := JsonObject():New()
        oBody["CODDEVOL"] := "06021"
        oBody["TIPO"]     := "ED"
        oBody["MOTIVO"]   := "DEVOLUCAO DE MERCADORIA"
        AAdd(aBody, oBody)

        oBody := JsonObject():New()
        oBody["CODDEVOL"] := "01051"
        oBody["TIPO"]     := "ED"
        oBody["MOTIVO"]   := "DEVOLUCAO DE MERCADORIA"
        AAdd(aBody, oBody)
    EndIf

    ConOut("JOBFVE22 >> Total Devolucoes: " + cValToChar(Len(aBody)))
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)

Return cJson


// Endpoint: POST /Nfent - Cabecalho NF Entrada/Devolucao (ERP_MXSNFENT)
Static Function NfentJson()
    Local aBody := {}
    Local oBody := NIL
    Local cJson := ""
    Local cQry  := ""
    Local cAls  := GetNextAlias()

    // Query UNION ALL para ambas as filiais
    cQry := ""
    // Filial 0602
    cQry += "SELECT '0602' AS CODFIL, "
    cQry += "SF1.R_E_C_N_O_ AS RECNO, "
    cQry += "SF1.F1_DOC AS NUMNOTA, "
    cQry += "SF1.F1_SERIE AS SERIE, "
    cQry += "SF1.F1_FORNECE AS CODFORNEC, "
    cQry += "SF1.F1_LOJA AS LOJA, "
    cQry += "SF1.F1_EMISSAO AS DTENT, "
    cQry += "SF1.F1_VALBRUT AS VLTOTAL, "
    cQry += "SF1.F1_PESO AS TOTPESO, "
    cQry += "SF1.F1_FRETE AS VLFRETE, "
    cQry += "SF1.F1_EST AS UF, "
    cQry += "ISNULL(SF1.F1_ZOBSGER,'') AS OBS, "
    cQry += "ISNULL(SA3.A3_COD,'') AS CODUSURDEVOL "
    cQry += "FROM SF1 SF1 WITH(NOLOCK) "
    cQry += "LEFT JOIN SA1 SA1 WITH(NOLOCK) ON SA1.A1_COD = SF1.F1_FORNECE AND SA1.A1_LOJA = SF1.F1_LOJA AND SA1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SA3 SA3 WITH(NOLOCK) ON SA3.A3_COD = SA1.A1_VEND AND SA3.D_E_L_E_T_ = ' ' "
    cQry += "WHERE SF1.D_E_L_E_T_ = ' ' AND SF1.F1_FILIAL LIKE '02%' AND SF1.F1_TIPO = 'D' AND SF1.F1_DTDIGIT >= '20250101' "

    cQry += "UNION ALL "

    // Filial 0105
    cQry += "SELECT '0105' AS CODFIL, "
    cQry += "SF1.R_E_C_N_O_ AS RECNO, "
    cQry += "SF1.F1_DOC AS NUMNOTA, "
    cQry += "SF1.F1_SERIE AS SERIE, "
    cQry += "SF1.F1_FORNECE AS CODFORNEC, "
    cQry += "SF1.F1_LOJA AS LOJA, "
    cQry += "SF1.F1_EMISSAO AS DTENT, "
    cQry += "SF1.F1_VALBRUT AS VLTOTAL, "
    cQry += "SF1.F1_PESO AS TOTPESO, "
    cQry += "SF1.F1_FRETE AS VLFRETE, "
    cQry += "SF1.F1_EST AS UF, "
    cQry += "ISNULL(SF1.F1_ZOBSGER,'') AS OBS, "
    cQry += "ISNULL(SA3.A3_COD,'') AS CODUSURDEVOL "
    cQry += "FROM SF1 SF1 WITH(NOLOCK) "
    cQry += "LEFT JOIN SA1 SA1 WITH(NOLOCK) ON SA1.A1_COD = SF1.F1_FORNECE AND SA1.A1_LOJA = SF1.F1_LOJA AND SA1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SA3 SA3 WITH(NOLOCK) ON SA3.A3_COD = SA1.A1_VEND AND SA3.D_E_L_E_T_ = ' ' "
    cQry += "WHERE SF1.D_E_L_E_T_ = ' ' AND SF1.F1_FILIAL LIKE '05%' AND SF1.F1_TIPO = 'D' AND SF1.F1_DTDIGIT >= '20250101' "

    cQry += "ORDER BY CODFIL, DTENT, NUMNOTA"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oBody := JsonObject():New()

        oBody["NUMTRANSENT"]       := AllTrim((cAls)->CODFIL) + StrZero((cAls)->RECNO, 10)
        oBody["CODCONT"]           := ""
        oBody["CODDEVOL"]          := AllTrim((cAls)->CODFIL) + "1"
        oBody["CODFILIAL"]         := AllTrim((cAls)->CODFIL)
        oBody["CODFISCAL"]         := 0
        oBody["DTENT"]             := FmtData(AllTrim((cAls)->DTENT))
        oBody["ESPECIE"]           := "NF"
        oBody["SERIE"]             := AllTrim((cAls)->SERIE)
        oBody["NUMNOTA"]           := Val(AllTrim((cAls)->NUMNOTA))
        oBody["OBS"]               := AllTrim((cAls)->OBS)
        oBody["CODMOTORISTADEVOL"] := ""
        oBody["CODUSURDEVOL"]      := AllTrim((cAls)->CODFIL) + AllTrim((cAls)->CODUSURDEVOL)
        oBody["SITUACAONFE"]       := 0
        oBody["UF"]                := AllTrim((cAls)->UF)
        oBody["TOTPESO"]           := (cAls)->TOTPESO
        oBody["VLFRETE"]           := (cAls)->VLFRETE
        oBody["VLST"]              := 0
        oBody["GERANFDEVCLI"]      := "S"
        oBody["CODFORNEC"]         := AllTrim((cAls)->CODFIL) + AllTrim((cAls)->CODFORNEC) + AllTrim((cAls)->LOJA)
        oBody["TIPODESCARGA"]      := "6"

        AAdd(aBody, oBody)
        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    ConOut("JOBFVE22 >> Total Nfent: " + cValToChar(Len(aBody)))
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)

Return cJson


// Endpoint: POST /EstornoComissao - Vinculo NF Devolucao x NF Saida (ERP_MXSESTCOM)
Static Function EstornoComissaoJson()
    Local aBody := {}
    Local oBody := NIL
    Local cJson := ""
    Local cQry  := ""
    Local cAls  := GetNextAlias()

    // Query UNION ALL para ambas as filiais
    cQry := ""
    // Filial 0602
    cQry += "SELECT '0602' AS CODFIL, "
    cQry += "SF1.R_E_C_N_O_ AS RECNO_F1, "
    cQry += "SF2.R_E_C_N_O_ AS RECNO_F2, "
    cQry += "SF1.F1_EMISSAO AS DTESTORNO, "
    cQry += "SF2.F2_VEND1 AS CODUSUR, "
    cQry += "SF1.F1_VALBRUT AS VLDEVOLUCAO "
    cQry += "FROM SD1 SD1 WITH(NOLOCK) "
    cQry += "INNER JOIN SF1 SF1 WITH(NOLOCK) ON SF1.F1_FILIAL = SD1.D1_FILIAL AND SF1.F1_DOC = SD1.D1_DOC AND SF1.F1_SERIE = SD1.D1_SERIE AND SF1.F1_TIPO = 'D' AND SF1.D_E_L_E_T_ = ' ' "
    cQry += "INNER JOIN SF2 SF2 WITH(NOLOCK) ON SF2.F2_FILIAL = SD1.D1_FILIAL AND SF2.F2_DOC = SD1.D1_NFORI AND SF2.D_E_L_E_T_ = ' ' "
    cQry += "WHERE SD1.D_E_L_E_T_ = ' ' AND SD1.D1_FILIAL LIKE '02%' AND SD1.D1_DTDIGIT >= '20250101' AND SD1.D1_NFORI <> '' "
    cQry += "GROUP BY SF1.R_E_C_N_O_, SF2.R_E_C_N_O_, SF1.F1_EMISSAO, SF2.F2_VEND1, SF1.F1_VALBRUT "

    cQry += "UNION ALL "

    // Filial 0105
    cQry += "SELECT '0105' AS CODFIL, "
    cQry += "SF1.R_E_C_N_O_ AS RECNO_F1, "
    cQry += "SF2.R_E_C_N_O_ AS RECNO_F2, "
    cQry += "SF1.F1_EMISSAO AS DTESTORNO, "
    cQry += "SF2.F2_VEND1 AS CODUSUR, "
    cQry += "SF1.F1_VALBRUT AS VLDEVOLUCAO "
    cQry += "FROM SD1 SD1 WITH(NOLOCK) "
    cQry += "INNER JOIN SF1 SF1 WITH(NOLOCK) ON SF1.F1_FILIAL = SD1.D1_FILIAL AND SF1.F1_DOC = SD1.D1_DOC AND SF1.F1_SERIE = SD1.D1_SERIE AND SF1.F1_TIPO = 'D' AND SF1.D_E_L_E_T_ = ' ' "
    cQry += "INNER JOIN SF2 SF2 WITH(NOLOCK) ON SF2.F2_FILIAL = SD1.D1_FILIAL AND SF2.F2_DOC = SD1.D1_NFORI AND SF2.D_E_L_E_T_ = ' ' "
    cQry += "WHERE SD1.D_E_L_E_T_ = ' ' AND SD1.D1_FILIAL LIKE '05%' AND SD1.D1_DTDIGIT >= '20250101' AND SD1.D1_NFORI <> '' "
    cQry += "GROUP BY SF1.R_E_C_N_O_, SF2.R_E_C_N_O_, SF1.F1_EMISSAO, SF2.F2_VEND1, SF1.F1_VALBRUT "

    cQry += "ORDER BY CODFIL, DTESTORNO"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        oBody := JsonObject():New()

        oBody["NUMTRANSENT"]   := AllTrim((cAls)->CODFIL) + StrZero((cAls)->RECNO_F1, 10)
        oBody["NUMTRANSVENDA"] := (cAls)->RECNO_F2
        oBody["DTESTORNO"]     := FmtData(AllTrim((cAls)->DTESTORNO))
        oBody["CODUSUR"]       := AllTrim((cAls)->CODFIL) + AllTrim((cAls)->CODUSUR)
        oBody["VLESTORNO"]     := 0
        oBody["VLDEVOLUCAO"]   := (cAls)->VLDEVOLUCAO

        AAdd(aBody, oBody)
        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    ConOut("JOBFVE22 >> Total EstornoComissao: " + cValToChar(Len(aBody)))
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)

Return cJson


// Endpoint: POST /NotasSaidaItens - Itens de NF Entrada/Devolucao (ERP_MXSMOV)
Static Function NfentItensJson()
    Local aBody  := {}
    Local oBody  := NIL
    Local cJson  := ""
    Local cQry   := ""
    Local cAls   := GetNextAlias()
    Local nTrans := 0

    // Query UNION ALL para ambas as filiais
    cQry := ""
    // Filial 0602
    cQry += "SELECT '0602' AS CODFIL, "
    cQry += "SD1.R_E_C_N_O_ AS RECNO, "
    cQry += "SF1.R_E_C_N_O_ AS RECNO_F1, "
    cQry += "SD1.D1_DOC AS NUMNOTA, "
    cQry += "SD1.D1_COD AS CODPROD, "
    cQry += "SD1.D1_ITEM AS NUMSEQ, "
    cQry += "SD1.D1_QUANT AS QT, "
    cQry += "SD1.D1_VUNIT AS PTABELA, "
    cQry += "SD1.D1_CUSTO AS CUSTOFIN, "
    cQry += "SD1.D1_VALIPI AS VLIPI, "
    cQry += "SD1.D1_ICMSRET AS ST, "
    cQry += "SD1.D1_PEDIDO AS NUMPED, "
    cQry += "ISNULL(SB1.B1_CODBAR,'') AS CODAUXILIAR, "
    cQry += "ISNULL(SA3.A3_COD,'') AS CODUSUR "
    cQry += "FROM SD1 SD1 WITH(NOLOCK) "
    cQry += "INNER JOIN SF1 SF1 WITH(NOLOCK) ON SF1.F1_FILIAL = SD1.D1_FILIAL AND SF1.F1_DOC = SD1.D1_DOC AND SF1.F1_SERIE = SD1.D1_SERIE AND SF1.F1_TIPO = 'D' AND SF1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SB1 SB1 WITH(NOLOCK) ON SB1.B1_COD = SD1.D1_COD AND SB1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SA1 SA1 WITH(NOLOCK) ON SA1.A1_COD = SF1.F1_FORNECE AND SA1.A1_LOJA = SF1.F1_LOJA AND SA1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SA3 SA3 WITH(NOLOCK) ON SA3.A3_COD = SA1.A1_VEND AND SA3.D_E_L_E_T_ = ' ' "
    cQry += "WHERE SD1.D_E_L_E_T_ = ' ' AND SD1.D1_FILIAL LIKE '02%' AND SD1.D1_DTDIGIT >= '20250101' "

    cQry += "UNION ALL "

    // Filial 0105
    cQry += "SELECT '0105' AS CODFIL, "
    cQry += "SD1.R_E_C_N_O_ AS RECNO, "
    cQry += "SF1.R_E_C_N_O_ AS RECNO_F1, "
    cQry += "SD1.D1_DOC AS NUMNOTA, "
    cQry += "SD1.D1_COD AS CODPROD, "
    cQry += "SD1.D1_ITEM AS NUMSEQ, "
    cQry += "SD1.D1_QUANT AS QT, "
    cQry += "SD1.D1_VUNIT AS PTABELA, "
    cQry += "SD1.D1_CUSTO AS CUSTOFIN, "
    cQry += "SD1.D1_VALIPI AS VLIPI, "
    cQry += "SD1.D1_ICMSRET AS ST, "
    cQry += "SD1.D1_PEDIDO AS NUMPED, "
    cQry += "ISNULL(SB1.B1_CODBAR,'') AS CODAUXILIAR, "
    cQry += "ISNULL(SA3.A3_COD,'') AS CODUSUR "
    cQry += "FROM SD1 SD1 WITH(NOLOCK) "
    cQry += "INNER JOIN SF1 SF1 WITH(NOLOCK) ON SF1.F1_FILIAL = SD1.D1_FILIAL AND SF1.F1_DOC = SD1.D1_DOC AND SF1.F1_SERIE = SD1.D1_SERIE AND SF1.F1_TIPO = 'D' AND SF1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SB1 SB1 WITH(NOLOCK) ON SB1.B1_COD = SD1.D1_COD AND SB1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SA1 SA1 WITH(NOLOCK) ON SA1.A1_COD = SF1.F1_FORNECE AND SA1.A1_LOJA = SF1.F1_LOJA AND SA1.D_E_L_E_T_ = ' ' "
    cQry += "LEFT JOIN SA3 SA3 WITH(NOLOCK) ON SA3.A3_COD = SA1.A1_VEND AND SA3.D_E_L_E_T_ = ' ' "
    cQry += "WHERE SD1.D_E_L_E_T_ = ' ' AND SD1.D1_FILIAL LIKE '05%' AND SD1.D1_DTDIGIT >= '20250101' "

    cQry += "ORDER BY CODFIL, NUMNOTA, NUMSEQ"

    TCQuery cQry New Alias (cAls)

    While !(cAls)->(Eof())
        nTrans++
        oBody := JsonObject():New()

        oBody["CODPROD"]       := AllTrim((cAls)->CODFIL) + AllTrim((cAls)->CODPROD)
        oBody["CODUSUR"]       := AllTrim((cAls)->CODFIL) + AllTrim((cAls)->CODUSUR)
        oBody["NUMSEQ"]        := Val(AllTrim((cAls)->NUMSEQ))
        oBody["CODOPER"]       := "ED"
        oBody["QT"]            := (cAls)->QT
        oBody["QTCONT"]        := (cAls)->QT
        oBody["NUMTRANSVENDA"] := NIL
        oBody["NUMTRANSITEM"]  := nTrans
        oBody["CODAUXILIAR"]   := AllTrim((cAls)->CODAUXILIAR)
        oBody["NUMCAR"]        := ""
        oBody["NUMNOTA"]       := Val(AllTrim((cAls)->NUMNOTA))
        oBody["NUMPED"]        := Val(AllTrim((cAls)->NUMPED))
        oBody["PTABELA"]       := (cAls)->PTABELA
        oBody["PUNITCONT"]     := (cAls)->PTABELA
        oBody["PUNIT"]         := (cAls)->PTABELA
        oBody["CUSTOFIN"]      := (cAls)->CUSTOFIN
        oBody["VLIPI"]         := (cAls)->VLIPI
        oBody["ST"]            := (cAls)->ST
        oBody["CODDEVOL"]      := AllTrim((cAls)->CODFIL) + "1"
        oBody["NUMTRANSENT"]   := AllTrim((cAls)->CODFIL) + StrZero((cAls)->RECNO_F1, 10)
        oBody["QTDEVOL"]       := 0
        oBody["CODFILIAL"]     := AllTrim((cAls)->CODFIL)

        AAdd(aBody, oBody)
        (cAls)->(DbSkip())
    EndDo

    (cAls)->(DbCloseArea())

    ConOut("JOBFVE22 >> Total NotasSaidaItens (Devolucao): " + cValToChar(Len(aBody)))
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)

Return cJson


// Funcao: FmtData - Formata data AAAAMMDD para AAAA-MM-DD                                       
Static Function FmtData(cData)
    Local cRet := ""

    If !Empty(cData) .And. Len(cData) >= 8
        cRet := SubStr(cData,1,4) + "-" + SubStr(cData,5,2) + "-" + SubStr(cData,7,2)
    EndIf

Return cRet
