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

// --- Variáveis Globais ---
int bpm = 120; // BPM padrão
Mix_Chunk *som_caixa = NULL;
Mix_Chunk *som_bumbo = NULL;

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

programa: ABRECHAVES NOVALINHA opt_bpm_def opt_lista_compassos FECHACHAVES { // <--- MODIFICADO AQUI
    $$ = criar_node_programa($3, $4);
    executar_programa_ast($$);
    liberar_ast($$);
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

// NOVO: Regra para a lista de compassos opcional (pode ser vazia)
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

// --- Implementação das Funções da AST e de Execução ---

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


// --- Funções de Execução da AST ---

void executar_programa_ast(ASTNode *programa_node) {
    if (!programa_node || programa_node->type != NODE_PROGRAMA) return;

    if (programa_node->data.programa.bpm_node) {
        bpm = programa_node->data.programa.bpm_node->data.bpm.value;
    }
    printf("BPM definido para: %d\n", bpm);

    ASTNode *current_compasso = programa_node->data.programa.compassos;
    while (current_compasso) {
        executar_compasso_ast(current_compasso);
        current_compasso = current_compasso->next;
    }
}

void executar_compasso_ast(ASTNode *compasso_node) {
    if (!compasso_node || compasso_node->type != NODE_COMPASSO) return;

    printf("\n--- Executando compasso ---\n");
    ASTNode *event_list_node = compasso_node->data.compasso.eventos;
    if (event_list_node) {
        ASTNode *current_evento = event_list_node->data.event_list.head;
        while (current_evento) {
            executar_evento_ast(current_evento);
            current_evento = current_evento->next;
        }
    }
}

void executar_evento_ast(ASTNode *evento_node) {
    if (!evento_node) return;

    switch (evento_node->type) {
        case NODE_TOQUE:
            calcular_delay_e_tocar(evento_node->data.toque.instrumento, evento_node->data.toque.modificador);
            break;
        case NODE_SILENCIO:
            printf("Silêncio (delay: %dms)\n", 60000 / bpm);
            SDL_Delay(60000 / bpm); // Silêncio com duração de uma batida base
            break;
        case NODE_REPETICAO:
            printf("Início Repetição x%d\n", evento_node->data.repeticao.count);
            for (int i = 0; i < evento_node->data.repeticao.count; i++) {
                // Percorre a lista de eventos para repetir
                ASTNode *current_event_to_repeat = evento_node->data.repeticao.eventos_para_repetir->data.event_list.head;
                while (current_event_to_repeat) {
                    executar_evento_ast(current_event_to_repeat);
                    current_event_to_repeat = current_event_to_repeat->next;
                }
            }
            printf("Fim Repetição\n");
            break;
        case NODE_AGRUPAMENTO: // Agrupamento sequencial
            printf("Início Agrupamento (sequencial)\n");
            executar_evento_ast(evento_node->data.agrupamento.evento1);
            executar_evento_ast(evento_node->data.agrupamento.evento2);
            printf("Fim Agrupamento\n");
            break;
        case NODE_EVENT_LIST: // Este tipo de nó é para ser usado internamente na AST, não para execução direta
            fprintf(stderr, "Erro: NODE_EVENT_LIST não deve ser executado diretamente.\n");
            break;
        default:
            fprintf(stderr, "Tipo de nó desconhecido: %d\n", evento_node->type);
            break;
    }
}

// Calcula o delay com base no modificador de tempo e toca o som
void calcular_delay_e_tocar(char instrumento, const char* modificador) {
    printf("Tocando %c", instrumento);
    int delay_ms = 60000 / bpm; // Duração base para uma batida (ex: colcheia, se BPM for 120 e 1 unidade = 1/8)

    if (modificador) {
        printf(" com modificador %s", modificador);
        if (strcmp(modificador, "!") == 0) { // Ex: 1/16 (semicolcheia), metade do tempo
            delay_ms /= 2;
        } else if (strcmp(modificador, "&") == 0) { // Ex: 1/8 (colcheia), duração base
            // Sem alteração
        } else if (strcmp(modificador, "&&") == 0) { // Ex: 1/4 (semínima), dobro do tempo
            delay_ms *= 2;
        } else if (strcmp(modificador, "&&&") == 0) { // Ex: 1/2 (mínima), quadruplo do tempo
            delay_ms *= 4;
        }
    }
    printf(" (delay: %dms)\n", delay_ms);

    if (instrumento == '@') {
        Mix_PlayChannel(-1, som_caixa, 0);
    } else if (instrumento == '#') {
        Mix_PlayChannel(-1, som_bumbo, 0);
    }
    SDL_Delay(delay_ms);
}

// Função de erro do Byson
int yyerror(const char *s) {
    fprintf(stderr, "Erro de sintaxe: %s\n", s);
    return 1;
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
                    // Caso de erro, se por algum motivo não fosse um NODE_EVENT_LIST
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
            // Apenas libera o nó NODE_EVENT_LIST em si, não seus filhos diretamente aqui,
            // para evitar double free se os filhos já foram liberados por um pai.
            // O caso NODE_COMPASSO acima já itera e libera os filhos da lista de eventos.
            break;
        default:
            // NODE_BPM, NODE_SILENCIO não possuem ponteiros para liberar recursivamente.
            break;
    }
    // Por último, libera o próprio nó
    free(node);
}