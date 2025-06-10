#ifndef AST_H
#define AST_H

// --- Estruturas da AST ---

// Enumeração para tipos de nós da AST
typedef enum {
    NODE_PROGRAMA,
    NODE_BPM,
    NODE_COMPASSO,
    NODE_TOQUE,
    NODE_SILENCIO,
    NODE_REPETICAO,
    NODE_AGRUPAMENTO,
    NODE_EVENT_LIST // Para listas de eventos (ex: sequencia_eventos)
} NodeType;

// Estrutura para um nó genérico da AST
typedef struct ASTNode {
    NodeType type;
    struct ASTNode *next; // Para listas (ex: lista_compassos, event_list dentro de compasso)
    union {
        // NODE_PROGRAMA
        struct {
            struct ASTNode *bpm_node;
            struct ASTNode *compassos; // Lista de compassos (agora pode ser NULL)
        } programa;
        // NODE_BPM
        struct {
            int value;
        } bpm;
        // NODE_COMPASSO
        struct {
            struct ASTNode *eventos; // Lista de eventos (será um NODE_EVENT_LIST)
        } compasso;
        // NODE_TOQUE
        struct {
            char instrumento; // '@' ou '#'
            char *modificador; // "!", "&", "&&", "&&&"
        } toque;
        // NODE_SILENCIO
        struct {
            // Nenhum dado adicional para silêncio
        } silencio;
        // NODE_REPETICAO
        struct {
            struct ASTNode *eventos_para_repetir; // Será um NODE_EVENT_LIST
            int count;
        } repeticao;
        // NODE_AGRUPAMENTO (sequencial)
        struct {
            struct ASTNode *evento1;
            struct ASTNode *evento2;
        } agrupamento;
        // NODE_EVENT_LIST (para sequencias_eventos)
        struct {
            struct ASTNode *head;
            struct ASTNode *tail;
        } event_list;
    } data;
} ASTNode;

// --- Funções de Criação de Nós da AST ---
ASTNode* criar_node(NodeType type);
ASTNode* criar_node_programa(ASTNode *bpm_node, ASTNode *compassos);
ASTNode* criar_node_bpm(int value);
ASTNode* criar_node_compasso(ASTNode *eventos);
ASTNode* criar_node_toque(char instrumento, char *modificador);
ASTNode* criar_node_silencio();
ASTNode* criar_node_repeticao(ASTNode *eventos_para_repetir, int count);
ASTNode* criar_node_agrupamento(ASTNode *evento1, ASTNode *evento2);
ASTNode* criar_node_event_list(ASTNode *event);
ASTNode* adicionar_evento_a_lista(ASTNode *list, ASTNode *event);

// --- Funções utilitárias (usadas pela VM ou por testes) ---
void calcular_delay_e_tocar(char instrumento, const char* modificador); // Mantida aqui para acesso pela VM

// --- Função para liberar a AST ---
void liberar_ast(ASTNode *node);

#endif // AST_H