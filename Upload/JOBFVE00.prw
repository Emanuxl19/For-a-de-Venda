#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE00                                                                          |
 | Descricao  : Remove todas as tabelas de preco no MaxPedido via DELETE /TabelasPrecos/Todos.    |
 | versao     : 1.0                                                                               |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE00()
    Local cURI         := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource    := "/TabelasPrecos/Todos"
    Local oRest        := FwRest():New(cURI)
    Local aHeader      := {}
    Local cBearerToken := U_JOBFVAUT()
    Local lSucesso     := .T.
    Local cAutoEmp     := "06"
    Local cAutoAmb     := "FAT"
    // Vari�veis para captura de resposta HTTP
    Local nCode        := 0
    Local cResult      := ""
    Local cRes         := ""
    Local cErr         := ""

    If Select("SX2") <= 0
        RPCSetEnv(cAutoEmp, , , , cAutoAmb)
    EndIf

    If Empty(cBearerToken)
        ConOut("JOBFVE00 >> Token nao informado. Abortando operacao.")
        Return .F.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath(cResource)

    If oRest:Delete(aHeader)
        // Sucesso: captura e exibe c�digo HTTP (quando num�rico) e resultado
        lSucesso := .T.
    nCode := oRest:GetHTTPCode()
    cResult := AllTrim(oRest:GetResult())
        If ValType(nCode) == "N"
            ConOut("JOBFVE00 >> Todas as tabelas de preco foram removidas no MaxPedido. HTTP: " + Str(nCode))
        Else
            ConOut("JOBFVE00 >> Todas as tabelas de preco foram removidas no MaxPedido.")
        EndIf
        If !Empty(cResult)
            ConOut("JOBFVE00 >> Response: " + cResult)
        EndIf
    Else
        // Falha: informa o body e o erro retornado pela lib
    lSucesso := .F.
    cRes := AllTrim(oRest:GetResult())
    cErr := AllTrim(oRest:GetLastError())
        ConOut("JOBFVE00 >> Erro ao remover tabelas de preco:")
        If !Empty(cRes)
            ConOut(" - Response: " + cRes)
        EndIf
        If !Empty(cErr)
            ConOut(" - Error: " + cErr)
        EndIf
    EndIf

Return lSucesso
