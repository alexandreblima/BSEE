$NOMOD51

;*****************************************************************************
;*****************************************************************************
;*                                                                           *
;*    UNIVERSIDADE DE SAO PAULO-ESCOLA POLITECNICA                           *
;*    DEPARTAMENTO DE ENGENHARIA ELETRONICA                                  *
;*    PEE528-LABORATORIO DE PROJETO DE FORMATURA  1996                       *
;*                                                                           *
;*    PROGRAMA DE COMUNICACAO FULL DUPLEX SERIAL ASSINCRONA C/ MODEM         *
;*                   (PROCESSADOR 89C52)                                     *
;*                                                                           *
;*    APLICACAO: TESTE FINAL PROJETO DO SCRAMBLER DIGITAL                    *
;*                                                                           *
;*    ROTINAS EM ASSEMBLER ASM51                                             *
;*                                                                           *
;*    ARQUIVO:     7TX3.A51   VERSAO: 1.0      REVISAO:3/12/96               *
;*    PROGRAMADORES: ALEXANDRE,MANSI E CELSO       DATA:3-12-96              *
;*                                                                           *
;*    OBS:  GRAVAR NA PLACA 2                                                *
;*                                                                           *
;*                                                                           *
;*****************************************************************************
;*****************************************************************************

           ;      NAME    7TX3

;****************************************************************
;****************************************************************
;*                                                              *
;*                  DEFINICAO DE CONSTANTES                     *
;*                                                              *
;****************************************************************
;****************************************************************

;****   DEFINICAO DO PROCESSADOR

$INCLUDE(REG52.PDF)

;****   DECLARACOES DE CONSTANTES


MAX_TX          EQU     255     ; FILA CIRCULAR DE TX DE COMPRIMENTO 255
MAX_RX          EQU     255     ; FILA CIRCULAR DE RX DE COMPRIMENTO 255

SEMENTE         EQU     88H     ; SEMENTE DOS REGISTRADORES DE DESLOCAMENTO


;****   ENDERECO DO CHIP DA ALTERA (MEMORY MAPPED I/O )

END_ALT         EQU     8000H   ; IF (A15 = 0) =>ACESSA MEMORIA 62256
                                ;  ELSE =>ACESSA ALTERA 


;*****          CONSTANTES DE DEFINICAO DOS VETORES DE INTERRUPCAO

INT_E0_NUMBER   EQU     0       ;NUMERO DO VETOR DE INT. EXTERNA 0
INT_T0_NUMBER   EQU     1       ;NUMERO DO VETOR DE INT. DO TIMER T0
INT_E1_NUMBER   EQU     2       ;NUMERO DO VETOR DE INT. EXTERNA 1
INT_T1_NUMBER   EQU     3       ;NUMERO DO VETOR DE INT. DO TIMER T1
INT_SR_NUMBER   EQU     4       ;NUMERO DO VETOR DE INT. SERIAL
INT_T2_NUMBER   EQU     5       ;NUMERO DO VETOR DE INT. DO TIMER T2



;***    CONSTANTES PARA T1 GERAR BAUD-RATE

BAUD_9600       EQU     0FDH    ;  9600
BAUD_4800       EQU     0FAH    ;  4800
BAUD_2400       EQU     0F4H    ;  2400
BAUD_1200       EQU     0E8H    ;  1200
BAUD_600        EQU     0D0H    ;  600
BAUD_300        EQU     0A0H    ;  300
BAUD_150        EQU     040H    ;  150


;***    CONSTANTES PARA T2 GERAR CLOCK EXTERNO

HIGH_9600       EQU     0FEH    ; PARA GERAR CLOCK DE 9600 , (RCAP2H,RCAP2L) =  
LOW_9600        EQU     0E0H    ; FEE0H = 65248


;
;****   CONSTANTES DE DEFINICAO DOS PORTS
;

;  PORT 0: MULTIPLEXA DADOS E ENDERECOS
;          OS DADOS SAO O BYTE ENTREGUE AO UC PELO S/P DO ALTERA E O
;          BYTE RECEBIDO PELO UC ENTREGUE AO P/S DO ALTERA  
;          O ALTERA E'MAPEADO COMO MEMORIA  
;           
AD0             EQU     P0_0    ;IN/OUT
AD1             EQU     P0_1    ;IN/OUT
AD2             EQU     P0_2    ;IN/OUT
AD3             EQU     P0_3    ;IN/OUT 
AD4             EQU     P0_4    ;IN/OUT  
AD5             EQU     P0_5    ;IN/OUT   
AD6             EQU     P0_6    ;IN/OUT   
AD7             EQU     P0_7    ;IN/OUT   


CLK_OUT         EQU     P1_0    ;OUT    CLOCK EXTERNO PARA O ALTERA E CODECS
CLRN            EQU     P1_2    ;OUT    DA' RESET NO ALTERA
OVFL            EQU     P1_4    ;OUT    LED SINALIZA OVERFLOW (VIDE BIT
                                ;       DE OVERFLOW) 


A8              EQU     P2_0    ;OUT    
A9              EQU     P2_1    ;OUT    
A10             EQU     P2_2    ;OUT    
A11             EQU     P2_3    ;OUT    
A12             EQU     P2_4    ;OUT     
A13             EQU     P2_5    ;OUT     
A14             EQU     P2_6    ;OUT     
A15             EQU     P2_7    ;OUT    SE A15=1 LE OU ESCREVE NO ALTERA  

   
RX              EQU     P3_0    ;IN     RXD
TX              EQU     P3_1    ;OUT    TXD
INT_TX          EQU     P3_2    ;IN     HA BYTE PRONTO PARA ENTRAR NA FILA_TX
INT_RX          EQU     P3_3    ;IN     ALTERA QUER RECEBER BYTE DA FILA_RX  
INICIA_TX_MODEM EQU     P3_4    ;IN     INICIA PEDIDO DE CONEXAO DO MODEM
LED_MODEM       EQU     P3_5    ;OUT    LIGA QUANDO MODEM ON
;esc            EQU     P3_6    ;OUT    SINAL DE ESCRITA EM MEMORIA
;le             EQU     P3_7    ;OUT    SINAL DE LEITURA EM MEMORIA



;****************************************************************
;****************************************************************
;*                                                              *
;*                  DEFINICAO DE VARIAVEIS                      *
;*                                                              *
;****************************************************************
;****************************************************************

;*****************************************************************************
;*****          AREA ABSOLUTA DA MEMORIA MAIN (RAM INTERNA)
;*****************************************************************************


                DSEG    AT      (30H)   ;ENDERECO 48

FILA_TX_F:      DS      1               ;APONTA O ENDERECO DE LEITURA (FRONT)  
FILA_TX_R:      DS      1               ;APONTA O ENDERECO DE ESCRITA (REAR)
FILA_TX_C:      DS      1               ;CONTROLA O NUMERO DE BYTES A
                                        ;TRANSMITIR DA FILA DE TX

FILA_RX_F:      DS      1               ;IDEM AOS DE TX    
FILA_RX_R:      DS      1               
FILA_RX_C:      DS      1               

?PUT_TX?BYTE:   DS      1               ;BYTE: ALTERA => ATMEL 
?PUT_RX?BYTE:   DS      1               ;BYTE: ATMEL =>ALTERA

SHIFT_REG_TX:   DS      1               ;REGISTRADOR DE DESLOCAMENTO TX
SHIFT_REG_RX:   DS      1               ;REGISTRADOR DE DESLOCAMENTO RX

CONT:           DS      1               ;CONTADOR PARA TX DE STRING

MSG_MODEM:      DS      1               ;BYTE MENSAGEM DO MODEM

CONT_BYTE_RX:   DS      1               ;NUMERO DE BYTES RECEBIDOS
CONT_BYTE_TX:   DS      1               ;NUMERO DE BYTES TRANSMITIDOS   

;*****  VARIAVEIS MAPEADAS SOBRE A AREA DE BITS[0F..08]
;
                DSEG    AT      (21H)
                


;*****************************************************************************
;*****          DEFINICAO DAS VARIAVEIS TIPO BIT (MEMORIA INTERNA)
;*****************************************************************************

                BSEG    AT      (0)
                
                
TX_ON:          DBIT    1               ;SE TX_ON = 0 =>FILA TX VAZIA

OVERFLOW:       DBIT    1               ;SE OVERFLOW = 0 => INDICA QUE O 
                                        ;PONTEIRO DE ESCRITA ATROPELOU O
                                        ;O PONTEIRO DE LEITURA.NA ETAPA 5
                                        ;NAO OCORRERA POIS OS UCs ESTAO A 
                                        ;19,2 Kbps. PODERA ACONTECER NA 
                                        ;ETAPA 6 SE OS MODENS ESTIVEREM 
                                        ;A MENOS DE 9600    

INIT_MODEM:     DBIT    1               ;SE INIT_MODEM = 1 ->INTERRUPCAO 
                                        ;SERIAL TRATA INICIALIZACAO DO
                                        ;MODEM, SE INIT_MODEM = 0
                                        ;INT SERIAL TRATA DE DADOS DE VOZ

REC_BYTE:       DBIT    1               ;SE BYTE FOI RECEBIDO E SETADO 

TESTE:          DBIT    1               ; BIT DE TESTE


PERDEU_SINC:           DBIT     1
SCRAMBLER_READY:       DBIT     1
WAIT_S:                DBIT     1
;SCRAMB_TX_READY:       DBIT     1
;SCRAMB_RX_READY:       DBIT     1 
;MANDOU_1:              DBIT     1
;RECEBEU_1:             DBIT     1
;MANDOU_2:              DBIT     1
;MANDOU_3:              DBIT     1
;RECEBEU_3:             DBIT     1
;MANDOU_FF:             DBIT     1


;****************************************************************************
;****         AREA DE MEMORIA EXTERNA
;****************************************************************************


FILA_TX        EQU     4000H            
FILA_RX        EQU     4100H           



;*****************************************************************************
;*****          DEFINICAO DA AREA DE PILHA DO PROGRAMA
;*****************************************************************************

                
;               PILHA INICIA NO ENDERECO DE RESET 07



;****************************************************************
;****************************************************************
;*                                                              *
;*                  VETORES DE INTERRUPCAO                      *
;*                                                              *
;****************************************************************
;****************************************************************

                CSEG    AT      0000H


                AJMP    INICIALIZACAO   ;RESET

                CSEG    AT      (8 * INT_E0_NUMBER + 3)
                
                RETI                    ;INT. EXTERNA 0 --> INIBIDA

                CSEG    AT      (8 * INT_T0_NUMBER + 3)

                RETI                    ;INT. TIMER 0   --> INIBIDA

                CSEG    AT      (8 * INT_E1_NUMBER + 3)

                RETI                    ;INT. EXTERNA 1 --> INIBIDA

                CSEG    AT      (8 * INT_T1_NUMBER + 3)

                RETI                    ;INT. TIMER 1   --> INIBIDA

                CSEG    AT      (8 * INT_SR_NUMBER + 3)

                AJMP    INT_SR          ;INT. SERIAL    --> 

                CSEG    AT      (8 * INT_T2_NUMBER + 3)

                RETI                    ;INT. TIMER 2   --> INIBIDA

  
                
;****************************************************************
;****************************************************************
;*                                                              *
;*           INICIO DO CODIGO A PARTIR DE RESET                 *
;*                                                              *
;****************************************************************
;****************************************************************
                

                CSEG    AT      0100H

INICIALIZACAO:  MOV     PSW,#0
                MOV     SP,#7FH
                
                CLR     P1_5              ;SINALIZA RI
                CLR     P1_6              ;SINALIZA TI
                CLR     P1_7              ;SINALIZA PERDA DE SINCRONISMO
                
                CLR     SCRAMBLER_READY
                SETB    EA                ;HABILITA INT SERIAL
                SETB    ES                ;HABILITA TODAS AS INTERRUPCOES
                SETB    INIT_MODEM        ;INICIALIZACAO DO MODEM
                CLR     REC_BYTE
                CLR     LED_MODEM
                SETB    TESTE
                


;*****          PROGRAMACAO DO TIMER 1
               
                MOV     TMOD,#00100000B   ;TIMER 1 NO MODO 2 ,TEMPORIZADOR
                                          ;DE 8 BITS COM RECARGA AUTOMATICA
                                          ;P/ GERAR A TAXA DE TRANSMISSAO
                                          ;NO CANAL SERIAL 
                
                MOV     PCON,#10000000B   ;SMOD = 1 =>E'NECESSARIO PARA GERAR
                                          ;TAXA DE 19,2 Kbps NO SERIAL                                           

                MOV     TL1,#BAUD_9600    ;COM Fosc = 11.0952 MHz =>19,2Kbps 
                MOV     TH1,#BAUD_9600
                SETB    TR1               ;TIMER 1 RODANDO
                    
;*****          PROGRAMACAO DO CANAL  SERIAL FULL DUPLEX - REG SCON
        
                CLR     SM2    ;DESABILITA MODO COMUNICACAO MULTIPROCESSADOR 
                
                CLR     SM0    ;PROGRAMA MODO 1: 1 START BIT, 8 BITS DE DADOS
                SETB    SM1    ;E 1 STOP BIT            
                CLR     TI     
                CLR     RI
                SETB    REN    ;HABILITA RECEPCAO SERIAL


;******         INICIALIZACAO DO MODEM                    


                ACALL   START_MODEM
                SETB    LED_MODEM

WAIT_COM:       JB      TESTE,INIT_TX_MODEM ;SE SINAL DE BOTAO EXT ATIVAR
                                           ;P3_4O MODEM LOCAL INICIA TX 
                                           ;PARA MODEM REMOTO
                JB      REC_BYTE,LOOK_14400;MODEM ESPERA RECEBER MENSAGEM 
                                           ; DE CONEXAO A 14400
                SJMP    WAIT_COM




MODEM_ON:       CLR     INIT_MODEM
                AJMP    SINC_SCRAMB

;
;************** ROTINA DE ENVIO DE STRING PARA O MODEM

TX_STRING:      MOV    CONT,#0 

LOOP:           MOV    A,CONT
                MOVC   A,@A+DPTR
                JZ     FIM
                MOV    SBUF,A   
                JNB    TI,$
                INC    CONT
                SJMP   LOOP                        
FIM:            RET


;************** ROTINA DE INICIALIZACAO DO MODEM

S_AT:           DB      'ATZ0&F0',0DH,0        ;Z0 => RESET MODEM
                                               ;&F0 => CARREGA PERFIL 0 DE 
                                               ;FABRICA
                                               ;&N8=> OPERACAO 14400
                                               ;V0 RESPOSTA DIGITOS
                                               ;O = ORIGINATE

START_MODEM:    MOV     DPTR,#S_AT            
                ACALL   TX_STRING

VOLTA_1:        ACALL   WAIT_BYTE
                CJNE    A,#'O',VOLTA_1         ;ENQUANTO NAO RECEBER OK DO
                                               ;MODEM NAO CONTINUA
                ACALL   WAIT_BYTE
                CJNE    A,#'K',START_MODEM

                RET
     

;********* ROTINA QUE DA' UMA PAUSA DE ~1 SEGUNDO

WAIT_1SEG:      CLR     TR0                     ;PARA T0
                CLR     TF0                     ;LIMPA FLAG DE OVERFLOW DE T0
                
                MOV     A,TMOD
                ANL     A,#11110000B            ;PRESERVA CONTROLES DO T1
                ORL     A,#00000010B            ;E SETA T0 PARA MODO 2
                MOV     TMOD,A
                
                MOV     TH0,#0                  ;ZERA VALOR DE AUTO-RELOAD
                
                SETB    TR0                     ;PARTIU T0
                
                MOV     DPTR,#(-4000)           ;PREPARA PARA CONTAR 4000
                
LOOP_WAIT_1S:   JNB     TF0,$                   ;ESPERA OVERFLOW DE T0
                CLR     TF0                     ;LIMPA OVERFLOW DE T0
                INC     DPTR                    ;AVANCA CONTADOR DE LOOP
                MOV     A,DPL                   ;SE DPTR NAO ALCANCOU 0000H
                ORL     A,DPH                   ;TEMPORIZA + UM POUCO
                JNZ     LOOP_WAIT_1S
                
                CLR     TR0                     ;PARA T0
                
                RET
                


;********* ROTINA QUE COMECA UMA TX VIA MODEM LOCAL

S_ATTX:         DB      'ATO',0DH,0

INIT_TX_MODEM:  ACALL   WAIT_1SEG
                MOV     DPTR,#S_ATTX
                
                ACALL   TX_STRING

VOLTA_2:        ACALL   WAIT_BYTE
                SJMP    LOOK_14400
                

LOOK_14400:    ; MOV     A,MSG_MODEM
                CJNE    A,#'C',VOLTA_2
                ACALL   WAIT_BYTE
               ; MOV     A,MSG_MODEM
                CJNE    A,#'O',VOLTA_2
                ACALL   WAIT_1SEG
                ACALL   WAIT_1SEG
                ACALL   WAIT_1SEG
                AJMP    MODEM_ON
                


WAIT_BYTE:      JNB     REC_BYTE,$      ;ESPERA FLAG DE BYTE PRONTO POR INT RX
                CLR     REC_BYTE        ;LIMPA FLAG
                MOV     A,MSG_MODEM     ;LE BYTE E DEVOLVE NO ACC
                RET
                

;********* ROTINA QUE DA' UMA PAUSA DE 2 MILISEGUNDOS

WAIT_2MSEG:     CLR     TR0                     ;PARA T0
                CLR     TF0                     ;LIMPA FLAG DE OVERFLOW DE T0
                
                MOV     A,TMOD
                ANL     A,#11110000B            ;PRESERVA CONTROLES DO T1
                ORL     A,#00000010B            ;E SETA T0 PARA MODO 2
                MOV     TMOD,A
                
                MOV     TH0,#0                  ;ZERA VALOR DE AUTO-RELOAD
                
                SETB    TR0                     ;PARTIU T0
                
                MOV     DPTR,#(-8)              ;PREPARA PARA CONTAR 8
                
LOOP_WAIT_2MS:  JNB     TF0,$                   ;ESPERA OVERFLOW DE T0
                CLR     TF0                     ;LIMPA OVERFLOW DE T0
                INC     DPTR                    ;AVANCA CONTADOR DE LOOP
                MOV     A,DPL                   ;SE DPTR NAO ALCANCOU 0000H
                ORL     A,DPH                   ;TEMPORIZA + UM POUCO
                JNZ     LOOP_WAIT_2MS
                
                CLR     TR0                     ;PARA T0
                
                RET




;****************************************************************
;*                                                              *
;*              SINCRONISMO DO SCRAMBLER                        * 
;*                                                              *
;****************************************************************


SINC_SCRAMB:    NOP
                ;CLR     SCRAMB_TX_READY
                ;CLR     SCRAMB_RX_READY
                ;CLR     MANDOU_1
                ;CLR     RECEBEU_1
                ;CLR     MANDOU_2
                ;CLR     MANDOU_3
                ;CLR     RECEBEU_3
                ;CLR     MANDOU_FF
                
                              
;*****          FICA MANDANDO CARACTERE '1', AT RECEBER '2' DE RESPOSTA
                
;ESPERA_RX_2:    JB      MANDOU_1,ESPERA_RX_2
;                MOV     SBUF,#0FFH
;                SETB    MANDOU_FF
;                JB      MANDOU_FF,$ 
;                MOV     SBUF,#'1'           ; MANDA BYTE DE SINCRONISMO '1'
;                SETB    MANDOU_1
                
;                JNB     SCRAMB_TX_READY,ESPERA_RX_2               
                
                
;*****          MANDA  CARACTERE 1, ESPERA CARACTERE 2

                MOV     SBUF,#'1'           ; MANDA BYTE DE SINCRONISMO '1'

RX_BYTE_2:      ACALL   WAIT_BYTE


;*****          TRATAMENTO DO CARACTERE RECEBIDO 2 (RESPOSTA AO 
;               '1'TRANSMITIDO)                
     
                CJNE    A,#'2',RX_BYTE_2
               
;
;*****          MANDA BYTE DE INICIO DE SCRAMBLER: BYTE '3'
;               DEPOIS DE RECEBER A RESPOSTA 3 TUDO E CRIPTOGRAFADO
                
                MOV     SBUF,#'3'
                
RX_BYTE_3:      ACALL   WAIT_BYTE
                
;*****          TRATAMENTO DO CARACTERE RECEBIDO 3

                CJNE    A,#'3',RX_BYTE_3
                       
                MOV     SHIFT_REG_TX,#SEMENTE    ;CARREGA VALOR INICIAL
                MOV     SHIFT_REG_RX,#SEMENTE    ;PARA EMBARALHAMENTO

                MOV     CONT_BYTE_TX,#0           
                MOV     CONT_BYTE_RX,#0                 
                CLR     PERDEU_SINC
                CLR     WAIT_S
                SETB    SCRAMBLER_READY
                
              
;*************** INICIALIZA FULL-DUPLEX

INIC_FD:        CLR     EA               ;INIBE TODAS AS INTERRUPCOES                                  
                CLR     TX_ON            ;NAO HA TX EM ANDAMENTO
                SETB    CLRN             ;CLRN(P1_2)= 1;
                SETB    OVERFLOW         ;IF OVFL=0 =>SINALIZA COM LED         
                SETB    OVFL             ;SE P1_4 = 1 =>LED APAGADO
 
;             
;*****          ATIVA HARDWARE
;
;*****          NO RESET PORTS SAO CONFIGURADOS COMO INPUTS                               
                

;***************************************************************************
;*                             INTERRUPCOES                                *
;***************************************************************************
          
;*****          O ALGORITMO DO PROGRAMA PRINCIPAL (MAIN_LOOP) CONTROLA
;               O ESTADO DOS FLAGS DE REQUISICAO DE INTERRUPCAO EXTERNA.
;               NO ENTANTO NAO HA HABILITACAO DAS MESMAS
                
                CLR     EX0    ;INT0 DESABILITADA
                CLR     EX1    ;INT1 DESABILITADA
                CLR     ET1    ;INT TIMER 1 DESABILITADA
                SETB    ES     ;SE EA = 1 => INT SERIAL HABILITADA
                SETB    IT0    ;INT0 SENSIVEL A BORDA DE DESCIDA
                SETB    IT1    ;INT1 SENSIVEL A BORDA DE DESCIDA  
                
                
;**************************************************************************          


;*****          ZERA AS FILAS

                ACALL   FLUSH_TX  ;LIMPA FILA_TX
                ACALL   FLUSH_RX  ;LIMPA FILA_RX


;*****          RESET DO ALTERA
                
                CLR     CLRN
                CLR     A
CLEAR_ALTERA:   INC     A
                CJNE    A,#30,CLEAR_ALTERA
                SETB    CLRN      ;SINAL DE RESET DE DURACAO IGUAL A 92 US  
                  

;*****          PROGRAMACAO DO TIMER 2
                
                MOV     RCAP2H,#HIGH_9600 
                MOV     RCAP2L,#LOW_9600
                MOV     T2CON,#00000100B  ;TIMER 2 RODANDO
                MOV     T2MOD,#00000010B  ;P1.0 FORNECENDO CLK DE 9600
                
                
;*****          ZERA FLAGS DE INT EXTERNA

                CLR     IE0         ; GARANTE QUE O UC NAO TRANSMITE
                CLR     IE1         ; O BYTE DE RESET DO ALTERA


                SETB    EA          
       
             
                
                
;*****          FIM DA INICIALIZACAO                 
            
                AJMP    MAIN_LOOP   ; VAI PARA O PROGRAMA PRINCIPAL



;***************************************************************************
;*                                                                         *
;*                      PROGRAMA PRINCIPAL                                 *
;*                                                                         *
;***************************************************************************         


;  MAIN_LOOP:         JBC     IE0,CHAMA_PUT_TX    ;IF IE0=1 =>RESETA IE0
                                                 ;E CHAMA ROTINA
                                                 ;PUT_TX ,QUE COLOCA O BYTE NA
                                                 ;FILA DE TX  

     ?BYTE_RX:      JBC     IE1,?CHAMA_GET_RX   ;IF IE1=1 =>RESETA IE1 E 
                                                 ;PODE SER QUE RETIRE BYTE
                                                 ;RECEBIDO DA FILA  
  
  
  
MAIN_LOOP:           MOV        A,FILA_RX_C
                     JZ         MAIN_LOOP
                     ACALL      GET_RX
                     MOV        ?PUT_TX?BYTE,?PUT_RX?BYTE
                     ACALL      PUT_TX
                     JB         TX_ON,MAIN_LOOP
                     ACALL      START_TX
                     SJMP       MAIN_LOOP
                     
                                                                           
                                      
                     SJMP    MAIN_LOOP
                

  CHAMA_PUT_TX:   MOV     DPTR,#END_ALT          ;(DPTR) <= ENDERECO ALTERA
                  MOVX    A,@DPTR                ;(ACC)<= BYTE P/ TX
                  MOV     ?PUT_TX?BYTE,A  
               ;  ACALL   SCRAMB_TX         ; EMBARALHA ANTES DE GUARDAR
                                            ; NA FILA DE TX
                  
               ; TESTE : RETRANSMITE A RAMPA DECRIPTOGRAFADA

                  ACALL   GET_RX            ; TIRA DA FILA O BYTE DA RAMPA
                                            ; PARA TRANSMITIR
                  
                  MOV     ?PUT_TX?BYTE,?PUT_RX?BYTE
                  ACALL   PUT_TX
                  
                  INC     CONT_BYTE_TX      ; CONTA NUMERO DE BYTES TX
                  MOV     A,CONT_BYTE_TX
                  CJNE    A,#11111111B,BYTE_INFO                             
                  MOV     CONT_BYTE_TX,#0   ; ZERA O CONTADOR DE BYTES TX
                  MOV     ?PUT_TX?BYTE,#0FFH
                  ACALL   PUT_TX            ; GUARDA BYTE "FF" DE SINCRONISMO
                                            ; NA FILA TX SEM SCRAMBLING       
                  
                  MOV     ?PUT_TX?BYTE,#'S' ; GUARDA BYTE "S" DE SINCRONISMO
                                            ; NA FILA TX SEM SCRAMBLING
                  ACALL   PUT_TX                          
                  MOV     SHIFT_REG_TX,#SEMENTE  ;RECARREGA VALOR INICIAL
                  
                  
   BYTE_INFO:     JNB     OVERFLOW,LIGA_LED_OVFL  ;SE BIT=0 =>SINALIZA ERRO                 
                  JB      TX_ON,?BYTE_RX
                  ACALL   START_TX
                  SJMP    ?BYTE_RX 
  

  ?CHAMA_GET_RX:  MOV     A,FILA_RX_C
                  JNZ     NOT_SILENCE 
                  MOV     A,#01010101B
                  MOV     DPTR,#END_ALT
                  MOVX    @DPTR,A
                  SJMP    MAIN_LOOP
                  
     NOT_SILENCE: ACALL   GET_RX
                  JNB     OVERFLOW,LIGA_LED_OVFL  
                  MOV     DPTR,#END_ALT                    
                  MOV     A,?PUT_RX?BYTE
                  MOVX    @DPTR,A                ;ALTERA<=BYTE RECEBIDO 
                  SJMP    MAIN_LOOP
  

  
  
  
  LIGA_LED_OVFL :   CLR  OVFL         ; P1_4 = 0 =>LED ACESO
                  
                  
                  ACALL   STOP_COM
                  JNB     OVFL,$  
                
;**************************************************************************                


;**************************************************************************
;*                                                                        *
;*                     ROTINAS AUXILIARES                                 *
;*                                                                        *
;**************************************************************************

;
;****   TRATAMENTO DA INTERRUPCAO SERIAL
;

INT_SR:         PUSH    ACC
                PUSH    B
                PUSH    DPH
                PUSH    DPL
                PUSH    PSW
                JB      RI,RX_BYTE
                JB      TI,TX_BYTE
;
INT_SR_END:     POP     PSW
                POP     DPL
                POP     DPH
                POP     B
                POP     ACC
                
                CLR     P1_5
                CLR     P1_6

                RETI

;
;*************  TRANSMISSAO DE UM BYTE PELA INTERFACE SERIAL 
;

TX_BYTE:        CLR     TI                      ;LIMPA INT PENDENTE
                
                SETB    P1_6                    ;SINALIZA TI EM ANDAMENTO
                
                JB     SCRAMBLER_READY,FD2
                JMP     INT_SR_END


;*************  TRATAMENTO DA FILA TX


FD2:            MOV     A,FILA_TX_C             ;VERIFICA SE FILA VAZIA
                JNZ     TX_RET                  ;NAO VAZIA --> TX_RET
                CLR     TX_ON                   ;VAZIA     --> TX_ON = FALSE
                JMP     INT_SR_END

;
;****   RETIRA BYTE DA FILA DE TX PELA INTERFACE SERIAL
;

TX_RET:         SETB    TX_ON
                MOV     A,FILA_TX_F
                CJNE    A,#MAX_TX-1,TX_RET_1
                MOV     FILA_TX_F,#00H
                SJMP    TX_RET_2
TX_RET_1:       INC     FILA_TX_F
TX_RET_2:       DEC     FILA_TX_C
                MOV     A,FILA_TX_F
                MOV     DPTR,#FILA_TX
                ADD     A,DPL
                MOV     DPL,A
                JNC     TX_RET_3
                INC     DPH
TX_RET_3:       MOVX    A,@DPTR

;
;****   TRANSMITE O BYTE
           
                
TX_RET_4:       MOV     SBUF,A
                JMP     INT_SR_END



;
;*************  RECEPCAO DE UM BYTE PELA INTERFACE SERIAL
;               

RX_BYTE:        CLR     RI                      ;LIMPA INT PENDENTE
                
                SETB    P1_5                   ; SINALIZA RI EM ANDAMENTO
                
                JB      SCRAMBLER_READY,FULL_DUPLEX
 

;***********    ROTINA QUE RECEBE UM BYTE SEM UTILIZAR A FILA
             
                MOV     A,SBUF                  ;RECEBE CARACTER AINDA SEM 
                SETB    REC_BYTE                ;TIMER   
                MOV     MSG_MODEM,A             ;MSG_MODEM <= ACC
                JMP     INT_SR_END              ;RECEBEU BYTE DO MODEM
                                                ;GUARDOU EM MSG_MODEM
                                                ;E VOLTA


;***********    INSERE NA FILA DE RX


;***********    APOS RECEBER 255 BYTES VE SE O PROXIMO E' O DE SINCRONISMO

FULL_DUPLEX:    MOV     A,SBUF       ;LE O CARACTER RECEBIDO
                MOV     B,A          ;B = BYTE A SER INSERIDO NA FILA
                
                               
                JB      WAIT_S,?RECEBEU_S?
                
                JB      PERDEU_SINC,?RECEBEU_FF?
                
                INC     CONT_BYTE_RX
                MOV     A,CONT_BYTE_RX                
                JZ      ?RECEBEU_FF?  ;INSERE NA FILA SE NAO E BYTE 
                                      ;"A" DE SINC 


RX_INS:         MOV     A,FILA_RX_R
                MOV     DPL,A
                CJNE    A,#MAX_RX-1,RX_INS_1
                MOV     FILA_RX_R,#00H
                SJMP    RX_INS_2
RX_INS_1:       INC     FILA_RX_R
RX_INS_2:       MOV     A,FILA_RX_R
                CJNE    A,FILA_RX_F,RX_INS_3
                MOV     FILA_RX_R,DPL
                JMP     RX_ERRO                 ;SE NAO INSERIU, ERRO
RX_INS_3:       MOV     A,FILA_RX_R
                MOV     DPTR,#FILA_RX
                ADD     A,DPL
                MOV     DPL,A
                JNC     RX_INS_4
                INC     DPH
                 

RX_INS_4:       MOV     A,B
                XRL     A,SHIFT_REG_RX       ;DECRIPTOGRAFA O BYTE RECEBIDO 
                MOV     B,A

;               GERACAO DA SEQ. DE COMPRIMENTO MAXIMO                
                
                MOV     A,SHIFT_REG_RX         
                ANL     A,#01110001B           ;POLINOMIO : 1+X^4+X^5+X^6
                JB      P,REALIMENTA_RX_1

;               REALIMENTA ZERO
                MOV     A,SHIFT_REG_RX 
                CLR     ACC.7
                RL      A
                MOV     SHIFT_REG_RX,A
                JMP     RX_INS_5


;               REALIMENTA UM                

REALIMENTA_RX_1:    MOV    A,SHIFT_REG_RX
                    SETB   ACC.7
                    RL     A
                    MOV    SHIFT_REG_RX,A
         

RX_INS_5:       MOV     A,B
                MOVX    @DPTR,A
                INC     FILA_RX_C
                JMP     INT_SR_END              ;SE INSERIU, FIM

RX_ERRO:        JMP     INT_SR_END              ;NAO HA' TRATAMENTO POR HORA



?RECEBEU_FF?:   MOV     A,B
                CJNE    A,#0FFH,PERDA_SINC
                SETB    WAIT_S
                JMP     INT_SR_END
                
                

?RECEBEU_S?:    MOV     A,B
                CJNE    A,#'S',PERDA_SINC
                CLR     WAIT_S
                
                CLR     P1_7                    ; SINALIZA SINC OK
                
                MOV     CONT_BYTE_RX,#0
                CLR     PERDEU_SINC
                MOV     SHIFT_REG_RX,#SEMENTE    ;RECARREGA ESTADO INICIAL
                                                 ;NO REGISTRADOR DA RECEPCAO              
                                   
                JMP     INT_SR_END
                

PERDA_SINC:     CLR     WAIT_S
                SETB    PERDEU_SINC
                
                SETB    P1_7         ; SINALIZA PERDA DE SINC
                  
            ;SE PERDEU SINCRONISMO VOLTA A CONDICAO INICIAL DA FILA_RX
              
            ;    MOV     FILA_RX_F,#MAX_RX-1
            ;    MOV     FILA_RX_R,#MAX_RX-1
            ;    MOV     FILA_RX_C,#0
                 
                
                JMP     INT_SR_END                              


;
;************** ROTINA PUT_TX
;               COLOCA BYTE PARA TRANSMITIR NA FILA DA INTERFACE SERIAL
;

PUT_TX:         CLR     EA
                MOV     A,FILA_TX_R
                MOV     B,A
                CJNE    A,#MAX_TX-1,PUT_TX_1
                MOV     FILA_TX_R,#00H
                SJMP    PUT_TX_2
PUT_TX_1:       INC     FILA_TX_R
PUT_TX_2:       MOV     A,FILA_TX_R
                CJNE    A,FILA_TX_F,PUT_TX_3
                MOV     FILA_TX_R,B
                CLR     OVERFLOW             ;PONTEIRO R ENCONTROU PONTEIRO F
                SETB    EA
                RET   
PUT_TX_3:       MOV     A,FILA_TX_R
                MOV     DPTR,#FILA_TX
                ADD     A,DPL
                MOV     DPL,A
                JNC     PUT_TX_4
                INC     DPH
PUT_TX_4:       MOV     A,?PUT_TX?BYTE
                MOVX    @DPTR,A
                INC     FILA_TX_C
                SETB    C
                SETB    EA
                RET   

;
;************** ROTINA GET_RX
;               RETIRA BYTE RECEBIDO DA FILA DA INTERFACE SERIAL
;

GET_RX:         CLR     EA
                MOV     A,FILA_RX_F
                CJNE    A,FILA_RX_R,GET_RX_1
                CLR     OVERFLOW
                SETB    EA
                RET   
GET_RX_1:       MOV     A,FILA_RX_F
                CJNE    A,#MAX_RX-1,GET_RX_2
                MOV     FILA_RX_F,#00H
                SJMP    GET_RX_3
GET_RX_2:       INC     FILA_RX_F
GET_RX_3:       DEC     FILA_RX_C
                MOV     A,FILA_RX_F
                MOV     DPTR,#FILA_RX
                ADD     A,DPL
                MOV     DPL,A
                JNC     GET_RX_4
                INC     DPH
GET_RX_4:       MOVX    A,@DPTR
                MOV     ?PUT_RX?BYTE,A
                SETB    EA
                RET   

;
;************** ROTINA FLUSH_TX 
;               ZERA A FILA DE TRANSMISSAO DA INTERFACE SERIAL
;

FLUSH_TX:       CLR     EA
                MOV     FILA_TX_F,#MAX_TX-1
                MOV     FILA_TX_R,#MAX_TX-1
                MOV     FILA_TX_C,#0
                SETB    EA
                RET   

;
;************** ROTINA FLUSH_RX
;               ZERA A FILA DE RECEPCAO DA INTERFACE SERIAL
;

FLUSH_RX:       CLR     EA
                MOV     FILA_RX_F,#MAX_RX-1
                MOV     FILA_RX_R,#MAX_RX-1
                MOV     FILA_RX_C,#0
                SETB    EA
                RET   

;
;************** ROTINA START_TX
;               INICIA TRANSMISSAO COM FILA JA' CHEIA
;

START_TX:       SETB    TI                      ;SETA BIT DE INT SERIAL
                SETB    C                       ;RETORNA COM CARRY = TRUE
                RET



;
;************** ROTINA STOP_COM
;               DESLIGA HARDWARE E DRIVER DE COMUNICACAO
;

STOP_COM:       CLR     ES                      ;INIBE INTERRUPCAO SERIAL
                CLR     TR1                     ;PARA TIMER 1
                CLR     REN                     ;INIBE RECEPCAO DA UART
                CLR     RI                      ;LIMPA INDICACAO DE RX READY
                RET


;
;************** ROTINA SCRAMB_TX
;               FAZ SCRAMBLER NO BYTE A SER TRANSMITIDO
;

SCRAMB_TX:      MOV     A,?PUT_TX?BYTE
                XRL     A,SHIFT_REG_TX         ;CRIPTOGRAFA O BYTE P/ TX 
                MOV     ?PUT_TX?BYTE,A

;               GERACAO DA SEQ. DE COMPRIMENTO MAXIMO                
                
                MOV     A,SHIFT_REG_TX         
                ANL     A,#01110001B           ;POLINOMIO : 1+X^4+X^5+X^6
                JB      P,REALIMENTA_TX_1

;               REALIMENTA ZERO
                MOV     A,SHIFT_REG_TX 
                CLR     ACC.7
                RL      A
                MOV     SHIFT_REG_TX,A
                RET


;               REALIMENTA UM                

REALIMENTA_TX_1:    MOV    A,SHIFT_REG_TX
                    SETB   ACC.7
                    RL     A
                    MOV    SHIFT_REG_TX,A
                    RET
     
     
                END 