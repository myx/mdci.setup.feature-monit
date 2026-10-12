# MAGIC.md — setup.feature-monit

Maintainer notes for the shared monit project. Every package here that monitors anything requires it (`setup.feature-mdci`, `setup.machine-l6route-minimal`), so a behaviour change here reaches all of them. Users read `README.md`.

## The monit cycle is 15 seconds, and nothing here overrides it

- `/usr/local/etc/monitrc` is written by `myx.common install/monit` — `os-myx.common/host/tarball/share/myx.common/bin/install/monit.FreeBSD:15-22` — as a heredoc carrying `set daemon 15`, `with start delay 60`, a logfile line, and `include /usr/local/etc/monitrc-*.conf`. That include is the only route by which any `monitrc-*.conf` is read.
- No file in this repo sets `set daemon`. So a cycle is 15 seconds, and any rule phrased in cycles is read in 15-second units.
- `with start delay 60`: monit checks nothing for the first 60 seconds after it starts. A status read taken right after a deploy can find a service monit has not looked at yet.

## `repeat every <n> cycles` semantics are unestablished

- Not settled. Two readings are possible for a level condition — that it fires once on transition, or once per cycle while it holds — and the rule files here do not decide between them.
- Anything written here that depends on which reading is correct must say so. It has not been measured against a running monit.

## `chown`/`chmod` on the `monitrc*` glob is not an abort site

`common-monit.install.txt:25-26` runs `chown root:wheel /usr/local/etc/monitrc*` and `chmod 400` on the same glob. A glob that matches nothing makes both fail. It is safe, and the reason is upstream.

- `myx.common install/monit` is line 4 of the same fragment. Its FreeBSD implementation — `os-myx.common/host/tarball/share/myx.common/bin/install/monit.FreeBSD` — **unconditionally writes `/usr/local/etc/monitrc` and `touch`es `/usr/local/etc/monitrc-custom.conf`**, at its own lines 15 and 26, under its own `set -e`. The only `||` in it is the two `type … ||` loader guards above line 13.
- So by the time line 25 runs, either that call succeeded and the glob matches at least two files, or it failed and the fragment already stopped under the generator's `( set -e ; eval … )` wrapper. **There is no path on which line 25 runs against an empty glob.** The `find … | xargs cp` at line 24 is not what makes it safe.
- No change is needed. The disproof lives in a different repository, which is why it is written here.

## `monit` and `rsync` come from `OS_PACKAGES`

- This project inserts `monit` into `OS_PACKAGES` and uses `rsync` at `common-monit.install.txt:30`. It installs neither itself.
- `setup.feature-myx.common`'s `install-myx.common.sh` installs `myx.common` and then runs `myx.common lib/installEnsurePackage` over `OS_PACKAGES`. The fragment works only where that has run first; `Requires:` here is empty.

## `monit-wrapper.sh` returns the wrapped command's status

- It ends `exit "$( { { "$@" 2>&1 ; printf '%s\n' "$?" >&3 ; } | logger -t "$SCRIPT" >&2 ; } 3>&1 )"`. The command's exit status is written to fd 3, which the outer brace group's `3>&1` points at the command substitution's capture. `logger`'s own stdout goes to stderr so it cannot enter that capture.
- Three edits look like tidying and are not: flattening the two brace groups removes the scope the `3>&1` applies to, so nothing is captured; moving or removing the `3>&1` points fd 3 elsewhere; dropping `>&2` from `logger` lets logger's output into the capture. The plain form `"$@" | logger` then `exit $?` returns logger's status, which is almost always 0.
- `PIPESTATUS` and `pipefail` are not available: the file is `#!/bin/sh`.
- **Check it by property, not by text.** Run three subjects exiting 0, 1 and 75 through the file under `/bin/sh` and `dash`, and require 0, 1, 75.
- Two behaviours left as they are: with no arguments the tag is empty (`logger -t ""`), and `$1` serves as both the tag and the command.
- A pipeline completes on EOF, not on process exit. A wrapped command that leaves a background child holding the pipe hangs the wrapper for that child's lifetime.
- No `monitrc-*.conf` in this repo calls `monit-wrapper.sh`. The two here — `monitrc-l6route.conf` and `monitrc-mdci.conf` — call `slackServiceAlert.sh`, `service ... restart`, `/sbin/reboot` and one inline `/bin/sh -c`.

## The scripts directory is owned by this sync

- `common-monit.install.txt:29-32` syncs `data/monit/scripts/` into `/usr/local/etc/mdci-monit-scripts/` with `--delete`. A script placed there by hand is removed on the next deploy.
- `data/monit` is collected with `*`, so the directory holds the scripts of this project and of every dependent project that ships `data/monit/scripts/`.
- `setup.feature-mdci` and `setup.machine-l6route-minimal` each ship a different `data/monit/scripts/slackServiceAlert.sh`. Both land on the same path.
