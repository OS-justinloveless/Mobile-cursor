package config

import (
	"fmt"
	"path/filepath"

	"github.com/spf13/viper"
)

// Config holds the application configuration.
type Config struct {
	Port       int    `mapstructure:"port"`
	Host       string `mapstructure:"host"`
	AuthToken  string `mapstructure:"auth_token"`
	DataDir    string `mapstructure:"data_dir"`
	ServerPath string `mapstructure:"server_path"`
}

// Load reads configuration from file and environment variables.
// Priority order (highest to lowest):
// 1. Command-line flags (handled by cobra)
// 2. Environment variables (NAPPTRAPP_PORT, NAPPTRAPP_HOST, etc.)
// 3. Config file (~/.napptrapp/config.yaml)
// 4. Default values
func Load() (*Config, error) {
	// Set config file location
	dataDir, err := ResolveDataDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get data directory: %w", err)
	}

	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(dataDir)
	viper.AddConfigPath(".")

	// Set environment variable prefix
	viper.SetEnvPrefix("NAPPTRAPP")
	viper.AutomaticEnv()

	// Set defaults
	viper.SetDefault("port", 3847)
	viper.SetDefault("host", "localhost")
	viper.SetDefault("data_dir", dataDir)

	// Read config file if it exists (ignore error if not found)
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return &cfg, nil
}

// Save writes the current configuration to the config file.
func Save(cfg *Config) error {
	dataDir, err := ResolveDataDir()
	if err != nil {
		return fmt.Errorf("failed to get data directory: %w", err)
	}

	configPath := filepath.Join(dataDir, "config.yaml")

	viper.Set("port", cfg.Port)
	viper.Set("host", cfg.Host)
	if cfg.AuthToken != "" {
		viper.Set("auth_token", cfg.AuthToken)
	}
	viper.Set("data_dir", cfg.DataDir)
	if cfg.ServerPath != "" {
		viper.Set("server_path", cfg.ServerPath)
	}

	if err := viper.WriteConfigAs(configPath); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// GetServerURL returns the full server URL based on host and port.
func (c *Config) GetServerURL() string {
	return fmt.Sprintf("http://%s:%d", c.Host, c.Port)
}
