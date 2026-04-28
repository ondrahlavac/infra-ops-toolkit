# Security Policy

## Scope

This repository contains infrastructure and administrative shell tooling,
primarily for Linux and Proxmox environments.

Because some scripts may be executed with elevated privileges, security issues
are taken seriously.

Examples of security-relevant issues include:

- Privilege escalation paths
- Command injection
- Unsafe handling of user input
- Credential exposure
- Insecure defaults
- Destructive logic errors with security impact
- Supply chain concerns in dependencies or install patterns

General bugs, usability issues, and feature requests should be reported through
GitHub Issues.


## Supported Versions

Security fixes are provided only for the current main branch.

| Version / Branch | Supported |
|------------------|-----------|
| main             | ✅ Yes    |
| Older commits     | ❌ No     |
| Forks             | ❌ No     |

As this project is currently distributed as scripts rather than versioned
releases, users should track the latest stable code on `main`.


## Reporting a Vulnerability

Please do **not** open public GitHub issues for suspected security vulnerabilities.

Instead, report privately via:

- Email: ondra@hlavac.cz

Please include:

- Description of the issue
- Affected script(s)
- Reproduction steps or proof of concept
- Impact assessment, if known
- Suggested remediation (optional)


## Response Expectations

Target response times:

- Initial acknowledgement: within 7 days
- Triage/update: within 14 days
- Fix or mitigation target: depends on severity

Valid reports will be investigated and, when confirmed, remediated as practical.

Responsible disclosure is appreciated.


## Security Philosophy

This repository aims to follow several operating principles:

- Safe defaults
- Minimal external dependencies
- Auditability over cleverness
- Idempotent behavior where practical
- Explicit parameters over hidden assumptions
- Human review before execution

Users are encouraged to inspect scripts before running them,
especially when executing with root privileges.

Do not pipe unreviewed scripts directly into a privileged shell.

I.e. preferably use:

```bash
curl -fsSLO <script-url>
less script.sh
chmod +x script.sh
./script.sh
```

instead of:

```bash
curl ... | bash
```


## Hardening Contributions Welcome

Security reviews, hardening suggestions, and responsible disclosures are welcome.
