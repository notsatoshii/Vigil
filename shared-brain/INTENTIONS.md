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
- ALL WORKSTREAMS: NEVER sit idle. When you finish a task, check INTENTIONS.md and KANBAN.md for the next thing to do. If nothing is queued, find something to improve proactively.
- COMMANDER: every 30 minutes, check for idle capacity and dispatch work from the queue. If the queue is empty, generate work (IMPROVE reviews, RESEARCH scans, OPERATE checks, ADVISOR analysis).
- IMPROVE: do not wait for the weekly schedule. If you are idle, review the product. There is always something to improve.
- RESEARCH: do not wait for the twice-daily scan. If you are idle, check watchlists, update trend data, research something from the knowledge gaps.
- BUILD: when no tasks are assigned, check KANBAN BACKLOG and INTENTIONS ACTIVE. Pick the top item and start the PLAN pipeline.
- SECURE: do not wait for Monday. If you are idle, pick a contract and audit it. Rotate through all 16 contracts.

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

## URGENT (immediate autonomous work)

1. VIGIL-DASHBOARD must be dramatically improved. It needs to be a real mission control. The KANBAN must be visible with real data. The pipeline must show tasks flowing. Activity must be live. This is the HIGHEST priority Vigil self-improvement task. OPERATE and BUILD should work on this immediately.
2. All 5 session slots must ALWAYS be full. The scheduler runs every 10 seconds. If a slot opens, fill it within 10 seconds with the next priority task.
3. VERIFY must use Puppeteer to take actual screenshots and evaluate them visually. Not just code review.
