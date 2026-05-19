# TE-galan: GUI Runtime Selftest Entrypoint

TE ID: TE-galan

## Decision Under Test

How should this repo validate TODO-dagij and GUI runtime health in Codespaces while
keeping the normal `decomk-conf-cswg` producer-bootstrap context unchanged?

## Assumptions

- The selftest target should be this repository, not `mob-sandbox`.
- The normal repo context intentionally remains `Block00`.
- A GUI runtime test must exercise `GUIDesktop-1`, runit service startup, noVNC
  HTTP, noVNC WebSocket proxying, and the desktop note.
- Codespaces creation may succeed even when `gh codespace create --status`
  reports a timeout, so the harness should create, discover by display name, and
  poll state explicitly.

## Alternatives

1. Extend the existing capture selftest directly.
2. Add a new GUI selftest that uses a separate devcontainer path.
3. Use a consumer repo such as `mob-sandbox` as the default GUI selftest target.
4. Create a normal `decomk-conf-cswg` Codespace, then SSH in and rerun decomk
   manually with a GUI context.

## Scenario Analysis

Normal bootstrap capture favors the existing selftest.  It should keep proving
that `/var/decomk` capture and stage0 execution work for the normal producer
context.

GUI runtime validation favors a separate selftest.  It needs stronger assertions
than a capture test: service health, process presence, HTTP reachability,
WebSocket-to-RFB reachability, and the absence of the TODO-dagij runit-dispatch
error.

Consumer-repo validation is valuable but is not the right default here.  It adds
another repo's branch state and devcontainer policy to the failure surface.

Manual SSH reruns are useful for debugging, but they do not prove initial
devcontainer startup behavior.  The GUI context must be selected before
`updateContent` and `postCreate` run.

## Conclusion

Use a dedicated selftest devcontainer at
`.devcontainer/gui-selftest/devcontainer.json` with
`DECOMK_CONTEXT=GUI-SELFTEST-1`.  Keep `tools/selftest-codespaces.sh` as the
generic capture test, add `tools/selftest-gui-codespaces.sh` for GUI runtime
health, and share Codespaces lifecycle helpers between them.

## Implications

TODO-dagij can be validated in this repo without changing normal startup policy.
TODO-gopof can later retarget `GUI-SELFTEST-1` from current `GUIDesktop-1`
composition to the future Block20 GUI baseline once Block20 exists.
