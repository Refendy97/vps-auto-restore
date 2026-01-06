diff --git a/README.md b/README.md
index c134cbd4cd45341ec04030122c79df3387b00e68..f39df9ec83449bc25ecc3ba2dd34ffcdc155804f 100644
--- a/README.md
+++ b/README.md
@@ -1,119 +1,113 @@
- ## 🔴 SKENARIO 1 — VPS BARU (Debian 11 / 12)
- 
- ### 1️⃣ Install dependency (AUTO)
- ```bash
- apt update
- apt install -y \
-   curl \
-   ca-certificates \
-   tar \
-   docker.io \
-   docker-compose-plugin \
-   docker-compose \
-   rclone
--2️⃣ Ambil script restore dari GitHub
--Salin kode
--Bash
-+```
-+
-+### 2️⃣ Ambil script restore dari GitHub
-+```bash
- curl -fsSL https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/restore.sh \
-   -o /usr/local/bin/vpn-restore
- chmod +x /usr/local/bin/vpn-restore
--3️⃣ Jalankan restore penuh
--Salin kode
--Bash
-+```
-+
-+### 3️⃣ Jalankan restore penuh
-+```bash
- vpn-restore --yes
--✅ Semua user VPN kembali
--✅ Traffic & limit tidak reset
--✅ Marzban, Nginx, Bot aktif
-+```
-+
-+✅ Semua user VPN kembali  
-+✅ Traffic & limit tidak reset  
-+✅ Marzban, Nginx, Bot aktif  
- ⏱️ Estimasi waktu: ±5–10 menit
--🟡 SKENARIO 2 — VPS LAMA (Rollback / Repair)
--🔍 Cek dulu (AMAN, tanpa perubahan)
--Salin kode
--Bash
-+
-+---
-+
-+## 🟡 SKENARIO 2 — VPS LAMA (Rollback / Repair)
-+
-+### 🔍 Cek dulu (AMAN, tanpa perubahan)
-+```bash
- vpn-restore --dry-run
--▶️ Restore backup TERBARU
--Salin kode
--Bash
-+```
-+
-+### ▶️ Restore backup TERBARU
-+```bash
- vpn-restore --yes
--▶️ Restore backup TANGGAL TERTENTU
--Salin kode
--Bash
-+```
-+
-+### ▶️ Restore backup TANGGAL TERTENTU
-+```bash
- vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes
--🛟 ROLLBACK DARURAT
-+```
-+
-+---
-+
-+## 🛟 ROLLBACK DARURAT
- Saat restore, script otomatis membuat backup pengaman lokal:
--Salin kode
- 
-+```
- /opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz
-+```
-+
- Rollback manual:
--Salin kode
--Bash
-+```bash
- tar -xzf /opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz -C /
- systemctl daemon-reload
- systemctl restart nginx
- docker compose -f /opt/marzban/docker-compose.yml up -d
- systemctl restart budivpn-bot
--✅ PERINTAH PENTING
--Salin kode
--Bash
-+```
-+
-+---
-+
-+## ✅ PERINTAH PENTING
-+```bash
- backup
- vpn-restore --dry-run
- vpn-restore --yes
- vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes
--🧠 CATATAN
--Script sudah diuji langsung di VPS aktif
--Tidak perlu edit restore.sh
--Debian 11 / 12 auto
--Backup Google Drive lebih penting dari snapshot VPS
-\ No newline at end of file
-+```
-+
-+---
-+
-+## 🧠 CATATAN
-+- Script sudah diuji langsung di VPS aktif.
-+- Tidak perlu edit `restore.sh`.
-+- Debian 11 / 12 auto.
-+- Backup Google Drive lebih penting dari snapshot VPS.
- 
\ No newline at end of file
+## 🔴 SKENARIO 1 — VPS BARU (Debian 11 / 12)
+
+### 1️⃣ Install dependency (AUTO)
+```bash
+apt update
+```
+
+```bash
+apt install -y \
+  curl \
+  ca-certificates \
+  tar \
+  docker.io \
+  docker-compose-plugin \
+  docker-compose \
+  rclone
+```
+
+### 2️⃣ Ambil script restore dari GitHub
+```bash
+curl -fsSL https://raw.githubusercontent.com/Refendy97/vps-auto-restore/main/restore.sh \
+  -o /usr/local/bin/vpn-restore
+```
+
+```bash
+chmod +x /usr/local/bin/vpn-restore
+```
+
+### 3️⃣ Jalankan restore penuh
+```bash
+vpn-restore --yes
+```
+
+✅ Semua user VPN kembali  
+✅ Traffic & limit tidak reset  
+✅ Marzban, Nginx, Bot aktif  
+⏱️ Estimasi waktu: ±5–10 menit
+
+---
+
+## 🟡 SKENARIO 2 — VPS LAMA (Rollback / Repair)
+
+### 🔍 Cek dulu (AMAN, tanpa perubahan)
+```bash
+vpn-restore --dry-run
+```
+
+### ▶️ Restore backup TERBARU
+```bash
+vpn-restore --yes
+```
+
+### ▶️ Restore backup TANGGAL TERTENTU
+```bash
+vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes
+```
+
+---
+
+## 🛟 ROLLBACK DARURAT
+Saat restore, script otomatis membuat backup pengaman lokal:
+
+```
+/opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz
+```
+
+Rollback manual:
+```bash
+tar -xzf /opt/restore-run/pre-restore-YYYY-MM-DD_HHMMSS.tar.gz -C /
+```
+
+```bash
+systemctl daemon-reload
+```
+
+```bash
+systemctl restart nginx
+```
+
+```bash
+docker compose -f /opt/marzban/docker-compose.yml up -d
+```
+
+```bash
+systemctl restart budivpn-bot
+```
+
+---
+
+## ✅ PERINTAH PENTING
+```bash
+backup
+```
+
+```bash
+vpn-restore --dry-run
+```
+
+```bash
+vpn-restore --yes
+```
+
+```bash
+vpn-restore --backup vpn-backup-YYYY-MM-DD.tar.gz --yes
+```
+
+---
+
+## 🧠 CATATAN
+- Script sudah diuji langsung di VPS aktif.
+- Tidak perlu edit `restore.sh`.
+- Debian 11 / 12 auto.
+- Backup Google Drive lebih penting dari snapshot VPS.
