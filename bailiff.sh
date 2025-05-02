#!/usr/bin/env zsh

# bailiff.sh - A tool to summon CLI tools when needed
# Version: 1.0.0
# License: MIT

# =====================================================
# Configuration
# =====================================================

# Default settings that can be overridden by user
: ${BAILIFF_CACHE_DIR:="${XDG_CACHE_HOME:-$HOME/.cache}/bailiff"}
: ${BAILIFF_CACHE_EXPIRY:=86400}  # 24 hours in seconds
: ${BAILIFF_LOG_FILE:="$BAILIFF_CACHE_DIR/summons.log"}
: ${BAILIFF_PACKAGE_MANAGER:="auto"}  # auto, brew, apt, yum, pacman
: ${BAILIFF_QUIET:=0}  # Set to 1 to suppress most messages
: ${BAILIFF_VERBOSE:=0}  # Set to 1 to show more details (e.g., already installed)
: ${BAILIFF_AUTO_SUMMON:=1}  # Set to 0 to disable auto-summoning when command not found
: ${BAILIFF_INSTALLED_FILE:="$BAILIFF_CACHE_DIR/installed_tools"}

# Create cache directory if it doesn't exist
mkdir -p "$BAILIFF_CACHE_DIR"
touch "$BAILIFF_INSTALLED_FILE"

# Map for custom binary names to package names
typeset -A BAILIFF_TOOL_MAP
# Default mappings
BAILIFF_TOOL_MAP=(
  # Common tool mappings (binary → package)
  "nvim" "neovim"
  "python" "python3"
  "rg" "ripgrep"
  "fd" "fd-find"
)

# Array to store summoned tools
typeset -a BAILIFF_SUMMONED_TOOLS

# =====================================================
# Internal Functions
# =====================================================

# Only print if not in quiet mode
_bailiff_print() {
  if [[ "$BAILIFF_QUIET" -eq 0 ]]; then
    echo "$@"
  fi
}

# Log operations
_bailiff_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$BAILIFF_LOG_FILE"
}

# Detect package manager
_bailiff_detect_package_manager() {
  if [[ "$BAILIFF_PACKAGE_MANAGER" != "auto" ]]; then
    echo "$BAILIFF_PACKAGE_MANAGER"
    return
  fi
  
  if command -v brew &> /dev/null; then
    echo "brew"
  elif command -v apt-get &> /dev/null; then
    echo "apt"
  elif command -v dnf &> /dev/null; then
    echo "dnf"
  elif command -v yum &> /dev/null; then
    echo "yum"
  elif command -v pacman &> /dev/null; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Install a tool
_bailiff_install_tool() {
  local tool=$1
  local package=${2:-$tool}
  local manager=${3:-$(_bailiff_detect_package_manager)}
  
  _bailiff_print "🧰 Bailiff: Summoning '$tool' via $manager..."
  _bailiff_log "Installing $package ($tool) via $manager"
  
  case "$manager" in
    brew)
      brew install "$package"
      ;;
    apt)
      sudo apt-get update && sudo apt-get install -y "$package"
      ;;
    dnf)
      sudo dnf install -y "$package"
      ;;
    yum)
      sudo yum install -y "$package"
      ;;
    pacman)
      sudo pacman -S --noconfirm "$package"
      ;;
    *)
      _bailiff_print "🚫 Bailiff: Unsupported package manager '$manager'. Please install '$package' manually."
      return 1
      ;;
  esac
  
  local retval=$?
  if [[ $retval -eq 0 ]]; then
    _bailiff_print "✅ Bailiff: '$tool' has been successfully summoned!"
    echo "$tool" >> "$BAILIFF_INSTALLED_FILE"
    return 0
  else
    _bailiff_print "❌ Bailiff: Failed to summon '$tool'. See $BAILIFF_LOG_FILE for details."
    return 1
  fi
}

# Check if tool cache is valid
_bailiff_check_cache() {
  local tool=$1
  local cache_file="$BAILIFF_CACHE_DIR/${tool}_cache"
  
  if [[ -f "$cache_file" ]]; then
    local cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file")))
    
    if [[ $cache_age -lt $BAILIFF_CACHE_EXPIRY ]]; then
      # Cache is valid
      return 0
    fi
  fi
  
  # Cache invalid or doesn't exist
  return 1
}

# Mark tool as checked in cache
_bailiff_update_cache() {
  local tool=$1
  touch "$BAILIFF_CACHE_DIR/${tool}_cache"
}

# Check if a tool is installed
_bailiff_is_installed() {
  local tool=$1
  command -v "$tool" &> /dev/null
}

# =====================================================
# Main Function
# =====================================================

# Main function to summon a tool
bailiff() {
  # Help message if no arguments
  if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
bailiff - A tool to summon CLI tools when needed

Usage:
  bailiff [PACKAGE_MANAGER] TOOL [PACKAGE]  # Summon a tool (install if not present)
  bailiff -x TOOL                           # Verbose mode, shows already installed tools
  bailiff --list                            # List all summoned tools
  bailiff --clear-cache                     # Clear the cache
  bailiff --version                         # Show version
  bailiff --help                            # Show this help

Examples:
  bailiff nvim                    # Will install 'neovim' package for 'nvim' command
  bailiff brew antibody           # Specify package manager (brew, apt, yum, pacman)
  bailiff brew rg ripgrep         # Specify both package manager and custom package name
  
Configuration (add to your .zshrc before sourcing bailiff.sh):
  BAILIFF_CACHE_DIR="$HOME/.cache/bailiff"  # Cache directory
  BAILIFF_CACHE_EXPIRY=86400                # Cache expiry in seconds (24h)
  BAILIFF_QUIET=0                           # Set to 1 to silence messages
  BAILIFF_VERBOSE=0                         # Set to 1 to always show "already installed" messages
  BAILIFF_AUTO_SUMMON=1                     # Auto-install missing commands
  
  # Custom mappings from command to package name
  BAILIFF_TOOL_MAP+=(
    "custom-tool" "actual-package-name"
  )
EOF
    return 0
  fi
  
  # Handle special commands
  case "$1" in
    --version|-v)
      echo "bailiff v1.0.0"
      return 0
      ;;
    --list|-l)
      if [[ -f "$BAILIFF_INSTALLED_FILE" ]]; then
        _bailiff_print "🧰 Tools summoned by Bailiff:"
        cat "$BAILIFF_INSTALLED_FILE" | sort | uniq
      else
        _bailiff_print "No tools have been summoned yet."
      fi
      return 0
      ;;
    --clear-cache|-c)
      rm -f "$BAILIFF_CACHE_DIR"/*_cache
      _bailiff_print "🧹 Bailiff: Cache cleared"
      return 0
      ;;
    -x|--verbose)
      # Enable verbose mode for this call
      BAILIFF_VERBOSE=1
      # Shift the arguments to process the next one
      shift
      # If no more arguments, show help
      if [[ $# -eq 0 ]]; then
        bailiff --help
        return 0
      fi
      ;;
  esac
  
  local package_manager=""
  local tool=""
  local package=""
  
  # Parse arguments - detect if first arg is a package manager
  if [[ "$1" == "brew" || "$1" == "apt" || "$1" == "dnf" || "$1" == "yum" || "$1" == "pacman" ]]; then
    package_manager="$1"
    if [[ $# -lt 2 ]]; then
      _bailiff_print "❌ Bailiff: No tool specified after package manager."
      return 1
    fi
    tool="$2"
    package="${3:-$tool}"
    _bailiff_print "Using package manager: $package_manager"
  else
    tool="$1"
    package="${2:-$tool}"
    package_manager=$(_bailiff_detect_package_manager)
  fi
  
  # Check if we have a mapping for this tool
  if [[ -n "${BAILIFF_TOOL_MAP[$tool]}" && -z "$3" ]]; then
    package="${BAILIFF_TOOL_MAP[$tool]}"
  fi
  
  # Add to summoned tools list
  BAILIFF_SUMMONED_TOOLS+=("$tool")
  
  # Check if already installed
  if _bailiff_is_installed "$tool"; then
    _bailiff_update_cache "$tool"
    # Only show "already installed" message in verbose mode with -x flag
    if [[ "$BAILIFF_VERBOSE" -eq 1 ]]; then
      _bailiff_print "✅ Bailiff: Tool '$tool' is already installed."
    fi
    return 0
  fi
  
  # Check cache
  if _bailiff_check_cache "$tool"; then
    # Tool was checked recently and still isn't installed
    _bailiff_print "🔍 Bailiff: Tool '$tool' was checked recently and is not installed."
    return 1
  fi
  
  # Install the tool
  _bailiff_install_tool "$tool" "$package" "$package_manager"
  local result=$?
  
  # Update cache regardless of installation result
  _bailiff_update_cache "$tool"
  
  return $result
}

# Function to handle command not found
bailiff_command_not_found_handler() {
  local cmd=$1
  
  # Check if auto-summon is enabled and if the command is in our list
  if [[ "$BAILIFF_AUTO_SUMMON" -eq 1 && " ${BAILIFF_SUMMONED_TOOLS[@]} " =~ " ${cmd} " ]]; then
    _bailiff_print "🔍 Bailiff: Command '$cmd' not found. Attempting to summon..."
    
    if bailiff "$cmd"; then
      # Run the command if installation succeeded
      _bailiff_print "🚀 Bailiff: Running '$cmd $@'..."
      "$cmd" "${@:2}"
      return $?
    fi
  fi
  
  # Fallback to system handler if we couldn't resolve it
  if type command_not_found_handler 2>/dev/null | grep -q function; then
    command_not_found_handler "$@"
  else
    echo "zsh: command not found: $cmd" >&2
    return 127
  fi
}

# =====================================================
# Setup
# =====================================================

# Detect if being sourced or executed directly
if [[ "${ZSH_EVAL_CONTEXT:-}" == *:file:* ]]; then
  # Being sourced in ZSH
  SOURCED=1
elif [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Being sourced in Bash
  SOURCED=1
else
  # Being executed directly
  SOURCED=0
fi

# Set up if sourced
if [[ "$SOURCED" -eq 1 ]]; then
  # Hook into ZSH command not found
  if [[ "$BAILIFF_AUTO_SUMMON" -eq 1 ]]; then
    # Backup original handler if it exists
    if typeset -f command_not_found_handler > /dev/null; then
      functions[original_command_not_found_handler]=$functions[command_not_found_handler]
    fi
    
    # Override command_not_found_handler
    command_not_found_handler() {
      bailiff_command_not_found_handler "$@"
    }
  fi
  
  # Return success when sourced
  return 0
else
  # If executed directly, run the bailiff command with arguments
  bailiff "$@"
  exit $?
fi