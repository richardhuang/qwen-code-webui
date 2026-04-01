# Offline Package Installation Method

This directory contains scripts for building and deploying offline installation packages for Qwen Code Web UI.

## Overview

The offline package method is ideal for:
- Deploying to servers without internet access
- Installing on systems where npm/Deno are not available
- Production environments requiring pre-built binaries
- Air-gapped or restricted network environments

## Scripts

| Script | Purpose |
|--------|---------|
| `package.sh` | Build offline installation packages |
| `install.sh` | Install the package on target system |
| `uninstall.sh` | Remove installed package |

---

## Building Packages

### Prerequisites

- Deno installed on the build machine
- Node.js and npm for frontend build
- Make tool

### Usage

```bash
# Build Linux x64 only (default)
./package.sh

# Build all platforms
./package.sh --all

# Build specific platforms
./package.sh --platform linux-arm64
./package.sh --platform linux-x64,macos-arm64

# Build and bump version
./package.sh --bump patch    # 0.2.4 -> 0.2.5
./package.sh --bump minor    # 0.2.4 -> 0.3.0
./package.sh --bump major    # 0.2.4 -> 1.0.0
```

### Output

Packages are created in `packages/` directory:

```
packages/
├── qwen-code-webui-v0.2.4-20260401-Linux-x64.tar.gz
├── qwen-code-webui-v0.2.4-20260401-Linux-arm64.tar.gz
├── qwen-code-webui-v0.2.4-20260401-macOS-x64.tar.gz
└── qwen-code-webui-v0.2.4-20260401-macOS-arm64.tar.gz
```

Each package contains:
- Platform-specific binary
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation script
- `README.txt` - Quick installation guide

---

## Installation

### Prerequisites on Target System

- **Linux**: systemd service manager
- **macOS**: launchd service manager
- Qwen CLI installed and authenticated (`qwen` command available)

### Basic Installation

```bash
# 1. Extract the package
tar -xzf qwen-code-webui-v0.2.4-20260401-Linux-x64.tar.gz

# 2. Enter the directory
cd qwen-code-webui-v0.2.4-20260401-Linux-x64

# 3. Run installer (interactive mode)
sudo ./install.sh
```

### Non-Interactive Installation

```bash
# Install with default settings
sudo ./install.sh -y

# Specify port
sudo ./install.sh -p 8080 -y

# Specify service user (required when running as root without SUDO_USER)
sudo ./install.sh -u myuser -y

# Mount project directories (colon-separated)
sudo ./install.sh -u myuser -d /home/myuser/workspace:/home/myuser/projects -y

# Configure firewall
sudo ./install.sh -p 8080 --firewall -y
```

### Options

| Option | Description |
|--------|-------------|
| `-p, --port <port>` | Port to listen on (default: 3000) |
| `-y, --yes` | Non-interactive mode |
| `--firewall` | Configure firewall to allow the port |
| `-d, --dirs <dirs>` | Colon-separated project directories |
| `-u, --user <user>` | User to run the service as |
| `-h, --help` | Show help message |

### What Gets Installed

1. **Binary**: `/usr/local/bin/qwen-code-webui`
2. **Service**:
   - Linux: `/etc/systemd/system/qwen-code-webui.service`
   - macOS: `~/Library/LaunchAgents/com.qwen-code-webui.plist`
3. **Project sessions**: `~/.qwen/projects/` (if directories specified)

### Post-Installation

After installation, the service starts automatically:

```bash
# Check service status (Linux)
systemctl status qwen-code-webui

# Check service status (macOS)
launchctl list | grep qwen-code-webui

# View logs (Linux)
journalctl -u qwen-code-webui -f

# View logs (macOS)
tail -f /tmp/qwen-code-webui.log
```

Access the Web UI at: `http://localhost:3000` (or your configured port)

---

## Upgrade

To upgrade to a newer version:

```bash
# 1. Download the new package

# 2. Uninstall current version (keeps config)
sudo ./uninstall.sh

# 3. Extract and install new version
tar -xzf qwen-code-webui-v0.2.5-*.tar.gz
cd qwen-code-webui-v0.2.5-*
sudo ./install.sh -y
```

**Note**: Basic uninstall (`./uninstall.sh`) preserves configuration. Use `--all` to remove everything.

---

## Uninstallation

### Basic Uninstall

Removes binary and service, keeps configuration:

```bash
sudo ./uninstall.sh
```

### Full Cleanup

Removes everything including configuration and firewall rules:

```bash
sudo ./uninstall.sh --all
```

### Remove Firewall Rules Only

```bash
sudo ./uninstall.sh --firewall --port 3000
```

### Options

| Option | Description |
|--------|-------------|
| `--all` | Remove everything (config, firewall rules) |
| `--firewall` | Remove firewall rules |
| `--port <port>` | Port to remove firewall rule for |
| `-h, --help` | Show help message |

---

## Service Management

### Linux (systemd)

```bash
# Start service
sudo systemctl start qwen-code-webui

# Stop service
sudo systemctl stop qwen-code-webui

# Restart service
sudo systemctl restart qwen-code-webui

# Enable auto-start on boot
sudo systemctl enable qwen-code-webui

# Disable auto-start
sudo systemctl disable qwen-code-webui

# View logs
journalctl -u qwen-code-webui -f
```

### macOS (launchd)

```bash
# Start service
launchctl load ~/Library/LaunchAgents/com.qwen-code-webui.plist

# Stop service
launchctl unload ~/Library/LaunchAgents/com.qwen-code-webui.plist

# View logs
tail -f /tmp/qwen-code-webui.log
tail -f /tmp/qwen-code-webui.error.log
```

---

## Environment Variables

The service uses these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Web UI port | 3000 |
| `HOST` | Bind address | 0.0.0.0 |
| `QWEN_CONFIG_DIR` | Qwen config directory | ~/.qwen |
| `PROJECT_DIRS` | Comma-separated project directories | (none) |

---

## Troubleshooting

### Service fails to start

```bash
# Check logs
journalctl -u qwen-code-webui -n 50  # Linux
cat /tmp/qwen-code-webui.error.log   # macOS

# Verify Qwen CLI is available
qwen --version

# Check binary exists
ls -la /usr/local/bin/qwen-code-webui
```

### Port already in use

```bash
# Find what's using the port
lsof -i :3000

# Use a different port during install
sudo ./install.sh -p 8080 -y
```

### Permission denied

```bash
# Ensure running with appropriate permissions
sudo ./install.sh

# On Linux, must run as root
# On macOS, may need sudo for /usr/local/bin
```

### Project directories not appearing

```bash
# Check project sessions directory
ls -la ~/.qwen/projects/

# Verify directories were specified during install
sudo ./install.sh -d /path/to/projects -y
```

---

## Comparison with Other Installation Methods

| Method | Pros | Cons |
|--------|------|------|
| **npm** | Easy update, standard tooling | Requires npm, internet |
| **Docker** | Isolated, portable | Requires Docker, larger footprint |
| **Offline Package** | No dependencies, air-gapped | Manual updates, platform-specific |

Choose the offline package method when:
- Target system has no internet access
- npm/Deno are not installed
- You need a self-contained deployment
- Production environments with strict requirements