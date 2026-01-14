//Bibliotecas
#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVR04                                                                          |
 | Descri��o  : Receber Os Or�amentos Emitidos pelo APP da M�xima                                 |
 |              Fluxo igual ao JOBFVR01, por�m usa endpoint /2 e grava em SCJ/SCK (MATA415)       |
 | Data       : 09/01/2026                                                                        |
 | Responsavel: EMANUEL AZEVEDO                                                                   |
 | Vers�o     : 1.0                                                                               |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVR04()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRestORC      := NIL
    Local aHeader       := {}
    Local cBearerToken  := ""
    Local jJson         := JsonObject():New()
    Local jJsonItens    := JsonObject():New()
    Local aOrcamentos   := {}
    Local aItensORC     := {}
    Local nxOrc         := 0
    Local nxItens       := 0
    Local cFilORC       := ""
    Local cId_pedido    := ""
    Local cNumped       := ""
    Local cCodusur      := ""
    Local cCodusuario   := ""
    Local nStatus       := 1
    Local nTpPedido     := 2  // Or�amento
    Local cCritica      := ""
    Local cNumCritica   := ""

    Local dDtOrcFV      := Date()
    Local cCodCli       := ""
    Local cLojCli       := ""
    Local cNomCli       := ""
    Local cCondPg       := ""
    Local cCodVend      := ""
    Local cCodProd      := ""
    Local cDescProd     := ""
    Local cUMProd       := ""
    Local cCodTES       := ""
    Local nQuant        := 0
    Local nVlrUnit      := 0
    Local nVlrTotal     := 0
    Local nVlrDesc      := 0
    Local aStatus       := {}

    // INICIALIZACAO CONDICIONAL - S�o executa se ambiente n�o estiver preparado
    If Select("SX2") <= 0
        RPCSetEnv("06", "02", , , "FAT")
    EndIf

    cBearerToken := U_JOBFVAUT()

    If Empty(cBearerToken)
        ConOut("JOBFVR04 >> Token vazio. Abortando.")
        Return .F.
    EndIf

    // Monta o Header
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRestORC := FwRest():New(cURI)

    // DIFERENCA: /2 no final = Or�amentos (ao inv�s de /1 = Pedidos)
    oRestORC:SetPath("/StatusPedidos/0,1,2,9/2")

    If oRestORC:Get(aHeader)
            
        jJson:FromJson(oRestORC:cResult) 
        
        If jJson:HasProperty("success") .And. ValType(jJson["success"]) == "A"
            For nxOrc := 1 To Len(jJson["success"])  
                nTpPedido   := jJson["success"][nxOrc]["tipopedido"]
                nStatus     := jJson["success"][nxOrc]["status"]

                // DIFERENCA: tipopedido = 2 (Or�amento)
                If (nStatus == 0 .Or. nStatus == 1 .Or. nStatus == 2 .Or. nStatus == 9) .And. nTpPedido == 2
                    jJsonItens:FromJson(jJson["success"][nxOrc]["objeto_json"]) 
                    cId_pedido  := jJson["success"][nxOrc]["id_pedido"]
                    cNumped     := jJson["success"][nxOrc]["numped"]
                    cCodusur    := jJson["success"][nxOrc]["codusur"]
                    cCodusuario := jJson["success"][nxOrc]["codusuario"]
                    cCritica    := IIf(jJson["success"][nxOrc]:HasProperty("critica"), jJson["success"][nxOrc]["critica"], "")
                    cNumCritica := IIf(jJson["success"][nxOrc]:HasProperty("numcritica"), cValToChar(jJson["success"][nxOrc]["numcritica"]), "")
                    cFilORC     := jJsonItens["CodigoFilialNF"]
                    cCodCli     := SubStr(jJsonItens["Cliente"]["Codigo"], 5, 6)
                    cLojCli     := SubStr(jJsonItens["Cliente"]["Codigo"], 11, 2)
                    cNomCli     := jJsonItens["Cliente"]["Nome"]
                    dDtOrcFV    := CToD(SubStr(jJsonItens["Data"], 1, 10))
                    cCondPg     := StrZero(Val(jJsonItens["PlanoPagamento"]["Codigo"]), 3)

                    If Len(AllTrim(jJsonItens["Representante"]["Codigo"])) > 6
                        cCodVend := Right(AllTrim(jJsonItens["Representante"]["Codigo"]), 6)
                    Else    
                        cCodVend := StrZero(Val(jJsonItens["Representante"]["Codigo"]), 6)
                    EndIf

                    aItensORC := {}
                    For nxItens := 1 To Len(jJsonItens["Produtos"])
                        cCodProd    := jJsonItens["Produtos"][nxItens]["Codigo"]
                        cDescProd   := jJsonItens["Produtos"][nxItens]["Descricao"]  
                        cUMProd     := jJsonItens["Produtos"][nxItens]["Unidade"]      
                        cCodTES     := "501"
                        nQuant      := jJsonItens["Produtos"][nxItens]["Quantidade"]
                        nVlrUnit    := jJsonItens["Produtos"][nxItens]["PrecoVenda"] 
                        nVlrTotal   := nQuant * nVlrUnit
                        nVlrDesc    := 0

                        AAdd(aItensORC, {cCodProd, cDescProd, cUMProd, cCodTES, nQuant, nVlrUnit, nVlrDesc, nVlrTotal})
                    Next

                    // Array: {Filial, Id, NumPed, CodUsur, CodUsuario, CodCli, LojaCli, NomeCli, Data, CondPag, Vendedor, Itens, NumCritica, Critica}
                    AAdd(aOrcamentos, {cFilORC, cId_pedido, cNumped, cCodusur, cCodusuario, cCodCli, cLojCli, cNomCli, dDtOrcFV, cCondPg, cCodVend, aItensORC, cNumCritica, cCritica})
                EndIf
            Next
        EndIf
    Else
        ConOut("JOBFVR04 >> Erro na API: " + oRestORC:GetLastError())
        Return .F.
    EndIf  
   
    FreeObj(oRestORC)

    ConOut("JOBFVR04 >> Orcamentos recebidos: " + cValToChar(Len(aOrcamentos)))

    aStatus := fGravaOrc(aOrcamentos)

    If !Empty(aStatus)
        fStatusORC(cURI, aHeader, aStatus)
    EndIf

    ConOut("JOBFVR04 >> Finalizado. Orcamentos integrados: " + cValToChar(Len(aStatus)))

Return .T.


// Grava or�amentos no Protheus usando MATA415 (SCJ/SCK)
Static Function fGravaOrc(aOrcamentos)
    Local aRetorno  := {}
    Local aCabec    := {}
    Local aLinha    := {}
    Local aItens    := {}
    Local cCodEmp   := ""
    Local cCodFil   := ""
    Local nX        := 0
    Local nxItens   := 0
    Local lRet      := .F.

    Private lMsErroAuto := .F.
    Private lMsHelpAuto := .T.

    For nX := 1 To Len(aOrcamentos)

        lRet        := .F.
        aCabec      := {}
        aLinha      := {}
        aItens      := {}
        lMsErroAuto := .F.

        cCodEmp := Left(aOrcamentos[nX, 1], 2)
        cCodFil := Right(aOrcamentos[nX, 1], 2)

        RPCSetEnv(cCodEmp, cCodFil, , , "FAT")

        If fValOrc(cCodFil, AllTrim(Str(aOrcamentos[nX, 3])))

            // DIFERENCA: Cabecalho do Or�amento (SCJ) ao inv�s de SC5
            AAdd(aCabec, {"CJ_CLIENTE", aOrcamentos[nX, 6],  NIL})
            AAdd(aCabec, {"CJ_LOJA",    aOrcamentos[nX, 7],  NIL})
            AAdd(aCabec, {"CJ_CLIENT",  aOrcamentos[nX, 6],  NIL})
            AAdd(aCabec, {"CJ_LOJAENT", aOrcamentos[nX, 7],  NIL})
            AAdd(aCabec, {"CJ_CONDPAG", aOrcamentos[nX, 10], NIL})
            AAdd(aCabec, {"CJ_TPFRETE", "C",                 NIL})
            AAdd(aCabec, {"CJ_VEND1",   aOrcamentos[nX, 11], NIL})
            AAdd(aCabec, {"CJ_NUMEXT", AllTrim(Str(aOrcamentos[nX, 3])), NIL})  // Num pedido MaxPedido

            // DIFERENCA: Itens do Or�amento (SCK) ao inv�s de SC6
            For nxItens := 1 To Len(aOrcamentos[nX, 12])      
                aLinha := {}  

                AAdd(aLinha, {"CK_ITEM",    StrZero(nxItens, TamSX3("CK_ITEM")[1]), NIL})
                AAdd(aLinha, {"CK_PRODUTO", aOrcamentos[nX, 12][nxItens][1],        NIL})
                AAdd(aLinha, {"CK_QTDVEN",  aOrcamentos[nX, 12][nxItens][5],        NIL})
                AAdd(aLinha, {"CK_PRCVEN",  aOrcamentos[nX, 12][nxItens][6],        NIL})
                AAdd(aLinha, {"CK_PRUNIT",  aOrcamentos[nX, 12][nxItens][6],        NIL})
                AAdd(aLinha, {"CK_VALOR",   aOrcamentos[nX, 12][nxItens][8],        NIL})
                AAdd(aLinha, {"CK_TES",     aOrcamentos[nX, 12][nxItens][4],        NIL})
                AAdd(aLinha, {"CK_DESCONT", aOrcamentos[nX, 12][nxItens][7],        NIL})

                AAdd(aItens, aLinha)
            Next

            // DIFERENCA: Usa MATA415 (Or�amentos) ao inv�s de MATA410 (Pedidos)
            FwMsgRun(NIL, {|| MSExecAuto({|x,y,z| MATA415(x, y, z)}, aCabec, aItens, 3)}, NIL, "Gerando o or�amento...")

            If !lMsErroAuto
                // {cId_pedido, cNumped, cCodusur, cCodusuario, numcritica, critica, numpederp}
                AAdd(aRetorno, {aOrcamentos[nX, 2], aOrcamentos[nX, 3], aOrcamentos[nX, 4], aOrcamentos[nX, 5], aOrcamentos[nX, 13], aOrcamentos[nX, 14], aOrcamentos[nX, 3]})
                ConOut("JOBFVR04 >> Orcamento " + cValToChar(aOrcamentos[nX, 3]) + " integrado com sucesso!")
            Else
                ConOut("JOBFVR04 >> ERRO ao gravar orcamento " + cValToChar(aOrcamentos[nX, 3]))
                lRet := .F.
            EndIf
        EndIf
    Next

Return aRetorno


// Envia status de retorno para API MaxPedido
Static Function fStatusORC(cURI, aHeader, aStatus)
    Local oStatus    := NIL
    Local cJsonStat  := ""
    Local lSucesso   := .F.
    Local nX         := 0
    
    For nX := 1 To Len(aStatus)
        oStatus := FwRest():New(cURI)

        cJsonStat := StatusJson(aStatus[nX])
        oStatus:SetPath("/StatusPedidos")

        If oStatus:Put(aHeader, cJsonStat)
            lSucesso := .T.
            ConOut("JOBFVR04 >> Status atualizado para orcamento ID: " + cValToChar(aStatus[nX][1]))
        Else
            ConOut("JOBFVR04 >> Erro ao atualizar status ID: " + cValToChar(aStatus[nX][1]) + " - " + oStatus:GetLastError())
            lSucesso := .F.
        EndIf
    Next
 
Return lSucesso


// Monta JSON de status do or�amento
Static Function StatusJson(aDadosSt)
    Local sJsonCrit := ""
    Local sJsonStat := ""
    Local cData     := StrZero(Year(Date()), 4) + "-" + StrZero(Month(Date()), 2) + "-" + StrZero(Day(Date()), 2)
    Local cNumCrit  := ""

    cNumCrit := StrZero(Year(Date()), 4) + StrZero(Month(Date()), 2) + StrZero(Day(Date()), 2) + "00000000"
 
    sJsonCrit += '"{\"numPedido\":' + AllTrim(Str(aDadosSt[2])) + ','
    sJsonCrit += '\"codigoPedidoNuvem\":' + AllTrim(Str(aDadosSt[1])) + ','
    sJsonCrit += '\"numPedidoERP\":\"' + AllTrim(Str(aDadosSt[7])) + '\",'
    sJsonCrit += '\"numCritica\":' + cNumCrit + ','
    sJsonCrit += '\"codigoUsuario\":' + AllTrim(aDadosSt[4]) + ','
    sJsonCrit += '\"data\":\"' + cData + '\",'
    sJsonCrit += '\"tipo\":\"Sucesso\",'
    sJsonCrit += '\"posicaoPedidoERP\":\"Pendente\"}"'
 
    sJsonStat += '[{"id_pedido":' + AllTrim(Str(aDadosSt[1])) + ','
    sJsonStat += '"numped":' + AllTrim(Str(aDadosSt[2])) + ','
    sJsonStat += '"status":4,'
    sJsonStat += '"data":"' + cData + '",'
    // DIFERENCA: tipopedido = 2 (Or�amento)
    sJsonStat += '"tipopedido":2,'
    sJsonStat += '"codusur":"' + aDadosSt[3] + '",'
    sJsonStat += '"codusuario":"' + aDadosSt[4] + '",'
    sJsonStat += '"numcritica":' + cNumCrit + ','
    sJsonStat += '"tipocritica":0,'
    sJsonStat += '"numpederp":' + AllTrim(Str(aDadosSt[7])) + ','
    sJsonStat += '"critica":' + sJsonCrit + '}]'

Return sJsonStat


// Valida se or�amento j� existe no Protheus
Static Function fValOrc(cCodFil, cNroFV)
    Local lRet    := .T.
    Local cQry    := ""
    Local cTabela := ""
    Local cAls    := GetNextAlias()

    // Usa RetSqlName para obter o nome correto da tabela conforme empresa
    cTabela := RetSqlName("SCJ")

    cQry := ""
    cQry += " SELECT CJ_NUM, CJ_NUMEXT" + CRLF
    cQry += " FROM " + cTabela + " SCJ" + CRLF
    cQry += " WHERE SCJ.D_E_L_E_T_ = ' '" + CRLF
    cQry += "   AND CJ_FILIAL = '" + cCodFil + "'" + CRLF
    cQry += "   AND CJ_NUMEXT = '" + cNroFV + "'"

    TCQuery cQry New Alias (cAls)

    If !(cAls)->(EoF())
        ConOut("JOBFVR04 >> Orcamento ja existe: CJ_NUM=" + AllTrim((cAls)->CJ_NUM) + " CJ_NUMEXT=" + AllTrim((cAls)->CJ_NUMEXT))
        lRet := .F.
    EndIf

    (cAls)->(DbCloseArea())

Return lRet

