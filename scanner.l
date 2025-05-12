%{
#include "parser.tab.h"
%}

%%

"bpm"           { return BPM; }
"="             { return IGUAL; }
[0-9]+          { yylval.num = atoi(yytext); return NUMERO; }
"@"             { return CAIXA; }
"#"             { return BUMBU; }
"!"             { return EXCLAMACAO; }
"&&&"           { return TRES_ECOM; }
"&&"            { return DOIS_ECOM; }
"&"             { return ECOM; }
"~"             { return SILENCIO; }
"x"             { return X; }
"("             { return ABRE_PAREN; }
")"             { return FECHA_PAREN; }
"+"             { return MAIS; }
"|"             { return BARRA; }
"\n"            { return NEWLINE; }
[ \t\r]         { /* Ignora espaços */ }
.               { printf("Caractere inválido: %s\n", yytext); return -1; }

%%

int yywrap() {
    return 1;
}
