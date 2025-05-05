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
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bailiff"

# Detect shell and set appropriate config file
detect_shell() {
  # First check if a specific shell was requested
  if [[ -n "$1" ]]; then
    echo "$1"
    return
  fi

  # Try to detect the current shell
  local current_shell
  current_shell=$(basename "$SHELL" 2>/dev/null || echo "unknown")
  
  # Fallback to checking process
  if [[ "$current_shell" == "unknown" ]]; then
    current_shell=$(ps -p $$ -o comm= 2>/dev/null | sed 's/-//' || echo "unknown")
  fi
  
  echo "$current_shell"
}

SHELL_TYPE=$(detect_shell "$1")
case "$SHELL_TYPE" in
  zsh)
    CONFIG_FILE="$HOME/.zshrc"
    COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
    ;;
  bash)
    CONFIG_FILE="$HOME/.bashrc"
    # For macOS, use .bash_profile if it exists
    if [[ "$(uname)" == "Darwin" ]] && [[ -f "$HOME/.bash_profile" ]]; then
      CONFIG_FILE="$HOME/.bash_profile"
    fi
    COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
    ;;
  ksh)
    CONFIG_FILE="$HOME/.kshrc"
    # Fallback to .profile if .kshrc doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
      CONFIG_FILE="$HOME/.profile"
    fi
    COMPLETION_DIR=""  # No completion for ksh yet
    ;;
  fish)
    CONFIG_FILE="$HOME/.config/fish/config.fish"
    COMPLETION_DIR="$HOME/.config/fish/completions"
    ;;
  *)
    # Default to bash if we can't detect
    CONFIG_FILE="$HOME/.bashrc"
    COMPLETION_DIR=""
    ;;
esac

# Temporary directory for cloning
TMP_DIR=$(mktemp -d)
REPO_URL="https://github.com/livetheoogway/bailiff.git"

# Create directories if they don't exist
mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null || true

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

  # Check if git is installed
  if ! command -v git >/dev/null 2>&1; then
    print_error "Git is required for installation. Please install git first."
    exit 1
  fi
  
  # Create directories
  print_step "Creating directories"
  mkdir -p "$INSTALL_DIR" "$CACHE_DIR"
  
  # Create completion directory if specified
  if [[ -n "$COMPLETION_DIR" ]]; then
    mkdir -p "$COMPLETION_DIR"
  fi
  
  # Clone repository
  print_step "Downloading Bailiff"
  git clone --depth=1 "$REPO_URL" "$TMP_DIR"
  
  # Copy files
  print_step "Installing Bailiff"
  cp "$TMP_DIR/bailiff.sh" "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/bailiff.sh"
  
  # Install completion
  if [[ -n "$COMPLETION_DIR" ]]; then
    case "$SHELL_TYPE" in
      zsh)
        if [[ -f "$TMP_DIR/completions/_bailiff" ]]; then
          print_step "Installing ZSH completion"
          cp "$TMP_DIR/completions/_bailiff" "$COMPLETION_DIR/"
        fi
        ;;
      bash)
        if [[ -f "$TMP_DIR/completions/bailiff.bash" ]]; then
          print_step "Installing Bash completion"
          cp "$TMP_DIR/completions/bailiff.bash" "$COMPLETION_DIR/bailiff"
        fi
        ;;
      fish)
        if [[ -f "$TMP_DIR/completions/bailiff.fish" ]]; then
          print_step "Installing Fish completion"
          cp "$TMP_DIR/completions/bailiff.fish" "$COMPLETION_DIR/bailiff.fish"
        fi
        
        # Also copy the command-not-found handler for reference
        if [[ -f "$TMP_DIR/completions/fish_command_not_found.fish" ]]; then
          print_step "Installing Fish command-not-found handler"
          mkdir -p "$HOME/.config/fish/functions" 2>/dev/null || true
          cp "$TMP_DIR/completions/fish_command_not_found.fish" "$HOME/.config/fish/functions/"
          print_info "Installed command-not-found handler to $HOME/.config/fish/functions/"
        fi
        ;;
    esac
  fi
  
  # Copy documentation
  print_step "Installing documentation"
  cp "$TMP_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true
  cp "$TMP_DIR/LICENSE" "$INSTALL_DIR/" 2>/dev/null || true
  
  # Check if bailiff is already in shell config
  if grep -q "bailiff\.sh" "$CONFIG_FILE" 2>/dev/null; then
    print_info "Bailiff is already in your $CONFIG_FILE"
  else
    print_step "Adding Bailiff to $CONFIG_FILE"
    
    case "$SHELL_TYPE" in
      fish)
        # Fish uses a different syntax for sourcing
        cat >> "$CONFIG_FILE" << EOF

# Bailiff configuration
source $INSTALL_DIR/bailiff.sh

# Add your tools with Bailiff
# Example:
# bailiff nvim
# bailiff htop
EOF
        ;;
      *)
        # Bash, ZSH, and KSH use similar syntax
        cat >> "$CONFIG_FILE" << EOF

# Bailiff configuration
source "$INSTALL_DIR/bailiff.sh"

# Add your tools with Bailiff
# Example:
# bailiff nvim
# bailiff htop
EOF
        ;;
    esac
    
    print_info "Added Bailiff to $CONFIG_FILE"
  fi
  
  # Success message
  echo
  echo -e "${BOLD}${GREEN}✓ Bailiff has been successfully installed!${NC}"
  echo
  echo -e "To start using Bailiff, either:"
  echo -e "  1. Restart your shell: ${BOLD}exec $SHELL_TYPE${NC}"
  echo -e "  2. Source it manually: ${BOLD}source $INSTALL_DIR/bailiff.sh${NC}"
  echo
  echo -e "Then add the tools you want to summon in your $CONFIG_FILE:"
  echo -e "  ${BOLD}bailiff nvim${NC}"
  echo -e "  ${BOLD}bailiff htop${NC}"
  echo
  
  # Shell-specific notes
  case "$SHELL_TYPE" in
    fish)
      echo -e "${YELLOW}Note:${NC} For Fish shell, auto-summoning requires manual setup."
      echo -e "Create a file at ~/.config/fish/functions/fish_command_not_found.fish with:"
      echo -e "  ${BOLD}function fish_command_not_found${NC}"
      echo -e "  ${BOLD}    bailiff \$argv[1]${NC}"
      echo -e "  ${BOLD}    if type -q \$argv[1]${NC}"
      echo -e "  ${BOLD}        eval \$argv${NC}"
      echo -e "  ${BOLD}    end${NC}"
      echo -e "  ${BOLD}end${NC}"
      echo
      ;;
    bash)
      if [[ "$(uname)" == "Ubuntu" ]] || [[ "$(uname)" == "Debian" ]]; then
        echo -e "${YELLOW}Note:${NC} For Bash on Ubuntu/Debian, you may need to install the 'command-not-found' package"
        echo -e "for the auto-summoning feature to work properly:"
        echo -e "  ${BOLD}sudo apt-get install command-not-found${NC}"
        echo
      fi
      ;;
  esac
  
  echo -e "See the README for more options: ${BOLD}cat $INSTALL_DIR/README.md${NC}"
  echo
}

main "$@"
