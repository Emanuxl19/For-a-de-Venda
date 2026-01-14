#Include "TOTVS.ch"
#Include "Topconn.ch"
#Include "Protheus.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVR03                                                                           |
 | Data       : 06/01/2026
 | Descricao  : Receber clientes cadastrados no MaxPedido e integrar ao Protheus (SA1)             |
 | Autor      : EMANUEL AZEVEDO                                                                    |
 | Versao     : 1.0                                                                                |
 *-------------------------------------------------------------------------------------------------*/

User Function JOBFVR03()

    Local aArea     := GetArea()
    Local cURI      := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest     := FwRest():New(cURI)
    Local aHeader   := {}
    Local cToken    := U_JOBFVAUT()
    Local jJson     := JsonObject():New()
    Local aClientes := {}
    Local aStatus   := {}
    Local aSuccess  := NIL
    Local nX        := 0
    Local nStat     := 0
    Local cEmpFil   := ""
    Local jObjCli   := NIL

    If Select("SX2") <= 0
        RPCSetEnv("06", "02", , , "FAT")
    EndIf

    cToken := U_JOBFVAUT()
    If Empty(cToken)
        ConOut("JOBFVR03 >> Token nao informado. Abortando.")
        RestArea(aArea)
        Return .F.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cToken)

    oRest:SetPath("/StatusClientes/0,1,2,5,9")

    If oRest:Get(aHeader)
        jJson:FromJson(oRest:cResult)

        // Valida propriedade success (case insensitive)
        If jJson:HasProperty("success")
            aSuccess := jJson["success"]
        ElseIf jJson:HasProperty("Success")
            aSuccess := jJson["Success"]
        EndIf

        If ValType(aSuccess) == "A"

            For nX := 1 To Len(aSuccess)

                nStat := aSuccess[nX]["status"]

                    // Processa apenas pendências (0/1/2/9)
                If nStat == 0 .Or. nStat == 1 .Or. nStat == 2 .Or. nStat == 9
                    jObjCli := JsonObject():New()
                    jObjCli:FromJson(aSuccess[nX]["objeto_json"])

                    // Define empresa/filial pelo Codfilialnf
                    cEmpFil := "0602"
                    If jObjCli:HasProperty("Codfilialnf") .And. !Empty(jObjCli["Codfilialnf"])
                        If Left(jObjCli["Codfilialnf"], 2) == "01"
                            cEmpFil := "0105"
                        EndIf
                    EndIf

                    // Valida campos obrigatorios
                    If Empty(fJsonVal(jObjCli, "Cgcent")) .Or.;
                       Empty(fJsonVal(jObjCli, "Cliente")) .Or.;
                       Empty(fJsonVal(jObjCli, "Estent"))
                        
                        AAdd(aStatus, {aSuccess[nX]["id_cliente"], ;
                            aSuccess[nX]["data"], ;
                            jObjCli, ;
                            5, 3, ;
                            "Dados obrigatorios faltando", ""})
                    Else
                        AAdd(aClientes, {aSuccess[nX]["id_cliente"], ;
                            aSuccess[nX]["data"], ;
                            jObjCli, ;
                            cEmpFil})
                    EndIf
                EndIf
            Next
        EndIf
    Else
        ConOut("JOBFVR03 >> Erro ao buscar clientes: " + oRest:GetLastError())
    EndIf

    FreeObj(oRest)

    // Integra clientes no Protheus
    aStatus := fIntegraCli(aClientes, aStatus)

    // Envia status de retorno
    If Len(aStatus) > 0
        fEnviaStatus(cURI, aHeader, aStatus)
    EndIf

    ConOut("JOBFVR03 >> Finalizado. Clientes processados: " + cValToChar(Len(aStatus)))

Return .T.


//fIntegraCli - Integra clientes no SA1 via MSExecAuto MATA030 
Static Function fIntegraCli(aClientes, aStatus)
    Local nX        := 0
    Local aDados    := {}
    Local aErros    := {}
    Local cCodCli   := ""
    Local cLoja     := ""
    Local cCritica  := ""
    Local cCGC      := ""
    Local cVend     := ""
    Local cAls      := ""
    Local cEmpFil   := ""
    Local cGrpEmp   := ""
    Local cFil      := ""
    Local cEmpAnt   := ""
    Local cFilAnt   := ""
    Local cFilSA1   := ""
    Local nOpc      := 3
    Local nProx     := 0
    Local lOk       := .F.
    Local nI        := 0
    Local cTabelaSA1:= ""

    Private lMsErroAuto := .F.
    Private lMsHelpAuto := .T.

    For nX := 1 To Len(aClientes)
        cEmpFil := AllTrim(cValToChar(aClientes[nX][4])) // "0105" ou "0602"
        cGrpEmp := Left(cEmpFil, 2)
        cFil    := Right(cEmpFil, 2)

      // Verifica se precisa trocar de empresa
         If cEmpAnt <> cGrpEmp .Or. cFilAnt <> cFil
            RPCSetEnv(cGrpEmp, cFil, NIL, NIL, "FAT")
            cEmpAnt := cGrpEmp
            cFilAnt := cFil
        EndIf

        // SA1 normalmente usa filial 2 dígitos; garantimos isso
        cFilSA1 := Left(xFilial("SA1"), 2)
        If Empty(cFilSA1)
            cFilSA1 := cFil
        EndIf

                lMsErroAuto := .F.
        aDados   := {}
        aErros   := {}
        cCodCli  := ""
        cLoja    := ""
        cCritica := ""
        nOpc     := 3
        lOk      := .F.

        // Busca CGC apenas numeros
        cCGC := fSoNum(fJsonVal(aClientes[nX][3], "Cgcent"))
        If Empty(cCGC)
            AAdd(aStatus, { aClientes[nX][1], aClientes[nX][2], aClientes[nX][3], 5, 3, "CGC/CPF (Cgcent) vazio.", "" })
            Loop
        EndIf

            cTabelaSA1 := "SA1" + cGrpEmp + "0"

         // Verifica se cliente já existe pelo CGC (mesma filial SA1)
        cAls := GetNextAlias()
        TCQuery ;
            " SELECT A1_COD, A1_LOJA " + CRLF + ;
            "   FROM " + cTabelaSA1 + " SA1 WITH (NOLOCK) " + CRLF + ;
            "  WHERE SA1.D_E_L_E_T_ = ' ' " + CRLF + ;
            "    AND SA1.A1_FILIAL  = '" + fSqlEscape(cFilSA1) + "' " + CRLF + ;
            "    AND REPLACE(REPLACE(REPLACE(REPLACE(RTRIM(SA1.A1_CGC),'.',''),'-',''),'/',''),' ','') = '" + fSqlEscape(cCGC) + "' " ;
            New Alias (cAls)

        If !(cAls)->(Eof())
            cCodCli := AllTrim((cAls)->A1_COD)
            cLoja   := AllTrim((cAls)->A1_LOJA)
            nOpc    := 4  // Alteracao
        Else
            // Busca proximo codigo disponivel
            (cAls)->(DbCloseArea())
            cAls := GetNextAlias()

            TCQuery ;
                " SELECT MAX(CAST(A1_COD AS INT)) AS MAXCOD " + CRLF + ;
                "   FROM " + cTabelaSA1 + " SA1 WITH (NOLOCK) " + CRLF + ;
                "  WHERE SA1.D_E_L_E_T_ = ' ' " + CRLF + ;
                "    AND SA1.A1_FILIAL  = '" + fSqlEscape(cFilSA1) + "' " + CRLF + ;
                "    AND ISNUMERIC(SA1.A1_COD) = 1 " ;
                New Alias (cAls)

            nProx   := IIf(!(cAls)->(Eof()) .And. !Empty((cAls)->MAXCOD), (cAls)->MAXCOD + 1, 1)
            cCodCli := StrZero(nProx, 6)
            cLoja   := "01"
            nOpc    := 3  // Inclusao
        EndIf
        (cAls)->(DbCloseArea())

        // Monta array de dados para MATA030
        AAdd(aDados, {"A1_FILIAL", cFilSA1,                               NIL})
        AAdd(aDados, {"A1_COD",    cCodCli,                               NIL})
        AAdd(aDados, {"A1_LOJA",   cLoja,                                 NIL})
        AAdd(aDados, {"A1_NOME",   fJsonVal(aClientes[nX][3], "Cliente"), NIL})
        AAdd(aDados, {"A1_NREDUZ", fJsonVal(aClientes[nX][3], "Fantasia"),NIL})
        AAdd(aDados, {"A1_PESSOA", fJsonVal(aClientes[nX][3], "Tipofj"),  NIL})
        AAdd(aDados, {"A1_CGC",    cCGC,                                  NIL})
        AAdd(aDados, {"A1_INSCR",  fJsonVal(aClientes[nX][3], "Ieent"),   NIL})
        AAdd(aDados, {"A1_END",    fJsonVal(aClientes[nX][3], "Enderent"),NIL})
        AAdd(aDados, {"A1_BAIRRO", fJsonVal(aClientes[nX][3], "Bairroent"),NIL})
        AAdd(aDados, {"A1_MUN",    fJsonVal(aClientes[nX][3], "Municent"),NIL})
        AAdd(aDados, {"A1_EST",    fJsonVal(aClientes[nX][3], "Estent"),  NIL})
        AAdd(aDados, {"A1_CEP",    fJsonVal(aClientes[nX][3], "Cepent"),  NIL})
        AAdd(aDados, {"A1_CODMUN", fJsonVal(aClientes[nX][3], "Codcidade"),NIL})
        AAdd(aDados, {"A1_TEL",    fJsonVal(aClientes[nX][3], "Telent"),  NIL})
        AAdd(aDados, {"A1_EMAIL",  fJsonVal(aClientes[nX][3], "Email"),   NIL})
        AAdd(aDados, {"A1_TIPO",   "F",                                   NIL})

        // Vendedor - pega ultimos 6 digitos
        cVend := fSoNum(fJsonVal(aClientes[nX][3], "Codusur1"))
        If Len(cVend) > 6
            cVend := Right(cVend, 6)
        ElseIf !Empty(cVend)
            cVend := StrZero(Val(cVend), 6)
        EndIf
        If !Empty(cVend)
            AAdd(aDados, {"A1_VEND", cVend, NIL})
        EndIf

        // Executa MATA030
        Begin Transaction

            MSExecAuto({|x,y| MATA030(x,y)}, aDados, nOpc)

            If lMsErroAuto
                aErros := GetAutoGRLog()
                cCritica := ""
                For nI := 1 To Len(aErros)
                    cCritica += AllTrim(aErros[nI]) + " | "
                Next
                lOk := .F.
                DisarmTransaction()
            Else
                lOk := .T.
            EndIf

        End Transaction

        // Adiciona ao array de status
         If lOk
            AAdd(aStatus, { aClientes[nX][1], aClientes[nX][2], aClientes[nX][3], 4, 2, "Cliente integrado com sucesso.", cCodCli + cLoja })
        Else
            If Empty(cCritica)
                cCritica := "Falha ao integrar cliente (erro nao identificado pelo MSExecAuto)."
            EndIf
            AAdd(aStatus, { aClientes[nX][1], aClientes[nX][2], aClientes[nX][3], 5, 3, cCritica, "" })
        EndIf
    Next

Return aStatus


//fEnviaStatus - Envia status de retorno para API MaxPedido
Static Function fEnviaStatus(cURI, aHeader, aStatus)

    Local oRest  := FwRest():New(cURI)
    Local oJson  := NIL
    Local cJson  := ""
    Local nX     := 0

    For nX := 1 To Len(aStatus)

      
        oJson := JsonObject():New()

        // Atualiza objeto_json com retorno
        aStatus[nX][3]["Codigo"]            := aStatus[nX][7]
        aStatus[nX][3]["CriticaImportacao"] := aStatus[nX][6]
        aStatus[nX][3]["RetornoImportacao"] := aStatus[nX][5]

        oJson["id_cliente"]  := aStatus[nX][1]
        oJson["data"]        := aStatus[nX][2]
        oJson["objeto_json"] := aStatus[nX][3]:ToJson()
        oJson["status"]      := aStatus[nX][4]

        cJson := oJson:ToJson()

        // Envia PUT (JSON como segundo parametro)
        oRest:SetPath("/StatusClientes")

        If oRest:Put(aHeader, cJson)
            ConOut("JOBFVR03 >> Status enviado ID: " + cValToChar(aStatus[nX][1]))
        Else
            ConOut("JOBFVR03 >> Erro ao enviar status ID: " + cValToChar(aStatus[nX][1]) + " - " + oRest:GetLastError())
        EndIf
    Next

    FreeObj(oRest)

Return


//fJsonVal - Busca valor no objeto JSON (case insensitive)
Static Function fJsonVal(oJson, cField)
    Local xValue := ""

    If oJson == NIL .Or. ValType(oJson) <> "O"
        Return ""
    EndIf

    If oJson:HasProperty(cField)
        xValue := oJson[cField]
    ElseIf oJson:HasProperty(Upper(cField))
        xValue := oJson[Upper(cField)]
    ElseIf oJson:HasProperty(Lower(cField))
        xValue := oJson[Lower(cField)]
    EndIf

    If ValType(xValue) != "C"
        xValue := cValToChar(xValue)
    EndIf

Return AllTrim(xValue)


//fSoNum - Extrai somente numeros de uma string
Static Function fSoNum(cStr)
    Local cRet := ""
    Local nPos := 0
    Local cChr := ""

    cStr := AllTrim(cValToChar(cStr))

    For nPos := 1 To Len(cStr)
        cChr := SubStr(cStr, nPos, 1)
        If cChr >= "0" .And. cChr <= "9"
            cRet += cChr
        EndIf
    Next

Return cRet

//Minimiza risco de aspas em SQL dinâmico 
Static Function fSqlEscape(cText)
    cText := cValToChar(cText)
    cText := StrTran(cText, "'", "''")
Return cText
