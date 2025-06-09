%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int yylex(void);

typedef enum { T_TOQUE, T_SILENCIO, T_REPETICAO, T_AGRUPAMENTO } TipoEvento;

typedef struct Evento {
    TipoEvento tipo;

    // Para toque
    int instrumento;  // 1=caixa, 2=bumbo
    int duracao;      // 1=!, 2=&, 3=&&, 4=&&& (padrão 1)

    // Para repetição
    struct Evento* filho;
    int vezes;

    // Para agrupamento
    struct Evento* esquerda;
    struct Evento* direita;

    struct Evento* prox; // lista de eventos em compasso
} Evento;

// Cabeça do programa
typedef struct {
    int bpm;
    Evento* compassos; // lista de eventos (compasso simplificado)
} Programa;

Programa programa;

Evento* criaEventoToque(int instrumento, int duracao);
Evento* criaEventoSilencio();
Evento* criaEventoRepeticao(Evento* e, int vezes);
Evento* criaEventoAgrupamento(Evento* e1, Evento* e2);
Evento* adicionaEvento(Evento* lista, Evento* novo);

%}

%union {
    int num;
    Evento* evento;
}

%token BPM IGUAL CAIXA BUMBU EXCLAMACAO ECOM DOIS_ECOM TRES_ECOM
%token SILENCIO X ABRE_PAREN FECHA_PAREN MAIS BARRA NEWLINE
%token <num> NUMERO

%type <evento> evento toque modificador_opt repeticao agrupamento evento_list compasso compasso_list bpm_opt programa

%%

programa:
    '{' NEWLINE bpm_opt compasso_list '}' {
        printf("Programa parseado. BPM: %d\n", programa.bpm);
    }
;

bpm_opt:
    /* vazio */ { programa.bpm = 120; } // padrão 120 bpm
    | BPM IGUAL NUMERO NEWLINE { programa.bpm = $3; }
;

compasso_list:
    compasso { programa.compassos = $1; }
    | compasso_list compasso { programa.compassos = adicionaEvento(programa.compassos, $2); }
;

compasso:
    evento_list BARRA NEWLINE { $$ = $1; }
;

evento_list:
    /* vazio */ { $$ = NULL; }
    | evento_list evento { $$ = adicionaEvento($1, $2); }
;

evento:
    toque { $$ = $1; }
    | SILENCIO { $$ = criaEventoSilencio(); }
    | repeticao { $$ = $1; }
    | agrupamento { $$ = $1; }
;

toque:
    instrumento modificador_opt {
        $$ = criaEventoToque($1, $2);
    }
;

modificador_opt:
    /* vazio */ { $$ = 1; }
    | EXCLAMACAO { $$ = 1; }
    | ECOM { $$ = 2; }
    | DOIS_ECOM { $$ = 3; }
    | TRES_ECOM { $$ = 4; }
;

instrumento:
    CAIXA { $$ = 1; }
    | BUMBU { $$ = 2; }
;

repeticao:
    ABRE_PAREN evento FECHA_PAREN X NUMERO {
        $$ = criaEventoRepeticao($2, $5);
    }
;

agrupamento:
    evento MAIS evento {
        $$ = criaEventoAgrupamento($1, $3);
    }
;

%%

// Funções para criar e manipular a AST

Evento* criaEventoToque(int instrumento, int duracao) {
    Evento* e = malloc(sizeof(Evento));
    e->tipo = T_TOQUE;
    e->instrumento = instrumento;
    e->duracao = duracao;
    e->filho = NULL;
    e->vezes = 0;
    e->esquerda = NULL;
    e->direita = NULL;
    e->prox = NULL;
    return e;
}

Evento* criaEventoSilencio() {
    Evento* e = malloc(sizeof(Evento));
    e->tipo = T_SILENCIO;
    e->prox = NULL;
    return e;
}

Evento* criaEventoRepeticao(Evento* filho, int vezes) {
    Evento* e = malloc(sizeof(Evento));
    e->tipo = T_REPETICAO;
    e->filho = filho;
    e->vezes = vezes;
    e->prox = NULL;
    return e;
}

Evento* criaEventoAgrupamento(Evento* e1, Evento* e2) {
    Evento* e = malloc(sizeof(Evento));
    e->tipo = T_AGRUPAMENTO;
    e->esquerda = e1;
    e->direita = e2;
    e->prox = NULL;
    return e;
}

Evento* adicionaEvento(Evento* lista, Evento* novo) {
    if (!lista) return novo;
    Evento* p = lista;
    while (p->prox) p = p->prox;
    p->prox = novo;
    return lista;
}

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintático: %s\n", s);
}
