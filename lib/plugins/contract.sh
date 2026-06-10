# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# lib/plugins/contract.sh — pyve plugin contract
#
# Defines the no-op default implementation for every plugin hook.
# A plugin implementing a subset of hooks does not need to provide
# the rest; `plugin_dispatch <name> <hook>` (in registry.sh) falls
# back to `pyve_plugin_default_<hook>` when the plugin-specific form
# `<name>_pyve_plugin_<hook>` is undefined.
#
# Hook groups (per concept doc § 5; spike conclusions S1–S11):
#
#   1. manifest_namespace    — return the plugin's manifest key
#   2. register_backends     — register backend providers with bp_*
#   3. detect                — scaffold-time detection
#   4. lifecycle             — init / purge / update / check / status
#                              / run / test
#   5. activate              — `.envrc` snippet emission
#   6. diagnostics           — plugin-internal health checks
#   7. gitignore_entries     — `.gitignore` patterns owned by this plugin
#   8. purge_inventory       — created-vs-authored inventory for purge
#
# Defaults are silent: each prints nothing and returns 0. The dispatcher
# never errors on a missing hook implementation — by design, since N-2
# stories register Python's hooks one at a time.
#============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "Error: %s is a library and cannot be executed directly.\n" "${BASH_SOURCE[0]}" >&2
    exit 1
fi

pyve_plugin_default_manifest_namespace() { :; }
pyve_plugin_default_register_backends()  { :; }
pyve_plugin_default_detect()             { :; }
pyve_plugin_default_init()               { :; }
pyve_plugin_default_purge()              { :; }
pyve_plugin_default_update()             { :; }
pyve_plugin_default_check()              { :; }
pyve_plugin_default_status()             { :; }
pyve_plugin_default_run()                { :; }
pyve_plugin_default_test()               { :; }
pyve_plugin_default_activate()           { :; }
pyve_plugin_default_diagnostics()        { :; }
pyve_plugin_default_gitignore_entries()  { :; }
pyve_plugin_default_purge_inventory()    { :; }
