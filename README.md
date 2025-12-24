# 🔄 Auto Restore VPS (Marzban + VPN + Bot)

Script `restore.sh` ini digunakan untuk **RESTORE PENUH VPS** yang menjalankan:
- Marzban Panel (Docker)
- Xray / VPN (database user & traffic)
- Nginx (akses publik / domain)
- Bot Telegram

Backup tersimpan aman di **Google Drive (rclone)** dan **sudah termasuk konfigurasi rclone**  
→ **TIDAK perlu `rclone config` ulang saat restore di VPS baru**

---

## 📦 DATA YANG DIRESTORE
Script ini akan mengembalikan data berikut:
- `/var/lib/marzban` → database user VPN (`db.sqlite3`)
- `/opt/marzban` → panel Marzban + `docker-compose.yml`
- `/opt/marzban-bot` → bot Telegram
- `/etc/nginx` → konfigurasi domain / publik
- `/etc/systemd/system` → service bot
- `/root/.config/rclone` → konfigurasi rclone (**AUTO**)

---

## 🔴 SKENARIO 1 — RESTORE DI VPS BARU  
*(VPS lama mati total / data lokal hilang)*

### ⚠️ CATATAN PENTING SEBELUM RESTORE
Jika VPS lama mati dan kamu **beli VPS baru**, **IP pasti berubah**.

👉 **JANGAN LUPA arahkan domain ke IP VPS baru:**
- Update **A record** domain (Cloudflare / DNS provider)
- Tunggu propagasi (biasanya **1–5 menit**)

---

# 1️⃣ Install dependency dasar (WAJIB)
Gunakan perintah ini (**versi aman & lengkap**):

```bash
apt update
apt install -y \
  curl \
  ca-certificates \
  tar \
  docker.io \
  docker-compose-plugin \
  rclone

# 2️⃣ Ambil script restore dari GitHub

```bash
curl -fsSL https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/restore.sh \
  -o /usr/local/bin/vpn-restore && chmod +x /usr/local/bin/vpn-restore

# 3️⃣ Jalankan restore penuh

```Bash
vpn-restore --yes

# ✅ Hasil:
Semua user VPN kembali
Traffic & limit tidak reset
Marzban, Nginx, Bot aktif
Tidak perlu login Google / rclone config
⏱️ Estimasi waktu: ±5–10 menit

# 🟡 SKENARIO 2 — RESTORE DI VPS LAMA
(Rollback / perbaikan tanpa install ulang OS)
🔍 Cek dulu (AMAN, tanpa downtime)

```Bash
vpn-restore --dry-run

# ▶️ Restore backup TERBARU

```Bash
vpn-restore --yes

# ▶️ Restore backup TANGGAL TERTENTU

```Bash
vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes

# 🛟 ROLLBACK DARURAT (JIKA TERJADI ERROR)
Saat restore, script otomatis membuat backup pengaman lokal:

/opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz
Cara rollback manual:

```Bash
tar -xzf /opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz -C /
systemctl daemon-reload
systemctl restart nginx
docker compose -f /opt/marzban/docker-compose.yml up -d
systemctl restart budivpn-bot

# 🧠 CATATAN PENTING
Restore menyebabkan downtime singkat
Script tidak menghapus OS Debian
Backup Google Drive lebih penting daripada snapshot VPS
VPS boleh mati, data tetap aman

# ✅ PERINTAH YANG PERLU DIINGAT

Bash
```backup                 # backup manual
```vpn-restore --dry-run  # cek restore (aman)
```vpn-restore --yes      # restore penuh
