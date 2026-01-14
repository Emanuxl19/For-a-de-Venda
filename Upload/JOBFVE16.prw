#include "Totvs.ch"
#include "Topconn.ch"
/*------------------------------------------------------------------------------------------------------------------------------*
 | Rotina     : JOBFVE16                                                                                                        |
 | Data       : 03/12/2025                                                                                                      |
 | Autor      : EMANUEL AZEVEDO                                                                                                 |
 | Descricao  : Respons�vel por armazenar os t�tulos financeiros em abertos ou fechados dos clientes que o vendedor atende      |
 |              (MXPREST) para o MaxPedido via POST.                                                                            |
 | versao     : 1.0                                                                                                             |
 *------------------------------------------------------------------------------------------------------------------------------*/

User Function JOBFVE16()

    Local cURI := "URL_DA_MAXIMA_SOLUCOES" // Configurar com a URL da API MaxPedido
    Local oRest := FwRest():New(cURI)
    Local aHeader := {}
    Local cBearerToken := U_JOBFVAUT()
    Local lSucesso := .T.

    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    AAdd(aHeader, "Authorization: Bearer " + cBearerToken)
    oRest:SetPath("/PrestacoesTitulos")
    oRest:SetPostParams(PrestacoesTitulosJson())

        If (oRest:Post(aHeader))
    Else
        lSucesso := .F.
    EndIf
Return lSucesso

Static Function PrestacoesTitulosJson()
    Local aBody     := {}
    Local oBody     := NIL
    Local cJson     := ""
    Local aConfig   := {}
    Local nCfg      := 0
    Local cTabela   := ""
    Local cGrpEmp   := ""
    Local cEmpresa  := ""
    Local cCodFilial:= ""
    Local cQry      := ""
    Local nNumTrans := 0

    Local cTabSE1_1 := ""
    Local cTabSE1_2 := ""

    // Primeira empresa (01-05) - EMPRESA_EXEMPLO_B
    RPCSetEnv("01", "05", , , "FAT")
    cTabSE1_1 := RetSqlName("SE1")

    // Segunda empresa (06-02) - EMPRESA_EXEMPLO_A
    RPCSetEnv("06", "02", , , "FAT")
    cTabSE1_2 := RetSqlName("SE1")

    AADD(aConfig, {cTabSE1_1, "01", "05"})  // EMPRESA_EXEMPLO_B
    AADD(aConfig, {cTabSE1_2, "06", "02"})  // EMPRESA_EXEMPLO_A

    For nCfg      := 1 To Len(aConfig)
        cTabela   := aConfig[nCfg][1]
        cGrpEmp   := aConfig[nCfg][2]
        cEmpresa  := aConfig[nCfg][3]

        cCodFilial := Right("00" + AllTrim(cGrpEmp), 2) + Right("00" + AllTrim(cEmpresa), 2)

        cQry := ""
                cQry += "SELECT " + CRLF
        cQry += "       SE1.R_E_C_N_O_ AS RECNO," + CRLF
        cQry += "       SE1.E1_FILIAL," + CRLF
        cQry += "       SE1.E1_PREFIXO," + CRLF
        cQry += "       SE1.E1_NUM," + CRLF
        cQry += "       SE1.E1_PARCELA," + CRLF
        cQry += "       SE1.E1_TIPO," + CRLF
        cQry += "       SE1.E1_CLIENTE," + CRLF
        cQry += "       SE1.E1_LOJA," + CRLF
        cQry += "       SE1.E1_NOMCLI," + CRLF
        cQry += "       SE1.E1_PORTADO," + CRLF
        cQry += "       SE1.E1_AGEDEP," + CRLF
        cQry += "       SE1.E1_VALOR," + CRLF
        cQry += "       SE1.E1_SALDO," + CRLF
        cQry += "       SE1.E1_EMISSAO," + CRLF
        cQry += "       SE1.E1_VENCTO," + CRLF
        cQry += "       SE1.E1_VENCORI," + CRLF
        cQry += "       SE1.E1_VENCREA," + CRLF
        cQry += "       SE1.E1_STATUS," + CRLF
        cQry += "       SE1.E1_SITUACA," + CRLF
        cQry += "       SE1.E1_VEND1," + CRLF
        cQry += "       SE1.E1_NUMBCO," + CRLF
        cQry += "       SE1.E1_CODBAR," + CRLF
        cQry += "       SE1.E1_CODDIG," + CRLF
        cQry += "       SE1.E1_DESCONT," + CRLF
        cQry += "       SE1.E1_VALLIQ," + CRLF
        cQry += "       SE1.E1_MULTA," + CRLF
        cQry += "       SE1.E1_JUROS," + CRLF
        cQry += "       SE1.E1_COMIS1," + CRLF
        cQry += "       SE1.E1_VALCOM1," + CRLF
        cQry += "       SE1.E1_BAIXA," + CRLF
        cQry += "       SE1.E1_BOLETO," + CRLF
        cQry += "       '" + cCodFilial + "' AS CODFILIAL," + CRLF
        cQry += "       '" + cGrpEmp + "' AS GRPEMP" + CRLF
        cQry += "  FROM " + cTabela + " SE1 WITH (NOLOCK)" + CRLF
        cQry += " WHERE SE1.D_E_L_E_T_ = ' '" + CRLF
        cQry += "   AND SE1.E1_FILIAL LIKE '" + cEmpresa + "%'" + CRLF
        cQry += "   AND SE1.E1_SALDO > 0" + CRLF                          // Apenas em aberto
        cQry += "   AND SE1.E1_EMISSAO >= '20250101'" + CRLF              // A partir de 01/01/2025
        cQry += "   AND SE1.E1_CLIENTE NOT LIKE 'CHA%'" + CRLF            // Bloqueia cliente EMPRESA_EXEMPLO_B (CHA1, etc)
        cQry += " ORDER BY SE1.E1_EMISSAO, SE1.E1_NUM, SE1.E1_PARCELA" + CRLF

        TCQuery cQry New Alias "TABTEMP"

        While ! TABTEMP->(EoF())
            oBody := JsonObject():New()
            
            //NUMTRANSVENDA: Sequencial �nico = GrpEmp (2 dig) + R_E_C_N_O_ (8 dig)
            //Isso garante unicidade mesmo com m�ltiplas tabelas
            nNumTrans  := Val(cGrpEmp) * 1000000 + TABTEMP->RECNO

            oBody["NUMTRANSVENDA"] := nNumTrans
            oBody["NUMBANCO"]      := Val(AllTrim(TABTEMP->E1_PORTADO))
            oBody["CODCLI"]        := cCodFilial + AllTrim(TABTEMP->E1_CLIENTE) + AllTrim(TABTEMP->E1_LOJA)
            oBody["CODFILIAL"]     := cCodFilial
            oBody["VALOR"]         := TABTEMP->E1_SALDO
            oBody["VALORORIG"]     := TABTEMP->E1_VALOR
            oBody["PREST"]         := AllTrim(TABTEMP->E1_PARCELA)
            oBody["DTVENCORIG"]    := IIf(!Empty(TABTEMP->E1_VENCORI), FmtDtStr(TABTEMP->E1_VENCORI), FmtDtStr(TABTEMP->E1_VENCTO))
            oBody["DTVENC"]        := FmtDtStr(TABTEMP->E1_VENCTO)
            oBody["CODUSUR"]       := AllTrim(TABTEMP->E1_VEND1)
            oBody["PROTESTO"]      := IIf(AllTrim(TABTEMP->E1_SITUACA) == "P", "S", "N")
            oBody["DTEMISSAO"]     := FmtDtStr(TABTEMP->E1_EMISSAO)
            oBody["CODCOB"]        := AllTrim(TABTEMP->E1_TIPO)
            oBody["DUPLIC"]        := Val(AllTrim(TABTEMP->E1_NUM))
            oBody["STATUS"]        := IIf(AllTrim(TABTEMP->E1_STATUS) == "A", "A", "P")
            oBody["NOSSONUMBCO"]   := AllTrim(TABTEMP->E1_NUMBCO)
            oBody["CODBARRA"]      := AllTrim(TABTEMP->E1_CODBAR)
            oBody["NUMCARTEIRA"]   := ""
            oBody["LINHADIG"]      := AllTrim(TABTEMP->E1_CODDIG)
            oBody["CODCLIENTENOBANCO"] := AllTrim(TABTEMP->E1_CLIENTE)
            oBody["VALORDESC"]     := TABTEMP->E1_DESCONT
            oBody["VPAGO"]         := TABTEMP->E1_VALLIQ
            oBody["VALORMULTA"]    := TABTEMP->E1_MULTA
            oBody["VLTXBOLETO"]    := 0
            oBody["CARTORIO"]      := IIf(AllTrim(TABTEMP->E1_SITUACA) == "C", "S", "N")
            oBody["PERCOM"]        := TABTEMP->E1_COMIS1
            oBody["COMISSAO"]      := TABTEMP->E1_VALCOM1
            oBody["AGENCIA"]       := AllTrim(TABTEMP->E1_AGEDEP)
            oBody["DTPAG"]         := IIf(!Empty(TABTEMP->E1_BAIXA), FmtDtStr(TABTEMP->E1_BAIXA), NIL)
            oBody["BOLETO"]        := IIf(AllTrim(TABTEMP->E1_BOLETO) == "1", "S", "N")
            oBody["RECEBIVEL"]     := "N"
            oBody["ID_ERP"]        := AllTrim(TABTEMP->E1_PREFIXO) + AllTrim(TABTEMP->E1_NUM) + AllTrim(TABTEMP->E1_PARCELA) + AllTrim(TABTEMP->E1_TIPO)

                    aAdd(aBody, oBody)
            TABTEMP->(DbSkip())
        EndDo

        TABTEMP->(DbCloseArea())

    Next nCfg
    cJson := FWJsonSerialize(aBody, .F., .F., .T.)
Return cJson

Static Function FmtDtStr(cData)
    Local cRet := ""
    If Empty(AllTrim(cData))
        Return ""
    EndIf
    // YYYYMMDD -> YYYY-MM-DD
    If Len(AllTrim(cData)) >= 8
        cRet := SubStr(cData, 1, 4) + "-" + SubStr(cData, 5, 2) + "-" + SubStr(cData, 7, 2)
    EndIf
Return cRet
