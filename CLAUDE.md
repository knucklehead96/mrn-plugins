# mrn-plugins

## Rules

- Any change under `plugins/<name>/` (agents, hooks, skills, plugin.json) must
  bump `"version"` in `plugins/<name>/.claude-plugin/plugin.json` in the same
  commit. Semver: patch for fixes/wording, minor for new skills/agents/hooks,
  major for breaking changes. Installed copies are cached by version, so
  without a bump users never receive the update.
- No Co-Authored-By or attribution lines in commits.
