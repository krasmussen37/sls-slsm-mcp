#!/usr/bin/env bash
# sls-slsm-mcp installer
# Checks prerequisites, installs the MCP server, optionally configures
# Claude Code, Codex CLI, and/or Gemini CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="sls-slsm-mcp"

# Colors (disabled if NO_COLOR set or not a terminal)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
fi

info()  { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $*"; }
fail()  { echo -e "${RED}[err]${NC} $*"; exit 1; }

usage() {
    echo "Usage: install.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  --configure-claude    Add MCP server to Claude Code (~/.claude.json)"
    echo "  --configure-codex     Add MCP server to Codex CLI (~/.codex/config.toml)"
    echo "  --configure-gemini    Add MCP server to Gemini CLI (~/.gemini/settings.json)"
    echo "  --configure-all       Configure all three agents"
    echo "  -h, --help            Show this help"
    echo
    echo "Without flags, the installer will prompt interactively (if running in a terminal)."
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
configure_claude=false
configure_codex=false
configure_gemini=false
flag_mode=false

for arg in "$@"; do
    case "$arg" in
        --configure-claude) configure_claude=true; flag_mode=true ;;
        --configure-codex)  configure_codex=true;  flag_mode=true ;;
        --configure-gemini) configure_gemini=true;  flag_mode=true ;;
        --configure-all)    configure_claude=true; configure_codex=true; configure_gemini=true; flag_mode=true ;;
        -h|--help)          usage; exit 0 ;;
        *)                  warn "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
echo -e "${BOLD}sls-slsm-mcp installer${NC}"
echo

errors=0

# Python 3.7+
if command -v python3 &>/dev/null; then
    py_ver=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    py_major=$(echo "$py_ver" | cut -d. -f1)
    py_minor=$(echo "$py_ver" | cut -d. -f2)
    if (( py_major >= 3 && py_minor >= 7 )); then
        info "Python $py_ver"
    else
        warn "Python $py_ver found (need 3.7+)"
        errors=$((errors + 1))
    fi
else
    warn "Python 3 not found"
    errors=$((errors + 1))
fi

# sls
if command -v sls &>/dev/null; then
    sls_ver=$(sls --version 2>/dev/null || echo "unknown")
    info "sls ($sls_ver)"
else
    warn "sls not found - install from: https://github.com/krasmussen37/sls"
    errors=$((errors + 1))
fi

# slsm
if command -v slsm &>/dev/null; then
    slsm_ver=$(slsm --version 2>/dev/null || echo "unknown")
    info "slsm ($slsm_ver)"
else
    warn "slsm not found - install from: https://github.com/krasmussen37/sls-memory"
    errors=$((errors + 1))
fi

if (( errors > 0 )); then
    echo
    fail "Missing prerequisites. Install them and re-run this script."
fi

echo

# ---------------------------------------------------------------------------
# Install binary
# ---------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
info "Installed to $INSTALL_DIR/$SCRIPT_NAME"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    warn "$INSTALL_DIR is not in your PATH. Add it:"
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi

FULL_CMD="$INSTALL_DIR/$SCRIPT_NAME"

# ---------------------------------------------------------------------------
# Interactive prompts (only if no flags were passed and we have a terminal)
# ---------------------------------------------------------------------------
if ! $flag_mode && [[ -t 0 ]]; then
    echo
    echo -e "${BOLD}Configure agent MCP servers:${NC}"

    read -rp "  Claude Code (~/.claude.json)?       [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_claude=true

    read -rp "  Codex CLI   (~/.codex/config.toml)?  [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_codex=true

    read -rp "  Gemini CLI  (~/.gemini/settings.json)? [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]] && configure_gemini=true
fi

# ---------------------------------------------------------------------------
# Configure Claude Code (~/.claude.json)
# ---------------------------------------------------------------------------
if $configure_claude; then
    claude_json="${HOME}/.claude.json"
    if [[ -f "$claude_json" ]]; then
        if python3 -c "
import json, sys
with open('$claude_json') as f:
    data = json.load(f)
if 'sls-slsm' in data.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            info "Claude Code: already configured"
        else
            python3 -c "
import json
with open('$claude_json') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['sls-slsm'] = {
    'command': '$FULL_CMD',
    'args': [],
    'env': {},
    'description': 'System log search (sls) + error pattern memory (slsm)'
}
with open('$claude_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
            info "Claude Code: added sls-slsm to $claude_json"
        fi
    else
        python3 -c "
import json
data = {
    'mcpServers': {
        'sls-slsm': {
            'command': '$FULL_CMD',
            'args': [],
            'env': {},
            'description': 'System log search (sls) + error pattern memory (slsm)'
        }
    }
}
with open('$claude_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        info "Claude Code: created $claude_json"
    fi
fi

# ---------------------------------------------------------------------------
# Configure Codex CLI (~/.codex/config.toml)
# ---------------------------------------------------------------------------
if $configure_codex; then
    codex_toml="${HOME}/.codex/config.toml"
    if [[ -f "$codex_toml" ]]; then
        if grep -q '^\[mcp_servers\.sls-slsm\]' "$codex_toml" 2>/dev/null; then
            info "Codex CLI: already configured"
        else
            cat >> "$codex_toml" <<EOF

[mcp_servers.sls-slsm]
command = "$FULL_CMD"
args = []
EOF
            info "Codex CLI: added sls-slsm to $codex_toml"
        fi
    else
        mkdir -p "$(dirname "$codex_toml")"
        cat > "$codex_toml" <<EOF
[mcp_servers.sls-slsm]
command = "$FULL_CMD"
args = []
EOF
        info "Codex CLI: created $codex_toml"
    fi
fi

# ---------------------------------------------------------------------------
# Configure Gemini CLI (~/.gemini/settings.json)
# ---------------------------------------------------------------------------
if $configure_gemini; then
    gemini_json="${HOME}/.gemini/settings.json"
    if [[ -f "$gemini_json" ]]; then
        if python3 -c "
import json, sys
with open('$gemini_json') as f:
    data = json.load(f)
if 'sls-slsm' in data.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
            info "Gemini CLI: already configured"
        else
            python3 -c "
import json
with open('$gemini_json') as f:
    data = json.load(f)
if 'mcpServers' not in data:
    data['mcpServers'] = {}
data['mcpServers']['sls-slsm'] = {
    'command': '$FULL_CMD',
    'args': []
}
with open('$gemini_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
            info "Gemini CLI: added sls-slsm to $gemini_json"
        fi
    else
        mkdir -p "$(dirname "$gemini_json")"
        python3 -c "
import json
data = {
    'mcpServers': {
        'sls-slsm': {
            'command': '$FULL_CMD',
            'args': []
        }
    }
}
with open('$gemini_json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        info "Gemini CLI: created $gemini_json"
    fi
fi

echo
echo -e "${GREEN}Done!${NC} Restart agent sessions to pick up the new MCP server."
echo
echo "Verify:  $SCRIPT_NAME --version"
echo "Test:    echo '{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\",\"params\":{}}' | $SCRIPT_NAME"
