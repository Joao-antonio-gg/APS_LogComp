%{
#include <stdio.h>
#include <stdlib.h>

int yylex(void);
void yyerror(const char *s);
%}

%union {
    int num;
}

%token BPM IGUAL CAIXA BUMBU EXCLAMACAO ECOM DOIS_ECOM TRES_ECOM
%token SILENCIO X ABRE_PAREN FECHA_PAREN MAIS BARRA NEWLINE
%token <num> NUMERO

%%

programa:
    '{' NEWLINE bpm_opt compasso_list '}'
    ;

bpm_opt:
    /* vazio */
    | BPM IGUAL NUMERO NEWLINE {
        printf("BPM definido como %d\n", $3);
    }
    ;

compasso_list:
    compasso
    | compasso_list compasso
    ;

compasso:
    evento_list BARRA NEWLINE {
        printf("Fim do compasso\n");
    }
    ;

evento_list:
    /* vazio */
    | evento_list evento
    ;

evento:
    toque
    | SILENCIO {
        printf("Silêncio\n");
    }
    | repeticao
    | agrupamento
    ;

toque:
    instrumento modificador_opt
    ;

modificador_opt:
    /* vazio */ {
        printf(" com duração padrão (1 batida)\n");
    }
    | EXCLAMACAO {
        printf(" com duração padrão (1 batida)\n");
    }
    | ECOM {
        printf(" com duração dupla (2 batidas)\n");
    }
    | DOIS_ECOM {
        printf(" com duração tripla (3 batidas)\n");
    }
    | TRES_ECOM {
        printf(" com duração quádrupla (4 batidas)\n");
    }
    ;

instrumento:
    CAIXA {
        printf("Tocando caixa");
    }
    | BUMBU {
        printf("Tocando bumbo");
    }
    ;

repeticao:
    ABRE_PAREN evento FECHA_PAREN X NUMERO {
        printf("Repetição anterior %d vezes\n", $5);
    }
    ;

agrupamento:
    evento MAIS evento {
        printf("Agrupamento de eventos\n");
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintático: %s\n", s);
}

int main(void) {
    printf("Iniciando análise...\n");
    if (yyparse() == 0) {
        printf("Entrada válida!\n");
    } else {
        printf("Entrada inválida!\n");
    }
    return 0;
}
