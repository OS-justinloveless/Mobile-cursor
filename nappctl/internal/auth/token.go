package auth

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"time"

	"github.com/google/uuid"
	"github.com/mdp/qrterminal/v3"
)

// GenerateToken creates a new random authentication token.
func GenerateToken() string {
	return uuid.New().String()
}

// CreateAndSaveToken generates a new token and saves it to the auth file.
func CreateAndSaveToken(authPath string) (string, error) {
	token := GenerateToken()
	authData := &AuthData{
		Token:     token,
		CreatedAt: time.Now().UTC().Format(time.RFC3339),
	}

	if err := WriteAuthFile(authPath, authData); err != nil {
		return "", fmt.Errorf("failed to save token: %w", err)
	}

	return token, nil
}

// GetToken retrieves the current token from the auth file.
// Returns empty string if no token exists.
func GetToken(authPath string) (string, error) {
	authData, err := ReadAuthFile(authPath)
	if err != nil {
		return "", err
	}

	if authData == nil {
		return "", nil
	}

	return authData.Token, nil
}

// RotateToken generates a new token and replaces the existing one.
func RotateToken(authPath string) (string, error) {
	// Delete existing token
	if err := DeleteAuthFile(authPath); err != nil {
		return "", fmt.Errorf("failed to remove old token: %w", err)
	}

	// Create new token
	return CreateAndSaveToken(authPath)
}

// PrintQRCode displays a QR code for the given text (typically a URL with token).
func PrintQRCode(text string) {
	// Try to use Node.js qrcode library first (same as server uses)
	if err := printQRCodeWithNode(text); err == nil {
		return
	}

	// Fallback to Go qrterminal library
	qrterminal.GenerateHalfBlock(text, qrterminal.L, os.Stdout)
}

// printQRCodeWithNode uses Node.js qrcode library for compact output
func printQRCodeWithNode(text string) error {
	// Try to use qrcode-terminal package from the server's node_modules
	// This matches exactly what the server uses
	script := fmt.Sprintf(`
		try {
			const QRCode = require('qrcode');
			QRCode.toString('%s', {
				type: 'terminal',
				small: true,
				errorCorrectionLevel: 'L'
			}, (err, string) => {
				if (err) process.exit(1);
				console.log(string);
			});
		} catch (e) {
			process.exit(1);
		}
	`, text)

	cmd := exec.Command("node", "-e", script)
	cmd.Stdout = os.Stdout
	// Suppress stderr (module not found errors)
	return cmd.Run()
}

// ValidateToken checks if a token string is valid (non-empty and well-formed).
func ValidateToken(token string) error {
	if token == "" {
		return fmt.Errorf("token is empty")
	}

	// Check if it's a valid UUID format
	if _, err := uuid.Parse(token); err != nil {
		return fmt.Errorf("token is not a valid UUID: %w", err)
	}

	return nil
}

// GetLocalIP returns the local network IP address (non-loopback IPv4).
// Returns empty string if no suitable address is found.
func GetLocalIP() string {
	interfaces, err := net.Interfaces()
	if err != nil {
		return ""
	}

	for _, iface := range interfaces {
		// Skip down interfaces and loopback
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}

			// Return first non-loopback IPv4 address
			if ip != nil && !ip.IsLoopback() && ip.To4() != nil {
				return ip.String()
			}
		}
	}

	return ""
}
