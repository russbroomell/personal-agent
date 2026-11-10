---
name: Setup or bot problem
about: Something failed during setup, or the bot isn't working as described
labels: bug
---

**What happened**
<!-- One or two sentences. What did you expect, and what did you get? -->

**Where**
<!-- Which step of the README (1-5), which script, or which chat command. -->

**Server**
<!-- Provider and size (e.g. OVH 4 GB), and Ubuntu 24.04 / Debian 12 / Debian 13. -->

**Health check**
<!-- Paste the output of:  bash ~/personal-agent/scripts/check.sh --speed
     It contains no passwords or tokens. It does show your Tailscale address
     (…ts.net); replace that with "my-tailnet" if you'd rather not share it. -->

```
paste here
```

**Error lines** (if any)
<!-- journalctl --user -u hermes-gateway -n 60 --no-pager | grep -iE -B2 -A3 'error|traceback'
     Don't paste anything from .env or auth.json, or any bot token. -->

```
paste here
```
