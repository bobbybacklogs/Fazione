# Factory

Personal Docker workshop for Node 22, Python, and Cursor Agent (`agent`). This is not an ISO of Fazione. It is not Kali. It is not GUI Cursor.

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
node -v && npm -v && python3 -V && git --version && agent --version
```

(`python3 -V` is the version flag.)

Auth is yours: `agent login` or `CURSOR_API_KEY`. The script does not store secrets.

Re-run `setup.sh` anytime; it skips work that is already done.
