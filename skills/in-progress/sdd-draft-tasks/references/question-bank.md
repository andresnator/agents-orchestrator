# Tasks Question Bank

Ask one at a time, in the user's language, with a recommended answer. Skip anything the spec or design already answers.

1. What is the smallest end-to-end slice that proves the change works?
2. Which design File Changes must land first because others build on them?
3. How should tasks group into phases (foundation, core, integration, tests)?
4. Which spec scenario does each task satisfy as its acceptance criteria?
5. Where do tests belong — alongside each task or a separate group?
6. Does the estimated diff exceed ~400 changed lines, and on what boundary should it split into chained PRs?
7. What per-task verification proves completion (command, observable behavior)?
8. Is any task too big for one session and needs splitting?
