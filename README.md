A PowerShell script for synchronizing a local data folder with a remote .data folder associated with a Git repository.

## 🧠 Intended Use
This script is specifically designed for environments where:

- A Git bare repository is created using git init --bare on a shared drive.
- The data folder is excluded from Git tracking (e.g., via .gitignore) but still needs to be synchronized between local and remote environments.
⚠️ If you're unfamiliar with Git bare repositories or shared drive setups, this script may not be suitable for your workflow.

## 🚀 Features
🔄 Sync local ↔ remote data folders
🧠 Smart sync using file hash comparison
🗃️ Optional cleaning of local or remote folders
📁 Configurable via syncconfig.json
📝 Logging to console and sync.log
🧪 Dry run mode for safe testing
⚠️ Error handling with retry logic
📊 Sync summary report
🚫 Exclusion patterns support
📈 Progress bar during sync
❓ Help and usage instructions

## 📦 Installation
Place folder-sync.ps1 in a folder included in your system PATH so it can be run globally from any Git-tracked directory.

## ⚙️ Configuration
Create a syncconfig.json file in your project root to define default behavior:

```json
{
  "Direction": "push",
  "CleanRemote": true,
  "CleanLocal": false,
  "FolderName": "data",
  "EnableLogFile": true,
  "DryRun": false,
  "Log": true,
  "Exclusions": ["*.tmp", "*.log", "cache", "__pycache__"],
  "MaxRetries": 3
}

```

## 📌 Parameters

| Parameter         | Type     | Required | Description                                                                 |
|------------------|----------|----------|-----------------------------------------------------------------------------|
| `-Direction`      | string   | ✅ Yes   | `push` to sync local → remote, `pull` for remote → local.                  |
| `-CleanRemote`    | bool     | No       | If `true`, clears the remote data folder before syncing.                   |
| `-CleanLocal`     | bool     | No       | If `true`, clears the local data folder before syncing.                    |
| `-FolderName`     | string   | No       | Defaults to `data`. The folder to sync.                                    |
| `-Log`            | switch   | No       | Enables verbose logging to the console.                                    |
| `-EnableLogFile`  | switch   | No       | Writes logs to `sync.log` in the current directory.                        |
| `-DryRun`         | switch   | No       | Simulates actions without making changes.                                  |
| `-Help`           | switch   | No       | Displays usage instructions and exits.                                     |

## 🛠️ Usage

```pwsh
folder-sync.ps1 -Direction push -CleanRemote $true -CleanLocal $false -Log -EnableLogFile
```

## 📄 License
This project is open-source and available under the MIT License.
