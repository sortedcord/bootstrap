# Command: help
# Lists all available bootstrap commands and installers

echo "Available bootstrap commands:"
# Non-installers first (aligned to 6 chars width)
printf "  %-6s - %s\n" "all" "List all available commands"
printf "  %-6s - %s\n" "con" "Edit config (e.g. b con nvim)"
printf "  %-6s - %s\n" "up" "Check for updates and update Bootstrap CLI"
printf "  %-6s - %s\n" "bye" "Uninstall Bootstrap CLI helper"

# Installers second
for key in "${INSTALLER_KEYS[@]}"; do
    printf "  %-6s - %s\n" "$key" "${INSTALLERS[$key]}"
done
