penv() {
    local command="$1"
    local venv_name="$2"
    local venv_dir
    local venv_file=".py-venv"

    case "$command" in
        list|l)
            local venv_dir="$HOME/.local/share/py-venv"
            if [[ -d "$venv_dir" ]]; then
                ls -1 "$venv_dir"
            else
                echo "No virtual environments found in $venv_dir."
            fi
            ;;

        create)
            if [[ -z "$venv_name" ]]; then
                echo "Error: You must specify a name for the virtual environment to create."
                return 1
            fi

            venv_dir="$HOME/.local/share/py-venv/$venv_name"
            if [[ -d "$venv_dir" ]]; then
                echo "Error: Virtual environment '$venv_name' already exists in $HOME/.local/share/py-venv."
                return 1
            fi

            echo -n "Are you sure you want to create the virtual environment '$venv_name'? (y/N) "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                uv venv "$venv_dir" "${@:3}"
                echo "Virtual environment '$venv_name' created at $venv_dir."
            else
                echo "Aborted creation of virtual environment '$venv_name'."
            fi
            ;;

        delete)
            if [[ -z "$venv_name" ]]; then
                echo "Error: You must specify a name for the virtual environment to delete."
                return 1
            fi

            venv_dir="$HOME/.local/share/py-venv/$venv_name"
            if [[ ! -d "$venv_dir" ]]; then
                echo "Error: Virtual environment '$venv_name' does not exist in $HOME/.local/share/py-venv."
                return 1
            fi

            echo -n "Are you sure you want to delete the virtual environment '$venv_name'? This action cannot be undone. (y/N) "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -rf "$venv_dir"
                echo "Virtual environment '$venv_name' deleted."
            else
                echo "Aborted deletion of virtual environment '$venv_name'."
            fi
            ;;

        shell)
            if [[ "$venv_name" == "--unset" ]]; then
                if [[ -n "$PENV_VENV" ]]; then
                    local current_venv="$PENV_VENV"
                    unset PENV_VENV

                    if [[ -f "$venv_file" ]]; then
                        local venv_in_file
                        venv_in_file=$(<"$venv_file")
                        if [[ "$venv_in_file" == "$current_venv" ]]; then
                            echo "Unset PENV_VENV but kept the environment active because it matches .py-venv."
                            return
                        else
                            deactivate 2>/dev/null || echo "No virtual environment is active."
                            local venv_dir="$HOME/.local/share/py-venv/$venv_in_file"
                            if [[ -d "$venv_dir" ]]; then
                                source "$venv_dir/bin/activate"
                                echo "Switched to the environment defined by .py-venv: $venv_in_file"
                            else
                                echo "Error: Virtual environment '$venv_in_file' defined in .py-venv does not exist."
                            fi
                            return
                        fi
                    else
                        deactivate 2>/dev/null || echo "No virtual environment is active."
                        echo "Unset PENV_VENV and deactivated the environment."
                    fi
                else
                    echo "No PENV_VENV is set. Nothing to unset."
                fi
                return
            fi

            venv_dir="$HOME/.local/share/py-venv/$venv_name"
            if [ -d "$venv_dir" ]; then
                export PENV_VENV="$venv_name"
                source "$venv_dir/bin/activate"
                echo "Set and activated virtual environment for the current shell session: $venv_name"
            else
                echo "Error: Virtual environment '$venv_name' does not exist in $HOME/.local/share/py-venv."
            fi
            ;;

        local)
            if [[ "$venv_name" == "--unset" ]]; then
                if [[ -f "$venv_file" ]]; then
                    rm "$venv_file"
                    deactivate 2>/dev/null || echo "No virtual environment is active."
                    echo "Unset virtual environment for the current directory."
                else
                    echo "No local virtual environment is set."
                fi
                return
            fi

            venv_dir="$HOME/.local/share/py-venv/$venv_name"
            if [ -d "$venv_dir" ]; then
                echo "$venv_name" > "$venv_file"
                source "$venv_dir/bin/activate"
                echo "Set and activated virtual environment for the current directory: $venv_name"
            else
                echo "Error: Virtual environment '$venv_name' does not exist in $HOME/.local/share/py-venv."
            fi
            ;;

        why|w)
            if [[ -n "$VIRTUAL_ENV" ]]; then
                local current_venv_name="${VIRTUAL_ENV##*/}"
                if [[ -n "$PENV_VENV" ]]; then
                    echo "Env '${current_venv_name}' activated because of the 'penv shell' command."
                    echo "To deactivate this virtual environment, run: penv shell --unset"
                elif [[ -f "$PWD/$venv_file" && "$(cat "$PWD/$venv_file")" == "$current_venv_name" ]]; then
                    echo "Env '${current_venv_name}' activated because of the .py-venv file in the current directory."
                    echo "To deactivate this virtual environment, run: penv local --unset"
                else
                    echo "Env '${current_venv_name}' activated manually or by another mechanism."
                fi
            else
                echo "No virtual environment is currently active."
            fi
            ;;

        *)
            cat <<EOF
Usage:
  penv list|l                    List all available virtual environments
  penv create <name> [options]   Create a new virtual environment
  penv delete <name>             Delete an existing virtual environment
  penv shell <name>|--unset      Set or unset a virtual environment for the current shell session
  penv local <name>|--unset      Set or unset a virtual environment for the current directory
  penv why|w                     Explain why a virtual environment is active (or not)
EOF
            return 1
            ;;
    esac
}

_autoload_penv() {
    local venv_name
    local venv_dir
    local venv_file=".py-venv"

    if [[ -n "$PENV_VENV" ]]; then
        return
    fi

    if [[ -f "$venv_file" ]]; then
        venv_name=$(<"$venv_file")
        venv_dir="$HOME/.local/share/py-venv/$venv_name"

        if [ -d "$venv_dir" ]; then
            if [[ "$VIRTUAL_ENV" != "$venv_dir" ]]; then
                source "$venv_dir/bin/activate"
                echo "Auto-activated virtual environment: $venv_name"
            fi
            return
        fi
    fi

    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate
        echo "Deactivated virtual environment because no .py-venv file was found in the current directory."
    fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _autoload_penv

_autoload_penv

# Autocompletions
_penv() {
    local -a subcommands
    subcommands=(
        "list:List all available virtual environments"
        "create:Create a new virtual environment"
        "delete:Delete an existing virtual environment"
        "shell:Set a virtual environment for the current shell session, or unset it with --unset"
        "local:Set a virtual environment for the current directory, or unset it with --unset"
        "why:Explain why a virtual environment is active (or not)"
        "w:Alias for 'penv why'"
        "l:Alias for 'penv list'"
    )

    local -a venv_names
    if [[ $words[2] =~ ^(delete|shell|local)$ ]]; then
        local venv_dir="$HOME/.local/share/py-venv"
        if [[ -d $venv_dir ]]; then
            venv_names=("${(f)$(ls -1 $venv_dir)}")
        else
            venv_names=()
        fi

        [[ $words[2] =~ ^(shell|local)$ ]] && venv_names+=("--unset")
    fi

    if (( CURRENT == 2 )); then
        _describe -t commands "penv subcommands" subcommands
    elif (( CURRENT == 3 )); then
        _describe -t venvs "Available virtual environments" venv_names
    fi
}
compdef _penv penv
