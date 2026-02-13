#!/usr/bin/env bash
#
# Copyright (c) 2025 Pointmatic, (https://www.pointmatic.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

#============================================================
# Python 3.12+ distutils compatibility shim
#============================================================

PYVE_DISTUTILS_SHIM_MARKER="# pyve-managed: distutils shim"

pyve_is_distutils_shim_disabled() {
    [[ "${PYVE_DISABLE_DISTUTILS_SHIM:-}" == "1" ]]
}

pyve_get_python_major_minor() {
    local python_path="$1"

    "$python_path" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null
}

pyve_python_is_312_plus() {
    local python_path="$1"
    local majmin
    majmin="$(pyve_get_python_major_minor "$python_path")"

    if [[ -z "$majmin" ]]; then
        return 1
    fi

    local major="${majmin%%.*}"
    local minor="${majmin#*.}"

    if [[ "$major" -gt 3 ]]; then
        return 0
    fi
    if [[ "$major" -lt 3 ]]; then
        return 1
    fi
    [[ "$minor" -ge 12 ]]
}

pyve_get_site_packages_dir() {
    local python_path="$1"

    # Prefer site.getsitepackages for venv/conda; fall back to sysconfig
    "$python_path" -c 'import site, sysconfig; sp = (getattr(site, "getsitepackages", lambda: [])() or [sysconfig.get_paths()["purelib"]])[0]; print(sp)' 2>/dev/null
}

pyve_write_sitecustomize_shim() {
    local site_packages_dir="$1"
    local sitecustomize_path="$site_packages_dir/sitecustomize.py"

    mkdir -p "$site_packages_dir" || return 1

    local desired
    desired="${PYVE_DISTUTILS_SHIM_MARKER}
import os
os.environ.setdefault(\"SETUPTOOLS_USE_DISTUTILS\", \"local\")
import setuptools  # noqa: F401
"

    if [[ -f "$sitecustomize_path" ]]; then
        # Only update if it's clearly ours
        if ! grep -qF "$PYVE_DISTUTILS_SHIM_MARKER" "$sitecustomize_path"; then
            log_warning "sitecustomize.py exists and is not pyve-managed; skipping distutils shim"
            return 0
        fi

        # Update in-place if different
        if [[ "$(cat "$sitecustomize_path")" == "$desired" ]]; then
            return 0
        fi
    fi

    printf "%s" "$desired" > "$sitecustomize_path"
}

pyve_distutils_shim_probe() {
    local python_path="$1"

    # Keep this probe lightweight and non-fatal: it should not block initialization.
    local probe_output
    probe_output="$("$python_path" -c 'import os, setuptools; print(os.environ.get("SETUPTOOLS_USE_DISTUTILS", ""))' 2>/dev/null)" || {
        log_warning "Distutils shim probe failed (could not import setuptools); continuing"
        return 0
    }

    if [[ "$probe_output" == "local" ]]; then
        log_success "Distutils shim probe: SETUPTOOLS_USE_DISTUTILS=local"
    elif [[ -z "$probe_output" ]]; then
        log_warning "Distutils shim probe: SETUPTOOLS_USE_DISTUTILS was not set"
    else
        log_warning "Distutils shim probe: SETUPTOOLS_USE_DISTUTILS=$probe_output"
    fi

    return 0
}

pyve_ensure_venv_packaging_prereqs() {
    local python_path="$1"

    # Ensure pip exists; avoid failure if ensurepip is not available
    "$python_path" -m pip --version >/dev/null 2>&1 || {
        "$python_path" -m ensurepip --upgrade >/dev/null 2>&1 || true
    }

    "$python_path" -m pip install -U setuptools wheel >/dev/null
}

pyve_ensure_micromamba_packaging_prereqs() {
    local micromamba_path="$1"
    local env_prefix="$2"

    "$micromamba_path" install -p "$env_prefix" -y pip setuptools wheel >/dev/null
}

pyve_install_distutils_shim_for_python() {
    local python_path="$1"

    if pyve_is_distutils_shim_disabled; then
        log_info "Distutils shim disabled (PYVE_DISABLE_DISTUTILS_SHIM=1)"
        return 0
    fi

    if ! pyve_python_is_312_plus "$python_path"; then
        return 0
    fi

    local site_packages_dir
    site_packages_dir="$(pyve_get_site_packages_dir "$python_path")"
    if [[ -z "$site_packages_dir" ]]; then
        log_warning "Could not determine site-packages directory; skipping distutils shim"
        return 0
    fi

    log_info "Python >= 3.12 detected; installing distutils compatibility shim"

    pyve_ensure_venv_packaging_prereqs "$python_path" || {
        log_warning "Failed to install setuptools/wheel prerequisites; continuing"
    }

    pyve_write_sitecustomize_shim "$site_packages_dir" || {
        log_warning "Failed to write sitecustomize.py shim"
        return 0
    }

    if [[ -f "$site_packages_dir/sitecustomize.py" ]] && grep -qF "$PYVE_DISTUTILS_SHIM_MARKER" "$site_packages_dir/sitecustomize.py"; then
        log_success "Installed distutils compatibility shim: $site_packages_dir/sitecustomize.py"
        log_info "Disable with: PYVE_DISABLE_DISTUTILS_SHIM=1"
        pyve_distutils_shim_probe "$python_path"
    fi

    return 0
}

pyve_install_distutils_shim_for_micromamba_prefix() {
    local micromamba_path="$1"
    local env_prefix="$2"

    local python_path="$env_prefix/bin/python"
    if [[ ! -x "$python_path" ]]; then
        # No Python in the conda env; nothing to do
        return 0
    fi

    if pyve_is_distutils_shim_disabled; then
        log_info "Distutils shim disabled (PYVE_DISABLE_DISTUTILS_SHIM=1)"
        return 0
    fi

    if ! pyve_python_is_312_plus "$python_path"; then
        return 0
    fi

    log_info "Python >= 3.12 detected; installing distutils compatibility shim"

    pyve_ensure_micromamba_packaging_prereqs "$micromamba_path" "$env_prefix" || {
        log_warning "Failed to install pip/setuptools/wheel via micromamba; continuing"
    }

    local site_packages_dir
    site_packages_dir="$(pyve_get_site_packages_dir "$python_path")"
    if [[ -z "$site_packages_dir" ]]; then
        log_warning "Could not determine site-packages directory; skipping distutils shim"
        return 0
    fi

    pyve_write_sitecustomize_shim "$site_packages_dir" || {
        log_warning "Failed to write sitecustomize.py shim"
        return 0
    }

    if [[ -f "$site_packages_dir/sitecustomize.py" ]] && grep -qF "$PYVE_DISTUTILS_SHIM_MARKER" "$site_packages_dir/sitecustomize.py"; then
        log_success "Installed distutils compatibility shim: $site_packages_dir/sitecustomize.py"
        log_info "Disable with: PYVE_DISABLE_DISTUTILS_SHIM=1"
        pyve_distutils_shim_probe "$python_path"
    fi

    return 0
}
