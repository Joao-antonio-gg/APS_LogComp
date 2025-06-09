#include <SDL2/SDL.h>
#include <SDL2/SDL_mixer.h>
#include <stdio.h>
#include <stdlib.h>
#include "parser.tab.h"

// Protótipos da AST do parser
extern Programa programa;

void tocarEvento(Evento* e, int bpm);
void tocarToque(int instrumento, int duracao, int bpm);

int main() {
    printf("Iniciando parser...\n");
    if (yyparse() != 0) {
        printf("Erro na análise sintática.\n");
        return 1;
    }
    printf("Parsing completo. Executando...\n");

    // Inicializa SDL2
    if (SDL_Init(SDL_INIT_AUDIO) < 0) {
        fprintf(stderr, "Erro SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) < 0) {
        fprintf(stderr, "Erro Mix_OpenAudio: %s\n", Mix_GetError());
        SDL_Quit();
        return 1;
    }

    tocarEvento(programa.compassos, programa.bpm);

    Mix_CloseAudio();
    SDL_Quit();
    return 0;
}

void tocarEvento(Evento* e, int bpm) {
    while (e) {
        switch (e->tipo) {
            case T_TOQUE:
                tocarToque(e->instrumento, e->duracao, bpm);
                break;
            case T_SILENCIO:
                SDL_Delay(60000 / bpm);  // Espera 1 batida
                break;
            case T_REPETICAO:
                for (int i = 0; i < e->vezes; i++) {
                    tocarEvento(e->filho, bpm);
                }
                break;
            case T_AGRUPAMENTO:
                // Toca os dois eventos em sequência simples
                tocarEvento(e->esquerda, bpm);
                tocarEvento(e->direita, bpm);
                break;
        }
        e = e->prox;
    }
}

void tocarToque(int instrumento, int duracao, int bpm) {
    const char* arquivo = NULL;
    switch (instrumento) {
        case 1: arquivo = "caixa.wav"; break;
        case 2: arquivo = "bumbo.wav"; break;
    }
    if (!arquivo) return;

    Mix_Chunk* som = Mix_LoadWAV(arquivo);
    if (!som) {
        fprintf(stderr, "Erro ao carregar som %s: %s\n", arquivo, Mix_GetError());
        return;
    }
    Mix_PlayChannel(-1, som, 0);

    // Espera pela duração da batida multiplicada pelo modificador
    int duracao_ms = (60000 / bpm) * duracao;
    SDL_Delay(duracao_ms);

    Mix_FreeChunk(som);
}
