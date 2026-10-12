# mdci.setup.feature-monit

Installs and starts monit, and deploys the monit rules and scripts that other packages ship.

Maintainer notes: `MAGIC.md`.

## Requires

- Nothing in `Requires:`.
- `myx.common` on the host (`myx.common install/monit` does the base install).
- `monit` and `rsync` from `OS_PACKAGES`, installed by `setup.feature-myx.common`.
- FreeBSD paths (`/usr/local/etc`, `root:wheel`).

## What it installs and configures

- Package `monit` (added to `OS_PACKAGES`).
- `myx.common install/monit` — enables the daemon and writes `/usr/local/etc/monitrc`, which includes `/usr/local/etc/monitrc-*.conf`.
- `/usr/local/etc/.mdci-monit-env` — the Slack settings that alert scripts read (mode 444).
- Every `data/monit/monitrc-*.conf` to `/usr/local/etc/` (mode 400).
- `data/monit/scripts/` to `/usr/local/etc/mdci-monit-scripts/` (mode 500, with `--delete`).
- `data/newsyslog.conf.d/monit.conf` — rotation of `/var/log/monit.log`, deployed by the FreeBSD floor's `newsyslog.conf.d` contract.
- After all other steps: `service monit restart`.

A package that requires this one adds rules by shipping `data/monit/monitrc-<name>.conf`, and scripts in `data/monit/scripts/`.

## Inputs

All optional. They are written to `/usr/local/etc/.mdci-monit-env`.

| variable | default |
|---|---|
| `SLACK_TOKEN` | empty |
| `SLACK_TOKEN_AGIT` | empty |
| `SLACK_TOPIC` | `cloud-infra` |
| `SLACK_ALERT` | `event-alert` |
| `SLACK_AUDIT` | `event-audit` |
| `SLACK_TRACK` | `event-track` |
| `SLACK_DEBUG` | `event-debug` |

## Commands

- `/usr/local/etc/mdci-monit-scripts/monit-wrapper.sh <cmd> …` — runs a command, sends its output to syslog tagged with the command name, and returns the command's exit status.
