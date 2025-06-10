// Esta é uma diretiva especial do Bison que instrui a incluir ast.h
// diretamente no arquivo de cabeçalho gerado (parser.tab.h).
// Isso garante que ASTNode seja definido ANTES que a união seja declarada em parser.tab.h.
%code requires {
#include "ast.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "SDL2/SDL.h"
#include "SDL2/SDL_mixer.h"
#include "ast.h" // <--- ADICIONE ESTA LINHA AQUI!

// --- Variáveis Globais ---
// BPM, som_caixa, som_bumbo agora são declaradas em main.c
// int bpm = 120;
// Mix_Chunk *som_caixa = NULL;
// Mix_Chunk *som_bumbo = NULL;

// Variável global para armazenar a raiz da AST, acessível por main.c
ASTNode *yyparse_result_program_node = NULL; // <--- DEFINIÇÃO E INICIALIZAÇÃO AQUI

// Funções padrão do Byson/Flex
int yyerror(const char *s);
int yylex(void);
extern FILE *yyin;

%}

// --- Definições da União para yylval ---
%union {
    int num;
    char simbolo;
    char* modificador;
    ASTNode* node; // Tipo para os nós da AST
}

// --- Declaração de Tokens ---
%token <num> NUMERO
%token <simbolo> SIMBOLO_INSTRUMENTO
%token <modificador> MODIFICADOR_TEMPO

%token BPM_KEYWORD IGUAL X_KEYWORD ABREPAR FECHAPAR MAIS FIMCOMPASSO NOVALINHA
%token ABRECHAVES FECHACHAVES SILENCIO_KEYWORD

// --- Declaração de Tipos para Símbolos Não Terminais ---
%type <node> programa bpm_def lista_compassos compasso lista_eventos evento toque silencio repeticao agrupamento
%type <node> sequencia_eventos_conteudo // Conteúdo da sequência (lista interna)
%type <node> opt_bpm_def // Para a definição opcional de BPM
%type <node> opt_lista_compassos // Novo: Para a lista de compassos opcional

%%

// --- Regras da Gramática ---

programa: ABRECHAVES NOVALINHA opt_bpm_def opt_lista_compassos FECHACHAVES {
    $$ = criar_node_programa($3, $4);
    yyparse_result_program_node = $$; // <--- SALVA A RAIZ DA AST AQUI
} ;

// BPM é opcional agora, use um não-terminal dedicado para isso
opt_bpm_def: bpm_def { $$ = $1; }
           | /* vazio */ { $$ = NULL; }
;

bpm_def: BPM_KEYWORD IGUAL NUMERO NOVALINHA { $$ = criar_node_bpm($3); } ;

// `lista_compassos` é uma lista de UM OU MAIS compassos.
// Essa regra não pode ser vazia por si só.
lista_compassos: compasso { $$ = $1; } // Primeiro compasso
               | lista_compassos compasso { // Adiciona o próximo compasso na lista encadeada
                   // Encontra o último nó na lista e anexa o novo compasso
                   ASTNode *current_compasso = $1;
                   while (current_compasso->next != NULL) {
                       current_compasso = current_compasso->next;
                   }
                   current_compasso->next = $2;
                   $$ = $1; // Retorna a cabeça da lista
               }
;

// Regra para a lista de compassos opcional (pode ser vazia)
opt_lista_compassos: lista_compassos { $$ = $1; } // Se houver compassos, usa a lista não-vazia
                   | /* vazio */ { $$ = NULL; }   // Se não houver, a lista é nula
;

compasso: lista_eventos FIMCOMPASSO NOVALINHA { $$ = criar_node_compasso($1); } ;

// `lista_eventos` é uma lista de UM OU MAIS eventos.
// O resultado SEMPRE será um NODE_EVENT_LIST
lista_eventos: evento { $$ = criar_node_event_list($1); }
             | lista_eventos evento { $$ = adicionar_evento_a_lista($1, $2); }
;

evento: toque { $$ = $1; }
      | silencio { $$ = $1; }
      | repeticao { $$ = $1; }
      | agrupamento { $$ = $1; }
;

toque: SIMBOLO_INSTRUMENTO { $$ = criar_node_toque($1, NULL); }
     | SIMBOLO_INSTRUMENTO MODIFICADOR_TEMPO { $$ = criar_node_toque($1, $2); }
;

silencio: SILENCIO_KEYWORD { $$ = criar_node_silencio(); } ;

// Conteúdo da sequência de eventos para repetição/agrupamento
// Isso é uma lista de UM OU MAIS eventos, SEMPRE retorna um NODE_EVENT_LIST
sequencia_eventos_conteudo: evento { $$ = criar_node_event_list($1); }
                          | sequencia_eventos_conteudo evento { $$ = adicionar_evento_a_lista($1, $2); }
;

repeticao: ABREPAR sequencia_eventos_conteudo FECHAPAR X_KEYWORD NUMERO {
    $$ = criar_node_repeticao($2, $5);
};

agrupamento: evento MAIS evento { $$ = criar_node_agrupamento($1, $3); } ;

%%

// --- Implementação das Funções da AST e de Liberação ---
// As funções criar_node_*, calcular_delay_e_tocar, yyerror e liberar_ast
// estão agora em ast.h/main.c para melhor organização.

ASTNode* criar_node(NodeType type) {
    ASTNode *node = (ASTNode*)malloc(sizeof(ASTNode));
    if (!node) {
        perror("Falha ao alocar nó da AST");
        exit(EXIT_FAILURE);
    }
    node->type = type;
    node->next = NULL; // Por padrão, não há próximo na lista
    return node;
}

ASTNode* criar_node_programa(ASTNode *bpm_node, ASTNode *compassos) {
    ASTNode *node = criar_node(NODE_PROGRAMA);
    node->data.programa.bpm_node = bpm_node;
    node->data.programa.compassos = compassos;
    return node;
}

ASTNode* criar_node_bpm(int value) {
    ASTNode *node = criar_node(NODE_BPM);
    node->data.bpm.value = value;
    return node;
}

ASTNode* criar_node_compasso(ASTNode *eventos) {
    ASTNode *node = criar_node(NODE_COMPASSO);
    node->data.compasso.eventos = eventos;
    return node;
}

ASTNode* criar_node_toque(char instrumento, char *modificador) {
    ASTNode *node = criar_node(NODE_TOQUE);
    node->data.toque.instrumento = instrumento;
    node->data.toque.modificador = modificador; // strdup já foi feito no lexer
    return node;
}

ASTNode* criar_node_silencio() {
    ASTNode *node = criar_node(NODE_SILENCIO);
    return node;
}

ASTNode* criar_node_repeticao(ASTNode *eventos_para_repetir, int count) {
    ASTNode *node = criar_node(NODE_REPETICAO);
    node->data.repeticao.eventos_para_repetir = eventos_para_repetir;
    node->data.repeticao.count = count;
    return node;
}

ASTNode* criar_node_agrupamento(ASTNode *evento1, ASTNode *evento2) {
    ASTNode *node = criar_node(NODE_AGRUPAMENTO);
    node->data.agrupamento.evento1 = evento1;
    node->data.agrupamento.evento2 = evento2;
    return node;
}

// Cria uma nova lista de eventos com o primeiro evento
ASTNode* criar_node_event_list(ASTNode *event) {
    ASTNode *list_node = criar_node(NODE_EVENT_LIST);
    list_node->data.event_list.head = event;
    list_node->data.event_list.tail = event;
    return list_node;
}

// Adiciona um evento ao final de uma lista existente
ASTNode* adicionar_evento_a_lista(ASTNode *list, ASTNode *event) {
    if (list == NULL) {
        return criar_node_event_list(event);
    }
    if (list->type != NODE_EVENT_LIST) {
        fprintf(stderr, "Erro: Tentativa de adicionar evento a nó não-lista. Tipo: %d\n", list->type);
        exit(EXIT_FAILURE);
    }
    list->data.event_list.tail->next = event;
    list->data.event_list.tail = event;
    return list;
}

// Função para liberar a memória da AST (revisada)
void liberar_ast(ASTNode *node) {
    if (!node) return;

    // Primeiro, libera os nós filhos recursivamente
    switch (node->type) {
        case NODE_PROGRAMA:
            liberar_ast(node->data.programa.bpm_node);
            // Libera a lista de compassos
            {
                ASTNode *current = node->data.programa.compassos;
                while (current) {
                    ASTNode *temp = current;
                    current = current->next; // Avança antes de liberar o nó atual
                    liberar_ast(temp); // Libera o nó do compasso e seus eventos
                }
            }
            break;
        case NODE_COMPASSO:
            // Libera a lista de eventos
            {
                ASTNode *event_list_node = node->data.compasso.eventos;
                if (event_list_node && event_list_node->type == NODE_EVENT_LIST) {
                    ASTNode *event_to_free = event_list_node->data.event_list.head;
                    while(event_to_free){
                        ASTNode *temp_event = event_to_free;
                        event_to_free = event_to_free->next;
                        liberar_ast(temp_event); // Libera o nó de evento real (toque, silencio, etc.)
                    }
                    free(event_list_node); // Libera o nó NODE_EVENT_LIST em si
                } else if (event_list_node) {
                    liberar_ast(event_list_node);
                }
            }
            break;
        case NODE_TOQUE:
            if (node->data.toque.modificador) {
                free(node->data.toque.modificador); // Libera a string alocada por strdup
            }
            break;
        case NODE_REPETICAO:
            liberar_ast(node->data.repeticao.eventos_para_repetir); // Libera o NODE_EVENT_LIST que contém os eventos a repetir
            break;
        case NODE_AGRUPAMENTO:
            liberar_ast(node->data.agrupamento.evento1);
            liberar_ast(node->data.agrupamento.evento2);
            break;
        case NODE_EVENT_LIST:
            // Este nó de lista é um contêiner. Seus conteúdos (eventos) são liberados
            // quando a lista que os contém é processada (ex: NODE_COMPASSO ou NODE_REPETICAO).
            break;
        default:
            break;
    }
    // Por último, libera o próprio nó
    free(node);
}