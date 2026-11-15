#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <dlfcn.h>
#include <poll.h>
#include <time.h>
#include <sys/ioctl.h>
#include <linux/gpio.h>

extern char *program_invocation_short_name;

typedef struct SDL_Color {
    uint8_t r, g, b, a;
} SDL_Color;

typedef struct SDL_PixelFormat {
    uint32_t format;
    void *palette;
    uint8_t BitsPerPixel;
    uint8_t BytesPerPixel;
    uint8_t padding[2];
    uint32_t Rmask;
    uint32_t Gmask;
    uint32_t Bmask;
    uint32_t Amask;
} SDL_PixelFormat;

typedef struct SDL_Surface {
    uint32_t flags;
    SDL_PixelFormat *format;
    int w, h;
    int pitch;
    void *pixels;
} SDL_Surface;

static bool g_is_jws = false;
static volatile int g_ir_line_fd = -1;
static volatile int g_ir_wake = 0;
static volatile uint64_t g_last_input_ms = 0;
static uint64_t g_last_render_ms = 0;
static time_t g_last_render_sec = 0;
static uint64_t g_main_frames = 0;
static bool g_seen_geometry = false;
static bool g_render_this_frame = true;
static bool g_pending_clear = false;
static bool g_skip_next_dim_rect = false;

#define MAX_BG_TEXTURES 32
static void *g_bg_textures[MAX_BG_TEXTURES];
static int g_num_bg_textures = 0;

static int (*real_open)(const char *pathname, int flags, ...) = NULL;
static int (*real_ioctl)(int fd, unsigned long request, ...) = NULL;
static int (*real_poll)(struct pollfd *fds, nfds_t nfds, int timeout) = NULL;

static void *(*real_SDL_CreateTextureFromSurface)(void *renderer, SDL_Surface *surface) = NULL;
static int (*real_SDL_SetTextureScaleMode)(void *texture, int scaleMode) = NULL;
static int (*real_SDL_SetTextureBlendMode)(void *texture, int blendMode) = NULL;
static int (*real_SDL_RenderClear)(void *renderer) = NULL;
static int (*real_SDL_RenderGeometryRaw)(
    void *renderer, void *texture,
    const float *xy, int xy_stride,
    const SDL_Color *color, int color_stride,
    const float *uv, int uv_stride,
    int num_vertices, const void *indices, int num_indices, int size_indices) = NULL;
static void (*real_SDL_RenderPresent)(void *renderer) = NULL;
static int (*real_SDL_PollEvent)(void *event) = NULL;
static int (*real_SDL_PushEvent)(void *event) = NULL;
static void (*real_SDL_Delay)(uint32_t ms) = NULL;

static uint64_t get_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ULL + (uint64_t)(ts.tv_nsec / 1000000ULL);
}

static void resolve_libc_symbols(void) {
    if (!real_open) real_open = dlsym(RTLD_NEXT, "open");
    if (!real_ioctl) real_ioctl = dlsym(RTLD_NEXT, "ioctl");
    if (!real_poll) real_poll = dlsym(RTLD_NEXT, "poll");
}

static void resolve_sdl_symbols(void) {
    resolve_libc_symbols();
    if (!real_SDL_CreateTextureFromSurface)
        real_SDL_CreateTextureFromSurface = dlsym(RTLD_NEXT, "SDL_CreateTextureFromSurface");
    if (!real_SDL_SetTextureScaleMode)
        real_SDL_SetTextureScaleMode = dlsym(RTLD_NEXT, "SDL_SetTextureScaleMode");
    if (!real_SDL_SetTextureBlendMode)
        real_SDL_SetTextureBlendMode = dlsym(RTLD_NEXT, "SDL_SetTextureBlendMode");
    if (!real_SDL_RenderClear)
        real_SDL_RenderClear = dlsym(RTLD_NEXT, "SDL_RenderClear");
    if (!real_SDL_RenderGeometryRaw)
        real_SDL_RenderGeometryRaw = dlsym(RTLD_NEXT, "SDL_RenderGeometryRaw");
    if (!real_SDL_RenderPresent)
        real_SDL_RenderPresent = dlsym(RTLD_NEXT, "SDL_RenderPresent");
    if (!real_SDL_PollEvent)
        real_SDL_PollEvent = dlsym(RTLD_NEXT, "SDL_PollEvent");
    if (!real_SDL_PushEvent)
        real_SDL_PushEvent = dlsym(RTLD_NEXT, "SDL_PushEvent");
    if (!real_SDL_Delay)
        real_SDL_Delay = dlsym(RTLD_NEXT, "SDL_Delay");
}

__attribute__((constructor))
static void jws_perf_init(void) {
    resolve_libc_symbols();
    if (program_invocation_short_name &&
        strcmp(program_invocation_short_name, "jadwalsholat_imgui") == 0) {
        g_is_jws = true;
        g_last_input_ms = get_now_ms();
        resolve_sdl_symbols();

        /* Jika dijalankan langsung dari PuTTY/SSH di luar folder /opt/jws, pindah ke /opt/jws */
        if (access("settings.json", F_OK) != 0 && access("/opt/jws/settings.json", F_OK) == 0) {
            int r = chdir("/opt/jws");
            (void)r;
        }

        /* Pastikan environment variable KMSDRM selalu aktif
         * meskipun dijalankan manual via ./jadwalsholat_imgui di PuTTY */
        if (!getenv("DISPLAY") && !getenv("WAYLAND_DISPLAY")) {
            setenv("SDL_VIDEODRIVER", "kmsdrm", 0);
        }
        setenv("SDL_RENDER_DRIVER", "opengles2", 0);
        setenv("SDL_AUDIODRIVER", "dummy", 0);
        setenv("SDL_RENDER_VSYNC", "1", 0);
        setenv("SDL_HINT_RENDER_BATCHING", "1", 0);

        if (access("/dev/dri/renderD128", F_OK) != 0) {
            /* CATATAN: JANGAN set GBM_ALWAYS_SOFTWARE=1 karena akan mematikan kemampuan
             * scanout DRM KMS di /dev/dri/card0 sehingga layar HDMI blank/hitam! */
            setenv("LIBGL_ALWAYS_SOFTWARE", "1", 1);
            setenv("MESA_LOADER_DRIVER_OVERRIDE", "kms_swrast", 1);
            setenv("GALLIUM_DRIVER", "llvmpipe", 1);
            setenv("LP_NUM_THREADS", "1", 1);
            setenv("MESA_GL_VERSION_OVERRIDE", "2.1", 1);
            setenv("MESA_GLES_VERSION_OVERRIDE", "2.0", 1);
        }

        /* Jika dijalankan interaktif dari PuTTY (ttyS0) atau SSH (pts),
         * hentikan jws.service di background agar tidak berebut GPIO 78 & DRM master */
        if (!getenv("JWS_GUARD_DONE")) {
            setenv("JWS_GUARD_DONE", "1", 1);
            const char *tty = ttyname(0);
            if (!tty) tty = ttyname(1);
            if (tty && (strstr(tty, "ttyS") || strstr(tty, "ttyAMA") || strstr(tty, "pts"))) {
                int rc = system("systemctl is-active --quiet jws.service 2>/dev/null");
                if (rc == 0) {
                    fprintf(stderr, "[JWS-Guard] Menghentikan background jws.service agar tidak bentrok dengan sesi terminal ini...\n");
                    int s = system("systemctl stop jws.service 2>/dev/null || sudo -n systemctl stop jws.service 2>/dev/null");
                    (void)s;
                    usleep(250000);
                }
            }
        }
    }
}

/* 1. Auto-redirect /dev/gpiochip0 -> /dev/gpiochip1 jika gpiochip0 hanya r_pio (32 line) */
int open(const char *pathname, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (!real_open) resolve_libc_symbols();

    if (g_is_jws && pathname[0] == '/' && strncmp(pathname, "/dev/gpiochip", 13) == 0) {
        int fd = real_open(pathname, flags, mode);
        if (fd >= 0 && real_ioctl) {
            struct gpiochip_info cinfo;
            memset(&cinfo, 0, sizeof(cinfo));
            if (real_ioctl(fd, GPIO_GET_CHIPINFO_IOCTL, &cinfo) == 0 && cinfo.lines <= 32) {
                /* Cari gpiochip utama (300b000.pinctrl, 288 lines) */
                for (int i = 0; i < 4; i++) {
                    char alt[32];
                    snprintf(alt, sizeof(alt), "/dev/gpiochip%d", i);
                    int afd = real_open(alt, flags, mode);
                    if (afd >= 0) {
                        struct gpiochip_info ainfo;
                        memset(&ainfo, 0, sizeof(ainfo));
                        if (real_ioctl(afd, GPIO_GET_CHIPINFO_IOCTL, &ainfo) == 0 && ainfo.lines > 64) {
                            close(fd);
                            fprintf(stderr, "[IR-AutoFix] Redirect %s (lines=%u) -> %s (%s, lines=%u)\n",
                                    pathname, cinfo.lines, alt, ainfo.label, ainfo.lines);
                            return afd;
                        }
                        close(afd);
                    }
                }
            }
        }
        return fd;
    }

    return real_open(pathname, flags, mode);
}

/* 2. Auto-fallback ioctl GPIO_V2_GET_LINE_IOCTL untuk Line 78 (PC14) */
int ioctl(int fd, unsigned long request, ...) {
    va_list ap;
    va_start(ap, request);
    void *arg = va_arg(ap, void *);
    va_end(ap);

    if (!real_ioctl) resolve_libc_symbols();

    int ret = real_ioctl(fd, request, arg);
    if (g_is_jws && request == GPIO_V2_GET_LINE_IOCTL) {
        struct gpio_v2_line_request *req = (struct gpio_v2_line_request *)arg;
        if (ret < 0 && req && (errno == EINVAL || errno == EBUSY || errno == EACCES || errno == ENOENT)) {
            if (errno == EBUSY) {
                const char *tty = ttyname(0);
                if (!tty) tty = ttyname(1);
                if (tty && (strstr(tty, "ttyS") || strstr(tty, "ttyAMA") || strstr(tty, "pts"))) {
                    int s = system("systemctl stop jws.service 2>/dev/null || sudo -n systemctl stop jws.service 2>/dev/null");
                    (void)s;
                    usleep(250000);
                }
            }
            for (int i = 0; i < 4; i++) {
                char alt[32];
                snprintf(alt, sizeof(alt), "/dev/gpiochip%d", i);
                int cfd = real_open(alt, O_RDWR | O_CLOEXEC);
                if (cfd < 0) continue;
                struct gpiochip_info cinfo;
                memset(&cinfo, 0, sizeof(cinfo));
                if (real_ioctl(cfd, GPIO_GET_CHIPINFO_IOCTL, &cinfo) == 0 &&
                    cinfo.lines > req->offsets[0]) {
                    ret = real_ioctl(cfd, request, arg);
                    if (ret == 0) {
                        dup2(cfd, fd);
                        close(cfd);
                        fprintf(stderr, "[IR-AutoFix] GPIO Line %u aktif pada %s (%s)\n",
                                req->offsets[0], alt, cinfo.label);
                        break;
                    }
                }
                close(cfd);
            }
        }
        if (ret == 0 && req && req->fd > 0) {
            g_ir_line_fd = req->fd;
        }
    }
    return ret;
}

/* 3. Deteksi instan sinyal IR Remote di level kernel poll() */
int poll(struct pollfd *fds, nfds_t nfds, int timeout) {
    if (!real_poll) resolve_libc_symbols();
    int ret = real_poll(fds, nfds, timeout);
    if (ret > 0 && g_is_jws && nfds == 1 && fds && fds[0].fd == g_ir_line_fd && (fds[0].revents & POLLIN)) {
        g_last_input_ms = get_now_ms();
        g_ir_wake = 1;
    }
    return ret;
}

/* 4. Pre-dimming & GL_NEAREST untuk tekstur gambar latar slideshow */
void *SDL_CreateTextureFromSurface(void *renderer, SDL_Surface *surface) {
    if (!real_SDL_CreateTextureFromSurface) resolve_sdl_symbols();
    bool is_bg = false;

    if (g_is_jws && surface && surface->format && surface->pixels &&
        surface->w >= 600 && surface->h >= 340) {
        int bpp = surface->format->BytesPerPixel;
        if (bpp == 3) {
            for (int y = 0; y < surface->h; y++) {
                uint8_t *row = (uint8_t *)surface->pixels + y * surface->pitch;
                int row_bytes = surface->w * 3;
                for (int x = 0; x < row_bytes; x++) {
                    row[x] = (uint8_t)(((unsigned int)row[x] * 166U + 890U) >> 8);
                }
            }
            is_bg = true;
        } else if (bpp == 4 && surface->format->Amask == 0xff000000U) {
            for (int y = 0; y < surface->h; y++) {
                uint8_t *row = (uint8_t *)surface->pixels + y * surface->pitch;
                for (int x = 0; x < surface->w; x++) {
                    row[x * 4 + 0] = (uint8_t)(((unsigned int)row[x * 4 + 0] * 166U + 890U) >> 8);
                    row[x * 4 + 1] = (uint8_t)(((unsigned int)row[x * 4 + 1] * 166U + 890U) >> 8);
                    row[x * 4 + 2] = (uint8_t)(((unsigned int)row[x * 4 + 2] * 166U + 890U) >> 8);
                }
            }
            is_bg = true;
        }
    }

    void *tex = real_SDL_CreateTextureFromSurface(renderer, surface);
    if (g_is_jws && tex && is_bg) {
        if (real_SDL_SetTextureScaleMode) {
            real_SDL_SetTextureScaleMode(tex, 0 /* SDL_ScaleModeNearest */);
        }
        if (g_num_bg_textures < MAX_BG_TEXTURES) {
            g_bg_textures[g_num_bg_textures++] = tex;
        } else {
            g_bg_textures[g_num_bg_textures - 1] = tex;
        }
    }
    return tex;
}

static bool is_bg_texture(void *tex) {
    if (!tex) return false;
    for (int i = 0; i < g_num_bg_textures; i++) {
        if (g_bg_textures[i] == tex) return true;
    }
    return false;
}

/* 5. Deteksi input event dari Keyboard, Mouse, Controller, atau IR Remote */
int SDL_PollEvent(void *event) {
    if (!real_SDL_PollEvent) resolve_sdl_symbols();
    int ret = real_SDL_PollEvent(event);
    if (ret > 0 && g_is_jws && event) {
        uint32_t type = *(uint32_t *)event;
        if ((type >= 0x200 && type <= 0x405) || (type >= 0x600 && type <= 0x660)) {
            g_last_input_ms = get_now_ms();
            g_ir_wake = 1;
            g_render_this_frame = true;
        }
    }
    return ret;
}

int SDL_PushEvent(void *event) {
    if (!real_SDL_PushEvent) resolve_sdl_symbols();
    if (g_is_jws) {
        g_last_input_ms = get_now_ms();
        g_ir_wake = 1;
        g_render_this_frame = true;
    }
    return real_SDL_PushEvent(event);
}

/* 6. Adaptive Frame Skipping & Single-Pass Opaque Blit Optimization */
int SDL_RenderClear(void *renderer) {
    if (!real_SDL_RenderClear) resolve_sdl_symbols();
    if (!g_is_jws || !g_seen_geometry || g_main_frames < 90) {
        g_render_this_frame = true;
        return real_SDL_RenderClear(renderer);
    }

    uint64_t now = get_now_ms();
    time_t now_sec = time(NULL);
    bool active_input = (now - g_last_input_ms < 3500ULL);

    if (active_input) {
        /* Saat ada navigasi remote / tombol, render halus 20-30 FPS */
        g_render_this_frame = true;
    } else if (now_sec != g_last_render_sec || (now - g_last_render_ms >= 220ULL)) {
        /* Mode idle dashboard: sinkron detik jam HH:MM:SS + update halus hemat CPU (< 10%) */
        g_render_this_frame = true;
    } else {
        g_render_this_frame = false;
    }

    g_pending_clear = true;
    g_skip_next_dim_rect = false;
    return 0;
}

int SDL_RenderGeometryRaw(
    void *renderer, void *texture,
    const float *xy, int xy_stride,
    const SDL_Color *color, int color_stride,
    const float *uv, int uv_stride,
    int num_vertices, const void *indices, int num_indices, int size_indices)
{
    if (!real_SDL_RenderGeometryRaw) resolve_sdl_symbols();
    g_seen_geometry = true;

    if (!g_is_jws) {
        return real_SDL_RenderGeometryRaw(
            renderer, texture, xy, xy_stride, color, color_stride,
            uv, uv_stride, num_vertices, indices, num_indices, size_indices);
    }

    /* Jika sedang transisi crossfade slide (0 < alpha < 255 pada gambar latar), paksa render frame ini */
    if (num_vertices == 4 && num_indices == 6 && color && is_bg_texture(texture)) {
        if (color->a > 0 && color->a < 255) {
            g_last_input_ms = get_now_ms();
            g_render_this_frame = true;
        }
    }

    if (!g_render_this_frame) {
        return 0;
    }

    if (g_pending_clear) {
        real_SDL_RenderClear(renderer);
        g_pending_clear = false;
    }

    /* Lewati full-screen alpha-blend dimming rect jika gambar latar sudah di-pre-dim */
    if (g_skip_next_dim_rect && num_vertices == 4 && num_indices == 6 && color) {
        g_skip_next_dim_rect = false;
        if (color->r <= 20 && color->g <= 25 && color->b <= 25 && color->a < 240) {
            return 0;
        }
    }

    /* Gunakan fast opaque blit (SDL_BLENDMODE_NONE) untuk gambar latar penuh yang tidak sedang crossfade */
    if (num_vertices == 4 && num_indices == 6 && color && color->a == 255 &&
        is_bg_texture(texture) && real_SDL_SetTextureBlendMode) {
        real_SDL_SetTextureBlendMode(texture, 0 /* SDL_BLENDMODE_NONE */);
        int rc = real_SDL_RenderGeometryRaw(
            renderer, texture, xy, xy_stride, color, color_stride,
            uv, uv_stride, num_vertices, indices, num_indices, size_indices);
        real_SDL_SetTextureBlendMode(texture, 1 /* SDL_BLENDMODE_BLEND */);
        g_skip_next_dim_rect = true;
        return rc;
    }

    return real_SDL_RenderGeometryRaw(
        renderer, texture, xy, xy_stride, color, color_stride,
        uv, uv_stride, num_vertices, indices, num_indices, size_indices);
}

void SDL_RenderPresent(void *renderer) {
    if (!real_SDL_RenderPresent) resolve_sdl_symbols();
    if (!g_is_jws || !g_seen_geometry) {
        real_SDL_RenderPresent(renderer);
        return;
    }

    g_main_frames++;
    if (!g_render_this_frame) {
        g_pending_clear = false;
        return;
    }

    if (g_pending_clear) {
        real_SDL_RenderClear(renderer);
        g_pending_clear = false;
    }

    real_SDL_RenderPresent(renderer);
    g_last_render_ms = get_now_ms();
    g_last_render_sec = time(NULL);
}

void SDL_Delay(uint32_t ms) {
    if (!real_SDL_Delay) resolve_sdl_symbols();
    if (!g_is_jws || !g_seen_geometry || g_main_frames < 90) {
        real_SDL_Delay(ms);
        return;
    }

    uint64_t now = get_now_ms();
    if (now - g_last_input_ms < 3500ULL) {
        /* Mode interaktif (remote baru ditekan): responsif penuh */
        real_SDL_Delay(ms);
        return;
    }

    /* Mode idle dashboard: tidur dalam potongan 10ms yang langsung bangun (< 10ms)
     * begitu tombol remote IR atau keyboard ditekan, menjaga CPU di bawah 7% */
    uint32_t target_ms = 60;
    uint32_t slept = 0;
    while (slept < target_ms && !g_ir_wake && (get_now_ms() - g_last_input_ms >= 3500ULL)) {
        real_SDL_Delay(10);
        slept += 10;
    }
    g_ir_wake = 0;
}
