# sls-slsm-mcp

MCP server bridging [sls](https://github.com/krasmussen37/sls) (System Log Search) and [slsm](https://github.com/krasmussen37/sls-memory) (SLS Memory) into a single tool server for AI coding agents.

## Tools

| Tool | Description |
|------|-------------|
| `sls_search` | Search system logs, agent stderr, and application logs |
| `sls_context` | Get surrounding log entries around a timestamp for root cause analysis |
| `sls_timeline` | Activity timeline aggregated by time buckets |
| `sls_alert` | Check error/warning thresholds (OK/WARNING/CRITICAL) |
| `slsm_context` | Look up known fixes for an error from the pattern playbook |
| `slsm_add_pattern` | Add a new error pattern with regex and metadata |
| `slsm_feedback` | Mark a pattern as helpful or harmful |
| `slsm_reflect` | Auto-extract new patterns from recent logs |

## Prerequisites

- Python 3.7+
- [sls](https://github.com/krasmussen37/sls) on PATH
- [slsm](https://github.com/krasmussen37/sls-memory) on PATH

## Install

```bash
./install.sh                    # Interactive
./install.sh --configure-all    # Non-interactive, configure all agents
./install.sh --configure-claude # Claude Code only
```

## Manual Configuration

**Claude Code** (`~/.claude.json`):
```json
{
  "mcpServers": {
    "sls-slsm": {
      "command": "/home/you/.local/bin/sls-slsm-mcp",
      "args": [],
      "env": {},
      "description": "System log search (sls) + error pattern memory (slsm)"
    }
  }
}
```

**Codex CLI** (`~/.codex/config.toml`):
```toml
[mcp_servers.sls-slsm]
command = "/home/you/.local/bin/sls-slsm-mcp"
args = []
```

**Gemini CLI** (`~/.gemini/settings.json`):
```json
{
  "mcpServers": {
    "sls-slsm": {
      "command": "/home/you/.local/bin/sls-slsm-mcp",
      "args": []
    }
  }
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SLS_BIN` | auto-detect | Path to `sls` binary |
| `SLSM_BIN` | auto-detect | Path to `slsm` binary |
| `SLS_SLSM_MCP_DEBUG` | unset | Set to `1` to keep stderr open |

## Test

```bash
sls-slsm-mcp --version
echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{}}' | sls-slsm-mcp
```

## License

MIT
