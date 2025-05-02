#!/usr/bin/env bash

# Install script for Bailiff
# This script will install Bailiff and set it up for use

set -e

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default install location
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bailiff"
COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bailiff"

# Temporary directory for cloning
TMP_DIR=$(mktemp -d)
REPO_URL="https://github.com/livetheoogway/bailiff.git"

print_header() {
  echo -e "${BOLD}${BLUE}"
  echo "==============================================" 
  echo "  Bailiff - CLI Tool Manager Installation"
  echo "==============================================" 
  echo -e "${NC}"
}

print_step() {
  echo -e "${BOLD}${GREEN}==>${NC} $1"
}

print_info() {
  echo -e "${BLUE}INFO:${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}WARN:${NC} $1"
}

print_error() {
  echo -e "${RED}ERROR:${NC} $1"
}

cleanup() {
  print_step "Cleaning up temporary files"
  rm -rf "$TMP_DIR"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

main() {
  print_header

  # Check if zsh is installed
  if ! command -v zsh >/dev/null 2>&1; then
    print_error "Zsh is required for Bailiff. Please install zsh first."
    exit 1
  fi
  
  # Check if git is installed
  if ! command -v git >/dev/null 2>&1; then
    print_error "Git is required for installation. Please install git first."
    exit 1
  fi
  
  # Create directories
  print_step "Creating directories"
  mkdir -p "$INSTALL_DIR" "$COMPLETION_DIR" "$CACHE_DIR"
  
  # Clone repository
  print_step "Downloading Bailiff"
  git clone --depth=1 "$REPO_URL" "$TMP_DIR"
  
  # Copy files
  print_step "Installing Bailiff"
  cp "$TMP_DIR/bailiff.sh" "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/bailiff.sh"
  
  # Install completion
  if [[ -f "$TMP_DIR/completions/_bailiff" ]]; then
    print_step "Installing ZSH completion"
    cp "$TMP_DIR/completions/_bailiff" "$COMPLETION_DIR/"
  fi
  
  # Copy documentation
  print_step "Installing documentation"
  cp "$TMP_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true
  cp "$TMP_DIR/LICENSE" "$INSTALL_DIR/" 2>/dev/null || true
  
  # Check if bailiff is already in zshrc
  if grep -q "bailiff\.sh" "$HOME/.zshrc"; then
    print_info "Bailiff is already in your .zshrc"
  else
    print_step "Adding Bailiff to .zshrc"
    cat >> "$HOME/.zshrc" << EOF

# Bailiff configuration
source "$INSTALL_DIR/bailiff.sh"

# Add your tools with Bailiff
# Example:
# bailiff nvim
# bailiff htop
EOF
    print_info "Added Bailiff to .zshrc"
  fi
  
  # Success message
  echo
  echo -e "${BOLD}${GREEN}✓ Bailiff has been successfully installed!${NC}"
  echo
  echo -e "To start using Bailiff, either:"
  echo -e "  1. Restart your shell: ${BOLD}exec zsh${NC}"
  echo -e "  2. Source it manually: ${BOLD}source $INSTALL_DIR/bailiff.sh${NC}"
  echo
  echo -e "Then add the tools you want to summon in your .zshrc:"
  echo -e "  ${BOLD}bailiff nvim${NC}"
  echo -e "  ${BOLD}bailiff htop${NC}"
  echo
  echo -e "See the README for more options: ${BOLD}cat $INSTALL_DIR/README.md${NC}"
  echo
}

main "$@"