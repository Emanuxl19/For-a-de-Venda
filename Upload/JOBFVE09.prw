//Bibliotecas
#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE09                                                                          |
 | Data       : 13/11/2025                                                                        |
 | Descricao  : Envia Produtos e ProdutosFiliais para o MaxPedido                                 |     
 |  Autor     : Emanuel Azevedo                                                                   |
 | versao     : 1.1 - Acrescentado tratamento de acentos na descricao                             |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE09()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRestProd     := FwRest():New(cURI)
    Local oRestProdFil  := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local aProdFiliais  := {}
    Local cJsonProd     := ""
    Local cJsonFiliais  := ""
    Local lSucesso      := .F.

    If Empty(cBearerToken)
        Return .F.
    EndIf

    // Monta o payload de produtos e filiais
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    cJsonProd := ProdutosJson(@aProdFiliais)
    cJsonFiliais := ProdutosFiliaisJson(aProdFiliais)

 
    // Envia ao endpoint Produtos
    oRestProd:SetPath("/Produtos")
    oRestProd:SetPostParams(cJsonProd)

    If oRestProd:Post(aHeader)
        lSucesso := .T.
    Else
        Return .F.
    EndIf

    // Envia ao endpoint ProdutosFiliais (enviar mesmo se cJsonFiliais estiver vazio)
    oRestProdFil:SetPath("/ProdutosFiliais")
    oRestProdFil:SetPostParams(cJsonFiliais)

    If oRestProdFil:Post(aHeader)
        lSucesso := lSucesso .And. .T.
    Else
        lSucesso := .F.
    EndIf

Return lSucesso


Static Function ProdutosJson(aProdFiliais)
    Local aProdutos   := {}
    Local cTabela     := ""
    Local cTpProd     := ""
    Local cFornecedor := ""
    Local cQry        := ""
    Local cCodSec     := ""
    Local oProd       := NIL
    Local aConfig     := {}
    Local nCfg        := 0

   aConfig := {}
   // Array: [GrupoEmp, Empresa, Fornecedor, TipoProd, CodSec, Depto]
   AADD(aConfig,{"01", "05", "FOR002","ME","0002","2"}) //// EMPRESA_EXEMPLO_B
   AADD(aConfig,{"06", "02", "FOR001","PA","0001","1"}) //// EMPRESA_EXEMPLO_A


    For nCfg := 1 To Len(aConfig)
        cGrpEmp     := aConfig[nCfg][1]
        cEmpresa    := aConfig[nCfg][2]
        cFornecedor := aConfig[nCfg][3]
        cTpProd     := aConfig[nCfg][4]
        cCodSec     := aConfig[nCfg][5]
        cDepto      := aConfig[nCfg][6]

        RPCSetEnv(cGrpEmp, , , , "FAT")

        // Obt�m o nome correto da tabela SB1 conforme a empresa
        cTabela := RetSqlName("SB1")

        cCodFilial := Right("00" + AllTrim(cGrpEmp), 2) + Right("00" + AllTrim(cEmpresa), 2)

        cQry  := " SELECT B1_COD as CODPROD, B1_DESC, B1_TIPO, B1_UM, B1_PRV1," + CRLF
        cQry += "        B1_GRUPO, B1_POSIPI, B1_PESO, B1_PESBRU, B1_QE, B1_PROC," + CRLF
        cQry += "        '1' AS CODDEP," + CRLF
        cQry += "        '0001' AS CODSESS" + CRLF
        cQry += "   FROM " + cTabela + CRLF
        cQry += "  WHERE D_E_L_E_T_ = ' '" + CRLF
        cQry += "    AND B1_FILIAL   = '" + cEmpresa + "'" + CRLF
        cQry += "    AND B1_TIPO     = '" + cTpProd   + "'"

        TCQuery cQry New Alias "TABPROD"

        While ! TABPROD->(EoF())
            oProd := JsonObject():New()
            oProd["CODPROD"]            := AllTrim(TABPROD->CODPROD)
            oProd["DESCRICAO"]          := NormalizeText(AllTrim(TABPROD->B1_DESC))
            oProd["UNIDADE"]            := AllTrim(TABPROD->B1_UM)
            oProd["TIPOMERC"]           := AllTrim(TABPROD->B1_TIPO)
            oProd["EMBALAGEM"]          := AllTrim(TABPROD->B1_UM)
            oProd["EMBALAGEMMASTER"]    := AllTrim(TABPROD->B1_UM)
            oProd["QTUNIT"]             := 1
            oProd["QTUNITCX"]           := IIf(TABPROD->B1_QE > 0, TABPROD->B1_QE, 1)
            oProd["REVENDA"]            := "S"
            oProd["NBMSH"]              := AllTrim(TABPROD->B1_POSIPI)
            oProd["CLASSIFICFISCAL"]    := AllTrim(TABPROD->B1_POSIPI)
            oProd["CODFORNEC"]          := cFornecedor
            oProd["CODEPTO"]            := cDepto
            oProd["CODSEC"]             := cCodSec
            oProd["CODGRUPOPROD"]       := AllTrim(TABPROD->B1_GRUPO)
            oProd["PESOBRUTO"]          := IIf(TABPROD->B1_PESBRU > 0, TABPROD->B1_PESBRU, 1)
            oProd["PESOLIQ"]            := IIf(TABPROD->B1_PESO > 0, TABPROD->B1_PESO, 1)
            oProd["CODFILIAL"]          := cCodFilial
            oProd["TIPOESTOQUE"]        := "PA"
            oProd["ENVIARFORCASVENDAS"] := "S"
            oProd["DTCADASTRO"]         := "2025-12-09"
            oProd["DTVENC"]             := "2026-12-31"
            oProd["ENVIARFORCAVENDAS"]  := "S"

            AAdd(aProdutos, oProd)

            // Prepara estrutura para ProdutosFiliais (replica em todas filiais dessa config)
            AAdd(aProdFiliais, { oProd["CODPROD"], cCodFilial, cFornecedor, cDepto, cCodSec, oProd["TIPOMERC"], oProd["UNIDADE"] })

            TABPROD->(DbSkip())
        EndDo

        TABPROD->(DbCloseArea())
    Next nCfg

    // Retorna o JSON de produtos
    Return FWJsonSerialize(aProdutos, .F., .F., .T.)


Static Function ProdutosFiliaisJson(aProdFiliais)
    Local aBody := {}
    Local oFil  := NIL
    Local nI    := 0

    For nI := 1 To Len(aProdFiliais)
        oFil := JsonObject():New()
        oFil["CODPROD"]      := aProdFiliais[nI][1]
        oFil["CODFILIAL"]    := aProdFiliais[nI][2]
        oFil["CODFORNEC"]    := aProdFiliais[nI][3]
        oFil["CODEPTO"]      := aProdFiliais[nI][4]
        oFil["CODSEC"]       := aProdFiliais[nI][5]
        oFil["TIPOMERC"]     := aProdFiliais[nI][6]
        oFil["UNIDADE"]      := aProdFiliais[nI][7]
        oFil["VENDAOVR"]     := 0
        oFil["VENDAUNIT"]    := "S"
        oFil["PRECOREGIAO"]  := "N"
        oFil["PRECODEPTO"]   := "N"
        oFil["PRECOSEC"]     := "N"
        oFil["UTILIZACODFORN"] := "N"
        oFil["ENVIARFORCAVENDAS"] := "S"
        oFil["PROIBIDAVENDA"]    := "N"

        AAdd(aBody, oFil)
    Next nI

Return FWJsonSerialize(aBody, .F., .F., .T.)


// Remove acentos e caracteres especiais mais comuns
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
