package pidfile

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// PIDInfo contains information about a running server process
type PIDInfo struct {
	PID       int       `json:"pid"`
	Port      int       `json:"port"`
	StartedAt time.Time `json:"started_at"`
	DataDir   string    `json:"data_dir"`
}

// Write creates a PID file with the given process information.
func Write(path string, pid int, port int, dataDir string) error {
	info := PIDInfo{
		PID:       pid,
		Port:      port,
		StartedAt: time.Now(),
		DataDir:   dataDir,
	}

	data, err := json.MarshalIndent(info, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal PID info: %w", err)
	}

	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("failed to write PID file: %w", err)
	}
	return nil
}

// Read reads the PID information from a PID file.
func Read(path string) (*PIDInfo, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("PID file not found")
		}
		return nil, fmt.Errorf("failed to read PID file: %w", err)
	}

	// Try JSON format first
	var info PIDInfo
	if err := json.Unmarshal(data, &info); err == nil {
		return &info, nil
	}

	// Fall back to legacy format (just PID number)
	pidStr := strings.TrimSpace(string(data))
	pid, err := strconv.Atoi(pidStr)
	if err != nil {
		return nil, fmt.Errorf("invalid PID file format: %w", err)
	}

	return &PIDInfo{
		PID:  pid,
		Port: 3847, // Default port
	}, nil
}

// Remove deletes a PID file.
func Remove(path string) error {
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to remove PID file: %w", err)
	}
	return nil
}

// IsProcessRunning checks if a process with the given PID is running.
func IsProcessRunning(pid int) bool {
	if pid <= 0 {
		return false
	}

	// Send signal 0 to check if process exists
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}

	// On Unix, FindProcess always succeeds, so we need to send a signal
	err = process.Signal(syscall.Signal(0))
	return err == nil
}

// IsRunning checks if a server is running based on PID file.
func IsRunning(path string) bool {
	info, err := Read(path)
	if err != nil {
		return false
	}
	return IsProcessRunning(info.PID)
}

// GetRunningPID reads the PID file and checks if the process is running.
// Returns the PID if running, 0 otherwise.
func GetRunningPID(path string) (int, error) {
	info, err := Read(path)
	if err != nil {
		// If file doesn't exist, that's fine - no server is running
		if os.IsNotExist(err) || strings.Contains(err.Error(), "PID file not found") {
			return 0, nil
		}
		return 0, err
	}

	if info.PID == 0 {
		return 0, nil
	}

	if !IsProcessRunning(info.PID) {
		// PID file exists but process is not running - clean up
		if err := Remove(path); err != nil {
			return 0, fmt.Errorf("failed to clean up stale PID file: %w", err)
		}
		return 0, nil
	}

	return info.PID, nil
}
