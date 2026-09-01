# Security Policy

## Supported Versions

The latest release (currently [v2.6.1](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.6.1)) receives security fixes. Older versions are not actively maintained.

## Reporting a Vulnerability

**Do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to the maintainers:

- Create a private contact through GitHub: open an issue with title `[SECURITY]` and mark it as **confidential**, or
- Contact the repository owner directly through the GitHub profile's listed contact method.

Please include:

1. **Description** of the vulnerability and its potential impact
2. **Steps to reproduce** or proof-of-concept (if applicable)
3. **Affected versions** (which releases are impacted)
4. **Suggested fix** (if you have one)

## What to Expect

- **Acknowledgment**: We aim to acknowledge receipt within **72 hours**.
- **Assessment**: We will investigate and respond with an initial assessment within **7 days**.
- **Resolution**: Valid vulnerabilities will be fixed in the next patch release. You will be credited in the release notes unless you prefer anonymity.
- **Disclosure**: We follow coordinated disclosure — please allow us time to patch before public disclosure.

## Scope

### In Scope
- **Authentication/authorization bypass** in hooks (fail-gate-hook, integrity-guard) or state-machine guards
- **Injection vulnerabilities** (SQL/command/code injection) in precheck gates or generate-skill pipeline
- **Supply-chain attacks** via malicious skill definitions or UNIVERSAL_FILES tampering
- **Sensitive data exposure** (secrets, credentials) through generated artifacts or logs
- **Path traversal / arbitrary file write** beyond declared boundaries

### Out of Scope
- **Design decisions** (e.g., enforcement level choices, gate selection) — these are documented in README §6.3 (paradigm-decisions)
- **Performance issues** without security impact
- **Non-security bugs** (use regular issue tracker)
- **Vulnerabilities in third-party runtimes** (report them to the respective upstream projects)

## Security-Related Design

swarm-yuan's security posture is enforced through:

- **fail-closed defaults**: Permission boundaries fail-closed; fail-open only with lower-layer enforcement
- **spec-first enforcement**: `fail-gate-hook` intercepts source writes without approved spec (Claude deny / Codex exit 2)
- **sandbox wildcards**: `.env` and secret-file deny patterns prevent renames that bypass detection
- **gate-deny logging**: All hook denials are logged to `gate-deny.jsonl` for audit
- **spec §19-21 left-shift**: Security constraints embedded in spec/plan stages (not just post-hoc review)

See [README.md §4.2 约束实现](swarm-yuan/README.md) for enforcement details.
