---
name: kill-switch
description: "Stop everything - pause every scheduled job and watcher and stop any errand in progress - when the person says \"stop everything\", \"kill switch\", \"pause everything\" or similar. Also handles \"resume everything\"."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [safety, control]
---

# Kill switch

## Stop
1. Stop whatever errand you're in the middle of. Don't submit, send or buy
   anything.
2. List all scheduled jobs with the cronjob tool and pause every one of
   them (briefs, recaps, distill, watchers, reminders).
3. Close the browser if one is open.
4. Reply in one or two lines: "Stopped. N scheduled jobs paused, nothing in
   progress. Say 'resume everything' when you want me back." Keep the
   persona voice but no jokes.

## Resume
1. List paused jobs and resume them all, except watchers past their end
   date.
2. Reply: "Back on. N jobs resumed." and name the next one due.

The person can also stop the whole agent from the server:
`hermes gateway stop` (no messages in or out until `hermes gateway start`).
