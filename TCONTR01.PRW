#INCLUDE 'PROTHEUS.CH'
#INCLUDE 'RWMAKE.CH'
#INCLUDE 'FONT.CH'
#INCLUDE 'COLORS.CH'
#INCLUDE 'TOPCONN.CH'
//Constantes
#Define STR_PULA		Chr(13)+Chr(10)

/*{Protheus.doc} u_CotacaoFrete()
    Relação de fretes cotados por períodos.
    author Rodrigo Augusto
    since 05/03/2023
    see: http://tdn.totvs.com/display/tec/twebengine
          http://tdn.totvs.com/display/tec/twebchannel
    observation:
          Compativel com SmartClient Desktop(Qt);
*/


//##################################################################################################################
// FUNÇÃO PRINCIPAL QUE É CHAMADA PELO MENU
//##################################################################################################################
User function TCTL01()

    local oWebEngine
    local aSize             := MsAdvSize()
    local aParamBox         := {}
    private oModal
    private aAtualizar      := {}
    private aPesquisa       := {}
    private aResetar        := {}
    private aRelatorio      := {}
    private aIncluiAltera   := {}
    private aExclui         := {}
    private cAno        
    private cStatusParam    := {}
    private cDtInicio
    private cDtFim


    //Solicita ao usuário os Parâmetros para pesquisa.
        aAdd(aParamBox,{1,"Data Inicio" ,Ctod(Space(8)) ,"","","","",50,.F.})   // Tipo data
	    aAdd(aParamBox,{1,"Data Fim"    ,Ctod(Space(8)) ,"","","","",50,.F.})   // Tipo data
        aAdd(aParamBox,{4,"Considera Abertos ?"     ,.F.,"Aberto",90,"",.F.})
        aAdd(aParamBox,{4,"Considera Cotados ?"     ,.F.,"Cotado",90,"",.F.})
        aAdd(aParamBox,{4,"Considera Finalizado ?"  ,.F.,"Finalizado",90,"",.F.})

        ParamBox(aParamBox,"Parametros de pesquisa.")

        cDtInicio       := DtoS(MV_PAR01) + " 00:00:00"
        cDtFim          := DtoS(MV_PAR02) + " 23:59:59"

        Iif(MV_PAR03, aadd(cStatusParam, "1"), aadd(cStatusParam, "0"))
        Iif(MV_PAR04, aadd(cStatusParam, "2"), aadd(cStatusParam, "0"))
        Iif(MV_PAR05, aadd(cStatusParam, "3"), aadd(cStatusParam, "0"))

    private oWebChannel, oCotacaoFrete


    oModal := MSDialog():New(aSize[7],0,aSize[6],aSize[5], "Página Local",,,,,,,,,.T./*lPixel*/)
        // WebSocket (comunicacao AdvPL x JavaScript)
        oWebChannel := TWebChannel():New()
        oWebChannel:bJsToAdvpl := {|self,key,value| jsToAdvpl(self,key,value) } 
        oWebChannel:connect()
        
        // WebEngine (chromium embedded)
        oWebEngine := TWebEngine():New(oModal,0,0,100,100,/*cUrl*/,oWebChannel:nPort)
        oWebEngine:Align := CONTROL_ALIGN_ALLCLIENT
        
        // WebComponent de teste
        oCotacaoFrete := CotacaoFrete():Constructor()
        oWebEngine:navigate(;
            iif(oCotacaoFrete:GetOS()=="UNIX", "file://", "")+;
            oCotacaoFrete:mainHTML)
        
        // bLoadFinished sera disparado ao fim da carga da pagina
        // instanciando o bloco de codigo do componente, e tambem um customizado
        oWebEngine:bLoadFinished := {|webengine, url| oCotacaoFrete:OnInit(webengine, url),myLoadFinish() }


    oModal:Activate()

return


//##################################################################################################################
// FUNÇÃO CUSTOMIZAVEL QUE SERA DISPARADA APÓS TERMINAR O CARREGAMENTO DA PÁGINA
//##################################################################################################################
static function myLoadFinish(oWebEngine, url)
    ConsultaFretes()
return


//##################################################################################################################
// FUNÇÃO QUE RECEBE OS DADOS VINDOS DO JAVASCRYPT
//##################################################################################################################
static function jsToAdvpl(self,key,value)
	conout("",;
		"jsToAdvpl->key: " + key,;
           	"jsToAdvpl->value: " + value)

    // ---------------------------------------------------------------
    // Insira aqui o tratamento para as mensagens vindas do JavaScript
    // ---------------------------------------------------------------
    Do Case
        case key  == "<incluiealtera>" // Função fazer inclusão ou alteração de um registro.

            aadd( aIncluiAltera, StrTokArr(value, ",") )
            oCotacaoFrete:set("aAtendimento", aIncluiAltera, {|| fParambox()} )

        case key  == "<exclui>" // Função fazer inclusão ou alteração de um registro.

            aadd( aExclui, StrTokArr(value, ",") )
            oCotacaoFrete:set("aExclui", aExclui, {|| ExcluiDados()} )

        case key == "<Atualizar>" // Função para atualizar as informações da tela

            aadd( aAtualizar, StrTokArr(value, ",") )
            oCotacaoFrete:set("aAtualizar", aAtualizar, {|| ConsultaFretes()} )

        case key == "<Pesquisa>" // Função para pesquisar um pedido específico no banco de atendimentos.

            aadd( aPesquisa, StrTokArr(value, ",") )
            oCotacaoFrete:set("aPesquisa", aPesquisa, {|| PesqPedido()} )

        case key == "<Relatorio>" // Função para imprimir relatório de atendimentos por período.

            aadd( aPesquisa, StrTokArr(value, ",") )
            oCotacaoFrete:set("aRelatorio", aRelatorio, {|| PrintReport()} )

        case key == "<Resetar>" // Função para resetar a página e refazer a pesquisa.

            aadd( aResetar, StrTokArr(value, ",") )
            oCotacaoFrete:set("aResetar", aResetar, {|| ResetarPag()} )

    EndCase
Return


//##################################################################################################################
// FUNÇÃO PARA ESTRUTURA E APRESNTAÇÃO DA PÁGINA
//##################################################################################################################
Static FUNCTION ConsultaFretes(cPesqAtend)
    Local aDadosZCF     := {}
    local aNum          := {}
    local cRecno        := ""
    Local y             := 0
    Local nPrasoOrc     := 30
    local dDtValidade   := ""
    local cTabela       := ""
    local w             := 0

    Statuscheck()



    if !Empty(cPesqAtend)

        //SQL PEGA OS VALORES DA PESQUISA POR PEDIDO.
        BEGINSQL ALIAS "SQL_ZCF"
            SELECT	                                                                                                    
            ZCF_STATUS,                                                                                                 
            ZCF_NUM,                                                                                                    
            UA_CLIENTE,                                                                                                 
            A1_NOME,                                                                                                    
            A1_CGC,                                                                                                     
            US_NOME,                                                                                                    
		    US_CGC,                                                                                                     
            UA_NUMSC5,
            A3_NREDUZ,
            UA_PROSPEC,                                                                                        
            CONVERT(VARCHAR,CONVERT(DATE,ZCF_EMISSA), 103) AS EMIDATE,                                                  
            CONVERT(VARCHAR,CONVERT(TIME,ZCF_EMISSA), 108) AS EMITIME,                                                  
            CASE WHEN ZCF_DTORC = '-' THEN '-' else CONVERT(VARCHAR,CONVERT(DATE,ZCF_DTORC), 103) END AS ORCDATE,       
            CASE WHEN ZCF_DTORC = '-' THEN '-' else CONVERT(VARCHAR,CONVERT(TIME,ZCF_DTORC), 108) END AS ORCTIME,       
            ZCF_VFRETE,                                                                                                 
            ZCF_VALPED,                                                                                                 
            ZCF_VOLUME,                                                                                                 
            ZCF_PESO,                                                                                                   
            ZCF_ALTURA,                                                                                                 
            ZCF_LARGUR,                                                                                                 
            ZCF_COMPRI,                                                                                                 
            ZCF_OBS                                                                                                     
            FROM ZCF010 ZCF 
            LEFT OUTER JOIN SUA010 SUA ON UA_FILIAL = ZCF_FILIAL AND ZCF_NUM = UA_NUM                                                   
            LEFT OUTER JOIN SA1010 SA1 ON A1_COD = UA_CLIENTE AND A1_LOJA = UA_LOJA AND A1_FILIAL = LEFT(UA_FILIAL,4) AND SA1.D_E_L_E_T_ = ''
            LEFT OUTER JOIN SUS010 SUS ON US_COD = UA_CLIENTE AND US_LOJA = UA_LOJA AND US_FILIAL = LEFT(UA_FILIAL,4) AND SUS.D_E_L_E_T_ = ''
            LEFT OUTER JOIN SA3010 SA3 ON UA_VEND = A3_COD AND LEFT(UA_FILIAL,4) = A3_FILIAL
            WHERE ZCF_FILIAL = %xFilial:ZCF%                                                                            
            AND ZCF_EMISSA >= %EXP:cDtInicio%                                                                           
            AND ZCF_EMISSA <= %EXP:cDtFim%                                                                              
            AND ZCF.D_E_L_E_T_ = ''                                                                                 
            AND ZCF_STATUS IN ('1','2','3')                                                                             
            AND ZCF_NUM = %EXP:cPesqAtend%                                                                              
            ORDER BY ZCF_EMISSA DESC                                                                                    
        ENDSQL

        cPesqAtend := ""

    else

        BEGINSQL ALIAS "SQL_ZCN"

            SELECT DISTINCT 
            ZCF_NUM 
            FROM ZCF010
            WHERE ZCF_FILIAL = %xFilial:ZCF%                                                                            
            AND ZCF_EMISSA >= %EXP:cDtInicio%                                                                           
            AND ZCF_EMISSA <= %EXP:cDtFim%     

        ENDSQL

        if !SQL_ZCN->(EoF())

            SQL_ZCN->( dbGoTop() )

                While ! SQL_ZCN->(EoF())
                    cDadosZCN := SQL_ZCN->ZCF_NUM
                    aadd( aNum, StrTokArr(cDadosZCN, ",") )
                    SQL_ZCN->(DbSkip())
                EndDo

            SQL_ZCN->( dbCloseArea() )
        
        Endif

        //fecha o alias temporário
        If Select("SQL_ZCN") > 0
            dbSelectArea("SQL_ZCN")
            dbCloseArea()
        EndIf

        for w:=1 to len(aNum)

            leng := len(aNum)

            cNumeroatendemento := aNum[w][1]
            If w == leng
                cSeparador := ""
            else
                cSeparador := "','"
            endif

            BEGINSQL ALIAS "SQL_ZCR"

                SELECT TOP 1 R_E_C_N_O_ 
                FROM ZCF010 
                WHERE ZCF_FILIAL = %xFilial:ZCF% 
                AND ZCF_NUM = %EXP:cNumeroatendemento% 
                AND D_E_L_E_T_ = ''

            ENDSQL

            if !SQL_ZCR->(EoF())

                SQL_ZCR->( dbGoTop() )

                    While ! SQL_ZCR->(EoF())
                        cRecno += cValtochar(SQL_ZCR->R_E_C_N_O_ ) + cSeparador
                        SQL_ZCR->(DbSkip())
                    EndDo

                SQL_ZCR->( dbCloseArea() )
        
            Endif

            //fecha o alias temporário
            If Select("SQL_ZCR") > 0
                dbSelectArea("SQL_ZCR")
                dbCloseArea()
            EndIf

        next
    
        //SQL PEGA OS VALORES DA CONSULTA INICIAL
        BEGINSQL ALIAS "SQL_ZCF"
            SELECT	
            ZCF_STATUS,
            ZCF_NUM,
            UA_CLIENTE,
            A1_NOME,
            A1_CGC,
            US_NOME,
		    US_CGC,
            UA_NUMSC5,
            A3_NREDUZ,
            UA_PROSPEC,
            CONVERT(VARCHAR,CONVERT(DATE,ZCF_EMISSA), 103) AS EMIDATE,
            CONVERT(VARCHAR,CONVERT(TIME,ZCF_EMISSA), 108) AS EMITIME,
            CASE WHEN ZCF_DTORC = '-' THEN '-' else CONVERT(VARCHAR,CONVERT(DATE,ZCF_DTORC), 103) END AS ORCDATE,
            CASE WHEN ZCF_DTORC = '-' THEN '-' else CONVERT(VARCHAR,CONVERT(TIME,ZCF_DTORC), 108) END AS ORCTIME,
            ZCF_VFRETE,
            ZCF_VALPED,
            ZCF_VOLUME,
            ZCF_PESO,
            ZCF_ALTURA,
            ZCF_LARGUR,
            ZCF_COMPRI,
            ZCF_OBS
            FROM ZCF010 ZCF 
            LEFT OUTER JOIN SUA010 SUA ON UA_FILIAL = ZCF_FILIAL AND ZCF_NUM = UA_NUM
            LEFT OUTER JOIN SA1010 SA1 ON A1_COD = UA_CLIENTE AND A1_LOJA = UA_LOJA AND A1_FILIAL = LEFT(UA_FILIAL,4) AND SA1.D_E_L_E_T_ = ''
            LEFT OUTER JOIN SUS010 SUS ON US_COD = UA_CLIENTE AND US_LOJA = UA_LOJA AND US_FILIAL = LEFT(UA_FILIAL,4) AND SUS.D_E_L_E_T_ = ''
            LEFT OUTER JOIN SA3010 SA3 ON UA_VEND = A3_COD AND LEFT(UA_FILIAL,4) = A3_FILIAL
            WHERE ZCF_FILIAL = %xFilial:ZCF%
            AND ZCF_EMISSA >= %EXP:cDtInicio%
            AND ZCF_EMISSA <= %EXP:cDtFim%
            AND ZCF.D_E_L_E_T_ = ''
            AND ZCF.R_E_C_N_O_ IN (%EXP:cRecno%)
            AND ZCF_STATUS IN (%EXP:cStatusParam[1]%,%EXP:cStatusParam[2]%,%EXP:cStatusParam[3]%)
            ORDER BY ZCF_EMISSA DESC
        ENDSQL

    endif

    //Se houver dados
        if ! SQL_ZCF->(EoF())

            SQL_ZCF->( dbGoTop() )

                While ! SQL_ZCF->(EoF())

                    cDadosZCF:= CValToChar(SQL_ZCF->ZCF_STATUS)                                         + "," +;
                                SQL_ZCF->ZCF_NUM                                                        + "," +;
                                SQL_ZCF->UA_CLIENTE                                                     + "," +;
                                Iif(SQL_ZCF->UA_PROSPEC = 'F' , SQL_ZCF->A1_NOME  , SQL_ZCF->US_NOME  ) + "," +;
                                Iif(SQL_ZCF->UA_PROSPEC = 'F' , SQL_ZCF->A1_CGC   , SQL_ZCF->US_CGC   ) + "," +;
                                Iif(SQL_ZCF->UA_NUMSC5 <> ''  , SQL_ZCF->UA_NUMSC5, '-')                + "," +;
                                SQL_ZCF->EMIDATE + " " + EMITIME                                        + "," +;
                                SQL_ZCF->ORCDATE + " " + ORCTIME                                        + "," +;
                                CValToChar(SQL_ZCF->ZCF_VFRETE)                                         + "," +;
                                CValToChar(SQL_ZCF->ZCF_VALPED)                                         + "," +;
                                CValToChar(SQL_ZCF->ZCF_VOLUME)                                         + "," +;
                                CValToChar(SQL_ZCF->ZCF_PESO  )                                         + "," +;
                                CValToChar(SQL_ZCF->ZCF_ALTURA)                                         + "," +;
                                CValToChar(SQL_ZCF->ZCF_LARGUR)                                         + "," +;
                                CValToChar(SQL_ZCF->ZCF_COMPRI)                                         + "," +;
                                SQL_ZCF->ZCF_OBS                                                        + "," +;
                                SQL_ZCF->A3_NREDUZ

                    aadd( aDadosZCF, StrTokArr(cDadosZCF, ",") )

                    SQL_ZCF->(DbSkip())

                EndDo

            SQL_ZCF->( dbCloseArea() )
            
        else

            MsgStop("Nao foram encontrados Dados para o período pesquisado!", "Atencao")
            SQL_ZCF->( dbCloseArea() )

        endif

    //Monta o cabeçalho da tabela para exibição
        cTabela +=  "<div>"+;
                        "<br>"+;
                        "<div class='row'>"+;
                            "<div class='col'>"+;
                                "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<incluiealtera>`,`inclui`)'>Incluir</button>"    +;
                                "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<Atualizar>`,`atualizar`)'>Atualizar</button>"   +;
                            "</div>"+;
                            "<div class='col'>"+;
                                "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<Pesquisa>`,`pesquisa`)'>Pesquisar</button>"     +;
                                "<button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<Relatorio>`,`relatorio`)'>Relatório</button>"   +;
                            "</div>"+;
                        "</div>"+;
                        "<br>"+;
                    "</div>"+;
                    "<table class='table table-bordered table-striped table-dark'>"+;
                    "<tr>"+;
                        "<th width='120'>ALTERAR</th>"+;
                        "<th width='120'>EXCLUIR</th>"+;
                        "<th width='120'>STATUS</th>"+;
                        "<th width='120'>ORÇ/ATEND</th>"+;
                        "<th width='120'>NOME CLIENTE</th>"+;
                        "<th width='120'>PEDIDO</th>"+;
                        "<th width='120'>VENDEDORA</th>"+;
                        "<th width='120'>DT. SOLICITAÇÃO</th>"+;
                        "<th width='120'>DT. COTAÇÃO</th>"+;
                        "<th width='120'>DT. VALIDADE</th>"+;
                        "<th width='120'>VALOR FRETE</th>"+;
                        "<th width='120'>VALOR PEDIDO</th>"+;
                        "<th width='120'>VOLUME</th>"+;
                        "<th width='120'>PESO</th>"+;
                        "<th width='120'>ALTURA</th>"+;
                        "<th width='120'>LARGURA</th>"+;
                        "<th width='120'>COMPRIMENTO</th>"+;
                        "<th style='width: 200px' class='truncate' title='Hello'>OBSERVAÇÕES</th>"+;
                    "<tr>"
    //Loop para montar as linhas com os dados e preencher a tabela.
        For y := 1 to Len(aDadosZCF)

            // De houver data de cotação calcula a data de validade
            if !Empty(aDadosZCF[y][9]) .and. aDadosZCF[y][9] <> "0"
                dDtValidade := DtoC(DaySum(CTOD(AllTrim(aDadosZCF[y][8])), nPrasoOrc))
            else
                dDtValidade := "-"
            endif

            // Monta a tabela com os dados consultados sendo que a primeira/segunda coluna são um botões para alterar ou excluir um registro.
            cTabela +=  "<tr>"+;
                            "<td><button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<incluiealtera>`,`altera," + aDadosZCF[y][2] + "`)'>Alterar</button></td>"+; //Botão alterar
                            "<td><button class='btn btn-outline-secondary' onclick='twebchannel.jsToAdvpl(`<exclui>`,`" + aDadosZCF[y][2] + ",exclui`)'>Excluir</button></td>"          //Botão Excluir
                            if aDadosZCF[y][1] = "1"

                                cTabela += "<td><button type='button' class='btn btn-success'>O</button></td>"     // Status"

                            elseif aDadosZCF[y][1] = "2"

                                cTabela +="<td><button type='button' class='btn btn-warning'>-</td>"     // Status

                            else

                                cTabela +="<td><button type='button' class='btn btn-danger'>X</td>"     // Status

                            endif

            cTabela +=      "<td width='50%'>"+ AllTrim(aDadosZCF[y][2] )+"</td>"+;     // Orçamento
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][4] )+"</td>"+;     // Nome Cliente
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][6] )+"</td>"+;     // Pedido
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][17])+"</td>"+;     // Vendedora
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][7] )+"</td>"+;     // Dt Solicitação
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][8] )+"</td>"+;     // Dt Cotação
                            "<td width='120'>"+ dDtValidade              +"</td>"+;     // Dt Validade
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][9] )+"</td>"+;     // Valor Frete
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][10])+"</td>"+;     // Valor Pedido
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][11])+"</td>"+;     // Volume
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][12])+"</td>"+;     // Peso
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][13])+"</td>"+;     // Altura
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][14]) +"</td>"+;    // Largura
                            "<td width='120'>"+ AllTrim(aDadosZCF[y][15]) +"</td>"+;    // Comprimento
                            "<td style='width: 200px' class='truncate' title='Hello'>"+ AllTrim(aDadosZCF[y][16]) +"</td>"+;    // Observações
                        "</tr>"

        Next y 



    oWebChannel:advplToJS("<relacao-geral>", cTabela)

Return


//##################################################################################################################
// FUNÇÃO PARA PESQUISA DE PEDIDO/ATENDIMENTO
//##################################################################################################################
Static FUNCTION PesqPedido()
    local aParamBox         := {}
    local cPedOrc           := ""
    local cPesqAtend        := ""


    //Solicita ao usuário os Parâmetros para pesquisa.
    aAdd(aParamBox,{1,"Nº do Pedido"      ,Space(6),"","","","",0,.F.}) // Tipo caractere
    aAdd(aParamBox,{1,"Nº do Orçamento"   ,Space(6),"","","","",0,.F.}) // Tipo caractere
        // Tipo 1 -> MsGet()
        // [2]-Descricao
        // [3]-String contendo o inicializador do campo
        // [4]-String contendo a Picture do campo
        // [5]-String contendo a validacao
        // [6]-Consulta F3
        // [7]-String contendo a validacao When
        // [8]-Tamanho do MsGet
        // [9]-Flag .T./.F. Parametro Obrigatorio ?

    // Verifica se o Parambox retorna True
    if ParamBox(aParamBox,"Informe o Pedido:")
        // Passa o valor informado para a variável.
        If !Empty(MV_PAR01)
            cPedOrc := MV_PAR01

            // Verifica se o pedido tem uma cotação de frete atrelada a ele.
            dbSelectArea("SUA")
            SUA->(dbSetOrder(8))
            if SUA->(dbSeek(xFilial("SUA") + cPedOrc))

                cPesqAtend := UA_NUM

                //Fecha a area da SUA
                if Select("SUA") > 0
                    dbSelectArea("SUA")
                    dbCloseArea()
                endif

                ConsultaFretes(cPesqAtend)

            Else

                Alert("Não existe uma cotação aberta para o Pedido '" + cPedOrc + "'!","ATENCAO")

                //Fecha a area da SUA
                if Select("SUA") > 0
                    dbSelectArea("SUA")
                    dbCloseArea()
                endif
            endif

        Else

            cPedOrc := MV_PAR02

            // Verifica se o pedido tem uma cotação de frete atrelada a ele.
            dbSelectArea("SUA")
            SUA->(dbSetOrder(1))
            if SUA->(dbSeek(xFilial("SUA") + cPedOrc))

                cPesqAtend := UA_NUM

                //Fecha a area da SUA
                if Select("SUA") > 0
                    dbSelectArea("SUA")
                    dbCloseArea()
                endif

                ConsultaFretes(cPesqAtend)

            Else

                Alert("Não existe uma cotação aberta para o Pedido '" + cPedOrc + "'!","ATENCAO")

                //Fecha a area da SUA
                if Select("SUA") > 0
                    dbSelectArea("SUA")
                    dbCloseArea()
                endif
            endif
        endif
    endif
Return


//##################################################################################################################
// FUNÇAO PARAMBOX
//##################################################################################################################
Static Function fParambox()

    Local aParamBox         := {}
    Local cAtendimento	    := "    "
    Local aAtendimento      := oCotacaoFrete:get("aAtendimento")

    //Solicita ao usuário os Parâmetros para pesquisa.
    aAdd(aParamBox,{1,"Orçamento/Atendimento :",Space(6),"","","","",0,.T.}) // Tipo caractere
        // Tipo 1 -> MsGet()
        // [2]-Descricao
        // [3]-String contendo o inicializador do campo
        // [4]-String contendo a Picture do campo
        // [5]-String contendo a validacao
        // [6]-Consulta F3
        // [7]-String contendo a validacao When
        // [8]-Tamanho do MsGet
        // [9]-Flag .T./.F. Parametro Obrigatorio ?

    //Verifica se é alteração
    if aAtendimento[1][1] = 'altera'

        cAtendimento := aAtendimento[1][2]

        //Na alteração chama a função incluir passando como parametro o numero do atendimento selecionado.
        Incluir(cAtendimento)


    elseif ParamBox(aParamBox,"Informe o Atendimento/Orçamento.") 

        cAtendimento := MV_PAR01

        dbSelectArea("ZCF")
        ZCF->(dbSetOrder(1))
        if ZCF->(dbSeek(xFilial("ZCF") + cAtendimento)) .and. !Deleted()    

            Alert("Já existe uma cotação aberta para o Orçamento/Atendimento " + cAtendimento + "!","ATENCAO")

            //Fecha a area da ZCF
            if Select("ZCF") > 0
                dbSelectArea("ZCF")
                dbCloseArea()
            endif

        else
            dbSelectArea("SUA")
            SUA->(dbSetOrder(1))
            if SUA->(dbSeek(xFilial("SUA") + cAtendimento))

                //Fecha a area da ZCF
                if Select("ZCF") > 0
                    dbSelectArea("ZCF")
                    dbCloseArea()
                endif

                //Fecha a area da SUA
                if Select("SUA") > 0
                    dbSelectArea("SUA")
                    dbCloseArea()
                endif

                Incluir(cAtendimento)

            else

                Alert("O Orçamento/Atendimento '" + AllTrim(cAtendimento) + "' não encontrado na base de dados!","ATENCAO")
                cAtendimento := "    "

            endif
        endif
    endif
    //EndDo

    //Fecha a area da ZCF
    if Select("ZCF") > 0
        dbSelectArea("ZCF")
        dbCloseArea()
    endif

    //Fecha a area da SUA
    if Select("SUA") > 0
        dbSelectArea("SUA")
        dbCloseArea()
    endif

Return


//##################################################################################################################
// TELA DE INCLUSÃO
//##################################################################################################################
Static Function Incluir(cAtendimento)
    Local aaCampos  	:= {"CODIGO"       ,;
                            "ZCF_VALPED"   ,;
                            "ZCF_VFRETE"   ,;
                            "ZCF_VOLUME"   ,;
                            "ZCF_ALTURA"   ,;
                            "ZCF_LARGUR"   ,;
                            "ZCF_COMPRI"   ,;
                            "ZCF_PESO"     ,;
                            "ZCF_OBS"} 	//Variável contendo o campo editável no Grid

    Local aBotoes	        := {}         	//Variável onde será incluido o botão para a legenda
    private aProdutos       := {}
    private oDlg                            //Declara o Objeto da dialog
    Private oLista                       	//Declarando o objeto do browser
    Private aCabecalho      := {}         	//Variavel que montará o aHeader do grid
    Private aColsEx 	    := {}         	//Variável que receberá os dados
    Private cDtEmissao		:= DTOS(DATE()) + " " + cVALTOCHAR(TIME())       
	Private cDtOrcamento	:= DTOS(DATE()) + " " + cVALTOCHAR(TIME())
 
    //Declarando os objetos de cores para usar na coluna de status do grid
    Private oVerde  	:= LoadBitmap( GetResources(), "BR_VERDE")
    Private oAzul  	    := LoadBitmap( GetResources(), "BR_AZUL")
    Private oVermelho	:= LoadBitmap( GetResources(), "BR_VERMELHO")
    Private oAmarelo	:= LoadBitmap( GetResources(), "BR_AMARELO")
 
    DEFINE MSDIALOG oDlg TITLE "Cotação de Frete" FROM 000, 000  TO 300, 900  PIXEL
        //chamar a função que cria a estrutura do aHeader
        CriaCabec()
 
        //Monta o browser com inclusão, remoção e atualização
        oLista := MsNewGetDados():New( 053, 078, 415, 775, GD_INSERT+GD_DELETE+GD_UPDATE, "AllwaysTrue", "AllwaysTrue", "AllwaysTrue", aACampos,1, 999, "AllwaysTrue", "", "AllwaysTrue", oDlg, aCabecalho, aColsEx)
 
        //Carregar os itens que irão compor o conteudo do grid
        Carregar(cAtendimento)
 
        //Alinho o grid para ocupar todo o meu formulário
        oLista:oBrowse:Align := CONTROL_ALIGN_ALLCLIENT

        //Ao abrir a janela o cursor está posicionado no meu objeto
        oLista:oBrowse:SetFocus()
 
        //Crio o menu que irá aparece no botão Ações relacionadas
        aadd(aBotoes,{"NG_ICO_LEGENDA", {||Legenda()},"Legenda","Legenda"})
 
        EnchoiceBar(oDlg, {|| GravaDados()}, {|| Cancelar() },,aBotoes)

    ACTIVATE MSDIALOG oDlg CENTERED
Return


//##################################################################################################################
// FUNÇAO DE CRIAR CABEÇALHO
//##################################################################################################################
Static Function CriaCabec()
    Aadd(aCabecalho, {"Atendimento",;   //X3Titulo()
                  "ZCF_NUM",;   //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  6,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;		        //X3_VALID
                  "",;			    //X3_USADO
                  "C",;			    //X3_TIPO
                  "",; 			    //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Cód. Cliente",;  //X3Titulo()
                  "CODCLIENTE",;    //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  6,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "C",;			    //X3_TIPO
                  "",; 		    //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Nome Cliente",;  //X3Titulo()
                  "NOMECLIENTE",;   //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  25,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "C",;			    //X3_TIPO
                  "",; 		    //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"CNPJ",;	        //X3Titulo()
                  "CNPJ",;  	    //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  14,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "C",;			    //X3_TIPO
                  "",;		    //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Loja",;	        //X3Titulo()
                  "LOJA",;  	        //X3_CAMPO
                  "@!",;		        //X3_PICTURE
                  04,;			        //X3_TAMANHO
                  0,;			        //X3_DECIMAL
                  "",;			        //X3_VALID
                  "",;			        //X3_USADO
                  "C",;			        //X3_TIPO
                  "",;		            //X3_F3
                  "R",;			        //X3_CONTEXT
                  "",;			        //X3_CBOX
                  "",;			        //X3_RELACAO
                  ""})			        //X3_WHEN

    Aadd(aCabecalho, {"Produto",;	    //X3Titulo()
                  "PRODUTO",;  	        //X3_CAMPO
                  "@!",;		        //X3_PICTURE
                  04,;			        //X3_TAMANHO
                  0,;			        //X3_DECIMAL
                  "",;			        //X3_VALID
                  "",;			        //X3_USADO
                  "C",;			        //X3_TIPO
                  "",;		            //X3_F3
                  "R",;			        //X3_CONTEXT
                  "",;			        //X3_CBOX
                  "",;			        //X3_RELACAO
                  ""})			        //X3_WHEN

    Aadd(aCabecalho, {"Item",;	        //X3Titulo()
                  "ITEM",;  	        //X3_CAMPO
                  "@!",;		        //X3_PICTURE
                  04,;			        //X3_TAMANHO
                  0,;			        //X3_DECIMAL
                  "",;			        //X3_VALID
                  "",;			        //X3_USADO
                  "C",;			        //X3_TIPO
                  "",;		            //X3_F3
                  "R",;			        //X3_CONTEXT
                  "",;			        //X3_CBOX
                  "",;			        //X3_RELACAO
                  ""})			        //X3_WHEN

    Aadd(aCabecalho, {"Valor Pedido",;	//X3Titulo()
                  "ZCF_VALPED",;  	//X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",;		    //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Valor Frete",;   //X3Titulo()
                  "ZCF_VFRETE",;    //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  2,;			    //X3_DECIMAL
                  "",;		    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",; 			    //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO			    
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Volumes",;       //X3Titulo()
                  "ZCF_VOLUME",;    //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",; 		        //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Altura",;        //X3Titulo()
                  "ZCF_ALTURA",;    //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  2,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",; 		        //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Largura",;	    //X3Titulo()
                  "ZCF_LARGUR",;  	//X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  2,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",;		        //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Comprimento",;	//X3Titulo()
                  "ZCF_COMPRI",;  	//X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  2,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",;		        //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Peso",;	        //X3Titulo()
                  "ZCF_PESO",;  	//X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  10,;			    //X3_TAMANHO
                  2,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "N",;			    //X3_TIPO
                  "",;		        //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN

    Aadd(aCabecalho, {"Observações",;	//X3Titulo()
                  "ZCF_OBS",;  	    //X3_CAMPO
                  "@!",;		    //X3_PICTURE
                  50,;			    //X3_TAMANHO
                  0,;			    //X3_DECIMAL
                  "",;			    //X3_VALID
                  "",;			    //X3_USADO
                  "C",;			    //X3_TIPO
                  "",;		        //X3_F3
                  "R",;			    //X3_CONTEXT
                  "",;			    //X3_CBOX
                  "",;			    //X3_RELACAO
                  ""})			    //X3_WHEN
 
Return


//##################################################################################################################
// FUNÇAO DE CARREGAR DADOS
//##################################################################################################################
Static Function Carregar(cAtendimento)
    local aItemEProduto     := {}
    Local aItem             := {}
    local i                 := 0
    local z                 := 0
    Local c                 := 0
    Local cValPed           := space(12)
    Local cValFrete         := space(12)
    Local cVolume           := space(3)
    Local cAltura           := space(5)
    Local cLargura          := space(5)
    Local cComprimento      := space(5)
    Local cPeso             := space(8)
    Local cObs              := space(150)
    Local aAtendimento      := oCotacaoFrete:get("aAtendimento")

    //Verifica se é uma inclusão ou alteração.
    if aAtendimento[1][1] = 'inclui'

		if !Empty(cAtendimento)


            // NA INCLUSÃO DE CADASTRO É USADO O COD PASSADO PELO USUÁRIO PARA BUSCAR OS DADOS DO REGISTRO
			//Preenche as variaveis com o código do Cliente e Loja
			dbSelectArea("SUA")
			SUA->(dbSetOrder(1))
			if SUA->(dbSeek(xFilial("SUA") + cAtendimento))

				cCodCliente := SUA->UA_CLIENTE
				cLojCliente := SUA->UA_LOJA
            else
                Alert("O campo Orçamento/Atendimento não não encontrado!","ATENCAO")

			endif

            //Fecha a area da SUA
            if Select("SUA") > 0
                dbSelectArea("SUA")
                dbCloseArea()
            endif

			//Preenche as variaveis com Nome e CNPJ do cliente 
			dbSelectArea("SA1")
			SA1->(dbSetOrder(1))
			if SA1->(dbSeek(xFilial("SA1") + cCodCliente + cLojCliente))

				cNomeCliente    := SA1->A1_NOME
				cCNPJCliente    := SA1->A1_CGC

            else
                // Se não for cliente procura dos dados  na tabela de prospects
                dbSelectArea("SUS")
			    SUS->(dbSetOrder(1))
                SUS->(dbSeek(xFilial("SUS") + cCodCliente + cLojCliente))
                cNomeCliente    := SUS->US_NOME
				cCNPJCliente    := SUS->US_CGC

                //Fecha a area da SUS
                if Select("SUS") > 0
                    dbSelectArea("SUS")
                    dbCloseArea()
                endif

			endif

            //Fecha a area da SA1
            if Select("SA1") > 0
                dbSelectArea("SA1")
                dbCloseArea()
            endif

        else
            Alert("O campo Orçamento/Atendimento não pode estar vazio!","ATENCAO")
        endif

        //PEGA DADOS DOS ITENS DO PEDIDO PARA COMPOR O GRID
        dbSelectArea("SUB")
        SUB->(dbSetOrder(1))
        SUB->(dbGoTop())
        SUB->(dbSeek(xFilial("SUB") + cAtendimento))

            while !eof() .and. cAtendimento == SUB->UB_NUM

                cItemEProduto   :=  SUB->UB_ITEM    + "," +;
                                    SUB->UB_PRODUTO + "," +;
                                    cValPed         + "," +;
                                    cValFrete       + "," +;
                                    cVolume         + "," +;
                                    cAltura         + "," +;
                                    cLargura        + "," +;
                                    cComprimento    + "," +;
                                    cPeso           + "," +;
                                    cObs

                aadd( aItemEProduto, StrTokArr(cItemEProduto, ",") )
                dbselectarea("SUB")
                SUB->(dbskip())
            Enddo

        //Fecha a area da SUB
        if Select("SUB") > 0
            dbSelectArea("SUB")
            dbCloseArea()
        endif

    else
        // PARA ALTERAÇÃO DE CADASTRO É USADO O COD DO ATENDIMENTO PARA IDENTifICAR O REGISTRO
        cAtendimento := aAtendimento[1][2]

        //Preenche as variaveis com o código do Cliente e Loja
			dbSelectArea("SUA")
			SUA->(dbSetOrder(1))
			if SUA->(dbSeek(xFilial("SUA") + cAtendimento))

				cCodCliente := SUA->UA_CLIENTE
				cLojCliente := SUA->UA_LOJA

			endif

            //Fecha a area da SUA
            if Select("SUA") > 0
                dbSelectArea("SUA")
                dbCloseArea()
            endif

			///Preenche as variaveis com Nome e CNPJ do cliente 
			dbSelectArea("SA1")
			SA1->(dbSetOrder(1))
			if SA1->(dbSeek(xFilial("SA1") + cCodCliente + cLojCliente))

				cNomeCliente    := SA1->A1_NOME
				cCNPJCliente    := SA1->A1_CGC

            else
                // Se não for cliente procura dos dados  na tabela de prospects
                dbSelectArea("SUS")
			    SUS->(dbSetOrder(1))
                SUS->(dbSeek(xFilial("SUS") + cCodCliente + cLojCliente))
                cNomeCliente    := SUS->US_NOME
				cCNPJCliente    := SUS->US_CGC

                //Fecha a area da SUS
                if Select("SUS") > 0
                    dbSelectArea("SUS")
                    dbCloseArea()
                endif

			endif

            //PEGA DADOS DOS ITENS DO PEDIDO PARA COMPOR O GRID
            dbSelectArea("SUB")
            SUB->(dbSetOrder(1))
            SUB->(dbGoTop())
            SUB->(dbSeek(xFilial("SUB") + cAtendimento))

                while !eof() .and. cAtendimento == SUB->UB_NUM

                    c += 1
                    cItemEProduto    := SUB->UB_ITEM + "," + AllTrim(SUB->UB_PRODUTO)
                    aadd( aItem, StrTokArr(cItemEProduto, ","))

                    dbSelectArea("ZCF")
                    ZCF->(dbSetOrder(1))
                    ZCF->(dbGoTop())
                    dbSeek(xFilial("ZCF") + cAtendimento + aItem[c][1] )

                        cItemEProduto   +=  "," +;
                                            StrZero(ZCF->ZCF_VALPED,12,2)                                                           + "," +;
                                            StrZero(Iif(Empty(ZCF->ZCF_VFRETE) .or. ZCF->ZCF_VFRETE = 0,0,ZCF->ZCF_VFRETE),12,2)    + "," +;
                                            StrZero(ZCF->ZCF_VOLUME,3)                                                              + "," +;
                                            StrZero(ZCF->ZCF_ALTURA,5,2)                                                            + "," +;
                                            StrZero(ZCF->ZCF_LARGUR,5,2)                                                            + "," +;
                                            StrZero(ZCF->ZCF_COMPRI,5,2)                                                            + "," +;
                                            StrZero(ZCF->ZCF_PESO,8,2)                                                              + "," +;
                                            PADR(ZCF->ZCF_OBS,150," ")
                    if Select("ZCF") > 0
                        dbSelectArea("ZCF")
                        dbCloseArea()
                    endif

                    aadd( aItemEProduto, StrTokArr(cItemEProduto, ",") )
                    dbselectarea("SUB")
                    SUB->(dbskip())
                Enddo

            //Fecha a area da SUB
            if Select("SUB") > 0
                dbSelectArea("SUB")
                dbCloseArea()
            endif

            //Fecha a area da SA1
            if Select("SA1") > 0
                dbSelectArea("SA1")
                dbCloseArea()
            endif

	endif

    //Monta um array com os dados do atendimento e com os campos editáveis
    for z := 1 to len(aItemEProduto)

        aadd(aProdutos,{cAtendimento,;          //Atendimento
                        cCodCliente,;           //Cod cliente
                        cNomeCliente,;          //Nome Cliente
                        cCNPJCliente,;          //CNPJ
                        cLojCliente,;           //Loja
                        aItemEProduto[z][2],;   //Produto
                        aItemEProduto[z][1],;   //Item
                        aItemEProduto[z][3],;   //Valor pedido
                        aItemEProduto[z][4],;   //Valor Frete
                        aItemEProduto[z][5],;   //volumes
                        aItemEProduto[z][6],;   //altura
                        aItemEProduto[z][7],;   //largura
                        aItemEProduto[z][8],;   //comprimento
                        aItemEProduto[z][9],;   //peso
                        aItemEProduto[z][10]})  //Obs
    Next
 
    //Monta o array do aCols que vai popular o grid
    For i := 1 to len(aProdutos)
 
        aadd(aColsEx,{  aProdutos[i,1],;        //Atendimento
                        aProdutos[i,2],;        //Cod cliente
                        aProdutos[i,3],;        //Nome Cliente
                        aProdutos[i,4],;        //CNPJ
                        aProdutos[i,5],;        //Loja
                        aProdutos[i,6],;        //Produto
                        aProdutos[i,7],;        //Item
                        aProdutos[i,8],;        //Valor pedido
                        aProdutos[i,9],;        //Valor Frete
                        aProdutos[i,10],;       //volumes
                        aProdutos[i,11],;       //altura
                        aProdutos[i,12],;       //largura
                        aProdutos[i,13],;       //comprimento
                        aProdutos[i,14],;       //peso
                        aProdutos[i,15],.F.})   //Obs
        
    Next
 
    //Setar array do aCols do Objeto.
    oLista:SetArray(aColsEx,.T.)
 
    //Atualizo as informações no grid
    oLista:Refresh()
Return


//##################################################################################################################
// FUNÇAO DE GRAVA/ATUALIZA DADOS
//##################################################################################################################
Static function GravaDados(aProdutos)

    Local aColsAux      := oLista:aCols
    Local x             := 0
    Local y             := 0
    Local aAtendimento  := oCotacaoFrete:get("aAtendimento")
    local Fail          := 0

    // Verifica se existem valores vazios
    for y=1 to len(aColsAux)

        if  Empty(Alltrim(aColsAux[y][1]))  .or.;   //Atendimento
            Empty(Alltrim(aColsAux[y][6]))  .or.;   //Produto
            Empty(Alltrim(aColsAux[y][7]))  .or.;   //Item
            Empty(Alltrim(aColsAux[y][10])) .or.;   //volumes
            Empty(Alltrim(aColsAux[y][11])) .or.;   //altura
            Empty(Alltrim(aColsAux[y][12])) .or.;   //largura
            Empty(Alltrim(aColsAux[y][13])) .or.;   //comprimento
            Empty(Alltrim(aColsAux[y][14])) .or.;   //peso
            Empty(Alltrim(aColsAux[y][15])) .or.;   //Obs
            Empty(Alltrim(aColsAux[y][8]))          //Valor pedido

            Alert("Existem campos obrigatórios vazios, favor preencher!","ATENCAO")
            Fail:=1

        endif

    Next

    if Fail == 0

        for x=1 to len(aColsAux)

            //GRAVA REGISTRO NO BANCO DE DADOS	
            dbSelectArea("ZCF")
                if aAtendimento[1][1] <> 'inclui'
                    ZCF->(dbSetOrder(1))
                    ZCF->(dbSeek(xFilial("ZCF") + aColsAux[x][1] + aColsAux[x][7])) // POSICIONA NA "FILIAL + ATENDIMENTO + N° ITEM"

                    // Adiciona o valor 2(Alteração) ou 1(Solicitação) ao Status
                    if !Empty(aColsAux[x][9]) .and. aColsAux[x][9] <> "0"
                        cStatus = 2 //(Alteração)
                    else
                        cStatus = 1 //(Solicitação)
                    endif
                    // ALTERA UM REGISTRO NA TABELA, RecLock([Alias], [.T. = inclusão, .F. = manipulação])
                    RecLock("ZCF", .F.)
                        Begin Transaction
                            ZCF->ZCF_FILIAL  	:= xFilial("ZCF")
                            ZCF->ZCF_NUM	 	:= aColsAux[x][1]                                               //Atendimento
                            ZCF->ZCF_PRODUT	 	:= aColsAux[x][6]                                               //Produto
                            ZCF->ZCF_ITEM	 	:= Val(StrTran(AllTrim(aColsAux[x][7] ), ",", ".",,))           //Item
                            ZCF->ZCF_VOLUME  	:= Val(StrTran(AllTrim(aColsAux[x][10]), ",", ".",,))           //volumes
                            ZCF->ZCF_ALTURA	  	:= Val(StrTran(AllTrim(aColsAux[x][11]), ",", ".",,))           //altura
                            ZCF->ZCF_LARGUR	  	:= Val(StrTran(AllTrim(aColsAux[x][12]), ",", ".",,))           //largura
                            ZCF->ZCF_COMPRI		:= Val(StrTran(AllTrim(aColsAux[x][13]), ",", ".",,))           //comprimento
                            ZCF->ZCF_PESO  	    := Val(StrTran(AllTrim(aColsAux[x][14]), ",", ".",,))           //peso
                            ZCF->ZCF_OBS	  	:= cValtoChar(StrTran(AllTrim(aColsAux[x][15]), ",", ".",,))    //Obs
                            ZCF->ZCF_STATUS	  	:= cStatus                                                      //Status
                            ZCF->ZCF_VALPED		:= Val(StrTran(AllTrim(aColsAux[x][8]), ",", ".",,))            //Valor Pedido
                            //ZCF->ZCF_EMISSA	:= cDtEmissao                                                   //DTEmissão 
                            ZCF->ZCF_VFRETE  	:= Val(StrTran(AllTrim(aColsAux[x][9]), ",", ".",,))            //Valor Frete
                            if cStatus = 2
                                ZCF->ZCF_DTORC	:= cDtOrcamento                                         //DTOrçamento
                            endif
                            ZCF->ZCF_USRALT     := CUSERNAME                                            //Usuário de alteração
                        End Transaction
                    ZCF->(msUnlock())

                else

                    // Adiciona o valor 1(Solicitação) ao Status
                    cStatus := 1
                    // CRIA UM NOVO REGISTRO NA TABELA.
                    RecLock("ZCF", .T.)
                        Begin Transaction
                            ZCF->ZCF_FILIAL  	:= xFilial("ZCF")
                            ZCF->ZCF_NUM	 	:= aColsAux[x][1]                                       //Atendimento
                            ZCF->ZCF_PRODUT	 	:= aColsAux[x][6]                                       //Produto
                            ZCF->ZCF_ITEM	 	:= Val(StrTran(AllTrim(aColsAux[x][7] ), ",", ".",,))   //Item
                            ZCF->ZCF_VOLUME  	:= Val(StrTran(AllTrim(aColsAux[x][10]), ",", ".",,))   //volumes
                            ZCF->ZCF_ALTURA	  	:= Val(StrTran(AllTrim(aColsAux[x][11]), ",", ".",,))   //altura
                            ZCF->ZCF_LARGUR	  	:= Val(StrTran(AllTrim(aColsAux[x][12]), ",", ".",,))   //largura
                            ZCF->ZCF_COMPRI		:= Val(StrTran(AllTrim(aColsAux[x][13]), ",", ".",,))   //comprimento
                            ZCF->ZCF_PESO  	    := Val(StrTran(AllTrim(aColsAux[x][14]), ",", ".",,))   //peso
                            ZCF->ZCF_OBS	  	:= cValtoChar(StrTran(AllTrim(aColsAux[x][15]), ",", ".",,))   //Obs
                            ZCF->ZCF_STATUS	  	:= cStatus                                              //Status
                            ZCF->ZCF_VALPED		:= Val(StrTran(AllTrim(aColsAux[x][8]), ",", ".",,))    //Valor Pedido
                            ZCF->ZCF_EMISSA	  	:= cDtEmissao                                           //DTEmissão 
                            ZCF->ZCF_VFRETE  	:= Val(StrTran(AllTrim(aColsAux[x][9]), ",", ".",,))    //Valor Frete
                            if Empty(aColsAux[x][9])
                                ZCF->ZCF_DTORC	  	:= "-"                                              //DTOrçamento
                            endif
                            ZCF_USRCRI          := CUSERNAME                                            //Usuário de criação
                            ZCF->ZCF_USRALT     := CUSERNAME                                            //Usuário de alteração
                            
                        End Transaction
                    ZCF->(msUnlock())
                endif

            DbFechaArea()

        Next

        // Vereicica se o Alias esta aberto e o encerra
        If Select("ZCF") > 0
            dbSelectArea("ZCF")
            dbCloseArea()
        EndIf

        MsgInfo("Inclusão concluída com sucesso!","AVISO!")

        oDlg:End()

    endif

return


//##################################################################################################################
// FUNÇAO DE EXCLUI DADOS
//##################################################################################################################
Static function ExcluiDados()

    Local aExclui   := oCotacaoFrete:get("aExclui")
    Local cExclui   := aExclui[1][1]

	//SELECIONAMOS A TABEA/ÁREA
	dbSelectArea("ZCF")
        dbSetOrder(1)

        if !(dbSeek(xFilial("ZCF")+cExclui))
            Alert("Este registro não existe,"+Chr(13)+Chr(10)+"portanto não pode ser DELETADO!","ATENÇÃO!")
            DbFechaArea()
        else
        //GRAVA DELEÇÃO NO BANCO DE DADOS	
            if MsgYesNo("Tem certeza que quer DELETAR o registro?", "ATENÇÃO" )
                dbSelectArea("ZCF")
                while ZCF->ZCF_NUM == cExclui
                    RecLock("ZCF",.F.)  
                    
                        dbDelete() //função responsável pela deleção lógica

                    MsUnlock()
                    dbSkip()
                Enddo
                
                MsgInfo("Registro DELETADO com sucesso!","AVISO!")
            else
                MsgInfo("Deleção abortada pelo usuário!","AVISO!")
            endif
        endif

	DbFechaArea()

return


//##################################################################################################################
// FUNÇAO DE LEGENDA
//##################################################################################################################
Static function Legenda()
    Local aLegenda := {}
    aadd(aLegenda,{"BR_AMARELO"     ,"   AMARELP"   })
    aadd(aLegenda,{"BR_AZUL"    	,"   AZUL"      })
    aadd(aLegenda,{"BR_VERDE"    	,"   VERDE"     })
    aadd(aLegenda,{"BR_VERMELHO" 	,"   VERMELHO"  })
 
    BrwLegenda("Legenda", "Legenda", aLegenda)
Return Nil


//##################################################################################################################
// FUNÇAO PARA IMPRESSÃO DE RELATÓRIO
//##################################################################################################################
Static Function PrintReport()
	Local aArea         := GetArea()
	Local oReport       
	Local lEmail        := .F.
	Local cPara         := ""

	//Cria as definições do relatório
	oReport := fReportDef()

	//Será enviado por e-Mail?
	If lEmail
		oReport:nRemoteType := NO_REMOTE
		oReport:cEmail := cPara
		oReport:nDevice := 3 //1-Arquivo,2-Impressora,3-email,4-Planilha e 5-Html
		oReport:SetPreview(.F.)
		oReport:Print(.F., "", .T.)
		//Senão, mostra a tela
	Else
		oReport:PrintDialog()
	EndIf

	RestArea(aArea)
Return


//##################################################################################################################
// FUNÇAO QUE MONTA A DEFINIÇÃO DO RELATÓRIO
//##################################################################################################################
Static Function fReportDef()
	Local oReport
	Local oSectDad := Nil
	
	//Criação do componente de impressão
	oReport := TReport():New(	"Fretes Cotados por Período",;		//Nome do Relatório
								"Relatorio",;		//Título
								,;		//Pergunte ... Se eu defino a pergunta aqui, será impresso uma página com os parâmetros, conforme privilégio 101
								{|oReport| fRepPrint(oReport)},;		//Bloco de código que será executado na confirmação da impressão
								)		//Descrição
	oReport:SetTotalInLine(.F.)
	oReport:lParamPage := .F.
	oReport:oPage:SetPaperSize(9) //Folha A4
	oReport:SetLandscape()
	
	//Criando a seção de dados
	oSectDad := TRSection():New(	oReport,;		//Objeto TReport que a seção pertence
									"Dados",;		//Descrição da seção
									{"QRY_AUX"})		//Tabelas utilizadas, a primeira será considerada como principal da seção
	oSectDad:SetTotalInLine(.F.)  //Define se os totalizadores serão impressos em linha ou coluna. .F.=Coluna; .T.=Linha
	
	//Colunas do relatório
	TRCell():New(oSectDad, "EMIDATE"    , "QRY_AUX", "Data Solicitação", /*Picture*/		    , 20, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
    TRCell():New(oSectDad, "ORCDATE"    , "QRY_AUX", "Data Cotação"    , /*Picture*/		    , 20, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
	TRCell():New(oSectDad, "A3_NREDUZ"  , "QRY_AUX", "Vendedora"       , /*Picture*/		    , 20, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
    TRCell():New(oSectDad, "ZCF_NUM"    , "QRY_AUX", "Orçamento"       , /*Picture*/		    , 20, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
	TRCell():New(oSectDad, "UA_NUMSC5"  , "QRY_AUX", "Pedido"          , /*Picture*/            , 06, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
	TRCell():New(oSectDad, "A1_NOME"    , "QRY_AUX", "Cliente"         , /*Picture*/		    , 30, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
    TRCell():New(oSectDad, "ZCF_PESO"   , "QRY_AUX", "Peso do Volume"  , /*Picture*/		    , 06, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
	TRCell():New(oSectDad, "ZCF_VALPED" , "QRY_AUX", "Valor do Pedido" , "@E 999,999,999.99"    , 14, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
	TRCell():New(oSectDad, "ZCF_VFRETE" , "QRY_AUX", "Valor do Frete"  , "@E 999,999,999.99"    , 14, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)
	TRCell():New(oSectDad, "ZCF_OBS"    , "QRY_AUX", "Observações"     , /*Picture*/		    , 50, /*lPixel*/,/*{|| code-block de impressao }*/,/*cAlign*/,/*lLineBreak*/,/*cHeaderAlign */,/*lCellBreak*/,/*nColSpace*/,/*lAutoSize*/,/*nClrBack*/,/*nClrFore*/,/*lBold*/)


Return oReport


//##################################################################################################################
// FUNÇAO QUE IMPRIME O RELATÓRIO
//##################################################################################################################
Static Function fRepPrint(oReport)
	Local aArea    := GetArea()
	Local cQryAux  := ""
	Local oSectDad := Nil
	Local nAtual   := 0
	Local nTotal   := 0
    local aParamBox     := {}
    local aData         := {}
    local cDtInicio
    local cDtFim

    //Solicita ao usuário os Parâmetros para pesquisa.
    aAdd(aParamBox      ,{1,"Data Inicio" ,Ctod(Space(8)) ,"","","","",50,.F.})   // Tipo data
    aAdd(aParamBox      ,{1,"Data Fim"    ,Ctod(Space(8)) ,"","","","",50,.F.})   // Tipo data
    ParamBox(aParamBox  ,"Parametros de pesquisa.")

    cDtInicio       := DtoS(MV_PAR01) + " 00:00:00"
    cDtFim          := DtoS(MV_PAR02) + " 23:59:59"

    aAdd(aData, {DtoS(MV_PAR01) + " 00:00:00", "," , DtoS(MV_PAR01) + " 00:00:00"})

	//Pegando as seções do relatório
	oSectDad := oReport:Section(1)

        //Montando consulta de dados
        cQryAux :=  " SELECT	                                                                                                                                                        " + STR_PULA
        cQryAux +=  "ZCF_STATUS,                                                                                                                                                        " + STR_PULA
        cQryAux +=  "ZCF_NUM,                                                                                                                                                           " + STR_PULA
        cQryAux +=  "UA_CLIENTE,                                                                                                                                                        " + STR_PULA
        cQryAux +=  "A1_NOME,                                                                                                                                                           " + STR_PULA
        cQryAux +=  "A1_CGC,                                                                                                                                                            " + STR_PULA
        cQryAux +=  "US_NOME,                                                                                                                                                           " + STR_PULA
        cQryAux +=  " US_CGC,                                                                                                                                                           " + STR_PULA
        cQryAux +=  "UA_NUMSC5,A3_NREDUZ,                                                                                                                                               " + STR_PULA
        cQryAux +=  "CONCAT((CONVERT(VARCHAR,CONVERT(DATE,ZCF_EMISSA), 103)),' ',CONVERT(VARCHAR,CONVERT(TIME,ZCF_EMISSA), 108)) AS EMIDATE,                                            " + STR_PULA
        cQryAux +=  "CASE WHEN ZCF_DTORC = '-' THEN '-' else CONCAT(CONVERT(VARCHAR,CONVERT(DATE,ZCF_DTORC), 103), ' ' ,CONVERT(VARCHAR,CONVERT(TIME,ZCF_DTORC), 108)) END AS ORCDATE,  " + STR_PULA
        cQryAux +=  "ZCF_VFRETE,                                                                                                                                                        " + STR_PULA
        cQryAux +=  "ZCF_VALPED,                                                                                                                                                        " + STR_PULA
        cQryAux +=  "ZCF_PESO,                                                                                                                                                          " + STR_PULA
        cQryAux +=  "ZCF_OBS                                                                                                                                                            " + STR_PULA
        cQryAux +=  "FROM ZCF010 ZCF LEFT OUTER JOIN                                                                                                                                    " + STR_PULA
        cQryAux +=  "SUA010 SUA ON UA_FILIAL = ZCF_FILIAL AND ZCF_NUM = UA_NUM                                                                                                          " + STR_PULA
        cQryAux +=  "LEFT OUTER JOIN SA1010 SA1 ON A1_COD = UA_CLIENTE AND A1_LOJA = UA_LOJA AND A1_FILIAL = LEFT(UA_FILIAL,4) AND SA1.D_E_L_E_T_ = ''                                  " + STR_PULA
        cQryAux +=  "LEFT OUTER JOIN SUS010 SUS ON US_COD = UA_CLIENTE AND US_LOJA = UA_LOJA AND US_FILIAL = LEFT(UA_FILIAL,4) AND SUS.D_E_L_E_T_ = ''                                  " + STR_PULA
        cQryAux +=  "LEFT OUTER JOIN SA3010 SA3 ON UA_VEND = A3_COD AND LEFT(UA_FILIAL,4) = A3_FILIAL                                                                                   " + STR_PULA
        cQryAux +=  "WHERE ZCF_FILIAL = '" + %xFilial:CFILANT% + "'                                                                                                                     " + STR_PULA
        cQryAux +=  "AND ZCF_EMISSA >= '" + %EXP:cDtInicio% + "'                                                                                                                        " + STR_PULA
        cQryAux +=  "AND ZCF_EMISSA <= '" + %EXP:cDtFim% + "'                                                                                                                           " + STR_PULA
        cQryAux +=  "AND ZCF.D_E_L_E_T_ = ''                                                                                                                                            " + STR_PULA
        cQryAux +=  "AND ZCF_ITEM = '1'                                                                                                                                                 " + STR_PULA
        cQryAux +=  "AND ZCF_STATUS IN ('1','2','3')                                                                                                                                    " + STR_PULA
        cQryAux +=  "ORDER BY ZCF_EMISSA DESC                                                                                                                                           " + STR_PULA

	cQryAux := ChangeQuery(cQryAux)

	//Executando consulta e setando o total da régua
	TCQuery cQryAux New Alias "QRY_AUX"
	Count to nTotal
	oReport:SetMeter(nTotal)

	//Enquanto houver dados
	oSectDad:Init()
	QRY_AUX->(DbGoTop())
	While ! QRY_AUX->(Eof())
		//Incrementando a régua
		nAtual++

		//Imprimindo a linha atual
		oSectDad:PrintLine()
		
		QRY_AUX->(DbSkip())
	EndDo
	oSectDad:Finish()
	QRY_AUX->(DbCloseArea())
	
	RestArea(aArea)
Return


//##################################################################################################################
// FUNÇAO QUE FECHA AREA
//##################################################################################################################
Static function DbFechaArea()

	if Select("ZCF") > 0
		dbSelectArea("ZCF")
		dbCloseArea()
	endif

return


//##################################################################################################################
// FUNÇAO QUE CANCELA OPERAÇÃO
//##################################################################################################################
Static function Cancelar()

	oDlg:End()

    MsgInfo("Operação cancelada pelo usuário!","AVISO!")

return


//##################################################################################################################
// FUNÇAO QUE RESETA A PAGINA COM UMA NOVA CONSULTA.
//##################################################################################################################
    //Static function ResetarPag()
    //
    //    If oModal <> NIL
    //        oModal:MSDialog():End()  
    //        FreeObj(oModal)
    //        oModal := Nil  
    //    EndIf
    //
    //    U_TCTL01()
    //
//return

//##################################################################################################################
// FUNÇAO QUE VERIFICA E ATUALIZA O STATUS
//##################################################################################################################
Static function Statuscheck()

    local cResultados   := ''
    local s             := 0
    local aResultados   := {}

    BEGINSQL ALIAS "SQL_ZCF2"
    SELECT
        ZCF_FILIAL, 
		ZCF_NUM,
		ZCF_VFRETE,
		ZCF_STATUS,
        R_E_C_N_O_
		FROM ZCF010
			WHERE ZCF_FILIAL = %EXP:CFILANT%                                                                           
            AND ZCF_EMISSA >= %EXP:cDtInicio%                                                                           
            AND ZCF_EMISSA <= %EXP:cDtFim%                                                                              
            AND D_E_L_E_T_ = ''            
			AND ZCF_VFRETE  != '0'
			AND ZCF_STATUS  = '1'
    ENDSQL

    // Se houver dados preenche a variável cResultados com o RECNO dos itens filtrados no SQL
    if ! SQL_ZCF2->(EoF())

        SQL_ZCF2->( dbGoTop() )

            While ! SQL_ZCF2->(EoF())

                cResultados := cValToChar(SQL_ZCF2->R_E_C_N_O_) + ', '

                aadd( aResultados, StrTokArr(cResultados, ",") )

                SQL_ZCF2->(DbSkip())

            EndDo

        SQL_ZCF2->( dbCloseArea() )

    endif

    for s=1 to len(aResultados)

        dbSelectArea("ZCF")
        ZCF->(dbgotop())
        ZCF->(dbgoto(Val(aResultados[s][1])))
            RecLock("ZCF", .F.)
                Begin Transaction

                    ZCF->ZCF_STATUS := 2

                End Transaction
        ZCF->(msUnlock())
 
    next

    //Fecha alias
    If Select("SQL_ZCF2") > 0
        dbSelectArea("SQL_ZCF2")
        dbCloseArea()
    EndIf

return

// Classe WebComponent
Class CotacaoFrete
    data mainHTML
    data mainData
    data tmp

    Method Constructor() CONSTRUCTOR
    Method OnInit()     // Instanciado pelo bLoadFinished 
    Method Template()   // HTML inicial
    Method Script()     // JS inicial
    Method Style()      // Style inicial

    Method Get()
    Method Set()

    Method SaveFile(cContent)
    Method GetOS()
endClass

// Construtor
Method Constructor() class CotacaoFrete
    local cMainHTML
    ::tmp := GetTempPath()
    ::mainHTML := ::tmp + lower(getClassName(self)) + ".html"
    ::mainData := {} // Array com as variaveis globais (State)
 
    // ----------------------------------------------------
    // Importante: Compile o twebchannel.js em seu ambiente
    // ----------------------------------------------------
    // Baixa do RPO o arquivo twebchannel.js e salva no TEMP
    // Este arquivo eh responsavel pela comunicacao AdvPL x JS
    h := fCreate(iif(::GetOS()=="UNIX", "l:", "") + ::tmp + "twebchannel.js")
    fWrite(h, GetApoRes("twebchannel.js"))
    fClose(h)

    // HTML principal
    cMainHTML := ::Script() + chr(10) +;
                 ::Style() + chr(10) +;
                 ::Template()

    // Verifica se o HTML principal foi criado
    if !::SaveFile(cMainHTML)
        msgAlert("Arquivo HTML principal nao pode ser criado")
    endif
return

// Instanciado apos a carga da pagina HTML
Method OnInit(webengine, url) class CotacaoFrete
    // Desabilita pintura evitando refreshs desnecessarios
    webengine:SetUpdatesEnable(.F.)

    // -------------------------------------------------------------------
    // Importante: Acoes que dependam da carga devem ser instanciadas aqui
    // -------------------------------------------------------------------

    // Processa mensagens pendentes e reabilita pintura
    ProcessMessages()
    sleep(300)
    webengine:SetUpdatesEnable(.T.)
return

// Pagina HTML inicial
Method Template() class CotacaoFrete
    
    BeginContent var cHTML
        <script src="twebchannel.js"></script>
        <script>
            var relacao_geral
            var consulta_fornecedor
            

            window.onload = function() {
                
                relacao_geral = document.getElementById('relacao-geral');
                consulta_fornecedor = document.getElementById('consulta-fornecedor')

                // Estabelece conexao entre o AdvPL e o JavaScript via WebSocket
                twebchannel.connect( () => { console.log('Websocket Connected!'); } );
                twebchannel.advplToJs = function(key, value) {

                    // ----------------------------------------------------------
                    // Insira aqui o tratamento para as mensagens vindas do AdvPL
                    // ----------------------------------------------------------
                    if (key === "<script>") {
                        let tag = document.createElement('script');
                        tag.setAttribute("type", "text/javascript");
                        tag.innerText = value;
                        document.getElementsByTagName("head")[0].appendChild(tag);
                    }
                    else if(key === "<relacao-geral>") {
                        relacao_geral.innerHTML  = value
                        
                    }
                    else if(key === "<consulta-fornecedor>") {
                       
                        consulta_fornecedor.innerHTML   = value
                    }
                   
                }
            };
        </script>
        <body style='background-color: #d1e6cc;'>
            <div class='flex-contariner'>
                <nav class="navbar navbar-dark justify-content-center" style='background-color: #217b4b;'>
                    <div>
                        <h3 class="navbar-brand">Orçamentos de Frete.</h3>
                    </div>
                </nav>
            </div>

            <div id="relacao-geral"></div>

            <div class="container">

                <div id="consulta-fornecedor"></div>
               
            </div>
        
    EndContent

return cHTML


// Scripts
Method Script() class CotacaoFrete
    BeginContent var cScript

        <script>
            // [*Submit]
            onClickSubmit = (e, form) => {
                e.preventDefault()
                
                // Varre itens preenchidos
                let elements = form.elements
                let retToAdvpl = ""
                for(let i = 0 ; i < elements.length ; i++){
                    let item = elements.item(i)
                    if (form.elements[i].type != "submit"){
                        retToAdvpl += item.value

                        //Se o proximo elemento for um submit nao insere o separador
                        if (form.elements[i+1].type != "submit"){
                            retToAdvpl += ","
                        }
                    }
                }

                // Retorna informacoes do Form para o AdvPL
                
                twebchannel.jsToAdvpl("<submit>", retToAdvpl)
                form.reset()
                document.getElementById("pedido").focus()
                return false
            }

            // Adiciona a função truncate para restringir o tamanho das celulas de observação
            var truncate = document.querySelectorAll(".truncate");
            truncate = [].slice.apply(truncate);
            truncate.forEach(function (elemento, indice) {
            elemento.title = elemento.innerHTML;
            })
            .truncate {
            display: block;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;  
            }
        </script>
    EndContent
return cScript   

// Estilos
Method Style() class CotacaoFrete
    BeginContent var cStyle


        <!--// Links Bootstrap que adicionam css e js com resposividade.-->
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-MrcW6ZMFYlzcLA8Nl+NtUVF0sA7MsXsP1UyJoMp4YLEuNSfAP+JcXn/tWtIaxVXM" crossorigin="anonymous"></script>
        
        <style>
           <!-- Adicionar estilos personalizados aqui-->
            body {
                background: #488d36;
            }
            .flex-container {
                display: flex;
                background-color: #488d36;
                
            }
            h3 {
                text-align: center;
            }
            /* Dropdown Button */
            .dropbtn {
            background-color: #217b4b;
            color: white;
            padding: 16px;
            font-size: 16px;
            border: none;
            margin: 16px;
            }

            /* The container <div> - needed to position the dropdown content */
            .dropdown {
            position: relative;
            display: inline-block;
            }

            /* Dropdown Content (Hidden by Default) */
            .dropdown-content {
            display: none;
            position: absolute;
            background-color: #f1f1f1;
            min-width: 160px;
            box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
            z-index: 1;
            }

            /* Links inside the dropdown */
            .dropdown-content a {
            color: black;
            padding: 12px 16px;
            text-decoration: none;
            display: block;
            }

            /* Change color of dropdown links on hover */
            .dropdown-content a:hover {background-color: #ddd;}

            /* Show the dropdown menu on hover */
            .dropdown:hover .dropdown-content {display: block;}

            /* Change the background color of the dropdown button when the dropdown content is shown */
            .dropdown:hover .dropbtn {background-color: #3e8e41;}

        </style>

    EndContent
return cStyle

// Getter [*Getter_and_Setter]
Method Get(cVarname) class CotacaoFrete
    // Recupera valor do array global (State)
    local nPosBase := AScan( ::mainData, {|x| x[1] == cVarname} )
    if nPosBase > 0
        return ::mainData[nPosBase, 2]
    endif
return ""

// Setter [*Getter_and_Setter]
Method Set(cVarname, xValue, bUpdate) class CotacaoFrete
    // Define/Atualiza valor do array global (State)
    local nPosBase := AScan( ::mainData, {|x| x[1] == cVarname} )
    if nPosBase > 0
        if valType(xValue) == "A"
            ::mainData[nPosBase, 2] := aClone(xValue)
        else
            ::mainData[nPosBase, 2] := xValue
        endif
    else
        Aadd(::mainData, {cVarname, xValue})
    endif
    // Zera variavel global
    xValue := {}
    
    // Dispara bloco de codigo customizado
    // apos atualizacao do valor
    if valtype(bUpdate) == "B"
        eval(bUpdate)
    endif
return

// Salva arquivo em disco
Method SaveFile(cContent) class CotacaoFrete
    local nHdl := fCreate(iif(::GetOS()=="UNIX", "l:", "") + ::mainHTML)
    if nHdl > -1
        fWrite(nHdl, cContent)
        fClose(nHdl)
    else
        return .F.
    endif
return .T.

// Retorna Sistema Operacional em uso
Method GetOS() class CotacaoFrete
    local stringOS := Upper(GetRmtInfo()[2])

    if GetRemoteType() == 0 .or. GetRemoteType() == 1
        return "WINDOWS"
    elseif GetRemoteType() == 2 
        return "UNIX" // Linux ou MacOS		
    elseif GetRemoteType() == 5 
        return "HTML" // Smartclient HTML		
    elseif ("ANDROID" $ stringOS)
        return "ANDROID" 
    elseif ("IPHONEOS" $ stringOS)
        return "IPHONEOS"
    endif    
return ""

