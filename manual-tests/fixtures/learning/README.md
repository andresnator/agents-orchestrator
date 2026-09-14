# Prepare one Learning case

Prepare any ID directly; no case consumes another case's output. [cases.json](cases.json) enumerates fresh variants, and [materials/inputs.md](materials/inputs.md) supplies exact learner inputs. All starting snapshots and materials are **synthetic**, including historical narrative. They are not verified learner references, native consent, or human competence. Every initialized topic uses a theme profile: HTTP cache, pizza dough, airport English, or plugin security. `validate.mjs` checks the slug, title, goal, concept, module, win, and language units against that profile, so a valid schema alone cannot hide a cross-topic fixture.

## Install and launch

Requirements: Python 3.9+, Node 24+ (native TypeScript loading), Git, OpenCode, and Herdr for parallel execution. Preparation was checked with Python 3.9.6 and Node 24.20.0; the scripted provider was smoke-tested through OpenCode 1.18.30 with a real `learning_context` tool call. Record installed versions during each run. No model credentials or model calls are needed to prepare or validate fixtures.

Run from the **case's new worktree**, with an absolute, nonexistent destination outside the source tree:

```bash
python3 manual-tests/fixtures/learning/prepare.py MT-LEARNING-MODULE-DELIVERY /tmp/learning-run/case-01
node manual-tests/fixtures/learning/validate.mjs /tmp/learning-run/case-01
```

Replace the ID and destination for each assignment. `manifest.json` lists variant names. `prepare.py` refuses existing destinations. Each variant has its own project, config, XDG roots, temporary files, provider directory, materials, and evidence. Dates default to local today; `--date YYYY-MM-DD` is only for explicitly labeled historical fixture checks, never simulated human follow-up.

For **each variant**, install from its assigned worktree before sourcing its environment (the installer links to that worktree):

```bash
bash installers/opencode.sh install --domain learning --target /tmp/learning-run/case-01/base/config --no-install-brew-tools
source /tmp/learning-run/case-01/base/env.sh
opencode --version
node --version
opencode debug agent mentor > ../evidence/mentor.json
opencode debug agent english-tutor > ../evidence/english-tutor.json
```

Exception: `skill:*` variants already contain exactly one copied skill. Do not run the domain installer there. Use the host's default agent with only that skill exposed. `learning-session` handles both teaching and the quiz input; there are eight skill targets, not nine skills.

For real-model runs, configure only the explicitly authorized provider/model and child-agent settings in this variant's config. Keep credentials out of evidence. Isolated XDG roots intentionally do not inherit host auth. Supply authorized credentials deliberately; never copy the whole global config. Inspect effective parent and child model IDs from exported host messages, not preset names. Missing authorization or credentials means `BLOCKED` (model comparison without authorization is `PENDING`).

Start `opencode` in the sourced shell for native interaction. For scripted protocol checks start the fixture service in another case-owned shell:

```bash
python3 /absolute/case-worktree/manual-tests/fixtures/learning/provider.py /tmp/learning-run/case-01/base/provider
```

It binds loopback port 0 and writes the actual port/PID to `endpoint.json`. Put this provider in the variant's `config/opencode.json` (replace BASE_URL with that value):

```json
{
  "model": "fixture/scripted",
  "small_model": "fixture/scripted",
  "enabled_providers": ["fixture"],
  "provider": {
    "fixture": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Manual protocol fixture",
      "options": {"baseURL": "BASE_URL", "apiKey": "fixture"},
      "models": {"scripted": {"name": "Scripted", "limit": {"context": 128000, "output": 16000}}}
    }
  },
  "agent": {
    "mentor": {"model": "fixture/scripted"},
    "english-tutor": {"model": "fixture/scripted"},
    "learning-researcher": {"model": "fixture/scripted"},
    "learning-writer": {"model": "fixture/scripted"},
    "learning-summarizer": {"model": "fixture/scripted"}
  }
}
```

Use the installed host's `/doc` for HTTP request schemas if using `opencode serve --hostname 127.0.0.1 --port 0`; record its actual listening address. UI and API are equivalent only when the session records prove the same native interaction. Check `/experimental/tool` with `provider=fixture&model=scripted` for the tool inventory.

## Drive the scripted provider

The provider writes `request-0001.json`, etc., and waits for the matching `response-0001.json`. Inspect each request to distinguish parent and worker; concurrent requests are numbered under a lock. Write a temporary JSON file then rename it into place. Replies are supplied by the executor, so no fixed guessed session IDs or approvals are baked in. Example responses:

```json
{"message":{"role":"assistant","tool_calls":[{"id":"call-context-1","type":"function","function":{"name":"learning_context","arguments":"{}"}}]}}
```

```json
{"delay_seconds":5,"message":{"role":"assistant","content":"Scripted researcher terminal result"}}
```

Use `learning_event_reference` for the exact event payload, subject and revision. Read real tool output in the next provider request; supply its returned `next_args` **unchanged** to `question`, answer in the host UI/API with the documented option, then call `learning_choice_result`. New references come from `learning_evidence` after submitting the exact input as an ordinary user message. Never turn a synthetic snapshot's narrative into a verified quote. For FLEXIBLE-PATH, submit the plugin explanation and record real consolidation with the practical gap before testing scope revision.

Construct writer JSON from the actual assignment fields/schema in the child request. Use its artifact path, method, module and source revision. For malformed output return `not JSON`; for the retired writer variant add `selected_card_ids: []` to otherwise valid output. To delay a worker, leave its response absent or use `delay_seconds`; advance the parent through a separate host request if required. Preserve the accepted child ID across interruption and recovery. Stop the provider by its recorded PID only after checking process ownership.

## Preparation by ID

Every variant listed in the manifest is mandatory unless its step is explicitly `PENDING`. Start each variant with a fresh host session and environment. Within a variant, sequential steps intentionally share state; before repeating a destructive negative mutation, prepare another fresh copy of that same ID. The catalog contains the assertions; the instructions below supply concrete setup and inputs.

| ID suffix | Starting points and execution details |
|---|---|
| RUNTIME | `base`, `limits`, `cancellation`, `transport`, `missing_api`, `missing_helper`, `upgrade` are empty; `retired` starts in Class. Use the provider protocol above. In `limits`, use `"q".repeat(300)` and 301, the Omit/Practice choice, then change the subject, replay its ID, and stage a second choice. Delay researcher by five seconds; try another worker while pending, then cancel the parent in the host. For transport, disconnect the client while retaining host/child and recover that ID. Upgrade fixture recipe and host-only fault boundary are below. Reply Reject to the command permission. |
| SESSION | Empty `base`; run the catalog's exact `/learn session` prompt and Class answer. Decline any save offered; inspect hidden files. |
| PATH | Empty variants for English path, Spanish natural route, ambiguous route, Java Create/Cancel, rejection, missing consent and changed proposal. For Java say `/learn path Java: basics, OOP, collections, exceptions, streams, concurrency, testing and JVM tooling. Goal: build and test a concurrent service. Two sessions per week. Materials in Spanish.` Choose Create in `java_create`, Cancel in `java_cancel`, Revise then change the goal in `changed`, Cancel in `reject`, and dismiss in `missing_consent`. In `markdown_only`, create `.ai/learning/http-cache-validation/mission.md` containing `Existing notes` before requesting that slug. No runtime-created state is a prerequisite. |
| MODULE-DELIVERY | `base` and `final` start in Mission, `omit` in Class, `partial` with a synthetic partial attempt, `stale_writer` and `legacy` in Consolidation. Use Cache inputs in order; dismiss the first readiness question, ask the ETag clarification, then select Practicar. In `omit`, select Omitir; in `partial`, submit the partial input before Omitir. Submit the consolidation/transfer answer. The fixture has one module, so `final` exercises mission completion. `legacy` has schema-1 narrative but no verified references: obtain new real references, then restart and reuse only those stored by this run. In `invalid_evidence`, test each rejection in the catalog separately against a before-state hash. |
| INDEPENDENT-EVIDENCE | All variants start in Class with no attempt/consolidation. Submit the Class answer, select its exact excerpt with `learning_evidence`, and request teach-back. Omit module ID in `base`, provide M-0001 in `explicit_module`. `automatic` omits selection; `no_evidence` starts the writer before any answer. In `invalid`, independently alter quote, message ID, part ID, session ID; select assistant or synthetic host text; duplicate references; pass `[]`. Capture jobs and state before each request. |
| FLEXIBLE-PATH | `base`, `defer`, `cancel`, `stale`, `conceptual_gap` use `flexible`: the `plugin-security` goal requires implementing a plugin, M-0001 requires implementing/activating/diagnosing/disabling it, and M-0002 requires incorporating it in the integration project. Practice is skipped; materials and `No implemented plugin.` remain pending practical evidence. Submit Plugin theory input and record its verified explanation with that gap still blocking. Request the catalog's theoretical scope, approve Apply, and check both old practical wins survive in scope history. In `cancel` choose Cancel, then test changed subject; `stale` advances revision before old approval; `conceptual_gap` retains `Cannot explain plugin activation permissions.` in reassessment. In `defer` choose M-0002 and then return to M-0001. `prior` uses `plugin-mission`: one theoretical plugin module in Mission with no recorded teaching, attempt, consolidation or materials. Submit Plugin theory input, choose Omitir and request materials. |
| AMBIGUOUS-ROUTE | All copies contain initialized `pizza` with the pizza-dough profile. Say `/learn pizza`; choose localized one-off in `base`, durable in `durable`; dismiss and say `path de aprendizaje` in `dismissed`. For the one-off answer use the Pizza inputs. |
| SUMMARY-LIFECYCLE | Each copy starts empty. Before saving, say `/learn session Explain HTTP statelessness` and submit the Cache Class answer in that same session. Then use the catalog save prompt and choose Save. In `concurrent`, issue the same summary-create call through two host requests and replay after settlement; a second independent Save choice tests collision safety. `malformed` returns `not JSON` from the summarizer. |
| REVIEW-ONDEMAND | Closed module, Cornell note, and historical queue already supplied. `/learn review http-cache-validation`; submit Review 1 and Review 2 inputs. Ask `Give me a quiz`, then `Give me a drill`. In `retired`, use the catalog's retired requests. Real next-day repetition remains PENDING until that date; do not occupy a pane waiting. |
| ENGLISH | `base` empty; `adoption` has an English/Spanish topic. Use the catalog sentence and Language retry. In adoption repeat `She has lived here since two years` and correct to `She has lived here for two years`; approve only the displayed synthetic category. Then say `Explain a Java for loop` without `/english`. |
| STANDALONE-SKILLS | Eight pre-copied single-skill configs. Invoke the corresponding catalog input using only that skill. Supply Standalone material to Cornell; run the quiz under learning-session as a second isolated session; supply Dialogue to language-loop, Source/Spanish to bidirectional-translation, and Vocabulary rows to anki-vocab. Do not supply a save destination. |
| STATE-RECOVERY | `base`, `views`, `foreign`, lock variants start in Class; `writer` in Consolidation. Use a `record_class` event from event reference, same ID/body twice then change evidence, and two distinct IDs with the same expected revision. `views`: run `fault.py <assignment>/views pending-views`, then recover through host. `writer`: obtain real consolidation input, delay a writer, advance with a valid event, and test stale attachment; repeat current writer with host restart. Filesystem fault recipes below. |
| NO-SRS-COMPAT | Pending and selected historical retention copies include valid preview digest, card, review event, retired consent and future language date. Submit a real Cache consolidation answer, attach current materials, and Close; compare historical field values and queue bytes. `bad_digest`: run `fault.py <assignment>/bad_digest bad-digest`; `bad_disposition`: run `fault.py <assignment>/bad_disposition bad-disposition`; both must fail on host read. `unexpected_date`: send add_language_unit with next_due tomorrow. Do not access or back up any real learner topic. |
| LANGUAGE-PRACTICE | `one`, `five`, `six` have that many units passively seen on preparation date. `/learn path airport`, then `Quiero practicar ahora L-0001`. On the one-unit copy try Gist, meaning-changing, input-only, then equivalent in sequence; on larger copies spread them over the first three units and finish remaining units in order. Replace flight number in inputs to match each unit. Attempt topic completion before and after required production and module criteria. `negative` sends add_language_unit with next_due and tries completion while input-only. |
| VOCAB-EXPORT | English/Spanish `airport` with no candidates/exports. Use the two exact Vocabulary rows, choose only check in. Edit boarding pass's example to `Please show your boarding pass.` and matching Spanish, reject old approval, then choose that row on a fresh preview. Replay the exact event, propose `CHECK   IN` in English and `check in` in French. In `malformed`, independently mismatch field 1, add a quote, newline, or sixth field, checking no partial write each time. |
| MODEL-VARIANCE | Own `session`, `module`, `review`, `language`, `vocab`, and `standalone` samples; prepare this ID anew for each authorized model. Use respectively SESSION's exact prompt/answer, MODULE's Omitir+consolidation, Review 1/2, input-only language, selected check in export, and Cornell teacher notes above. These are inputs, not executions/results of other IDs. Record per-sample rubric and state diff. Without authorized models, PENDING. |
| DELAYED-RETENTION | Own Mission seed. A real participant supplies day-0 explanation/transfer; do not submit the synthetic answer on their behalf. Ask the dated prompts from inputs only on the actual day with that participant. Without participation, day 0 PENDING; days 7/30 PENDING with continuation date and record path. No pane remains assigned while waiting. |

## Fault recipes and evidence boundaries

- **Upgrade:** in `upgrade/config`, install current Learning, then run `python3 manual-tests/fixtures/learning/fault.py <assignment>/upgrade upgrade` from the worktree. This adds synthetic retired files and exact `file\t<absolute-path>` ownership records in `.agents-orchestrator-manifest`. Reinstall Learning with the same target and verify both files are removed. This tests removal of managed retired paths, not loading a historical runtime. For a genuine old-version upgrade, resolve an explicitly selected old Git SHA in a separate case-owned checkout and install it first; if unavailable, that upgrade variant is BLOCKED. Preserve the before manifest. Never fabricate an old-version PASS.
- **Missing helper:** run `node manual-tests/fixtures/learning/host-faults.mjs <assignment>/missing_helper`. This copies the runtime away from source dependencies and invokes its loader with empty fixture helper roots; it must report `learning_tool_helper_unavailable`. It never removes global or installed packages. This is loader injection evidence, not a live-host result. A live host that auto-repairs dependencies may make this fault unavailable; report that subcheck BLOCKED.
- **Missing session API:** run `node manual-tests/fixtures/learning/host-faults.mjs <assignment>/missing_api`. A copied host client without `session.prompt` must report `sequential_session_api_unavailable` and create zero children. A provider cannot remove a host SDK method. Keep this deterministic evidence separate; a live-host claim needs an instrumented disposable host and otherwise remains BLOCKED.
- **Foreign state:** prepare another copy of this same ID under the assignment root; replace only the `foreign` variant's `.state.json` with a symlink to the other copy's same-slug state. The second copy is part of this case, never another case's data. Snapshot both before and after.
- **Locks:** run `python3 manual-tests/fixtures/learning/fault.py <assignment>/<variant> dead-lock`, `live-lock`, or `malformed-lock`. The helper writes `{pid, token, acquired_at}` with a UUID-v4 token, using an exited child or an owned sleeper; malformed writes `not JSON`. The sleeper's stdin/stdout/stderr use `DEVNULL`, so the helper also finishes when its launcher captures output. Ownership is saved in `evidence/lock-owner.json`. Race two host recovery requests against the dead lock. Record ownership/claim responses and stop only the owned sleeper. Do not guess a globally unused PID.
- **Read-denied writer:** deny read in the copied writer's config, retain `skill` access, and inspect returned skill content in host tool parts. Never edit the symlinked source skill or agent.
- **Bad evidence:** capture actual user, assistant and synthetic parts through the host. If the host cannot create a synthetic or foreign-session condition, mark that subcheck BLOCKED; fabricated fixture IDs are only useful for the missing-ID rejection.

## Record and clean up

Record every numbered catalog step and negative variant in `evidence/checks.json`: assertion, actual observation, PASS/FAIL/BLOCKED/PENDING, layer (`fixture`, `scripted-protocol`, `model`, `human`), and relative evidence paths. Include session exports with actual user/tool IDs, native requests/replies, effective parent/child models, state before/after, generated artifacts, service logs, process identities, source SHA, versions and duration. A case cannot be PASS while any required subcheck is unexecuted; use FAIL for observed violations, BLOCKED for unavailable execution, PENDING for human/date/authorization continuation.

Before deletion, copy evidence to the coordinator's `.ai/manual-test-runs/<run-id>/<case-id>/`, verify readability and checksums, stop owned services, and end the case agent session. Remove PASS environments only after archival; retain FAIL/BLOCKED and any PENDING environment needed to continue. Retaining an environment never requires retaining its pane or running processes. Cleanup must include each variant and any foreign-state/upgrade copy owned by the assignment.

## Validate preparation and the queue

Run `python3 scripts/lint-manual-tests.py` and `git diff --check`. Prepare every key in `cases.json` twice under different nonexistent directories and run `validate.mjs` on each. Compare copied state/material bytes and verify each environment points only to its own directories; do not source another assignment. Installation must use the assigned worktree.

Run `node --test manual-tests/fixtures/learning/fixtures.test.mjs` for the focused regressions: captured live-lock pipes, theoretical plugin prior knowledge, practical requirements preserved through scope revision, and rejection of mismatched FLEXIBLE-PATH variants. These are fixture and runtime-contract checks with explicitly synthetic consent, not native UI or model evidence. `validate.mjs` checks FLEXIBLE-PATH's expected kind and starting conditions by case ID and variant, independently of the supplied kind label; run it before executing or injecting faults into the fixtures.

Inside Herdr, run:

```bash
python3 manual-tests/fixtures/learning/queue-smoke.py /tmp/learning-queue-unique-run
```

This creates four owned panes and five fresh worktrees at HEAD, launches five **simulated processes**, and verifies continuous reuse, inactivity review, timeout and archive-before-cleanup. Test-only thresholds are 2 seconds without progress and 5 seconds total. `queue.json` records the ordering; the fifth must use the first pane before the other three finish. PASS worktrees are removed; blocked/timeout worktrees are retained. Copy the output into the coordinator report before any later cleanup. This smoke check does not validate actual coding-agent startup/exit, native consent, or model behavior. The production limits and agent lifecycle are specified in the reusable prompt.
