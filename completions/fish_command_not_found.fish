#!/usr/bin/env fish
# Fish command not found handler for Bailiff
# Save this file to ~/.config/fish/functions/fish_command_not_found.fish

function fish_command_not_found
    # Try to install the command using bailiff
    bailiff $argv[1]
    
    # If the command is now available, run it with all arguments
    if type -q $argv[1]
        # Get all arguments including the command
        set -l cmd $argv
        
        # Execute the command with all arguments
        eval $cmd
    end
end
