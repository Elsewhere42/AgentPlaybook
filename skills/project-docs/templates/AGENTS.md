# {{PROJECT_NAME}}

[One or two sentences: what this is, and who it's for.]

[DESIGN.md](DESIGN.md) is the source of truth for the project's current state. Read it before changing anything.

## Project basics

- **Status:** [Idea / In development / Live]
- **Stack:** [Languages, frameworks, images]
- **Runs on:** [Where it's hosted, or local only]
- **Public address:** [URL, or none]
- **Repo:** [Remote and visibility, or local git only]
- **Depends on:** [Other services or projects, or none]

Related projects (read by /refresh): [paths to sibling project folders, or delete this line]

## How to work on it

- **Run locally:** [Command]
- **Test:** [Command]
- **Verify after a change:** [docs/Verify.md, or the checks to run]
- **Deploy:** [Command, or see DESIGN.md. As which account?]
- **Rollback:** [How to undo a deploy]

## Project rules

- Keep the docs current: [DESIGN.md](DESIGN.md) for what exists, [DecisionLog.md](DecisionLog.md) for why, [LearningLog.md](LearningLog.md) for gotchas.
- Decision (D-) and learning (L-) numbers belong to this project alone. Always name the project when referring to another one's, as in `OtherProject D-012`.
- At the start of every task, before answering or doing other work, check whether `CLAUDE.md`, `DESIGN.md`, `DecisionLog.md` and `LearningLog.md` are present. For local-only project docs, the three memory files under `.agent/` count as present. If any required file is missing, check for `.agent/project-docs-opt-out.md`. If there is no note, ask immediately whether the user wants the default files set up with `/project-docs`, then wait for the answer. This applies to read-only and change requests, not only substantive edits. If they decline, create the local opt-out note and exclude it from Git. Do not ask again while the note exists; an explicit setup request, yes to an active offer, or `/project-docs` request overrides it.
- [Anything else that differs from or adds to the user's global rules.]

## Plan

[Phases or next steps.]
