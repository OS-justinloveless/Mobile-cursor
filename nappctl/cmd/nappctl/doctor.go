package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/server"
	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Check system setup and fix issues",
	Long:  "Diagnose and automatically fix common setup issues with Napp Trapp.",
	Run: func(cmd *cobra.Command, args []string) {
		fix, _ := cmd.Flags().GetBool("fix")

		color.Cyan("🔍 Running Napp Trapp diagnostics...\n")

		issues := 0
		fixed := 0

		// Check 1: Node.js installation
		if err := checkNodeJS(); err != nil {
			color.Red("✗ Node.js: %v", err)
			color.Yellow("  → Install Node.js from https://nodejs.org/")
			issues++
		} else {
			color.Green("✓ Node.js installed")
		}

		// Check 2: Server files
		if err := checkServerFiles(); err != nil {
			color.Red("✗ Server files: %v", err)
			if fix {
				color.Yellow("  → Cannot auto-fix: Server files must be present")
			}
			issues++
		} else {
			color.Green("✓ Server files found")
		}

		// Check 3: Server dependencies
		if err := checkServerDependencies(); err != nil {
			color.Red("✗ Server dependencies: %v", err)
			if fix {
				color.Yellow("  → Attempting to install dependencies...")
				if err := fixServerDependencies(); err != nil {
					color.Red("  ✗ Failed to install: %v", err)
					issues++
				} else {
					color.Green("  ✓ Dependencies installed")
					fixed++
				}
			} else {
				color.Yellow("  → Run 'nappctl doctor --fix' to install")
				issues++
			}
		} else {
			color.Green("✓ Server dependencies installed")
		}

		// Check 4: Data directory
		if err := checkDataDirectory(); err != nil {
			color.Red("✗ Data directory: %v", err)
			if fix {
				if err := fixDataDirectory(); err != nil {
					color.Red("  ✗ Failed to create: %v", err)
					issues++
				} else {
					color.Green("  ✓ Data directory created")
					fixed++
				}
			} else {
				color.Yellow("  → Run 'nappctl doctor --fix' to create")
				issues++
			}
		} else {
			color.Green("✓ Data directory exists")
		}

		// Check 5: Auth token
		if err := checkAuthToken(); err != nil {
			color.Red("✗ Auth token: %v", err)
			if fix {
				if err := fixAuthToken(); err != nil {
					color.Red("  ✗ Failed to generate: %v", err)
					issues++
				} else {
					color.Green("  ✓ Auth token generated")
					fixed++
				}
			} else {
				color.Yellow("  → Run 'nappctl doctor --fix' to generate")
				issues++
			}
		} else {
			color.Green("✓ Auth token exists")
		}

		// Check 6: Server path configuration
		if err := checkServerPathConfig(); err != nil {
			color.Red("✗ Server path: %v", err)
			if fix {
				if err := fixServerPathConfig(); err != nil {
					color.Red("  ✗ Failed to configure: %v", err)
					issues++
				} else {
					color.Green("  ✓ Server path configured")
					fixed++
				}
			} else {
				color.Yellow("  → Run 'nappctl doctor --fix' to configure")
				issues++
			}
		} else {
			color.Green("✓ Server path configured")
		}

		// Check 7: QR code package (optional)
		if err := checkQRCodePackage(); err != nil {
			color.Yellow("⚠ QR code package: %v", err)
			color.Yellow("  → Optional: Install with 'npm install -g qrcode' for better QR codes")
		} else {
			color.Green("✓ QR code package installed (optional)")
		}

		// Check 8: GOPATH/bin in PATH
		if err := checkGoPathInPath(); err != nil {
			color.Yellow("⚠ Go bin directory: %v", err)
			color.Yellow("  → Add to your ~/.zshrc or ~/.bashrc:")
			color.Cyan("    export PATH=\"$HOME/go/bin:$PATH\"")
		} else {
			color.Green("✓ Go bin directory in PATH")
		}

		// Summary
		fmt.Println()
		if issues == 0 {
			color.Green("✓ All checks passed! Your setup is ready.")
		} else if fix && fixed > 0 {
			color.Yellow("⚠ Fixed %d issue(s), %d remaining", fixed, issues-fixed)
			if issues-fixed > 0 {
				color.Yellow("  Some issues require manual intervention (see above)")
			}
		} else {
			color.Red("✗ Found %d issue(s)", issues)
			color.Yellow("  Run 'nappctl doctor --fix' to automatically fix what we can")
		}
	},
}

func init() {
	doctorCmd.Flags().BoolP("fix", "f", false, "Automatically fix issues when possible")
}

// Check functions

func checkNodeJS() error {
	nodePath, err := server.FindNodeJS()
	if err != nil {
		return err
	}

	version, err := server.GetNodeVersion(nodePath)
	if err != nil {
		return fmt.Errorf("found but cannot get version: %w", err)
	}

	// Just inform about version, don't enforce minimum
	color.White("  Version: %s", version)
	return nil
}

func checkServerFiles() error {
	_, err := server.FindNappTrappServer()
	return err
}

func checkServerDependencies() error {
	serverPath, err := server.FindNappTrappServer()
	if err != nil {
		return err
	}

	return server.CheckServerDependencies(serverPath)
}

func checkDataDirectory() error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}

	if _, err := os.Stat(dataDir); os.IsNotExist(err) {
		return fmt.Errorf("does not exist at %s", dataDir)
	}

	color.White("  Location: %s", dataDir)
	return nil
}

func checkAuthToken() error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}

	authPath := config.GetAuthPath(dataDir)
	if _, err := os.Stat(authPath); os.IsNotExist(err) {
		return fmt.Errorf("no auth.json found")
	}

	return nil
}

func checkServerPathConfig() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("cannot load config: %w", err)
	}

	if cfg.ServerPath == "" {
		return fmt.Errorf("not configured")
	}

	if _, err := os.Stat(cfg.ServerPath); os.IsNotExist(err) {
		return fmt.Errorf("configured but path invalid: %s", cfg.ServerPath)
	}

	color.White("  Path: %s", cfg.ServerPath)
	return nil
}

func checkQRCodePackage() error {
	cmd := exec.Command("node", "-e", "require('qrcode')")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("not installed")
	}
	return nil
}

func checkGoPathInPath() error {
	goPath := os.Getenv("GOPATH")
	if goPath == "" {
		homeDir, _ := os.UserHomeDir()
		goPath = filepath.Join(homeDir, "go")
	}

	goBin := filepath.Join(goPath, "bin")
	pathEnv := os.Getenv("PATH")

	if !strings.Contains(pathEnv, goBin) {
		return fmt.Errorf("not in PATH")
	}

	return nil
}

// Fix functions

func fixServerDependencies() error {
	serverPath, err := server.FindNappTrappServer()
	if err != nil {
		return err
	}

	serverDir := filepath.Dir(filepath.Dir(serverPath))

	cmd := exec.Command("npm", "install")
	cmd.Dir = serverDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func fixDataDirectory() error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}

	return config.EnsureDataDir(dataDir)
}

func fixAuthToken() error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}

	authPath := config.GetAuthPath(dataDir)

	// Check if auth file exists with server format
	if data, err := os.ReadFile(authPath); err == nil {
		// If file exists and has content, don't overwrite
		if len(data) > 0 {
			return nil
		}
	}

	// Generate new token in nappctl format
	token := generateToken()
	authData := fmt.Sprintf(`{
  "token": "%s",
  "createdAt": "%s"
}`, token, getCurrentTimestamp())

	if err := os.MkdirAll(filepath.Dir(authPath), 0755); err != nil {
		return err
	}

	return os.WriteFile(authPath, []byte(authData), 0600)
}

func fixServerPathConfig() error {
	serverPath, err := server.FindNappTrappServer()
	if err != nil {
		return err
	}

	cfg, err := config.Load()
	if err != nil {
		// Create new config
		cfg = &config.Config{
			Port:       3847,
			Host:       "localhost",
			ServerPath: serverPath,
		}
	} else {
		cfg.ServerPath = serverPath
	}

	return config.Save(cfg)
}

// Helper functions

func generateToken() string {
	// Simple UUID v4 generation
	b := make([]byte, 16)
	if _, err := os.ReadFile("/dev/urandom"); err == nil {
		f, _ := os.Open("/dev/urandom")
		defer f.Close()
		f.Read(b)
	}

	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80

	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func getCurrentTimestamp() string {
	return "2026-02-10T00:00:00Z" // Simple ISO format timestamp
}
