#!/bin/bash

# ============================================
# Qwen Code Web UI - Quick Install Script
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
PORT="${PORT:-3000}"
IMAGE_NAME="qwen-code-webui"
CONTAINER_NAME="qwen-code-webui"
QWEN_CONFIG_DIR="${HOME}/.qwen"
INTERACTIVE=true
PROJECT_DIRS=""
QWEN_BINARY=""
CONFIGURE_FIREWALL=false
IMAGE_FILE=""
DOCKER_USER="${DOCKER_USER:-open-ace}"

# Detected OS and firewall info
OS_TYPE=""
FIREWALL_TYPE=""
FIREWALL_ENABLED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            INTERACTIVE=false
            shift 2
            ;;
        -y|--yes)
            INTERACTIVE=false
            shift
            ;;
        --firewall)
            CONFIGURE_FIREWALL=true
            shift
            ;;
        -i|--image)
            IMAGE_FILE="$2"
            shift 2
            ;;
        -u|--user)
            DOCKER_USER="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -p, --port <port>    Port to expose (default: 3000)"
            echo "  -y, --yes            Non-interactive mode, use defaults"
            echo "  --firewall           Configure firewall to allow the port"
            echo "  -i, --image <file>   Load Docker image from tar file (offline install)"
            echo "  -u, --user <user>    User to run Docker commands (default: open-ace)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  PORT                 Port to expose (default: 3000)"
            echo "  PROJECT_DIRS         Colon-separated list of project directories to mount"
            echo "  DOCKER_USER          User to run Docker commands (default: open-ace)"
            echo ""
            echo "Examples:"
            echo "  $0                           # Interactive mode"
            echo "  $0 -p 3000                   # Install on port 3000 (non-interactive)"
            echo "  $0 -y --firewall             # Non-interactive with firewall config"
            echo "  $0 -i ./qwen-code-webui.tar  # Load image from tar file"
            echo "  $0 -u myuser                 # Run Docker as myuser"
            echo "  PROJECT_DIRS=~/projects:~/work $0  # Mount multiple project directories"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# ============================================
# Helper Functions
# ============================================

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                          ║${NC}"
    echo -e "${BLUE}║    ${BOLD}Qwen Code Web UI - Install${NC}             ${BLUE}║${NC}"
    echo -e "${BLUE}║                                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}  $1${NC}"
}

# Run docker command as specified user
run_docker() {
    local cmd="$*"
    if [ "$(id -u)" -eq 0 ] && [ -n "$DOCKER_USER" ] && [ "$DOCKER_USER" != "root" ]; then
        # Use sg to run with docker group, which works immediately without re-login
        su - "$DOCKER_USER" -c "sg docker -c '$cmd'" 2>/dev/null || su - "$DOCKER_USER" -c "$cmd"
    else
        eval "$cmd"
    fi
}

# Check if a port is in use
port_in_use() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1 || netstat -an 2>/dev/null | grep -q ":$port "; then
        return 0
    fi
    return 1
}

# Find next available port
find_available_port() {
    local port=$1
    while port_in_use $port; do
        ((port++))
    done
    echo $port
}

# Select from a list
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local num_options=${#options[@]}

    # If only one option, auto-select
    if [ $num_options -eq 1 ]; then
        echo "${options[0]}"
        return
    fi

    echo -e "\n$prompt"
    echo ""
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${options[$i]}"
    done
    echo ""

    while true; do
        read -p "  Select [1-${num_options}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $num_options ]; then
            echo "${options[$((choice-1))]}"
            return
        fi
        print_warning "Invalid selection. Please enter a number between 1 and $num_options."
    done
}

# Multi-select from a list (default: select all, confirm to proceed)
multi_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}

    if [ $num_options -eq 0 ]; then
        echo ""
        return
    fi

    echo -e "\n$prompt" >&2
    echo "" >&2

    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}✓${NC} ${options[$i]}" >&2
    done
    echo "" >&2

    echo -e "${CYAN}  All directories selected. Press Enter to confirm, or enter numbers to customize.${NC}" >&2
    read -p "  Confirm [Y/n]: " choices

    if [ -z "$choices" ] || [ "$choices" = "y" ] || [ "$choices" = "Y" ]; then
        # Return all options
        echo "${options[@]}"
        return
    fi

    # Custom selection
    local valid=true
    local selected=()
    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $num_options ]; then
            selected+=("${options[$((choice-1))]}")
        else
            valid=false
            break
        fi
    done

    if $valid; then
        echo "${selected[@]}"
        return
    fi

    # Invalid input, return all
    echo "${options[@]}"
}

# ============================================
# Firewall Detection and Configuration
# ============================================

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS_TYPE="macos"
            ;;
        Linux*)
            OS_TYPE="linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS_TYPE="windows"
            ;;
        *)
            OS_TYPE="unknown"
            ;;
    esac
}

# Detect firewall type and status
detect_firewall() {
    detect_os

    case "$OS_TYPE" in
        macos)
            detect_firewall_macos
            ;;
        linux)
            detect_firewall_linux
            ;;
        windows)
            detect_firewall_windows
            ;;
        *)
            FIREWALL_TYPE="unknown"
            FIREWALL_ENABLED=false
            ;;
    esac
}

# macOS firewall detection
detect_firewall_macos() {
    # Check if Application Firewall is enabled
    local fw_status
    fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "disabled")

    if echo "$fw_status" | grep -qi "enabled"; then
        FIREWALL_TYPE="socketfilterfw"
        FIREWALL_ENABLED=true
    else
        # Check if pf is enabled
        if pfctl -s info 2>/dev/null | grep -q "Enabled"; then
            FIREWALL_TYPE="pf"
            FIREWALL_ENABLED=true
        else
            FIREWALL_TYPE="socketfilterfw"
            FIREWALL_ENABLED=false
        fi
    fi
}

# Linux firewall detection
detect_firewall_linux() {
    # Check for ufw (Ubuntu/Debian)
    if command -v ufw > /dev/null 2>&1; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null || echo "inactive")
        if echo "$ufw_status" | grep -qi "active"; then
            FIREWALL_TYPE="ufw"
            FIREWALL_ENABLED=true
            return
        fi
    fi

    # Check for firewalld (CentOS/RHEL/Fedora)
    if command -v firewall-cmd > /dev/null 2>&1; then
        if systemctl is-active firewalld > /dev/null 2>&1; then
            FIREWALL_TYPE="firewalld"
            FIREWALL_ENABLED=true
            return
        fi
    fi

    # Check for iptables
    if command -v iptables > /dev/null 2>&1; then
        local iptables_rules
        iptables_rules=$(iptables -S 2>/dev/null | grep -c "ACCEPT\|DROP\|REJECT" || echo "0")
        if [ "$iptables_rules" -gt 3 ]; then
            FIREWALL_TYPE="iptables"
            FIREWALL_ENABLED=true
            return
        fi
    fi

    # Check for nftables
    if command -v nft > /dev/null 2>&1; then
        if nft list ruleset 2>/dev/null | grep -q "chain"; then
            FIREWALL_TYPE="nftables"
            FIREWALL_ENABLED=true
            return
        fi
    fi

    FIREWALL_TYPE="none"
    FIREWALL_ENABLED=false
}

# Windows firewall detection (Git Bash/WSL)
detect_firewall_windows() {
    # Try to detect via PowerShell
    if command -v powershell.exe > /dev/null 2>&1; then
        local fw_status
        fw_status=$(powershell.exe -Command "Get-NetFirewallProfile | Select-Object -ExpandProperty Enabled" 2>/dev/null || echo "False")
        if echo "$fw_status" | grep -qi "true"; then
            FIREWALL_TYPE="netsh"
            FIREWALL_ENABLED=true
            return
        fi
    fi

    FIREWALL_TYPE="netsh"
    FIREWALL_ENABLED=false
}

# Configure firewall to allow port
configure_firewall_port() {
    local port=$1
    local proto=${2:-tcp}

    print_step "Configuring firewall for port $port..."

    case "$FIREWALL_TYPE" in
        socketfilterfw)
            configure_firewall_macos_port "$port" "$proto"
            ;;
        pf)
            configure_firewall_pf_port "$port" "$proto"
            ;;
        ufw)
            configure_firewall_ufw_port "$port" "$proto"
            ;;
        firewalld)
            configure_firewall_firewalld_port "$port" "$proto"
            ;;
        iptables)
            configure_firewall_iptables_port "$port" "$proto"
            ;;
        nftables)
            configure_firewall_nftables_port "$port" "$proto"
            ;;
        netsh)
            configure_firewall_netsh_port "$port" "$proto"
            ;;
        *)
            print_warning "Unknown firewall type: $FIREWALL_TYPE"
            print_info "Please manually configure your firewall to allow port $port"
            return 1
            ;;
    esac
}

# macOS Application Firewall configuration
configure_firewall_macos_port() {
    local port=$1
    local proto=$2

    # socketfilterfw doesn't support port-based rules directly
    # We need to add the application to the firewall
    print_info "macOS Application Firewall uses application-based rules"
    print_info "Docker Desktop should be allowed through the firewall"
    print_info "If you have issues, check System Settings > Privacy & Security > Firewall"

    # Check if we can use pf instead
    if [ "$FIREWALL_TYPE" = "socketfilterfw" ] && command -v pfctl > /dev/null 2>&1; then
        echo ""
        echo -e "  ${YELLOW}Would you like to configure pf (Packet Filter) instead?${NC}"
        echo -e "  ${CYAN}1)${NC} Yes, configure pf"
        echo -e "  ${CYAN}2)${NC} No, skip firewall configuration"
        echo ""
        read -p "  Select [1-2]: " pf_choice

        if [ "$pf_choice" = "1" ]; then
            configure_firewall_pf_port "$port" "$proto"
            return
        fi
    fi

    print_success "Firewall note: Ensure Docker Desktop is allowed"
}

# macOS pf configuration
configure_firewall_pf_port() {
    local port=$1
    local proto=$2

    local anchor_name="qwen-code-webui"
    local pf_conf="/etc/pf.conf"
    local custom_conf="/etc/pf.anchors/qwen-code-webui"

    # Check if rule already exists
    if [ -f "$custom_conf" ]; then
        if grep -q "port $port" "$custom_conf" 2>/dev/null; then
            print_success "Firewall rule already exists for port $port"
            return 0
        fi
    fi

    print_info "Creating pf anchor for port $port..."

    # Create anchor file
    echo "# Qwen Code Web UI - Auto-generated firewall rule" | sudo tee "$custom_conf" > /dev/null
    echo "pass in proto $proto from any to any port $port" | sudo tee -a "$custom_conf" > /dev/null

    # Add anchor to pf.conf if not already present
    if ! grep -q "qwen-code-webui" "$pf_conf" 2>/dev/null; then
        echo "anchor \"qwen-code-webui\"" | sudo tee -a "$pf_conf" > /dev/null
        echo "load anchor \"qwen-code-webui\" from \"/etc/pf.anchors/qwen-code-webui\"" | sudo tee -a "$pf_conf" > /dev/null
    fi

    # Reload pf rules
    sudo pfctl -ef "$pf_conf" 2>/dev/null || true

    print_success "pf configured to allow port $port"
}

# UFW configuration (Ubuntu/Debian)
configure_firewall_ufw_port() {
    local port=$1
    local proto=$2

    # Check if rule already exists
    if ufw status | grep -q "$port/$proto"; then
        print_success "UFW rule already exists for port $port"
        return 0
    fi

    print_info "Adding UFW rule for port $port..."

    # Check if we need sudo
    if [ "$(id -u)" -ne 0 ]; then
        sudo ufw allow "$port/$proto" comment "Qwen Code Web UI"
    else
        ufw allow "$port/$proto" comment "Qwen Code Web UI"
    fi

    print_success "UFW configured to allow port $port"
}

# firewalld configuration (CentOS/RHEL/Fedora)
configure_firewall_firewalld_port() {
    local port=$1
    local proto=$2

    # Check if rule already exists
    if firewall-cmd --list-ports 2>/dev/null | grep -q "$port/$proto"; then
        print_success "firewalld rule already exists for port $port"
        return 0
    fi

    print_info "Adding firewalld rule for port $port..."

    # Add permanent and runtime rule
    if [ "$(id -u)" -ne 0 ]; then
        sudo firewall-cmd --permanent --add-port="$port/$proto"
        sudo firewall-cmd --add-port="$port/$proto"
    else
        firewall-cmd --permanent --add-port="$port/$proto"
        firewall-cmd --add-port="$port/$proto"
    fi

    print_success "firewalld configured to allow port $port"
}

# iptables configuration
configure_firewall_iptables_port() {
    local port=$1
    local proto=$2

    # Check if rule already exists
    if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:$port"; then
        print_success "iptables rule already exists for port $port"
        return 0
    fi

    print_info "Adding iptables rule for port $port..."

    if [ "$(id -u)" -ne 0 ]; then
        sudo iptables -I INPUT -p $proto --dport $port -m state --state NEW -j ACCEPT
        # Try to save the rule
        if command -v iptables-save > /dev/null 2>&1; then
            sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    else
        iptables -I INPUT -p $proto --dport $port -m state --state NEW -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi

    print_success "iptables configured to allow port $port"
}

# nftables configuration
configure_firewall_nftables_port() {
    local port=$1
    local proto=$2

    print_info "Adding nftables rule for port $port..."

    if [ "$(id -u)" -ne 0 ]; then
        sudo nft add rule inet filter input "$proto" dport "$port" accept
    else
        nft add rule inet filter input "$proto" dport "$port" accept
    fi

    print_success "nftables configured to allow port $port"
}

# Windows netsh configuration
configure_firewall_netsh_port() {
    local port=$1
    local proto=$2

    print_info "Adding Windows Firewall rule for port $port..."

    # Use PowerShell for better control
    local rule_name="Qwen Code Web UI - Port $port"

    powershell.exe -Command "New-NetFirewallRule -DisplayName '$rule_name' -Direction Inbound -LocalPort $port -Protocol $proto -Action Allow" 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "Windows Firewall configured to allow port $port"
    else
        print_warning "Failed to configure Windows Firewall"
        print_info "Please manually add a rule for port $port"
    fi
}

# Remove firewall rule
remove_firewall_port() {
    local port=$1
    local proto=${2:-tcp}

    print_step "Removing firewall rule for port $port..."

    case "$FIREWALL_TYPE" in
        ufw)
            if ufw status | grep -q "$port/$proto"; then
                if [ "$(id -u)" -ne 0 ]; then
                    sudo ufw delete allow "$port/$proto"
                else
                    ufw delete allow "$port/$proto"
                fi
                print_success "UFW rule removed for port $port"
            fi
            ;;
        firewalld)
            if firewall-cmd --list-ports 2>/dev/null | grep -q "$port/$proto"; then
                if [ "$(id -u)" -ne 0 ]; then
                    sudo firewall-cmd --permanent --remove-port="$port/$proto"
                    sudo firewall-cmd --remove-port="$port/$proto"
                else
                    firewall-cmd --permanent --remove-port="$port/$proto"
                    firewall-cmd --remove-port="$port/$proto"
                fi
                print_success "firewalld rule removed for port $port"
            fi
            ;;
        iptables)
            if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:$port"; then
                if [ "$(id -u)" -ne 0 ]; then
                    sudo iptables -D INPUT -p $proto --dport $port -m state --state NEW -j ACCEPT
                else
                    iptables -D INPUT -p $proto --dport $port -m state --state NEW -j ACCEPT
                fi
                print_success "iptables rule removed for port $port"
            fi
            ;;
        pf)
            local custom_conf="/etc/pf.anchors/qwen-code-webui"
            if [ -f "$custom_conf" ]; then
                sudo rm -f "$custom_conf"
                sudo pfctl -ef /etc/pf.conf 2>/dev/null || true
                print_success "pf rule removed for port $port"
            fi
            ;;
        netsh)
            local rule_name="Qwen Code Web UI - Port $port"
            powershell.exe -Command "Remove-NetFirewallRule -DisplayName '$rule_name'" 2>/dev/null
            print_success "Windows Firewall rule removed for port $port"
            ;;
        *)
            print_info "Please manually remove firewall rule for port $port"
            ;;
    esac
}

# ============================================
# Interactive Configuration
# ============================================

run_interactive() {
    print_header

    # Step 1: Port selection
    print_step "Step 1: Configure Port"

    if port_in_use $PORT; then
        print_warning "Port $PORT is already in use"
        local available_port=$(find_available_port $((PORT+1)))
        echo -e "  ${CYAN}1)${NC} Use suggested port: ${GREEN}$available_port${NC}"
        echo -e "  ${CYAN}2)${NC} Enter custom port"
        echo -e "  ${CYAN}3)${NC} Force use port $PORT (may conflict)"
        echo ""

        while true; do
            read -p "  Select [1-3]: " port_choice
            case $port_choice in
                1) PORT=$available_port; break ;;
                2)
                    read -p "  Enter port number: " custom_port
                    if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
                        PORT=$custom_port
                        break
                    fi
                    print_warning "Invalid port number"
                    ;;
                3) break ;;
                *) print_warning "Invalid selection" ;;
            esac
        done
    else
        echo -e "  Default port: ${GREEN}$PORT${NC}"
        echo -e "  ${CYAN}1)${NC} Use default port $PORT"
        echo -e "  ${CYAN}2)${NC} Enter custom port"
        echo ""

        read -p "  Select [1-2, default=1]: " port_choice
        case $port_choice in
            2)
                read -p "  Enter port number: " custom_port
                if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
                    PORT=$custom_port
                fi
                ;;
        esac
    fi

    print_success "Port set to $PORT"

    # Step 2: Project directories
    print_step "Step 2: Mount Project Directories"

    # Determine the home directory to search for projects
    local search_home="$HOME"
    if [ "$(id -u)" -eq 0 ] && [ -n "$DOCKER_USER" ] && [ "$DOCKER_USER" != "root" ]; then
        search_home=$(eval echo "~$DOCKER_USER" 2>/dev/null || echo "$HOME")
        print_info "Searching projects for user: $DOCKER_USER ($search_home)"
    fi

    # Find common project directories
    local common_dirs=()
    for dir in "$search_home/projects" "$search_home/workspace" "$search_home/work" "$search_home/code" "$search_home/dev"; do
        if [ -d "$dir" ]; then
            common_dirs+=("$dir")
        fi
    done

    # Also find subdirectories in common project locations
    local project_subdirs=()
    for parent in "${common_dirs[@]}"; do
        local count=0
        while IFS= read -r subdir; do
            if [ $count -lt 5 ]; then
                project_subdirs+=("$subdir")
                ((count++))
            fi
        done < <(find "$parent" -maxdepth 1 -type d ! -path "$parent" 2>/dev/null | head -5)
    done

    local all_projects=("${common_dirs[@]}" "${project_subdirs[@]}")

    if [ ${#all_projects[@]} -gt 0 ]; then
        echo -e "  Found project directories:"
        echo ""

        local selected_dirs=$(multi_select "Select directories to mount:" "${all_projects[@]}")

        if [ -n "$selected_dirs" ]; then
            PROJECT_DIRS=""
            for dir in $selected_dirs; do
                if [ -n "$PROJECT_DIRS" ]; then
                    PROJECT_DIRS="$PROJECT_DIRS:$dir"
                else
                    PROJECT_DIRS="$dir"
                fi
            done
            print_success "Selected directories: ${PROJECT_DIRS//:/, }"
        else
            print_info "No directories selected"
        fi
    else
        echo -e "  ${YELLOW}No common project directories found.${NC}"
    fi

    # Manual directory input
    echo ""
    echo -e "  ${CYAN}Enter additional directories to mount (comma or space separated)${NC}"
    echo -e "  ${CYAN}Or press Enter to skip:${NC}"
    read -p "  " manual_dirs

    if [ -n "$manual_dirs" ]; then
        # Replace commas and spaces with colons
        manual_dirs=$(echo "$manual_dirs" | tr ', ' ':' | tr -s ':')
        # Expand ~ to the Docker user's home directory
        manual_dirs="${manual_dirs//\~/$search_home}"

        if [ -n "$PROJECT_DIRS" ]; then
            PROJECT_DIRS="$PROJECT_DIRS:$manual_dirs"
        else
            PROJECT_DIRS="$manual_dirs"
        fi
        print_success "Added directories: ${manual_dirs//:/, }"
    fi

    # Step 3: Docker user configuration
    print_step "Step 3: Configure Docker User"

    # Check if running as root
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "  Running as ${YELLOW}root${NC}, need to specify a user for Docker commands."
        echo ""
        echo -e "  Current user: ${GREEN}$DOCKER_USER${NC}"
        echo -e "  ${CYAN}1)${NC} Use default user: $DOCKER_USER"
        echo -e "  ${CYAN}2)${NC} Enter custom user"
        echo ""

        read -p "  Select [1-2, default=1]: " user_choice
        case $user_choice in
            2)
                read -p "  Enter username: " custom_user
                if [ -n "$custom_user" ]; then
                    # Verify user exists
                    if id "$custom_user" > /dev/null 2>&1; then
                        DOCKER_USER="$custom_user"
                    else
                        print_warning "User '$custom_user' not found, using default: $DOCKER_USER"
                    fi
                fi
                ;;
        esac

        # Update QWEN_CONFIG_DIR for the docker user
        local user_home
        user_home=$(eval echo "~$DOCKER_USER")
        if [ -d "$user_home/.qwen" ]; then
            QWEN_CONFIG_DIR="$user_home/.qwen"
        fi

        # Check if user has Docker permissions
        print_info "Checking Docker permissions for user: $DOCKER_USER"
        if ! groups "$DOCKER_USER" 2>/dev/null | grep -q '\bdocker\b'; then
            print_warning "User '$DOCKER_USER' is not in the 'docker' group."
            echo -e "  Adding user '$DOCKER_USER' to docker group..."
            usermod -aG docker "$DOCKER_USER" 2>/dev/null || gpasswd -a "$DOCKER_USER" docker 2>/dev/null || {
                print_error "Failed to add user to docker group."
                echo -e "  Please run: usermod -aG docker $DOCKER_USER"
                exit 1
            }
            print_success "User '$DOCKER_USER' added to docker group"
            print_warning "The user may need to log out and log back in for changes to take effect."
            echo -e "  Or run: newgrp docker"
        else
            print_success "User '$DOCKER_USER' has Docker permissions"
        fi
    else
        echo -e "  Running as ${GREEN}$(whoami)${NC}, Docker commands will use current user."
        DOCKER_USER="$(whoami)"
    fi

    print_success "Docker user: $DOCKER_USER"

    # Step 4: Firewall configuration
    print_step "Step 4: Firewall Configuration"

    # Detect firewall
    detect_firewall

    if [ "$FIREWALL_ENABLED" = true ]; then
        echo -e "  Detected firewall: ${GREEN}$FIREWALL_TYPE${NC} (enabled)"
        echo ""
        echo -e "  ${CYAN}1)${NC} Configure firewall to allow port $PORT"
        echo -e "  ${CYAN}2)${NC} Skip firewall configuration"
        echo ""

        read -p "  Select [1-2, default=1]: " fw_choice
        case $fw_choice in
            2)
                print_info "Skipping firewall configuration"
                ;;
            *)
                CONFIGURE_FIREWALL=true
                ;;
        esac
    else
        echo -e "  Detected firewall: ${YELLOW}$FIREWALL_TYPE${NC} (disabled or not found)"
        echo ""
        if [ "$FIREWALL_TYPE" != "none" ] && [ "$FIREWALL_TYPE" != "unknown" ]; then
            echo -e "  ${CYAN}1)${NC} Configure firewall anyway (for future use)"
            echo -e "  ${CYAN}2)${NC} Skip firewall configuration"
            echo ""

            read -p "  Select [1-2, default=2]: " fw_choice
            case $fw_choice in
                1)
                    CONFIGURE_FIREWALL=true
                    ;;
            esac
        else
            print_info "No firewall detected, skipping configuration"
        fi
    fi

    # Step 5: Confirmation
    print_step "Step 5: Confirm Installation"

    echo ""
    echo -e "  ${BOLD}Configuration Summary:${NC}"
    echo -e "  ─────────────────────────────────────────"
    echo -e "  Port:              ${GREEN}$PORT${NC}"
    echo -e "  Docker User:       ${GREEN}$DOCKER_USER${NC}"
    echo -e "  Qwen Config:       ${GREEN}$QWEN_CONFIG_DIR${NC}"
    if [ -n "$PROJECT_DIRS" ]; then
        echo -e "  Project Dirs:      ${GREEN}${PROJECT_DIRS//:/\n                      }${NC}"
    else
        echo -e "  Project Dirs:      ${YELLOW}None${NC}"
    fi
    if [ "$CONFIGURE_FIREWALL" = true ]; then
        echo -e "  Firewall:          ${GREEN}Configure ($FIREWALL_TYPE)${NC}"
    else
        echo -e "  Firewall:          ${YELLOW}Skip${NC}"
    fi
    echo -e "  ─────────────────────────────────────────"
    echo ""

    echo -e "  ${GREEN}Ready to install. Press Enter to start, or enter 2 to cancel.${NC}"
    read -p "  Confirm [Y/n]: " confirm

    case $confirm in
        2|n|N)
            echo -e "\n${YELLOW}Installation cancelled.${NC}"
            exit 0
            ;;
    esac
}

# ============================================
# Main Installation
# ============================================

install() {
    print_header

    # Check if Docker is running
    print_step "Checking Docker..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"

    # Check Qwen config
    print_step "Checking Qwen CLI configuration..."

    # Try to find Qwen config directory for the Docker user
    local config_found=false

    if [ -n "$DOCKER_USER" ] && [ "$DOCKER_USER" != "root" ]; then
        # Check Docker user's .qwen directory first
        local user_home
        user_home=$(eval echo "~$DOCKER_USER" 2>/dev/null || echo "")
        if [ -n "$user_home" ] && [ -d "$user_home/.qwen" ]; then
            QWEN_CONFIG_DIR="$user_home/.qwen"
            config_found=true
        elif [ -n "$user_home" ] && [ -f "$user_home/.qwen/settings.json" ]; then
            # settings.json exists but directory might not be fully set up
            QWEN_CONFIG_DIR="$user_home/.qwen"
            config_found=true
        fi
    fi

    # Fallback to current user's config
    if [ "$config_found" = false ] && [ -d "$QWEN_CONFIG_DIR" ]; then
        config_found=true
    fi

    if [ "$config_found" = true ]; then
        print_success "Qwen config found at $QWEN_CONFIG_DIR"

        # Ensure projects directory exists with correct permissions
        if [ -f "$QWEN_CONFIG_DIR/settings.json" ]; then
            if [ ! -d "$QWEN_CONFIG_DIR/projects" ]; then
                print_info "Creating projects directory..."
                mkdir -p "$QWEN_CONFIG_DIR/projects"

                # Set correct ownership for Docker user
                if [ -n "$DOCKER_USER" ] && [ "$DOCKER_USER" != "root" ]; then
                    chown -R "$DOCKER_USER:$DOCKER_USER" "$QWEN_CONFIG_DIR/projects" 2>/dev/null || true
                fi
                print_success "Created $QWEN_CONFIG_DIR/projects"
            fi
        fi

        # Fix permissions for container access (nodejs user in container needs write access)
        if [ "$(id -u)" -eq 0 ]; then
            print_info "Setting write permissions for container access..."
            chmod -R a+rwX "$QWEN_CONFIG_DIR" 2>/dev/null || true
            print_success "Permissions updated"
        fi
    else
        print_warning "Qwen CLI not configured on this machine."
        echo -e "  The Docker image includes qwen-code CLI."
        echo -e "  You need to mount your Qwen config directory:"
        echo ""
        echo -e "  ${CYAN}Option 1:${NC} Run 'qwen' command first to authenticate, then re-run this script"
        echo -e "  ${CYAN}Option 2:${NC} Copy your ~/.qwen directory from another machine"
        echo -e "  ${CYAN}Option 3:${NC} Continue and manually configure later"
        echo ""

        if $INTERACTIVE; then
            echo -e "  ${CYAN}1)${NC} Continue without Qwen config (manual setup later)"
            echo -e "  ${CYAN}2)${NC} Cancel and configure Qwen first"
            echo ""

            while true; do
                read -p "  Select [1-2]: " config_choice
                case $config_choice in
                    1)
                        print_info "Continuing without Qwen config..."
                        QWEN_CONFIG_DIR="/tmp/.qwen-placeholder"
                        mkdir -p "$QWEN_CONFIG_DIR" 2>/dev/null || true
                        ;;
                    2)
                        echo -e "\n${YELLOW}Installation cancelled. Please configure Qwen CLI first.${NC}"
                        exit 0
                        ;;
                    *)
                        print_warning "Invalid selection"
                        ;;
                esac
                break
            done
        else
            # Non-interactive mode: create placeholder and continue
            print_info "Creating placeholder config directory..."
            QWEN_CONFIG_DIR="/tmp/.qwen-placeholder"
            mkdir -p "$QWEN_CONFIG_DIR" 2>/dev/null || true
        fi
    fi

    # Check/load Docker image
    print_step "Checking Docker image..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

    # Check if image already exists
    if run_docker "docker image inspect \"$IMAGE_NAME:latest\"" > /dev/null 2>&1; then
        print_success "Image already exists"
    else
        # Try to load from tar file
        local image_loaded=false

        # If image file specified, use it
        if [ -n "$IMAGE_FILE" ]; then
            if [ -f "$IMAGE_FILE" ]; then
                print_info "Loading image from: $IMAGE_FILE"
                # Make file readable for docker user
                chmod a+r "$IMAGE_FILE" 2>/dev/null || true
                docker load -i "$IMAGE_FILE"
                image_loaded=true
                print_success "Image loaded from $IMAGE_FILE"
            else
                print_error "Image file not found: $IMAGE_FILE"
                exit 1
            fi
        else
            # Auto-detect image tar file in common locations
            local search_dirs=("$PROJECT_DIR" "$SCRIPT_DIR" "$(pwd)" "$(dirname "$(pwd")")
            local tar_patterns=("qwen-code-webui*.tar" "qwen-code-webui*.tar.gz" "qwen-code-webui*.tgz")

            for dir in "${search_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    for pattern in "${tar_patterns[@]}"; do
                        local found_files=( "$dir"/$pattern )
                        if [ -f "${found_files[0]}" ]; then
                            local tar_file="${found_files[0]}"
                            print_info "Found image file: $tar_file"
                            print_info "Loading image..."
                            # Make file readable for docker user
                            chmod a+r "$tar_file" 2>/dev/null || true
                            docker load -i "$tar_file"
                            image_loaded=true
                            print_success "Image loaded from $tar_file"
                            break 2
                        fi
                    done
                fi
            done
        fi

        # If still not loaded, try to build
        if [ "$image_loaded" = false ]; then
            if [ -f "$PROJECT_DIR/Dockerfile" ]; then
                print_info "Image not found. Building..."
                cd "$PROJECT_DIR"
                docker build -t "$IMAGE_NAME:latest" .
                print_success "Image built successfully"
            else
                print_error "Docker image not found and no Dockerfile available."
                echo -e "  Please either:"
                echo -e "  1. Copy the image tar file to this directory"
                echo -e "  2. Use -i option: $0 -i /path/to/qwen-code-webui.tar"
                echo -e "  3. Build from source: clone the repo and run docker build"
                exit 1
            fi
        fi
    fi

    # Stop existing container if running
    print_step "Preparing container..."
    if run_docker "docker ps -a --format '{{.Names}}'" | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Stopping existing container..."
        run_docker "docker stop \"$CONTAINER_NAME\"" > /dev/null 2>&1 || true
        run_docker "docker rm \"$CONTAINER_NAME\"" > /dev/null 2>&1 || true
    fi

    # Build volume mounts
    VOLUMES="-v ${QWEN_CONFIG_DIR}:/home/nodejs/.qwen"

    # Add project directories if specified
    if [ -n "$PROJECT_DIRS" ]; then
        IFS=':' read -ra DIRS <<< "$PROJECT_DIRS"
        local dir_count=${#DIRS[@]}

        for dir in "${DIRS[@]}"; do
            # Expand ~ to home directory
            dir="${dir/#\~/$HOME}"
            if [ -d "$dir" ]; then
                if [ $dir_count -eq 1 ]; then
                    # Single directory: mount directly to /workspace
                    VOLUMES="$VOLUMES -v ${dir}:/workspace"
                    CONTAINER_PATH="/workspace"
                else
                    # Multiple directories: mount to /workspace/<basename>
                    VOLUMES="$VOLUMES -v ${dir}:/workspace/$(basename "$dir")"
                    CONTAINER_PATH="/workspace/$(basename "$dir")"
                fi
                print_info "Mounting: $dir"

                # Create qwen project session for this directory
                # This allows the project to appear in the Web UI project list
                local encoded_name=$(echo "$CONTAINER_PATH" | sed 's/^[\/]//' | sed 's/[\/]/-/g' | sed 's/^/-/')
                local project_session_dir="$QWEN_CONFIG_DIR/projects/$encoded_name"

                if [ ! -d "$project_session_dir" ]; then
                    print_info "Creating project session: $encoded_name"
                    mkdir -p "$project_session_dir/chats"
                    chmod -R a+rwX "$project_session_dir" 2>/dev/null || true
                fi

                # Update mapping file
                local mapping_file="$QWEN_CONFIG_DIR/projects/.mapping.json"
                if [ -f "$mapping_file" ]; then
                    # Merge with existing mapping
                    local existing_mapping=$(cat "$mapping_file" 2>/dev/null || echo '{}')
                    # Simple merge - add new mapping
                    echo "$existing_mapping" | sed "s/}/, \"$encoded_name\": \"$CONTAINER_PATH\"}/" | sed 's/{,/{/' > "$mapping_file" 2>/dev/null || \
                        echo "{\"$encoded_name\": \"$CONTAINER_PATH\"}" > "$mapping_file"
                else
                    echo "{\"$encoded_name\": \"$CONTAINER_PATH\"}" > "$mapping_file"
                fi
                chmod a+rw "$mapping_file" 2>/dev/null || true
            else
                print_warning "Directory not found: $dir"
            fi
        done
    fi

    # Run container
    print_step "Starting container..."

    # Build docker run command
    local docker_cmd="docker run -d \
        --name \"$CONTAINER_NAME\" \
        -p \"${PORT}:3000\" \
        -e QWEN_CODE_LANG=zh \
        $VOLUMES \
        --restart unless-stopped \
        --health-cmd \"wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1\" \
        --health-interval 30s \
        --health-timeout 10s \
        --health-retries 3 \
        \"$IMAGE_NAME:latest\""

    # Execute docker command as specified user
    if [ "$(id -u)" -eq 0 ] && [ "$DOCKER_USER" != "root" ]; then
        print_info "Running Docker as user: $DOCKER_USER"
    fi
    run_docker "$docker_cmd" > /dev/null

    print_success "Container started"

    # Configure firewall if requested
    if [ "$CONFIGURE_FIREWALL" = true ]; then
        # Detect firewall if not already done
        if [ -z "$FIREWALL_TYPE" ] || [ "$FIREWALL_TYPE" = "" ]; then
            detect_firewall
        fi
        configure_firewall_port "$PORT" "tcp"
    fi

    # Wait for health check
    print_step "Waiting for service..."
    for i in {1..30}; do
        if curl -s "http://localhost:${PORT}/health" > /dev/null 2>&1; then
            print_success "Service is healthy and ready!"
            break
        fi
        sleep 1
    done

    # Print summary
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                          ║${NC}"
    echo -e "${GREEN}║         ${BOLD}Installation Complete!${NC}             ${GREEN}║${NC}"
    echo -e "${GREEN}║                                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}URL:${NC}     ${CYAN}http://localhost:${PORT}${NC}"
    echo ""
    echo -e "  ${BLUE}Commands:${NC}"
    echo -e "    Status:   docker ps -f name=$CONTAINER_NAME"
    echo -e "    Logs:     docker logs -f $CONTAINER_NAME"
    echo -e "    Stop:     docker stop $CONTAINER_NAME"
    echo -e "    Remove:   ./scripts/uninstall.sh"
    echo ""

    # Try to open browser (only if graphical environment available)
    if command -v open > /dev/null 2>&1; then
        sleep 1
        open "http://localhost:${PORT}" 2>/dev/null || true
    elif [ -n "$DISPLAY" ] && command -v xdg-open > /dev/null 2>&1; then
        sleep 1
        xdg-open "http://localhost:${PORT}" 2>/dev/null || true
    fi
}

# ============================================
# Entry Point
# ============================================

if $INTERACTIVE && [ -z "$PROJECT_DIRS" ]; then
    run_interactive
else
    # Non-interactive mode: auto-detect project directories for Docker user
    if [ -z "$PROJECT_DIRS" ]; then
        # Determine the home directory to search for projects
        SEARCH_HOME="$HOME"
        if [ "$(id -u)" -eq 0 ] && [ -n "$DOCKER_USER" ] && [ "$DOCKER_USER" != "root" ]; then
            SEARCH_HOME=$(eval echo "~$DOCKER_USER" 2>/dev/null || echo "$HOME")
        fi

        # Auto-detect common project directories
        for dir in "$SEARCH_HOME/workspace" "$SEARCH_HOME/projects" "$SEARCH_HOME/work" "$SEARCH_HOME/code" "$SEARCH_HOME/dev"; do
            if [ -d "$dir" ]; then
                if [ -n "$PROJECT_DIRS" ]; then
                    PROJECT_DIRS="$PROJECT_DIRS:$dir"
                else
                    PROJECT_DIRS="$dir"
                fi
            fi
        done

        if [ -n "$PROJECT_DIRS" ]; then
            print_info "Auto-detected project directories: ${PROJECT_DIRS//:/, }"
        fi
    fi
fi

install