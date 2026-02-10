package config

import (
	"os"
	"path/filepath"
)

// ResolveDataDir returns the data directory path
func ResolveDataDir() (string, error) {
	if dir := os.Getenv("NAPPTRAPP_DATA_DIR"); dir != "" {
		return filepath.Abs(dir)
	}
	home, err := os.UserHomeDir()
	if err == nil {
		return filepath.Join(home, ".napptrapp"), nil
	}
	return filepath.Abs("./.napp-trapp-data")
}

// EnsureDataDir ensures the data directory exists
func EnsureDataDir(dataDir string) error {
	return os.MkdirAll(filepath.Join(dataDir, "logs"), 0755)
}

// GetAuthPath returns the path to auth.json
func GetAuthPath(dataDir string) string {
	return filepath.Join(dataDir, "auth.json")
}

// GetDBPath returns the path to chat persistence database
func GetDBPath(dataDir string) string {
	return filepath.Join(dataDir, "chat-persistence.db")
}

// GetPIDPath returns the path to server PID file
func GetPIDPath(dataDir string) string {
	return filepath.Join(dataDir, "server.pid")
}

// GetLogDir returns the path to logs directory
func GetLogDir(dataDir string) string {
	return filepath.Join(dataDir, "logs")
}

// GetDataDir is an alias for ResolveDataDir for backward compatibility
func GetDataDir() (string, error) {
	return ResolveDataDir()
}

// GetLogsPath is an alias for GetLogDir
func GetLogsPath(dataDir string) string {
	return GetLogDir(dataDir)
}

// GetPidPath is a case-insensitive alias for GetPIDPath
func GetPidPath(dataDir string) string {
	return GetPIDPath(dataDir)
}
