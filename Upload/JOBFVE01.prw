//Bibliotecas
#Include "TOTVS.ch"
 
/*-------------------------------------------------------------------------------------------------*
 | Data       : 07/11//2025                                                                        |
 | Rotina     : JOBFVE01                                                                           |
 | Responsável: EMANUEL AZEVEDO                                                                    |
 | Descrição  : Rotina para do Endpoint no método POST dos Departamentos para o  sistema MaxPedido.| 
 | versão     : 1.0                                                                                |
 | Histórico  :                                                                                    | 
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE01()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource     := "/Departamentos"
    Local oRest         := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .F.
    
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath(cResource)
    oRest:SetPostParams(DeptosJson())

    If (oRest:Post(aHeader))
        ConOut("Departamentos criados com sucesso!")
        lSucesso := .T.
    Else
        ConOut("Erro ao enviar departamentos:" + CRLF + oRest:GetLastError())
        lSucesso := .F.
    EndIf
    
Return lSucesso
    
Static Function DeptosJson()
    Local aDepartamentos := {}
    Local oDepto
    Local cJson := ""
    
    oDepto := JsonObject():New()
    oDepto["codepto"]   := "1"
    oDepto["descricao"] := "EMPRESA_EXEMPLO_A DA REGIAO_EXEMPLO INDUSTRIA LTDA"
    aAdd(aDepartamentos, oDepto)
    
    oDepto := JsonObject():New()
    oDepto["codepto"]   := "2"
    oDepto["descricao"] := "EMPRESA_EXEMPLO_B"
    aAdd(aDepartamentos, oDepto)
    
    cJson := FWJsonSerialize(aDepartamentos, .F., .F., .T.)
    
Return cJson

