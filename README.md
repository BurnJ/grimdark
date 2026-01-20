# Grimdark (Isometric 2D RPG)

This repository contains the Grimdark isometric 2D project built for Godot 4.5.1.

Purpose of the `testing` branch
- Use `testing` for experimental changes and nightlies.
- If you like the results, merge `testing` into `master` via a PR.
- A snapshot/tag `v0.0-before-nightly` exists to roll back `master` if needed.

Quick commands
- Work on testing locally:
  - `git checkout testing`
  - `git add -A && git commit -m "WIP: ..."`
  - `git push`
- Make `testing` the new master (merge via PR or locally):
  - `git checkout master && git merge --no-ff testing && git push`

Notes
- See `.github/workflows/pr-check.yml` for a minimal CI job that runs on PRs.
