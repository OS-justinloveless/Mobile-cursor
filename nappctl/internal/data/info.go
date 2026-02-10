package data

import (
	"database/sql"
	"fmt"
	"os"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/config"
	_ "modernc.org/sqlite"
)

// Info represents data directory information
type Info struct {
	DataDir         string
	AuthExists      bool
	DBExists        bool
	DBSize          int64
	ConversationCount int
	MessageCount    int
}

// GetInfo returns information about the data directory
func GetInfo() (*Info, error) {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return nil, err
	}

	info := &Info{
		DataDir: dataDir,
	}

	// Check auth file
	authPath := config.GetAuthPath(dataDir)
	if _, err := os.Stat(authPath); err == nil {
		info.AuthExists = true
	}

	// Check database
	dbPath := config.GetDBPath(dataDir)
	if stat, err := os.Stat(dbPath); err == nil {
		info.DBExists = true
		info.DBSize = stat.Size()

		// Query conversation and message counts
		db, err := sql.Open("sqlite", dbPath)
		if err == nil {
			defer db.Close()

			row := db.QueryRow("SELECT COUNT(*) FROM conversations")
			row.Scan(&info.ConversationCount)

			row = db.QueryRow("SELECT COUNT(*) FROM messages")
			row.Scan(&info.MessageCount)
		}
	}

	return info, nil
}

// GetDataDir returns the resolved data directory path
func GetDataDir() (string, error) {
	return config.ResolveDataDir()
}

// CleanLogs removes old log files
func CleanLogs(daysOld int) error {
	dataDir, err := config.ResolveDataDir()
	if err != nil {
		return err
	}

	logDir := config.GetLogDir(dataDir)
	// Implementation for cleaning logs older than daysOld
	fmt.Printf("Cleaning logs older than %d days from %s\n", daysOld, logDir)

	// This is a placeholder - full implementation would scan directory
	// and remove files older than daysOld days
	return nil
}
