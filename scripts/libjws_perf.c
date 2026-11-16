#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <time.h>
#include <sys/ioctl.h>
#include <linux/gpio.h>

extern char *program_invocation_short_name;

static bool g_is_jws = false;
static uint64_t g_last_render_ms = 0;
static uint64_t g_last_input_ms = 0;

static int (*real_open)(const char *pathname, int flags, ...) = NULL;
static int (*real_ioctl)(int fd, unsigned long request, ...) = NULL;
static void (*real_SDL_RenderPresent)(void *renderer) = NULL;
static int (*real_SDL_PollEvent)(void *event) = NULL;
static int (*real_SDL_PushEvent)(void *event) = NULL;
static void (*real_SDL_Delay)(uint32_t ms) = NULL;

static uint64_t get_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ULL + (uint64_t)(ts.tv_nsec / 1000000ULL);
}

static void resolve_symbols(void) {
    if (!real_open) real_open = dlsym(RTLD_NEXT, "open");
    if (!real_ioctl) real_ioctl = dlsym(RTLD_NEXT, "ioctl");
    if (!real_SDL_RenderPresent) real_SDL_RenderPresent = dlsym(RTLD_NEXT, "SDL_RenderPresent");
    if (!real_SDL_PollEvent) real_SDL_PollEvent = dlsym(RTLD_NEXT, "SDL_PollEvent");
    if (!real_SDL_PushEvent) real_SDL_PushEvent = dlsym(RTLD_NEXT, "SDL_PushEvent");
    if (!real_SDL_Delay) real_SDL_Delay = dlsym(RTLD_NEXT, "SDL_Delay");
}

__attribute__((constructor))
static void jws_perf_init(void) {
    resolve_symbols();
    if (program_invocation_short_name &&
        strcmp(program_invocation_short_name, "jadwalsholat_imgui") == 0) {
        g_is_jws = true;
        g_last_input_ms = get_now_ms();

        if (access("settings.json", F_OK) != 0 && access("/opt/jws/settings.json", F_OK) == 0) {
            int r = chdir("/opt/jws");
            (void)r;
        }

        if (!getenv("DISPLAY") && !getenv("WAYLAND_DISPLAY")) {
            setenv("SDL_VIDEODRIVER", "kmsdrm", 0);
        }
        setenv("SDL_RENDER_DRIVER", "opengles2", 0);
        setenv("SDL_AUDIODRIVER", "dummy", 0);
        setenv("SDL_RENDER_VSYNC", "1", 0);
        setenv("SDL_HINT_RENDER_BATCHING", "1", 0);

        if (access("/dev/dri/renderD128", F_OK) != 0) {
            setenv("LIBGL_ALWAYS_SOFTWARE", "1", 1);
            setenv("MESA_LOADER_DRIVER_OVERRIDE", "kms_swrast", 1);
            setenv("GALLIUM_DRIVER", "llvmpipe", 1);
            setenv("LP_NUM_THREADS", "1", 0);
            setenv("MESA_NO_ERROR", "1", 0);
            setenv("MESA_GL_VERSION_OVERRIDE", "2.1", 1);
            setenv("MESA_GLES_VERSION_OVERRIDE", "2.0", 1);
        }
    }
}

/* 1. Auto-redirect GPIO ke /dev/gpiochip0 jika gpiochip yang dibuka <= 32 lines */
int open(const char *pathname, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (!real_open) resolve_symbols();

    if (g_is_jws && pathname && strncmp(pathname, "/dev/gpiochip", 13) == 0) {
        int fd = real_open(pathname, flags, mode);
        if (fd >= 0 && real_ioctl) {
            struct gpiochip_info cinfo;
            memset(&cinfo, 0, sizeof(cinfo));
            if (real_ioctl(fd, GPIO_GET_CHIPINFO_IOCTL, &cinfo) == 0 && cinfo.lines <= 32) {
                close(fd);
                return real_open("/dev/gpiochip0", flags, mode);
            }
        }
        return fd;
    }
    return real_open(pathname, flags, mode);
}

int SDL_PollEvent(void *event) {
    if (!real_SDL_PollEvent) resolve_symbols();
    int ret = real_SDL_PollEvent(event);
    if (g_is_jws && ret > 0) {
        g_last_input_ms = get_now_ms();
    }
    return ret;
}

int SDL_PushEvent(void *event) {
    if (!real_SDL_PushEvent) resolve_symbols();
    if (g_is_jws) {
        g_last_input_ms = get_now_ms();
    }
    return real_SDL_PushEvent(event);
}

/* 2. Log active SDL renderer once and avoid extra throttling beyond app's 30 FPS / VSync */
typedef struct {
    const char *name;
    uint32_t flags;
    uint32_t num_texture_formats;
    uint32_t texture_formats[16];
    int max_texture_width;
    int max_texture_height;
} JwsSDLRendererInfo;

void SDL_RenderPresent(void *renderer) {
    static int logged_renderer = 0;
    if (!real_SDL_RenderPresent) resolve_symbols();
    if (!logged_renderer && g_is_jws && renderer) {
        logged_renderer = 1;
        int (*fn_info)(void *, JwsSDLRendererInfo *) = dlsym(RTLD_NEXT, "SDL_GetRendererInfo");
        const char *(*fn_vid)(void) = dlsym(RTLD_NEXT, "SDL_GetCurrentVideoDriver");
        JwsSDLRendererInfo info;
        memset(&info, 0, sizeof(info));
        if (fn_info && fn_info(renderer, &info) == 0) {
            fprintf(stderr, "[JWS-PERF] SDL video=%s renderer=%s flags=0x%x LP_NUM_THREADS=%s\n",
                    fn_vid ? (fn_vid() ? fn_vid() : "?") : "?",
                    info.name ? info.name : "?",
                    info.flags,
                    getenv("LP_NUM_THREADS") ? getenv("LP_NUM_THREADS") : "unset");
            fflush(stderr);
        }
    }
    real_SDL_RenderPresent(renderer);

    if (!g_is_jws) return;

    /* Aplikasi jadwalsholat_imgui sudah memiliki limiter 30 FPS (33ms) + SDL_RENDER_VSYNC.
     * Jangan menyuntikkan sleep 70ms tambahan di sini agar animasi & navigasi tidak patah-patah. */
    g_last_render_ms = get_now_ms();
    (void)g_last_input_ms;
}
