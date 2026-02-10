package main

import (
	"fmt"
	"os"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/spf13/cobra"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

var rootCmd = &cobra.Command{
	Use:   "nappctl",
	Short: "Napp Trapp CLI - Control your mobile IDE server",
	Long: `nappctl is a command-line interface for managing the Napp Trapp server.

Napp Trapp allows you to control Cursor IDE from your mobile device.
This CLI helps you start/stop the server, manage authentication, and configure settings.`,
	Version: fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, date),
}

func init() {
	// Global flags
	rootCmd.PersistentFlags().StringP("data-dir", "d", "", "Data directory (overrides NAPPTRAPP_DATA_DIR)")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "Enable verbose output")

	// Add subcommands
	rootCmd.AddCommand(serverCmd)
	rootCmd.AddCommand(authCmd)
	rootCmd.AddCommand(prereqCmd)
	rootCmd.AddCommand(dataCmd)
	rootCmd.AddCommand(configCmd)
	rootCmd.AddCommand(doctorCmd)
}

func main() {
	// Override data directory if flag is set
	if dataDir, _ := rootCmd.Flags().GetString("data-dir"); dataDir != "" {
		os.Setenv("NAPPTRAPP_DATA_DIR", dataDir)
	}

	// Ensure data directory exists
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to resolve data directory: %v\n", err)
		os.Exit(1)
	}
	if err := config.EnsureDataDir(dataDir); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to initialize data directory: %v\n", err)
		os.Exit(1)
	}

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
