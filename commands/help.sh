# shellcheck shell=bash
# Command: help
# Lists all available bootstrap commands and tools

echo "Available bootstrap commands:"
# Non-tools first (aligned to 6 chars width)
printf "  %-6s - %s\n" "all" "List all available commands"
printf "  %-6s - %s\n" "con" "Edit config (e.g. b con nvim)"
printf "  %-6s - %s\n" "up" "Check for updates and update Bootstrap CLI"
printf "  %-6s - %s\n" "ware" "Edit and run a tool (e.g. b ware nvim)"
printf "  %-6s - %s\n" "gone" "Uninstall Bootstrap CLI helper"


