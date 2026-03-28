# HEARTBEAT.md - Proactive Tasks

# Check git status of LEVER Protocol repo
- check lever-protocol git status
  message: "Check git status of /home/lever/lever-protocol. Are there uncommitted changes? Untracked files? Is the repo clean? Report any issues."
  every: 4h

# Surface stalled intentions
- check stalled intentions
  message: "Read /home/lever/command/shared-brain/INTENTIONS.md. Are there any ACTIVE items that have been sitting idle for more than 48 hours? If so, flag them."
  every: 12h

# Check for pending approvals
- check pending approvals
  message: "Check INTENTIONS.md for PENDING MASTER APPROVAL items and ADVISOR_BRIEFS.md for pending proposals. If anything has been waiting more than 24 hours, remind Master."
  every: 8h
