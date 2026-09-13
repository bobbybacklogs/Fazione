#!/usr/bin/env bash
# Agent OS factory toolchain. Run *inside* debian:bookworm-slim as root.
#
# Host (no --privileged until ISO / nested Docker):
#   docker run -it --name agent_os_factory -v "$(pwd):/workspace" -w /workspace debian:bookworm-slim
# then:
#   bash /workspace/setup.sh
#
# Success: node -v && python3 -V && git --version && agent --version
#          && codex --version && grok --version && opencode --version
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

NODE_MAJOR=22
NODE_PREFIX=/usr/local
CURSOR_INSTALL_URL="https://cursor.com/install"

log() { printf '==> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root inside the factory container: bash /workspace/setup.sh" >&2
    exit 1
  fi
}

apt_base() {
  log "apt: base + python"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    git \
    sudo \
    bash \
    procps \
    locales \
    openssh-client \
    unzip \
    tar \
    gzip \
    xz-utils \
    zstd \
    jq \
    tmux \
    build-essential \
    pkg-config \
    libstdc++6 \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev
  if ! grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null; then
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  fi
  locale-gen en_US.UTF-8 >/dev/null
  update-locale LANG=en_US.UTF-8
}

node_major() {
  node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/' || true
}

install_node_22() {
  if have node && [[ "$(node_major)" == "$NODE_MAJOR" ]]; then
    log "Node $(node -v) already present (22 LTS) — skip tarball"
    return 0
  fi
  if have node && [[ -n "$(node_major)" ]]; then
    log "Replacing Node $(node -v) with official 22 LTS tarball (not Debian nodejs)"
  else
    log "Node 22 LTS from nodejs.org (not Debian nodejs)"
  fi

  local arch tarball url tmp
  case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *)
      echo "Unsupported arch $(uname -m) for Node tarball" >&2
      exit 1
      ;;
  esac

  tmp="$(mktemp -d)"
  curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/SHASUMS256.txt" -o "$tmp/SHASUMS256.txt"
  tarball="$(
    grep -E "node-v${NODE_MAJOR}\\.[0-9.]+-linux-${arch}\\.tar\\.xz$" "$tmp/SHASUMS256.txt" \
      | awk '{print $2}' \
      | tail -n1
  )"
  if [[ -z "$tarball" ]]; then
    echo "Could not find Node ${NODE_MAJOR} linux-${arch} tarball in SHASUMS256.txt" >&2
    rm -rf "$tmp"
    exit 1
  fi
  url="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/${tarball}"
  log "fetch $url"
  curl -fsSL "$url" -o "$tmp/$tarball"
  (cd "$tmp" && grep "  ${tarball}$" SHASUMS256.txt | sha256sum -c -)
  tar -xJf "$tmp/$tarball" -C "$NODE_PREFIX" --strip-components=1
  rm -rf "$tmp"
  hash -r || true
  if have corepack; then
    corepack enable >/dev/null || true
  fi
}

path_files() {
  mkdir -p /etc/profile.d /root
  cat >/etc/profile.d/agent-os-factory.sh <<'EOF'
# Cursor `agent` must win over Grok's extra `agent` symlink in ~/.grok/bin.
export PATH="/usr/local/bin:${HOME}/.local/bin:${HOME}/.grok/bin:${HOME}/.opencode/bin:${PATH}"
EOF
  chmod 644 /etc/profile.d/agent-os-factory.sh

  local line='export PATH="$HOME/.local/bin:$HOME/.grok/bin:/usr/local/bin:$PATH"'
  touch /root/.bashrc
  if ! grep -Fqx "$line" /root/.bashrc; then
    printf '\n# Cursor Agent (factory)\n%s\n' "$line" >> /root/.bashrc
  fi
  # Non-login interactive bash in docker often skips .bashrc when stdin is not a tty.
  touch /root/.profile
  if ! grep -Fq 'agent-os-factory.sh' /root/.profile 2>/dev/null; then
    printf '\n. /etc/profile.d/agent-os-factory.sh\n' >> /root/.profile
  fi
}

install_cursor_agent() {
  export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
  if have agent && agent --version >/dev/null 2>&1; then
    log "Cursor Agent already on PATH ($(agent --version 2>/dev/null | head -n1)) — skip installer"
    return 0
  fi
  log "Cursor CLI from cursor.com/install (agent, not the Electron IDE)"
  curl -fsS "$CURSOR_INSTALL_URL" | bash
}

# Grok's installer also links `agent`; this factory's `agent` is Cursor CLI.
protect_cursor_agent() {
  local target candidate
  mkdir -p "${HOME}/.local/bin"
  rm -f "${HOME}/.grok/bin/agent"
  for candidate in "${HOME}/.local/bin/agent" /usr/local/bin/agent; do
    [[ -e "$candidate" || -L "$candidate" ]] || continue
    target="$(readlink -f "$candidate" 2>/dev/null || true)"
    if [[ "$target" == *grok* ]] || [[ "$target" == *'/.grok/'* ]]; then
      log "removing Grok's $candidate so Cursor Agent keeps the name agent"
      rm -f "$candidate"
    fi
  done
}

install_codex() {
  export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
  if have codex && codex --version >/dev/null 2>&1; then
    log "Codex already on PATH ($(codex --version 2>/dev/null | head -n1)) — skip"
    return 0
  fi
  log "OpenAI Codex CLI"
  local script
  script="$(mktemp)"
  if curl -fsSL https://chatgpt.com/codex/install.sh -o "$script" && bash "$script"; then
    rm -f "$script"
    hash -r || true
    if have codex; then
      return 0
    fi
  fi
  rm -f "$script"
  log "Codex installer script failed — npm @openai/codex"
  npm install -g @openai/codex
}

install_grok() {
  export PATH="${HOME}/.local/bin:${HOME}/.grok/bin:/usr/local/bin:${PATH}"
  if have grok && { grok --version >/dev/null 2>&1 || grok version >/dev/null 2>&1; }; then
    log "Grok already on PATH ($(grok --version 2>/dev/null || grok version 2>/dev/null | head -n1)) — skip"
    protect_cursor_agent
    return 0
  fi
  log "xAI Grok Build CLI"
  local script
  script="$(mktemp)"
  if curl -fsSL https://x.ai/cli/install.sh -o "$script" && bash "$script"; then
    rm -f "$script"
    hash -r || true
  else
    rm -f "$script"
  fi
  if ! have grok; then
    log "Grok curl installer missed PATH — npm @xai-official/grok"
    npm install -g @xai-official/grok
  fi
  protect_cursor_agent
}

install_opencode() {
  export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
  if have opencode && opencode --version >/dev/null 2>&1; then
    log "OpenCode already on PATH ($(opencode --version 2>/dev/null | head -n1)) — skip"
    return 0
  fi
  log "OpenCode CLI"
  export XDG_BIN_DIR="${HOME}/.local/bin"
  mkdir -p "$XDG_BIN_DIR"
  local script
  script="$(mktemp)"
  if curl -fsSL https://opencode.ai/install -o "$script" && bash "$script"; then
    rm -f "$script"
    hash -r || true
    export PATH="${HOME}/.local/bin:${HOME}/.opencode/bin:/usr/local/bin:${PATH}"
    if have opencode; then
      return 0
    fi
    if [[ -x "${HOME}/.local/bin/opencode" || -x "${HOME}/.opencode/bin/opencode" ]]; then
      return 0
    fi
  fi
  rm -f "$script"
  log "OpenCode installer script failed — npm opencode-ai"
  npm install -g opencode-ai
}

tool_ok() {
  local name="$1"
  shift
  if ! have "$name"; then
    echo "missing on PATH: $name" >&2
    return 1
  fi
  if "$@" >/dev/null 2>&1; then
    "$@"
    return 0
  fi
  echo "$name did not accept version flag" >&2
  return 1
}

verify() {
  export PATH="${HOME}/.local/bin:${HOME}/.grok/bin:/usr/local/bin:${PATH}"
  protect_cursor_agent
  hash -r || true
  log "verify"
  node -v
  npm -v
  python3 -V
  git --version
  agent --version
  tool_ok codex codex --version
  if have grok && grok --version >/dev/null 2>&1; then
    grok --version
  else
    tool_ok grok grok version
  fi
  tool_ok opencode opencode --version
  local major
  major="$(node_major)"
  if [[ "$major" != "$NODE_MAJOR" ]]; then
    echo "Node major is $major, expected $NODE_MAJOR" >&2
    exit 1
  fi
  local agent_path
  agent_path="$(command -v agent)"
  if [[ "$(readlink -f "$agent_path" 2>/dev/null || echo "$agent_path")" == *grok* ]]; then
    echo "agent on PATH is Grok, not Cursor CLI" >&2
    exit 1
  fi
}

main() {
  require_root
  apt_base
  path_files
  install_node_22
  install_cursor_agent
  install_codex
  install_grok
  install_opencode
  protect_cursor_agent
  path_files
  verify
  log "factory ready. Auth is yours (agent login / grok login / codex / opencode). No keys in this script."
}

main "$@"
