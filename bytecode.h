#ifndef BYTECODE_H
#define BYTECODE_H

// Opcodes para a sua mini-VM
typedef enum {
    OP_LOAD_BPM,       // Carrega um valor de BPM (operand: valor do BPM)
    OP_PLAY_SNARE,     // Toca caixa (operand: índice do modificador de tempo)
    OP_PLAY_KICK,      // Toca bumbo (operand: índice do modificador de tempo)
    OP_SILENCE,        // Pausa (sem operand, ou operand para duração customizada)
    OP_REPEAT_START,   // Início de um loop de repetição (operand: contador de repetições)
    OP_REPEAT_END,     // Fim de um loop de repetição
    OP_COMPASSO_END,   // Marca o fim de um compasso (para depuração/organização)
    OP_PROGRAM_END     // Fim do programa
} OpCode;

// Estrutura para uma instrução de bytecode
typedef struct {
    OpCode opcode;
    int operand; // Usado para valores (BPM, contador), ou índices de modificador
} BytecodeInstruction;

// Mapeamento de modificadores de tempo para índices
// Isso é útil para que o bytecode não precise carregar strings
typedef enum {
    MOD_NONE = 0, // Sem modificador (ex: &)
    MOD_FAST,     // !
    MOD_DOUBLE,   // &&
    MOD_QUADRUPLE // &&&
} TimeModifierIndex;

// Funções que serão usadas pelo compilador para obter o índice do modificador
int get_modifier_index(const char *mod);

#endif // BYTECODE_H