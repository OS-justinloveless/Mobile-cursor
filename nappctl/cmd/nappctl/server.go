package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/server"
	"github.com/OS-justinloveless/Napp-Trapp/nappctl/pkg/pidfile"
	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

var serverCmd = &cobra.Command{
	Use:   "server",
	Short: "Manage the Napp Trapp server",
	Long:  "Start, stop, restart, and check status of the Napp Trapp server.",
}

var serverStartCmd = &cobra.Command{
	Use:   "start",
	Short: "Start the server",
	Long:  "Start the Napp Trapp server in the background.",
	Run: func(cmd *cobra.Command, args []string) {
		port, _ := cmd.Flags().GetInt("port")
		detach, _ := cmd.Flags().GetBool("detach")

		if err := startServer(port, detach); err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}
	},
}

var serverStopCmd = &cobra.Command{
	Use:   "stop",
	Short: "Stop the server",
	Long:  "Stop the running Napp Trapp server.",
	Run: func(cmd *cobra.Command, args []string) {
		if err := stopServer(); err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}
	},
}

var serverRestartCmd = &cobra.Command{
	Use:   "restart",
	Short: "Restart the server",
	Long:  "Stop and start the Napp Trapp server.",
	Run: func(cmd *cobra.Command, args []string) {
		port, _ := cmd.Flags().GetInt("port")

		// Try to stop existing server
		stopServer() // Ignore error if not running

		// Wait a bit for clean shutdown
		time.Sleep(1 * time.Second)

		// Start server
		if err := startServer(port, true); err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}
	},
}

var serverStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Check server status",
	Long:  "Check if the Napp Trapp server is running.",
	Run: func(cmd *cobra.Command, args []string) {
		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		pidPath := config.GetPidPath(dataDir)

		pid, err := pidfile.GetRunningPID(pidPath)
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		if pid == 0 {
			color.Yellow("Server is not running")
			os.Exit(1)
		}

		color.Green("Server is running (PID: %d)", pid)

		// Try to get config for URL
		cfg, err := config.Load()
		if err == nil {
			fmt.Printf("URL: %s\n", cfg.GetServerURL())
		}
	},
}

var serverLogsCmd = &cobra.Command{
	Use:   "logs",
	Short: "View server logs",
	Long:  "Display the server log file.",
	Run: func(cmd *cobra.Command, args []string) {
		follow, _ := cmd.Flags().GetBool("follow")
		lines, _ := cmd.Flags().GetInt("lines")

		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		logsPath := config.GetLogsPath(dataDir)

		logFile := filepath.Join(logsPath, "server.log")
		if _, err := os.Stat(logFile); os.IsNotExist(err) {
			color.Yellow("No log file found at %s", logFile)
			os.Exit(1)
		}

		if follow {
			// Use tail -f for following
			cmd := exec.Command("tail", "-f", "-n", fmt.Sprintf("%d", lines), logFile)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				color.Red("Error following logs: %v", err)
				os.Exit(1)
			}
		} else {
			// Just show last N lines
			cmd := exec.Command("tail", "-n", fmt.Sprintf("%d", lines), logFile)
			output, err := cmd.Output()
			if err != nil {
				color.Red("Error reading logs: %v", err)
				os.Exit(1)
			}
			fmt.Print(string(output))
		}
	},
}

func init() {
	serverStartCmd.Flags().IntP("port", "p", 3847, "Server port")
	serverStartCmd.Flags().BoolP("detach", "D", true, "Run in background")

	serverRestartCmd.Flags().IntP("port", "p", 3847, "Server port")

	serverLogsCmd.Flags().BoolP("follow", "f", false, "Follow log output")
	serverLogsCmd.Flags().IntP("lines", "n", 50, "Number of lines to show")

	serverCmd.AddCommand(serverStartCmd)
	serverCmd.AddCommand(serverStopCmd)
	serverCmd.AddCommand(serverRestartCmd)
	serverCmd.AddCommand(serverStatusCmd)
	serverCmd.AddCommand(serverLogsCmd)
}

func startServer(port int, detach bool) error {
	// Check if already running
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}
	pidPath := config.GetPidPath(dataDir)

	existingPID, err := pidfile.GetRunningPID(pidPath)
	if err != nil {
		return err
	}

	if existingPID != 0 {
		return fmt.Errorf("server is already running (PID: %d)", existingPID)
	}

	// Find Node.js
	nodePath, err := server.FindNodeJS()
	if err != nil {
		return fmt.Errorf("Node.js not found: %w", err)
	}

	// Find server script
	serverPath, err := server.FindNappTrappServer()
	if err != nil {
		return fmt.Errorf("server script not found: %w", err)
	}

	// Check dependencies
	if err := server.CheckServerDependencies(serverPath); err != nil {
		return err
	}

	// Prepare environment and log files
	env := os.Environ()
	env = append(env, fmt.Sprintf("PORT=%d", port))
	env = append(env, fmt.Sprintf("NAPPTRAPP_DATA_DIR=%s", dataDir))

	// Prepare log files
	logsPath := config.GetLogsPath(dataDir)
	os.MkdirAll(logsPath, 0755)
	logFile := filepath.Join(logsPath, "server.log")

	// Start server
	cmd := exec.Command(nodePath, serverPath)
	cmd.Env = env

	if detach {
		// Redirect output to log file
		outFile, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return fmt.Errorf("failed to open log file: %w", err)
		}
		defer outFile.Close()

		cmd.Stdout = outFile
		cmd.Stderr = outFile

		// Start in background
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("failed to start server: %w", err)
		}

		// Write PID file
		if err := pidfile.Write(pidPath, cmd.Process.Pid, port, dataDir); err != nil {
			return fmt.Errorf("failed to write PID file: %w", err)
		}

		color.Green("✓ Server started (PID: %d)", cmd.Process.Pid)
		fmt.Printf("Port: %d\n", port)
		fmt.Printf("Logs: %s\n", logFile)
	} else {
		// Run in foreground
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		color.Green("Starting server on port %d...", port)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("server exited with error: %w", err)
		}
	}

	return nil
}

func stopServer() error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}
	pidPath := config.GetPidPath(dataDir)

	pid, err := pidfile.GetRunningPID(pidPath)
	if err != nil {
		return err
	}

	if pid == 0 {
		return fmt.Errorf("server is not running")
	}

	// Find process
	process, err := os.FindProcess(pid)
	if err != nil {
		return fmt.Errorf("failed to find process: %w", err)
	}

	// Send SIGTERM
	if err := process.Signal(os.Interrupt); err != nil {
		return fmt.Errorf("failed to stop server: %w", err)
	}

	// Wait for process to exit (with timeout)
	timeout := time.After(5 * time.Second)
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			// Force kill if still running
			process.Kill()
			pidfile.Remove(pidPath)
			return fmt.Errorf("server did not stop gracefully, killed")
		case <-ticker.C:
			if !pidfile.IsProcessRunning(pid) {
				pidfile.Remove(pidPath)
				color.Green("✓ Server stopped")
				return nil
			}
		}
	}
}
