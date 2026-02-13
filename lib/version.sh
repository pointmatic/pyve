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
# Version Validation
#------------------------------------------------------------

validate_pyve_version() {
    local recorded_version
    recorded_version="$(read_config_value "pyve_version")"
    
    if [[ -z "$recorded_version" ]]; then
        return 0
    fi
    
    local comparison
    comparison="$(compare_versions "$recorded_version" "$VERSION")"
    
    case "$comparison" in
        equal)
            return 0
            ;;
        less)
            if [[ "${PYVE_SKIP_VERSION_CHECK:-}" != "1" ]]; then
                log_warning "Project initialized with Pyve v$recorded_version (current: v$VERSION)"
                log_warning "Run 'pyve --validate' to check compatibility"
            fi
            return 0
            ;;
        greater)
            if [[ "${PYVE_SKIP_VERSION_CHECK:-}" != "1" ]]; then
                log_warning "Project initialized with newer Pyve v$recorded_version (current: v$VERSION)"
                log_warning "Consider upgrading Pyve or re-initializing the project"
            fi
            return 0
            ;;
    esac
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
    
    local backend
    backend="$(read_config_value "backend")"
    
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
    venv_dir="$(read_config_value "venv.directory")"
    venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
    
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

#------------------------------------------------------------
# Full Validation Report
#------------------------------------------------------------

run_full_validation() {
    # Severity: 0 = pass, 2 = warnings, 1 = errors.
    # Only escalate: warnings never overwrite errors.
    local exit_code=0
    _escalate() { (( $1 == 1 || ( $1 == 2 && exit_code != 1 ) )) && exit_code=$1; return 0; }
    
    echo "Pyve Installation Validation"
    echo "=============================="
    echo ""
    
    local recorded_version
    recorded_version="$(read_config_value "pyve_version")"
    
    if [[ -z "$recorded_version" ]]; then
        echo "⚠ Pyve version: not recorded (legacy project)"
        echo "  Run 'pyve --init --update' to add version tracking"
        _escalate 2
    else
        local comparison
        comparison="$(compare_versions "$recorded_version" "$VERSION")"
        
        case "$comparison" in
            equal)
                echo "✓ Pyve version: $recorded_version (current)"
                ;;
            less)
                echo "⚠ Pyve version: $recorded_version (current: $VERSION)"
                echo "  Migration recommended. Run 'pyve --init --update' to update."
                _escalate 2
                ;;
            greater)
                echo "⚠ Pyve version: $recorded_version (current: $VERSION)"
                echo "  Project uses newer Pyve version. Consider upgrading."
                _escalate 2
                ;;
        esac
    fi
    
    local backend
    backend="$(read_config_value "backend")"
    
    if [[ -n "$backend" ]]; then
        echo "✓ Backend: $backend"
    else
        echo "✗ Backend: not configured"
        _escalate 1
    fi
    
    case "$backend" in
        venv)
            local venv_dir
            venv_dir="$(read_config_value "venv.directory")"
            venv_dir="${venv_dir:-${DEFAULT_VENV_DIR:-.venv}}"
            
            if [[ -d "$venv_dir" ]]; then
                echo "✓ Virtual environment: $venv_dir (exists)"
            else
                echo "✗ Virtual environment: $venv_dir (missing)"
                echo "  Run 'pyve --init' to create."
                _escalate 1
            fi
            ;;
        micromamba)
            if [[ -f "environment.yml" ]]; then
                echo "✓ Environment file: environment.yml (exists)"
            else
                echo "✗ Environment file: environment.yml (missing)"
                _escalate 1
            fi
            
            local env_name
            env_name="$(resolve_environment_name "")"
            if [[ -n "$env_name" ]]; then
                echo "✓ Environment name: $env_name"
            else
                echo "✗ Environment name: could not determine"
                _escalate 1
            fi
            ;;
    esac
    
    if [[ -f ".pyve/config" ]]; then
        echo "✓ Configuration: valid"
    else
        echo "✗ Configuration: missing"
        _escalate 1
    fi
    
    local python_version
    python_version="$(read_config_value "python.version")"
    if [[ -n "$python_version" ]]; then
        echo "✓ Python version: $python_version"
    fi
    
    if [[ -f ".env" ]]; then
        echo "✓ direnv integration: .env (exists)"
    else
        echo "⚠ direnv integration: .env (missing)"
        _escalate 2
    fi
    
    echo ""
    
    case $exit_code in
        0)
            echo "All validations passed."
            ;;
        1)
            echo "Validation completed with errors."
            ;;
        2)
            echo "Validation completed with warnings."
            ;;
    esac
    
    return $exit_code
}

#------------------------------------------------------------
# Config Writing with Version
#------------------------------------------------------------

write_config_with_version() {
    local config_file=".pyve/config"
    
    mkdir -p ".pyve"
    
    {
        echo "pyve_version: \"$VERSION\""
        
        if [[ -f "$config_file" ]]; then
            grep -v "^pyve_version:" "$config_file" || true
        fi
    } > "${config_file}.tmp"
    
    mv "${config_file}.tmp" "$config_file"
}

update_config_version() {
    local config_file=".pyve/config"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    # Basic sanity check: a readable config must have a backend.
    # If it's missing, treat the config as corrupted/unparseable and fail.
    local backend
    backend="$(read_config_value "backend")"
    if [[ -z "$backend" ]]; then
        return 1
    fi
    
    local current_version
    current_version="$(read_config_value "pyve_version")"
    
    if [[ "$current_version" == "$VERSION" ]]; then
        return 0
    fi
    
    {
        echo "pyve_version: \"$VERSION\""
        grep -v "^pyve_version:" "$config_file" || true
    } > "${config_file}.tmp"
    
    mv "${config_file}.tmp" "$config_file"
}
