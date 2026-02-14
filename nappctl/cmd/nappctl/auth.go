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
		tailscale, _ := cmd.Flags().GetBool("tailscale")

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

		if qr || tailscale {
			// Load config to get server URL
			cfg, err := config.Load()
			if err != nil {
				color.Red("Error loading config: %v", err)
				os.Exit(1)
			}

			if qr {
				url := fmt.Sprintf("%s?token=%s", cfg.GetServerURL(), token)
				fmt.Println("\nQR Code:")
				auth.PrintQRCode(url)
			}

			if tailscale {
				printTailscaleQR(cfg.Port, token)
			}
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
		tailscale, _ := cmd.Flags().GetBool("tailscale")

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

		if qr || tailscale {
			// Load config to get server URL
			cfg, err := config.Load()
			if err != nil {
				color.Red("Error loading config: %v", err)
				os.Exit(1)
			}

			if qr {
				url := fmt.Sprintf("%s?token=%s", cfg.GetServerURL(), token)
				fmt.Println("\nQR Code:")
				auth.PrintQRCode(url)
			}

			if tailscale {
				printTailscaleQR(cfg.Port, token)
			}
		}
	},
}

var authRotateCmd = &cobra.Command{
	Use:   "rotate",
	Short: "Rotate token",
	Long:  "Generate a new token and invalidate the old one.",
	Run: func(cmd *cobra.Command, args []string) {
		qr, _ := cmd.Flags().GetBool("qr")
		tailscale, _ := cmd.Flags().GetBool("tailscale")

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

		if qr || tailscale {
			// Load config to get server URL
			cfg, err := config.Load()
			if err != nil {
				color.Red("Error loading config: %v", err)
				os.Exit(1)
			}

			if qr {
				url := fmt.Sprintf("%s?token=%s", cfg.GetServerURL(), token)
				fmt.Println("\nQR Code:")
				auth.PrintQRCode(url)
			}

			if tailscale {
				printTailscaleQR(cfg.Port, token)
			}
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
	Long: `Display the authentication token as a QR code for easy scanning.

Use --tailscale (-t) to also display a QR code using your Tailscale IP,
allowing iOS devices on the same tailnet to connect.`,
	Run: func(cmd *cobra.Command, args []string) {
		tailscale, _ := cmd.Flags().GetBool("tailscale")

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
		fmt.Println("\nQR Code (Local Network):")
		auth.PrintQRCode(url)

		// Show Tailscale QR code if requested
		if tailscale {
			printTailscaleQR(cfg.Port, token)
		}
	},
}

func init() {
	authShowCmd.Flags().BoolP("qr", "q", false, "Show QR code")
	authShowCmd.Flags().BoolP("tailscale", "t", false, "Also show Tailscale QR code")
	authGenerateCmd.Flags().BoolP("force", "f", false, "Overwrite existing token")
	authGenerateCmd.Flags().BoolP("qr", "q", false, "Show QR code")
	authGenerateCmd.Flags().BoolP("tailscale", "t", false, "Also show Tailscale QR code")
	authRotateCmd.Flags().BoolP("qr", "q", false, "Show QR code")
	authRotateCmd.Flags().BoolP("tailscale", "t", false, "Also show Tailscale QR code")
	authQRCmd.Flags().BoolP("tailscale", "t", false, "Also show Tailscale QR code")

	authCmd.AddCommand(authShowCmd)
	authCmd.AddCommand(authGenerateCmd)
	authCmd.AddCommand(authRotateCmd)
	authCmd.AddCommand(authDeleteCmd)
	authCmd.AddCommand(authQRCmd)
}

// printTailscaleQR detects the Tailscale IP and prints a QR code for it.
func printTailscaleQR(port int, token string) {
	tsIP := auth.GetTailscaleIP()
	if tsIP == "" {
		color.Yellow("\nTailscale: No Tailscale interface detected.")
		fmt.Println("Make sure Tailscale is installed and connected (tailscale up).")
		return
	}

	tsURL := fmt.Sprintf("http://%s:%d?token=%s", tsIP, port, token)
	color.Cyan("\nTailscale IP: %s", tsIP)
	fmt.Println("Tailscale URL with token:")
	fmt.Println(tsURL)
	fmt.Println("\nQR Code (Tailscale):")
	auth.PrintQRCode(tsURL)
}
