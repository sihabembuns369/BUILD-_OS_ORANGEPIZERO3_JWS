#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 720

// Struktur kotak waktu salat
typedef struct {
    const char *name;
    const char *time_str;
    int r, g, b;
} PrayerCard;

PrayerCard prayers[] = {
    {"SUBUH",   "04:15", 30, 41, 59},
    {"TERBIT",  "05:35", 30, 41, 59},
    {"DZUHUR",  "11:45", 30, 41, 59},
    {"ASHAR",   "15:05", 16, 185, 129}, // Aktif (Hijau Zamrud)
    {"MAGHRIB", "17:55", 30, 41, 59},
    {"ISYA",    "19:08", 30, 41, 59}
};

// Fungsi menggambar persegi panjang terisi
void draw_card(SDL_Renderer *renderer, int x, int y, int w, int h, int r, int g, int b) {
    SDL_Rect rect = {x, y, w, h};
    SDL_SetRenderDrawColor(renderer, r, g, b, 255);
    SDL_RenderFillRect(renderer, &rect);

    // Border aksen emas
    SDL_SetRenderDrawColor(renderer, 245, 158, 11, 200);
    SDL_RenderDrawRect(renderer, &rect);
}

int main(int argc, char *argv[]) {
    printf("[JWS] Memulai aplikasi Jadwal Waktu Salat Kiosk (SDL2)...\n");

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "[JWS] SDL_Init Error: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window *window = SDL_CreateWindow(
        "Orange Pi Zero 3 - Jadwal Waktu Salat (JWS)",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        SCREEN_WIDTH, SCREEN_HEIGHT,
        SDL_WINDOW_FULLSCREEN | SDL_WINDOW_SHOWN
    );

    if (!window) {
        fprintf(stderr, "[JWS] SDL_CreateWindow Error: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *renderer = SDL_CreateRenderer(
        window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    );

    if (!renderer) {
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    }

    // Gambar frame pertama sebelum menutup Plymouth
    SDL_SetRenderDrawColor(renderer, 15, 23, 42, 255); // Background Dark Navy
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);

    // Transisi mulus Anbernic style: Tutup splash tepat saat UI SDL2 pertama siap
    system("plymouth quit 2>/dev/null");

    int running = 1;
    SDL_Event event;

    int num_cards = sizeof(prayers) / sizeof(prayers[0]);
    int card_w = 175;
    int card_h = 160;
    int card_gap = 25;
    int start_x = (SCREEN_WIDTH - (num_cards * card_w + (num_cards - 1) * card_gap)) / 2;
    int start_y = 480;

    while (running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT || 
               (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)) {
                running = 0;
            }
        }

        time_t now = time(NULL);
        struct tm *t = localtime(&now);

        // 1. Gambar Background
        SDL_SetRenderDrawColor(renderer, 15, 23, 42, 255);
        SDL_RenderClear(renderer);

        // 2. Header Bar Masjid / JWS
        SDL_Rect header_rect = {40, 30, SCREEN_WIDTH - 80, 80};
        SDL_SetRenderDrawColor(renderer, 30, 41, 59, 255);
        SDL_RenderFillRect(renderer, &header_rect);
        SDL_SetRenderDrawColor(renderer, 245, 158, 11, 255);
        SDL_RenderDrawRect(renderer, &header_rect);

        // 3. Jam Digital Besar di Tengah
        SDL_Rect clock_rect = {(SCREEN_WIDTH - 420) / 2, 150, 420, 240};
        SDL_SetRenderDrawColor(renderer, 24, 33, 47, 255);
        SDL_RenderFillRect(renderer, &clock_rect);
        SDL_SetRenderDrawColor(renderer, 16, 185, 129, 255);
        SDL_RenderDrawRect(renderer, &clock_rect);

        // Garis dekorasi jam
        SDL_Rect inner_clock = {(SCREEN_WIDTH - 400) / 2, 160, 400, 220};
        SDL_SetRenderDrawColor(renderer, 15, 23, 42, 255);
        SDL_RenderFillRect(renderer, &inner_clock);

        // 4. Kartu Waktu Salat 6 Waktu
        for (int i = 0; i < num_cards; i++) {
            int cx = start_x + i * (card_w + card_gap);
            draw_card(renderer, cx, start_y, card_w, card_h, 
                      prayers[i].r, prayers[i].g, prayers[i].b);

            // Garis indikator atas kartu
            SDL_Rect top_bar = {cx, start_y, card_w, 8};
            SDL_SetRenderDrawColor(renderer, 245, 158, 11, 255);
            SDL_RenderFillRect(renderer, &top_bar);
        }

        SDL_RenderPresent(renderer);
        SDL_Delay(100);
    }

    if (renderer) SDL_DestroyRenderer(renderer);
    if (window) SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
