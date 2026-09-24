# MAGIC.md — setup.feature-monit

Team-owned notes for the magic-* team on the shared monit project. It is required by every host in this namespace that monitors anything, so a behaviour change here reaches all of them and is not a rig author's to make.

**Recovery note.** This file was written earlier in the 2026-09-21 session with the cycle facts and the wrapper defect below, and was found empty when the next entry was appended. The entries have been re-established from source rather than restored from memory, and each says what was checked. If a fuller version exists elsewhere, prefer it.

## The monit cycle is 15 seconds, and nothing in this namespace overrides it

- `/usr/local/etc/monitrc` is written by `myx.common install/monit` — `os-myx.common/host/tarball/share/myx.common/bin/install/monit.FreeBSD:15-22` — as a heredoc carrying `set daemon 15`, `with start delay 60`, a logfile line, and `include /usr/local/etc/monitrc-*.conf`. That include is the only route by which any `monitrc-*.conf` in this namespace is read.
- Searched for an override across every `.conf`, install fragment and `monitrc*` in source: **none**. So a cycle is 15 seconds everywhere, and any rule phrased in cycles has to be read in 15-second units.
- `with start delay 60` has a deploy-time consequence worth knowing before reading a fresh box: monit does not begin checking for the first 60 seconds after it starts. A status read taken immediately after a deploy can find a service monit has not looked at yet.

## `repeat every <n> cycles` semantics are unestablished

- Recorded as not settled rather than guessed. Two readings are possible for a level condition — that it fires once on transition, or once per cycle while it holds — and the estate's evidence does not decide between them: 15 explicit `repeat every` lines exist, which is evidence against a default of every-cycle repetition, and none of the pullers carries one.
- Anything written here that depends on which reading is correct must say so. It has not been measured against a running monit.

## The wrapper discards the wrapped command's status

- `data/monit/scripts/monit-wrapper.sh` ends with `"$@" 2>&1 | logger -t "$SCRIPT"` followed by `exit $?`. A pipeline's status is its last element's, so `$?` is **logger's** status, not the wrapped command's. A wrapped command that fails exits 0 through this wrapper.
- POSIX `sh` has no `pipefail`, so the fix is not a one-word option; it needs the status captured, or the pipe replaced. Not changed here: this file is shared, the change is behavioural, and it was ruled to belong outside a rig build. Recorded so that a caller does not read a 0 from this wrapper as the wrapped command having succeeded.

## `chown`/`chmod` on the `monitrc*` glob is not an abort site

Raised as a real abort site once the generated installer began stopping on a failing fragment: `common-monit.install.txt:25-26` runs `chown root:wheel /usr/local/etc/monitrc*` and `chmod 400` on the same glob, and a glob that matches nothing makes both fail. Established as safe, and the reason is upstream rather than here.

- `myx.common install/monit` is line 4 of the same fragment, and its FreeBSD implementation — `os-myx.common/host/tarball/share/myx.common/bin/install/monit.FreeBSD` — **unconditionally writes `/usr/local/etc/monitrc` and `touch`es `/usr/local/etc/monitrc-custom.conf`**, at its own lines 15 and 26. It runs under its own `set -e`.
- So by the time line 25 runs, either that call succeeded and the glob matches at least two files, or it failed and the fragment already aborted. **There is no path on which line 25 runs against an empty glob.** The `find … | xargs cp` at line 24 is not what makes it safe and does not need to match anything.
- It was previously described as masked by the `myx.common` failure earlier in the same fragment. It was not masked; it was never exposed.
- No change made, and none is needed. This is recorded because the next reader will re-derive the same alarm from the glob alone, and the disproof lives in a different repository.
- **Re-verified against the generated artefact rather than carried from the source read**, because what makes it matter is the fragment's behaviour under the generator's `set -e` and that is a property of the generated file. In the real full-path installer this fragment is wrapped `( set -e ; eval …)` with `mdscFragmentRc=$?` captured and tested after it; `myx.common install/monit` is at relative line 8 and the two globs at 29 and 30. So a failure at line 8 aborts the subshell twenty-one lines before the globs are read, and the deploy then stops. Confirmed in the same pass that `monit.FreeBSD` has no conditional around its `monitrc` write or its `monitrc-custom.conf` touch — the only `||` in it is the two `type … ||` loader guards above line 13.

## Everything this fragment needs is installed at position 1

- The generated installer exports `OS_PACKAGES` at top level before any fragment, and the upstream `install-myx.common.sh` ends by running `myx.common lib/installEnsurePackage` over it. The FreeBSD floor's `0.prepare` pipes that installer into `sh -e` at position 1 with the environment inherited, so the declared packages are present from the start.
- For this fragment that covers `monit` itself and the `rsync` at line 30. Both used to depend on a package installed at position 14, behind this fragment at 13.
- The ordering defect this project was the visible half of — `myx.common install/monit` running before anything installed `myx.common` — is closed by the same bootstrap. Nothing changed in this project to close it.

## `monit-wrapper.sh` returns the wrapped command's status — fixed 2026-09-21

Fixed on the human-owner's explicit ruling, because it is a behaviour change on operating hosts. The fix is `magic-developer`'s, and the explanation below is its wording rather than a paraphrase of it:

> `monit-wrapper.sh` ends `exit "$( { { "$@" 2>&1 ; printf '%s\n' "$?" >&3 ; } | logger -t "$SCRIPT" >&2 ; } 3>&1 )"`. The command's exit status is written to file descriptor 3, which the outer brace group's `3>&1` has pointed at the command substitution's capture; `logger`'s own stdout is sent to stderr so it cannot enter that capture. Three edits that look like tidying and are not: flattening the two brace groups removes the scope the `3>&1` applies to, so nothing is captured; moving or removing the `3>&1` points fd 3 elsewhere; dropping `>&2` from `logger` admits logger's output into the capture, making the exit status whatever logger last printed. The previous form, `"$@" 2>&1 | logger -t "$SCRIPT"` then `exit $?`, returned the *pipeline's* last stage — `logger`'s — which effectively always succeeds. Measured both ways: three subjects exiting 0, 1 and 75 returned 0, 0, 0 through the old form and 0, 1, 75 through this one. `PIPESTATUS` was not available as a simpler fix because this file is `#!/bin/sh`, and every `pipefail`/`PIPESTATUS` instance in the estate is a bash construct.

- **Verified by property rather than by text, and that is the check to repeat.** The line reached this file through two relays, so comparing characters is the weaker test: a character lost in transit either fails to parse or returns the wrong number, and both surface at once. Run the three subjects against the landed file and require 0, 1, 75. Measured on the landed file: `/bin/sh` gives 0/1/75, `dash` gives 0/1/75, the captured value is `75` alone, and both `dash -n` and `/bin/sh -n` are clean with no trailing whitespace on the line.
- Two pre-existing behaviours deliberately unchanged: with no arguments at all the tag is empty, `logger -t ""`; and `$1` serves as both the tag and the command.

### A hang that predates this change and is unaffected by it

- The wrapper runs caller-supplied commands through a pipeline, and a pipeline completes on EOF rather than on process exit. A command that leaves a background child holding the pipe hangs the wrapper for that child's lifetime.
- **Measured identically before and after**: a subject backgrounding a 3-second child took 3.4s through the old form and 3.0s through the new, against 0.0s called directly. Recorded separately and explicitly so a hang observed after deployment is not misattributed to the status fix.
- **No affected script is named here.** `carp-hetzner-deferred.sh` has unexamined failure semantics and its name suggests deferred work, which is the shape that backgrounds things — that is an inference from a filename and is not recorded as a finding. Someone who can see that file should read it for `&`, `nohup`, or a daemonising call.

### What the first monit cycle after deployment is expected to surface

State it both ways round, because written only the first way a silent cycle reads as success:

- **A flood of alerts on the first cycle is the fix working.** They are real pre-existing faults that have never been able to reach anyone. The first cycle is a survey, not an incident.
- **A silent first cycle is the thing to investigate.** It means either nothing routes through the wrapper, or the fix did not land.
- At least one new alert may come from a script that returns non-zero **routinely rather than exceptionally**, so the first noisy alarm is to be triaged rather than treated as proof the change was wrong.
- Monit's `with start delay 60` means it checks nothing for the first 60 seconds after starting, so neither outcome is readable immediately after a deploy.

### Scope of the flood, measured in this workspace — narrower than it was put

The consequence weighed before the ruling named `carp-hetzner-deferred.sh` among the alarms that would begin firing. **In this workspace that does not hold**, and the correction is recorded because the decision was taken with it in front of the decider:

- **No monit rule shipped from this workspace invokes `monit-wrapper.sh`.** Searched every file: the only references outside these `MAGIC.md` notes are none. The three `monitrc-*.conf` here — `monitrc-l6route.conf`, `monitrc-mdci.conf`, `monitrc-mbufs.conf` — reach `slackServiceAlert.sh`, `service ... restart`, `/sbin/reboot` and one inline `/bin/sh -c`, and no wrapper.
- **`carp-hetzner-deferred.sh` does not go through the wrapper.** Its rule is `monitrc-l6route.conf:54-57`, and line 57 is `exec "/bin/sh -c '…'"` directly. This change cannot alter its behaviour. (The rule is present here even though the script file is not, so a search for the filename in `data/monit/scripts/` finds nothing while the estate does reference it — that is what made it look absent.)
- So on `mel` hosts the wrapper is deployed into `/usr/local/etc/ndci-monit-scripts/` and called by nothing. The fix is correct and its blast radius here is zero. Rules in other namespaces are not deployed from this workspace and are not assessed here.
- The practical consequence for the expectation above: **on `mel` hosts a silent first cycle is the predicted outcome, not the alarming one.** A flood would mean a rule exists that this search did not find.

### "The wrapper is fixed" must not be read as "the puller flag bug is fixed"

The two are different claims about different hosts, and the second is not established. Raised by `magic-developer` before this item closed, and it is the part that changes what was decided rather than what was done.

- **What is fixed, and where.** This workspace's copy of `monit-wrapper.sh`. `common-monit.install.txt:29-32` is what populates `/usr/local/etc/ndci-monit-scripts/` on the hosts this workspace deploys, and it syncs with `--delete`, so on those hosts the directory is authoritative from here and the landed fix is the copy that runs. Those hosts are the ones reached by `setup.feature-mdci`, `setup.common-l6route`.
- **Where the consumed instances are.** `keeper-ndm` established that the wrapper is byte-identical across three trees, and that the eight live puller rules — the ones where the wrapper sits before an `&& touch <flag>`, so the status is actually consumed — are in the `ndm` and `ws-2017` trees, not this one. In this workspace nothing calls the wrapper at all.
- **The open question, and it is not this file's to answer.** Which source tree populates `/usr/local/etc/ndci-monit-scripts/` on the hosts running those pullers. If it is not this workspace, the live defect is still open on them and this change did not touch it. `keeper-ndm` owns that estate and is the one who can settle it. **Nothing here asserts an answer, and no session should read one into this entry.**
- **Why it matters beyond bookkeeping.** The ruling to fix now was taken against a stated consequence — alarms beginning to fire on running hosts — which belongs to whichever tree deploys that path. If that is a different tree than the one that got the fix, then the risk that was accepted and the change that was made are about different machines, and the decision deserves to be revisited rather than recorded as executed.

### How the `carp-hetzner-deferred.sh` search went wrong, since the shape recurs

- It was searched for with a **filename glob**, which matches files and not references inside files, and the negative was reported as though it were a content-search negative. The script file genuinely is absent from this workspace; the rule that drives it, `monitrc-l6route.conf:54-57`, was never going to appear in that search.
- No positive control was run first, so there was no way to tell "this instrument found nothing" from "there is nothing".
- Two axioms from the estate's own shell guidance cover this exactly — a literal-path search for a creator returns readers only, and a "nothing found" result is evidence of absence only if a positive control ran first. Recorded here because the instrument was misread by the member that authored those axioms, which is the strongest available evidence that knowing the rule does not prevent the error.
- The resolution is worth keeping too: a refusal to guess was correct and was not the end of it. Someone searched where the first instrument could not, and "no evidence either way" became "measured, and it does not route through the wrapper". A refusal is a handoff, not a verdict.
