//Bibliotecas
#Include "TOTVS.ch"
#Include "Topconn.ch"


/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVR01                                                                          |
 | Descri��o  : Receber Os pedidos de Venda Emitidos pelo APP da M�xima                          |
 |              A primeira fun��o monta os produtos e fornece a base para as filiais.             |
 |              A segunda fun��o reaproveita os dados para definir o caminho por filial.          |
 | vers�o     : 1.0                                                                               |
 | Hist�rico  :                                                                                   |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVR01()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRestPV       := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local jJson         := JsonObject():New()
    Local jJsonItens    := JsonObject():New()
    Local aPedidos      := {}
    Local aItensPV      := {}
    Local nxPed         := 0
    Local nxItens       := 0
    Local cFilPV        := ""
    Local cId_pedido    := ""
    Local cNumped       := ""
    Local cCodusur      := ""
    Local cCodusuario   := ""
    Local nStatus       := 1
    Local nTpPedido     := 1
    Local cCritica      := ""
    Local cNumCritica   := ""

    Local dDtPedFV      := Date()
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
    Local aStatus      := {}


    // Monta o payload de produtos e filiais
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    // Envia ao endpoint ProdutosFiliais (enviar mesmo se cJsonFiliais estiver vazio)
    oRestPV:SetPath("/StatusPedidos/0,1,2,9/1")

    If oRestPV:Get(aHeader)
            
        jJson:FromJson(oRestPV:CRESULT) 
        
        For nxPed := 1 to len(jJson["success"])  
            nTpPedido   := jJson["success"][nxPed]["tipopedido"]
            nStatus     := jJson["success"][nxPed]["status"]
            If  (nStatus == 0 .or. nStatus == 1 .or. nStatus == 2 .or. nStatus == 9) .And. nTpPedido == 1
                jJsonItens:FromJson(jJson["success"][nxPed]["objeto_json"]) 
                cId_pedido  := jJson["success"][nxPed]["id_pedido"]
                cNumped     := jJson["success"][nxPed]["numped"]
                cCodusur    := jJson["success"][nxPed]["codusur"]
                cCodusuario := jJson["success"][nxPed]["codusuario"]
                cCritica    := jJson["success"][nxPed]["critica"]
                cNumCritica := jJson["success"][nxPed]["numcritica"]
                cFilPV      := jJsonItens["CodigoFilialNF"]
                cCodCli     := SubStr(jJsonItens["Cliente"]["Codigo"],5,6)
                cLojCli     := SubStr(jJsonItens["Cliente"]["Codigo"],11,2)
                cNomCli     := jJsonItens["Cliente"]["Nome"]
                dDtPedFV    := Ctod(SubStr(jJsonItens["Data"],1,10))
                cCondPg     := StrZero(Val(jJsonItens["PlanoPagamento"]["Codigo"]),3)
                If Len(Alltrim(jJsonItens["Representante"]["Codigo"])) >6
                    cCodVend    := Right(Alltrim(jJsonItens["Representante"]["Codigo"]),6)
                Else    
                    cCodVend    := StrZero(Val(jJsonItens["Representante"]["Codigo"]),6)
                EndIf
                aItensPV := {}
                For nxItens := 1 to Len(jJsonItens["Produtos"])
                    cCodProd    := jJsonItens["Produtos"][nxItens]["Codigo"]
                    cDescProd   := jJsonItens["Produtos"][nxItens]["Descricao"]  
                    cUMProd     := jJsonItens["Produtos"][nxItens]["Unidade"]      
                    cCodTES     := "501"
                    nQuant      := jJsonItens["Produtos"][nxItens]["Quantidade"]
                    nVlrUnit    := jJsonItens["Produtos"][nxItens]["PrecoVenda"] 
                    nVlrTotal      := nQuant * nVlrUnit
                    nVlrDesc    := 0
                    AADD(aItensPV,{cCodProd,cDescProd,cUMProd,cCodTES,nQuant,nVlrUnit,nVlrDesc,nVlrTotal})
                Next
                AADD(aPedidos,{cFilPV,cId_pedido,cNumped,cCodusur,cCodusuario,cCodCli,cLojCli,cNomCli,dDtPedFV,cCondPg, cCodVend,aItensPV,cNumCritica,cCritica})
            EndIf
        Next     
   

    Else
        fConOut("[JOBFVR01] - ** Erro Api ViaCep: "+oRestPV:GetLastError())
    Endif  
   
   
    FreeObj(oRestPV)
    aStatus := fGravaPed(aPedidos)
    If !Empty(aStatus)
        fStatusFV(cURI,aHeader,aStatus)
    EndIf
Return

Static Function fGravaPed(aPedidos)
    Local aRetorno  := {}
	Local c1DupNat	:= ""
	Local aCabec	:= {}
	Local aLinha	:= {}
	Local aItens	:= {}
    Local cCodEmp   := ""
    Local cCodFil   := ""
    Local nX        := 0
    Local nxItens   := 0
    Local nVolume   := 0
    Local cSpecie   := ""
    Local cUM       := ""

	Private lMsErroAuto	:= .F.

    For nX := 1 to Len(aPedidos)

	    lRet 	:= .F.
        aCabec	:= {}
	    aLinha	:= {}
	    aItens	:= {}
	    lMsErroAuto	:= .F.
        cCodEmp := Left(aPedidos[nX,1],2)
        cCodFil := Right(aPedidos[nX,1],2)
        RPCSetEnv(cCodEmp,cCodFil, , , "FAT")
        If fValPV(cCodEmp,Alltrim(Str(aPedidos[nX,3])))
            aAdd(aCabec,{"C5_TIPO" 		,"N",               Nil})
            aAdd(aCabec,{"C5_CLIENTE"	,aPedidos[nX,6],	Nil})
            aAdd(aCabec,{"C5_LOJACLI"	,aPedidos[nX,7],    Nil})
            aAdd(aCabec,{"C5_CLIENT"	,aPedidos[nX,6],	Nil})
            aAdd(aCabec,{"C5_LOJAENT"	,aPedidos[nX,7],	Nil})
            aAdd(aCabec,{"C5_CONDPAG"	,aPedidos[nX,10],	Nil})
            aAdd(aCabec,{"C5_TABELA" 	,"",	            Nil})
            aAdd(aCabec,{"C5_MOEDA"  	,1,				    Nil})
            aAdd(aCabec,{"C5_XTPPV"  	,"F",				Nil}) /// FOR�A DE VENDA
            aAdd(aCabec,{"C5_VEND1"  	,aPedidos[nX,11],	Nil})
            aAdd(aCabec,{"C5_XNUMFV"  	,Alltrim(Str(aPedidos[nX,3])),	Nil})
            
            c1DupNat	:= Upper(SuperGetMv("MV_1DUPNAT",.F.,""))		   								
            If ( "C5_NATUREZ" $ c1DupNat )
                aAdd(aCabec,{"C5_NATUREZ",GetAdvFval("SA1","A1_NATUREZ",xFilial("SA1")+aPedidos[nX,6]+aPedidos[nX,7])  ,Nil})
            Endif

            For nxItens := 1 to len(aPedidos[nX,12])      
                aLinha := {}  
                If Empty(cUM)
                    cUM := Posicione("SB1",1,xFilial("SB1")+aPedidos[nX,12][nxItens][1],"B1_UM")
                    cSpecie := Posicione("SAH",1,xFilial("SAH")+cUM,"AH_UMRES")
                EndIf
                aAdd(aLinha,{"C6_ITEM",		StrZero(1,TamSX3("C6_ITEM")[1]),Nil})
                aAdd(aLinha,{"C6_PRODUTO",	aPedidos[nX,12][nxItens][1],    Nil})
                aAdd(aLinha,{"C6_QTDVEN",	aPedidos[nX,12][nxItens][5],	Nil})
                aAdd(aLinha,{"C6_PRCVEN",	aPedidos[nX,12][nxItens][6],	Nil})
                aAdd(aLinha,{"C6_PRUNIT",	aPedidos[nX,12][nxItens][6],	Nil})
                aAdd(aLinha,{"C6_VALOR",	aPedidos[nX,12][nxItens][8],	Nil})
                aAdd(aLinha,{"C6_TES",		aPedidos[nX,12][nxItens][4],	Nil})
                aAdd(aLinha,{"C6_DESCONT",	aPedidos[nX,12][nxItens][7],	Nil})
                aAdd(aLinha,{"C6_VALDESC",	aPedidos[nX,12][nxItens][7],	Nil}) 
                aAdd(aItens,aLinha)
                nVolume += aPedidos[nX,12][nxItens][5]
            Next        
            aAdd(aCabec,{"C5_VOLUME1"  	,nVolume,				Nil}) /// FOR�A DE VENDA
            aAdd(aCabec,{"C5_ESPECI1"  	,cSpecie,				Nil}) /// FOR�A DE VENDA
            FwMsgRun(Nil,{|| MSExecAuto({|x,y,z| MATA410(x,y,z)},aCabec,aItens,3)},Nil,"Gerando o pedido de venda...")
            

            If !lMsErroAuto
                ///            cId_pedido     cNumped        cCodusur       cCodusuario    numcritica      critica         numpederp
                AADD(aRetorno,{aPedidos[nX,2],aPedidos[nX,3],aPedidos[nX,4],aPedidos[nX,5],aPedidos[nX,13],aPedidos[nX,14],aPedidos[nX,3]})
            Else
                lRet := .F.
            EndIf
        EndIf
    Next

Return aRetorno



Static Function fStatusFV(cURI,aHeader,aStatus)

    Local oStatus    := FwRest():New(cURI)
    Local cJsonStat  := ""
    Local lSucesso   := .F.
    Local nX         := 1
    
    For nX := 1 to Len(aStatus)
        cJsonStat := StatusJson(aStatus[nX])
        oStatus:SetPath("/StatusPedidos")
//        oStatus:SetPutParams(cJsonStat)

        If oStatus:Put(aHeader,cJsonStat)
            lSucesso := .T.
            alert("atualizou Pedido")
            ConOut("PUT: " + oStatus:GetResult())
        Else
            alert("Erro na Atualizacao")
            ConOut("PUT: " + oStatus:GetLastError())
            lSucesso := .F.
        EndIf
    Next
 
Return lSucesso


Static Function StatusJson(aDadosSt)
    Local sJsonCrit   := ""
    Local sJsonStat   := ""
    Local cData     := StrZero(Year(Date()),4) + "-" + StrZero(Month(Date()),2) + "-" + StrZero(Day(Date()),2)
    Local cNumCrit := ""

    cNumCrit+= StrZero(Year(Date()),4)  + StrZero(Month(Date()),2) + StrZero(Day(Date()),2)+"00000000"
 
    sJsonCrit += '"{\"numPedido\":'+Alltrim(str(aDadosSt[2]))+','
    sJsonCrit += '\"codigoPedidoNuvem\":'+Alltrim(str(aDadosSt[1]))+','
    sJsonCrit += '\"numPedidoERP\":\"'+Alltrim(str(aDadosSt[7]))+'\",'
    sJsonCrit += '\"numCritica\":'+cNumCrit+','
    sJsonCrit += '\"codigoUsuario\":'+Alltrim(aDadosSt[4])+','
    sJsonCrit += '\"data\":\"'+cData+'\",'
    sJsonCrit += '\"tipo\":\"Sucesso\",'
    sJsonCrit += '\"posicaoPedidoERP\":\"Pendente\"}"'
 
    sJsonStat+= '[{"id_pedido":'+Alltrim(Str(aDadosSt[1]))+','
    sJsonStat+= '"numped":'+Alltrim(Str(aDadosSt[2]))+','
    sJsonStat+= '"status":4,'
    sJsonStat+= '"data":"'+cData+'",'
    sJsonStat+= '"tipopedido":1,'
    sJsonStat+= '"codusur":"'+aDadosSt[3]+'",'
    sJsonStat+= '"codusuario":"'+aDadosSt[4]+'",'
    sJsonStat+= '"numcritica":'+cNumCrit+','
    sJsonStat+= '"tipocritica":0,'
    sJsonStat+= '"numpederp":'+Alltrim(Str(aDadosSt[7]))+','
    sJsonStat+= '"critica":'+sJsonCrit+'}]'
Return sJsonStat

Static Function fValPV(cEmpresa,cNroFV)
    Local lRet := .T.
    Local cQry := ""
    Local cTabela := ""
        // Usa RetSqlName para obter o nome correto da tabela conforme empresa
        cTabela := RetSqlName("SC5")

        // Monta a query para buscar produtos dessa combina��o
        cQry := ""
        cQry += " SELECT C5_FILIAL,C5_EMISSAO,C5_NUM,C5_XNUMFV" + CRLF
        cQry += " FROM " + cTabela +" SC5"+ CRLF
        cQry += " WHERE SC5.D_E_L_E_T_ = ' '" + CRLF
        cQry += "   AND C5_FILIAL   = '"+cEmpresa+"01'" + CRLF
        cQry += "   AND C5_XNUMFV = '"+cNroFV+"'"
        cQry += "   GROUP BY C5_FILIAL,C5_EMISSAO,C5_CONDPAG,C5_XNUMFV,C5_XTPPV,C5_VEND1,C5_NUM,C5_CLIENTE,C5_LOJACLI,C5_PESOL" + CRLF
        TCQuery cQry New Alias "TABHIST"

        If !TABHIST->(EoF())
            conout("PEDIDO -->"+TABHIST->C5_XNUMFV)
            lRet := .F.
        Else
            conout("PASSOU -->")
            lRet := .T.
        EndIf
        TABHIST->(DbCloseArea())

Return lRet
