#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE12                                                                          |
 | Data       : 14/11/2025                                                                        |
 | Responsável: EMANUEL AZEVEDO                                                                   |
 | Descrição  : Envia as Regiões (MXSREGIAO) para o MaxPedido                                     |
 *------------------------------------------------------------------------------------------------*/
 
User Function JOBFVE12()
	Local cURI         := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
	Local oRest        := FwRest():New(cURI)
	Local aHeader      := {}
	Local cBearerToken := U_JOBFVAUT()
	Local aRegioes     := {}

	If Empty(cBearerToken)
		Return .F.
	EndIf

	aRegioes := {}
    
	AAdd(aRegioes, { "001", "TABELA EMPRESA_EXEMPLO_B", "A", "0105" })
    AAdd(aRegioes, { "002", "TABELA EMPRESA_EXEMPLO_A - VENDA DIRETA", "A", "0602" })
    AAdd(aRegioes, { "003", "TABELA EMPRESA_EXEMPLO_A - VAREJO", "A", "0602" })
	AAdd(aRegioes, { "004", "TABELA EMPRESA_EXEMPLO_A - ATACADO", "A", "0602" })
	AAdd(aRegioes, { "005", "TABELA EMPRESA_EXEMPLO_A - DISTRIBUIDOR", "A", "0602" })

	AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
	AAdd(aHeader, "Accept: application/json")
	AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
	AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

	oRest:SetPath("/Regioes")
	oRest:SetPostParams(FWJsonSerialize(MontaJsonRegioes(aRegioes), .F., .F., .T.))

	  If oRest:Post(aHeader)
        Return .T.
    Else
        Return .F.
    EndIf
Return .F.

Static Function MontaJsonRegioes(aConfig)
	Local aBody   := {}
	Local oReg    := NIL
    Local nIdx    := 0

	For nIdx := 1 To Len(aConfig)
		oReg := JsonObject():New()
		oReg["NUMREGIAO"] := aConfig[nIdx][1]
		oReg["REGIAO"]    := aConfig[nIdx][2]
		oReg["STATUS"]    := aConfig[nIdx][3]
		oReg["CODFILIAL"] := aConfig[nIdx][4]
		AAdd(aBody, oReg)
	Next
Return aBody
