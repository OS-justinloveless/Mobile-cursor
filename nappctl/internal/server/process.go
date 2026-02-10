package server

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/OS-justinloveless/Napp-Trapp/nappctl/pkg/pidfile"
)

// StartServer starts the Napp Trapp server
func StartServer(port int, token string, foreground bool) error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return fmt.Errorf("failed to resolve data directory: %w", err)
	}

	// Check if server is already running
	pidPath := config.GetPIDPath(dataDir)
	if pidfile.IsRunning(pidPath) {
		return fmt.Errorf("server is already running")
	}

	// Find Node.js binary
	nodePath, err := exec.LookPath("node")
	if err != nil {
		return fmt.Errorf("node not found in PATH: %w", err)
	}

	// Find server path
	serverPath, err := FindServerPath()
	if err != nil {
		return fmt.Errorf("failed to find server: %w", err)
	}

	// Build command
	entryPoint := fmt.Sprintf("%s/src/index.js", serverPath)
	cmd := exec.Command(nodePath, entryPoint)

	// Set environment variables
	cmd.Env = append(os.Environ(),
		fmt.Sprintf("PORT=%d", port),
		fmt.Sprintf("NAPPTRAPP_DATA_DIR=%s", dataDir),
		"NAPPTRAPP_CLI=true",
	)

	if token != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("AUTH_TOKEN=%s", token))
	}

	// Configure stdio
	if foreground {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
	} else {
		// Daemon mode: redirect to log file
		logPath := fmt.Sprintf("%s/logs/nappctl.log", dataDir)
		logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
		if err != nil {
			return fmt.Errorf("failed to open log file: %w", err)
		}
		cmd.Stdout = logFile
		cmd.Stderr = logFile

		// Detach process
		cmd.SysProcAttr = &syscall.SysProcAttr{
			Setpgid: true,
		}
	}

	// Start the server
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start server: %w", err)
	}

	pid := cmd.Process.Pid

	if foreground {
		// Wait for process in foreground mode
		return cmd.Wait()
	}

	// Daemon mode: write PID file and return
	if err := pidfile.Write(pidPath, pid, port, dataDir); err != nil {
		// Kill the process if we can't write PID file
		cmd.Process.Kill()
		return fmt.Errorf("failed to write PID file: %w", err)
	}

	fmt.Printf("Server started successfully (PID: %d, Port: %d)\n", pid, port)
	fmt.Printf("Data directory: %s\n", dataDir)
	fmt.Printf("Logs: %s/logs/nappctl.log\n", dataDir)

	return nil
}

// StopServer stops the running server
func StopServer(force bool) error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return fmt.Errorf("failed to resolve data directory: %w", err)
	}

	pidPath := config.GetPIDPath(dataDir)
	pidInfo, err := pidfile.Read(pidPath)
	if err != nil {
		return fmt.Errorf("server is not running or PID file not found: %w", err)
	}

	process, err := os.FindProcess(pidInfo.PID)
	if err != nil {
		// Clean up stale PID file
		os.Remove(pidPath)
		return fmt.Errorf("process not found: %w", err)
	}

	// Send SIGTERM for graceful shutdown
	if err := process.Signal(syscall.SIGTERM); err != nil {
		os.Remove(pidPath)
		return fmt.Errorf("failed to send SIGTERM: %w", err)
	}

	// Wait for process to exit
	timeout := 30 * time.Second
	if force {
		timeout = 5 * time.Second
	}

	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	timer := time.NewTimer(timeout)
	defer timer.Stop()

	for {
		select {
		case <-timer.C:
			// Timeout reached
			if force {
				// Send SIGKILL
				fmt.Println("Timeout reached, sending SIGKILL...")
				if err := process.Signal(syscall.SIGKILL); err != nil {
					return fmt.Errorf("failed to send SIGKILL: %w", err)
				}
				time.Sleep(500 * time.Millisecond)
			} else {
				return fmt.Errorf("timeout waiting for server to stop (use --force for SIGKILL)")
			}
		case <-ticker.C:
			// Check if process is still running
			if err := process.Signal(syscall.Signal(0)); err != nil {
				// Process has exited
				os.Remove(pidPath)
				fmt.Println("Server stopped successfully")
				return nil
			}
		}
	}
}

// GetServerStatus returns the server status
func GetServerStatus() (*pidfile.PIDInfo, bool, error) {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return nil, false, err
	}

	pidPath := config.GetPIDPath(dataDir)
	pidInfo, err := pidfile.Read(pidPath)
	if err != nil {
		return nil, false, nil
	}

	// Check if process is actually running
	process, err := os.FindProcess(pidInfo.PID)
	if err != nil {
		return pidInfo, false, nil
	}

	// Send signal 0 to check if process exists
	if err := process.Signal(syscall.Signal(0)); err != nil {
		return pidInfo, false, nil
	}

	return pidInfo, true, nil
}

// RestartServer restarts the server
func RestartServer(port int, token string, foreground bool) error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}

	// Stop if running
	if pidfile.IsRunning(config.GetPIDPath(dataDir)) {
		fmt.Println("Stopping server...")
		if err := StopServer(false); err != nil {
			return fmt.Errorf("failed to stop server: %w", err)
		}
		time.Sleep(1 * time.Second)
	}

	// Start server
	fmt.Println("Starting server...")
	return StartServer(port, token, foreground)
}
