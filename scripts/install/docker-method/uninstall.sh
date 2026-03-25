#!/bin/bash

# ============================================
# Qwen Code Web UI - Uninstall Script
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
IMAGE_NAME="qwen-code-webui"
CONTAINER_NAME="qwen-code-webui"
REMOVE_FIREWALL=false
PORT=""
DOCKER_USER="${DOCKER_USER:-open-ace}"
FULL_CLEANUP=false

# Detected firewall info
OS_TYPE=""
FIREWALL_TYPE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            FULL_CLEANUP=true
            shift
            ;;
        --firewall)
            REMOVE_FIREWALL=true
            shift
            ;;
        --port)
            PORT="$2"
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
            echo "  --all             Remove container, image, and build cache"
            echo "  --firewall        Remove firewall rules"
            echo "  --port <port>     Port to remove firewall rule for (default: 3000)"
            echo "  -u, --user <user> User to run Docker commands (default: open-ace)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  DOCKER_USER       User to run Docker commands (default: open-ace)"
            echo ""
            echo "Default behavior:"
            echo "  - Stop and remove container"
            echo "  - Keep Docker image for faster redeploy"
            echo "  - Keep firewall rules"
            echo ""
            echo "Examples:"
            echo "  $0                      # Basic uninstall"
            echo "  $0 --all                # Full cleanup including image"
            echo "  $0 --firewall           # Also remove firewall rules"
            echo "  $0 -u myuser            # Run Docker as myuser"
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

print_step() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
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

# ============================================
# Firewall Detection Functions
# ============================================

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

detect_firewall() {
    detect_os

    case "$OS_TYPE" in
        macos)
            local fw_status
            fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "disabled")
            if echo "$fw_status" | grep -qi "enabled"; then
                FIREWALL_TYPE="socketfilterfw"
            elif pfctl -s info 2>/dev/null | grep -q "Enabled"; then
                FIREWALL_TYPE="pf"
            else
                FIREWALL_TYPE="socketfilterfw"
            fi
            ;;
        linux)
            if command -v ufw > /dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "active"; then
                FIREWALL_TYPE="ufw"
            elif command -v firewall-cmd > /dev/null 2>&1 && systemctl is-active firewalld > /dev/null 2>&1; then
                FIREWALL_TYPE="firewalld"
            elif command -v iptables > /dev/null 2>&1 && [ "$(iptables -S 2>/dev/null | grep -c 'ACCEPT\|DROP\|REJECT' || echo 0)" -gt 3 ]; then
                FIREWALL_TYPE="iptables"
            elif command -v nft > /dev/null 2>&1 && nft list ruleset 2>/dev/null | grep -q "chain"; then
                FIREWALL_TYPE="nftables"
            else
                FIREWALL_TYPE="none"
            fi
            ;;
        windows)
            FIREWALL_TYPE="netsh"
            ;;
        *)
            FIREWALL_TYPE="unknown"
            ;;
    esac
}

remove_firewall_port() {
    local port=$1
    local proto=${2:-tcp}

    print_info "Removing firewall rule for port $port..."

    case "$FIREWALL_TYPE" in
        ufw)
            if ufw status 2>/dev/null | grep -q "$port/$proto"; then
                if [ "$(id -u)" -ne 0 ]; then
                    sudo ufw delete allow "$port/$proto"
                else
                    ufw delete allow "$port/$proto"
                fi
                print_success "UFW rule removed for port $port"
            else
                print_info "No UFW rule found for port $port"
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
            else
                print_info "No firewalld rule found for port $port"
            fi
            ;;
        iptables)
            if iptables -L INPUT -n 2>/dev/null | grep -q "dpt:$port"; then
                if [ "$(id -u)" -ne 0 ]; then
                    sudo iptables -D INPUT -p $proto --dport $port -m state --state NEW -j ACCEPT 2>/dev/null || true
                else
                    iptables -D INPUT -p $proto --dport $port -m state --state NEW -j ACCEPT 2>/dev/null || true
                fi
                print_success "iptables rule removed for port $port"
            else
                print_info "No iptables rule found for port $port"
            fi
            ;;
        pf)
            local custom_conf="/etc/pf.anchors/qwen-code-webui"
            if [ -f "$custom_conf" ]; then
                if [ "$(id -u)" -ne 0 ]; then
                    sudo rm -f "$custom_conf"
                    sudo pfctl -ef /etc/pf.conf 2>/dev/null || true
                else
                    rm -f "$custom_conf"
                    pfctl -ef /etc/pf.conf 2>/dev/null || true
                fi
                print_success "pf rule removed"
            else
                print_info "No pf rule file found"
            fi
            ;;
        netsh)
            local rule_name="Qwen Code Web UI - Port $port"
            powershell.exe -Command "Remove-NetFirewallRule -DisplayName '$rule_name'" 2>/dev/null || true
            print_success "Windows Firewall rule removed for port $port"
            ;;
        *)
            print_info "Unknown firewall type, please manually remove rule for port $port"
            ;;
    esac
}

# ============================================
# Main Uninstall
# ============================================

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                          ║${NC}"
echo -e "${BLUE}║    ${BOLD}Qwen Code Web UI - Uninstall${NC}           ${BLUE}║${NC}"
echo -e "${BLUE}║                                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root and show Docker user
if [ "$(id -u)" -eq 0 ] && [ "$DOCKER_USER" != "root" ]; then
    print_info "Running as root, Docker commands will use user: $DOCKER_USER"
fi

# Stop and remove container
print_step "Stopping container..."
if run_docker "docker ps --format '{{.Names}}'" | grep -q "^${CONTAINER_NAME}$"; then
    run_docker "docker stop \"$CONTAINER_NAME\""
    print_success "Container stopped"
elif run_docker "docker ps -a --format '{{.Names}}'" | grep -q "^${CONTAINER_NAME}$"; then
    print_info "Container already stopped"
else
    print_info "No container found"
fi

# Remove container
print_step "Removing container..."
if run_docker "docker ps -a --format '{{.Names}}'" | grep -q "^${CONTAINER_NAME}$"; then
    run_docker "docker rm \"$CONTAINER_NAME\""
    print_success "Container removed"
else
    print_info "No container to remove"
fi

# Remove firewall rules if requested
print_step "Firewall rules..."
if [ "$REMOVE_FIREWALL" = true ]; then
    # Default port if not specified
    if [ -z "$PORT" ]; then
        PORT="3000"
    fi
    detect_firewall
    remove_firewall_port "$PORT" "tcp"
else
    print_info "Skipping firewall rules (use --firewall to remove)"
fi

# Full cleanup if requested
if [ "$FULL_CLEANUP" = true ]; then
    print_step "Full cleanup..."

    # Remove image
    print_info "Removing Docker image..."
    if docker image inspect "$IMAGE_NAME:latest" > /dev/null 2>&1; then
        docker rmi "$IMAGE_NAME:latest" 2>/dev/null || true
        docker rmi "$IMAGE_NAME:0.2.0" 2>/dev/null || true
        print_success "Image removed"
    else
        print_info "No image to remove"
    fi

    # Prune build cache
    print_info "Cleaning build cache..."
    docker builder prune -f --filter "label=stage=frontend-builder" 2>/dev/null || true
    docker builder prune -f --filter "label=stage=backend-builder" 2>/dev/null || true
    print_success "Build cache cleaned"
fi

# Print summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                          ║${NC}"
echo -e "${GREEN}║         ${BOLD}Uninstall Complete!${NC}                ${GREEN}║${NC}"
echo -e "${GREEN}║                                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo -e "  ${BOLD}Summary:${NC}"
if [ "$FULL_CLEANUP" = true ]; then
    echo -e "    Removed: container, image, build cache"
else
    echo -e "    Removed: container"
    echo -e "    Kept:    Docker image (use --all to remove)"
fi

if [ "$REMOVE_FIREWALL" = true ]; then
    echo -e "    Removed: firewall rule for port $PORT"
else
    echo -e "    Kept:    firewall rules (use --firewall to remove)"
fi

echo ""
echo -e "  ${BLUE}Reinstall:${NC} ./scripts/install.sh"
echo ""