#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define SCREEN_WIDTH 1280
#define SCREEN_HEIGHT 720

typedef struct {
    const char *name;
    const char *time_str;
    int r, g, b;
} PrayerCard;

PrayerCard prayers[] = {
    {"SUBUH",   "04:15", 30, 41, 59},
    {"TERBIT",  "05:35", 30, 41, 59},
    {"DZUHUR",  "11:45", 30, 41, 59},
    {"ASHAR",   "15:05", 16, 185, 129}, // Aktif
    {"MAGHRIB", "17:55", 30, 41, 59},
    {"ISYA",    "19:08", 30, 41, 59}
};

void draw_card(SDL_Renderer *renderer, int x, int y, int w, int h, int r, int g, int b) {
    SDL_Rect rect = {x, y, w, h};
    SDL_SetRenderDrawColor(renderer, r, g, b, 255);
    SDL_RenderFillRect(renderer, &rect);

    SDL_SetRenderDrawColor(renderer, 245, 158, 11, 220); // Border Emas
    SDL_RenderDrawRect(renderer, &rect);
}

int main(int argc, char *argv[]) {
    printf("[JWS] Memulai aplikasi Jadwal Waktu Salat Kiosk...\n");

    // Hint agar kompatibel di QEMU virtio-gpu dan Orange Pi DRM KMS
    SDL_SetHint(SDL_HINT_RENDER_DRIVER, "software");
    SDL_SetHint(SDL_HINT_FRAMEBUFFER_ACCELERATION, "0");

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        // Fallback jika video driver default gagal
        setenv("SDL_VIDEODRIVER", "dummy", 0);
        if (SDL_Init(SDL_INIT_VIDEO) != 0) {
            fprintf(stderr, "[JWS] Gagal inisialisasi SDL: %s\n", SDL_GetError());
            return 1;
        }
    }

    SDL_Window *window = SDL_CreateWindow(
        "Orange Pi Zero 3 - Jadwal Waktu Salat",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        SCREEN_WIDTH, SCREEN_HEIGHT,
        SDL_WINDOW_SHOWN | SDL_WINDOW_FULLSCREEN_DESKTOP
    );

    if (!window) {
        // Coba mode window biasa jika fullscreen desktop gagal
        window = SDL_CreateWindow(
            "Orange Pi Zero 3 - Jadwal Waktu Salat",
            0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
            SDL_WINDOW_SHOWN
        );
    }

    if (!window) {
        fprintf(stderr, "[JWS] Gagal membuat window: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    if (!renderer) {
        renderer = SDL_CreateRenderer(window, -1, 0);
    }

    if (!renderer) {
        fprintf(stderr, "[JWS] Gagal membuat renderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    // Render frame awal sebelum menutup Plymouth
    SDL_SetRenderDrawColor(renderer, 15, 23, 42, 255);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);

    // Tutup Plymouth splash setelah UI aplikasi terbukti tampil di layar
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

        // 1. Gambar Background (Biru Malam Gelap Islami)
        SDL_SetRenderDrawColor(renderer, 15, 23, 42, 255);
        SDL_RenderClear(renderer);

        // 2. Header Bar Masjid / JWS
        SDL_Rect header_rect = {40, 30, SCREEN_WIDTH - 80, 80};
        SDL_SetRenderDrawColor(renderer, 30, 41, 59, 255);
        SDL_RenderFillRect(renderer, &header_rect);
        SDL_SetRenderDrawColor(renderer, 245, 158, 11, 255); // Aksen Emas
        SDL_RenderDrawRect(renderer, &header_rect);

        // 3. Jam Digital Besar di Tengah
        SDL_Rect clock_rect = {(SCREEN_WIDTH - 420) / 2, 150, 420, 240};
        SDL_SetRenderDrawColor(renderer, 24, 33, 47, 255);
        SDL_RenderFillRect(renderer, &clock_rect);
        SDL_SetRenderDrawColor(renderer, 16, 185, 129, 255); // Border Hijau Zamrud
        SDL_RenderDrawRect(renderer, &clock_rect);

        SDL_Rect inner_clock = {(SCREEN_WIDTH - 400) / 2, 160, 400, 220};
        SDL_SetRenderDrawColor(renderer, 15, 23, 42, 255);
        SDL_RenderFillRect(renderer, &inner_clock);

        // 4. Kartu Waktu Salat 6 Waktu
        for (int i = 0; i < num_cards; i++) {
            int cx = start_x + i * (card_w + card_gap);
            draw_card(renderer, cx, start_y, card_w, card_h, 
                      prayers[i].r, prayers[i].g, prayers[i].b);

            SDL_Rect top_bar = {cx, start_y, card_w, 8};
            SDL_SetRenderDrawColor(renderer, 245, 158, 11, 255);
            SDL_RenderFillRect(renderer, &top_bar);
        }

        SDL_RenderPresent(renderer);
        SDL_Delay(100);
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
