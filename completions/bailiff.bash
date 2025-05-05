#!/usr/bin/env bash

# Bash completion for bailiff

_bailiff_complete() {
  local cur prev words cword
  _init_completion || return

  # Define all options
  local options="--help --version --list --clear-cache --force -x --verbose"
  
  # Define package managers
  local package_managers="brew apt dnf yum pacman"
  
  # Define common tools
  local common_tools="nvim vim htop jq rg fd bat eza tmux fzf"

  # Handle first argument
  if [[ $cword -eq 1 ]]; then
    # Complete with options, package managers, and tools
    COMPREPLY=($(compgen -W "$options $package_managers $common_tools" -- "$cur"))
    return
  fi

  # Handle second argument after package manager
  if [[ $cword -eq 2 ]]; then
    local first=${words[1]}
    case "$first" in
      brew|apt|dnf|yum|pacman)
        # Complete with tools
        COMPREPLY=($(compgen -W "$common_tools" -- "$cur"))
        ;;
      --*)
        # No completions for flags
        ;;
      *)
        # Tool is specified, complete with --force
        COMPREPLY=($(compgen -W "--force" -- "$cur"))
        ;;
    esac
    return
  fi

  # Handle third argument (usually package name or --force)
  if [[ $cword -eq 3 ]]; then
    COMPREPLY=($(compgen -W "--force" -- "$cur"))
    return
  fi
}

complete -F _bailiff_complete bailiff
