# 🧩 Config Backup Script - 組態檔備份腳本

這是一個自動化備份服務組態檔的 Shell 腳本。它會讀取一個 YAML 設定檔，根據其中的定義，將散落在各處的檔案和資料夾收集起來，並打包成一個帶有時間戳的 `.tar.gz` 壓縮檔。

此工具非常適合系統管理員，或任何希望將重要設定檔備份流程簡化、集中管理的使用者，例如定期備份到外接硬碟或 NAS。

✨ **核心功能**

*   **集中式設定**：透過單一 `config_backup.yaml` 檔案，即可管理所有服務的備份目標。
*   **彈性的路徑定義**：支援備份以下三種類型：
    *   單一檔案 (`config_paths`)。
    *   整個資料夾（遞迴備份） (`include_dirs`)。
    *   使用萬用字元（Glob）匹配檔案與資料夾 (`include_globs`, 例如 `*.conf`, `/**/`)。
*   **自動化結構**：腳本會自動在壓縮檔內為每個服務建立專屬資料夾，結構清晰。
*   **檔名衝突處理**：當來源不同但檔名相同時，會自動附加雜湊值重新命名，避免檔案被覆蓋。
*   **簡單可靠**：以 `bash` 撰寫，僅依賴 `yq`，具備高可攜性且易於理解。
*   **時間戳命名**：產生的壓縮檔會自動命名為 `config_backup_YYYY-MM-DD_HH:MM.tar.gz`，方便識別。

---

## 🚀 快速開始

### **1. 前置需求**

此腳本需要 `yq` 來解析 YAML 設定檔。`yq` 是一個輕量、可攜的命令列 YAML 處理器。

**安裝 (Linux):**

*   **Debian/Ubuntu:**
    ```bash
    sudo apt-get update && sudo apt-get install -y yq
    ```
*   **RHEL/CentOS/Fedora:**
    ```bash
    sudo yum install -y yq
    ```

### **2. 安裝腳本**

1.  將腳本內容儲存至 `/usr/local/bin/backup_configs.sh`。
2.  賦予腳本執行權限：
    ```bash
    sudo chmod +x /usr/local/bin/backup_configs.sh
    ```

### **3. 建立設定檔**

建立您的 YAML 設定檔，腳本預設會讀取 `/etc/config_backup.yaml`。

```bash
sudo touch /etc/config_backup.yaml
```

接著，編輯這個檔案，填入您的備份設定。詳細格式請參考下方的設定檔說明。

---

## ⚙️ 設定檔 (`config_backup.yaml`)

YAML 設定檔定義了壓縮檔的輸出位置，以及每個服務需要備份的具體路徑。
目前存在 `/etc/backup_config` 底下

### **檔案結構**

```yaml
# --- 全域設定 ---

# [必填] 最終 .tar.gz 壓縮檔的儲存路徑。
backup_dir: /mnt/backup

# [選填] 壓縮檔內最上層資料夾的名稱。
# 若留空，預設為 "config_backup"。
root_dir_name: my_server_configs

# --- 服務定義 ---

services:
  # --- 服務 1：僅包含幾個設定檔的簡單服務 ---
  - name: kafka
    # 要備份的「單一檔案」列表。
    config_paths:
      - /etc/kafka/server.properties
      - /etc/kafka/zookeeper.properties

  # --- 服務 2：包含資料夾與萬用字元路徑的服務 ---
  - name: nginx
    # 你可以混合使用不同的路徑類型。
    config_paths:
      - /etc/nginx/nginx.conf
    # 遞迴備份此資料夾下的所有內容。
    include_dirs:
      - /etc/nginx/conf.d
    # 備份符合 Glob 萬用字元模式的檔案或資料夾。
    # `**` 萬用字元可實現遞迴匹配。
    include_globs:
      - /etc/nginx/sites-enabled/*.conf
      - /opt/myapp/**/config*.yml

  # --- 服務 3：只有一個檔案的服務 ---
  - name: mongodb
    config_paths:
      - /etc/mongod.conf
```

### **設定參數說明**

| 鍵值            | 類型   | 是否必填 | 預設值            | 說明                                                               |
| --------------- | ------ | -------- | ----------------- | ------------------------------------------------------------------ |
| `backup_dir`    | 字串   | 是       | `/mnt/backup`     | 最終壓縮檔的儲存目錄。                                             |
| `root_dir_name` | 字串   | 否       | `config_backup`   | 產生之 `.tar.gz` 檔案內部最上層的資料夾名稱。                      |
| `services`      | 陣列   | 是       |                   | 一個包含所有待備份服務的列表。                                     |
| `name`          | 字串   | 是       |                   | 服務的唯一名稱，將作為壓縮檔內的子資料夾名稱。                     |
| `config_paths`  | 陣列   | 否       |                   | 一個包含多個「單一檔案」絕對路徑的列表。                           |
| `include_dirs`  | 陣列   | 否       |                   | 一個包含多個「資料夾」絕對路徑的列表，將會遞迴複製整個資料夾。     |
| `include_globs` | 陣列   | 否       |                   | 一個包含多個 Glob 模式的列表，用以匹配檔案或資料夾，支援 `*` 與 `**`。 |

---

## 🏃‍♀️ 如何執行

您可以直接執行腳本，或在執行時指定設定檔路徑。

*   **使用預設設定檔 (`/etc/config_backup.yaml`):**
    ```bash
    sudo /usr/local/bin/backup_configs.sh
    ```

*   **指定自訂的設定檔路徑:**
    ```bash
    sudo /usr/local/bin/backup_configs.sh /path/to/my/custom_config.yaml
    ```

### **執行輸出範例**

```[INFO] Backup start: 2025-10-09 18:00:05
[INFO] Using config: /etc/config_backup.yaml
[INFO] Output dir   : /mnt/backup
[INFO] Root in tar  : config_backup
[INFO] >> 處理服務：kafka
[OK]   file: /etc/kafka/server.properties
[OK]   file: /etc/kafka/zookeeper.properties
[INFO] >> 處理服務：nginx
[OK]   file: /etc/nginx/nginx.conf
[OK]   dir : /etc/nginx/conf.d/ (recursive)
[OK]   glob-file: /etc/nginx/sites-enabled/default.conf
[INFO] >> 處理服務：mongodb
[OK]   file: /etc/mongod.conf
config_backup/
config_backup/kafka/
config_backup/kafka/server.properties
...
[INFO] 完成：/mnt/backup/config_backup_2025-10-09_18:00.tar.gz
```

---


## 🗂️ 壓縮檔結構

執行腳本後，一個新的壓縮檔會被建立在您指定的 `backup_dir` 中。解壓縮後，其內部結構如下：

```
<root_dir_name>/
├── <service_one_name>/
│   ├── config_file_1.conf
│   └── some_other_file.properties
│
├── <service_two_name>/
│   ├── another_config.yml
│   └── included_directory/
│       └── ...
└── ...
```

**範例:**

根據前述的 YAML 範例，解壓縮 `config_backup_2025-10-09_18:00.tar.gz` 後的內容會是：

```
my_server_configs/
├── kafka/
│   ├── server.properties
│   └── zookeeper.properties
├── mongodb/
│   └── mongod.conf
└── nginx/
    ├── nginx.conf
    ├── conf.d/
    │   └── default.conf
    └── sites-enabled/
        └── default.conf
```

---

## 🧠 提示與腳本行為

*   **找不到檔案**：若 `config_paths` 或 `include_dirs` 中定義的檔案或資料夾不存在，腳本會印出 `[WARN]` 警告訊息，但會繼續執行，不會中斷。
*   **Glob 無匹配**：若 `include_globs` 中的模式沒有匹配到任何檔案，腳本同樣會顯示警告並繼續執行。
*   **檔名衝突**：如果兩個來自不同路徑的檔案有相同的檔名（例如 `/app1/config.yml` 和 `/app2/config.yml`），腳本會自動將後者的檔名附加其來源路徑的 SHA1 雜湊值前 8 碼，以避免檔案被覆蓋。
    *   範例：`config.yml` 會變成 `config.yml__a1b2c3d4`。


## Crontab

```
sudo crontab -e
```

```
0 1 * * * /usr/local/bin/backup_configs.sh >> /var/log/backup_configs.log 2>&1
```

## 方便的腳本，一鍵貼上
```
cat >/tmp/setup_backup_configs.sh <<'SETUP'
#!/usr/bin/env bash
set -euo pipefail

# 這個腳本會：
# 1) 寫入 /usr/local/bin/backup_configs.sh 並 chmod +x
# 2) 寫入 /etc/config_backup.yaml
# 3) 建立 /etc/backup_config 目錄（作為備份輸出路徑）
# 4) 建立 /var/log/backup_configs.log
# 5) 設定 root 的 crontab：每天 01:00 執行

need_cmd() { command -v "$1" >/dev/null 2>&1; }
say() { printf "[%s] %s\n" "$(date '+%F %T')" "$*"; }

# --- 1) 寫入 /usr/local/bin/backup_configs.sh ---
say "寫入 /usr/local/bin/backup_configs.sh ..."
sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/backup_configs.sh >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob dotglob globstar

MAIN_CFG="${1:-/etc/config_backup.yaml}"

# ---------- 小工具 ----------
trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' ; }

# 去掉 # 後面的註解（若在引號內則保留）；純 Bash 實作
rstrip_comment() {
  local line out inq qt ch i
  while IFS= read -r line; do
    out=""
    inq=0
    qt=""
    for ((i=0; i<${#line}; i++)); do
      ch="${line:i:1}"
      if (( inq == 0 )); then
        if [[ "$ch" == '"' || "$ch" == "'" ]]; then
          inq=1
          qt="$ch"
          out+="$ch"
          continue
        fi
        if [[ "$ch" == "#" ]]; then
          break
        fi
        out+="$ch"
      else
        out+="$ch"
        if [[ "$ch" == "$qt" ]]; then
          inq=0
          qt=""
        fi
      fi
    done
    printf '%s\n' "$out"
  done
}

strip_quotes(){ sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

# ---------- 檢查 yq ----------
have_yq=0
if command -v yq >/dev/null 2>&1; then
  have_yq=1
fi

# ---------- 讀取全域設定（先試 yq；不行就用內建解析） ----------
if [[ "$have_yq" -eq 1 ]]; then
  BACKUP_DIR="$(yq -r '.backup_dir // "/mnt/backup"' "$MAIN_CFG")"
  ROOT_DIR_NAME="$(yq -r '.root_dir_name // "config_backup"' "$MAIN_CFG")"
else
  BACKUP_DIR="/mnt/backup"
  ROOT_DIR_NAME="config_backup"
  while IFS= read -r raw; do
    line="$(printf '%s\n' "$raw" | rstrip_comment | trim)"
    [[ -z "$line" ]] && continue
    case "$line" in
      backup_dir:*)
        v="${line#backup_dir:}"
        BACKUP_DIR="$(printf '%s' "$v" | trim | strip_quotes)"
        [[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="/mnt/backup"
        ;;
      root_dir_name:*)
        v="${line#root_dir_name:}"
        ROOT_DIR_NAME="$(printf '%s' "$v" | trim | strip_quotes)"
        [[ -z "$ROOT_DIR_NAME" ]] && ROOT_DIR_NAME="config_backup"
        ;;
    esac
  done < "$MAIN_CFG"
fi

# ---------- 準備輸出與暫存 ----------
mkdir -p "$BACKUP_DIR"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

STAGE_DIR="$TMP_ROOT/$ROOT_DIR_NAME"
mkdir -p "$STAGE_DIR"

echo "[INFO] Backup start: $(date '+%F %T')"
echo "[INFO] Using config: $MAIN_CFG"
echo "[INFO] Output dir  : $BACKUP_DIR"
echo "[INFO] Root in tar : $ROOT_DIR_NAME"

# ---------- 若有 yq，走原本流程 ----------
if [[ "$have_yq" -eq 1 ]]; then
  SERV_COUNT="$(yq -r '.services | length' "$MAIN_CFG" 2>/dev/null || echo 0)"
  if [[ "$SERV_COUNT" -eq 0 ]]; then
    echo "[WARN] 沒有任何 services 設定；結束。"
    ARCHIVE_NAME="$(date +"config_backup_%F_%H:%M").tar.gz"
    tar -zcvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_ROOT" "$ROOT_DIR_NAME"
    echo "[INFO] 完成：$BACKUP_DIR/$ARCHIVE_NAME"
    exit 0
  fi

  for ((i=0; i<SERV_COUNT; i++)); do
    SERVICE_NAME="$(yq -r ".services[$i].name" "$MAIN_CFG")"
    [[ "$SERVICE_NAME" == "null" || -z "$SERVICE_NAME" ]] && SERVICE_NAME="service_$i"

    DEST_DIR="$STAGE_DIR/$SERVICE_NAME"
    mkdir -p "$DEST_DIR"
    echo "[INFO] >> 處理服務：$SERVICE_NAME"

    # files
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

    # dirs
    while IFS= read -r DIR_PATH; do
      [[ -z "${DIR_PATH:-}" || "$DIR_PATH" == "null" ]] && continue
      if [[ -d "$DIR_PATH" ]]; then
        cp -a "$DIR_PATH" "$DEST_DIR/"
        echo "[OK]  dir : $DIR_PATH/ (recursive)"
      else
        echo "[WARN] dir not found: $DIR_PATH"
      fi
    done < <(yq -r ".services[$i].include_dirs[]?" "$MAIN_CFG")

    # globs
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

else
  # ---------- 無 yq：簡易 YAML 解析器 ----------
  echo "[INFO] yq 不可用，使用內建 YAML 解析器（受限簡單語法）"

  in_services=0
  cur_name=""
  declare -a cur_files=()
  declare -a cur_dirs=()
  declare -a cur_globs=()

  # 使用 nameref（declare -n）安全地接陣列參數
  flush_service() {
    local name="$1"; shift
    declare -n files_ref="$1"; shift
    declare -n dirs_ref="$1"; shift
    declare -n globs_ref="$1"

    [[ -z "$name" ]] && return 0
    local DEST_DIR="$STAGE_DIR/$name"
    mkdir -p "$DEST_DIR"
    echo "[INFO] >> 處理服務：$name"

    # files
    for FILE_PATH in "${files_ref[@]:-}"; do
      [[ -z "${FILE_PATH:-}" ]] && continue
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
    done

    # dirs
    for DIR_PATH in "${dirs_ref[@]:-}"; do
      [[ -z "${DIR_PATH:-}" ]] && continue
      if [[ -d "$DIR_PATH" ]]; then
        cp -a "$DIR_PATH" "$DEST_DIR/"
        echo "[OK]  dir : $DIR_PATH/ (recursive)"
      else
        echo "[WARN] dir not found: $DIR_PATH"
      fi
    done

    # globs
    for PATTERN in "${globs_ref[@]:-}"; do
      [[ -z "${PATTERN:-}" ]] && continue
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
    done
  }

  mode=""   # "", "files", "dirs", "globs"
  while IFS= read -r raw; do
    # 去註解（保留引號內 #），保留前導空白；去掉 CR
    line="$(printf '%s\n' "$raw" | rstrip_comment)"
    line="${line%$'\r'}"
    stripped="$(printf '%s' "$line" | trim)"

    [[ -z "$stripped" ]] && continue

    # 進入 services
    if [[ "$stripped" == "services:" ]]; then
      in_services=1
      cur_name=""
      cur_files=(); cur_dirs=(); cur_globs=()
      mode=""
      continue
    fi

    if [[ "$in_services" -eq 1 ]]; then
      # 新 service
      if [[ "$stripped" =~ ^-?[[:space:]]*-?[[:space:]]*name:[[:space:]] ]]; then
        # flush 舊的
        if [[ -n "$cur_name" ]]; then
          flush_service "$cur_name" cur_files cur_dirs cur_globs
          cur_files=(); cur_dirs=(); cur_globs=()
        fi
        v="${stripped#*- name:}"
        v="$(printf '%s' "$v" | trim | strip_quotes)"
        cur_name="$v"
        mode=""
        continue
      fi

      # 切換 section
      case "$stripped" in
        config_paths:)
          mode="files"; continue ;;
        include_dirs:)
          mode="dirs"; continue ;;
        include_globs:)
          mode="globs"; continue ;;
      esac

      # 清單項目
      if [[ "$stripped" =~ ^-[[:space:]] ]]; then
        item="${stripped#- }"
        item="$(printf '%s' "$item" | trim | strip_quotes)"
        case "$mode" in
          files) cur_files+=("$item") ;;
          dirs)  cur_dirs+=("$item") ;;
          globs) cur_globs+=("$item") ;;
          *)     cur_files+=("$item") ;;
        esac
        continue
      fi

      # 遇到其他 top-level -> 結束 services
      if [[ ! "$line" =~ ^[[:space:]] ]]; then
        if [[ -n "$cur_name" ]]; then
          flush_service "$cur_name" cur_files cur_dirs cur_globs
          cur_name=""
        fi
        in_services=0
      fi
    fi
  done < "$MAIN_CFG"

  # EOF flush
  if [[ -n "${cur_name:-}" ]]; then
    flush_service "$cur_name" cur_files cur_dirs cur_globs
  fi
fi

ARCHIVE_NAME="$(date +"config_backup_%F_%H:%M").tar.gz"
tar -zcvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_ROOT" "$ROOT_DIR_NAME"
echo "[INFO] 完成：$BACKUP_DIR/$ARCHIVE_NAME"
SCRIPT

sudo chmod +x /usr/local/bin/backup_configs.sh

# --- 2) 寫入 /etc/config_backup.yaml ---
say "寫入 /etc/config_backup.yaml ..."
sudo mkdir -p /etc/backup_config
sudo tee /etc/config_backup.yaml >/dev/null <<'YAML'
backup_dir: /etc/backup_config
root_dir_name: my_server_configs

services:
  - name: ipfixcol2
    config_paths:
      - /etc/ipfixcol2/ipfixcol2.xml
  - name: libfds
    config_paths:
      - /etc/libfds/user/elements/enterprise-procera.xml
      - /etc/libfds/system/elements/iana.xml
      - /etc/libfds/user/element_mapping.txt
  - name: sysctl.d
    config_paths:
      - /etc/sysctl.d/99-ipfixcol2.conf
  - name: kafka
    config_paths:
      - /opt/kafka_2.12-3.9.1/config/connect-console-sink.properties
      - /opt/kafka_2.12-3.9.1/config/connect-console-source.properties
      - /opt/kafka_2.12-3.9.1/config/connect-distributed.properties
      - /opt/kafka_2.12-3.9.1/config/connect-file-sink.properties
      - /opt/kafka_2.12-3.9.1/config/connect-file-source.properties
      - /opt/kafka_2.12-3.9.1/config/connect-log4j.properties
      - /opt/kafka_2.12-3.9.1/config/connect-mirror-maker.properties
      - /opt/kafka_2.12-3.9.1/config/connect-standalone.properties
      - /opt/kafka_2.12-3.9.1/config/consumer.properties
      - /opt/kafka_2.12-3.9.1/config/log4j.properties
      - /opt/kafka_2.12-3.9.1/config/producer.properties
      - /opt/kafka_2.12-3.9.1/config/server.properties
      - /opt/kafka_2.12-3.9.1/config/tools-log4j.properties
      - /opt/kafka_2.12-3.9.1/config/trogdor.conf
      - /opt/kafka_2.12-3.9.1/config/zookeeper.properties
  - name: ntp
    config_paths:
      - /etc/chrony.conf
  - name: vip
    config_paths:
      - /etc/keepalived/keepalived.conf
  - name: kafka-kraft
    config_paths:
      - /opt/kafka_2.12-3.9.1/config/kraft/broker.properties
      - /opt/kafka_2.12-3.9.1/config/kraft/controller.properties
      - /opt/kafka_2.12-3.9.1/config/kraft/reconfig-server.properties
      - /opt/kafka_2.12-3.9.1/config/kraft/server.properties
  - name: mongo
    config_paths:
      - /etc/mongod.conf
      - /etc/mongod-arbiter01.conf
      - /etc/mongod-arbiter02.conf
      - /etc/mongod-arbiter03.conf
      - /etc/mongod-arbiter04.conf
      - /etc/mongod-arbiter05.conf
      - /etc/mongod-arbiter06.conf
      - /etc/mongod-arbiter07.conf
      - /etc/mongod-arbiter08.conf
      - /etc/mongos.conf
  - name: vip
    config_paths:
      - /etc/keepalived/keepalived.conf
YAML

# --- 3) 準備日誌檔 ---
say "建立 /var/log/backup_configs.log ..."
sudo touch /var/log/backup_configs.log
sudo chmod 0644 /var/log/backup_configs.log

# --- 4) 設定 root crontab ---
say "設定 root crontab 每日 01:00 執行 ..."
CRON_LINE='0 1 * * * /usr/local/bin/backup_configs.sh >> /var/log/backup_configs.log 2>&1'
# 移除舊有相同腳本的行，再加入新的
sudo sh -c "(crontab -l 2>/dev/null | grep -v -F '/usr/local/bin/backup_configs.sh' || true; echo \"$CRON_LINE\") | crontab -"

say "全部完成！可以手動試跑： sudo /usr/local/bin/backup_configs.sh"
SETUP

bash /tmp/setup_backup_configs.sh
```
