#Include "TOTVS.ch"
 
/*-------------------------------------------------------------------------------------------------*
 | Data       : 07/11//2025                                                                        |
 | Rotina     : BAFATJFV                                                                           |
 | Responsavel: EMANUEL AZEVEDO                                                                    |
 | Descricao  : Rotina que executar as funcoes de envio para o as APIS do sistema                  |
 |              MaxPedido.                                                                         |
 | versao     : 1.0                                                                                |
 | Historico  :                                                                                    |
 *------------------------------------------------------------------------------------------------*/

 
User Function BAFATJFV()
    Local aRotinas := {}
    Local nIdx     := 0
    Local cFunc    := ""
    Local cAlias   := ""
    Local cMacro   := ""
    Local lOkGeral := .T.
    Local lOkRot   := .F.
    Local oError   := NIL

    // Sequencia de execucao (todas as rotinas 01..21, exceto a 18)
    AAdd(aRotinas, { "U_JOBFVR01", "Importa os Pedidos de Venda" })
    AAdd(aRotinas, { "U_JOBFVR02", "Atualiza Histõrico" })
    AAdd(aRotinas, { "U_JOBFVR03", "Importa Clientes" })
    AAdd(aRotinas, { "U_JOBFVE10", "Atualiza Estoques" })

    For nIdx := 1 To Len(aRotinas)
        cFunc  := aRotinas[nIdx][1]
        cAlias := aRotinas[nIdx][2]

        If FindFunction(cFunc)
            cMacro := cFunc + "()"
            oError := NIL

            Begin Sequence
                lOkRot := &(cMacro)
            Recover Using oError
                ConOut("Erro ao executar " + cFunc + " (" + cAlias + "): " + If(oError == NIL, "Erro nao identificado.", oError:Description))
                lOkRot := .F.
            End Sequence

            If ! lOkRot
                ConOut("Rotina " + cFunc + " (" + cAlias + ") retornou falha logica.")
            EndIf

            lOkGeral := lOkGeral .And. lOkRot
        Else
            ConOut("Funcao " + cFunc + " (" + cAlias + ") nao encontrada no AppMap. Compile o fonte correspondente antes de executar a rotina integradora.")
            lOkGeral := .F.
        EndIf
    Next nIdx

Return lOkGeral
