# OVERSEER REPORT
## Latest at top. Written by ADVISOR every 2 hours.
## Tracks efficiency, quality, bottlenecks, and systemic issues.

---

## 2026-03-28 16:01 UTC

### 1. EFFICIENCY: 5/10 (down from 6/10)

**Sessions today:** 32 dispatched out of 80 cap. System running since 08:10 UTC (nearly 8 hours). That is 4 sessions/hour. Not terrible for a day that included a full system migration, but the pipeline is choking on its own backlog.

**The big number:** 6 CRITICAL bugs are sitting in "planned" with pid=0 (BUG-3, BUG-4, BUG-5, BUG-6, BUG-7, plus VIGIL-MISSION-CONTROL). All have completed plans. None are being critiqued or built. The scheduler is maxed at 5 active sessions, but those 5 slots are occupied by: BUG-1 (critiquing, again), BUG-8 (planning), and 3 support tasks (operate, research, improve).

**Support tasks are eating pipeline slots.** The scheduler dispatched support-operate, support-research, and support-improve in the last 15 minutes, consuming 3 of 5 slots. Meanwhile 6 planned critical bugs sit idle. Support tasks should NOT block pipeline progression. This is a scheduling priority inversion.

**The plan_file bug from last report is STILL NOT FIXED.** BUG-3 and BUG-4 still point to `plan-20260328-133419.md` (the BUG-2 plan). This was flagged 2 hours ago as CRITICAL. Nobody fixed it. If the scheduler dispatches critique for BUG-3 or BUG-4 with these wrong references, CRITIQUE will review the wrong plan and either waste a session or, worse, approve the wrong fix.

**BUG-2 regressed to "backlog."** It was IN REVIEW on the KANBAN (VERIFY passed), but the scheduler shows stage "backlog" with pid=0. The KANBAN says IN REVIEW. The scheduler says backlog. Which is it? If VERIFY passed (and it did, with a clean PASS verdict), BUG-2 should be DONE. Someone needs to reconcile this.

---

### 2. QUALITY: 7/10

**Good:**
- VERIFY (BUG-2): Thorough, well-structured verdict. 4 regression tests validated, each mapped to specific bug scenarios. Coverage assessment is real, not hand-wavy. This is how VERIFY should work.
- PLAN (BUG-6, BUG-7): Both completed with detailed root cause analysis and scoped fixes. BUG-6 identifies FeeRouter being called by Liquidation/Settlement without USDT transfer. BUG-7 traces zero liquidations to unset depthThreshold. Good work.
- CRITIQUE (BUG-1, 3rd review): Caught the LEVER-P06 ordering constraint that makes Phase 2 without Phase 3 unsafe. This is a genuinely important catch. The vault NAV drift from mismatched realized/unrealized PnL formulas would have been subtle and damaging.

**Concern:**
- PLAN is still deferring contract interface questions to BUILD. The BUG-3 open question about PositionManager (from last report) was not resolved. Now BUG-7 plan is 18KB. Are these plans getting bloated? A good plan for a depthThreshold setter should not need 18KB. Plans should be tight: root cause, fix, test strategy. Not dissertations.

**Concern:**
- IMPROVE proposals are accumulating with no action. 3 proposals (header stats bug, price confusion, vault APY) are OPEN with no scheduled work. The header stats bug (Proposal #1) is labeled "Ship now" priority. It is a first-impression-killer for investor demos. Nobody has picked it up.

---

### 3. BOTTLENECKS: BUG-1 is STILL stuck (4+ hours)

**BUG-1 has been in critique for 4 hours.** The scheduler shows stage "critiquing" with pid 2865523. The latest critique file (15:47) says REVISE with 3 blockers. The scheduler dispatched a new critique session at 16:06. This is the THIRD critique cycle for BUG-1. It keeps bouncing between PLAN and CRITIQUE because:

1. The plan's exit formula diverges from LESSONS.md (double vs single impact). Master must decide.
2. LEVER-P06 makes shipping Phase 2 without Phase 3 unsafe (vault NAV drift).
3. All line numbers in the plan are stale.

**This will keep looping forever without Master input.** Issue #1 is a design decision, not a code question. CRITIQUE correctly identifies it. PLAN cannot resolve it. The system has no mechanism to escalate "needs Master decision" items. BUG-1 should be BLOCKED in the scheduler (not burning sessions on re-critiques) with a clear question for Master.

**Previous report's Action Items #1-5: Status**
1. Fix scheduler-state.json plan_file references: NOT DONE.
2. Dispatch CRITIQUE for BUG-3 and BUG-4: NOT DONE. Still sitting at planned.
3. Dispatch PLAN revision for BUG-1: Partially done (critique re-dispatched, but the fundamental issue remains).
4. Add CRITIQUE->PLAN revision loop: NOT DONE.
5. PLAN should verify contract interfaces: NOT DONE.

Zero of five action items completed in 2 hours. The system does not act on its own oversight reports. This is a meta-problem.

---

### 4. RECURRING PROBLEMS: Scheduler data integrity

**Same bug, same report, twice now.** The wrong plan_file references for BUG-3 and BUG-4 were flagged at 14:01. It is 16:01. Still broken. The scheduler wrote these values incorrectly when the tasks were initially registered, and no process exists to validate or correct them. If this is a code bug in the scheduler, it needs a code fix. If it is a one-time data corruption, someone needs to manually edit the JSON.

**BUG-1 critique loop** is also recurring. This is the 3rd critique cycle. The system is burning Opus sessions re-critiquing a plan that needs a human decision, not another AI review.

---

### 5. SYSTEM HEALTH: Stable but with cron issues

- 16:00 health check: healthy, 0 problems. Good.
- 12:00 health check had a gateway failure, could not restart (bus connection error). Resolved itself by 16:00. The health-escalate.sh fix from earlier (using sudo for systemctl) was committed (9995fab).
- Scheduler running at capacity (5/5 slots). Load is fine. RAM is fine.
- Cron jobs for operate-selfcheck and overseer previously timed out (noted in RECENT_SESSIONS). Overseer timeout was 1800s. These are long-running analysis tasks; timeouts may need increasing or the tasks need to be more focused.

---

### 6. WASTED WORK: YES

**Support tasks are displacing critical bug work.** At 16:05-16:14, the scheduler dispatched: support-operate (#28), critique for BUG-1 (#29, 3rd cycle), support-research (#30), plan for BUG-8 (#31), support-improve (#32). That is 3 support tasks and 1 redundant critique, consuming 4 of 5 slots. Meanwhile:

- BUG-3 (CRITICAL, Ghost OI): planned, idle for 2.5 hours
- BUG-4 (CRITICAL, InsuranceFund bad debt): planned, idle for 2.5 hours
- BUG-5 (CRITICAL, decimal mismatch): planned, idle for 1 hour
- BUG-6 (CRITICAL, FeeRouter without USDT): planned, idle since completion
- BUG-7 (CRITICAL, zero liquidations): planned, just completed

**Support tasks should run only when pipeline slots are actually free.** The scheduler is treating support-operate, support-research, and support-improve as equal priority to pipeline work. They are not. A system health check (when health was just confirmed clear at 16:00) is not more important than advancing a CRITICAL bug fix through critique.

**BUG-8 is being planned while BUG-3 through BUG-7 have not even entered critique.** This is FIFO violation. The scheduler is planning new work instead of advancing existing work through the pipeline. Plans without critique are inventory, not progress.

---

### ACTIONS REQUIRED (ordered by priority)

| # | Action | Who | Priority | Status |
|---|--------|-----|----------|--------|
| 1 | Fix scheduler-state.json: BUG-3 plan_file -> plan-lever-bug-3.md, BUG-4 plan_file -> plan-lever-bug-4.md | OPERATE | CRITICAL | OVERDUE (flagged 2h ago) |
| 2 | Mark BUG-2 as DONE in scheduler (VERIFY passed, KANBAN says IN REVIEW, scheduler says backlog) | OPERATE | HIGH | NEW |
| 3 | Mark BUG-1 as BLOCKED in scheduler with reason "needs Master decision on exit formula" | OPERATE | HIGH | NEW |
| 4 | Dispatch CRITIQUE for BUG-3 and BUG-4 immediately (2.5 hours idle with approved plans) | Scheduler | HIGH | OVERDUE |
| 5 | Prioritize pipeline tasks over support tasks in scheduler (support should only fill idle slots) | Scheduler code fix | HIGH | NEW |
| 6 | Stop re-critiquing BUG-1 until the plan is actually revised with the CRITIQUE feedback | Scheduler | MEDIUM | NEW |
| 7 | Pick up IMPROVE Proposal #1 (empty header stats, investor demo killer) | BUILD/PLAN | MEDIUM | NEW |

---

### VERDICT

The pipeline is producing good plans and good critiques, but nothing is flowing through to BUILD. We have 6 CRITICAL planned bugs gathering dust while the scheduler burns slots on support tasks and redundant BUG-1 re-critiques. The system is diagnosing well and executing poorly. The scheduler needs a priority model: pipeline advancement first, support tasks second, and a hard stop on re-critiquing tasks that need human input. If this does not change, we will end the day with 8 great plans and zero bugs actually fixed (beyond the P01-P06 batch from this morning).

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
