#!/bin/bash

# Ubuntu Workstation Configuration Script (2014,  Ubuntu 14.04 LTS)
# Run this script with sudo privileges: sudo ./configure_workstation.sh

# Exit on error
set -e

# Log function for better output
log() {
    echo "[INFO] $1"
}

# Error function
error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
fi

# Update and upgrade the system
log "Updating and upgrading the system..."
apt-get update && apt-get upgrade -y || error "Failed to update/upgrade system"

# Install essential tools
log "Installing essential tools..."
apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    software-properties-common || error "Failed to install essential tools"

# Install development tools (Python, Ruby, etc.)
log "Installing development tools..."

# Python (Python 3 was less common in 2014, but included for flexibility)
apt-get install -y python python-pip python3 python3-pip || error "Failed to install Python"
pip install --upgrade pip

# Ruby (popular for web dev in 2014)
apt-get install -y ruby rubygems || error "Failed to install Ruby"
gem install bundler

# Install Node.js (using a 2014-compatible method)
log "Installing Node.js..."
curl -sL https://deb.nodesource.com/setup_0.10 | bash -
apt-get install -y nodejs || error "Failed to install Node.js"

# Install Docker (early versions available in 2014)
log "Installing Docker..."
apt-get install -y docker.io || error "Failed to install Docker"
usermod -aG docker $SUDO_USER
service docker start

# Install Sublime Text 2 (popular in 2014)
log "Installing Sublime Text 2..."
add-apt-repository -y ppa:webupd8team/sublime-text-2
apt-get update
apt-get install -y sublime-text || error "Failed to install Sublime Text 2"

# Configure Git
log "Configuring Git..."
read -p "Enter your Git username: " git_username
read -p "Enter your Git email: " git_email
sudo -u $SUDO_USER git config --global user.name "$git_username"
sudo -u $SUDO_USER git config --global user.email "$git_email"
sudo -u $SUDO_USER git config --global core.editor "vim"

# Install and configure UFW (Uncomplicated Firewall)
log "Configuring firewall..."
apt-get install -y ufw || error "Failed to install UFW"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw enable
service ufw start

# Optimize swap (for systems with low RAM)
log "Configuring swap..."
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

# Install Unity Tweak Tool (for Ubuntu 14.04's Unity desktop)
log "Installing Unity Tweak Tool..."
apt-get install -y unity-tweak-tool || error "Failed to install Unity Tweak Tool"
sudo -u $SUDO_USER gsettings set com.canonical.Unity.Launcher launcher-position Bottom
sudo -u $SUDO_USER gsettings set org.gnome.desktop.interface clock-show-date true

# Clean up
log "Cleaning up..."
apt-get autoremove -y
apt-get autoclean

log "Workstation configuration completed successfully!"
