# 🌐 Qwen Code Web UI

[![npm Version](https://img.shields.io/npm/v/qwen-code-webui)](https://www.npmjs.com/package/qwen-code-webui)
[![License](https://img.shields.io/github/license/ivycomputing/qwen-code-webui)](https://github.com/ivycomputing/qwen-code-webui/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/ivycomputing/qwen-code-webui)](https://github.com/ivycomputing/qwen-code-webui/releases)

> **A modern web interface for Qwen Code CLI** - Transform your command-line coding experience into an intuitive web-based chat interface

## 📱 Screenshots

<div align="center">

| Desktop Interface | Mobile Experience |
| ----------------- | ----------------- |
| Chat-based coding interface with instant responses and ready input field | Mobile-optimized chat experience with touch-friendly design |

</div>

---

## 📑 Table of Contents

- [✨ Why Qwen Code Web UI?](#-why-qwen-code-web-ui)
- [🚀 Quick Start](#-quick-start)
- [⚙️ CLI Options](#️-cli-options)
- [🚨 Troubleshooting](#-troubleshooting)
- [🔧 Development](#-development)
- [🔒 Security Considerations](#-security-considerations)
- [❓ FAQ](#-faq)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## ✨ Why Qwen Code Web UI?

**Transform the way you interact with Qwen Code**

Instead of being limited to command-line interactions, Qwen Code Web UI brings you:

| CLI Experience                | Web UI Experience            |
| ----------------------------- | ---------------------------- |
| ⌨️ Terminal only              | 🌐 Any device with a browser |
| 📱 Desktop bound              | 📱 Mobile-friendly interface |
| 📝 Plain text output          | 🎨 Rich formatted responses  |
| 🗂️ Manual directory switching | 📁 Visual project selection  |

### 🎯 Key Features

- **📋 Permission Mode Switching** - Toggle between normal, plan, auto-edit, and yolo modes
- **🔄 Real-time streaming responses** - Live Qwen Code output in chat interface
- **📁 Project directory selection** - Visual project picker for context-aware sessions
- **💬 Conversation history** - Browse and restore previous chat sessions
- **🛠️ Tool permission management** - Granular control over Qwen's tool access
- **🎨 Dark/light theme support** - Automatic system preference detection
- **📱 Mobile-responsive design** - Touch-optimized interface for any device

---

## 🚀 Quick Start

Get up and running in under 2 minutes:

### Option 1: npm Package (Recommended)

```bash
# Install globally via npm
npm install -g qwen-code-webui

# Start the server
qwen-code-webui

# Open browser to http://localhost:3000
```

### Option 2: Docker

```bash
# Clone repository
git clone https://github.com/ivycomputing/qwen-code-webui.git
cd qwen-code-webui

# Build and run with Docker Compose
docker compose up -d

# Or build and run with Docker directly
docker build -t qwen-code-webui .
docker run -d -p 3000:3000 -v ~/.qwen:/home/nodejs/.qwen:ro qwen-code-webui

# Open browser to http://localhost:3000
```

### Option 3: Development Mode

```bash
# Clone repository
git clone https://github.com/ivycomputing/qwen-code-webui.git
cd qwen-code-webui

# Backend (choose one)
cd backend && npm run dev      # Node.js runtime

# Frontend (new terminal)
cd frontend && npm run dev

# Open browser to http://localhost:3000
```

### Prerequisites

- ✅ **Qwen CLI** installed and authenticated ([Get it here](https://github.com/QwenLM/qwen-code))
- ✅ **Node.js >=20.0.0** (for npm installation) or **Docker** (for containerized deployment)
- ✅ **Modern browser** (Chrome, Firefox, Safari, Edge)

---

## ⚙️ CLI Options

The backend server supports the following command-line options:

| Option                 | Description                                               | Default     |
| ---------------------- | --------------------------------------------------------- | ----------- |
| `-p, --port <port>`    | Port to listen on                                         | 3000        |
| `--host <host>`        | Host address to bind to (use 0.0.0.0 for all interfaces)  | 127.0.0.1   |
| `--qwen-path <path>`   | Path to qwen executable (overrides automatic detection)   | Auto-detect |
| `-d, --debug`          | Enable debug mode                                         | false       |
| `-h, --help`           | Show help message                                         | -           |
| `-v, --version`        | Show version                                              | -           |

### Environment Variables

- `PORT` - Same as `--port`
- `DEBUG` - Same as `--debug`

### Examples

```bash
# Default (localhost:3000)
qwen-code-webui

# Custom port
qwen-code-webui --port 3000

# Bind to all interfaces (accessible from network)
qwen-code-webui --host 0.0.0.0 --port 9000

# Enable debug mode
qwen-code-webui --debug

# Custom Qwen CLI path
qwen-code-webui --qwen-path /path/to/qwen
```

---

## 🚨 Troubleshooting

### Qwen CLI Path Detection Issues

If you encounter errors, this typically indicates Qwen CLI path detection failure.

**Quick Solution:**

```bash
qwen-code-webui --qwen-path "$(which qwen)"
```

**Debug Mode:**
Use `--debug` flag for detailed error information:

```bash
qwen-code-webui --debug
```

---

## 🐳 Docker Deployment

### Quick Start with Docker

The easiest way to deploy with Docker is using Docker Compose:

```bash
# Build and start the container
docker compose up -d

# View logs
docker compose logs -f

# Stop the container
docker compose down
```

### Offline Deployment

For air-gapped or offline environments, you can export and load the Docker image:

#### 1. Export Image (on a machine with internet)

```bash
# Export image to tar file
./scripts/install/docker-method/export-image.sh -v 0.2.0

# Or specify output directory
./scripts/install/docker-method/export-image.sh -v 0.2.0 -o ~/Downloads
```

This creates `qwen-code-webui-0.2.0.tar.gz` (~150MB compressed).

#### 2. Transfer and Deploy (on target machine)

```bash
# Copy the tar file and scripts to target machine
scp qwen-code-webui-0.2.0.tar.gz user@target:/path/to/deploy/
scp -r scripts/install/docker-method/ user@target:/path/to/deploy/scripts/install/

# On target machine, deploy with the image file
./scripts/install/docker-method/install.sh -i ./qwen-code-webui-0.2.0.tar.gz

# Or let the script auto-detect the tar file
./scripts/install/docker-method/install.sh  # Automatically finds *.tar.gz in current directory
```

#### 3. Deploy Options

```bash
# Interactive mode (recommended for first time)
./scripts/install/docker-method/install.sh

# Non-interactive with firewall configuration
./scripts/install/docker-method/install.sh -y --firewall -i ./qwen-code-webui-0.2.0.tar.gz

# Custom port
./scripts/install/docker-method/install.sh -p 3000 -i ./qwen-code-webui-0.2.0.tar.gz
```

### Docker Configuration Options

#### Environment Variables

You can configure the container using environment variables in `docker-compose.yml`:

```yaml
environment:
  - PORT=3000           # Server port
  - HOST=0.0.0.0        # Bind address
  - DEBUG=true          # Enable debug mode (optional)
```

#### Volume Mounts

The Docker setup mounts the following volumes by default:

| Volume | Purpose |
|--------|---------|
| `~/.qwen:/home/nodejs/.qwen:ro` | Qwen CLI configuration and authentication |
| Project directories | Mount your project directories for Qwen to access |

To add more project directories, edit `docker-compose.yml`:

```yaml
volumes:
  - ~/.qwen:/home/nodejs/.qwen:ro
  - ~/my-project:/workspace/my-project:ro  # Add your projects
```

#### Custom Port

To use a different port, modify the ports mapping:

```yaml
ports:
  - "3000:3000"  # Host port 3000 -> Container port 3000
```

### Building the Image Manually

```bash
# Build the image
docker build -t qwen-code-webui .

# Run the container
docker run -d \
  --name qwen-code-webui \
  -p 3000:3000 \
  -v ~/.qwen:/home/nodejs/.qwen:ro \
  qwen-code-webui
```

### Docker Deployment Notes

1. **Authentication**: The container needs access to your Qwen CLI configuration. The default setup mounts `~/.qwen` read-only.

2. **Project Access**: Mount any project directories you want Qwen to work with using additional volume mounts.

3. **Qwen CLI**: The container expects Qwen CLI to be available. You can either:
   - Mount the Qwen binary from your host: `-v $(which qwen):/usr/local/bin/qwen:ro`
   - Install Qwen CLI inside the container (modify the Dockerfile)

4. **Security**: The container runs as a non-root user (`nodejs`) for improved security.

---

## 🔧 Development

### Setup

```bash
# Clone repository
git clone https://github.com/ivycomputing/qwen-code-webui.git
cd qwen-code-webui

# Install dependencies
cd backend && npm install
cd ../frontend && npm install
```

### Development Commands

```bash
# Start backend
cd backend && npm run dev

# Start frontend (new terminal)
cd frontend && npm run dev
```

---

## 🔒 Security Considerations

**Important**: This tool executes Qwen CLI locally and provides web access to it.

### ✅ Safe Usage Patterns

- **🏠 Local development**: Default localhost access
- **📱 Personal network**: LAN access from your own devices

### ⚠️ Security Notes

- **No authentication**: Currently no built-in auth mechanism
- **System access**: Qwen can read/write files in selected projects
- **Network exposure**: Configurable but requires careful consideration

---

## ❓ FAQ

<details>
<summary><strong>Q: Do I need Qwen API access?</strong></summary>

Yes, you need the Qwen CLI tool installed and authenticated. The web UI is a frontend for the existing Qwen CLI.

</details>

<details>
<summary><strong>Q: Can I use this on mobile?</strong></summary>

Yes! The web interface is fully responsive and works great on mobile devices when connected to your local network.

</details>

<details>
<summary><strong>Q: Is my code safe?</strong></summary>

Yes, everything runs locally. No data is sent to external servers except Qwen's normal API calls through the CLI.

</details>

---

## 🤝 Contributing

We welcome contributions! Please feel free to:

- 🐛 Report bugs
- ✨ Suggest features
- 📝 Improve documentation
- 🔧 Submit pull requests

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ for the Qwen Code community**

[⭐ Star this repo](https://github.com/ivycomputing/qwen-code-webui) • [🐛 Report issues](https://github.com/ivycomputing/qwen-code-webui/issues)

</div>
