//Bibliotecas
#Include "Protheus.ch"
#Include "TopConn.ch"
	
//Constantes
#Define STR_PULA		Chr(13)+Chr(10)

/*-------------------------------------------------------------------------------------------------*
 | Data       : 15/12//2025                                                                        |
 | Rotina     : BAFATPFV                                                                           |
 | Responsavel: EMANUEL AZEVEDO                                                                    |
 | Descricao  : Rotina que executar as funcoes de envio para o as APIS do sistema                  |
 |              MaxPedido.                                                                         |
 | versao     : 1.0                                                                                |
 | Historico  :                                                                                    |
 *------------------------------------------------------------------------------------------------*/


User Function BAFATPFV()
	Local aArea   := GetArea()
	Private cPerg := ""

	cPerg := "BAFATPFV"

	If Pergunte(cPerg, .T.)
		Processa({|| fUpdMaxima()}, "Enviandos Dados para Força de Vendas...")
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


	If MV_PAR01 == 1
	    AAdd(aRotinas, { "U_JOBFVE01", "Departamentos" })
		nTotExec++
	EndIf
	If MV_PAR02 == 1
    	AAdd(aRotinas, { "U_JOBFVE02", "Fornecedores" })
		nTotExec++
	EndIf
	If MV_PAR03 == 1
    	AAdd(aRotinas, { "U_JOBFVE03", "Cidades" })
		nTotExec++
	EndIf
	If MV_PAR04 == 1
    	AAdd(aRotinas, { "U_JOBFVE04", "Clientes" })
		nTotExec++
	EndIf
	If MV_PAR05 == 1
    	AAdd(aRotinas, { "U_JOBFVE05", "Tabelas de Precos" })
		nTotExec++
	EndIf
	If MV_PAR06 == 1
    	AAdd(aRotinas, { "U_JOBFVE06", "Secoes" })
		nTotExec++
	EndIf
	If MV_PAR07 == 1
    	AAdd(aRotinas, { "U_JOBFVE07", "Dias Uteis" })
		nTotExec++
	EndIf
	If MV_PAR08 == 1
    	AAdd(aRotinas, { "U_JOBFVE08", "Vendedores" })
		nTotExec++
	EndIf
	If MV_PAR09 == 1
    	AAdd(aRotinas, { "U_JOBFVE09", "Produtos" })
		nTotExec++
	EndIf
	If MV_PAR10 == 1
    	AAdd(aRotinas, { "U_JOBFVE10", "Estoques" })
		nTotExec++
	EndIf
	If MV_PAR11 == 1
    	AAdd(aRotinas, { "U_JOBFVE11", "Cobrancas" })
		nTotExec++
	EndIf
	If MV_PAR12 == 1
    	AAdd(aRotinas, { "U_JOBFVE12", "Regioes" })
		nTotExec++
	EndIf
	If MV_PAR13 == 1
    	AAdd(aRotinas, { "U_JOBFVE13", "Tributos" })
		nTotExec++
	EndIf
	If MV_PAR14 == 1
    	AAdd(aRotinas, { "U_JOBFVE14", "Pracas" })
		nTotExec++
	EndIf
	If MV_PAR15 == 1
    	AAdd(aRotinas, { "U_JOBFVE15", "PlanosPagamentos" })
		nTotExec++
	EndIf
	If MV_PAR16 == 1
    	AAdd(aRotinas, { "U_JOBFVE16", "PrestacoesTitulos" })
		nTotExec++
	EndIf
	If MV_PAR17 == 1
    	AAdd(aRotinas, { "U_JOBFVE17", "Descontos" })
		nTotExec++
	EndIf
	If MV_PAR18 == 1
   		AAdd(aRotinas, { "U_JOBFVE18", "MotivosNaoCompra" })
		nTotExec++
	EndIf
	If MV_PAR19 == 1
    	AAdd(aRotinas, { "U_JOBFVE19", "ProdutosUsuarios" })
		nTotExec++
	EndIf
	If MV_PAR20 == 1
    	AAdd(aRotinas, { "U_JOBFVE20", "ClientesPorVendedores" })
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
    Aviso("Carga de Dados", cMsg, {"OK"}, 2, "Carga de Dados para o sistema de Força de Venda (Maxima Sistemas)")

Return lOkGeral
