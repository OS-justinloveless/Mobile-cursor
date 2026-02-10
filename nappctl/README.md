# nappctl - Napp Trapp Control CLI

A command-line interface for managing the Napp Trapp mobile IDE server.

## Features

- **Server Management**: Start, stop, restart, and monitor the Napp Trapp server
- **Authentication**: Generate, rotate, and display auth tokens with QR codes
- **Prerequisites Checking**: Verify all required tools are installed
- **Data Management**: View, export, backup, and restore chat history
- **Configuration**: Manage CLI settings

## Installation

### From Source

```bash
cd nappctl
make build
make install
```

### Using Go Install

```bash
go install github.com/OS-justinloveless/Napp-Trapp/nappctl/cmd/nappctl@latest
```

## Quick Start

```bash
# Check prerequisites
nappctl prereq check

# Start the server
nappctl server start

# View server status
nappctl server status

# Show auth token with QR code
nappctl auth qr

# Stop the server
nappctl server stop
```

## Commands

### Server Management

- `nappctl server start` - Start server (daemon mode by default)
- `nappctl server start --foreground` - Start in foreground mode
- `nappctl server stop` - Stop server gracefully
- `nappctl server stop --force` - Force stop server
- `nappctl server restart` - Restart server
- `nappctl server status` - Show server status
- `nappctl server logs` - View server logs
- `nappctl server logs --follow` - Tail server logs

### Authentication

- `nappctl auth show` - Display current token
- `nappctl auth generate` - Generate new token
- `nappctl auth rotate` - Rotate token
- `nappctl auth qr` - Show QR code for mobile connection

### Prerequisites

- `nappctl prereq check` - Check all prerequisites
- `nappctl prereq list` - List detected tools

### Data Management

- `nappctl data info` - Show data directory info
- `nappctl data path` - Print data directory path
- `nappctl data export --output backup.json` - Export chat history
- `nappctl data clear --confirm` - Clear all data

### Configuration

- `nappctl config show` - Display configuration
- `nappctl config set KEY VALUE` - Set configuration value
- `nappctl config reset` - Reset to defaults

## Configuration

Configuration is stored in `~/.napptrapp/config.yaml`.

### Environment Variables

- `NAPPTRAPP_DATA_DIR` - Override data directory location
- `AUTH_TOKEN` - Override auth token
- `PORT` - Server port (default: 3847)

### Data Directory Priority

1. `NAPPTRAPP_DATA_DIR` environment variable
2. `~/.napptrapp` (default for CLI)
3. `./.napp-trapp-data` (development mode)

## Development

```bash
# Install dependencies
make deps

# Build
make build

# Run tests
make test

# Cross-compile
make build-all
```

## Architecture

- **Daemon Mode**: Server runs in background by default
- **Process Management**: PID file-based process tracking
- **Auto-detection**: Automatically finds Node.js and napptrapp installation
- **Graceful Shutdown**: SIGTERM with 30-second timeout

## Requirements

- Go 1.21+
- Node.js 18+ (for running the server)
- npm (for server installation)

## License

MIT
