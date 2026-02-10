package auth

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// AuthData represents the structure of auth.json.
type AuthData struct {
	Token     string `json:"token"`
	CreatedAt string `json:"createdAt,omitempty"`
}

// ServerAuthData represents the server's auth.json format (for backward compatibility)
type ServerAuthData struct {
	MasterToken string                 `json:"masterToken"`
	Sessions    map[string]interface{} `json:"sessions"`
	LastSaved   int64                  `json:"lastSaved"`
}

// ReadAuthFile reads the auth.json file and returns the auth data.
// Supports both nappctl format (token field) and server format (masterToken field).
func ReadAuthFile(authPath string) (*AuthData, error) {
	data, err := os.ReadFile(authPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil // File doesn't exist, return nil
		}
		return nil, fmt.Errorf("failed to read auth file: %w", err)
	}

	// Try nappctl format first
	var authData AuthData
	if err := json.Unmarshal(data, &authData); err == nil && authData.Token != "" {
		return &authData, nil
	}

	// Try server format (backward compatibility)
	var serverAuth ServerAuthData
	if err := json.Unmarshal(data, &serverAuth); err == nil && serverAuth.MasterToken != "" {
		return &AuthData{
			Token:     serverAuth.MasterToken,
			CreatedAt: "", // Server format doesn't track creation time
		}, nil
	}

	// File exists but has no valid token
	return nil, nil
}

// WriteAuthFile writes auth data to the auth.json file.
func WriteAuthFile(authPath string, authData *AuthData) error {
	// Ensure parent directory exists
	dir := filepath.Dir(authPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create auth directory: %w", err)
	}

	// Marshal with indentation for readability
	data, err := json.MarshalIndent(authData, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal auth data: %w", err)
	}

	// Write with restricted permissions (only owner can read/write)
	if err := os.WriteFile(authPath, data, 0600); err != nil {
		return fmt.Errorf("failed to write auth file: %w", err)
	}

	return nil
}

// DeleteAuthFile removes the auth.json file.
func DeleteAuthFile(authPath string) error {
	if err := os.Remove(authPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete auth file: %w", err)
	}
	return nil
}

// AuthFileExists checks if the auth.json file exists.
func AuthFileExists(authPath string) bool {
	_, err := os.Stat(authPath)
	return err == nil
}
