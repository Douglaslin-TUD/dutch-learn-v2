# Agent Team Design — Universal Programming Team Template

**Date:** 2026-02-10
**Status:** Approved

## Goal

Build a reusable agent team template for software development, covering the full
lifecycle: research → design → implement → test → review → document.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Team size | 7 agents + Lead | Complete coverage of all development phases |
| Collaboration mode | Semi-autonomous | Lead defines tasks/deps, agents self-organize |
| Plan approval | Architect only | Design is the critical decision point |
| User confirmation | Design phase only | Post-design phases are fully automated |
| Model strategy | 5 Opus + 2 Sonnet | Maximize quality; Sonnet for Explorer and Doc Writer |
| Quality gates | TaskCompleted + TeammateIdle hooks | Automated test verification before task completion |
| Feedback loops | Max 3 iterations | Prevent infinite review-fix cycles |

## Team Composition

| # | Role | Agent File | Model | Tools | Permission Mode |
|---|------|-----------|-------|-------|-----------------|
| 0 | Lead | (main session) | Opus | All | default |
| 1 | Explorer | `explorer.md` | Sonnet | Read, Grep, Glob, Bash, LSP | default (read-only by tool restriction) |
| 2 | Architect | `architect.md` | Opus | Read, Grep, Glob, Bash, LSP | plan (requires Lead approval) |
| 3 | Implementer | `implementer.md` | Opus | Read, Write, Edit, Bash, Glob, Grep | acceptEdits |
| 4 | Tester | `tester.md` | Opus | Read, Write, Edit, Bash, Glob, Grep | default |
| 5 | Reviewer | `reviewer.md` | Opus | Read, Grep, Glob, Bash | default (read-only) |
| 6 | Security Auditor | `security-auditor.md` | Opus | Read, Grep, Glob, Bash | default (read-only) |
| 7 | Doc Writer | `doc-writer.md` | Sonnet | Read, Write, Edit, Glob, Grep | default |

### Role Responsibilities

- **Lead**: Creates team, defines tasks, sets dependencies, approves Architect's design, synthesizes results, shuts down team
- **Explorer**: Searches codebase, traces code paths, collects context for other agents
- **Architect**: Analyzes architecture, produces design specs with trade-off analysis, requires Lead approval
- **Implementer**: Writes code following approved designs, self-verifies with tests (max 3 iterations)
- **Tester**: Writes test cases, runs test suites, reports coverage gaps
- **Reviewer**: Reviews code quality, reports findings by severity (Critical/Warning/Suggestion)
- **Security Auditor**: Audits for vulnerabilities (OWASP Top 10), reports by severity with fixes
- **Doc Writer**: Updates documentation, API docs, changelog, inline comments

## Workflow: Wave Execution Pattern

```
Wave 1 — Research (parallel, 2 tasks)
  ├─ Explorer: Search codebase, collect relevant files and patterns
  └─ Explorer: Analyze existing architecture and conventions

Wave 2 — Design (sequential, requires approval)
  └─ Architect: Produce architecture design (blockedBy: Wave 1)
     ⏸️ Lead approves design → User confirms

Wave 3 — Implement + Test (parallel, 2 tasks)
  ├─ Implementer: Write code + self-verify (blockedBy: Wave 2)
  └─ Tester: Write test cases (blockedBy: Wave 2)

Wave 4 — Verify + Review (parallel, 3 tasks)
  ├─ Tester: Run full test suite (blockedBy: Wave 3)
  ├─ Reviewer: Code quality review (blockedBy: Wave 3)
  └─ Security Auditor: Security scan (blockedBy: Wave 3)

Wave 5 — Fix (sequential, iteration-capped)
  └─ Implementer: Fix review/security issues (blockedBy: Wave 4, max 3 rounds)

Wave 6 — Document (sequential)
  └─ Doc Writer: Generate/update documentation (blockedBy: Wave 5)
```

### Task Dependency Graph

```
T1 (Explorer: search)  ──┐
T2 (Explorer: analyze) ──┤
                          ├──→ T3 (Architect: design) ──┬──→ T4 (Implementer: code)  ──┐
                                                        └──→ T5 (Tester: write tests) ──┤
                                                                                        ├──→ T6 (Tester: run tests)     ──┐
                                                                                        ├──→ T7 (Reviewer: review)       ──┤
                                                                                        └──→ T8 (Security: audit)        ──┤
                                                                                                                          ├──→ T9 (Implementer: fix)  ──→ T10 (Doc Writer: docs)
```

## Quality Gates

### TaskCompleted Hook (`quality-gate.sh`)

Triggers when any agent marks a task as completed:
1. Detects which codebase area changed (desktop/mobile) via `git diff`
2. Runs the corresponding test suite (pytest / flutter test)
3. If tests fail → exit code 2 → blocks completion, feeds error back to agent
4. If tests pass → exit code 0 → allows completion

### TeammateIdle Hook (`check-idle.sh`)

Triggers when any teammate is about to go idle:
1. Checks if the teammate has in-progress tasks → blocks idle, tells them to finish
2. Checks if there are unclaimed pending tasks → blocks idle, tells them to claim one
3. No remaining work → allows idle

### Self-Verification Loop (in Implementer prompt)

Built into the Implementer agent's system prompt:
- After writing code, runs tests automatically
- If tests fail, reads error output, diagnoses root cause, fixes
- Repeats up to 3 iterations
- If still failing after 3 rounds, reports FAILURE with details

## Team Lifecycle

### Phase 1: Setup
```
TeamCreate("dev-team")
TaskCreate x 10 (all tasks from the wave plan)
TaskUpdate (set blockedBy dependencies)
Task (spawn Explorer, Architect, Implementer, Tester, Reviewer, Security Auditor, Doc Writer)
```

### Phase 2: Execution
Each teammate independently:
```
TaskList() → find available work
TaskUpdate(claim: in_progress, owner: self)
[Do the work]
TaskUpdate(complete)
SendMessage(report to Lead)
Loop back to TaskList()
```

### Phase 3: Teardown
```
SendMessage(shutdown_request) to each teammate
[Wait for shutdown_response approvals]
TeamDelete()
```

## Example Usage Prompt

To start the team for a feature:

```
Create an agent team called "feature-auth" to implement user authentication.

Spawn these teammates:
- explorer (sonnet): research the current auth patterns
- architect (opus): design the auth system
- implementer (opus): implement the code
- tester (opus): write and run tests
- reviewer (opus): review the implementation
- security-auditor (opus): audit for security issues
- doc-writer (sonnet): update documentation

Tasks:
1. Explorer: Search codebase for existing auth-related code
2. Explorer: Analyze current session/token handling
3. Architect: Design JWT-based auth system (blocked by 1, 2)
4. Implementer: Implement auth endpoints (blocked by 3)
5. Tester: Write auth test cases (blocked by 3)
6. Tester: Run full test suite (blocked by 4, 5)
7. Reviewer: Review auth implementation (blocked by 4, 5)
8. Security Auditor: Audit auth code (blocked by 4, 5)
9. Implementer: Fix review findings (blocked by 6, 7, 8)
10. Doc Writer: Update API docs (blocked by 9)
```

## File Structure

```
.claude/
├── agents/
│   ├── explorer.md          # Codebase researcher (Sonnet)
│   ├── architect.md         # System architect (Opus, plan mode)
│   ├── implementer.md       # Developer (Opus, acceptEdits)
│   ├── tester.md            # Test specialist (Opus)
│   ├── reviewer.md          # Code reviewer (Opus, memory)
│   ├── security-auditor.md  # Security auditor (Opus, memory)
│   └── doc-writer.md        # Documentation writer (Sonnet)
├── hooks/
│   ├── quality-gate.sh      # TaskCompleted: test before complete
│   └── check-idle.sh        # TeammateIdle: no premature idle
└── settings.json            # Hook configuration
```

## Cost Considerations

- 5 Opus + 2 Sonnet agents = approximately 6-7x single-session token cost
- Mitigated by: wave execution (agents only active when unblocked), max 3 fix iterations, idle hook prevents waste
- For simple tasks (single-file fix, minor change), use single session or subagent instead
- Reserve team mode for: multi-file features, cross-layer changes, complex debugging

## Known Limitations

- One team per session (clean up before starting a new team)
- No session resumption for teammates (`/resume` doesn't restore them)
- No nested teams (teammates cannot spawn their own teams)
- Split pane mode requires tmux or iTerm2 (not VS Code terminal)
- File conflicts possible if two agents edit the same file (mitigated by Architect assigning file ownership)

## Research Sources

- [Anthropic: Building a C Compiler with Agent Teams](https://www.anthropic.com/engineering/building-c-compiler)
- [Official Docs: Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Official Docs: Custom Subagents](https://code.claude.com/docs/en/sub-agents)
- [Addy Osmani: Claude Code Swarms](https://addyosmani.com/blog/claude-code-agent-teams/)
- [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [wshobson/agents](https://github.com/wshobson/agents)
- [Kieran Klaassen: Swarm Orchestration Skill](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
- [alexop.dev: TDD Workflow](https://alexop.dev/posts/custom-tdd-workflow-claude-code-vue/)
- [HAMY: 9 Parallel AI Agents for Code Review](https://hamy.xyz/blog/2026-02_code-reviews-claude-subagents)
- [DeepMind: Scaling Agent Systems (17x Error Trap)](https://towardsdatascience.com/why-your-multi-agent-system-is-failing-escaping-the-17x-error-trap-of-the-bag-of-agents/)
