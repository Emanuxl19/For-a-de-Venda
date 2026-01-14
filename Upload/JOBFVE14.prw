#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE14                                                                          |
 | Data       : 14/11/2025                                                                        |
 | Responsável: EMANUEL AZEVEDO                                                                   |
 | Descrição  : Envia as Praças (MXSPRACA) para o MaxPedido                                       |
 |              Importante para o vínculo Cliente -> Tabela de Preço                              |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE14()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest         := FwRest():New(cURI)
    Local cBearerToken  := U_JOBFVAUT()
    Local aPracas       := {}
    Local aHeader       := {}

    If Empty(cBearerToken)
        Return .F.
    EndIf

    aPracas := {}
    
    AAdd(aPracas, { "001", "001", "TABELA EMPRESA_EXEMPLO_B", "A", 0 }) 
    AAdd(aPracas, { "002","002", "TABELA EMPRESA_EXEMPLO_A - VENDA DIRETA", "A", 0 })
    AAdd(aPracas, { "003", "003", "TABELA EMPRESA_EXEMPLO_A - VAREJO", "A", 0 })
    AAdd(aPracas, { "004", "004", "TABELA EMPRESA_EXEMPLO_A - ATACADO", "A", 0 })
    AAdd(aPracas, { "005", "005", "TABELA EMPRESA_EXEMPLO_A - DISTRIBUIDOR", "A", 0 })


    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath("/Pracas")
    oRest:SetPostParams(FWJsonSerialize(MontaJsonPracas(aPracas), .F., .F., .T.))

      If oRest:Post(aHeader)
        Return .T.
    Else
        Return .F.
    EndIf

Static Function MontaJsonPracas(aCfg)
    Local aBody := {}
    Local oPraca
    Local nIdx

    For nIdx := 1 To Len(aCfg)
        oPraca := JsonObject():New()
        oPraca["CODPRACA"] := aCfg[nIdx][1]
        oPraca["NUMREGIAO"]:= aCfg[nIdx][2]
        oPraca["PRACA"]    := aCfg[nIdx][3]
        oPraca["SITUACAO"] := aCfg[nIdx][4]
        oPraca["ROTA"]     := aCfg[nIdx][5]
        AAdd(aBody, oPraca)
    Next
Return aBody
