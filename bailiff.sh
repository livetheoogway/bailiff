#!/usr/bin/env bash

# bailiff.sh - A tool to summon CLI tools when needed
# Version: 1.0.6
# Author: tushar.naik
# License: MIT

# =====================================================
# Determine if being executed or sourced
# =====================================================
# This needs to be at the very beginning of the file
_BAILIFF_SOURCED=0
if [[ -n $ZSH_EVAL_CONTEXT && $ZSH_EVAL_CONTEXT =~ :file$ ]]; then
  _BAILIFF_SOURCED=1
elif [[ -n $BASH_VERSION && $0 != "$BASH_SOURCE" ]]; then
  _BAILIFF_SOURCED=1
elif [[ -n $KSH_VERSION && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]]; then
  _BAILIFF_SOURCED=1
elif [[ -n $FISH_VERSION ]]; then
  # Fish has status --is-sourced but it's not available in all versions
  # This is a workaround that should work in most cases
  _BAILIFF_SOURCED=1
fi

# Detect current shell
_BAILIFF_SHELL="unknown"
if [[ -n $ZSH_VERSION ]]; then
  _BAILIFF_SHELL="zsh"
elif [[ -n $BASH_VERSION ]]; then
  _BAILIFF_SHELL="bash"
elif [[ -n $KSH_VERSION ]]; then
  _BAILIFF_SHELL="ksh"
elif [[ -n $FISH_VERSION ]]; then
  _BAILIFF_SHELL="fish"
fi

# =====================================================
# Configuration
# =====================================================

# Default settings that can be overridden by user
: ${BAILIFF_CACHE_DIR:="${XDG_CACHE_HOME:-$HOME/.cache}/bailiff"}
: ${BAILIFF_CACHE_EXPIRY:=2592000}  # 30 days in seconds
: ${BAILIFF_LOG_FILE:="$BAILIFF_CACHE_DIR/summons.log"}
: ${BAILIFF_PACKAGE_MANAGER:="auto"}  # auto, brew, apt, yum, pacman
: ${BAILIFF_QUIET:=1}  # Set to 1 to suppress most messages
: ${BAILIFF_VERBOSE:=0}  # Set to 1 to show more details (e.g., already installed)
: ${BAILIFF_AUTO_SUMMON:=1}  # Set to 0 to disable auto-summoning when command not found
: ${BAILIFF_INSTALLED_FILE:="$BAILIFF_CACHE_DIR/installed_tools"}

# Create cache directory if it doesn't exist
if [[ ! -d "$BAILIFF_CACHE_DIR" ]]; then
  mkdir -p "$BAILIFF_CACHE_DIR"
fi
if [[ ! -f "$BAILIFF_INSTALLED_FILE" ]]; then
  touch "$BAILIFF_INSTALLED_FILE"
fi

# Map for custom binary names to package names
if [[ "$_BAILIFF_SHELL" == "zsh" ]]; then
  typeset -A BAILIFF_TOOL_MAP
  # Default mappings
  BAILIFF_TOOL_MAP=(
    "nvim" "neovim"
    "python" "python3"
    "rg" "ripgrep"
    "fd" "fd-find"
  )
else
  # For bash and other shells, use associative array if supported
  if [[ "$_BAILIFF_SHELL" == "bash" ]] && (( BASH_VERSINFO[0] >= 4 )); then
    declare -A BAILIFF_TOOL_MAP
    # Default mappings
    BAILIFF_TOOL_MAP=( 
      ["nvim"]="neovim"
      ["python"]="python3"
      ["rg"]="ripgrep"
      ["fd"]="fd-find"
    )
  else
    # Fallback for shells without associative arrays
    # We'll use a function to emulate the behavior
    BAILIFF_TOOL_MAP_KEYS="nvim python rg fd"
    
    _bailiff_get_package() {
      local tool=$1
      case "$tool" in
        nvim) echo "neovim" ;;
        python) echo "python3" ;;
        rg) echo "ripgrep" ;;
        fd) echo "fd-find" ;;
        *) echo "$tool" ;;
      esac
    }
  fi
fi

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

# Print help message
_bailiff_help() {
  cat <<EOF
bailiff - A tool to summon CLI tools when needed

Usage:
  bailiff [PACKAGE_MANAGER] TOOL [PACKAGE]  # Summon a tool (install if not present)
  bailiff -x TOOL                           # Verbose mode, shows already installed tools
  bailiff --force TOOL                      # Force check/install regardless of cache
  bailiff --list                            # List all summoned tools
  bailiff --clear-cache                     # Clear the cache
  bailiff --version                         # Show version
  bailiff --help                            # Show this help

Examples:
  bailiff nvim                    # Will install 'neovim' package for 'nvim' command
  bailiff brew antibody           # Specify package manager (brew, apt, yum, pacman)
  bailiff brew rg ripgrep         # Specify both package manager and custom package name
  
Configuration (add to your shell config file before sourcing bailiff.sh):
  # For zsh: ~/.zshrc, bash: ~/.bashrc, fish: ~/.config/fish/config.fish, etc.
  BAILIFF_CACHE_DIR="$HOME/.cache/bailiff"  # Cache directory
  BAILIFF_CACHE_EXPIRY=2592000              # Cache expiry in seconds (default 30d)
  BAILIFF_QUIET=0                           # Set to 1 to silence messages
  BAILIFF_VERBOSE=0                         # Set to 1 to always show "already installed" messages
  BAILIFF_AUTO_SUMMON=1                     # Auto-install missing commands

  # Custom mappings from command to package name
  # For example, to map 'custom-tool' to 'actual-package-name':
  BAILIFF_TOOL_MAP_KEYS="nvim python rg fd custom-tool"
  BAILIFF_TOOL_MAP_custom_tool="actual-package-name"
EOF
}

# Function to handle command not found
_bailiff_command_not_found_handler() {
  local cmd=$1
  
  # Check if auto-summon is enabled (removed check for command in list to try installing any command)
  if [[ "$BAILIFF_AUTO_SUMMON" -eq 1 ]]; then
    _bailiff_print "🔍 Bailiff: Command '$cmd' not found. Attempting to summon..."
    
    if _bailiff_install_tool "$cmd"; then
      # Run the command if installation succeeded
      _bailiff_print "🚀 Bailiff: Running '$cmd $@'..."
      "$cmd" "${@:2}" 
      return $?
    fi
  fi
  
  # Fallback to system handler if we couldn't resolve it
  case "$_BAILIFF_SHELL" in
    zsh)
      if typeset -f original_command_not_found_handler > /dev/null; then
        original_command_not_found_handler "$@"
      else
        echo "zsh: command not found: $cmd" >&2
        return 127
      fi
      ;;
    bash)
      if declare -F original_command_not_found_handle > /dev/null; then
        original_command_not_found_handle "$@"
      else
        echo "bash: command not found: $cmd" >&2
        return 127
      fi
      ;;
    *)
      echo "$_BAILIFF_SHELL: command not found: $cmd" >&2
      return 127
      ;;
  esac
}

# =====================================================
# Main Function
# =====================================================

# Main function to summon a tool
bailiff() {
  # No arguments given
  if [[ $# -eq 0 ]]; then
    # Only show help if not being sourced or if explicitly called with --help
    if [[ $_BAILIFF_SOURCED -eq 0 ]]; then
      _bailiff_help
    fi
    return 0
  fi
  
  # Handle special commands
  case "$1" in
    --help|-h)
      _bailiff_help
      return 0
      ;;
    --version|-v)
      echo "bailiff v1.0.6"
      return 0
      ;;
    --list|-l)
      if [[ -f "$BAILIFF_INSTALLED_FILE" && -s "$BAILIFF_INSTALLED_FILE" ]]; then
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
  esac
  
  local package_manager=""
  local tool=""
  local package=""
  local force_check=0
  local verbose_mode=0
  local i=0
  local arg=""
  
  # Process all arguments to find flags
  for arg in "$@"; do
    if [[ "$arg" == "--force" || "$arg" == "-f" ]]; then
      force_check=1
    elif [[ "$arg" == "-x" || "$arg" == "--verbose" ]]; then
      verbose_mode=1
    fi
  done
  
  # If verbose mode is enabled, set the global flag
  if [[ "$verbose_mode" -eq 1 ]]; then
    BAILIFF_VERBOSE=1
  fi
  
  # Extract the command and package from the arguments
  # First, check if the first argument is a package manager
  if [[ "$1" =~ ^(brew|apt|dnf|yum|pacman)$ ]]; then
    package_manager="$1"
    shift
    
    # Now find the first non-flag argument for the tool name
    for arg in "$@"; do
      if [[ "$arg" != "--force" && "$arg" != "-f" && 
            "$arg" != "-x" && "$arg" != "--verbose" ]]; then
        tool="$arg"
        break
      fi
    done
    
    if [[ -z "$tool" ]]; then
      _bailiff_print "❌ Bailiff: No tool specified after package manager."
      return 1
    fi
    
    _bailiff_print "Using package manager: $package_manager"
  else
    # Find the first non-flag argument for the tool name
    for arg in "$@"; do
      if [[ "$arg" != "--force" && "$arg" != "-f" && 
            "$arg" != "-x" && "$arg" != "--verbose" ]]; then
        tool="$arg"
        break
      fi
    done
    
    if [[ -z "$tool" ]]; then
      _bailiff_print "❌ Bailiff: No tool specified."
      return 1
    fi
    
    package_manager=$(_bailiff_detect_package_manager)
  fi
  
  # Find the package name (usually after the tool name)
  package="$tool"
  
  # Check arguments after the tool name for package name
  local found_tool=0
  for arg in "$@"; do
    if [[ "$found_tool" -eq 1 && "$arg" != "--force" && "$arg" != "-f" && 
          "$arg" != "-x" && "$arg" != "--verbose" ]]; then
      package="$arg"
      break
    fi
    
    if [[ "$arg" == "$tool" ]]; then
      found_tool=1
    fi
  done
  
  # Check if we have a mapping for this tool
  if [[ "$_BAILIFF_SHELL" == "zsh" ]]; then
    if [[ -n "${BAILIFF_TOOL_MAP[$tool]}" ]]; then
      package="${BAILIFF_TOOL_MAP[$tool]}"
    fi
  elif [[ "$_BAILIFF_SHELL" == "bash" ]] && (( BASH_VERSINFO[0] >= 4 )); then
    if [[ -n "${BAILIFF_TOOL_MAP[$tool]}" ]]; then
      package="${BAILIFF_TOOL_MAP[$tool]}"
    fi
  else
    # Use the fallback function for shells without associative arrays
    package=$(_bailiff_get_package "$tool")
  fi
  
  # If force flag is set, clear the cache for this tool
  if [[ "$force_check" -eq 1 ]]; then
    rm -f "$BAILIFF_CACHE_DIR/${tool}_cache"
    _bailiff_print "🔄 Bailiff: Forcing check for '$tool'"
  fi

  
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

# =====================================================
# Setup
# =====================================================

# Setup the command not found handler
if [[ $_BAILIFF_SOURCED -eq 1 && "$BAILIFF_AUTO_SUMMON" -eq 1 ]]; then
  case "$_BAILIFF_SHELL" in
    zsh)
      # Backup original handler if it exists
      if typeset -f command_not_found_handler > /dev/null; then
        function original_command_not_found_handler() {
          echo "zsh: command not found: $1" >&2
          return 127
        }
      fi
      
      # Define the new handler
      function command_not_found_handler() {
        _bailiff_command_not_found_handler "$@"
      }
      ;;
    bash)
      # Bash uses command_not_found_handle (no 'r' at the end)
      # Backup original handler if it exists
      if declare -F command_not_found_handle > /dev/null; then
        function original_command_not_found_handle() {
          echo "bash: command not found: $1" >&2
          return 127
        }
      fi
      
      # Define the new handler
      function command_not_found_handle() {
        _bailiff_command_not_found_handler "$@"
      }
      ;;
    fish)
      # Fish uses a different mechanism, but we can't easily set it up here
      # Users would need to create a function in ~/.config/fish/functions/fish_command_not_found.fish
      _bailiff_print "Note: For Fish shell, auto-summoning requires manual setup."
      _bailiff_print "Create a file at ~/.config/fish/functions/fish_command_not_found.fish with:"
      _bailiff_print "function fish_command_not_found"
      _bailiff_print "    bailiff \$argv[1]"
      _bailiff_print "    if type -q \$argv[1]"
      _bailiff_print "        eval \$argv"
      _bailiff_print "    end"
      _bailiff_print "end"
      ;;
    *)
      _bailiff_print "Note: Auto-summoning may not work in $_BAILIFF_SHELL shell."
      _bailiff_print "Consider manually running 'bailiff <command>' before using new commands."
      ;;
  esac
fi

# If the script is executed directly, not sourced, process arguments
if [[ $_BAILIFF_SOURCED -eq 0 ]]; then
  bailiff "$@"
  exit $?
fi

# When sourced, return success
return 0
