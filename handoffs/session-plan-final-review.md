# Session Plan: Final System Review and Fixes
## Date: 2026-03-28
## Context: Master is frustrated because the system is not thinking deeply enough

---

## What is Actually Wrong Right Now (honest assessment)

### 1. The Dashboard Does Not Work As a Mission Control
- It shows static data refreshed every 60 seconds
- The WebSocket server was written but the data it pushes comes from shell commands that are slow and often wrong
- No KANBAN is visible
- No pipeline visualization shows real task flow
- It is not mobile-first despite Master checking on his phone
- The data generator has bugs (nextJobs shows agent names not times, health was wrong)
- **Root cause**: I rushed through 3 dashboard versions in this session. Each was incrementally better but none was properly planned or tested.

### 2. VERIFY Does Not Use Browser Testing
- VERIFY's CLAUDE.md says "use Chromium browser" but no verification session has actually launched Puppeteer
- Screenshots are not being taken
- Claude vision is not being used to evaluate visual output
- **Root cause**: Writing instructions in CLAUDE.md does not make it happen. The agent needs explicit tooling setup (Puppeteer path, screenshot commands, vision API access).

### 3. The Scheduler Has Bugs
- It dispatched 2 PLANs simultaneously (fixed but not tested)
- Process counting was inaccurate
- Task ID to handoff file matching is brittle (filename prefix matching)
- No integration test of the full PLAN -> CRITIQUE -> BUILD -> VERIFY flow
- **Root cause**: I wrote the scheduler in one shot without testing each component.

### 4. The System Does Not Self-Improve
- The Overseer is an ADVISOR cron that has never run
- OPERATE's self-check cron was in error state
- When things break, nobody fixes them automatically
- **Root cause**: Self-improvement requires more than instructions. It requires actual tooling (log monitoring, error detection, auto-remediation scripts).

### 5. Sessions Are Being Wasted
- The bash dispatcher fired duplicate sessions
- Support tasks (IMPROVE, RESEARCH) ran instead of critical pipeline tasks
- No prioritization of what matters
- **Root cause**: The dispatcher was dumb. The scheduler v2 is better but untested.

---

## What Should I Actually Do (in order)

### Step 1: Stop and Verify What Works
Before building anything new, test what exists:
- Send a message to Timmy on Telegram. Does he respond?
- Check if the scheduler is dispatching correctly (no duplicates)
- Check if handoff files are being created by PLAN sessions
- Check the dashboard at :8080. What renders? What is broken?

### Step 2: Fix the Dashboard Data (not the design)
The design can wait. The DATA must be correct first:
- Fix the data generator to output correct nextJobs times
- Make sure KANBAN data flows through to the frontend
- Make sure the WebSocket actually pushes updates
- Test on mobile

### Step 3: Fix VERIFY to Actually Use Browser Testing
This requires:
- Confirming Puppeteer/Chromium works on this server
- Adding explicit screenshot commands to VERIFY's CLAUDE.md
- Testing it manually

### Step 4: Run the Full Pipeline Once End-to-End
Take one KANBAN backlog item. Manually trigger:
1. PLAN produces a plan file
2. CRITIQUE reviews it, produces verdict
3. BUILD implements based on the approved plan
4. VERIFY reviews with browser screenshots
Observe each step. Fix what breaks.

### Step 5: THEN Improve the Dashboard
Only after the pipeline is proven, improve the dashboard to visualize it.

---

## Self-Critique of This Plan

**What is wrong with this plan?**

1. It is reactive. I am fixing things Master pointed out instead of thinking about what ELSE is wrong.
2. Steps 1-4 are sequential but could be partially parallelized.
3. I have been in this session for hours. Context is getting long. Some of these fixes should be handed off to a fresh session that can focus.

**What should I actually recommend to Master?**

Honestly: we should save the current state, write a comprehensive handoff doc, and start a fresh session for the remaining work. This session has been running too long, the context is enormous, and I am making sloppier decisions as it goes on. A fresh session with a clear HANDOFF.md would be more effective than continuing to patch things here.

---

## My Recommendation

Save everything. Update HANDOFF.md with the complete current state and remaining work. Push to git. Let the scheduler and overseer run overnight. Start fresh tomorrow to:
1. Fix the dashboard properly (plan it, review it, build it, test it)
2. Fix VERIFY browser testing
3. Run the full pipeline end-to-end test
4. Harden the scheduler

The system is running. 10 services are up. The scheduler is dispatching. The Telegram gateway handles files. The knowledge graph has real data. It is not perfect but it is functional. The remaining work needs focused attention, not rushed patches.
