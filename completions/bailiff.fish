#!/usr/bin/env fish
# Fish completion for bailiff

# Define all options
set -l bailiff_options --help --version --list --clear-cache --force -x --verbose

# Define package managers
set -l package_managers brew apt dnf yum pacman

# Define common tools
set -l common_tools nvim vim htop jq rg fd bat eza tmux fzf

# Main completion function
function __fish_bailiff_complete
    set -l cmd (commandline -opc)
    set -l cmdline (commandline -ct)
    
    # No arguments yet, complete with options, package managers, and tools
    if test (count $cmd) -eq 1
        printf "%s\n" $bailiff_options
        printf "%s\n" $package_managers
        printf "%s\n" $common_tools
        return
    end
    
    # Handle second argument
    if test (count $cmd) -eq 2
        set -l first $cmd[2]
        switch $first
            case "brew" "apt" "dnf" "yum" "pacman"
                # Complete with tools
                printf "%s\n" $common_tools
            case "--*" "-*"
                # No completions for flags
            case "*"
                # Tool is specified, complete with --force
                echo --force
        end
        return
    end
    
    # Handle third argument
    if test (count $cmd) -eq 3
        echo --force
        return
    end
end

# Register completions
complete -c bailiff -f -a "(__fish_bailiff_complete)"

# Add descriptions for options
complete -c bailiff -f -l help -d "Show help message"
complete -c bailiff -f -l version -d "Show version information"
complete -c bailiff -f -l list -d "List all summoned tools"
complete -c bailiff -f -l clear-cache -d "Clear the tool cache"
complete -c bailiff -f -l force -d "Force check/install regardless of cache"
complete -c bailiff -f -s x -d "Verbose mode, shows already installed tools"
complete -c bailiff -f -l verbose -d "Verbose mode, shows already installed tools"

# Add descriptions for package managers
complete -c bailiff -f -n "__fish_is_first_arg" -a "brew" -d "Homebrew package manager"
complete -c bailiff -f -n "__fish_is_first_arg" -a "apt" -d "Advanced Package Tool"
complete -c bailiff -f -n "__fish_is_first_arg" -a "dnf" -d "Package manager for RPM"
complete -c bailiff -f -n "__fish_is_first_arg" -a "yum" -d "Yellowdog Updater Modified"
complete -c bailiff -f -n "__fish_is_first_arg" -a "pacman" -d "Package manager for Arch"

# Add descriptions for common tools
complete -c bailiff -f -n "__fish_is_first_arg" -a "nvim" -d "Neovim text editor"
complete -c bailiff -f -n "__fish_is_first_arg" -a "vim" -d "Vi IMproved text editor"
complete -c bailiff -f -n "__fish_is_first_arg" -a "htop" -d "Interactive process viewer"
complete -c bailiff -f -n "__fish_is_first_arg" -a "jq" -d "JSON processor"
complete -c bailiff -f -n "__fish_is_first_arg" -a "rg" -d "Ripgrep search tool"
complete -c bailiff -f -n "__fish_is_first_arg" -a "fd" -d "Fast find alternative"
complete -c bailiff -f -n "__fish_is_first_arg" -a "bat" -d "Better cat"
complete -c bailiff -f -n "__fish_is_first_arg" -a "eza" -d "Modern ls replacement"
complete -c bailiff -f -n "__fish_is_first_arg" -a "tmux" -d "Terminal multiplexer"
complete -c bailiff -f -n "__fish_is_first_arg" -a "fzf" -d "Fuzzy finder"
