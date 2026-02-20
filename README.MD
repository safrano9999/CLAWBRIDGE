# 🦞 CLAWBRIDGE

A minimal, rootless job dispatcher triggered by filesystem events.  
Built for [OpenClaw](https://openclaw.dev) – but works with any unprivileged service user.  
No sudo. No polling. Just files.

---

## 💡 What is this and why does it exist?

This setup is based on a deliberate security decision: running OpenClaw under its own dedicated system user `openclaw`, sharing only specific designated folders where needed. Each user stays in its own lane.

But here's the problem: what if OpenClaw needs to trigger something that belongs to your main user? Like sorting your emails, running a backup, or executing a personal script? You can't just let `openclaw` run those — it has no access, and giving it access would defeat the entire point.

**CLAWBRIDGE solves this with a dead-simple idea:**

> `openclaw` drops a file into a shared folder. That's it. That's the only thing it's allowed to do.

Your main user's service watches that folder. The moment a file appears, it picks it up, runs the right script, and cleans up. `openclaw` drops a file — that is the only thing CLAWBRIDGE is responsible for. What else is configured between the two users is up to you.

This keeps OpenClaw fully isolated while still letting it trigger actions on your behalf — without sudo, without shared passwords, without open ports.

---

## 🔒 Security Model

CLAWBRIDGE runs as a regular user service via systemd.  
The only shared surface between OpenClaw and the dispatcher is a single directory: `TRIGGERDIR/`.

- OpenClaw gets write access to `TRIGGERDIR/` – dropping a file there triggers jobs on the main user's side
- Job scripts run in the main user's context
- inotify is a Linux kernel mechanism – no polling process, no CPU load at idle

```
🦞 openclaw
    │
    │  touch TRIGGERDIR/A
    ▼
📬 TRIGGERDIR/           ← only shared surface (write-only for openclaw)
    ▲
    │  kernel notifies instantly via inotify
    ▼
⚙️  clawbridge.sh         ← runs as owner, reads config, executes jobs
```

---

## 📁 Structure

```
clawbridge/
├── clawbridge.sh       ← dispatcher (systemd user service)
├── clawbridge.yaml     ← job registry
├── clawbridge.service  ← systemd user unit
├── TRIGGERDIR/         ← trigger files land here
├── SCRIPTS/
│   └── A_example.sh   ← smoke test
└── logs/
    ├── CLAWBRIDGE.log
    └── DROP.log
```

---

## 🚀 Setup

### 1. Dependencies

```bash
sudo apt install inotify-tools github-cli
```

### 2. Permissions

```bash
chmod +x clawbridge.sh SCRIPTS/*.sh
```

### 3. Service

```bash
mkdir -p ~/.config/systemd/user
ln -s "$(realpath clawbridge.service)" ~/.config/systemd/user/clawbridge.service
systemctl --user daemon-reload
systemctl --user enable --now clawbridge
```

To keep the service running without an active login session:

```bash
sudo loginctl enable-linger $USER
```

### 4. TRIGGERDIR permissions

⚠️ Give OpenClaw write access to `TRIGGERDIR/`:

```bash
sudo chown $USER:openclaw TRIGGERDIR
sudo chmod 1770 TRIGGERDIR
```

---

## 📋 Job Modes

| Mode | Behavior |
|------|----------|
| `instant` | ⚡ inotify fires immediately when trigger file appears |
| `cron` | 👻 ignored by CLAWBRIDGE – the cron script handles it itself, no `script` needed |

Script paths in yaml support: `./relative`, `$HOME/...`, or absolute.

After editing `clawbridge.yaml`:

```bash
systemctl --user restart clawbridge
```

---

## 🎯 Triggering

```bash
touch TRIGGERDIR/A
```

---

## ⏰ Cron Jobs

Declare with `mode: cron` in the yaml – no `script` needed. CLAWBRIDGE ghosts the trigger file completely, leaving it for the cron script to consume.

Add this snippet at the top of any cron script:

```bash
_TRIGGER="$HOME/souly9999/CLAWBRIDGE/TRIGGERDIR/C"
[ ! -f "$_TRIGGER" ] && exit 0
rm -f "$_TRIGGER"
```

No trigger file → silent exit. Trigger file present → consume and continue.

---

## 📊 Logs

```bash
tail -f ~/souly9999/CLAWBRIDGE/logs/CLAWBRIDGE.log
tail -f ~/souly9999/CLAWBRIDGE/logs/DROP.log
journalctl --user -u clawbridge -f
```
