#include "compiler.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h> // Para strcmp

// Array dinâmico para armazenar o bytecode gerado
static BytecodeInstruction *generated_bytecode = NULL;
static int bytecode_capacity = 0;
static int bytecode_count = 0;

// Função auxiliar para adicionar uma instrução ao bytecode
static void add_instruction(OpCode opcode, int operand) {
    if (bytecode_count >= bytecode_capacity) {
        bytecode_capacity = (bytecode_capacity == 0) ? 16 : bytecode_capacity * 2;
        generated_bytecode = (BytecodeInstruction*)realloc(generated_bytecode, bytecode_capacity * sizeof(BytecodeInstruction));
        if (!generated_bytecode) {
            perror("Falha ao alocar memória para bytecode");
            exit(EXIT_FAILURE);
        }
    }
    generated_bytecode[bytecode_count].opcode = opcode;
    generated_bytecode[bytecode_count].operand = operand;
    bytecode_count++;
}

// Implementação da função para converter modificador de string para índice
int get_modifier_index(const char *mod) {
    if (mod == NULL || strcmp(mod, "&") == 0) return MOD_NONE; // & é o padrão
    if (strcmp(mod, "!") == 0) return MOD_FAST;
    if (strcmp(mod, "&&") == 0) return MOD_DOUBLE;
    if (strcmp(mod, "&&&") == 0) return MOD_QUADRUPLE;
    return MOD_NONE; // Padrão para qualquer coisa desconhecida
}

// Função recursiva para percorrer a AST e gerar bytecode
static void compile_node(ASTNode *node) {
    if (!node) return;

    switch (node->type) {
        case NODE_PROGRAMA:
            // Processa o BPM primeiro, se existir
            if (node->data.programa.bpm_node) {
                compile_node(node->data.programa.bpm_node);
            }
            // Percorre a lista de compassos
            ASTNode *current_compasso = node->data.programa.compassos;
            while (current_compasso) {
                compile_node(current_compasso);
                current_compasso = current_compasso->next;
            }
            add_instruction(OP_PROGRAM_END, 0); // Sinaliza o fim do programa
            break;

        case NODE_BPM:
            add_instruction(OP_LOAD_BPM, node->data.bpm.value);
            break;

        case NODE_COMPASSO:
            // Percorre a lista de eventos dentro do compasso
            ASTNode *event_list_node = node->data.compasso.eventos;
            if (event_list_node && event_list_node->type == NODE_EVENT_LIST) {
                ASTNode *current_event = event_list_node->data.event_list.head;
                while (current_event) {
                    compile_node(current_event);
                    current_event = current_event->next;
                }
            }
            add_instruction(OP_COMPASSO_END, 0); // Marca o fim do compasso
            break;

        case NODE_TOQUE:
            if (node->data.toque.instrumento == '#') { // Bumbo
                add_instruction(OP_PLAY_KICK, get_modifier_index(node->data.toque.modificador));
            } else if (node->data.toque.instrumento == '@') { // Caixa
                add_instruction(OP_PLAY_SNARE, get_modifier_index(node->data.toque.modificador));
            }
            break;

        case NODE_SILENCIO:
            add_instruction(OP_SILENCE, 0); // Sem operando específico para o delay padrão
            break;

        case NODE_REPETICAO: {
            int repeat_count = node->data.repeticao.count;
            // Para repetições, adicionamos o OP_REPEAT_START
            add_instruction(OP_REPEAT_START, repeat_count);

            // Gerar bytecode para os eventos internos da repetição
            ASTNode *events_to_repeat_list = node->data.repeticao.eventos_para_repetir;
            if (events_to_repeat_list && events_to_repeat_list->type == NODE_EVENT_LIST) {
                ASTNode *current_event = events_to_repeat_list->data.event_list.head;
                while (current_event) {
                    compile_node(current_event);
                    current_event = current_event->next;
                }
            }
            // Adicionamos OP_REPEAT_END para marcar o fim do bloco de repetição
            add_instruction(OP_REPEAT_END, 0);
            break;
        }
        case NODE_AGRUPAMENTO:
            // Para agrupamento sequencial, basta compilar os eventos em ordem
            compile_node(node->data.agrupamento.evento1);
            compile_node(node->data.agrupamento.evento2);
            break;

        case NODE_EVENT_LIST:
            // NODE_EVENT_LIST é um nó interno de organização, seus filhos são processados pelos pais
            // Não faz nada aqui diretamente
            break;
        default:
            fprintf(stderr, "Tipo de nó desconhecido na compilação: %d\n", node->type);
            break;
    }
}

// Função pública para compilar a AST
BytecodeInstruction* compile_ast_to_bytecode(ASTNode *program_node, int *size) {
    // Resetar o estado do compilador para uma nova compilação
    if (generated_bytecode) {
        free(generated_bytecode);
        generated_bytecode = NULL;
    }
    bytecode_capacity = 0;
    bytecode_count = 0;

    compile_node(program_node);
    *size = bytecode_count;
    return generated_bytecode;
}