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

