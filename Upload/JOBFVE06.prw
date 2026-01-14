#Include "TOTVS.ch"
#Include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE06                                                                          |
 | DaTA:       08/11/2025                                                                         |
 | Autor      : EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia Secoes, responsavel por armazenar informacoes de secao no MaxPedido         |
 |              (agrupamento de produtos).                                                        |
 | versao     : 1.0                                                                               |
 *------------------------------------------------------------------------------------------------*/


User Function JOBFVE06()
    Local cURI         := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest        := FwRest():New(cURI)
    Local aHeader      := {}
    Local cBearerToken := U_JOBFVAUT()
    Local lSucesso     := .F.
    Local cAutoEmp     := "06"
    Local cAutoAmb     := "FAT"
    Local nQtSecao     := 0
    Local aPayload     := {}
    Local cJsonSecao   := ""

    If Select("SX2") <= 0
        RPCSetEnv(cAutoEmp, , , , cAutoAmb)
    EndIf
    If Empty(cBearerToken)
        ConOut("JOBFVE06 >> Token nao informado. Abortando envio.")
        Return .F.
    EndIf

    aPayload   := SecoesPayload()
    cJsonSecao := aPayload[1]
    nQtSecao   := aPayload[2]

    If nQtSecao == 0
        ConOut("JOBFVE06 >> Nenhuma secao encontrada para envio.")
        Return .T.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath("/Secoes")
    // monta post e envia
    oRest:SetPostParams(cJsonSecao)

    If (oRest:Post(aHeader))
        ConOut("JOBFVE06 >> /Secoes atualizadas com sucesso (" + cValToChar(nQtSecao) + " registros).")
        lSucesso := .T.
    Else
        ConOut("JOBFVE06 >> Erro ao enviar /Secoes: " + CRLF + oRest:GetLastError())
    EndIf

Return lSucesso


// Monta o payload de secoes a partir de uma lista estática (não usa DB)
Static Function SecoesPayload()
    Local aBody    := {}
    Local aRet     := {}
    Local cJson    := ""
    Local nQtSecao := 0

    // Fonte estática baseada no print fornecido
    // Cada entrada: { CODSEC, CODEPTO, DESCRICAO }
    Local aSections := {}
    AAdd(aSections, { "0001", "1", "EMPRESA_EXEMPLO_A DA REGIAO_EXEMPLO INDUSTRIA LTDA" })
    AAdd(aSections, { "0002", "2", "EMPRESA_EXEMPLO_B" })

    Local nIdx := 0
    Local oBody := NIL

    For nIdx := 1 To Len(aSections)
        oBody := JsonObject():New()
        oBody["CODSEC"]    := aSections[nIdx][1]
        oBody["CODEPTO"]   := aSections[nIdx][2]
        oBody["DESCRICAO"] := aSections[nIdx][3]
        oBody["STATUS"]    := "A"
        AAdd(aBody, oBody)
    Next nIdx

    nQtSecao := Len(aBody)

    If nQtSecao > 0
        cJson := FWJsonSerialize(aBody, .F., .F., .T.)
    EndIf

    AAdd(aRet, cJson)
    AAdd(aRet, nQtSecao)

Return aRet


// Regra de mapeamento de grupo (B1_GRUPO) para CODSEC no MaxPedido.
Static Function GetCodSecValid(cGrupo)
    Local cKey      := AllTrim(cGrupo)
    Local cParam    := ""
    Local cCodSec   := ""
    Local cAutoEmp  := "06"
    Local cAutoAmb  := "FAT"

    If Empty(cKey)
        Return ""
    EndIf

    cParam := "MV_MPSEC" + Right("0000" + cKey, 4)

    If Select("SX6") <= 0
        RPCSetEnv(cAutoEmp, , , , cAutoAmb)
    EndIf

    DbSelectArea("SX6")
    DbSetOrder(1) // X6_FILIAL + X6_VAR

    If DbSeek(Space(6) + cParam)
        cCodSec := AllTrim(SX6->X6_CONTEUD)
    EndIf

    If Empty(cCodSec)
        ConOut("JOBFVE06 >> CODSEC nao mapeado para grupo " + cKey + ;
               " (parametro " + cParam + "). Secao nao sera enviada.")
    EndIf

Return cCodSec
