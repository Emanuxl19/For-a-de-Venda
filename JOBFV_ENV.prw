#Include "TOTVS.ch"
 
/*-------------------------------------------------------------------------------------------------*
 | Data       : 07/11//2025                                                                        |
 | Rotina     : JOBFV_ENV                                                                          |
 | Responsavel: EMANUEL AZEVEDO                                                                    |
 | Descricao  : Rotina que executar as funcoes de envio para o as APIS do sistema                  |
 |              MaxPedido.                                                                         |
 | versao     : 1.0                                                                                |
 | Historico  :                                                                                    |
 *------------------------------------------------------------------------------------------------*/

 
User Function JOBFV_ENV()
    Local aRotinas := {}
    Local nIdx     := 0
    Local cFunc    := ""
    Local cAlias   := ""
    Local cMacro   := ""
    Local lOkGeral := .T.
    Local lOkRot   := .F.
    Local oError   := NIL

    // Sequencia de execucao (todas as rotinas 01..21, exceto a 18)
    AAdd(aRotinas, { "U_JOBFVE01", "Departamentos" })
    AAdd(aRotinas, { "U_JOBFVE02", "Fornecedores" })
    AAdd(aRotinas, { "U_JOBFVE03", "Cidades" })
    AAdd(aRotinas, { "U_JOBFVE04", "Clientes" })
    AAdd(aRotinas, { "U_JOBFVE05", "Tabelas de Precos" })
    AAdd(aRotinas, { "U_JOBFVE06", "Secoes" })
    AAdd(aRotinas, { "U_JOBFVE07", "Dias Uteis" })
    AAdd(aRotinas, { "U_JOBFVE08", "Vendedores" })
    AAdd(aRotinas, { "U_JOBFVE09", "Produtos" })
    AAdd(aRotinas, { "U_JOBFVE10", "Estoques" })
    AAdd(aRotinas, { "U_JOBFVE11", "Cobrancas" })
    AAdd(aRotinas, { "U_JOBFVE12", "Regioes" })
    AAdd(aRotinas, { "U_JOBFVE13", "Tributos" })
    AAdd(aRotinas, { "U_JOBFVE14", "Pracas" })
    AAdd(aRotinas, { "U_JOBFVE15", "PlanosPagamentos" })
    AAdd(aRotinas, { "U_JOBFVE16", "PrestacoesTitulos" })
    AAdd(aRotinas, { "U_JOBFVE17", "Descontos" })
    AAdd(aRotinas, { "U_JOBFVE18", "MotivosNaoCompra" })
    AAdd(aRotinas, { "U_JOBFVE19", "ProdutosUsuarios" })
    AAdd(aRotinas, { "U_JOBFVE20", "ClientesPorVendedores" })

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
