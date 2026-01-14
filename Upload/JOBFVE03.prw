//Bibliotecas
#Include "TOTVS.ch"
#Include "Topconn.ch"
 
/*-------------------------------------------------------------------------------------------------*
 | Data       : 08/11//2025                                                                        |
 | Rotina     : JOBFVE03                                                                           |
 | Responsável: EMANUEL AZEVEDO                                                                    |
 | Descrição  : Rotina para do Endpointno método POST dos Cidades para o  sistema MaxPedido.       | 
 |                                                                                                 |
 | versão     : 1.0                                                                                |
 | Histórico  :                                                                                    | 
 *------------------------------------------------------------------------------------------------*/

 
User Function JOBFVE03()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource     := "/Cidades"
    Local oRest         := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .F.
    
    Local cAutoEmp  := "06"
    Local cAutoAmb  := "FAT"
 
    //Se o dicionário não estiver aberto, irá preparar o ambiente
    If Select("SX2") <= 0
        RPCSetEnv(cAutoEmp, , , , cAutoAmb)
    EndIf

    // Headers com Bearer Token (IGUAL AO THUNDER CLIENT)
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)
    
    // Informa o recurso e insere o JSON dos departamentos no corpo
    oRest:SetPath(cResource)
    oRest:SetPostParams(DeptosJson())
    
    // Realiza o POST e valida o retorno
    If (oRest:Post(aHeader))
        ConOut("Cidades criados com sucesso!")
        lSucesso := .T.
    Else
        ConOut("Erro ao enviar Cidades:" + CRLF + oRest:GetLastError())
        lSucesso := .F.
    EndIf
    
Return lSucesso
    


// CRIA O JSON COM ARRAY DE DEPARTAMENTOS (FORMATO THUNDER CLIENT)
Static Function DeptosJson()
    Local aBody := {}
    Local oBody
    Local cJson := ""
    Local cQry := ""

    cQry := " SELECT CC2_CODMUN,CC2_MUN,CC2_EST " + CRLF
    cQry += " FROM " + RetSQLName("CC2") + " CC2" + CRLF
    cQry += " WHERE CC2.D_E_L_E_T_ = ''" + CRLF
    cQry += "   AND CC2_EST IN ('AC','AP','AM','PA','RO','RR','TO')" + CRLF
    //Efetua a busca dos registros
 
    TCQuery cQry New Alias 'TABTEMP'

    While ! TABTEMP->(EoF())
        oBody := JsonObject():New()
        oBody["codcidade"]   := TABTEMP->CC2_CODMUN
        oBody["codibge"] := TABTEMP->CC2_CODMUN
        oBody["nomecidade"] := TABTEMP->CC2_MUN
        oBody["uf"] := TABTEMP->CC2_EST
        aAdd(aBody, oBody)
        TABTEMP->(DbSkip())
    EndDo

    TABTEMP->(DbCloseArea())

    
    
    // Serializa o array para JSON (usa FWJsonSerialize)
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
    
Return cJson
