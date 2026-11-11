# Writing Conventions

All text uses ASD-STE100 Simplified Technical English (STE): READMEs, guides, skills, prompts, code comments, commits, and pull requests.

## Language

- Write repository artifacts (code, comments, documentation, prompts, commits) in English. Use Spanish only for literal triggers and [glossary](glossary.md) terms.
- "Spanglish" rule: do not translate technical terms (`Kubernetes`, `pull request`, `commit`, `deploy`, `endpoint`), also in Spanish text.
- Do not translate literal triggers such as `"ejecuta el plan <change>"`. They are activation contracts.

## ASD-STE100 rules

| Rule | Instruction |
| --- | --- |
| Sentence length | Procedures: 20 words maximum. Descriptions: 25 words maximum. |
| One instruction | One instruction in each sentence. |
| Imperative | Start procedures with a verb: "Run the linter.", not "The linter should be run." |
| Active voice | Use passive voice only when the agent is not known. |
| Simple tenses | Simple present, past, and future only. |
| One meaning | One word for one meaning. No synonyms. |
| Approved words | "use", not "utilize"; "start", not "initiate"; "help", not "facilitate". |
| Articles | Keep "the", "a", and "an". |
| Paragraphs | One topic, six sentences maximum. |
| Lists | Numbered lists for sequential steps. Bullets for other items. |
| Warnings | Risk first, then the instruction: "Data loss can occur. Make a backup first." |
| Noun clusters | Three nouns together maximum. |

## Structure

- Put the result first. Use short sections and simple tables.
- Do not repeat an explanation. Link to the file that owns it.
- Put code, commands, paths, and literal output in code format.

## Abbreviations

In agents-orchestrator, define each abbreviation in the [glossary](glossary.md) before you use it. Use one form in a section (`k8s` or `Kubernetes`). Do not invent abbreviations.

## Examples

| Do not write | Write |
| --- | --- |
| It is recommended that the installer be executed prior to usage. | Run the installer before you use the agent. |
| The configuration may potentially need to be updated. | Update the configuration if it is necessary. |
| Ejecuta el despliegue en el clúster de Kubernetes. | Haz el `deploy` en el `cluster` de `Kubernetes`. |
