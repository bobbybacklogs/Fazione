# Fazione

<p align="center">
    <img src="docs/images/ghLock.png" alt="Fazione lockup" width="750" height="auto" />
</p>

Fazione is a personal, agent-first Linux distribution. This repository is private IP. The live slice is a Docker factory: one root script that prepares a `debian:bookworm-slim` container with Node 22, Python 3, git, Cursor CLI (`agent`), Codex, Grok Build, and OpenCode so distro work can proceed from a bind-mounted workspace.

The Ubuntu-based ISO, live-boot image, and desktop IDE are not in this slice. The factory is Debian Bookworm on purpose. It does not install Kali or security packs, does not use `--privileged`, and does not install GUI Cursor.

`agent` is Cursor. Grok’s installer also ships an `agent` binary; `setup.sh` removes that extra so the name stays Cursor. Invoke Grok as `grok`.

## What you can run today

From a machine with Docker (for example Docker Desktop on Windows), start the factory with the repo as `/workspace`:

```bash
docker run -it --name agent_os_factory -v "$(pwd):/workspace" -w /workspace debian:bookworm-slim
```

Inside the container, as root:

```bash
bash /workspace/setup.sh
```

Then:

```bash
node -v && npm -v && python3 -V && git --version && agent --version && codex --version && grok --version && opencode --version
```

`python3 -V` prints the version. `python3 -v` turns on verbose interpreter output.

The host one-liner is also in `factory-host.sh`. Re-run `setup.sh` anytime; it skips tools that are already present.

Auth is yours (`agent login`, Codex, `grok login`, OpenCode). The script does not store secrets.

## Toolchain

| Piece | Source | Notes |
| --- | --- | --- |
| Node 22 LTS + npm | nodejs.org tarball into `/usr/local` | Not Debian `nodejs` |
| Python 3 + venv/pip | Debian apt | Bookworm 3.11 in verification |
| git, curl, build-essential, jq, tmux, zstd | apt | Listed in `setup.sh` |
| Cursor Agent | `curl https://cursor.com/install -fsS \| bash` | CLI binary `agent` |
| OpenAI Codex | chatgpt.com/codex/install.sh, npm fallback `@openai/codex` | `codex` |
| xAI Grok Build | x.ai/cli/install.sh, npm fallback `@xai-official/grok` | `grok`; colliding `agent` symlink removed |
| OpenCode | opencode.ai/install, npm fallback `opencode-ai` | `opencode` |

Verified in `debian:bookworm-slim`:

```text
node -v            v22.23.2
npm -v             10.9.8
python3 -V         Python 3.11.2
git --version      git version 2.39.5
agent --version    2026.09.10-fd3934a
codex --version    codex-cli 0.154.0
grok --version     grok 1.0.30
opencode --version 1.18.30
```

## Status

Private prototype. Factory script only. Nested Docker, ISO/chroot, and a desktop session are out of scope until a later slice.

## License

MIT. See [LICENSE](LICENSE).

## Docs

- [Factory notes](docs/factory.md)
