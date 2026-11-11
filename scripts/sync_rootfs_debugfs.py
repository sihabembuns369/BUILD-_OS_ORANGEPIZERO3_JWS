#!/usr/bin/env python3
import os, subprocess, sys

ROOTFS = "build/rootfs.img"
OVERLAY_DIR = "overlay"

if not os.path.isfile(ROOTFS):
    print(f"Error: {ROOTFS} tidak ditemukan!")
    sys.exit(1)

def run_debugfs(cmds):
    proc = subprocess.Popen(
        ["debugfs", "-w", ROOTFS],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    out, err = proc.communicate(input="\n".join(cmds) + "\n")
    return out, err

print("==> Mengumpulkan berkas overlay...")
regular_files = []
symlinks = []
dirs_to_ensure = set()

for root, dirs, files in os.walk(OVERLAY_DIR):
    for d in dirs:
        host_d = os.path.join(root, d)
        rel_dir = os.path.relpath(host_d, OVERLAY_DIR)
        dirs_to_ensure.add("/" + rel_dir)
    for f in files:
        host_path = os.path.join(root, f)
        target_path = "/" + os.path.relpath(host_path, OVERLAY_DIR)
        if os.path.islink(host_path):
            link_target = os.readlink(host_path)
            symlinks.append((target_path, link_target))
        else:
            regular_files.append((host_path, target_path))

# Urutkan direktori berdasarkan kedalaman
sorted_dirs = sorted(list(dirs_to_ensure), key=lambda x: x.count('/'))

cmds = []
for d in sorted_dirs:
    cmds.append(f"mkdir {d}")

# Tulis berkas biasa
for host_path, target_path in regular_files:
    cmds.append(f"rm {target_path}")
    cmds.append(f"write {host_path} {target_path}")
    if "/bin/" in target_path or "/sbin/" in target_path or target_path.endswith(".sh") or target_path == "/opt/jws/jws" or target_path.endswith("jadwalsholat_imgui") or "/opt/jws/yt-dlp" in target_path:
        cmds.append(f"set_inode_field {target_path} mode 0100755")
    elif ".so" in target_path:
        cmds.append(f"set_inode_field {target_path} mode 0100755")
    else:
        cmds.append(f"set_inode_field {target_path} mode 0100644")

# Buat symlink
for target_path, link_dest in symlinks:
    cmds.append(f"rm {target_path}")
    cmds.append(f"symlink {target_path} {link_dest}")

# Set permission khusus
cmds.append("set_inode_field /etc/sudoers.d/jws mode 0100440")
cmds.append("set_inode_field /etc/fstab mode 0100644")
cmds.append("set_inode_field /home/jws/.ssh uid 1000")
cmds.append("set_inode_field /home/jws/.ssh gid 1000")
cmds.append("set_inode_field /home/jws/.ssh mode 040700")
cmds.append("set_inode_field /home/jws/.ssh/authorized_keys uid 1000")
cmds.append("set_inode_field /home/jws/.ssh/authorized_keys gid 1000")
cmds.append("set_inode_field /home/jws/.ssh/authorized_keys mode 0100600")

print(f"==> Menulis {len(regular_files)} berkas dan {len(symlinks)} symlinks ke {ROOTFS} via debugfs...")
out, err = run_debugfs(cmds)

print("==> Memeriksa kebersihan file system dengan e2fsck...")
proc = subprocess.run(["/sbin/e2fsck", "-fy", ROOTFS], capture_output=True, text=True)

proc2 = subprocess.run(["/sbin/e2fsck", "-f", "-n", ROOTFS], capture_output=True, text=True)
if proc2.returncode == 0:
    print("==> ROOTFS 100% BERSIH DAN VALID!")
else:
    print(f"Peringatan e2fsck: {proc2.stdout}")
