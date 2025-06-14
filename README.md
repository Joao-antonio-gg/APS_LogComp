# APS_LogComp
A linguagem de bateria é uma ferramenta simplificada criada para facilitar a composição de sequências rítmicas de bateria. Utilizando símbolos como @ para a caixa e # para o bumbo, ela permite ajustar a duração das notas com modificadores como ! e &, controlando o número de batidas por tempo. A linguagem também oferece repetições (x2) e permite definir o tempo da música (BPM). O objetivo principal é gerar padrões de bateria que podem ser convertidos para arquivos MIDI ou eventos sonoros, sendo útil em ambientes como jogos ou produções musicais.


## EBNF
PROGRAMA = "{", "\n", [ BPM ], { COMPASSO }, "}" ;

BPM = "bpm", "=", NUMERO, "\n" ;

COMPASSO = { EVENTO }, "|", "\n" ;

EVENTO = ( TOQUE | SILENCIO | REPETICAO | AGRUPAMENTO ) ;

TOQUE = SIMBOLO_INSTRUMENTO , [ MODIFICADOR_TEMPO ] ;

SILENCIO = "~" ;

REPETICAO = "(", EVENTO, ")", "x", NUMERO ;

AGRUPAMENTO = EVENTO, "+", EVENTO ;

SIMBOLO_INSTRUMENTO = ( "@" | "#" ) ;  -- Dois instrumentos: "@" e "#"

MODIFICADOR_TEMPO = ( "!" | "&" | "&&" | "&&&" ) ;

NUMERO = DIGITO, { DIGITO } ;

DIGITO = ( "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ) ;

### Exemplos de entrada 
```python
bpm=120
@! #& |
@! #& |
(#&)@! x2 |
```

### Como Compilar e Rodar
```bash
flex lexer.l
bison -v -d parser.y
gcc lex.yy.c parser.tab.c compiler.c main.c -o drum_player -lSDL2 -lSDL2_mixer
./drum_player exemplo.drum
```
