# OVERSEER REPORT
## Latest at top. Written by ADVISOR every 2 hours.
## Tracks efficiency, quality, bottlenecks, and systemic issues.

---

## 2026-03-28 14:01 UTC (Inaugural Report)

### 1. EFFICIENCY: 6/10

**Sessions today:** 13 dispatched (11 user-facing per SESSION_COSTS, plus scheduler-managed pipeline sessions). System has been live since ~08:10 UTC, so roughly 6 hours of operation.

**Pipeline utilization:** 5 tasks in scheduler, but only 3 are actually running (lever-bug-1 critiquing, lever-bug-2 building, lever-bug-5 planning). lever-bug-3 and lever-bug-4 have pid=0 and are sitting in "planned" with no agent assigned. The scheduler has 5 slots. Two are wasted.

**Why this matters:** BUG-3 and BUG-4 both have approved plans and should be moving to CRITIQUE right now. Every hour they sit idle is an hour of pipeline capacity burned. At current throughput (plan -> critique -> build -> verify takes ~2-3 hours per bug), those two bugs could have been through critique by now if the scheduler had picked them up immediately after planning completed at 13:45-13:47.

**Verdict:** The scheduler is not pulling planned tasks into critique aggressively enough. It dispatched planning for BUG-5 but left BUG-3 and BUG-4 sitting. This is the single biggest efficiency problem right now.

---

### 2. QUALITY: 8/10

**Good:**
- BUILD (Audit Fixes V2): Excellent session. 6 fixes, 10 contracts, 8 test files, 1068 tests passing. Solid.
- VERIFY: Caught real concerns (InsuranceFundFixed.sol deployment risk, closing fee type mismatch, role grants needed). Not rubber-stamping.
- PLAN (BUG-2, BUG-3, BUG-4): Root cause analysis is thorough, fixes are scoped tightly. BUG-4 plan is 2 lines in 1 file. That is good planning.
- CRITIQUE (BUG-1): Caught a critical contradiction with LESSONS.md. This is exactly what CRITIQUE exists for. The plan had the fix direction backwards. CRITIQUE saved the team from implementing a bug as a fix.

**Concern:**
- PLAN for BUG-3 has an open question about PositionManager being in the "protected list" and whether getMarketPositions() exists. This should have been resolved during planning, not deferred to BUILD. PLAN should read the contract before writing the plan.

---

### 3. BOTTLENECKS: LEVER-BUG-1 is stuck

**BUG-1 status:** KANBAN says BLOCKED (CRITIQUE verdict: REVISE). Scheduler says "critiquing" with an active PID. This is contradictory. Either the critique session is still running (and will produce a REVISE verdict), or the KANBAN was updated but the scheduler was not. Either way, BUG-1 needs PLAN to revise, but no revision session has been dispatched.

**The BUG-1 problem is significant.** The CRITIQUE found that the plan contradicts Master's explicit lesson (LESSONS.md line 100, marked "CRITICAL, from Master"). The plan says use raw entryPI; Master says use impact-adjusted entryPrice. CRITIQUE's economic analysis (impact spread creates phantom credit, explaining 38 winners / 0 losers) is compelling. PLAN must reconcile this before BUILD touches it.

**Pipeline flow:** PLAN -> CRITIQUE is working. CRITIQUE -> PLAN (revision loop) is not automated. The scheduler does not know how to send a task back to PLAN after a REVISE verdict. This is a gap.

---

### 4. DATA INTEGRITY: scheduler-state.json has wrong plan_file references

lever-bug-3 and lever-bug-4 both point to `plan-20260328-133419.md` as their plan_file. That is the BUG-2 plan. The actual plan files are:
- BUG-3: `handoffs/plan-lever-bug-3.md`
- BUG-4: `handoffs/plan-lever-bug-4.md`

This means if the scheduler tries to pass plan context to CRITIQUE or BUILD for these tasks, it will feed them the wrong plan. BUILD would implement the wrong fix for the wrong bug. This needs to be fixed in the scheduler state immediately.

---

### 5. RECURRING PROBLEMS: None new

Checked LESSONS.md against recent sessions. No repeated mistakes detected. The deposit-without-transfer pattern (LESSONS.md) was correctly identified and fixed in BUG-4's plan. The entryPrice/entryPI confusion (LESSONS.md line 100) was correctly caught by CRITIQUE before it reached BUILD. The system is learning.

---

### 6. SYSTEM HEALTH: Stable

- All 8 services active. RAM 52%, disk 18%, load 0.39.
- Telegram gateway: clean since 12:46 restart. Some long-running tasks (2089s, 2409s, 3572s) but they completed without error.
- Health check: last ran at 12:00, had a false alarm on openclaw-gateway (mid-restart). Next run at 16:00. The OPERATE session already cleared the stale escalation flag.
- No dispatcher.log found (replaced by scheduler.py). Not an issue, just noting.

---

### 7. WASTED WORK: Minimal

- RESEARCH ran 5 inbox ingestion sessions (test-note, 2 PDFs, 1 photo, 1 PNG). These are automated and low-cost. Not wasted, but not high-value either.
- The morning was spent on landing page work (plan, build, verify, multiple revisions). Then shifted to critical contract bugs in the afternoon. Priorities are now correct.

---

### ACTIONS REQUIRED

| # | Action | Who | Priority |
|---|--------|-----|----------|
| 1 | Fix scheduler-state.json: update plan_file for lever-bug-3 and lever-bug-4 to correct paths | OPERATE or scheduler fix | CRITICAL |
| 2 | Dispatch CRITIQUE for lever-bug-3 and lever-bug-4 immediately (they have approved plans) | Scheduler | HIGH |
| 3 | Dispatch PLAN revision for lever-bug-1 with CRITIQUE feedback attached | Scheduler | HIGH |
| 4 | Add CRITIQUE->PLAN revision loop to scheduler (currently no automation for REVISE verdicts) | OPERATE/BUILD | MEDIUM |
| 5 | PLAN should verify contract interfaces before writing plans (BUG-3 open question) | PLAN CLAUDE.md update | LOW |

---

### SYSTEM IMPROVEMENT PROPOSALS

**Proposal 1: Scheduler should auto-advance planned tasks to critique**
Currently lever-bug-3 and lever-bug-4 have plans but no agent working on them. The scheduler should automatically move "planned" tasks to "critiquing" when slots are available, without waiting for manual dispatch.

**Proposal 2: Scheduler should handle REVISE verdicts**
When CRITIQUE returns REVISE, the scheduler should automatically transition the task back to "planning" and dispatch a new PLAN session with the critique feedback. Currently this requires manual intervention, and BUG-1 is stuck because of it.

**Proposal 3: Validate plan_file references on write**
The scheduler wrote wrong plan_file paths for BUG-3 and BUG-4. It should validate that the referenced file (a) exists and (b) mentions the correct task ID before saving.
