#!/bin/bash

# Zabbix Agent 2 Installation Script for CentOS/RHEL
# Following official Zabbix documentation process

# Configuration parameters
LOG_FILE="/var/log/zabbix/zabbix_agentd.log"
SCRIPT_LOG_FILE="/var/log/zabbix_installation.log"
ALLOW_KEY=""
SERVER="192.168.6.76"
SERVER_ACTIVE="::1"
HOSTNAME="myHost"
CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"
# Set to true to install plugins
INSTALL_PLUGINS=true

# Create a function for logging
log() {
    local message="$1"
    local level="${2:-INFO}"
    
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    log_message="[$timestamp] [$level] $message"
    
    # Output to console with colors
    case "$level" in
        "INFO")
            echo -e "\e[32m$log_message\e[0m"
            ;;
        "WARN")
            echo -e "\e[33m$log_message\e[0m"
            ;;
        "ERROR")
            echo -e "\e[31m$log_message\e[0m"
            ;;
    esac
    
    # Ensure log directory exists
    log_dir=$(dirname "$SCRIPT_LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    
    # Write to log file
    echo "$log_message" >> "$SCRIPT_LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "This script must be run as root" "ERROR"
        exit 1
    fi
}

# Function to detect OS version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        log "Detected OS: $OS $VERSION"
        
        # Extract major version
        MAJOR_VERSION=$(echo $VERSION_ID | cut -d. -f1)
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | cut -d' ' -f1)
        VERSION=$(cat /etc/redhat-release | grep -o "[0-9]*\.[0-9]*" | head -n1)
        log "Detected OS from redhat-release: $OS $VERSION"
        
        # Extract major version
        MAJOR_VERSION=$(echo $VERSION | cut -d. -f1)
    else
        log "Unsupported OS. This script is designed for CentOS/RHEL" "ERROR"
        exit 1
    fi
    
    # Check if it's CentOS or RHEL
    if [[ $OS != *"CentOS"* ]] && [[ $OS != *"Red Hat"* ]]; then
        log "This script supports CentOS and Red Hat Linux only. Detected OS: $OS" "WARN"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation aborted by user" "INFO"
            exit 1
        fi
    fi
}

# Function to uninstall existing Zabbix Agent
uninstall_zabbix_agent() {
    log "Checking for existing Zabbix installations..."
    
    # Check if zabbix packages are installed
    if rpm -q zabbix-agent > /dev/null || rpm -q zabbix-agent2 > /dev/null; then
        log "Found existing Zabbix Agent installation"
        
        # Stop the service if running
        if systemctl is-active --quiet zabbix-agent; then
            log "Stopping zabbix-agent service..."
            systemctl stop zabbix-agent
        fi
        
        if systemctl is-active --quiet zabbix-agent2; then
            log "Stopping zabbix-agent2 service..."
            systemctl stop zabbix-agent2
        fi
        
        # Disable the service
        if systemctl is-enabled --quiet zabbix-agent 2>/dev/null; then
            log "Disabling zabbix-agent service..."
            systemctl disable zabbix-agent
        fi
        
        if systemctl is-enabled --quiet zabbix-agent2 2>/dev/null; then
            log "Disabling zabbix-agent2 service..."
            systemctl disable zabbix-agent2
        fi
        
        # Remove packages
        log "Removing zabbix-agent packages..."
        dnf remove -y zabbix-agent zabbix-agent2 zabbix-agent2-plugin-* 2>/dev/null
        
        # Remove configuration files
        log "Removing configuration files..."
        rm -f /etc/zabbix/zabbix_agentd.conf 2>/dev/null
        rm -f /etc/zabbix/zabbix_agent2.conf 2>/dev/null
        
        # Remove log files
        log "Cleaning up log files..."
        rm -f /var/log/zabbix/zabbix_agentd.log 2>/dev/null
        
        log "Uninstallation completed"
    else
        log "No existing Zabbix installation found. Skipping uninstallation."
    fi
}

# Function to configure EPEL repository exclusions
configure_epel() {
    log "Checking for EPEL repository..."
    
    if [ -f /etc/yum.repos.d/epel.repo ]; then
        log "EPEL repository found, configuring to exclude Zabbix packages"
        
        # Check if exclusion is already configured
        if grep -q "excludepkgs=zabbix\*" /etc/yum.repos.d/epel.repo; then
            log "EPEL exclusion for Zabbix packages already configured"
        else
            # Add exclusion for Zabbix packages
            sed -i '/\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
            log "Added Zabbix package exclusion to EPEL repository configuration"
        fi
    else
        log "EPEL repository not found. Skipping configuration."
    fi
}

# Function to install Zabbix repository
install_repo() {
    log "Setting up Zabbix repository..."
    
    # First configure EPEL to exclude Zabbix packages
    configure_epel
    
    # Determine the correct repository URL based on OS and version
    local repo_url=""
    
    if [[ $OS == *"CentOS"* ]]; then
        repo_url="https://repo.zabbix.com/zabbix/7.0/centos/${MAJOR_VERSION}/x86_64/zabbix-release-latest-7.0.el${MAJOR_VERSION}.noarch.rpm"
    elif [[ $OS == *"Red Hat"* ]]; then
        repo_url="https://repo.zabbix.com/zabbix/7.0/rhel/${MAJOR_VERSION}/x86_64/zabbix-release-latest-7.0.el${MAJOR_VERSION}.noarch.rpm"
    else
        # Default to CentOS repository if OS is not identified
        repo_url="https://repo.zabbix.com/zabbix/7.0/centos/${MAJOR_VERSION}/x86_64/zabbix-release-latest-7.0.el${MAJOR_VERSION}.noarch.rpm"
    fi
    
    log "Using repository URL: $repo_url"
    
    # Download and install the repository
    if rpm -Uvh $repo_url; then
        log "Zabbix repository installed successfully"
    else
        log "Failed to install Zabbix repository" "ERROR"
        exit 1
    fi
    
    # Clean dnf cache as per documentation
    dnf clean all
    log "Package cache cleaned"
}

# Function to install Zabbix Agent 2
install_zabbix_agent2() {
    log "Installing Zabbix Agent 2..."
    
    # Install Zabbix Agent 2
    if dnf install -y zabbix-agent2; then
        log "Zabbix Agent 2 installed successfully"
    else
        log "Failed to install Zabbix Agent 2" "ERROR"
        exit 1
    fi
    
    # Install plugins if enabled
    if [ "$INSTALL_PLUGINS" = true ]; then
        log "Installing Zabbix Agent 2 plugins..."
        if dnf install -y zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql; then
            log "Zabbix Agent 2 plugins installed successfully"
        else
            log "Failed to install some Zabbix Agent 2 plugins" "WARN"
        fi
    fi
    
    # Configure Zabbix Agent 2
    configure_zabbix_agent2
    
    # Start and enable Zabbix Agent 2 service
    log "Starting Zabbix Agent 2 service..."
    systemctl restart zabbix-agent2
    
    log "Enabling Zabbix Agent 2 to start at system boot..."
    systemctl enable zabbix-agent2
    
    # Verify service is running
    if systemctl is-active --quiet zabbix-agent2; then
        log "Zabbix Agent 2 service is running"
    else
        log "Zabbix Agent 2 service failed to start" "ERROR"
        systemctl status zabbix-agent2
        exit 1
    fi
}

# Function to configure Zabbix Agent 2
configure_zabbix_agent2() {
    log "Configuring Zabbix Agent 2..."
    
    # Ensure log directory exists
    log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        chown zabbix:zabbix "$log_dir"
    fi
    
    # Backup original config if it exists
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        log "Created backup of original configuration"
    fi
    
    # Create new config file
    cat > "$CONFIG_FILE" << EOL
# Zabbix Agent 2 configuration
# Generated by installation script on $(date)

LogFile=$LOG_FILE
Server=$SERVER
ServerActive=$SERVER_ACTIVE
Hostname=$HOSTNAME
EOL

    # Add AllowKey if it's defined
    if [ ! -z "$ALLOW_KEY" ]; then
        echo "AllowKey=$ALLOW_KEY" >> "$CONFIG_FILE"
    fi
    
    # Add default deny rule
    echo "DenyKey=vfs.file.contents[/etc/passwd]" >> "$CONFIG_FILE"
    
    # Set proper permissions
    chown zabbix:zabbix "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    
    log "Zabbix Agent 2 configured successfully"
}

# Function to configure firewall
configure_firewall() {
    log "Checking firewall status..."
    
    # Check if firewalld is installed and running
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        log "Firewalld is active, adding Zabbix Agent port to allowed list..."
        
        # Add zabbix port (10050) to firewall
        if firewall-cmd --permanent --add-port=10050/tcp; then
            firewall-cmd --reload
            log "Added Zabbix Agent port 10050/tcp to firewall"
        else
            log "Failed to add Zabbix Agent port to firewall" "WARN"
        fi
    else
        log "Firewalld is not running or not installed. Skipping firewall configuration."
    fi
}

# Function to verify installation
verify_installation() {
    log "Verifying Zabbix Agent 2 installation..."
    
    # Check if service is running
    if ! systemctl is-active --quiet zabbix-agent2; then
        log "Zabbix Agent 2 service is not running" "ERROR"
        systemctl status zabbix-agent2
        return 1
    fi
    
    # Check if configuration file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        log "Configuration file not found: $CONFIG_FILE" "ERROR"
        return 1
    fi
    
    # Check if agent is listening on port
    if ! ss -tunlp | grep 10050 > /dev/null; then
        log "Zabbix Agent is not listening on port 10050" "WARN"
    else
        log "Zabbix Agent is listening on port 10050"
    fi
    
    # Try to get agent version
    version=$(zabbix_agent2 -V 2>/dev/null | head -n 1)
    if [ -n "$version" ]; then
        log "Installed Zabbix Agent version: $version"
    else
        log "Could not determine Zabbix Agent version" "WARN"
    fi
    
    log "Verification completed"
    return 0
}

# Main execution
main() {
    log "=== Starting Zabbix Agent 2 Installation Script ==="
    
    # Check if running as root
    check_root
    
    # Detect OS
    detect_os
    
    # Uninstall existing Zabbix Agent
    uninstall_zabbix_agent
    
    # Install Zabbix repository
    install_repo
    
    # Install new Zabbix Agent 2
    install_zabbix_agent2
    
    # Configure firewall
    configure_firewall
    
    # Verify installation
    verify_installation
    
    log "=== Zabbix Agent 2 Installation Script Completed ==="
}

# Run the main function
main