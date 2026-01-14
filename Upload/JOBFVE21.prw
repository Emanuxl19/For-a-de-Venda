#include "Totvs.ch"
#include "Topconn.ch"

/*-------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE21                                                                           |
 | Descricao  : Envia/recebe notas de saida com Maxima                                             |
 | Data       : 16/12/2025                                                                         |
 | Responsavel: EMANUEL AZEVEDO                                                                    |     
 | Versao     : 1.1 - Removido campos F2_XINTMX e D2_XINTMX                                        |
 *-------------------------------------------------------------------------------------------------*/

User Function JOBFVE21()
    Local lRet := .T.

    If !EnvNtMax()
        lRet := .F.
    EndIf

    If !BuscNtMax()
        lRet := .F.
    EndIf

Return lRet

Static Function EnvNtMax()
    Local lSuc := .T.

    If !EnvNtCapas()
        lSuc := .F.
    EndIf
    
    If !EnvNtItens()
        lSuc := .F.
    EndIf

Return lSuc

Static Function EnvNtCapas()
    Local cURI    := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest   := FwRest():New(cURI)
    Local aHeader := {}
    Local cJson   := ""
    Local lSuc    := .F.

    cJson := JsonNtCapas()

    If Empty(cJson) .Or. cJson == "[]"
        Return .T.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + U_JOBFVAUT())

    oRest:SetPath("/NotasSaidaCapas")
    oRest:SetPostParams(cJson)

    If oRest:Post(aHeader)
        lSuc := .T.
    EndIf

Return lSuc

Static Function EnvNtItens()
    Local cURI    := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest   := FwRest():New(cURI)
    Local aHeader := {}
    Local cJson   := ""
    Local lSuc    := .F.

    cJson := JsonNtItens()

    If Empty(cJson) .Or. cJson == "[]"
        Return .T.
    EndIf

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + U_JOBFVAUT())

    oRest:SetPath("/NotasSaidaItens")
    oRest:SetPostParams(cJson)

    If oRest:Post(aHeader)
        lSuc := .T.
    EndIf

Return lSuc

Static Function JsonNtCapas()
    Local aBody   := {}
    Local oBody   := NIL
    Local cJson   := ""
    Local aConfig := {}
    Local nCfg    := 0
    Local cTab    := ""
    Local cGrp    := ""
    Local cEmp    := ""
    Local cFilFlt := ""
    Local cFilMp  := ""
    Local cQry    := ""
    Local cAls    := "QNFCAP"
    Local nTrans  := 0

    AAdd(aConfig, {"SF2", "06", "02", "02%"})
    AAdd(aConfig, {"SF2", "01", "05", "05%"})

    For nCfg := 1 To Len(aConfig)
        cTab    := aConfig[nCfg][1]
        cGrp    := aConfig[nCfg][2]
        cEmp    := aConfig[nCfg][3]
        cFilFlt := aConfig[nCfg][4]
        cFilMp  := Right("00" + AllTrim(cGrp), 2) + Right("00" + AllTrim(cEmp), 2)

        cQry := "SELECT "
        cQry += "SF2.R_E_C_N_O_ AS RECNO,"
        cQry += "SF2.F2_FILIAL AS CODFILIAL,"
        cQry += "SF2.F2_DOC AS NUMNOTA,"
        cQry += "SF2.F2_SERIE AS SERIE,"
        cQry += "SF2.F2_CLIENTE AS CODCLI,"
        cQry += "SF2.F2_EMISSAO AS DTSAIDA,"
        cQry += "SF2.F2_VALBRUT AS VLTOTAL,"
        cQry += "SF2.F2_PLIQUI AS TOTPESO,"
        cQry += "SF2.F2_VOLUME1 AS TOTVOLUME,"
        cQry += "SF2.F2_VEND1 AS CODUSUR,"
        cQry += "SF2.F2_TIPO AS TIPO,"
        cQry += "SE4.E4_CODIGO AS CODPLPAG,"
        cQry += "ISNULL(SC5.C5_NUM,'') AS NUMPED,"
        cQry += "ISNULL(SA3.A3_SUPER,'') AS CODSUPERVISOR "
        cQry += "FROM " + cTab + " SF2 WITH(NOLOCK) "
        cQry += "LEFT JOIN SE4" + SubStr(cTab,4,3) + " SE4 WITH(NOLOCK) ON SE4.E4_CODIGO=SF2.F2_COND AND SE4.D_E_L_E_T_=' ' "
        cQry += "LEFT JOIN SC5" + SubStr(cTab,4,3) + " SC5 WITH(NOLOCK) ON SC5.C5_FILIAL=SF2.F2_FILIAL AND SC5.C5_NOTA=SF2.F2_DOC AND SC5.D_E_L_E_T_=' ' "
        cQry += "LEFT JOIN SA3" + SubStr(cTab,4,3) + " SA3 WITH(NOLOCK) ON SA3.A3_COD=SF2.F2_VEND1 AND SA3.D_E_L_E_T_=' ' "
        cQry += "WHERE SF2.D_E_L_E_T_=' ' "
        cQry += "AND SF2.F2_FILIAL LIKE '" + cFilFlt + "' "
        cQry += "AND SF2.F2_EMISSAO>='20250101' "
        cQry += "ORDER BY SF2.F2_EMISSAO,SF2.F2_DOC"

        If Select(cAls) > 0
            (cAls)->(DbCloseArea())
        EndIf

        TCQuery cQry New Alias (cAls)
        (cAls)->(DbGoTop())
        nTrans := 0

        While !(cAls)->(Eof())
            nTrans++
            oBody := JsonObject():New()

            oBody["NUMCAR"]        := ""
            oBody["NUMNOTA"]       := Val(AllTrim((cAls)->NUMNOTA))
            oBody["SERIE"]         := AllTrim((cAls)->SERIE)
            oBody["CODUSUR"]       := AllTrim((cAls)->CODUSUR)
            oBody["CONDVENDA"]     := ConvCondVd((cAls)->TIPO)
            oBody["NUMTRANSVENDA"] := nTrans
            oBody["DTSAIDA"]       := FmtData((cAls)->DTSAIDA)
            oBody["DTFAT"]         := FmtData((cAls)->DTSAIDA)
            oBody["DTENTREGA"]     := FmtData((cAls)->DTSAIDA)
            oBody["DTCANCEL"]      := NIL
            oBody["VLTOTAL"]       := (cAls)->VLTOTAL
            oBody["ESPECIE"]       := "NF"
            oBody["CODCLI"]        := AllTrim((cAls)->CODCLI)
            oBody["NUMPED"]        := Val(AllTrim((cAls)->NUMPED))
            oBody["CODCOB"]        := ""
            oBody["CODPLPAG"]      := AllTrim((cAls)->CODPLPAG)
            oBody["CODFILIAL"]     := cFilMp
            oBody["NUMSEQ"]        := 0
            oBody["TOTPESO"]       := (cAls)->TOTPESO
            oBody["COMISSAO"]      := 0
            oBody["TOTVOLUME"]     := (cAls)->TOTVOLUME
            oBody["CODSUPERVISOR"] := AllTrim((cAls)->CODSUPERVISOR)

            AAdd(aBody, oBody)
            (cAls)->(DbSkip())
        EndDo

        If Select(cAls) > 0
            (cAls)->(DbCloseArea())
        EndIf
    Next nCfg

    If Len(aBody) > 0
        cJson := FWJsonSerialize(aBody)
    Else
        cJson := "[]"
    EndIf

Return cJson

Static Function JsonNtItens()
    Local aBody   := {}
    Local oBody   := NIL
    Local cJson   := ""
    Local aConfig := {}
    Local nCfg    := 0
    Local cTabD2  := ""
    Local cTabF2  := ""
    Local cFilFlt := ""
    Local cQry    := ""
    Local cAls    := "QNFITM"
    Local nTrans  := 0

    AAdd(aConfig, {"SD2", "SF2", "02%"})
    AAdd(aConfig, {"SD2", "SF2", "05%"})

    For nCfg := 1 To Len(aConfig)
        cTabD2  := aConfig[nCfg][1]
        cTabF2  := aConfig[nCfg][2]
        cFilFlt := aConfig[nCfg][3]

        cQry := "SELECT "
        cQry += "SD2.R_E_C_N_O_ AS RECNO,"
        cQry += "SD2.D2_DOC AS NUMNOTA,"
        cQry += "SD2.D2_COD AS CODPROD,"
        cQry += "SD2.D2_TES AS CODOPER,"
        cQry += "SD2.D2_QUANT AS QT,"
        cQry += "SD2.D2_ITEM AS NUMSEQ,"
        cQry += "SD2.D2_PRCVEN AS PTABELA,"
        cQry += "SD2.D2_CUSTO1 AS CUSTOFIN,"
        cQry += "SD2.D2_VALIPI AS VLIPI,"
        cQry += "SD2.D2_ICMSRET AS ST,"
        cQry += "ISNULL(SB1.B1_CODBAR,'') AS CODAUXILIAR,"
        cQry += "ISNULL(SD2.D2_PEDIDO,'') AS NUMPED "
        cQry += "FROM " + cTabD2 + " SD2 WITH(NOLOCK) "
        cQry += "INNER JOIN " + cTabF2 + " SF2 WITH(NOLOCK) ON SF2.F2_FILIAL=SD2.D2_FILIAL AND SF2.F2_DOC=SD2.D2_DOC AND SF2.F2_SERIE=SD2.D2_SERIE AND SF2.D_E_L_E_T_=' ' "
        cQry += "LEFT JOIN SB1" + SubStr(cTabD2,4,3) + " SB1 WITH(NOLOCK) ON SB1.B1_COD=SD2.D2_COD AND SB1.D_E_L_E_T_=' ' "
        cQry += "WHERE SD2.D_E_L_E_T_=' ' "
        cQry += "AND SD2.D2_FILIAL LIKE '" + cFilFlt + "' "
        cQry += "AND SD2.D2_EMISSAO>='20250101' "
        cQry += "ORDER BY SD2.D2_DOC,SD2.D2_ITEM"

        If Select(cAls) > 0
            (cAls)->(DbCloseArea())
        EndIf

        TCQuery cQry New Alias (cAls)
        (cAls)->(DbGoTop())
        nTrans := 0

        While !(cAls)->(Eof())
            nTrans++
            oBody := JsonObject():New()

            oBody["CODPROD"]       := AllTrim((cAls)->CODPROD)
            oBody["CODOPER"]       := AllTrim((cAls)->CODOPER)
            oBody["QT"]            := (cAls)->QT
            oBody["NUMSEQ"]        := Val(AllTrim((cAls)->NUMSEQ))
            oBody["QTCONT"]        := (cAls)->QT
            oBody["NUMTRANSVENDA"] := 0
            oBody["NUMTRANSITEM"]  := nTrans
            oBody["CODAUXILIAR"]   := AllTrim((cAls)->CODAUXILIAR)
            oBody["NUMCAR"]        := ""
            oBody["NUMNOTA"]       := Val(AllTrim((cAls)->NUMNOTA))
            oBody["NUMPED"]        := Val(AllTrim((cAls)->NUMPED))
            oBody["PTABELA"]       := (cAls)->PTABELA
            oBody["PUNITCONT"]     := (cAls)->PTABELA
            oBody["PUNIT"]         := (cAls)->PTABELA
            oBody["CUSTOFIN"]      := (cAls)->CUSTOFIN
            oBody["VLIPI"]         := (cAls)->VLIPI
            oBody["ST"]            := (cAls)->ST

            AAdd(aBody, oBody)
            (cAls)->(DbSkip())
        EndDo

        If Select(cAls) > 0
            (cAls)->(DbCloseArea())
        EndIf
    Next nCfg

    If Len(aBody) > 0
        cJson := FWJsonSerialize(aBody)
    Else
        cJson := "[]"
    EndIf

Return cJson

Static Function BuscNtMax()
    Local cURI    := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest   := FwRest():New(cURI)
    Local aHeader := {}
    Local cResult := ""
    Local oJson   := NIL
    Local nI      := 0

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + U_JOBFVAUT())

    oRest:SetPath("/NotasSaidaCapas?pendente=true")

    If oRest:Get(aHeader)
        cResult := oRest:GetResult()
        If !Empty(cResult) .And. cResult <> "[]"
            oJson := JsonObject():New()
            oJson:FromJson(cResult)
            If ValType(oJson) == "A"
                For nI := 1 To Len(oJson)
                    ProcNtMax(oJson[nI])
                Next nI
            EndIf
        EndIf
    EndIf

Return .T.

Static Function ProcNtMax(oNota)
    Local cNumNota := oNota["NUMNOTA"]
    Local cSerie   := oNota["SERIE"]
    Local cFil     := oNota["CODFILIAL"]
    Local lExiste  := .F.

    lExiste := ExisteNtSF2(cFil, cNumNota, cSerie)

    If !lExiste
        // TODO: Criar NF via MATA460
    EndIf

Return .T.

Static Function ExisteNtSF2(cFil, cNumNota, cSerie)
    Local cQry    := ""
    Local cAls    := "QEXIST"
    Local cTabSF2 := ""
    Local cFilFlt := SubStr(AllTrim(cFil),3,2) + "%"
    Local lExiste := .F.

    If SubStr(AllTrim(cFil),1,2) == "06"
        cTabSF2 := "SF2"
    Else
        cTabSF2 := "SF2"
    EndIf

    cQry := "SELECT 1 FROM " + cTabSF2 + " SF2 WITH(NOLOCK) "
    cQry += "WHERE SF2.F2_FILIAL LIKE '" + cFilFlt + "' "
    cQry += "AND SF2.F2_DOC='" + cNumNota + "' "
    cQry += "AND SF2.F2_SERIE='" + cSerie + "' "
    cQry += "AND SF2.D_E_L_E_T_=' '"

    If Select(cAls) > 0
        (cAls)->(DbCloseArea())
    EndIf

    TCQuery cQry New Alias (cAls)
    lExiste := !(cAls)->(Eof())
    (cAls)->(DbCloseArea())

Return lExiste

Static Function ConvCondVd(cTipo)
    Local nCond := 1

    Do Case
        Case cTipo == "N"
            nCond := 1
        Case cTipo == "D"
            nCond := 11
        Case cTipo == "B"
            nCond := 5
        Otherwise
            nCond := 1
    EndCase

Return nCond

Static Function FmtData(cData)
    Local cRet := ""

    If !Empty(cData) .And. Len(cData) >= 8
        cRet := SubStr(cData,1,4) + "-" + SubStr(cData,5,2) + "-" + SubStr(cData,7,2)
    EndIf

Return cRet
