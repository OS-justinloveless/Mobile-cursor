package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
	"github.com/spf13/cobra"
)

var dataCmd = &cobra.Command{
	Use:   "data",
	Short: "Manage data directory",
	Long:  "View and manage the Napp Trapp data directory.",
}

var dataInfoCmd = &cobra.Command{
	Use:   "info",
	Short: "Show data directory info",
	Long:  "Display information about the data directory and its contents.",
	Run: func(cmd *cobra.Command, args []string) {
		dataDir, err := config.GetDataDir()
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		fmt.Println("Data Directory:", dataDir)

		// Check if it exists
		if info, err := os.Stat(dataDir); err == nil {
			fmt.Printf("Exists: %s\n", color.GreenString("Yes"))
			fmt.Printf("Permissions: %s\n", info.Mode())

			// Calculate size
			size, err := getDirSize(dataDir)
			if err == nil {
				fmt.Printf("Size: %s\n", formatBytes(size))
			}

			// Show subdirectories
			fmt.Println("\nContents:")
			showDataDirContents(dataDir)
		} else {
			fmt.Printf("Exists: %s\n", color.RedString("No"))
		}
	},
}

var dataCleanCmd = &cobra.Command{
	Use:   "clean",
	Short: "Clean up data directory",
	Long:  "Remove old logs and chat data based on retention policies.",
	Run: func(cmd *cobra.Command, args []string) {
		force, _ := cmd.Flags().GetBool("force")

		if !force {
			fmt.Println("This will remove old logs and chat data.")
			fmt.Print("Continue? (y/N): ")
			var response string
			fmt.Scanln(&response)
			if response != "y" && response != "Y" {
				color.Yellow("Cancelled")
				os.Exit(0)
			}
		}

		dataDir, err := config.GetDataDir()
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		// Clean logs (keep last 100 lines per log file)
		logsPath := config.GetLogsPath(dataDir)
		if err := cleanLogs(logsPath); err != nil {
			color.Red("Error cleaning logs: %v", err)
		} else {
			color.Green("✓ Logs cleaned")
		}

		fmt.Printf("Data directory: %s\n", dataDir)
	},
}

var dataPathCmd = &cobra.Command{
	Use:   "path",
	Short: "Show data directory path",
	Long:  "Display the path to the data directory.",
	Run: func(cmd *cobra.Command, args []string) {
		dataDir, err := config.GetDataDir()
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}
		fmt.Println(dataDir)
	},
}

var dataResetCmd = &cobra.Command{
	Use:   "reset",
	Short: "Reset data directory",
	Long:  "Remove all data (auth, logs, chats) and reinitialize.",
	Run: func(cmd *cobra.Command, args []string) {
		force, _ := cmd.Flags().GetBool("force")

		if !force {
			color.Red("WARNING: This will delete ALL data including auth tokens!")
			fmt.Print("Are you sure? (y/N): ")
			var response string
			fmt.Scanln(&response)
			if response != "y" && response != "Y" {
				color.Yellow("Cancelled")
				os.Exit(0)
			}
		}

		dataDir, err := config.GetDataDir()
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		// Remove entire data directory
		if err := os.RemoveAll(dataDir); err != nil {
			color.Red("Error removing data directory: %v", err)
			os.Exit(1)
		}

		// Recreate empty directory
		if err := config.EnsureDataDir(dataDir); err != nil {
			color.Red("Error creating data directory: %v", err)
			os.Exit(1)
		}

		color.Green("✓ Data directory reset")
		fmt.Printf("Path: %s\n", dataDir)
	},
}

func init() {
	dataCleanCmd.Flags().BoolP("force", "f", false, "Skip confirmation")
	dataResetCmd.Flags().BoolP("force", "f", false, "Skip confirmation")

	dataCmd.AddCommand(dataInfoCmd)
	dataCmd.AddCommand(dataCleanCmd)
	dataCmd.AddCommand(dataPathCmd)
	dataCmd.AddCommand(dataResetCmd)
}

func showDataDirContents(dataDir string) {
	entries, err := os.ReadDir(dataDir)
	if err != nil {
		color.Red("Error reading directory: %v", err)
		return
	}

	if len(entries) == 0 {
		fmt.Println("  (empty)")
		return
	}

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Name", "Type", "Size"})
	table.SetBorder(false)
	table.SetColumnSeparator("")

	for _, entry := range entries {
		entryType := "file"
		if entry.IsDir() {
			entryType = "dir"
		}

		info, err := entry.Info()
		size := "-"
		if err == nil && !entry.IsDir() {
			size = formatBytes(info.Size())
		} else if err == nil && entry.IsDir() {
			dirSize, err := getDirSize(filepath.Join(dataDir, entry.Name()))
			if err == nil {
				size = formatBytes(dirSize)
			}
		}

		table.Append([]string{entry.Name(), entryType, size})
	}

	table.Render()
}

func getDirSize(path string) (int64, error) {
	var size int64
	err := filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return nil
	})
	return size, err
}

func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

func cleanLogs(logsPath string) error {
	if _, err := os.Stat(logsPath); os.IsNotExist(err) {
		return nil // No logs directory
	}

	entries, err := os.ReadDir(logsPath)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		logFile := filepath.Join(logsPath, entry.Name())

		// Read last 100 lines
		// For simplicity, we'll truncate large files
		info, err := entry.Info()
		if err != nil {
			continue
		}

		// If file is larger than 1MB, truncate to last 100KB
		if info.Size() > 1024*1024 {
			content, err := os.ReadFile(logFile)
			if err != nil {
				continue
			}

			// Keep last 100KB
			if len(content) > 100*1024 {
				truncated := content[len(content)-100*1024:]
				os.WriteFile(logFile, truncated, 0644)
			}
		}
	}

	return nil
}
