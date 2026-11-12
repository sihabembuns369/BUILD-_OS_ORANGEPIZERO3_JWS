#!/usr/bin/env python3
"""
Generator Animasi Booting Ultra-Realistik & Keren untuk Orange Pi Zero 3 JWS
Tema: Celestial Islamic Astrolabe & 3D Metallic Gold Crescent Moon
Menghasilkan:
- 30 Frame PNG resolusi native 320x320 RGBA (zero scaling overhead di Plymouth)
- File GIF animasi 'boot.gif' (30 frames, loop sempurna)
- File U-Boot splash 'splash.bmp' (1280x720, 24-bit uncompressed BMP, posisi pas)
"""

import os
import math
import numpy as np
from PIL import Image

SIZE = 320
TOTAL_FRAMES = 30
CX, CY = SIZE / 2.0, SIZE / 2.0

def render_frame(frame_idx):
    t = frame_idx / float(TOTAL_FRAMES)
    phase = t * 2.0 * math.pi

    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.float32)

    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    dx = x - CX
    dy = y - CY
    dist = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)

    # -------------------------------------------------------------------------
    # 1. Cosmic Atmosphere & Deep Emerald Nebula Aura
    # -------------------------------------------------------------------------
    aura_r = 152.0
    aura_falloff = np.clip(1.0 - (dist / aura_r), 0.0, 1.0)
    aura_pulse = 0.86 + 0.14 * math.sin(phase)
    aura_mask = (aura_falloff ** 2.4) * aura_pulse

    # Gradasi kosmik teal-zamrud lembut di kanvas tengah
    rgba[:, :, 0] += aura_mask * 14.0
    rgba[:, :, 1] += aura_mask * 80.0
    rgba[:, :, 2] += aura_mask * 105.0
    rgba[:, :, 3] += aura_mask * 120.0

    # -------------------------------------------------------------------------
    # 2. Sacred Astrolabe Orbital Rings & Coordinate Geometry
    # -------------------------------------------------------------------------
    r_main = 104.0
    r_in = 88.0
    r_out = 118.0

    # Cincin orbit anti-aliased halus
    ring_main = np.exp(-((dist - r_main) ** 2) / 2.2)
    ring_in = np.exp(-((dist - r_in) ** 2) / 1.6)
    ring_out = np.exp(-((dist - r_out) ** 2) / 1.6)
    ring_all = ring_main * 0.90 + ring_in * 0.40 + ring_out * 0.45

    ring_pulse = 0.90 + 0.10 * math.sin(phase)
    rgba[:, :, 0] += ring_all * 235.0 * ring_pulse
    rgba[:, :, 1] += ring_all * 195.0 * ring_pulse
    rgba[:, :, 2] += ring_all * 95.0 * ring_pulse
    rgba[:, :, 3] += ring_all * 225.0 * ring_pulse

    # 24 Penanda Menit Halus (Minor Subdivisions)
    for j in range(24):
        sub_ang = j * (math.pi / 12.0)
        d_sub = np.abs(np.arctan2(np.sin(ang - sub_ang), np.cos(ang - sub_ang)))
        sub_dist = np.abs(dist - r_out)
        sub_tick = np.exp(-(sub_dist ** 2) / 2.0) * np.exp(-(d_sub * r_out) ** 2 / 2.5)
        rgba[:, :, 0] += sub_tick * 170.0
        rgba[:, :, 1] += sub_tick * 150.0
        rgba[:, :, 2] += sub_tick * 80.0
        rgba[:, :, 3] += sub_tick * 180.0

    # 12 Penanda Waktu Jam Sholat Utama (Major Celestial Hour Nodes)
    for i in range(12):
        m_ang = i * (math.pi / 6.0)
        d_ang = np.abs(np.arctan2(np.sin(ang - m_ang), np.cos(ang - m_ang)))
        m_dist = np.abs(dist - r_main)
        marker = np.exp(-(m_dist ** 2) / 3.2) * np.exp(-(d_ang * r_main) ** 2 / 4.8)

        # Efek gelombang energi komet saat melintasi tiap penanda
        diff_phase = np.abs(np.arctan2(np.sin(m_ang - phase), np.cos(m_ang - phase)))
        boost = 1.0 + 1.4 * np.exp(-(diff_phase ** 2) / 0.18)

        rgba[:, :, 0] += marker * 215.0 * boost
        rgba[:, :, 1] += marker * 250.0 * boost
        rgba[:, :, 2] += marker * 230.0 * boost
        rgba[:, :, 3] += marker * 245.0 * boost

    # -------------------------------------------------------------------------
    # 3. Dynamic Orbiting Comet & Luminous Stardust Particle Stream
    # -------------------------------------------------------------------------
    tail_len = 24
    for k in range(tail_len):
        decay = (1.0 - (k / float(tail_len))) ** 1.85
        t_ang = phase - k * 0.082
        tx = CX + math.cos(t_ang) * r_main
        ty = CY + math.sin(t_ang) * r_main
        d_t = np.hypot(x - tx, y - ty)
        spread = 2.0 + k * 0.35
        blob = np.exp(-(d_t ** 2) / (2.0 * spread ** 2)) * decay

        if k == 0:
            # Inti komet: putih cemerlang bersinar intensif
            rgba[:, :, 0] += blob * 255.0
            rgba[:, :, 1] += blob * 255.0
            rgba[:, :, 2] += blob * 255.0
            rgba[:, :, 3] += blob * 255.0
        else:
            # Ekor komet: gradasi cyan listrik -> zamrud zamrud berkilau
            t_ratio = k / float(tail_len)
            r_val = (1.0 - t_ratio) * 100.0 + t_ratio * 16.0
            g_val = (1.0 - t_ratio) * 240.0 + t_ratio * 185.0
            b_val = (1.0 - t_ratio) * 255.0 + t_ratio * 129.0
            rgba[:, :, 0] += blob * r_val
            rgba[:, :, 1] += blob * g_val
            rgba[:, :, 2] += blob * b_val
            rgba[:, :, 3] += blob * (230.0 * decay)

    # Butiran Debu Bintang Terapung (Ambient Floating Stardust)
    for s in range(8):
        s_ang = s * (math.pi / 4.0) + phase * 0.65
        s_r = r_main + 6.0 * math.sin(phase * 2.0 + s)
        sp_x = CX + math.cos(s_ang) * s_r
        sp_y = CY + math.sin(s_ang) * s_r
        d_sp = np.hypot(x - sp_x, y - sp_y)
        spark = np.exp(-(d_sp ** 2) / 2.2) * (0.6 + 0.4 * math.sin(phase * 3.0 + s))
        rgba[:, :, 0] += spark * 240.0
        rgba[:, :, 1] += spark * 255.0
        rgba[:, :, 2] += spark * 220.0
        rgba[:, :, 3] += spark * 220.0

    # -------------------------------------------------------------------------
    # 4. Realistic 3D Metallic Golden Crescent Moon (SDF & Dual-Light Shading)
    # -------------------------------------------------------------------------
    m_cx, m_cy = CX - 2.0, CY
    r1 = 48.0   # Jari-jari kurva luar bulan sabit
    r2 = 41.0   # Jari-jari pemotong kurva dalam
    off_x = 16.0
    off_y = -3.0

    d1 = np.hypot(x - m_cx, y - m_cy)
    d2 = np.hypot(x - (m_cx + off_x), y - (m_cy + off_y))

    # Signed Distance Field (SDF) kurva bulan sabit
    sdf = np.maximum(d1 - r1, -(d2 - r2))
    moon_mask = np.clip(0.5 - sdf * 1.25, 0.0, 1.0)

    # Hitung Vektor Normal Permukaan 3D (Surface Normal Gradient)
    eps = 0.8
    dx1 = np.hypot(x + eps - m_cx, y - m_cy)
    dx2 = np.hypot(x + eps - (m_cx + off_x), y - (m_cy + off_y))
    sdf_x = np.maximum(dx1 - r1, -(dx2 - r2))

    dy1 = np.hypot(x - m_cx, y + eps - m_cy)
    dy2 = np.hypot(x - (m_cx + off_x), y + eps - (m_cy + off_y))
    sdf_y = np.maximum(dy1 - r1, -(dy2 - r2))

    grad_x = (sdf_x - sdf) / eps
    grad_y = (sdf_y - sdf) / eps
    # Kelengkungan kubah 3D halus (dome volume)
    dome_z = np.sqrt(np.maximum(0.0, 1.0 - np.clip(grad_x ** 2 + grad_y ** 2, 0.0, 0.96)))

    # Dual Light Sources:
    # 1. Lampu Utama Emas Hangat (Key Sun Light dari kiri atas)
    lx1, ly1, lz1 = -0.58, -0.62, 0.72
    # 2. Lampu Pemantul Tepi (Rim Fill Light bernuansa zamrud kosmik dari kanan bawah)
    lx2, ly2, lz2 = 0.62, 0.58, 0.35

    diffuse1 = np.maximum(0.0, -(grad_x * lx1 + grad_y * ly1) + dome_z * lz1)
    diffuse2 = np.maximum(0.0, -(grad_x * lx2 + grad_y * ly2) + dome_z * lz2)

    # Kilau Refleksi Spekular Logam Emas (Blinn-Phong)
    specular1 = np.maximum(0.0, -(grad_x * (lx1 - 0.22)) + dome_z * 0.90) ** 28.0

    # Kilau Cahaya Berjalan di Sepanjang Sudut Sabit (Rotating Edge Glint)
    glint_ang = phase
    gx = math.cos(glint_ang)
    gy = math.sin(glint_ang)
    dot_glint = np.maximum(0.0, -(grad_x * gx + grad_y * gy))
    edge_glint = (dot_glint ** 12.0) * (0.8 + 0.2 * math.sin(phase))

    # Ambient Occlusion di Cekungan Sabit
    ao = np.clip(1.0 - np.abs(sdf) / 10.0, 0.0, 1.0) ** 0.52

    # Palet Warna Emas Murni 24K Realistik
    gold_r = (248.0 * diffuse1 + 80.0 * diffuse2 + 255.0 * specular1 + 180.0 * edge_glint + 42.0) * ao
    gold_g = (185.0 * diffuse1 + 155.0 * diffuse2 + 250.0 * specular1 + 160.0 * edge_glint + 30.0) * ao
    gold_b = (36.0 * diffuse1 + 195.0 * diffuse2 + 160.0 * specular1 + 70.0 * edge_glint + 12.0) * ao

    # Pendaran Aura Emas Halus (Corona Bloom) di Sekitar Sabit
    moon_glow = np.exp(-((np.maximum(0.0, sdf)) ** 2) / 38.0) * (0.86 + 0.14 * math.sin(phase))
    rgba[:, :, 0] += moon_glow * 215.0 * (1.0 - moon_mask)
    rgba[:, :, 1] += moon_glow * 155.0 * (1.0 - moon_mask)
    rgba[:, :, 2] += moon_glow * 35.0 * (1.0 - moon_mask)
    rgba[:, :, 3] += moon_glow * 165.0 * (1.0 - moon_mask)

    # Gabungkan Logam Bulan Sabit ke Kanvas
    rgba[:, :, 0] = rgba[:, :, 0] * (1.0 - moon_mask) + gold_r * moon_mask
    rgba[:, :, 1] = rgba[:, :, 1] * (1.0 - moon_mask) + gold_g * moon_mask
    rgba[:, :, 2] = rgba[:, :, 2] * (1.0 - moon_mask) + gold_b * moon_mask
    rgba[:, :, 3] = np.maximum(rgba[:, :, 3], moon_mask * 255.0)

    # -------------------------------------------------------------------------
    # 5. Brilliant 8-Point Diamond Star in the Cradle (Bintang Berlian Optik)
    # -------------------------------------------------------------------------
    s_cx = CX + 22.0
    s_cy = CY - 20.0
    sx = x - s_cx
    sy = y - s_cy
    s_dist = np.hypot(sx, sy)

    # 4 Sinar Utama (Horizontal & Vertikal)
    ray_v = np.exp(-(sx ** 2) / 1.5) * np.exp(-(sy ** 2) / 58.0)
    ray_h = np.exp(-(sy ** 2) / 1.5) * np.exp(-(sx ** 2) / 58.0)

    # 4 Sinar Diagonal (45 Derajat)
    d_d1 = (sx + sy) * 0.7071
    d_d2 = (sx - sy) * 0.7071
    ray_d1 = np.exp(-(d_d1 ** 2) / 1.5) * np.exp(-(d_d2 ** 2) / 30.0) * 0.65
    ray_d2 = np.exp(-(d_d2 ** 2) / 1.5) * np.exp(-(d_d1 ** 2) / 30.0) * 0.65

    # Inti Bintang Berlian Putih Panas & Lingkaran Difraksi
    star_core = np.exp(-(s_dist ** 2) / 8.0)
    star_corona = np.exp(-((s_dist - 8.0) ** 2) / 4.0) * 0.35

    star_pulse = 0.82 + 0.18 * math.cos(phase * 2.0)
    star_flares = (ray_v + ray_h + ray_d1 + ray_d2 + star_core + star_corona) * star_pulse

    rgba[:, :, 0] += star_flares * 255.0
    rgba[:, :, 1] += star_flares * 248.0
    rgba[:, :, 2] += star_flares * 190.0
    rgba[:, :, 3] += np.clip(star_flares * 255.0, 0.0, 255.0)

    rgba = np.clip(rgba, 0.0, 255.0).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(script_dir)

    theme_dir = os.path.join(root_dir, "overlay", "usr", "share", "plymouth", "themes", "jws-animated")
    assets_dir = os.path.join(root_dir, "default_assets")
    os.makedirs(theme_dir, exist_ok=True)
    os.makedirs(assets_dir, exist_ok=True)

    print(f"🌟 Membuat {TOTAL_FRAMES} frame animasi realistik (320x320 RGBA)...")
    frames = []
    for i in range(TOTAL_FRAMES):
        img = render_frame(i)
        frames.append(img)
        # Format penamaan Plymouth: frame_001.png s/d frame_030.png
        frame_name = f"frame_{i+1:03d}.png"
        img.save(os.path.join(theme_dir, frame_name), "PNG", optimize=True)
        if (i + 1) % 5 == 0 or (i + 1) == TOTAL_FRAMES:
            print(f"   -> Frame {i+1}/{TOTAL_FRAMES} selesai.")

    # 1. Simpan default_logo.png & splash.png (Frame pertama)
    frames[0].save(os.path.join(theme_dir, "default_logo.png"), "PNG")
    frames[0].save(os.path.join(theme_dir, "splash.png"), "PNG")
    frames[0].save(os.path.join(assets_dir, "logo.png"), "PNG")

    # 2. Buat Animated GIF (boot.gif)
    print("🎬 Mengemas ke default_assets/boot.gif (30 FPS, loop sempurna)...")
    gif_path = os.path.join(assets_dir, "boot.gif")
    gif_frames = []
    for f in frames:
        bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        bg.alpha_composite(f)
        gif_frames.append(bg.convert("P", palette=Image.ADAPTIVE, colors=128))

    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=33, # ~30 FPS (33ms per frame)
        loop=0,
        optimize=True,
        disposal=2
    )
    print(f"✅ Berhasil membuat GIF: {gif_path} ({os.path.getsize(gif_path) / 1024:.1f} KB)")

    # 3. Buat U-Boot Static Splash BMP (1280x720 24-bit uncompressed, centered)
    print("🖼️  Membuat default_assets/splash.bmp (1280x720 24-bit Windows BMP)...")
    canvas_w, canvas_h = 1280, 720
    bmp_canvas = Image.new("RGB", (canvas_w, canvas_h), (0, 0, 0)) # Latar hitam murni
    # Paste frame pertama tepat di tengah layar sesuai koordinat Plymouth: pos_y = (720 - 320)/2 - 20 = 180
    paste_x = (canvas_w - SIZE) // 2
    paste_y = (canvas_h - SIZE) // 2 - 20
    bmp_canvas.paste(frames[0], (paste_x, paste_y), mask=frames[0])

    bmp_path = os.path.join(assets_dir, "splash.bmp")
    bmp_canvas.save(bmp_path, "BMP")
    print(f"✅ Berhasil membuat splash BMP: {bmp_path} ({os.path.getsize(bmp_path) / (1024*1024):.2f} MB)")

    # 4. Perbarui tema Plymouth jws-animated.script
    script_path = os.path.join(theme_dir, "jws-animated.script")
    template_path = os.path.join(theme_dir, "jws-animated.script.template")
    if os.path.exists(template_path):
        with open(template_path, "r") as tf:
            body = tf.read()
        header = f"""# jws-animated.script - Dibuat otomatis untuk Orange Pi Zero 3 JWS
mode = "gif";
bg_r = 0.000;
bg_g = 0.000;
bg_b = 0.000;
scale_mode = "fit";
position_mode = "center";
frame_count = {TOTAL_FRAMES};
target_fps = 30;
loop_mode = 1;
text_msg = "";
text_r = 1.000;
text_g = 1.000;
text_b = 1.000;

"""
        with open(script_path, "w") as sf:
            sf.write(header + body)
        print("✅ jws-animated.script berhasil diperbarui dengan frame_count = 30 & target_fps = 30!")

if __name__ == "__main__":
    main()
