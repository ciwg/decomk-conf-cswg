# GUI Baseline Decision Tree

This document records the decision tree for making the GUI desktop stack part of
the baseline decomk image, likely beginning with `Block20`.

The concrete GUI stack is:

- `xvfb`
- `openbox`
- `x11vnc`
- `novnc`

The intended result is that every repository using the baseline image receives
the same browser-accessible desktop substrate without needing repo-local GUI
bootstrap logic.

## Source Rationale

This decision follows from the bootstrapping and Turing-equivalence notes that
frame decomk-controlled repositories as interacting, self-hosting workspaces.

The bootstrapping argument is that a community coordination system cannot depend
on every participant first solving a different setup problem.  Early stages need
a boring, repeatable substrate that lowers the cost of participation and makes
the system usable before the system is fully self-hosting.

The Turing-equivalence argument is that a repository plus codespace is not just a
static build target.  It is an interacting machine connected to a shared,
changing environment: humans, services, source repos, package mirrors, image
registries, terminals, browsers, and future tools all write to the effective
tape.  A missing GUI path is therefore not merely a missing optional app; it is a
missing input/output modality for that machine.

## Decision Tree

### 1. Does the baseline image need a universal human-facing control surface?

If no:

- Each repo decides independently whether it needs GUI support.
- Repos drift in package sets, runit service definitions, ports, troubleshooting
  commands, and post-create behavior.
- Consumers rediscover the same failure modes when GUI tools become necessary.
- The baseline stays smaller, but the coordination burden moves into repo-local
  bootstrapping.

If yes:

- The GUI stack belongs in the baseline image.
- Every repo starts from a common desktop-capable substrate.
- Repo-local Makefiles can assume the same service names, ports, logs, and
  browser path.
- The baseline image becomes slightly heavier, but the operational model becomes
  simpler.

Decision: yes.  The GUI desktop is baseline infrastructure, not repo-specific
application behavior.

### 2. Should the GUI stack be installed but disabled, or installed and running?

If installed but disabled:

- Image build time and package availability improve.
- Runtime behavior still differs by repo because each repo must decide how and
  when to start services.
- Troubleshooting still begins with "did this repo enable the GUI path?"
- This helps package reproducibility but does not fully solve bootstrap friction.

If installed and running:

- Every repo has the same noVNC/X11 service surface immediately after startup.
- GUI-dependent debugging, screenshots, browser tools, waveform viewers, and
  future visual workflows work without a second enablement step.
- Service supervision can be tested once at the baseline level.
- The cost is a few always-on background processes and exposed localhost ports.

Decision: installed and running.  The target state is an always-on GUI substrate.

### 3. Should this modify the existing baseline block or create a new block?

If modifying the existing block:

- Existing channel users silently receive new packages, services, ports, and
  runtime behavior.
- Debugging regressions becomes harder because the same block name refers to
  different effective behavior over time.
- This weakens the image checkpoint model.

If creating a new block:

- `Block10` remains reproducible as the prior non-GUI baseline.
- `Block20` can clearly mean "baseline plus always-on GUI desktop".
- Consumers can move intentionally from `Block10` to `Block20`.
- Channel tags can advance after the new block is tested.

Decision: create an append-only `Block20` rather than rewriting `Block10`.

### 4. What must be true before cutting the Block20 image?

The baseline GUI stack is ready for image release only when:

- `xvfb`, `openbox`, `x11vnc`, and `novnc` are installed in the image.
- runit service definitions are generated from the conf repo in a repeatable
  way.
- service startup succeeds under a PID1-like supervisor path, or under a close
  approximation that matches Codespaces behavior closely enough to be useful.
- noVNC connects through the expected forwarded browser path.
- the desktop note target writes the expected file for the remote user.
- service logs either run cleanly under supervision or the design explicitly
  avoids per-service log supervision.
- security assumptions are documented, especially `localhost` binding and the
  absence or presence of VNC authentication.

If any of those are false, fix the baseline before moving channel tags.

## Operational Consequences

Making the GUI desktop baseline means downstream repos should not each reinvent
GUI package installation, noVNC startup, or desktop note generation.  They should
inherit those from the baseline image and only add repo-specific GUI tools when
needed.

This also means decomk smoke tests should treat the GUI stack as baseline health:
if the desktop services fail, the image is not merely missing an optional feature;
it is missing part of the expected universal workspace interface.

## Current Recommendation

Create `Block20` as the first baseline block where the GUI desktop stack is
always installed and always supervised.  Keep `Block10` intact.  Promote channel
tags only after a consumer repo confirms noVNC connectivity and service health in
a fresh Codespace.
