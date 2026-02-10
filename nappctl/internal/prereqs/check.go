package prereqs

import (
	"fmt"
	"os/exec"
	"strings"
)

// Prerequisite represents a system requirement.
type Prerequisite struct {
	Name        string
	Command     string
	MinVersion  string
	CheckFunc   func() (string, error)
	Satisfied   bool
	Version     string
	InstallHint string
}

// CheckResult holds the results of prerequisite checking.
type CheckResult struct {
	AllSatisfied bool
	Prereqs      []Prerequisite
}

// CheckAll verifies all system prerequisites.
func CheckAll() *CheckResult {
	prereqs := []Prerequisite{
		{
			Name:        "Node.js",
			Command:     "node",
			MinVersion:  "16.0.0",
			InstallHint: "Install from https://nodejs.org or use nvm",
			CheckFunc:   checkNode,
		},
		{
			Name:        "npm",
			Command:     "npm",
			MinVersion:  "7.0.0",
			InstallHint: "Included with Node.js",
			CheckFunc:   checkNpm,
		},
		{
			Name:        "cursor-agent",
			Command:     "cursor-agent",
			MinVersion:  "any",
			InstallHint: "curl https://cursor.com/install -fsS | bash",
			CheckFunc:   checkCursorAgent,
		},
		{
			Name:        "git",
			Command:     "git",
			MinVersion:  "2.0.0",
			InstallHint: "Install from https://git-scm.com",
			CheckFunc:   checkGit,
		},
	}

	allSatisfied := true
	for i := range prereqs {
		version, err := prereqs[i].CheckFunc()
		if err != nil {
			prereqs[i].Satisfied = false
			allSatisfied = false
		} else {
			prereqs[i].Satisfied = true
			prereqs[i].Version = version
		}
	}

	return &CheckResult{
		AllSatisfied: allSatisfied,
		Prereqs:      prereqs,
	}
}

func checkNode() (string, error) {
	cmd := exec.Command("node", "--version")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("node not found")
	}

	version := strings.TrimSpace(string(output))
	return version, nil
}

func checkNpm() (string, error) {
	cmd := exec.Command("npm", "--version")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("npm not found")
	}

	version := strings.TrimSpace(string(output))
	return version, nil
}

func checkCursorAgent() (string, error) {
	cmd := exec.Command("cursor-agent", "--version")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("cursor-agent not found")
	}

	version := strings.TrimSpace(string(output))
	return version, nil
}

func checkGit() (string, error) {
	cmd := exec.Command("git", "--version")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git not found")
	}

	// Parse "git version 2.39.0" format
	parts := strings.Fields(string(output))
	if len(parts) >= 3 {
		return parts[2], nil
	}

	return strings.TrimSpace(string(output)), nil
}

// Check verifies a single prerequisite by name.
func Check(name string) (*Prerequisite, error) {
	result := CheckAll()

	for _, prereq := range result.Prereqs {
		if strings.EqualFold(prereq.Name, name) {
			return &prereq, nil
		}
	}

	return nil, fmt.Errorf("unknown prerequisite: %s", name)
}
