package server

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// FindNodeJS attempts to locate the Node.js executable.
// Returns the path to node or an error if not found.
func FindNodeJS() (string, error) {
	// Try to find node in PATH
	path, err := exec.LookPath("node")
	if err == nil {
		return path, nil
	}

	// Common installation locations on macOS/Linux
	commonPaths := []string{
		"/usr/local/bin/node",
		"/opt/homebrew/bin/node",
		"/usr/bin/node",
	}

	for _, p := range commonPaths {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}

	return "", fmt.Errorf("node.js not found in PATH or common locations")
}

// GetNodeVersion returns the version of Node.js at the given path.
func GetNodeVersion(nodePath string) (string, error) {
	cmd := exec.Command(nodePath, "--version")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get node version: %w", err)
	}

	version := strings.TrimSpace(string(output))
	return version, nil
}

// FindServerPath finds the Napp Trapp server directory.
// Returns the path to the server directory (not the index.js file).
func FindServerPath() (string, error) {
	indexPath, err := FindNappTrappServer()
	if err != nil {
		return "", err
	}
	// Return the server directory, not the index.js file
	return filepath.Dir(filepath.Dir(indexPath)), nil
}

// FindNappTrappServer attempts to locate the napptrapp server.
// Search order:
// 1. Configured server_path in config.yaml
// 2. ../server/src/index.js (relative to nappctl binary)
// 3. Current working directory's server/src/index.js
// 4. ~/.napptrapp/server/src/index.js (global installation)
// If found via search, the path is saved to config for future use.
func FindNappTrappServer() (string, error) {
	// Import here to avoid circular dependency
	configModule := "github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	_ = configModule // Avoid unused import error

	// Try to load from config first
	var configuredPath string
	dataDir, err := resolveDataDirLocal()
	if err == nil {
		configPath := filepath.Join(dataDir, "config.yaml")
		if data, err := os.ReadFile(configPath); err == nil {
			// Simple YAML parsing for server_path
			lines := strings.Split(string(data), "\n")
			for _, line := range lines {
				if strings.HasPrefix(strings.TrimSpace(line), "server_path:") {
					parts := strings.SplitN(line, ":", 2)
					if len(parts) == 2 {
						configuredPath = strings.TrimSpace(parts[1])
						// Remove quotes if present
						configuredPath = strings.Trim(configuredPath, "\"'")
						break
					}
				}
			}
		}
	}

	// Validate configured path
	if configuredPath != "" {
		if _, err := os.Stat(configuredPath); err == nil {
			return configuredPath, nil
		}
	}

	// Search for server in common locations
	var foundPath string

	// Try relative to executable
	exePath, err := os.Executable()
	if err == nil {
		serverPath := filepath.Join(filepath.Dir(exePath), "..", "server", "src", "index.js")
		if _, err := os.Stat(serverPath); err == nil {
			absPath, _ := filepath.Abs(serverPath)
			foundPath = absPath
		}
	}

	// Try current working directory
	if foundPath == "" {
		cwd, err := os.Getwd()
		if err == nil {
			serverPath := filepath.Join(cwd, "server", "src", "index.js")
			if _, err := os.Stat(serverPath); err == nil {
				absPath, _ := filepath.Abs(serverPath)
				foundPath = absPath
			}
		}
	}

	// Try home directory installation
	if foundPath == "" {
		homeDir, err := os.UserHomeDir()
		if err == nil {
			serverPath := filepath.Join(homeDir, ".napptrapp", "server", "src", "index.js")
			if _, err := os.Stat(serverPath); err == nil {
				foundPath = serverPath
			}
		}
	}

	if foundPath == "" {
		return "", fmt.Errorf("napptrapp server not found (expected server/src/index.js)")
	}

	// Save the found path to config for future use
	if dataDir != "" {
		saveServerPathToConfig(dataDir, foundPath)
	}

	return foundPath, nil
}

// resolveDataDirLocal is a local copy to avoid circular import
func resolveDataDirLocal() (string, error) {
	if dir := os.Getenv("NAPPTRAPP_DATA_DIR"); dir != "" {
		return filepath.Abs(dir)
	}
	home, err := os.UserHomeDir()
	if err == nil {
		return filepath.Join(home, ".napptrapp"), nil
	}
	return filepath.Abs("./.napp-trapp-data")
}

// saveServerPathToConfig saves the server path to config file
func saveServerPathToConfig(dataDir, serverPath string) {
	configPath := filepath.Join(dataDir, "config.yaml")

	// Ensure data dir exists
	os.MkdirAll(dataDir, 0755)

	// Read existing config
	var existingLines []string
	if data, err := os.ReadFile(configPath); err == nil {
		existingLines = strings.Split(string(data), "\n")
	}

	// Check if server_path already exists
	hasServerPath := false
	for i, line := range existingLines {
		if strings.HasPrefix(strings.TrimSpace(line), "server_path:") {
			existingLines[i] = fmt.Sprintf("server_path: %s", serverPath)
			hasServerPath = true
			break
		}
	}

	// Add server_path if not present
	if !hasServerPath {
		existingLines = append(existingLines, fmt.Sprintf("server_path: %s", serverPath))
	}

	// Write back
	content := strings.Join(existingLines, "\n")
	os.WriteFile(configPath, []byte(content), 0644)
}

// CheckServerDependencies verifies that Node.js modules are installed.
func CheckServerDependencies(serverPath string) error {
	serverDir := filepath.Dir(filepath.Dir(serverPath)) // Go up to server/ directory
	nodeModules := filepath.Join(serverDir, "node_modules")

	if _, err := os.Stat(nodeModules); os.IsNotExist(err) {
		return fmt.Errorf("node_modules not found at %s. Run 'npm install' in the server directory", serverDir)
	}

	return nil
}
