🧩 Config Backup Script

這是一個 自動化備份各服務設定檔 的 Shell Script，
可依照單一 YAML 檔的設定，將多個服務的設定檔或資料夾收集起來，統一打包成壓縮檔，
方便系統管理員或自動化備份系統（如外接硬碟同步、NAS 備份）統一抓取。

✨ 功能簡介

以單一設定檔 config_backup.yaml 控制所有服務備份。

支援：

多服務配置

多檔案、多資料夾、多萬用字元 (*, **)

自動建立備份路徑與暫存資料夾

防止檔名衝突（自動加上雜湊後綴）

自動打包為 .tar.gz

執行後會在 backup_dir 目錄中生成：

config_backup_YYYY-MM-DD HH:MM.tar.gz

🗂️ YAML 設定檔格式

預設路徑：/etc/config_backup.yaml
（也可自行放在任意位置並於執行時指定）

backup_dir: /mnt/backup          # 壓縮檔輸出路徑（本機）
root_dir_name: config_backup     # 壓縮檔內最上層資料夾名稱（可省略）

services:
  - name: kafka
    config_paths:                # 要備份的「單一檔案」
      - /var/log/kafka/server.properties
      - /var/log/kafka/controller.properties

  - name: mongodb
    config_paths:
      - /etc/mongod.conf

  - name: nginx
    config_paths:
      - /etc/nginx/nginx.conf
    include_dirs:                # （可選）整個資料夾遞迴打包
      - /etc/nginx/conf.d
    include_globs:               # （可選）支援萬用字元
      - /etc/nginx/sites-enabled/*.conf
      - /opt/myapp/**/config*.yml

📦 壓縮檔結構範例

執行後會在 /mnt/backup 產生：

/mnt/backup/
└── config_backup_2025-10-09 18:00.tar.gz


解壓後的內容為：

config_backup/
├── kafka/
│   ├── server.properties
│   └── controller.properties
├── mongodb/
│   └── mongod.conf
└── nginx/
    ├── nginx.conf
    ├── conf.d/
    └── sites-enabled/

⚙️ 腳本說明

檔案：backup_configs.sh

#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob dotglob globstar

MAIN_CFG="${1:-/etc/config_backup.yaml}"

# 檢查 yq
if ! command -v yq >/dev/null 2>&1; then
  echo "[ERROR] 未找到 yq。請先安裝："
  echo "  - Debian/Ubuntu: sudo apt-get install -y yq"
  echo "  - RHEL/CentOS:   sudo yum install -y yq"
  exit 1
fi

# 讀取全域設定
BACKUP_DIR="$(yq -r '.backup_dir // "/mnt/backup"' "$MAIN_CFG")"
ROOT_DIR_NAME="$(yq -r '.root_dir_name // "config_backup"' "$MAIN_CFG")"

# 準備輸出與暫存
mkdir -p "$BACKUP_DIR"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

STAGE_DIR="$TMP_ROOT/$ROOT_DIR_NAME"
mkdir -p "$STAGE_DIR"

echo "[INFO] Backup start: $(date '+%F %T')"
echo "[INFO] Using config: $MAIN_CFG"
echo "[INFO] Output dir  : $BACKUP_DIR"
echo "[INFO] Root in tar : $ROOT_DIR_NAME"

# 服務數量
SERV_COUNT="$(yq -r '.services | length' "$MAIN_CFG" 2>/dev/null || echo 0)"
if [[ "$SERV_COUNT" -eq 0 ]]; then
  echo "[WARN] 沒有任何 services 設定；結束。"
  exit 0
fi

for ((i=0; i<SERV_COUNT; i++)); do
  SERVICE_NAME="$(yq -r ".services[$i].name" "$MAIN_CFG")"
  [[ "$SERVICE_NAME" == "null" || -z "$SERVICE_NAME" ]] && SERVICE_NAME="service_$i"

  DEST_DIR="$STAGE_DIR/$SERVICE_NAME"
  mkdir -p "$DEST_DIR"
  echo "[INFO] >> 處理服務：$SERVICE_NAME"

  # 拷貝檔案（config_paths）
  while IFS= read -r FILE_PATH; do
    [[ -z "${FILE_PATH:-}" || "$FILE_PATH" == "null" ]] && continue
    if [[ -f "$FILE_PATH" ]]; then
      bn="$(basename "$FILE_PATH")"
      to="$DEST_DIR/$bn"
      if [[ -e "$to" && ! -d "$to" ]]; then
        hash="$(echo -n "$FILE_PATH" | sha1sum | awk '{print $1}' | cut -c1-8)"
        to="$DEST_DIR/${bn}__${hash}"
        echo "[WARN] 檔名衝突，改名為：$(basename "$to")"
      fi
      cp -a "$FILE_PATH" "$to"
      echo "[OK]  file: $FILE_PATH"
    else
      echo "[WARN] file not found: $FILE_PATH"
    fi
  done < <(yq -r ".services[$i].config_paths[]?" "$MAIN_CFG")

  # 拷貝整個資料夾（include_dirs）
  while IFS= read -r DIR_PATH; do
    [[ -z "${DIR_PATH:-}" || "$DIR_PATH" == "null" ]] && continue
    if [[ -d "$DIR_PATH" ]]; then
      cp -a "$DIR_PATH" "$DEST_DIR/"
      echo "[OK]  dir : $DIR_PATH/ (recursive)"
    else
      echo "[WARN] dir not found: $DIR_PATH"
    fi
  done < <(yq -r ".services[$i].include_dirs[]?" "$MAIN_CFG")

  # 萬用字元（include_globs）
  while IFS= read -r PATTERN; do
    [[ -z "${PATTERN:-}" || "$PATTERN" == "null" ]] && continue
    eval "paths=( $PATTERN )"
    if ((${#paths[@]})); then
      for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then
          bn="$(basename "$p")"
          to="$DEST_DIR/$bn"
          if [[ -e "$to" && ! -d "$to" ]]; then
            hash="$(echo -n "$p" | sha1sum | awk '{print $1}' | cut -c1-8)"
            to="$DEST_DIR/${bn}__${hash}"
            echo "[WARN] 檔名衝突，改名為：$(basename "$to")"
          fi
          cp -a "$p" "$to"
          echo "[OK]  glob-file: $p"
        elif [[ -d "$p" ]]; then
          cp -a "$p" "$DEST_DIR/"
          echo "[OK]  glob-dir : $p/ (recursive)"
        fi
      done
    else
      echo "[WARN] glob no match: $PATTERN"
    fi
  done < <(yq -r ".services[$i].include_globs[]?" "$MAIN_CFG")

done

ARCHIVE_NAME="$(date +"config_backup_%F %H:%M").tar.gz"
tar -zcvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_ROOT" "$ROOT_DIR_NAME"
echo "[INFO] 完成：$BACKUP_DIR/$ARCHIVE_NAME"

🚀 使用方式
一、安裝

確保系統有 yq

sudo apt-get install -y yq      # Debian/Ubuntu
sudo yum install -y yq          # RHEL/CentOS


將腳本儲存為：

/usr/local/bin/backup_configs.sh
chmod +x /usr/local/bin/backup_configs.sh

二、執行
# 預設會讀取 /etc/config_backup.yaml
sudo /usr/local/bin/backup_configs.sh

# 或指定設定檔路徑
sudo /usr/local/bin/backup_configs.sh /path/to/config_backup.yaml

三、輸出範例
[INFO] Backup start: 2025-10-09 18:00:05
[INFO] Using config: /etc/config_backup.yaml
[INFO] Output dir  : /mnt/backup
[INFO] Root in tar : config_backup
[INFO] >> 處理服務：kafka
[OK]  file: /var/log/kafka/server.properties
[OK]  file: /var/log/kafka/controller.properties
[INFO] >> 處理服務：mongodb
[OK]  file: /etc/mongod.conf
[INFO] 完成：/mnt/backup/config_backup_2025-10-09 18:00.tar.gz

🧹 可擴充功能（未預設啟用）
功能	說明
--clean-old 7	刪除 7 天前的舊壓縮檔
systemd timer	可設計為每日自動執行
log 檔紀錄	輸出詳細執行紀錄至 /mnt/backup/backup.log
🧠 小提示

若某個檔案不存在，會顯示 [WARN] file not found，但不會中止整體執行。

若檔名重複（例如多個服務都叫 config.yaml），腳本會自動加上雜湊避免覆蓋。

解壓後的結構一定會是：

<root_dir_name>/<service_name>/<files...>

