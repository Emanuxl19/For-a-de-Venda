//Bibliotecas
#Include "TOTVS.ch"

/*-------------------------------------------------------------------------------------------------*
 | Data       : 13/11/2025                                                                         |
 | Rotina     : JOBFVE07                                                                           |
 | Responsável: EMANUEL AZEVEDO                                                                    |
 | Descrição  : Envia Dias Úteis para o MaxPedido.                                                 |
 | versão     : 1.0                                                                                |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVE07(cOper, nAnoIni, nAnoFim)
    Local cURI       := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest      := NIL
    Local aHeader    := {}
    Local cBearer    := ""
    Local lSucesso   := .F.

    // INICIALIZACAO CONDICIONAL - São executa se ambiente não estiver preparado
    If Select("SX2") <= 0
        RPCSetEnv("06", "02", , , "FAT")
    EndIf

    cBearer := U_JOBFVAUT()

    If Empty(cBearer)
        ConOut("JOBFVE07 >> Token vazio. Abortando.")
        Return .F.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearer)

    cOper   := IIf(Empty(cOper), "POST", Upper(AllTrim(cOper)))
    nAnoIni := IIf(ValType(nAnoIni) != "N" .Or. nAnoIni <= 0, Year(Date()), nAnoIni)
    nAnoFim := IIf(ValType(nAnoFim) != "N" .Or. nAnoFim < nAnoIni, nAnoIni + 1, nAnoFim)

    ConOut("JOBFVE07 >> " + cOper + " (" + cValToChar(nAnoIni) + "-" + cValToChar(nAnoFim) + ")")

    oRest := FwRest():New(cURI)

    If cOper == "POST"
        lSucesso := PostDiasUteis(oRest, aHeader, nAnoIni, nAnoFim)
    Else
        lSucesso := GetDiasUteis(oRest, aHeader)
    EndIf

Return lSucesso

Static Function _GetCfg()
    Local aCfg := {}
    // {CODFILMAX}
    AAdd(aCfg, {"0602"})
    AAdd(aCfg, {"0105"})
Return aCfg

Static Function PostDiasUteis(oRest, aHeader, nAnoIni, nAnoFim)
    Local aCfg      := _GetCfg()
    Local aBody     := {}
    Local oBody     := NIL
    Local aDias     := {"31","28","31","30","31","30","31","31","30","31","30","31"}
    Local cCodFil   := ""
    Local cData     := ""
    Local cJson     := ""
    Local dData     := NIL
    Local nFilial   := 0
    Local nAno      := 0
    Local nMes      := 0
    Local nDia      := 0
    Local nDiaSemana := 0
    Local lPosted   := .F.

    For nFilial := 1 To Len(aCfg)
        cCodFil := aCfg[nFilial][1]

        For nAno := nAnoIni To nAnoFim
            // Ano bissexto
            If (nAno % 4 == 0 .And. (nAno % 100 != 0 .Or. nAno % 400 == 0))
                aDias[2] := "29"
            Else
                aDias[2] := "28"
            EndIf

            For nMes := 1 To 12
                For nDia := 1 To Val(aDias[nMes])
                    cData := StrZero(nAno, 4) + "-" + StrZero(nMes, 2) + "-" + StrZero(nDia, 2)
                    dData := CToD(StrZero(nDia, 2) + "/" + StrZero(nMes, 2) + "/" + StrZero(nAno, 4))
                    nDiaSemana := DoW(dData)

                    oBody := JsonObject():New()
                    oBody["CODFILIAL"] := cCodFil
                    oBody["DATA"]      := cData
                    // Sábado (7) e Domingo (1) = Não Úteis ("N")
                    oBody["DIAUTIL"]   := IIf(nDiaSemana >= 2 .And. nDiaSemana <= 6, "S", "N")

                    AAdd(aBody, oBody)
                Next nDia
            Next nMes
        Next nAno
    Next nFilial

    oRest:SetPath("/DiasUteis")
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
    oRest:SetPostParams(cJson)

    ConOut("JOBFVE07 >> Enviando " + cValToChar(Len(aBody)) + " registros para filiais: 0602, 0105")

    lPosted := oRest:Post(aHeader)

    If lPosted
        ConOut("JOBFVE07 >> POST /DiasUteis enviado com sucesso!")
    Else
        ConOut("JOBFVE07 >> ERRO ao enviar /DiasUteis: " + oRest:GetLastError())
    EndIf

Return lPosted

Static Function GetDiasUteis(oRest, aHeader)
    Local lOK := .F.

    oRest:SetPath("/DiasUteis/Todos")
    lOK := oRest:Get(aHeader)

    If lOK
        ConOut("JOBFVE07 >> GET /DiasUteis retornou sucesso.")
    Else
        ConOut("JOBFVE07 >> ERRO ao buscar /DiasUteis: " + oRest:GetLastError())
    EndIf

Return lOK
