//Bibliotecas
#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVR02                                                                          |
 | Descrição  : Atualiza o Historico dos Pedidos no MaxPedido.                                    |
 |                                                                                                |
 |                                                                                                |
 | versão     : 1.0                                                                               |
 | Histórico  :                                                                                   |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVR02()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRestHCp      := FwRest():New(cURI)
    Local oRestHIt      := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local cJsonHCp      := ""
    Local cJsonHIt      := ""
    Local lSucesso      := .F.

    If Empty(cBearerToken)
        Return .F.
    EndIf

    // Monta o payload de produtos e filiais
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    cJsonHCp := fHCapJson()

    oRestHCp:SetPath("/HistoricosPedidosCapas")
    oRestHCp:SetPostParams(cJsonHCp)

    If oRestHCp:Post(aHeader)
        lSucesso := .T.
        alert("atualizou Pedido")
        ConOut("POST: " + oRestHCp:GetResult())
    Else
        alert("Erro na Atualizacao")
        ConOut("POST: " + oRestHCp:GetLastError())
        lSucesso := .F.
    EndIf

   cJsonHIt := fHIteJson()

    oRestHIt:SetPath("/HistoricosPedidosItens")
    oRestHIt:SetPostParams(cJsonHIt)

    If oRestHIt:Post(aHeader)
        lSucesso := .T.
        alert("atualizou Pedido")
        ConOut("POST: " + oRestHIt:GetResult())
    Else
        alert("Erro na Atualizacao")
        ConOut("POST: " + oRestHIt:GetLastError())
        lSucesso := .F.
    EndIf


Return lSucesso


Static Function fHCapJson()
    Local aJson       := {}
    Local cQry        := ""
    Local oJson       := NIL
    Local aConfig     := {}
    Local nCfg        := 0
    Local cCliente    := ""
    Local cvendedor    := ""


   aConfig := {}
   AADD(aConfig,{"010","01", "05", "FOR002","ME","0002","2"}) //// EMPRESA_EXEMPLO_B
   AADD(aConfig,{"060","06", "02", "FOR001","PA","0001","1"}) //// EMPRESA_EXEMPLO_A
   
 
    For nCfg := 1 To Len(aConfig)
        cTabela     := aConfig[nCfg][1]
        cGrpEmp     := aConfig[nCfg][2]
        cEmpresa    := aConfig[nCfg][3]
        cFornecedor := aConfig[nCfg][4]
        cTpProd     := aConfig[nCfg][5]
        cCodSec     := aConfig[nCfg][6]
        cDepto      := aConfig[nCfg][7]

        RPCSetEnv(cGrpEmp, , , , "FAT")



        // Monta a query para buscar produtos dessa combinação
        cQry := ""
        cQry += " SELECT C5_FILIAL,C5_EMISSAO,C5_CONDPAG,C5_XNUMFV,C5_XTPPV,C5_VEND1,C5_NUM,C5_CLIENTE,C5_LOJACLI,C5_PESOL,SUM(C6_VALOR) AS VALOR,SUM(C6_QTDVEN) AS QUANT" + CRLF
        cQry += " FROM SC5" + cTabela +" SC5"+ CRLF
        cQry += " INNER JOIN SC6" + cTabela + " SC6 ON SC6.D_E_L_E_T_ = '' AND C5_FILIAL = C6_FILIAL AND C5_NUM = C6_NUM" + CRLF
        cQry += " WHERE SC5.D_E_L_E_T_ = ' '" + CRLF
        cQry += "   AND C5_FILIAL   = '"+cEmpresa+"01'" + CRLF
        cQry += "   AND C5_XTPPV = 'F'"
        cQry += "   GROUP BY C5_FILIAL,C5_EMISSAO,C5_CONDPAG,C5_XNUMFV,C5_XTPPV,C5_VEND1,C5_NUM,C5_CLIENTE,C5_LOJACLI,C5_PESOL" + CRLF
        TCQuery cQry New Alias "TABHIST"

        // Processa os produtos retornados
        While !TABHIST->(EoF())
            cCliente := cGrpEmp+cEmpresa+TABHIST->C5_CLIENTE+TABHIST->C5_LOJACLI
            cVendedor := cGrpEmp+cEmpresa+TABHIST->C5_VEND1
            cData     := Left(TABHIST->C5_EMISSAO,4)+ "-" +SubStr(TABHIST->C5_EMISSAO,5,2)+ "-" +Right(TABHIST->C5_EMISSAO,2)
            oJson := JsonObject():New()
            oJson["CODEMITENTE"]    := 8888
            oJson["CODCLI"]         :=  cCliente
            oJson["NUMNOTA"]        := ""
            oJson["TOPPESO"]        := TABHIST->C5_PESOL
            oJson["ORIGEMPED"]      := TABHIST->C5_XTPPV
            oJson["POSICAO"]        := "P" //Posição do pedido (L – Liberado, B – Bloqueado, F –Faturado, M – Montado, P – Pendente, C – Cancelado
            oJson["VLTABELA"]       := TABHIST->VALOR
            oJson["NUMPED"]         := TABHIST->C5_XNUMFV
            oJson["CONDVENDA"]      := 1
            oJson["CODFILIAL"]      := cGrpEmp+cEmpresa
            oJson["CODUSUR"]        := cVendedor
            oJson["VLTEND"]         := TABHIST->VALOR
            oJson["CODCOB"]         := TABHIST->C5_CONDPAG
            oJson["VALTOTAL"]       := TABHIST->VALOR
            oJson["DATA"]           := cData
            oJson["NUMPEDRCA"]      := TABHIST->C5_XTPPV
            oJson["CODLPAG"]        := TABHIST->C5_CONDPAG
            oJson["CODSUPERVISOR"]  := "1" 
            oJson["TOTVOLUME"]      := TABHIST->QUANT
            oJson["CODPRACA"]       := "003"

            AAdd(aJson, oJson)

            TABHIST->(DbSkip())
        EndDo
        TABHIST->(DbCloseArea())
    Next 
Return FWJsonSerialize(aJson, .F., .F., .T.)


Static Function fHIteJson()
    Local aJson       := {}
    Local cQry        := ""
    Local oJson       := NIL
    Local aConfig     := {}
    Local nCfg        := 0



   aConfig := {}
   AADD(aConfig,{"010","01", "05", "FOR002","ME","0002","2"}) //// EMPRESA_EXEMPLO_B
   AADD(aConfig,{"060","06", "02", "FOR001","PA","0001","1"}) //// EMPRESA_EXEMPLO_A
   
 
    For nCfg := 1 To Len(aConfig)
        cTabela     := aConfig[nCfg][1]
        cGrpEmp     := aConfig[nCfg][2]
        cEmpresa    := aConfig[nCfg][3]
        cFornecedor := aConfig[nCfg][4]
        cTpProd     := aConfig[nCfg][5]
        cCodSec     := aConfig[nCfg][6]
        cDepto      := aConfig[nCfg][7]

        RPCSetEnv(cGrpEmp, , , , "FAT")



        // Monta a query para buscar produtos dessa combinação
        cQry := ""
        cQry += " SELECT C5_FILIAL,C5_EMISSAO,C5_XNUMFV,C5_XTPPV,C5_COMIS1,C6_QTDVEN,C6_PRCVEN,C6_ITEM,C6_PRODUTO" + CRLF
        cQry += " FROM SC5" + cTabela +" SC5"+ CRLF
        cQry += " INNER JOIN SC6" + cTabela + " SC6 ON SC6.D_E_L_E_T_ = '' AND C5_FILIAL = C6_FILIAL AND C5_NUM = C6_NUM" + CRLF
        cQry += " WHERE SC5.D_E_L_E_T_ = ' '" + CRLF
        cQry += "   AND C5_FILIAL   = '"+cEmpresa+"01'" + CRLF
        cQry += "   AND C5_XTPPV = 'F'"
        cQry += "   ORDER BY C5_NUM,C6_ITEM" + CRLF
        TCQuery cQry New Alias "TABHIST"

        // Processa os produtos retornados
        While !TABHIST->(EoF())
            cData     := Left(TABHIST->C5_EMISSAO,4)+ "-" +SubStr(TABHIST->C5_EMISSAO,5,2)+ "-" +Right(TABHIST->C5_EMISSAO,2)
            oJson := JsonObject():New()
            oJson["NUMPED"]         := TABHIST->C5_XNUMFV
            oJson["QT"]             := TABHIST->C6_QTDVEN
            oJson["NUMSEQ"]         := TABHIST->C6_ITEM
            oJson["PVENDA"]         := TABHIST->C6_PRCVEN
            oJson["CODPROD"]        := ALLTRIM(TABHIST->C6_PRODUTO)
            oJson["PTABELA"]        := TABHIST->C6_PRCVEN
            oJson["PERCOM"]         := TABHIST->C5_COMIS1
            oJson["DATA"]           := cData
            oJson["POSICAO"]        := "P" //Posição do pedido (L – Liberado, B – Bloqueado, F –Faturado, M – Montado, P – Pendente, C – Cancelado


            AAdd(aJson, oJson)

            TABHIST->(DbSkip())
        EndDo
        TABHIST->(DbCloseArea())
    Next 
Return FWJsonSerialize(aJson, .F., .F., .T.)




