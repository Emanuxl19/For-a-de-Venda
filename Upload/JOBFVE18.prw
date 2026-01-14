#include "Totvs.ch"
#include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE18                                                                          |
 | Data       : 10/12/2025                                                                        |
 | Autor      : EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia MotivosNaoCompra e MotivosVisita para o MaxPedido via POST (payload fixo).  |
 | versao     : 1.1 - Removida leitura de BD, incluidos motivos genericos                         |
 *-------------------------------------------------------------------------------------------------*/

User Function JOBFVE18()

    Local cURI         := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRestNao     := FwRest():New(cURI)
    Local oRestVis     := FwRest():New(cURI)
    Local aHeader      := {}
    Local cBearerToken := U_JOBFVAUT()
    Local lSucesso     := .T.

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    // Motivos de Nao Compra
    oRestNao:SetPath("/MotivosNaoCompra")
    oRestNao:SetPostParams(MotivosNaoCompraJson())

    If (oRestNao:Post(aHeader))
        lSucesso := .T.
    Else
        lSucesso := .F.
    EndIf

    // Motivos de Visita
    oRestVis:SetPath("/MotivosVisita")
    oRestVis:SetPostParams(MotivosVisitaJson())

    If (oRestVis:Post(aHeader))
        lSucesso := .T.
    Else
        lSucesso := .F.
    EndIf

Return lSucesso


// Motivos genericos para "porta a porta" de nao compra
Static Function MotivosNaoCompraJson()
    Local aBody := {}
    Local aMot  := {{ 101, "Sem decisor presente" },{ 102, "Preferiu concorrente" },{ 103, "Sem necessidade no momento" },{ 104, "Preco considerado alto" },{ 105, "Cliente indisponivel/sem tempo" }}
    Local nI := 0
    Local oRow := NIL

    For nI := 1 To Len(aMot)
        oRow := JsonObject():New()
        oRow["CODMOTIVO"] := aMot[nI][1]
        oRow["DESCRICAO"] := aMot[nI][2]
        AAdd(aBody, oRow)
    Next nI

Return FWJsonSerialize(aBody, .F., .F., .T.)


// Motivos genericos de visita (solicitacao, preferencia presencial, etc.)
Static Function MotivosVisitaJson()
    Local aBody := {}
    Local aMot  := {{ 201, "Solicitacao do cliente" },{ 202, "Apresentacao de novidades" },{ 203, "Resolucao de pendencias/cobranca" },{ 204, "Entrega ou coleta de material" },{ 205, "Cliente prefere atendimento presencial" }}
    Local nI := 0
    Local oRow := NIL

    For nI := 1 To Len(aMot)
        oRow := JsonObject():New()
        oRow["CODMOTIVO"] := aMot[nI][1]
        oRow["DESCRICAO"] := aMot[nI][2]
        AAdd(aBody, oRow)
    Next nI

Return FWJsonSerialize(aBody, .F., .F., .T.)
