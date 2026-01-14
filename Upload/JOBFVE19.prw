#Include "TOTVS.ch"
#Include "Topconn.ch"

/*------------------------------------------------------------------------------------------------*
 | Data       : 12/12/2025                                                                        |
 | Rotina     : JOBFVE19                                                                          |
 | Responsavel: EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia ProdutosUsuarios para o MaxPedido (endpoint /ProdutosUsuarios).             |
 | Versao     : 1.3 - Correção CODUSUR para usar padrao 0602 + A3_COD (sem A3_FILIAL)             |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE19()

    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource     := "/ProdutosUsuarios"
    Local oRest         := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .F.

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    // Informa o recurso e insere o JSON no corpo
    oRest:SetPath(cResource)
    oRest:SetPostParams(ProdutosUsuariosJson())

    If (oRest:Post(aHeader))
        ConOut("JOBFVE19 >> ProdutosUsuarios enviados com sucesso!")
        ConOut("JOBFVE19 >> HTTP: " + cValToChar(oRest:GetHTTPCode()))
        ConOut("JOBFVE19 >> Response: " + oRest:GetResult())
        lSucesso := .T.
    Else
        ConOut("JOBFVE19 >> Erro ao enviar ProdutosUsuarios:" + CRLF + oRest:GetLastError())
        ConOut("JOBFVE19 >> HTTP: " + cValToChar(oRest:GetHTTPCode()))
        ConOut("JOBFVE19 >> Response: " + oRest:GetResult())
        lSucesso := .F.
    EndIf

Return lSucesso

Static Function ProdutosUsuariosJson()
    Local aBody     := {}
    Local oBody
    Local cJson     := ""
    Local aConfig   := {}
    Local nCfg      := 0
    Local nX        := 1
    Local cTabela   := ""
    Local cGrpEmp   := ""
    Local cEmpresa  := ""
    Local cTpProd   := ""
    Local cCodFilial:= ""
    Local cTabelaVend := ""
    Local cQry      := ""

    // Mesma configuracao da JOBFVE09
    // {Tabela Produto, GrpEmp, Empresa/Filial, Fornecedor, TipoProd, CodSec, Depto}
    AADD(aConfig, {"SB1", "01", "05", "FOR002", "ME", "0002", "2"})  // EMPRESA_EXEMPLO_B
    AADD(aConfig, {"SB1", "06", "02", "FOR001", "PA", "0001", "1"})  // EMPRESA_EXEMPLO_A

    For nCfg := 1 To Len(aConfig)
        cTabela   := aConfig[nCfg][1]
        cGrpEmp   := aConfig[nCfg][2]
        cEmpresa  := aConfig[nCfg][3]
        cTpProd   := aConfig[nCfg][5]

        // Monta codigo da filial: GrpEmp + Empresa (ex: 0602, 0105)
        cCodFilial := Right("00" + AllTrim(cGrpEmp), 2) + Right("00" + AllTrim(cEmpresa), 2)

        // Define tabela de vendedores correspondente
        If cGrpEmp == "06"
            cTabelaVend := "SA3"
        Else
            cTabelaVend := "SA3"
        EndIf

          // verifica se é necessário inicializar o ambiente
        If Select("SX2") <= 0
             RPCSetEnv("06", "02", , , "FAT")
        EndIf

        // Query que cruza TODOS os produtos com TODOS os vendedores da mesma filial
        // CODUSUR = CODFILIAL + A3_COD (ex: 0602000031) - SEM A3_FILIAL no meio
        cQry := ""
        cQry += "SELECT '' AS CODCLI," + CRLF
        cQry += "       PROD.CODPROD," + CRLF
        cQry += "       VND.CODUSUR," + CRLF
        cQry += "       '2025-01-01' AS DATAINICIO," + CRLF
        cQry += "       '2026-12-31' AS DATAFIM," + CRLF
        cQry += "       0 AS QTMAXVENDA," + CRLF
        cQry += "       '" + cCodFilial + "' AS CODFILIAL" + CRLF
        cQry += "  FROM (" + CRLF
        cQry += "        SELECT RTRIM(B1_COD) AS CODPROD" + CRLF
        cQry += "          FROM " + cTabela + " SB1 WITH (NOLOCK)" + CRLF
        cQry += "         WHERE SB1.D_E_L_E_T_ = ' '" + CRLF
        cQry += "           AND SB1.B1_FILIAL  = '" + cEmpresa + "'" + CRLF
        cQry += "           AND SB1.B1_TIPO    = '" + cTpProd + "'" + CRLF
        cQry += "       ) PROD," + CRLF
        cQry += "       (" + CRLF
        //CODUSUR = CODFILIAL + A3_COD (sem A3_FILIAL)
        cQry += "        SELECT '" + cCodFilial + "' + RTRIM(A3_COD) AS CODUSUR" + CRLF
        cQry += "          FROM " + cTabelaVend + " SA3 WITH (NOLOCK)" + CRLF
        cQry += "         WHERE SA3.D_E_L_E_T_ = ' '" + CRLF
        cQry += "           AND SA3.A3_FILIAL LIKE '" + cEmpresa + "%'" + CRLF
        cQry += "       ) VND" + CRLF

        ConOut("JOBFVE19 >> Query ProdutosUsuarios (Filial " + cCodFilial + "):")
        ConOut(cQry)

        TCQuery cQry New Alias 'TABTEMP'

        While ! TABTEMP->(EoF())
            oBody := JsonObject():New()

            oBody["CODCLI"]     := AllTrim(TABTEMP->CODCLI)
            oBody["CODPROD"]    := AllTrim(TABTEMP->CODPROD)
            oBody["CODUSUR"]    := AllTrim(TABTEMP->CODUSUR)
            oBody["DATAINICIO"] := AllTrim(TABTEMP->DATAINICIO)
            oBody["DATAFIM"]    := AllTrim(TABTEMP->DATAFIM)
            oBody["QTMAXVENDA"] := 999999
            oBody["CODFILIAL"]  := AllTrim(TABTEMP->CODFILIAL)
            oBody["CODIGO"]     := nX

            aAdd(aBody, oBody)
            TABTEMP->(DbSkip())
            nX++
        EndDo

        TABTEMP->(DbCloseArea())

    Next nCfg

    ConOut("JOBFVE19 >> Total ProdutosUsuarios: " + cValToChar(Len(aBody)))

    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
Return cJson
