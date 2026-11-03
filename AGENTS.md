# Local server protection

- Read TASK/README and the nearest local analogue before edits. Prefer minimal reuse.
- `Server/` is private runtime and must remain entirely ignored and untracked. Never stage, upload or publish its files, logs, saves, plugins or configuration.
- Never run SteamCMD, update/validate, `loadMod.bat` or a real updater without a separate explicit task. Updating Rust can remove Oxide.
- Preserve the owner's worlds, maps, identities, ports, configurations and third-party mods. Do not wipe, reset or install replacements.
- Only the two BAT files explicitly authorized by task 001 may change locally, after byte-for-byte backups and hash checks. Preserve the original server argument string. Never run them during automated verification.
- Live tests require a new physical install root, isolated Oxide plugins/config/data, fresh identity/logs/secrets and verified network isolation. Do not use links to writable owner data. Fail closed if isolation is uncertain.
- Any existing Rust/server/client/SteamCMD process blocks live tests. Never stop foreign processes or kill by executable name.
- Own test processes must belong to a kill-on-close Job Object at creation. Attempt graceful quit, then bounded owned-job cleanup in finally; verify process and ports after exit.
- Raw evidence and secrets belong only in ignored `.local/` or `artifacts/`. Public documentation uses synthetic examples and sanitized evidence.
- No Git commands by default. An explicit task may authorize bounded inspection, exact-path staging, commit and ordinary push. Never use broad add/clean/reset/stash, force push or history rewrites.
- Source Cyrillic must remain readable UTF-8; separately check mojibake and escaped Cyrillic in changed text.
- Claim GREEN only with actual readiness, live Oxide compilation and validated physical navigation telemetry. An offline build is not live evidence.
