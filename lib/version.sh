#!/usr/bin/env bash
#============================================================
# Pyve Version Tracking and Validation
#
# Functions for tracking Pyve version in project configuration
# and validating installation structure.
#============================================================

#------------------------------------------------------------
# Version Comparison
#------------------------------------------------------------

compare_versions() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$version1" == "$version2" ]]; then
        echo "equal"
        return 0
    fi
    
    local IFS=.
    # shellcheck disable=SC2206 # intentional IFS=. split of dotted version strings; read -ra would change empty-field handling in the comparison below
    local i ver1=($version1) ver2=($version2)
    
    for ((i=0; i<${#ver1[@]} || i<${#ver2[@]}; i++)); do
        local v1=${ver1[i]:-0}
        local v2=${ver2[i]:-0}
        
        if ((v1 > v2)); then
            echo "greater"
            return 0
        elif ((v1 < v2)); then
            echo "less"
            return 0
        fi
    done
    
    echo "equal"
    return 0
}

#------------------------------------------------------------
# Installation Structure Validation
#------------------------------------------------------------

validate_installation_structure() {
    local errors=0
    local warnings=0
    
    if [[ ! -d ".pyve" ]]; then
        log_error "Missing .pyve directory"
        ((errors++))
        return 1
    fi
    
    if [[ ! -f ".pyve/config" ]]; then
        log_error "Missing .pyve/config file"
        ((errors++))
        return 1
    fi
    
    # Route the backend through the manifest. A v2 project resolves via the
    # read-compat synthesis (`manifest_load` reads its root backend from
    # `.pyve/config`); a v3-native project reads `pyve.toml`.
    manifest_load 2>/dev/null || true
    local backend
    backend="$(manifest_get_backend root 2>/dev/null || true)"

    if [[ -z "$backend" ]]; then
        log_error "No backend specified in config"
        ((errors++))
        return 1
    fi
    
    case "$backend" in
        venv)
            validate_venv_structure
            local venv_result=$?
            ((errors += venv_result))
            ;;
        micromamba)
            validate_micromamba_structure
            local mm_result=$?
            ((errors += mm_result))
            ;;
        *)
            log_error "Unknown backend: $backend"
            ((errors++))
            ;;
    esac
    
    if [[ ! -f ".env" ]]; then
        log_warning "Missing .env file (direnv integration)"
        ((warnings++))
    fi
    
    if ((errors > 0)); then
        return 1
    fi
    
    return 0
}

validate_venv_structure() {
    local venv_dir
    venv_dir="$(resolve_venv_directory)"

    if [[ ! -d "$venv_dir" ]]; then
        log_error "Virtual environment not found: $venv_dir"
        return 1
    fi
    
    if [[ ! -f "$venv_dir/bin/python" ]] && [[ ! -f "$venv_dir/Scripts/python.exe" ]]; then
        log_error "Invalid virtual environment: missing Python executable"
        return 1
    fi
    
    return 0
}

validate_micromamba_structure() {
    if [[ ! -f "environment.yml" ]]; then
        log_error "Missing environment.yml file"
        return 1
    fi
    
    # Basic validation - file exists and is readable
    if [[ ! -r "environment.yml" ]]; then
        log_error "environment.yml is not readable"
        return 1
    fi
    
    return 0
}

