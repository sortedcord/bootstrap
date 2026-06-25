#!/usr/bin/env bash
# System Information Dashboard Plugin for bootstrap CLI

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        echo "Usage: b sysinfo"
        echo ""
        echo "Displays a beautiful system resource and hardware information dashboard."
        return 0
    fi

    echo -e "${BLUE}==================================================${NC}"
    echo -e "   ${GREEN}SYSTEM INFORMATION DASHBOARD${NC}"
    echo -e "${BLUE}==================================================${NC}"

    # OS Info
    local os_name="Unknown"
    if [ -f /etc/os-release ]; then
        os_name=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
    elif [ "$(uname)" = "Darwin" ]; then
        os_name="macOS $(sw_vers -productVersion)"
    else
        os_name=$(uname -s)
    fi
    echo -e "${BLUE}OS:${NC}         $os_name"
    echo -e "${BLUE}Kernel:${NC}     $(uname -r)"
    echo -e "${BLUE}Uptime:${NC}     $(uptime | sed 's/^ *//')"

    # CPU Info
    local cpu_info="Unknown"
    if [ -f /proc/cpuinfo ]; then
        cpu_info=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    elif [ "$(uname)" = "Darwin" ]; then
        cpu_info=$(sysctl -n machdep.cpu.brand_string)
    fi
    echo -e "${BLUE}CPU:${NC}        $cpu_info"

    # Load Average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ *//')
    echo -e "${BLUE}Load Avg:${NC}   $load_avg"

    # Memory Usage
    echo -e "${BLUE}Memory:${NC}"
    if has_command free; then
        free -h | awk 'NR==2{printf "  Used: %s / Total: %s (%.2f%%)\n", $3, $2, $3/$2*100}'
    elif [ -f /proc/meminfo ]; then
        local mem_total
        mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local mem_free
        mem_free=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
        local mem_used=$((mem_total - mem_free))
        # Convert to MB
        local total_mb=$((mem_total / 1024))
        local used_mb=$((mem_used / 1024))
        local pct=$((used_mb * 100 / total_mb))
        echo "  Used: ${used_mb}MB / Total: ${total_mb}MB (${pct}%)"
    elif [ "$(uname)" = "Darwin" ]; then
        local total_mem
        total_mem=$(sysctl -n hw.memsize)
        local total_gb=$((total_mem / 1024 / 1024 / 1024))
        echo "  Total: ${total_gb}GB"
    else
        echo "  Unavailable"
    fi

    # Disk Usage
    echo -e "${BLUE}Disk Space (Root):${NC}"
    df -h / | awk 'NR==2{printf "  Used: %s / Total: %s (%s)\n", $3, $2, $5}'

    echo -e "${BLUE}==================================================${NC}"
}

main "$@"
