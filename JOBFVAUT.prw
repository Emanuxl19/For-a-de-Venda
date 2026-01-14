#Include "TOTVS.ch"
 
/*-------------------------------------------------------------------------------------------------*
 | Data       : 07/11//2025                                                                        |
 | Rotina     : JOBFVAUT                                                                           |
 | Responsável: EMANUEL AZEVEDO                                                                    |
 | Descriçao  : Rotina para autenticação e captura do token de acesso do sistema MaxPedido.        | 
 |                                                                                                 |
 | versãoo    : 1.0                                                                                |
 | Histórico  :                                                                                    | 
 *------------------------------------------------------------------------------------------------*/


 
User Function JOBFVAUT()
    Local cUsrLogin     := "LOGIN_DE_USUARIO"          // Configurar com seu login da API
    Local cUsrSenha     := "SENHA_DO_USUARIO"          // Configurar com sua senha da API
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource := "/Login"                  // RECURSO A SER CONSUMIDO
    Local oRest     := FwRest():New(cURI)                            // CLIENTE PARA CONSUMO REST
    Local aHeader   := {}   
    Local cToken := ""   
    Local jResultado
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")

    // INFORMA O RECURSO E INSERE O JSON NO CORPO (BODY) DA REQUISIï¿½ï¿½O
    oRest:SetPath(cResource)
    oRest:SetPostParams(AutJson(cUsrLogin, cUsrSenha))

    // REALIZA O MéTODO POST E VALIDA O RETORNO
    If (oRest:Post(aHeader))
        jResultado := JsonObject():New()
        jResultado:FromJson(oRest:cResult)

        // Alguns ambientes retornam campos com variação na grafia; tenta todas as opições conhecidas
        cToken := jResultado:GetJsonObject("token_De_Acesso")
        If Empty(cToken)
            cToken := jResultado:GetJsonObject("token_de_acesso")
        EndIf
        If Empty(cToken)
            cToken := jResultado:GetJsonObject("token")
        EndIf
    Else
        cToken := "Error"
    EndIf
    if Empty(cToken) .and. jResultado != Nil
    Endif
Return cToken


// CRIA O JSON QUE SERÍA ENVIADO NO CORPO (BODY) DA REQUISIÇÃO
Static Function AutJson(cLogin,cPassword)
    Local bObject       := {|| JsonObject():New()}
    Local oJson         := Eval(bObject)
    oJson["login"]      := cLogin
    oJson["password"]   := cPassword
Return (oJson:ToJson())
