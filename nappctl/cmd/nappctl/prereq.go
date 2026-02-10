package main

import (
	"fmt"
	"os"

	"github.com/OS-justinloveless/Napp-Trapp/nappctl/internal/prereqs"
	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
	"github.com/spf13/cobra"
)

var prereqCmd = &cobra.Command{
	Use:   "prereq",
	Short: "Check system prerequisites",
	Long:  "Verify that all required system dependencies are installed and accessible.",
}

var prereqCheckCmd = &cobra.Command{
	Use:   "check",
	Short: "Check all prerequisites",
	Long:  "Check that Node.js, npm, cursor-agent, and git are installed.",
	Run: func(cmd *cobra.Command, args []string) {
		result := prereqs.CheckAll()

		// Create table for output
		table := tablewriter.NewWriter(os.Stdout)
		table.SetHeader([]string{"Prerequisite", "Status", "Version", "Install Hint"})
		table.SetBorder(false)
		table.SetColumnSeparator("")
		table.SetAlignment(tablewriter.ALIGN_LEFT)

		// Add rows
		for _, prereq := range result.Prereqs {
			status := ""
			if prereq.Satisfied {
				status = color.GreenString("✓ Installed")
			} else {
				status = color.RedString("✗ Missing")
			}

			version := prereq.Version
			if version == "" {
				version = "-"
			}

			installHint := ""
			if !prereq.Satisfied {
				installHint = prereq.InstallHint
			}

			table.Append([]string{prereq.Name, status, version, installHint})
		}

		table.Render()

		// Print summary
		fmt.Println()
		if result.AllSatisfied {
			color.Green("✓ All prerequisites satisfied")
			os.Exit(0)
		} else {
			color.Red("✗ Some prerequisites are missing")
			fmt.Println("\nPlease install the missing dependencies before starting the server.")
			os.Exit(1)
		}
	},
}

var prereqCheckSingleCmd = &cobra.Command{
	Use:   "check-one <name>",
	Short: "Check a single prerequisite",
	Long:  "Check if a specific prerequisite (node, npm, cursor-agent, git) is installed.",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		name := args[0]
		prereq, err := prereqs.Check(name)
		if err != nil {
			color.Red("Error: %v", err)
			os.Exit(1)
		}

		if prereq.Satisfied {
			color.Green("✓ %s is installed", prereq.Name)
			fmt.Printf("  Version: %s\n", prereq.Version)
			os.Exit(0)
		} else {
			color.Red("✗ %s is not installed", prereq.Name)
			fmt.Printf("  Install: %s\n", prereq.InstallHint)
			os.Exit(1)
		}
	},
}

func init() {
	prereqCmd.AddCommand(prereqCheckCmd)
	prereqCmd.AddCommand(prereqCheckSingleCmd)
}
