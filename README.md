# VPS Auto Restore 🔧

Script otomatis untuk restore VPN Marzban, Nginx, dan Bot di VPS dengan mudah.

---

## 🔴 SKENARIO 1 — VPS BARU (Debian 11 / 12)

### 1️⃣ Install dependency (AUTO)
```bash
apt install -y \
  curl ca-certificates tar unzip cron \
  iptables iproute2 net-tools \
  openssl coreutils \
  docker.io docker-compose-plugin docker-compose \
  nginx \
  python3 python3-venv python3-pip \
  rclone
```
### Aktifkan docker & nginx:
```bash
systemctl enable --now docker
systemctl enable --now nginx
```


### 2️⃣ Ambil script install.sh dari GitHub
```bash
curl -fsSL https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/install.sh | bash
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
vpn-restore YYYY-MM-DD --yes
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
vpn-backup
vpn-restore --dry-run
vpn-restore --yes
vpn-backup-YYYY-MM-DD --yes
```

---

## 🧠 CATATAN
- Script sudah diuji langsung di VPS aktif.
- Tidak perlu edit `restore.sh`.
- Debian 11 / 12 auto.
- Backup Google Drive lebih penting dari snapshot VPS.