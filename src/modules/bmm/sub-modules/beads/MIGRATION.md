# Beads Integration Migration Guide

## v2.0 → v3.0: Aliases Path Change

**Changed:** Aliases location moved from project-local to global.

**Old:** `.beads/lib/aliases.sh` (project-local)
**New:** `~/.bmad/beads-aliases.sh` (global, persistent)

### Why This Change?

1. **Alignment:** Matches validator expectations and documentation
2. **Consistency:** Matches working reference projects (crypto-data-extend-system)
3. **Persistence:** Available across all projects and shell sessions
4. **Standards:** Follows `injections.yaml` specification

### Automatic Migration

Run the installer again - it will automatically update paths:

```bash
cd /path/to/your/project
bash ./_bmad/bmm/sub-modules/beads/install.sh
```

The installer will:
- ✅ Copy aliases to `~/.bmad/beads-aliases.sh`
- ✅ Update your shell profile (if not already done)
- ✅ Keep existing hooks functional

### Verification

```bash
# Reload shell
exec $SHELL

# Test aliases
bd-help  # Should work from any directory

# Check validator
bd-health
```

### Cleanup (Optional)

After migrating, you can remove the old aliases file:

```bash
rm .beads/lib/aliases.sh
```

Keep `.beads/logs/` and `.beads/tmp/` - these are still used.
