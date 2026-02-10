package main

import (
	"fmt"
	"os"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/auth"
	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

var authCmd = &cobra.Command{
	Use:   "auth",
	Short: "Manage authentication",
	Long:  "Generate, view, and manage authentication tokens for the Napp Trapp server.",
}

var authShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show current token",
	Long:  "Display the current authentication token.",
	Run: func(cmd *cobra.Command, args []string) {
		qr, _ := cmd.Flags().GetBool("qr")

		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		authPath := config.GetAuthPath(dataDir)

		token, err := auth.GetToken(authPath)
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		if token == "" {
			color.Yellow("No token found. Generate one with: nappctl auth generate")
			os.Exit(1)
		}

		fmt.Println("Token:", token)

		if qr {
			// Load config to get server URL
			cfg, err := config.Load()
			if err != nil {
				color.Red("Error loading config: %v", err)
				os.Exit(1)
			}

			url := fmt.Sprintf("%s?token=%s", cfg.GetServerURL(), token)
			fmt.Println("\nQR Code:")
			auth.PrintQRCode(url)
		}
	},
}

var authGenerateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate new token",
	Long:  "Generate a new authentication token and save it.",
	Run: func(cmd *cobra.Command, args []string) {
		force, _ := cmd.Flags().GetBool("force")
		qr, _ := cmd.Flags().GetBool("qr")

		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		authPath := config.GetAuthPath(dataDir)

		// Check if token already exists
		if auth.AuthFileExists(authPath) && !force {
			color.Yellow("Token already exists. Use --force to overwrite.")
			os.Exit(1)
		}

		token, err := auth.CreateAndSaveToken(authPath)
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		color.Green("✓ Token generated successfully")
		fmt.Println("Token:", token)
		fmt.Printf("Saved to: %s\n", authPath)

		if qr {
			// Load config to get server URL
			cfg, err := config.Load()
			if err != nil {
				color.Red("Error loading config: %v", err)
				os.Exit(1)
			}

			url := fmt.Sprintf("%s?token=%s", cfg.GetServerURL(), token)
			fmt.Println("\nQR Code:")
			auth.PrintQRCode(url)
		}
	},
}

var authRotateCmd = &cobra.Command{
	Use:   "rotate",
	Short: "Rotate token",
	Long:  "Generate a new token and invalidate the old one.",
	Run: func(cmd *cobra.Command, args []string) {
		qr, _ := cmd.Flags().GetBool("qr")

		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		authPath := config.GetAuthPath(dataDir)

		token, err := auth.RotateToken(authPath)
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		color.Green("✓ Token rotated successfully")
		fmt.Println("New Token:", token)

		if qr {
			// Load config to get server URL
			cfg, err := config.Load()
			if err != nil {
				color.Red("Error loading config: %v", err)
				os.Exit(1)
			}

			url := fmt.Sprintf("%s?token=%s", cfg.GetServerURL(), token)
			fmt.Println("\nQR Code:")
			auth.PrintQRCode(url)
		}
	},
}

var authDeleteCmd = &cobra.Command{
	Use:   "delete",
	Short: "Delete token",
	Long:  "Remove the authentication token file.",
	Run: func(cmd *cobra.Command, args []string) {
		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		authPath := config.GetAuthPath(dataDir)

		if !auth.AuthFileExists(authPath) {
			color.Yellow("No token file found")
			os.Exit(0)
		}

		if err := auth.DeleteAuthFile(authPath); err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		color.Green("✓ Token deleted")
	},
}

var authQRCmd = &cobra.Command{
	Use:   "qr",
	Short: "Show token as QR code",
	Long:  "Display the authentication token as a QR code for easy scanning.",
	Run: func(cmd *cobra.Command, args []string) {
		dataDir, err := config.ResolveDataDir()
		if err != nil {
			color.Red("Error resolving data directory: %v", err)
			os.Exit(1)
		}
		authPath := config.GetAuthPath(dataDir)

		token, err := auth.GetToken(authPath)
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		if token == "" {
			color.Yellow("No token found. Generate one with: nappctl auth generate")
			os.Exit(1)
		}

		// Load config to get server URL
		cfg, err := config.Load()
		if err != nil {
			color.Red("Error loading config: %v", err)
			os.Exit(1)
		}

		// Use local network IP instead of localhost for mobile access
		host := cfg.Host
		if host == "localhost" || host == "127.0.0.1" || host == "" {
			if localIP := auth.GetLocalIP(); localIP != "" {
				host = localIP
				color.Yellow("Using local IP %s instead of localhost for mobile access", localIP)
			}
		}

		url := fmt.Sprintf("http://%s:%d?token=%s", host, cfg.Port, token)
		fmt.Println("\nServer URL with token:")
		fmt.Println(url)
		fmt.Println("\nQR Code:")
		auth.PrintQRCode(url)
	},
}

func init() {
	authShowCmd.Flags().BoolP("qr", "q", false, "Show QR code")
	authGenerateCmd.Flags().BoolP("force", "f", false, "Overwrite existing token")
	authGenerateCmd.Flags().BoolP("qr", "q", false, "Show QR code")
	authRotateCmd.Flags().BoolP("qr", "q", false, "Show QR code")

	authCmd.AddCommand(authShowCmd)
	authCmd.AddCommand(authGenerateCmd)
	authCmd.AddCommand(authRotateCmd)
	authCmd.AddCommand(authDeleteCmd)
	authCmd.AddCommand(authQRCmd)
}
