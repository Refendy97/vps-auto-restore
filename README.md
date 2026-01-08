# VPS Auto Restore 🔧

Script otomatis untuk restore VPN Marzban, Nginx, dan Bot di VPS dengan mudah.

---

## 🔴 SKENARIO 1 — VPS BARU (Debian 11 / 12)

### 1️⃣ Install dependency (AUTO)
```bash
apt update
apt install -y \
  curl \
  ca-certificates \
  tar \
  docker.io \
  docker-compose-plugin \
  docker-compose \
  rclone
```

### 2️⃣ Ambil script restore dari GitHub
```bash
curl -fsSL https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/restore.sh \
  -o /usr/local/bin/vpn-restore
chmod +x /usr/local/bin/vpn-restore
```

### 3️⃣ Jalankan restore penuh
```bash
vpn-restore --yes
```

✅ Semua user VPN kembali  
✅ Traffic & limit tidak reset  
✅ Marzban, Nginx, Bot aktif  
⏱️ Estimasi waktu: ±5–10 menit

---

## 🟡 SKENARIO 2 — VPS LAMA (Rollback / Repair)

### 🔍 Cek dulu (AMAN, tanpa perubahan)
```bash
vpn-restore --dry-run
```

### ▶️ Restore backup TERBARU
```bash
vpn-restore --yes
```

### ▶️ Restore backup TANGGAL TERTENTU
```bash
vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes
```

---

## 🛟 ROLLBACK DARURAT

Saat restore, script otomatis membuat backup pengaman lokal:
```
/opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz
```

Rollback manual:
```bash
tar -xzf /opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz -C /
systemctl daemon-reload
systemctl restart nginx
docker compose -f /opt/marzban/docker-compose.yml up -d
systemctl restart budivpn-bot
```

---

## ✅ PERINTAH PENTING
```bash
backup
vpn-restore --dry-run
vpn-restore --yes
vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes
```

---

## 🧠 CATATAN
- Script sudah diuji langsung di VPS aktif.
- Tidak perlu edit `restore.sh`.
- Debian 11 / 12 auto.
- Backup Google Drive lebih penting dari snapshot VPS.