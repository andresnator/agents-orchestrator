# English Tutor Agent Scenarios

Golden-case validation for the explicit English tutor MVP. These cases validate prompt behavior, privacy boundaries, and documentation consistency only; there is no build or automated test runner for this repository.

## Manual Review Checklist

- [ ] Correction outputs use this exact order: `Original`, `Improved`, `Explanation`, `Learning gap`, `Practice suggestion`.
- [ ] Tutoring activates only through explicit English coaching requests, the `english-tutor` subagent/skill, or `/english`.
- [ ] All examples are generic or synthetic.
- [ ] No learner-specific raw history, personal identifiers, private examples, or Notion contents appear in repo artifacts.
- [ ] `English Coach Memory` is described only as a private Notion-side contract.
- [ ] Passive/background tutoring is disclosed as a future host/orchestrator integration, not current runtime behavior.

## Golden Cases

### 1. Standard correction

**Input**

```text
/english I have 30 years and I work in software since five years.
```

**Expected behavior**

- Returns the five required fields in order.
- Preserves the intended meaning.
- Identifies useful gaps such as age expression and present perfect/duration.
- Gives one focused practice suggestion.

**Must not include**

- Personal learner history.
- Unrelated style rewrites that change the meaning.

### 2. Multiple mistakes batched

**Input**

```text
/english Yesterday I go to a meeting and explain the architecture more clear.
```

**Expected behavior**

- May return one combined correction or multiple concise correction blocks.
- Every block keeps `Original`, `Improved`, `Explanation`, `Learning gap`, `Practice suggestion` in order.
- Focuses on high-value gaps such as past tense and adverb/adjective choice.

**Must not include**

- A long grammar lecture.
- More than the minimum useful corrections.

### 3. No unsolicited coaching during coding

**Input**

```text
Help me debug this failing Java test.
```

**Expected behavior**

- The assistant stays focused on the coding request.
- No English tutoring output appears because `/english` or another explicit tutoring cue was not used.

**Must not include**

- Grammar corrections for the user's coding message.

### 4. Stop/deactivate tutor mode

**Input**

```text
Stop English corrections for now. Let's go back to the implementation.
```

**Expected behavior**

- Acknowledges deactivation.
- Stops tutoring until explicitly reactivated.
- Continues normal work without language feedback.

**Must not include**

- Further English corrections after deactivation.

### 5. Spanish explanation

**Input**

```text
/english Explain in Spanish: I am agree with this solution.
```

**Expected behavior**

- Keeps `Original` and `Improved` focused on the English phrase.
- Provides `Explanation` and `Learning gap` in Spanish.
- Explains the pattern concisely, for example agreement expression.

**Must not include**

- Translation that removes the English learning target.

### 6. Recurring gap summary

**Input**

```text
/english Summarize my recurring gaps from English Coach Memory.
```

**Expected behavior**

- Produces aggregate categories only, such as articles, prepositions, verb tense, word order, or register.
- Recommends the next practice focus.
- Notes that `English Coach Memory` is private and outside the repository.

**Must not include**

- Raw correction history.
- Private learner examples.
- Notion page contents copied into the repo.

### 7. Privacy boundary and synthetic examples

**Input**

```text
Review the English tutor scenarios for privacy.
```

**Expected behavior**

- Confirms examples are generic or synthetic.
- Confirms repo artifacts contain only the public contract name `English Coach Memory` and aggregate schema guidance.
- Flags any learner-identifiable data if found.

**Must not include**

- Any real learner profile, personal identifiers, or private Notion content.

### 8. `/english` missing input

**Input**

```text
/english
```

**Expected behavior**

- Asks one question for the text or coaching target.
- Does not invent a correction target.

**Must not include**

- Multiple questions.
- Generic unsolicited lessons.

### 9. `/english` shortcut behavior

**Input**

```text
/english Make this sentence sound natural: I will explain you the design.
```

**Expected behavior**

- Treats `/english` as explicit activation.
- Returns the five-field correction contract.
- Keeps the response concise and actionable.

**Must not include**

- File edits, tool calls, or persistent public learner memory.

### 10. Passive/background limitation disclosure

**Input**

```text
Can this tutor correct every message automatically in the background?
```

**Expected behavior**

- States that this repository does not implement passive/background runtime interception.
- Describes passive tutoring only as a future host/orchestrator integration seam with explicit opt-in and privacy controls.

**Must not include**

- Claims that background monitoring currently works.
