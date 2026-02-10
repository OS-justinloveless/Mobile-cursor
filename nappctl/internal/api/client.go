package api

import (
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client represents an API client for the Napp Trapp server
type Client struct {
	baseURL string
	token   string
	client  *http.Client
}

// NewClient creates a new API client
func NewClient(baseURL, token string) *Client {
	return &Client{
		baseURL: baseURL,
		token:   token,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// HealthCheck checks if the server is responding
func (c *Client) HealthCheck() error {
	resp, err := c.client.Get(c.baseURL + "/health")
	if err != nil {
		return fmt.Errorf("health check failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("health check returned %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// GetSystemInfo retrieves system information from the server
func (c *Client) GetSystemInfo() (map[string]interface{}, error) {
	req, err := http.NewRequest("GET", c.baseURL+"/api/system/info", nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+c.token)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	// Parse JSON response
	// This is a placeholder - full implementation would unmarshal JSON
	return make(map[string]interface{}), nil
}
