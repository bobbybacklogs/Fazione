# Factory

Personal Docker workshop for Node 22, Python, Cursor Agent (`agent`), Codex, Grok Build, and OpenCode. This is not an ISO of Fazione. It is not Kali. It is not GUI Cursor.

`agent` is Cursor. Grok’s extra `agent` binary is removed; call Grok as `grok`.

## Host

```bash
docker run -it --name agent_os_factory -v "$(pwd):/workspace" -w /workspace debian:bookworm-slim
```

Do not add `--privileged` until ISO work or nested Docker actually needs it.

## Inside the container

```bash
bash /workspace/setup.sh
```

Then:

```bash
node -v && npm -v && python3 -V && git --version && agent --version && codex --version && grok --version && opencode --version
```

(`python3 -V` is the version flag.)

Auth is yours. The script does not store secrets.

Re-run `setup.sh` anytime; it skips work that is already done.
