# DECISIONS LOG
## Format: [DATE] [PROJECT] [WORKSTREAM] [DECISION]: [RATIONALE]

---

[2026-03-28] [Vigil] [MIGRATION] Use Caddy instead of Nginx for dashboard: Caddy is already installed and running on the server. Adding a route is simpler than installing Nginx and managing port conflicts.

[2026-03-28] [Vigil] [MIGRATION] Commander replaces lever-bot (same Telegram token, new code): Avoids 409 polling conflicts and consolidates Telegram access into one process.

[2026-03-28] [Vigil] [MIGRATION] New dashboard replaces existing lever-dashboard on port 8080: Consolidates monitoring into one view with more data.

[2026-03-20] [LEVER Protocol] [BUILD] Redeployed LeverVault, ExecutionEngine, SettlementEngine, LiquidationEngine: Fixed vault-to-RewardsDistributor mismatch and LiquidationEngine constructor arg scramble.
