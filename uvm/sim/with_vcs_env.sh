#!/usr/bin/env bash
set -euo pipefail

# Normalize the Synopsys/VCS environment for non-interactive shells.
export SNPSYS_HOME="${SNPSYS_HOME:-/opt/synopsys}"
export VERDI_HOME="${VERDI_HOME:-$SNPSYS_HOME/verdi201809}"
export VCS_HOME="${VCS_HOME:-$SNPSYS_HOME/vcs201809}"
export VCS_ARCH_OVERRIDE="${VCS_ARCH_OVERRIDE:-linux}"
export VCS_TARGET_ARCH="${VCS_TARGET_ARCH:-amd64}"
export DVE_HOME="${DVE_HOME:-$VCS_HOME/gui/dve}"
export NOVAS_HOME="${NOVAS_HOME:-$SNPSYS_HOME/verdi201809}"
export NOVAS_PLI="${NOVAS_PLI:-$NOVAS_HOME/share/PLI/VCS/LINUX64}"
export NOVAS="${NOVAS:-$NOVAS_HOME/share/PLI/VCS/LINUX64}"
export novas_args="${novas_args:-"-P $NOVAS/novas.tab   $NOVAS/pli.a "}"

# Match the working interactive shell's license settings.
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-27000@localhost}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27000@localhost}"

export PATH="$VERDI_HOME/bin:$VERDI_HOME/platform/LINUX64/bin:$SNPSYS_HOME/scl/v11.10/linux64/bin:$VCS_HOME/bin:$VCS_HOME/gui/dve/bin:$PATH"
export LD_LIBRARY_PATH="$VERDI_HOME/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH:-}"

if [[ -f /home/host/Desktop/5230/.project_env ]]; then
    # Keep behavior aligned with the user's interactive shell.
    # shellcheck disable=SC1091
    source /home/host/Desktop/5230/.project_env >/dev/null 2>&1 || true
fi

exec "$@"
