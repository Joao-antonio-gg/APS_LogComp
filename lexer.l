%{
#include "parser.tab.h" // Isso já inclui a definição de yylval
#include "ast.h"       // Inclui as definições de ASTNode e funções
#include <string.h>
#include <stdlib.h>
%}

DIGITO      [0-9]+
SIMBOLO     [@#]
MODTEMPO    "!"|"&&&"|"&&"|"&"

%%

"bpm"               { return BPM_KEYWORD; }
"="                 { return IGUAL; }
{DIGITO}            { yylval.num = atoi(yytext); return NUMERO; }
{SIMBOLO}           { yylval.simbolo = yytext[0]; return SIMBOLO_INSTRUMENTO; }
{MODTEMPO}          { yylval.modificador = strdup(yytext); return MODIFICADOR_TEMPO; }

"~"                 { return SILENCIO_KEYWORD; }
"x"                 { return X_KEYWORD; }
"("                 { return ABREPAR; }
")"                 { return FECHAPAR; }
"+"                 { return MAIS; }
"|"                 { return FIMCOMPASSO; }
"\n"                { return NOVALINHA; }
"{"                 { return ABRECHAVES; }
"}"                 { return FECHACHAVES; }
[ \t\r]+            { /* ignora espaços, tabs e retornos de carro */ }
.                   { printf("Caractere inválido: %s\n", yytext); return 0; }

%%
int yywrap() { return 1; }