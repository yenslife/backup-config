# 🧩 Config Backup Script

[中文說明 (台灣正體)](README.zh-TW.md)

This is a Shell Script designed to automate the backup of configuration files and directories for various services. It reads a single YAML configuration file to gather, organize, and compress specified paths into a timestamped `.tar.gz` archive.

This tool is ideal for system administrators or anyone looking to simplify and centralize the process of backing up critical configuration files to a designated location, such as an external drive or a NAS.

✨ **Key Features**

*   **Centralized Configuration**: Manage all backup targets from a single `config_backup.yaml` file.
*   **Flexible Path Definitions**: Supports backing up:
    *   Individual files (`config_paths`).
    *   Entire directories recursively (`include_dirs`).
    *   Files and directories using wildcard patterns (`include_globs`, e.g., `*.conf`, `/**/`).
*   **Automated Organization**: Creates a clean, structured archive with a dedicated folder for each service.
*   **Conflict Resolution**: Automatically renames files with conflicting names by appending a unique hash to prevent overwrites.
*   **Robust and Simple**: Written in `bash` with minimal dependencies (`yq`), making it highly portable and easy to understand.
*   **Timestamped Archives**: Generates uniquely named backup files like `config_backup_YYYY-MM-DD_HH:MM.tar.gz`.

---

## 🚀 Getting Started

### **1. Prerequisites**

The script requires `yq` to parse the YAML configuration file. `yq` is a lightweight and portable command-line YAML processor.

**Installation (Linux):**

*   **Debian/Ubuntu:**
    ```bash
    sudo apt-get update && sudo apt-get install -y yq
    ```
*   **RHEL/CentOS/Fedora:**
    ```bash
    sudo yum install -y yq
    ```

### **2. Script Installation**

1.  Save the script content as `/usr/local/bin/backup_configs.sh`.
2.  Make the script executable:
    ```bash
    sudo chmod +x /usr/local/bin/backup_configs.sh
    ```

### **3. Create the Configuration File**

Create your YAML configuration file. The default location is `/etc/config_backup.yaml`.

```bash
sudo touch /etc/config_backup.yaml
```

Now, populate this file with your desired backup settings. See the configuration format section below for details and examples.

---

## ⚙️ Configuration (`config_backup.yaml`)

The YAML file defines the backup destination and the specific files/directories for each service.

### **File Structure**

```yaml
# --- Global Settings ---

# [Required] The absolute path where the final .tar.gz archive will be saved.
backup_dir: /mnt/backup

# [Optional] The name of the root folder inside the .tar.gz archive.
# Defaults to "config_backup" if omitted.
root_dir_name: my_server_configs

# --- Service Definitions ---

services:
  # --- Service 1: A simple service with a few config files ---
  - name: kafka
    # A list of individual files to back up.
    config_paths:
      - /etc/kafka/server.properties
      - /etc/kafka/zookeeper.properties

  # --- Service 2: A service with a directory and wildcard patterns ---
  - name: nginx
    # You can mix and match different path types.
    config_paths:
      - /etc/nginx/nginx.conf
    # Recursively backs up the entire contents of this directory.
    include_dirs:
      - /etc/nginx/conf.d
    # Backs up files and directories matching glob patterns.
    # The `**` pattern enables recursive matching.
    include_globs:
      - /etc/nginx/sites-enabled/*.conf
      - /opt/myapp/**/config*.yml

  # --- Service 3: A service with only one file ---
  - name: mongodb
    config_paths:
      - /etc/mongod.conf

```

### **Configuration Parameters**

| Key             | Type   | Required | Default           | Description                                                                                             |
| --------------- | ------ | -------- | ----------------- | ------------------------------------------------------------------------------------------------------- |
| `backup_dir`    | string | Yes      | `/mnt/backup`     | The directory where the final compressed archive will be stored.                                        |
| `root_dir_name` | string | No       | `config_backup`   | The name of the top-level folder inside the generated `.tar.gz` file.                                     |
| `services`      | array  | Yes      |                   | A list of service objects to be backed up.                                                              |
| `name`          | string | Yes      |                   | A unique name for the service, used as the subdirectory name in the archive.                            |
| `config_paths`  | array  | No       |                   | A list of absolute paths to individual files.                                                           |
| `include_dirs`  | array  | No       |                   | A list of absolute paths to directories. The entire directory will be copied recursively.                 |
| `include_globs` | array  | No       |                   | A list of patterns (globs) to match files and directories. Supports `*` and `**` for recursive matching. |

---

## 🏃‍♀️ How to Run

You can execute the script with or without specifying a path to the configuration file.

*   **Using the default config file (`/etc/config_backup.yaml`):**
    ```bash
    sudo /usr/local/bin/backup_configs.sh
    ```

*   **Specifying a custom config file path:**
    ```bash
    sudo /usr/local/bin/backup_configs.sh /path/to/my/custom_config.yaml
    ```

### **Example Output**

```
[INFO] Backup start: 2025-10-09 18:00:05
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

## 🗂️ Archive Structure

After running the script, a new archive will be created in your specified `backup_dir`. If you extract this archive, the contents will be organized as follows:

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

**Example:**

Based on the sample YAML above, the extracted archive `config_backup_2025-10-09_18:00.tar.gz` would look like this:

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

## 🧠 Tips and Behavior

*   **File Not Found**: If a specified file or directory in `config_paths` or `include_dirs` does not exist, a `[WARN]` message is printed, but the script will continue without interruption.
*   **No Glob Match**: If a pattern in `include_globs` matches no files, a `[WARN]` message is shown, and the script continues.
*   **Filename Conflicts**: If two different source files have the same base name (e.g., `/app1/config.yml` and `/app2/config.yml`), the script will automatically rename the second file by appending the first 8 characters of its source path's SHA1 hash.
    *   Example: `config.yml` becomes `config.yml__a1b2c3d4`.

---

## Crontab

```
sudo crontab -e
```

```
0 1 * * * 30 1 * * * /usr/local/bin/backup_configs.sh >> /var/log/cleanup.log 2>&1
```
