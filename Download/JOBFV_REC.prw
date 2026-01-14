//Bibliotecas
#Include "Protheus.ch"
#Include "TopConn.ch"
	
//Constantes
#Define STR_PULA		Chr(13)+Chr(10)

/*-------------------------------------------------------------------------------------------------*
 | Data       : 08/01/2026                                                                         |
 | Rotina     : JOBFVREC                                                                           |
 | Responsavel: EMANUEL AZEVEDO                                                                    |
 | Descricao  : Rotina que executar as funcoes de Upload para da API para o ERP                    |
 |              MaxPedido.                                                                         |
 | versao     : 1.0                                                                                |
 | Historico  :                                                                                    |
 *------------------------------------------------------------------------------------------------*/

User Function JOBFVREC()
	Local aArea   := GetArea()
	Private cPerg := ""

    If Select("SX2") <= 0
		RPCSetEnv("06", "02", , , "FAT")
	EndIf

	cPerg := "JOBFVREC"

	If Pergunte(cPerg, .T.)
		Processa({|| fUpdMaxima()}, "Trazendo Dados para o Protheus...")
	Else
		Return .F.
	EndIf
	RestArea(aArea)
Return

Static Function fUpdMaxima()
	Local nTotExec := 0

    Local aRotinas := {}
    Local nIdx     := 0
    Local cFunc    := ""
    Local cAlias   := ""
    Local cMacro   := ""
    Local lOkGeral := .T.
    Local lOkRot   := .F.
    Local oError   := NIL
	Local cMsg     := ""


	If Val(cValToChar(MV_PAR01)) == 1
	    AAdd(aRotinas, { "U_JOBFVR01", "Pedidos de Venda" })
		nTotExec++
	EndIf
	If Val(cValToChar(MV_PAR02)) == 1
    	AAdd(aRotinas, { "U_JOBFVR02", "Historico dos Pedidos" })
		nTotExec++
	EndIf
	If Val(cValToChar(MV_PAR03)) == 1
    	AAdd(aRotinas, { "U_JOBFVR03", "Carga dos Clientes" })
		nTotExec++
	EndIf

	If Val(cValToChar(MV_PAR04)) == 1
    	AAdd(aRotinas, { "U_JOBFVR04", "Carga dos Orcamentos" })
		nTotExec++
	EndIf
	
	ProcRegua(nTotExec)

    For nIdx := 1 To Len(aRotinas)
        cFunc  := aRotinas[nIdx][1]
        cAlias := aRotinas[nIdx][2]
	 	IncProc("Executando (" + cValToChar(nIdx) + "/" + cValToChar(nTotExec) + ") >> "+cFunc+" - "+cAlias)

        If FindFunction(cFunc)
            cMacro := cFunc + "()"
            oError := NIL

            Begin Sequence
                lOkRot := &(cMacro)
            Recover Using oError
                ConOut("Erro ao executar " + cFunc + " (" + cAlias + "): " + If(oError == NIL, "Erro nao identificado.", oError:Description))
                lOkRot := .F.
            End Sequence

            If lOkRot
				cMsg += "Rotina " + cFunc + " (" + cAlias + ") - OK." + CRLF
			Else
				cMsg += "Rotina " + cFunc + " (" + cAlias + ") - Error." + CRLF
			EndIf

            lOkGeral := lOkGeral .And. lOkRot
        Else
            ConOut("Funcao " + cFunc + " (" + cAlias + ") nao encontrada no AppMap. Compile o fonte correspondente antes de executar a rotina integradora.")
            lOkGeral := .F.
        EndIf
    Next nIdx

    //Mensagem pequena normal
    Aviso("Carga de Dados", cMsg, {"OK"}, 2, "Carga de Dados para da Maxima para o Protheus (Maxima Sistemas)")

Return lOkGeral
