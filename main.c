#include <stdio.h>
#include <stdlib.h>
#include <string.h> // Para strcmp
#include "parser.tab.h" // Inclui as definições de token e a união yylval
#include "SDL2/SDL.h"
#include "SDL2/SDL_mixer.h"
#include "ast.h"         // Inclui as definições da AST e funções
#include "bytecode.h"    // Inclui as definições de bytecode
#include "compiler.h"    // Inclui o gerador de bytecode

// Variáveis externas definidas em parser.y
extern FILE *yyin;
extern int yyparse();
extern ASTNode *yyparse_result_program_node; // A raiz da AST, definida em parser.y

// Variáveis globais de áudio (declaradas e usadas aqui)
Mix_Chunk *som_caixa = NULL;
Mix_Chunk *som_bumbo = NULL;
int bpm = 120; // BPM global, será atualizado pela VM

// Funções utilitárias (mover para um arquivo de utilitários se a VM for muito grande)
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

// --- Implementação da Mini-VM ---
void execute_bytecode(BytecodeInstruction *bytecode, int size) {
    int pc = 0; // Program Counter
    // Pilha para lidar com repetições aninhadas
    typedef struct {
        int start_pc; // Ponto de retorno para o início do bloco repetido
        int count;    // Quantas vezes ainda precisa repetir
    } RepeatFrame;
    RepeatFrame repeat_stack[100]; // Limite de 100 aninhamentos
    int repeat_sp = 0; // Stack Pointer da pilha de repetição

    printf("\n--- Executando Bytecode na Mini-VM ---\n");

    while (pc < size) {
        BytecodeInstruction instr = bytecode[pc];
        pc++; // Avança o Program Counter para a próxima instrução

        switch (instr.opcode) {
            case OP_LOAD_BPM:
                bpm = instr.operand; // Atualiza o BPM global da VM
                printf("VM: BPM definido para: %d\n", bpm);
                break;
            case OP_PLAY_SNARE: {
                char* mod_str = NULL;
                // Converter índice de volta para string para a função de tocar
                switch (instr.operand) {
                    case MOD_FAST: mod_str = "!"; break;
                    case MOD_NONE: mod_str = "&"; break;
                    case MOD_DOUBLE: mod_str = "&&"; break;
                    case MOD_QUADRUPLE: mod_str = "&&&"; break;
                    default: mod_str = "&"; break; // Fallback
                }
                calcular_delay_e_tocar('@', mod_str);
                break;
            }
            case OP_PLAY_KICK: {
                char* mod_str = NULL;
                switch (instr.operand) {
                    case MOD_FAST: mod_str = "!"; break;
                    case MOD_NONE: mod_str = "&"; break;
                    case MOD_DOUBLE: mod_str = "&&"; break;
                    case MOD_QUADRUPLE: mod_str = "&&&"; break;
                    default: mod_str = "&"; break; // Fallback
                }
                calcular_delay_e_tocar('#', mod_str);
                break;
            }
            case OP_SILENCE:
                printf("VM: Silêncio (delay: %dms)\n", 60000 / bpm);
                SDL_Delay(60000 / bpm);
                break;
            case OP_REPEAT_START:
                if (repeat_sp >= 100) {
                    fprintf(stderr, "Erro: Pilha de repetição cheia. Aumente o limite.\n");
                    exit(EXIT_FAILURE);
                }
                repeat_stack[repeat_sp].start_pc = pc; // Salva o ponto de retorno (próxima instrução)
                repeat_stack[repeat_sp].count = instr.operand; // Salva o contador
                repeat_sp++;
                printf("VM: Início Repetição x%d\n", instr.operand);
                break;
            case OP_REPEAT_END:
                repeat_sp--; // Desempilha o frame atual
                if (repeat_stack[repeat_sp].count > 1) { // Se ainda houver repetições a fazer para ESTE bloco
                    repeat_stack[repeat_sp].count--; // Decrementa contador
                    pc = repeat_stack[repeat_sp].start_pc; // Volta para o início do bloco
                    repeat_sp++; // Re-empilha o frame (para o próximo ciclo)
                } else {
                    printf("VM: Fim Repetição\n");
                }
                break;
            case OP_COMPASSO_END:
                printf("VM: --- Fim de Compasso ---\n");
                break;
            case OP_PROGRAM_END:
                printf("VM: Fim do programa de bytecode.\n");
                return; // Termina a execução da VM
            default:
                fprintf(stderr, "VM: Opcode desconhecido: %d\n", instr.opcode);
                exit(EXIT_FAILURE);
        }
    }
}


// --- Função de erro do Byson (copiada de parser.y) ---
int yyerror(const char *s) {
    fprintf(stderr, "Erro de sintaxe: %s\n", s);
    return 1;
}

// --- Função principal ---
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s arquivo_entrada\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erro ao abrir arquivo");
        return 1;
    }

    // Inicialização do SDL e SDL_mixer
    if (SDL_Init(SDL_INIT_AUDIO) < 0 || Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) < 0) {
        fprintf(stderr, "Erro ao inicializar SDL: %s\n", SDL_GetError());
        return 1;
    }

    // Carregamento dos arquivos de som
    som_caixa = Mix_LoadWAV("caixa.wav");
    som_bumbo = Mix_LoadWAV("bumbo.wav");
    if (!som_caixa || !som_bumbo) {
        fprintf(stderr, "Erro ao carregar sons. Verifique se 'caixa.wav' e 'bumbo.wav' estão no mesmo diretório.\n");
        // Tentar continuar sem som para testar a gramática, mas avisar.
        // Ou exit(1);
    }

    printf("Executando parser da linguagem de bateria...\n");
    int parse_status = yyparse(); // Isso constrói a AST (yyparse_result_program_node)

    if (parse_status == 0) {
        printf("Parsing concluído com sucesso.\n");

        // --- NOVA ETAPA: Compilar a AST para Bytecode ---
        printf("\nCompilando AST para Bytecode...\n");
        int bytecode_size = 0;
        BytecodeInstruction *bytecode = compile_ast_to_bytecode(yyparse_result_program_node, &bytecode_size);

        if (bytecode) {
            printf("Bytecode gerado (%d instruções). Executando na VM...\n", bytecode_size);
            execute_bytecode(bytecode, bytecode_size); // Executa o bytecode na mini-VM
            free(bytecode); // Libera a memória do bytecode
        } else {
            fprintf(stderr, "Erro: Falha ao gerar bytecode.\n");
        }

        liberar_ast(yyparse_result_program_node); // Libera a AST após a compilação e execução
    } else {
        printf("Erro durante o parsing.\n");
    }

    // Liberação dos recursos do SDL_mixer
    Mix_FreeChunk(som_caixa);
    Mix_FreeChunk(som_bumbo);
    Mix_CloseAudio();
    SDL_Quit();

    return 0;
}