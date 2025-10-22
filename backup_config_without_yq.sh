#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob dotglob globstar

MAIN_CFG="${1:-/etc/config_backup.yaml}"

# ---------- 小工具 ----------
trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' ; }
rstrip_comment() {
  # 去掉 # 後面的註解（忽略在引號內的 #）
  # 簡化版：僅處理常見 case，用不到複雜 YAML 特性
  awk '
  {
    line=$0
    out=""; inq=0; qt=""
    for(i=1;i<=length(line);i++){
      c=substr(line,i,1)
      if(inq==0 && (c=="\"" || c=="'\'')){ inq=1; qt=c; out=out c; continue }
      if(inq==1 && c==qt){ inq=0; qt=""; out=out c; continue }
      if(inq==0 && c=="#"){ break }
      out=out c
    }
    print out
  }'
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
  # 用內建解析找出 backup_dir / root_dir_name
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

  flush_service() {
    local name="$1"; shift
    local -a files=("${!1}"); shift
    local -a dirs=("${!1}"); shift
    local -a globs=("${!1}")

    [[ -z "$name" ]] && return 0
    local DEST_DIR="$STAGE_DIR/$name"
    mkdir -p "$DEST_DIR"
    echo "[INFO] >> 處理服務：$name"

    # files
    for FILE_PATH in "${files[@]}"; do
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
    for DIR_PATH in "${dirs[@]}"; do
      [[ -z "${DIR_PATH:-}" ]] && continue
      if [[ -d "$DIR_PATH" ]]; then
        cp -a "$DIR_PATH" "$DEST_DIR/"
        echo "[OK]  dir : $DIR_PATH/ (recursive)"
      else
        echo "[WARN] dir not found: $DIR_PATH"
      fi
    done

    # globs
    for PATTERN in "${globs[@]}"; do
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
    # 去註解 + 去前後空白
    line="$(printf '%s\n' "$raw" | rstrip_comment | sed -e 's/[[:space:]]\+$//' )"
    # 保留前導空白，用於判斷縮排
    stripped="$(printf '%s' "$line" | trim)"

    # 空行
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
          flush_service "$cur_name" cur_files[@] cur_dirs[@] cur_globs[@]
          cur_files=(); cur_dirs=(); cur_globs=()
        fi
        v="${stripped#*- name:}"
        v="$(printf '%s' "$v" | trim | strip_quotes)"
        cur_name="$v"
        mode=""
        continue
      fi

      # 切換 section（config_paths/include_dirs/include_globs）
      case "$stripped" in
        config_paths:)
          mode="files"; continue ;;
        include_dirs:)
          mode="dirs"; continue ;;
        include_globs:)
          mode="globs"; continue ;;
      esac

      # 清單項目（- /path...）
      if [[ "$stripped" =~ ^-[[:space:]] ]]; then
        item="${stripped#- }"
        item="$(printf '%s' "$item" | trim | strip_quotes)"
        case "$mode" in
          files) cur_files+=("$item") ;;
          dirs)  cur_dirs+=("$item") ;;
          globs) cur_globs+=("$item") ;;
          *)     # 若沒有指定 mode，視為 config_paths（跟我們產的 YAML 相容）
                 cur_files+=("$item") ;;
        esac
        continue
      fi

      # 遇到其他 top-level 就結束 services（防呆）
      if [[ ! "$line" =~ ^[[:space:]] ]]; then
        # flush 最後一個
        if [[ -n "$cur_name" ]]; then
          flush_service "$cur_name" cur_files[@] cur_dirs[@] cur_globs[@]
          cur_name=""
        fi
        in_services=0
      fi
    fi
  done < "$MAIN_CFG"

  # flush EOF 的最後一個
  if [[ -n "${cur_name:-}" ]]; then
    flush_service "$cur_name" cur_files[@] cur_dirs[@] cur_globs[@]
  fi
fi

ARCHIVE_NAME="$(date +"config_backup_%F_%H:%M").tar.gz"
tar -zcvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_ROOT" "$ROOT_DIR_NAME"
echo "[INFO] 完成：$BACKUP_DIR/$ARCHIVE_NAME"
