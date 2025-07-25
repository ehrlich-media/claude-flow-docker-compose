#!/bin/bash
echo '=== SECURE NODE.JS CONTAINER WITH FULL BUILD SUPPORT ==='

# System vorbereiten - dpkg und apt Verzeichnisse erstellen
mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/info /var/lib/apt/lists/partial
mkdir -p /var/cache/apt/archives/partial
mkdir -p /var/log/apt
touch /var/lib/dpkg/status

# ALLE benötigten Pakete installieren (inkl. Build-Tools)
echo "Installiere System-Pakete..."
apt-get update && apt-get install -y \
  python3 \
  python3-pip \
  python3-dev \
  build-essential \
  g++ \
  make \
  curl \
  wget \
  sudo \
  git \
  openssh-client \
  sqlite3 \
  libsqlite3-dev

# Python symlink erstellen
ln -sf /usr/bin/python3 /usr/bin/python

# GitHub CLI als Binary installieren (umgeht APT Probleme)
echo "Installiere GitHub CLI..."
GH_VERSION="2.23.0"
wget -q "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" -O /tmp/gh.tar.gz
tar -xzf /tmp/gh.tar.gz -C /tmp
mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/
chmod +x /usr/local/bin/gh
rm -rf /tmp/gh.tar.gz /tmp/gh_${GH_VERSION}_linux_amd64

# Claude User erstellen (prüfe ob UID 1000 schon existiert)
if ! id -u claude >/dev/null 2>&1; then
  if id -u 1000 >/dev/null 2>&1; then
    useradd -m -u 1001 -s /bin/bash claude
  else
    useradd -m -u 1000 -s /bin/bash claude
  fi
fi

echo 'claude ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Home-Verzeichnis sicherstellen (wichtig weil /home ein tmpfs ist!)
mkdir -p /home/claude
chown claude:claude /home/claude
chmod 755 /home/claude

# SSH-Verzeichnis für claude user vorbereiten
mkdir -p /home/claude/.ssh
chmod 700 /home/claude/.ssh

# SSH-Keys vom Host kopieren (falls gemountet)
if [ -d "/host-ssh" ]; then
  if [ -f "/host-ssh/id_ed25519" ]; then
    cp /host-ssh/id_ed25519 /home/claude/.ssh/
    chmod 600 /home/claude/.ssh/id_ed25519
  fi
  if [ -f "/host-ssh/id_ed25519.pub" ]; then
    cp /host-ssh/id_ed25519.pub /home/claude/.ssh/
    chmod 644 /home/claude/.ssh/id_ed25519.pub
  fi
  echo "SSH-Keys wurden kopiert"
else
  echo "Warnung: /host-ssh nicht gefunden"
fi

chown -R claude:claude /home/claude/.ssh

# Workspace permissions
chown -R claude:claude /workspace || true

# NPM für User verfügbar machen
mkdir -p /home/claude/.npm-global
mkdir -p /home/claude/.npm
chown -R claude:claude /home/claude/.npm-global
chown -R claude:claude /home/claude/.npm

# NPM Config global setzen
npm config set prefix /home/claude/.npm-global --global
npm config set python /usr/bin/python3 --global

# Bash-Profile erstellen
touch /home/claude/.bashrc
touch /home/claude/.profile
echo 'export PATH=/home/claude/.npm-global/bin:$PATH' >> /home/claude/.bashrc
echo 'export PATH=/home/claude/.npm-global/bin:$PATH' >> /home/claude/.profile
echo 'export PYTHON=/usr/bin/python3' >> /home/claude/.bashrc
echo 'export PYTHON=/usr/bin/python3' >> /home/claude/.profile
chown claude:claude /home/claude/.bashrc /home/claude/.profile

# Python Pakete installieren
echo 'Installiere Python-Pakete...'
pip3 install anthropic requests --break-system-packages 2>/dev/null || pip3 install anthropic requests

# Git Config und SSH Known Hosts für claude user
su - claude -c "
  # Git Konfiguration
  git config --global user.name 'Claude Container'
  git config --global user.email 'claude@container.local'
  git config --global init.defaultBranch main
  
  # Known hosts für GitHub/GitLab hinzufügen
  ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts 2>/dev/null || true
  ssh-keyscan -t rsa gitlab.com >> ~/.ssh/known_hosts 2>/dev/null || true
  ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true
  ssh-keyscan -t ed25519 gitlab.com >> ~/.ssh/known_hosts 2>/dev/null || true
"

# Als claude user die NPM Tools installieren
echo 'Installiere NPM Tools als claude user...'
su - claude -c "
  export PATH=/home/claude/.npm-global/bin:\$PATH
  export PYTHON=/usr/bin/python3
  
  # NPM Config für claude setzen
  npm config set python /usr/bin/python3
  
  echo 'Installiere Claude Code (Anthropic CLI)...'
  npm install -g @anthropic-ai/claude-code
  
  echo 'Installiere Claude Flow (mit Build Support)...'
  npm install -g claude-flow@alpha
"

# Als claude user weitermachen
exec su - claude -c "
  export PATH=/home/claude/.npm-global/bin:\$PATH
  export PYTHON=/usr/bin/python3
  cd /workspace
  
  echo ''
  echo '=== SYSTEM INFO ==='
  echo \"✓ User: \$(whoami) (UID: \$(id -u))\"
  echo \"✓ Node.js: \$(node --version)\"
  echo \"✓ NPM: \$(npm --version)\"
  echo \"✓ Python: \$(python3 --version)\"
  echo \"✓ GCC: \$(gcc --version | head -n1)\"
  echo \"✓ SQLite: \$(sqlite3 --version)\"
  echo \"✓ GitHub CLI: \$(gh --version | head -n1)\"
  echo ''
  echo '=== INSTALLED TOOLS ==='
  echo \"✓ Claude Code: \$(claude --version 2>/dev/null || echo 'Prüfe mit: which claude')\"
  echo \"✓ Claude Flow: \$(claude-flow --version 2>/dev/null || echo 'Prüfe mit: which claude-flow')\"
  echo ''
  echo 'Container bereit!'
  echo ''
  echo 'Verfügbare Tools:'
  echo '  - claude         (Anthropic Claude Code)'
  echo '  - claude-flow    (ruvnet Claude Flow mit vollem Support)'
  echo ''
  echo 'Teste claude-flow mit:'
  echo '  claude-flow hive-mind spawn \"deine aufgabe\" --claude'
  echo ''
  
  # Container am Leben halten
  exec tail -f /dev/null
"