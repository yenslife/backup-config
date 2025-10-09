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

ARCHIVE_NAME="$(date +"config_backup_%F_%H:%M").tar.gz"
tar -zcvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_ROOT" "$ROOT_DIR_NAME"
echo "[INFO] 完成：$BACKUP_DIR/$ARCHIVE_NAME"

