package main

import (
	"fmt"
	"os"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage configuration",
	Long:  "View and modify Napp Trapp configuration settings.",
}

var configShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show current configuration",
	Long:  "Display all configuration values.",
	Run: func(cmd *cobra.Command, args []string) {
		cfg, err := config.Load()
		if err != nil {
			color.Red("Error loading config: %v", err)
			os.Exit(1)
		}

		table := tablewriter.NewWriter(os.Stdout)
		table.SetHeader([]string{"Setting", "Value"})
		table.SetBorder(false)
		table.SetColumnSeparator("")

		table.Append([]string{"Port", fmt.Sprintf("%d", cfg.Port)})
		table.Append([]string{"Host", cfg.Host})
		table.Append([]string{"Data Directory", cfg.DataDir})
		table.Append([]string{"Server URL", cfg.GetServerURL()})

		if cfg.AuthToken != "" {
			table.Append([]string{"Auth Token", "***" + cfg.AuthToken[len(cfg.AuthToken)-4:]})
		} else {
			table.Append([]string{"Auth Token", "(not set)"})
		}

		table.Render()
	},
}

var configSetCmd = &cobra.Command{
	Use:   "set <key> <value>",
	Short: "Set a configuration value",
	Long:  "Set a configuration value. Available keys: port, host",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		key := args[0]
		value := args[1]

		cfg, err := config.Load()
		if err != nil {
			color.Red("Error loading config: %v", err)
			os.Exit(1)
		}

		switch key {
		case "port":
			var port int
			if _, err := fmt.Sscanf(value, "%d", &port); err != nil {
				color.Red("Invalid port number: %s", value)
				os.Exit(1)
			}
			if port < 1 || port > 65535 {
				color.Red("Port must be between 1 and 65535")
				os.Exit(1)
			}
			cfg.Port = port

		case "host":
			cfg.Host = value

		default:
			color.Red("Unknown config key: %s", key)
			fmt.Println("Available keys: port, host")
			os.Exit(1)
		}

		if err := config.Save(cfg); err != nil {
			color.Red("Error saving config: %v", err)
			os.Exit(1)
		}

		color.Green("✓ Configuration updated")
		fmt.Printf("%s = %s\n", key, value)
	},
}

var configGetCmd = &cobra.Command{
	Use:   "get <key>",
	Short: "Get a configuration value",
	Long:  "Get a specific configuration value. Available keys: port, host, data-dir, server-url",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		key := args[0]

		cfg, err := config.Load()
		if err != nil {
			color.Red("Error loading config: %v", err)
			os.Exit(1)
		}

		switch key {
		case "port":
			fmt.Println(cfg.Port)
		case "host":
			fmt.Println(cfg.Host)
		case "data-dir":
			fmt.Println(cfg.DataDir)
		case "server-url":
			fmt.Println(cfg.GetServerURL())
		case "auth-token":
			if cfg.AuthToken != "" {
				fmt.Println(cfg.AuthToken)
			} else {
				color.Yellow("(not set)")
			}
		default:
			color.Red("Unknown config key: %s", key)
			fmt.Println("Available keys: port, host, data-dir, server-url, auth-token")
			os.Exit(1)
		}
	},
}

var configResetCmd = &cobra.Command{
	Use:   "reset",
	Short: "Reset configuration to defaults",
	Long:  "Reset all configuration values to their defaults.",
	Run: func(cmd *cobra.Command, args []string) {
		force, _ := cmd.Flags().GetBool("force")

		if !force {
			fmt.Println("This will reset all configuration to defaults.")
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

		// Remove config file
		configPath := fmt.Sprintf("%s/config.yaml", dataDir)
		if err := os.Remove(configPath); err != nil && !os.IsNotExist(err) {
			color.Red("Error removing config file: %v", err)
			os.Exit(1)
		}

		color.Green("✓ Configuration reset to defaults")
	},
}

var configPathCmd = &cobra.Command{
	Use:   "path",
	Short: "Show config file path",
	Long:  "Display the path to the configuration file.",
	Run: func(cmd *cobra.Command, args []string) {
		dataDir, err := config.GetDataDir()
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		configPath := fmt.Sprintf("%s/config.yaml", dataDir)
		fmt.Println(configPath)

		if _, err := os.Stat(configPath); os.IsNotExist(err) {
			color.Yellow("(file does not exist yet)")
		}
	},
}

func init() {
	configResetCmd.Flags().BoolP("force", "f", false, "Skip confirmation")

	configCmd.AddCommand(configShowCmd)
	configCmd.AddCommand(configSetCmd)
	configCmd.AddCommand(configGetCmd)
	configCmd.AddCommand(configResetCmd)
	configCmd.AddCommand(configPathCmd)
}
