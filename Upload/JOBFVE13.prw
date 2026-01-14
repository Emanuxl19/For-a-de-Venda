#Include "TOTVS.ch"
#Include "TopConn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE13                                                                          |
 | Data       : 14/11/2025                                                                        |
 | Responsável: EMANUEL AZEVEDO                                                                   |
 | Descricao  : Envia as tributacoes (MXSTRIBUT) para o MaxPedido via endpoint /Tributos.         |
 | Versao     : 1.0                                                                               |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE13()
    Local cURI          := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local cResource     := "/Tributos"
    Local oRest         := FwRest():New(cURI)
    Local aHeader       := {}
    Local cBearerToken  := U_JOBFVAUT()
    Local lSucesso      := .F.
    Local cAutoEmp      := "06"
    Local cAutoAmb      := "FAT"
    Local cJsonTrib     := ""

    If Select("SX2") <= 0
        RPCSetEnv(cAutoEmp, , , , cAutoAmb)
    EndIf

    cJsonTrib := TributosJson()

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)

    oRest:SetPath(cResource)
    oRest:SetPostParams(cJsonTrib)

    If (oRest:Post(aHeader))
        ConOut("[JOBFVE13] Tributos enviados com sucesso!")
        ConOut("[JOBFVE13] HTTP: " + cValToChar(oRest:GetHTTPCode()))
        ConOut("[JOBFVE13] Response: " + oRest:GetResult())
        lSucesso := .T.
    Else
        ConOut("[JOBFVE13] Erro ao enviar Tributos:")
        ConOut("[JOBFVE13] " + oRest:GetLastError())
        ConOut("[JOBFVE13] HTTP: " + cValToChar(oRest:GetHTTPCode()))
        ConOut("[JOBFVE13] Response: " + oRest:GetResult())
    EndIf

Return lSucesso

Static Function TributosJson()
    Local aBody := {}
    Local oBody := JsonObject():New()

    // Campos chave/obrigatorios
    oBody["CODST"]                        := "1"      // codigo da figura tributaria
    oBody["ALIQICMS1"]                    := 17.00     // aliquota ICMS 1 (obrigatorio)
    oBody["SITTRIBUT"]                    := "000"    // situacao tributaria geral (obrigatorio)
    oBody["SITTRIBUTPF"]                  := "000"    // situacao tributaria PF (obrigatorio)
    oBody["CODFISCALVENDAPRONTAENT"]      := "5904"   // CFOP venda pronta entrega (obrigatorio se pronta entrega)
    oBody["CODFISCALVENDAPRONTAENTINTER"] := "0"      // CFOP pronta entrega interestadual (obrigatorio se houver)
    oBody["CODFISCALBONIFIC"]             := "6904"   // CFOP bonificacao intra
    oBody["CODFISCALBONIFICINTER"]        := "0"      // CFOP bonificacao interestadual

    // Campos adicionais/optionais mapeados pela documentacao
    oBody["AGREGARIPICALCULOST"]          := "N"
    oBody["ALIQICMS1FONTE"]               := 0
    oBody["ALIQICMS2"]                    := 17.00
    oBody["ALIQICMS2FONTE"]               := 17.00
    oBody["ALIQICMSFECP"]                 := 0
    oBody["IVA"]                          := 0
    oBody["IVAFONTE"]                     := 0
    oBody["FORMULAPVENDA"]                := ""
    oBody["UTILIZAMOTORCALCULO"]          := "N"

    // Demais campos opcionais enviados em branco/zero para evitar rejeicao por falta de chave
    oBody["CODICM"]                        := ""
    oBody["CODICMPF"]                      := ""
    oBody["CODICMPRODURAL"]                := ""
    oBody["CODICMTAB"]                     := ""
    oBody["CODICMTABPF"]                   := ""
    oBody["FIGURAPARTILHA"]                := ""
    oBody["MOSTRARPVENDASEMPI"]            := "N"
    oBody["MOSTRAPREVENDASEMPJ"]           := "N"
    oBody["OBS"]                           := "Tributos MaxPedido"
    oBody["PAUTA"]                         := 0
    oBody["PERACRESCIMOFUNCEP"]            := 0
    oBody["PERACRESCIMOPF"]                := 0
    oBody["PERACRESCIMOPJ"]                := 0
    oBody["PERBASEICMS"]                   := 0
    oBody["PERBASECONSUMIDOR"]             := 0
    oBody["PERBASEREDST"]                  := 0
    oBody["PERBASEREDSTPF"]                := 0
    oBody["PERBASEREDSTPJ"]                := 0
    oBody["PERDECSCOFINS"]                 := 0
    oBody["PERDECSCPIS"]                   := 0
    oBody["PERCRPVDASIMPLESNAC"]           := 0
    oBody["PERDESCSIMENCAO"]               := 0
    oBody["PERDECSPSUFARMA"]               := 0
    oBody["PERDESCPASSE"]                  := 0
    oBody["PERDECSUFARMA"]                 := 0
    oBody["PERDIFERIMENTOICMS"]            := 0
    oBody["RIOLOGISERMOST"]                := ""
    oBody["USAVALORULTENTBASEST"]          := "N"
    oBody["USAVALORULTENTBASEST2"]         := "N"
    oBody["USAVALORULTENTMEIODABASEST"]    := "N"
    oBody["UTILIZAPERCBASEST"]             := "N"

    AAdd(aBody, oBody)

Return FWJsonSerialize(aBody, .F., .F., .T.)
