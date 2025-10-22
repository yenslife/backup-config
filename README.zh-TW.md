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
0 1 * * * 30 1 * * * /usr/local/bin/backup_configs.sh >> /var/log/cleanup.log 2>&1
```
