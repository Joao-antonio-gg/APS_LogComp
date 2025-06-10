#include <stdio.h>
#include <stdlib.h>
#include "parser.tab.h" // Inclui as definições de token e a união yylval
#include "SDL2/SDL.h"
#include "SDL2/SDL_mixer.h"
#include "ast.h"         // Inclui as definições da AST e funções

// Variáveis externas definidas em parser.y
extern FILE *yyin;
extern int yyparse();
extern Mix_Chunk *som_caixa;
extern Mix_Chunk *som_bumbo;

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
        return 1;
    }

    printf("Executando parser da linguagem de bateria...\n");
    int parse_status = yyparse(); // Chama o parser, que agora constrói e executa a AST

    if (parse_status == 0) {
        printf("Parsing concluído com sucesso.\n");
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