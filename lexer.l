%{
#include "parser.tab.h"
#include <stdlib.h>

void yyerror(const char *s);
%}
%option noyywrap

%%

"bpm"       { return BPM; }
"="         { return IGUAL; }
"@"         { return CAIXA; }
"#"         { return BUMBU; }
"!"         { return EXCLAMACAO; }
"&&&"       { return TRES_ECOM; }
"&&"        { return DOIS_ECOM; }
"&"         { return ECOM; }
"~"         { return SILENCIO; }
"x"         { return X; }
"("         { return ABRE_PAREN; }
")"         { return FECHA_PAREN; }
"+"         { return MAIS; }
"|"         { return BARRA; }
\n          { return NEWLINE; }
[0-9]+      { yylval.num = atoi(yytext); return NUMERO; }
"{"         { return '{'; }
"}"         { return '}'; }
[ \t]       { /* ignora espaços e tabulações */ }
.           { printf("Caractere inválido: %s\n", yytext); return -1; }

%%

int yywrap() { return 1; }
