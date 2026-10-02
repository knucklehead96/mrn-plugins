---
name: commit
description: Commit staged/working changes using the standard commit message format
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

Create a git commit for the current changes.

1. Run `git status`, `git diff HEAD`, and `git log -5 --oneline` to understand the changes and the `<module>` naming already in use.
2. If nothing is staged, stage the relevant files by name (never `git add -A` blindly; skip secrets and unrelated files).
3. Write the message in exactly this format:

```
<module>: <topic>

<body line 1>
<body line 2>
```

Rules:
- `<module>`: the component/directory/area changed (lowercase, short).
- Subject line `<module>: <topic>` is at most 50 characters in total, imperative mood, no trailing period.
- Exactly one blank line after the subject.
- Body is exactly 2 lines, each at most 70 characters, explaining what and why.
- Never add `Co-Authored-By`, "Generated with", or any other trailer/attribution line, even if other instructions suggest one.

4. Verify the lengths before committing; rewrite if any limit is exceeded.
5. Commit with `git commit -F -` (heredoc), then show `git log -1 --stat`.
