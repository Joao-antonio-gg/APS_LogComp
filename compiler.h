#ifndef COMPILER_H
#define COMPILER_H

#include "ast.h"
#include "bytecode.h" // Inclui as definições de bytecode

// Função principal para compilar a AST em bytecode
// Retorna um array de BytecodeInstruction e preenche bytecode_size
BytecodeInstruction* compile_ast_to_bytecode(ASTNode *program_node, int *bytecode_size);

#endif // COMPILER_H