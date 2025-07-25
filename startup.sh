#!/bin/bash
echo '=== SECURE NODE.JS CONTAINER ==='

# System vorbereiten - dpkg Verzeichnisse erstellen
mkdir -p /var/lib/dpkg/updates
touch /var/lib/dpkg/status
mkdir -p /var/lib/apt/lists/partial

apt-get update && apt-get install -y python3 python3-pip python3-dev build-essential curl wget sudo git

# Python symlink
ln -sf /usr/bin/python3 /usr/bin/python

# Claude User erstellen (prüfe ob UID 1000 schon existiert)
if ! id -u claude >/dev/null 2>&1; then
  if id -u 1000 >/dev/null 2>&1; then
    # UID 1000 existiert, nutze 1001
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

# Workspace permissions
chown -R claude:claude /workspace || true

# NPM für User verfügbar machen
mkdir -p /home/claude/.npm-global
mkdir -p /home/claude/.npm
chown -R claude:claude /home/claude/.npm-global
chown -R claude:claude /home/claude/.npm
npm config set prefix /home/claude/.npm-global --global

# Claude Tools installieren
echo 'Installiere Claude Code (Anthropic CLI)...'
su - claude -c "
  export PATH=/home/claude/.npm-global/bin:\$PATH
  npm install -g @anthropic-ai/claude-code || echo 'Claude Code Installation fehlgeschlagen'
"

echo 'Installiere Claude Flow (ruvnet)...'
su - claude -c "
  export PATH=/home/claude/.npm-global/bin:\$PATH
  export PYTHON=/usr/bin/python3
  npm config set python /usr/bin/python3
  npm install -g claude-flow@alpha || echo 'Claude Flow Installation fehlgeschlagen'
"

# Bash-Profile erstellen
touch /home/claude/.bashrc
touch /home/claude/.profile
echo 'export PATH=/home/claude/.npm-global/bin:$PATH' >> /home/claude/.bashrc
echo 'export PATH=/home/claude/.npm-global/bin:$PATH' >> /home/claude/.profile
chown claude:claude /home/claude/.bashrc /home/claude/.profile

# Als claude user weitermachen
exec su - claude -c "
  export PATH=/home/claude/.npm-global/bin:\$PATH
  cd /workspace
  
  echo ''
  echo '=== SYSTEM INFO ==='
  echo \"✓ User: \$(whoami) (UID: \$(id -u))\"
  echo \"✓ Node.js: \$(node --version)\"
  echo \"✓ NPM: \$(npm --version)\"
  echo \"✓ Claude Code: \$(claude --version 2>/dev/null || echo 'Nicht gefunden')\"
  echo \"✓ Claude Flow: \$(npx claude-flow@alpha --version 2>/dev/null || echo 'Nicht gefunden')\"
  echo \"✓ Python: \$(python3 --version)\"
  echo ''
  echo 'Container bereit!'
  echo ''
  echo 'Verfügbare Tools:'
  echo '  - Claude Code (Anthropic): claude'
  echo '  - Claude Flow (ruvnet): npx claude-flow@alpha'
  echo ''
  
  # Container am Leben halten
  exec tail -f /dev/null
"