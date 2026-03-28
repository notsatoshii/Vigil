# INTENTIONS
## Master's priority queue for autonomous work.

---

## ACTIVE
*Work on these when idle, in priority order.*

1. Complete Vigil migration (Phase 1 through Phase 9)

---

## STANDING ORDERS
*Always valid, recurring.*

- Never restart disabled services (lever-loop, lever-qa, lever-seeder, lever-watchdog)
- Strip CSP tag after every frontend build
- Use Number(value)/1e6, never parseFloat(formatUsdt())
- All contract addresses from deploy-env.sh, never hardcoded
- OPERATE: continuously monitor Vigil system health. When errors appear in logs (telegram-gateway.log, inbox.log, health-check.log, openclaw logs), diagnose and fix the root cause autonomously. Do not wait for Master to report issues.
- OPERATE: after any Vigil system fix, commit to git and restart affected services
- ADVISOR: during daily brief, check TIMMY_PERSONALITY.md observation log for frustration events. If Master was frustrated, trace why and propose a system fix.
- ADVISOR: evaluate Vigil's own performance. Are sessions timing out? Is the gateway dropping messages? Are workstreams producing quality output? Propose fixes.
- ALL WORKSTREAMS: if you encounter a Vigil system bug during your work (gateway not responding, permissions issue, missing context), log it in shared-brain/LESSONS.md so OPERATE can fix it

---

## PENDING MASTER APPROVAL
*Security findings and other items awaiting Master's go/no-go decision.*
*BUILD does NOT act on these until Master approves.*

*None yet.*

---

## ADVISOR APPROVED
*Auto-promoted from approved ADVISOR proposals.*

*None yet.*

---

## COMPLETED
*For record keeping.*

*None yet.*
