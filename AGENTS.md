# mrn-plugins

## Rules

- Any change under `plugins/<name>/` (agents, hooks, skills, plugin.json) must
  bump `"version"` in `plugins/<name>/.claude-plugin/plugin.json` in the same
  commit. Installed copies are cached by version, so without a bump users
  never receive the update.
- Versions are `MAJOR.MINOR.PATCH` per Semantic Versioning 2.0.0 (semver.org):
  - MAJOR: breaking change (renamed/removed skill, agent or hook, changed
    behavior users rely on).
  - MINOR: backward-compatible new skill, agent, hook or capability.
  - PATCH: backward-compatible fix, wording, or model/effort tweak.
  - No leading zeros, no `v` prefix in plugin.json. Reset lower numbers on a
    bump (1.4.2 -> 1.5.0). Bump once per commit; never reuse or lower a
    published version.
- No Co-Authored-By or attribution lines in commits.
