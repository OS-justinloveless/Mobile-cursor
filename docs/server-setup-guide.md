# Napp Trapp Server Setup Guide

A complete, step-by-step guide to setting up the Napp Trapp server from scratch on a fresh Linux or macOS machine. This covers everything from OS-level prerequisites to connecting your first mobile client.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
   - [System Requirements](#system-requirements)
   - [Install Node.js](#install-nodejs)
   - [Install Build Tools](#install-build-tools-for-native-modules)
   - [Install Git](#install-git)
   - [Install Go (for nappctl)](#install-go-for-nappctl)
   - [Install tmux (optional but recommended)](#install-tmux-optional-but-recommended)
3. [Install nappctl](#install-nappctl)
   - [From source](#from-source)
   - [Using go install](#using-go-install)
   - [Verify prerequisites with nappctl](#verify-prerequisites-with-nappctl)
4. [AI CLI Tools Setup](#ai-cli-tools-setup)
   - [Claude Code CLI (recommended)](#option-a-claude-code-cli-recommended)
   - [Cursor Agent CLI](#option-b-cursor-agent-cli)
   - [Gemini CLI](#option-c-gemini-cli)
5. [Server Installation](#server-installation)
   - [Option A: Install from npm (simplest)](#option-a-install-from-npm-simplest)
   - [Option B: Clone and run from source](#option-b-clone-and-run-from-source)
   - [Option C: Docker](#option-c-docker)
6. [Configuration](#configuration)
   - [nappctl config](#nappctl-config)
   - [Environment Variables](#environment-variables)
   - [Authentication](#authentication)
   - [Data Storage](#data-storage)
7. [Running the Server](#running-the-server)
   - [Using nappctl (recommended)](#using-nappctl-recommended)
   - [Direct methods](#direct-methods)
   - [Running as a background service](#running-as-a-background-service-linux)
8. [Managing the Server with nappctl](#managing-the-server-with-nappctl)
   - [Server lifecycle](#server-lifecycle)
   - [Authentication management](#authentication-management)
   - [Data management](#data-management)
   - [Diagnostics](#diagnostics)
9. [Connecting a Client](#connecting-a-client)
10. [Network Configuration](#network-configuration)
    - [Same Wi-Fi Network](#same-wi-fi-network)
    - [Tailscale (remote access)](#tailscale-remote-access)
    - [Firewall Rules](#firewall-rules)
11. [Verifying the Installation](#verifying-the-installation)
12. [Troubleshooting](#troubleshooting)

---

## Overview

Napp Trapp is a mobile-first IDE controller. The **server** runs on your development machine (the computer where your code lives) and exposes an API + WebSocket interface that mobile clients connect to. From your phone you can:

- Browse and edit files
- Run AI coding agents (Claude, Cursor Agent, Gemini)
- Use interactive terminals (via PTY or tmux)
- Manage Git repositories
- View project structures

The server is a Node.js/Express application that listens on port **3847** by default.

**nappctl** is the companion CLI tool (written in Go) that manages the server process, authentication tokens, data, and diagnostics. It is the recommended way to operate a Napp Trapp server.

---

## Prerequisites

### System Requirements

| Requirement | Minimum |
|---|---|
| OS | Linux (Ubuntu 20.04+, Debian 11+, RHEL 8+, etc.) or macOS 12+ |
| Node.js | 18.0.0 or higher (20.x LTS recommended) |
| Go | 1.21+ (only needed for building nappctl) |
| RAM | 512 MB free (1 GB+ recommended when running AI CLI tools) |
| Disk | 200 MB for the server + dependencies |
| Network | Local network access (Wi-Fi) or Tailscale for remote |

### Install Node.js

The server requires Node.js 18 or higher. Node.js 20 LTS is recommended.

**Linux (Ubuntu/Debian):**

```bash
# Install Node.js 20.x via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version   # Should print v20.x.x
npm --version    # Should print 10.x.x
```

**Linux (RHEL/CentOS/Fedora):**

```bash
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs
```

**macOS (via Homebrew):**

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js
brew install node@20

# Verify
node --version
npm --version
```

**Alternative: Using nvm (all platforms):**

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Restart your terminal, then:
nvm install 20
nvm use 20

# Verify
node --version
```

### Install Build Tools (for native modules)

The server depends on two native Node.js modules that must be compiled from C/C++ source during `npm install`:

- **`better-sqlite3`** -- SQLite database for chat persistence
- **`node-pty`** -- Pseudo-terminal support for interactive shells

These require a C/C++ compiler and Python 3.

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get update
sudo apt-get install -y build-essential python3 make g++
```

**Linux (RHEL/CentOS/Fedora):**

```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y python3
```

**Linux (Alpine -- for Docker):**

```bash
apk add --no-cache python3 make g++ linux-headers
```

**macOS:**

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Python 3 is included with macOS 12.3+
# If you need it: brew install python3
```

### Install Git

Git is required for the server's Git operations (status, diff, log, commit, branch management, etc.).

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get install -y git
```

**Linux (RHEL/CentOS/Fedora):**

```bash
sudo yum install -y git
```

**macOS:**

```bash
# Git is included with Xcode Command Line Tools
# Or install via Homebrew:
brew install git
```

Verify:

```bash
git --version   # Should print git version 2.x.x
```

### Install Go (for nappctl)

Go 1.21+ is required to build `nappctl`. If you don't plan to use nappctl, you can skip this.

**Linux (Ubuntu/Debian):**

```bash
# Download and install Go (check https://go.dev/dl/ for latest version)
curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf -

# Add to your PATH (add to ~/.bashrc or ~/.zshrc for persistence)
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
```

**macOS:**

```bash
brew install go

# Or download from https://go.dev/dl/
```

Verify:

```bash
go version   # Should print go1.21+ or higher
```

**Important:** Make sure `$HOME/go/bin` is in your `PATH` so that `go install` binaries are accessible:

```bash
# Add to ~/.bashrc, ~/.zshrc, or ~/.profile
export PATH="$HOME/go/bin:$PATH"
```

### Install tmux (optional but recommended)

tmux provides persistent, multiplexed terminal sessions. Without tmux, the server still provides terminal access via PTY sessions, but tmux adds session persistence (terminals survive app disconnects) and the ability to have multiple clients view the same terminal.

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get install -y tmux
```

**Linux (RHEL/CentOS/Fedora):**

```bash
sudo yum install -y tmux
```

**macOS:**

```bash
brew install tmux
```

Verify:

```bash
tmux -V   # Should print tmux 3.x
```

---

## Install nappctl

`nappctl` is a Go CLI tool for managing the Napp Trapp server. It handles server start/stop, auth token management, prerequisite checks, diagnostics, and data management.

### From source

```bash
git clone https://github.com/OS-justinloveless/Napp-Trapp.git
cd Napp-Trapp/nappctl

# Download dependencies and build
make deps
make build

# The binary is at ./bin/nappctl
# Install to $GOPATH/bin so it's in your PATH:
make install
```

### Using go install

```bash
go install github.com/OS-justinloveless/Napp-Trapp/nappctl/cmd/nappctl@latest
```

### Verify installation

```bash
nappctl --version
```

### Verify prerequisites with nappctl

Once installed, nappctl can check all system prerequisites for you:

```bash
nappctl prereq check
```

This prints a table showing the status of every required tool:

```
  Prerequisite    Status         Version    Install Hint
  Node.js         ✓ Installed    v20.11.0
  npm             ✓ Installed    10.2.4
  cursor-agent    ✗ Missing                 curl https://cursor.com/install -fsS | bash
  git             ✓ Installed    2.43.0
```

You can also check a single prerequisite:

```bash
nappctl prereq check-one node
nappctl prereq check-one git
```

---

## AI CLI Tools Setup

The chat feature in Napp Trapp works by spawning AI CLI tools as child processes. You need **at least one** of the following installed. Claude Code CLI is the most fully supported.

### Option A: Claude Code CLI (recommended)

Claude Code is the primary AI tool supported by Napp Trapp. It provides the richest integration including streaming, tool use, session resume, and permission management.

**Step 1: Install the CLI**

```bash
# Install globally via npm
npm install -g @anthropic-ai/claude-code
```

**Step 2: Create an Anthropic account and get an API key**

1. Go to [https://console.anthropic.com/](https://console.anthropic.com/)
2. Sign up for an account (or log in)
3. Navigate to **Settings** > **API Keys**
4. Click **Create Key**
5. Copy the key -- it starts with `sk-ant-...`
6. **Important:** Add billing/credits to your account. Claude Code requires a funded API account.

**Step 3: Authenticate the CLI**

```bash
claude login
```

This will open a browser window to authenticate. Follow the prompts.

Alternatively, set the API key directly:

```bash
# Create the Claude config directory
mkdir -p ~/.claude

# Set your API key (replace with your actual key)
echo '{"apiKey": "sk-ant-your-key-here"}' > ~/.claude/.claude.json
```

**Step 4: Verify**

```bash
claude --version
claude --print "Hello, world"   # Should get a response
```

**Optional: AWS Bedrock Configuration**

If you use Claude via AWS Bedrock instead of the Anthropic API directly, create a settings file:

```bash
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "ANTHROPIC_MODEL": "arn:aws:bedrock:us-east-1:ACCOUNT_ID:inference-profile/global.anthropic.claude-sonnet-4-5-20250929-v1:0",
    "AWS_REGION": "us-east-1"
  }
}
EOF
```

You will also need the AWS CLI configured with valid credentials (`aws configure`).

### Option B: Cursor Agent CLI

Cursor Agent is the CLI tool from Cursor IDE.

**Step 1: Install**

```bash
curl https://cursor.com/install -fsS | bash
```

**Step 2: Authenticate**

```bash
cursor-agent login
```

This opens a browser to log in with your Cursor account. You need an active Cursor subscription.

**Step 3: Verify**

```bash
cursor-agent --version
```

### Option C: Gemini CLI

Google's Gemini CLI is also supported, though with less deep integration.

**Step 1: Install**

Check the [Google AI documentation](https://ai.google.dev/) for the latest CLI installation instructions.

**Step 2: Get a Google AI API key**

1. Go to [https://aistudio.google.com/](https://aistudio.google.com/)
2. Sign in with your Google account
3. Navigate to API keys
4. Create a new API key
5. Set it as an environment variable:

```bash
export GEMINI_API_KEY="your-key-here"
# Add to your shell profile (~/.bashrc, ~/.zshrc) for persistence
```

**Step 3: Verify**

```bash
gemini --version
```

### Checking What's Installed

You can check which AI tools are detected at any time:

```bash
# Via nappctl (before server is running)
nappctl prereq check

# Via the API (after server is running)
TOKEN=$(nappctl auth show | grep Token | awk '{print $2}')
curl -H "Authorization: Bearer $TOKEN" http://localhost:3847/api/system/tools-status
```

---

## Server Installation

Choose one of the following methods.

### Option A: Install from npm (simplest)

This is the fastest way to get up and running. The npm package includes the pre-built web client.

```bash
# Run directly (no global install needed)
npx napptrapp

# Or install globally
npm install -g napptrapp
napptrapp
```

**CLI Options:**

```
napptrapp [options]

  --port, -p <port>     Port to run on (default: 3847)
  --token, -t <token>   Auth token (default: auto-generated & persisted)
  --data-dir <path>     Data storage directory (default: ~/.napptrapp)
  --help, -h            Show help
  --version, -v         Show version
```

Data is stored in `~/.napptrapp/` by default when running via npx/CLI.

### Option B: Clone and run from source

This is best for development or if you want to modify the server. This is also required if you want to use `nappctl` to manage the server (nappctl looks for `server/src/index.js` relative to the repo).

**Step 1: Clone the repository**

```bash
git clone https://github.com/OS-justinloveless/Napp-Trapp.git
cd Napp-Trapp
```

**Step 2: Install server dependencies**

```bash
cd server
npm install
```

This will compile the native modules (`better-sqlite3`, `node-pty`). If this step fails, make sure you have build tools installed (see [Install Build Tools](#install-build-tools-for-native-modules)).

**Step 3: Build the web client (optional but recommended)**

The web client is a React app that provides a browser-based interface. If you only plan to use the iOS or Android native apps, you can skip this.

```bash
# From the repository root
cd client
npm install
npm run build

# Or from the server directory, use the convenience script:
cd ../server
npm run build:client
```

This builds the client and copies it to `server/client-dist/`.

**Step 4: Configure environment (optional)**

```bash
cd server
cp .env.example .env
# Edit .env as needed (see Configuration section below)
```

**Step 5: Build nappctl (recommended)**

```bash
cd ../nappctl
make deps
make install
```

**Step 6: Run diagnostics to verify everything**

```bash
nappctl doctor
```

If any issues are found, let nappctl fix them automatically:

```bash
nappctl doctor --fix
```

**Step 7: Start the server**

```bash
# Using nappctl (recommended -- starts as background daemon):
nappctl server start

# Or directly:
cd server
npm start

# Or for development with auto-reload:
npm run dev
```

### Option C: Docker

Docker is the easiest way to get a reproducible, isolated installation. It bundles everything needed.

**Step 1: Install Docker**

Follow the official instructions for your platform:
- Linux: [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)
- macOS: [https://docs.docker.com/desktop/install/mac-install/](https://docs.docker.com/desktop/install/mac-install/)

**Step 2: Run with Docker**

```bash
# Quick start (pulls from Docker Hub)
docker run -d \
  --name napptrapp \
  -p 3847:3847 \
  -v napptrapp-data:/data \
  justinlovelessx/napptrapp

# View logs
docker logs -f napptrapp
```

**Or build and run from source with docker-compose:**

```bash
git clone https://github.com/OS-justinloveless/Napp-Trapp.git
cd Napp-Trapp

docker-compose up -d
```

**Step 3: Customization**

To set a custom auth token or port:

```bash
docker run -d \
  --name napptrapp \
  -p 8080:3847 \
  -e AUTH_TOKEN=my-secure-token \
  -v napptrapp-data:/data \
  justinlovelessx/napptrapp
```

To give the server access to your host filesystem (for browsing/editing projects):

```bash
docker run -d \
  --name napptrapp \
  -p 3847:3847 \
  -v napptrapp-data:/data \
  -v /home/yourusername/projects:/home/yourusername/projects \
  justinlovelessx/napptrapp
```

**Note:** The Docker image does **not** include AI CLI tools (claude, cursor-agent, gemini) or tmux. The chat feature and tmux terminals will not be available when running via Docker unless you build a custom image that includes them. nappctl is also not applicable inside Docker containers.

---

## Configuration

### nappctl config

nappctl stores its own configuration in `~/.napptrapp/config.yaml`. Use the `config` subcommands to manage it:

```bash
# Show all current settings
nappctl config show

# Output:
#   Setting        Value
#   Port           3847
#   Host           localhost
#   Data Directory /home/user/.napptrapp
#   Server URL     http://localhost:3847
#   Auth Token     (not set)

# Change the port
nappctl config set port 8080

# Change the host (for QR code generation)
nappctl config set host 192.168.1.100

# Get a single value
nappctl config get port
nappctl config get server-url
nappctl config get data-dir

# Reset all config to defaults
nappctl config reset

# Show where the config file lives
nappctl config path
```

Available config keys for `set`: `port`, `host`

Available config keys for `get`: `port`, `host`, `data-dir`, `server-url`, `auth-token`

### Environment Variables

The server is configured via environment variables. These can be set in a `.env` file (in the `server/` directory when running from source) or passed directly. Environment variables take priority over nappctl config values.

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3847` | HTTP/WebSocket port |
| `AUTH_TOKEN` | (auto-generated) | Override the authentication token. By default, a UUID is generated on first run and persisted to disk so it survives restarts. |
| `NAPPTRAPP_DATA_DIR` | `~/.napptrapp` (CLI) or `server/.napp-trapp-data` (source) | Directory for persistent data (auth, chat history, project registry) |
| `CHAT_RETENTION_DAYS` | `30` | Number of days to keep chat conversations before auto-cleanup |
| `CHAT_MAX_CONVERSATIONS` | `100` | Maximum number of stored conversations |

### Authentication

The server uses token-based authentication for all API and WebSocket requests.

**How it works:**

1. On first startup, the server generates a random UUID token and saves it to `{dataDir}/auth.json`
2. On subsequent startups, the same token is loaded from disk -- clients do not need to re-authenticate after server restarts
3. If you set the `AUTH_TOKEN` environment variable, it overrides the persisted token
4. The auth token is displayed in the terminal on startup and embedded in the QR code

**Managing tokens with nappctl:**

```bash
# Show the current auth token
nappctl auth show

# Show the token with a QR code for scanning
nappctl auth show --qr

# Show QR codes for both local network and Tailscale
nappctl auth show --qr --tailscale
```

See the [Authentication management](#authentication-management) section below for the full set of auth commands.

**Overriding the token without nappctl:**

```bash
# Via environment variable
AUTH_TOKEN=my-custom-token npm start

# Via the napptrapp CLI flag
npx napptrapp --token my-custom-token
```

**Viewing the current token without nappctl:**

The token is printed in the startup banner. You can also find it in:

```bash
cat ~/.napptrapp/auth.json   # CLI mode
# or
cat server/.napp-trapp-data/auth.json   # Source mode
```

### Data Storage

All server data is stored in a single directory:

```
{dataDir}/
  auth.json                  # Authentication token and sessions
  chat-persistence.db        # SQLite database for chat history
  registered-projects.json   # List of registered projects
  config.yaml                # nappctl configuration
  logs/                      # Server logs (when using nappctl)
    server.log
  server.pid                 # PID file (when using nappctl daemon mode)
```

Default locations:
- **npm/CLI mode:** `~/.napptrapp/`
- **Source/development mode:** `server/.napp-trapp-data/`
- **Docker:** `/data/` (mapped to a Docker volume)

You can override the data directory globally:

```bash
# Via environment variable
export NAPPTRAPP_DATA_DIR=/opt/napptrapp/data

# Via nappctl flag
nappctl -d /opt/napptrapp/data server start
```

---

## Running the Server

### Using nappctl (recommended)

nappctl starts the server as a background daemon by default, with PID tracking and log management.

```bash
# Start server in background (default port 3847)
nappctl server start

# Start on a custom port
nappctl server start --port 8080

# Start in foreground (for debugging -- logs go to stdout)
nappctl server start --detach=false

# Check if it's running
nappctl server status

# View logs
nappctl server logs

# Follow logs in real time
nappctl server logs --follow

# Show last 100 lines
nappctl server logs --lines 100

# Restart the server
nappctl server restart

# Stop the server
nappctl server stop
```

When started with nappctl, logs are written to `~/.napptrapp/logs/server.log` and a PID file is stored at `~/.napptrapp/server.pid`.

### Direct methods

If you prefer not to use nappctl:

**From npm:**

```bash
npx napptrapp
```

**From source:**

```bash
cd server
npm start
```

### Expected output

When the server starts successfully, you'll see a banner like this:

```
╔═══════════════════════════════════════════════════════════════════╗
║              Napp Trapp Server                                   ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   Scan this QR code with your phone camera to connect:           ║
║                                                                   ║
║    [QR CODE]                                                      ║
║                                                                   ║
╠═══════════════════════════════════════════════════════════════════╣
║   Manual Connection (if QR doesn't work):                         ║
║   URL:   http://192.168.1.100:3847                               ║
║   Token: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                    ║
╚═══════════════════════════════════════════════════════════════════╝
```

The QR code encodes the connection URL with the auth token. Scanning it with your phone camera will open the web client and authenticate automatically.

### Running as a background service (Linux)

For long-running production deployments, you can use systemd instead of (or in addition to) nappctl:

```bash
sudo tee /etc/systemd/system/napptrapp.service << 'EOF'
[Unit]
Description=Napp Trapp Server
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/home/YOUR_USERNAME
ExecStart=/usr/bin/npx napptrapp
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable napptrapp
sudo systemctl start napptrapp

# Check status
sudo systemctl status napptrapp

# View logs
sudo journalctl -u napptrapp -f
```

Replace `YOUR_USERNAME` with your Linux username. Adjust `ExecStart` if you're running from source instead of npm.

---

## Managing the Server with nappctl

### Server lifecycle

```bash
# Start the server as a background daemon
nappctl server start

# Start on a specific port
nappctl server start --port 8080

# Start in foreground mode (useful for debugging)
nappctl server start --detach=false

# Check server status (shows PID and URL)
nappctl server status

# Restart (stops then starts)
nappctl server restart

# Stop gracefully (sends SIGTERM, waits 5s, then SIGKILL)
nappctl server stop

# View server logs
nappctl server logs

# Tail logs in real time
nappctl server logs --follow

# Show last N lines of logs
nappctl server logs --lines 200
```

### Authentication management

```bash
# Display the current auth token
nappctl auth show

# Display with QR code (for scanning with your phone)
nappctl auth qr

# Display QR code for Tailscale connection too
nappctl auth qr --tailscale

# Generate a new token (fails if one exists; use --force to overwrite)
nappctl auth generate
nappctl auth generate --force

# Generate and immediately show QR code
nappctl auth generate --force --qr

# Rotate token (generates new token, invalidates old one)
nappctl auth rotate

# Rotate and show QR codes for both local and Tailscale
nappctl auth rotate --qr --tailscale

# Delete the auth token entirely
nappctl auth delete
```

After rotating a token, all connected clients will need to re-authenticate. Use `nappctl auth qr` to get a fresh QR code to scan.

### Data management

```bash
# Show data directory location, size, and contents
nappctl data info

# Print just the data directory path
nappctl data path

# Clean up old logs (truncates large log files)
nappctl data clean

# Clean without confirmation prompt
nappctl data clean --force

# Full reset -- deletes ALL data (auth, chats, projects, logs)
# WARNING: This is destructive and irreversible
nappctl data reset

# Reset without confirmation prompt
nappctl data reset --force
```

### Diagnostics

The `doctor` command runs a comprehensive health check across 8 areas and can auto-fix common issues:

```bash
# Run diagnostics
nappctl doctor
```

This checks:

1. **Node.js** -- Is it installed? What version?
2. **Server files** -- Can nappctl locate `server/src/index.js`?
3. **Server dependencies** -- Is `node_modules/` present?
4. **Data directory** -- Does `~/.napptrapp/` exist?
5. **Auth token** -- Does `auth.json` exist?
6. **Server path config** -- Is the server path saved in `config.yaml`?
7. **QR code package** -- Is the `qrcode` npm package available? (optional)
8. **Go bin in PATH** -- Is `$GOPATH/bin` in your `PATH`?

Example output:

```
🔍 Running Napp Trapp diagnostics...

✓ Node.js installed
  Version: v20.11.0
✓ Server files found
✓ Server dependencies installed
✓ Data directory exists
  Location: /home/user/.napptrapp
✗ Auth token: no auth.json found
✗ Server path: not configured
⚠ QR code package: not installed
✓ Go bin directory in PATH

✗ Found 2 issue(s)
  Run 'nappctl doctor --fix' to automatically fix what we can
```

Auto-fix all fixable issues:

```bash
nappctl doctor --fix
```

This will:
- Install missing npm dependencies (`npm install` in the server directory)
- Create the data directory if it's missing
- Generate an auth token if one doesn't exist
- Save the detected server path to `config.yaml`

Issues that require manual intervention (like installing Node.js) will be flagged with instructions.

### nappctl global flags

These flags can be used with any nappctl command:

```bash
# Override the data directory for this invocation
nappctl -d /custom/data/dir server start

# Enable verbose output
nappctl -v doctor
```

---

## Connecting a Client

### Web Client (any device with a browser)

1. Start the server
2. On your phone, scan the QR code shown in the terminal -- OR run `nappctl auth qr` to show it again --
3. Open a browser and navigate to `http://<server-ip>:3847`
4. Enter the auth token when prompted (get it with `nappctl auth show`)

### iOS Native App

1. Build and install the iOS app from `ios-client/` (requires macOS + Xcode)
2. Open the app
3. Scan the QR code or manually enter the server URL and token in Settings

### Android Native App

1. Build and install the Android app from `android-client/` (requires Android SDK)
2. Open the app
3. Scan the QR code or manually enter the server URL and token

---

## Network Configuration

Your phone and the server must be able to reach each other over the network.

### Same Wi-Fi Network

The simplest setup. If both your phone and computer are on the same Wi-Fi network, the server's local IP address (shown in the startup banner, e.g., `192.168.1.100`) should be directly accessible from your phone.

### Tailscale (remote access)

Tailscale creates a secure mesh VPN that lets your devices communicate as if they were on the same network, even across the internet. This is the recommended approach for remote access.

**Step 1: Create a Tailscale account**

1. Go to [https://tailscale.com/](https://tailscale.com/)
2. Sign up (free for personal use with up to 100 devices)

**Step 2: Install Tailscale on your server**

**Linux:**

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Follow the authentication URL printed in the terminal to add the machine to your tailnet.

**macOS:**

Download from the App Store or:

```bash
brew install tailscale
# Or download from https://tailscale.com/download/mac
```

**Step 3: Install Tailscale on your phone**

- iOS: Download "Tailscale" from the App Store
- Android: Download "Tailscale" from Google Play

Sign in with the same account you used on the server.

**Step 4: Connect**

Once both devices are on the same tailnet, Napp Trapp will automatically detect Tailscale and display the Tailscale IP and MagicDNS hostname in the startup banner:

```
╔═══════════════════════════════════════════════════════════════════╗
║   Tailscale Connected                                             ║
╠═══════════════════════════════════════════════════════════════════╣
║   Tailscale IP:  100.x.y.z                                       ║
║   MagicDNS:     your-machine.tailnet-name.ts.net                 ║
║   Tailscale URL: http://100.x.y.z:3847                           ║
║                                                                    ║
║   iOS devices on your tailnet will auto-discover this server.     ║
╚═══════════════════════════════════════════════════════════════════╝
```

You can also get a QR code specifically for the Tailscale address:

```bash
nappctl auth qr --tailscale
```

Use the Tailscale IP or MagicDNS hostname to connect from your phone.

### Firewall Rules

If your phone can't reach the server, you may need to open port 3847 in your firewall.

**Linux (UFW -- Ubuntu/Debian):**

```bash
sudo ufw allow 3847/tcp
```

**Linux (firewalld -- RHEL/CentOS/Fedora):**

```bash
sudo firewall-cmd --add-port=3847/tcp --permanent
sudo firewall-cmd --reload
```

**macOS:**

macOS typically allows incoming connections for apps you run. If prompted, click "Allow" when the system asks about incoming connections.

---

## Verifying the Installation

After starting the server, run through these checks:

**1. Server status (with nappctl):**

```bash
nappctl server status
# Expected: "Server is running (PID: 12345)"
```

**2. Health check:**

```bash
curl http://localhost:3847/health
# Expected: {"status":"ok","timestamp":"..."}
```

**3. System info (requires auth):**

```bash
TOKEN=$(nappctl auth show | grep Token | awk '{print $2}')
curl -H "Authorization: Bearer $TOKEN" http://localhost:3847/api/system/info
# Expected: JSON with hostname, platform, arch, memory, etc.
```

**4. AI tools status:**

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3847/api/system/tools-status
# Expected: JSON showing which AI CLI tools are detected
# Example: {"tools":{"cursor-agent":{"available":false,...},"claude":{"available":true,...},"gemini":{"available":false,...}}}
```

**5. Project list:**

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3847/api/projects
# Expected: JSON array of registered projects (empty on first run)
```

**6. Web client:**

Open `http://localhost:3847` in a browser. You should see the Napp Trapp web interface.

**7. Full diagnostic:**

```bash
nappctl doctor
# Expected: All checks passing green
```

---

## Troubleshooting

### `npm install` fails with compilation errors

This usually means build tools are missing. Make sure you have:

```bash
# Linux
sudo apt-get install -y build-essential python3 make g++

# macOS
xcode-select --install
```

If `node-pty` specifically fails on Linux, you may also need:

```bash
sudo apt-get install -y cmake   # Some distros need cmake for node-pty
```

### nappctl can't find the server

nappctl looks for `server/src/index.js` in several locations:

1. Path configured in `~/.napptrapp/config.yaml`
2. Relative to the nappctl binary (`../server/src/index.js`)
3. Current working directory (`./server/src/index.js`)
4. Home directory (`~/.napptrapp/server/src/index.js`)

If none of these work, run from the repository root or set the path manually:

```bash
nappctl doctor --fix   # Auto-detects and saves the server path
```

### nappctl says "server is already running" but it's not

The PID file may be stale (e.g., after a crash). Remove it manually:

```bash
rm ~/.napptrapp/server.pid
nappctl server start
```

### Server starts but phone can't connect

1. **Check the IP address** -- Make sure your phone can reach the IP shown in the banner. Try pinging it from another device.
2. **Same network?** -- Both devices must be on the same Wi-Fi network (or connected via Tailscale).
3. **Firewall** -- Open port 3847 (see [Firewall Rules](#firewall-rules)).
4. **Corporate/guest Wi-Fi** -- Some networks block device-to-device communication. Use Tailscale in this case.

### "No AI tools found" in chat

Make sure at least one AI CLI is installed and authenticated:

```bash
# Quick check with nappctl
nappctl prereq check

# Or manually
which claude && claude --version
which cursor-agent && cursor-agent --version
which gemini && gemini --version
```

If the CLI is installed but the server doesn't detect it, make sure the executable is in the server process's `PATH`. When running via systemd, you may need to add the path explicitly:

```bash
# In your systemd service file, add:
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/home/YOUR_USERNAME/.local/bin
```

### Chat sessions error with "CLI not found"

The Claude CLI binary may be installed in a non-standard location. Check:

```bash
which claude
# If this returns a path like /home/user/.local/bin/claude,
# make sure that directory is in your PATH
```

### `better-sqlite3` crashes or won't load

This can happen if Node.js was upgraded after `npm install`. Rebuild native modules:

```bash
cd server
npm rebuild better-sqlite3
npm rebuild node-pty
```

Or let nappctl fix it:

```bash
nappctl doctor --fix
```

### tmux features not working

```bash
# Verify tmux is installed
which tmux
tmux -V

# If not installed:
# Ubuntu/Debian: sudo apt-get install -y tmux
# macOS: brew install tmux
# RHEL: sudo yum install -y tmux
```

tmux is optional. Without it, the server still provides PTY-based terminals.

### Server crashes on startup

Check the logs for specific errors:

```bash
# If using nappctl
nappctl server logs

# Common causes:
```

- **Port already in use:** Another process is using port 3847. Change the port: `nappctl server start --port 4000`
- **Permission denied:** The data directory isn't writable. Check permissions on `~/.napptrapp/` or `server/.napp-trapp-data/`.
- **Node.js too old:** Verify `node --version` is 18.0.0 or higher.

### Docker: Chat/AI features not available

The default Docker image does not include AI CLI tools. To use chat features with Docker, you would need to build a custom image that includes the Claude CLI (or other tools), or run the server natively instead of in Docker.

---

## Quick Reference

### nappctl commands

| Command | Description |
|---|---|
| `nappctl server start` | Start server (background daemon) |
| `nappctl server start --port 8080` | Start on custom port |
| `nappctl server start --detach=false` | Start in foreground |
| `nappctl server stop` | Stop the server |
| `nappctl server restart` | Restart the server |
| `nappctl server status` | Check if server is running |
| `nappctl server logs` | View server logs |
| `nappctl server logs -f` | Tail logs in real time |
| `nappctl auth show` | Show auth token |
| `nappctl auth qr` | Show QR code for mobile connection |
| `nappctl auth qr -t` | Show QR codes (local + Tailscale) |
| `nappctl auth generate` | Generate a new token |
| `nappctl auth rotate` | Rotate (replace) the token |
| `nappctl auth delete` | Delete the token |
| `nappctl prereq check` | Check all prerequisites |
| `nappctl doctor` | Run full diagnostics |
| `nappctl doctor --fix` | Diagnose and auto-fix issues |
| `nappctl config show` | Show all config settings |
| `nappctl config set port 8080` | Change a config value |
| `nappctl config get server-url` | Get a single config value |
| `nappctl config reset` | Reset config to defaults |
| `nappctl data info` | Show data directory details |
| `nappctl data path` | Print data directory path |
| `nappctl data clean` | Clean up old logs |
| `nappctl data reset` | Delete all data and reinitialize |

### Direct commands (without nappctl)

| What | Command |
|---|---|
| Start server (npm) | `npx napptrapp` |
| Start server (source) | `cd server && npm start` |
| Start server (Docker) | `docker run -p 3847:3847 justinlovelessx/napptrapp` |
| Custom port | `npx napptrapp --port 8080` |
| Custom token | `npx napptrapp --token my-token` |
| Health check | `curl http://localhost:3847/health` |
| View QR code | `curl http://localhost:3847/qr` |
| Check AI tools | `curl -H "Authorization: Bearer TOKEN" http://localhost:3847/api/system/tools-status` |
| View auth token | `cat ~/.napptrapp/auth.json` |
| Server logs (systemd) | `journalctl -u napptrapp -f` |
| Server logs (Docker) | `docker logs -f napptrapp` |
