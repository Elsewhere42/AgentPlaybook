---
name: personalize
description: Help the user create or update an optional, local profile of cross-project working preferences. Ask first and save only after the user approves the proposed text.
argument-hint: "[optional topic]"
disable-model-invocation: true
---

# Personalize

Help the user record only the preferences they choose to share. This is an optional profile of working preferences, not a biography or a place for project rules.

The installed profile is:

- Linux, macOS or WSL: `~/.agent-playbook/user-profile.md`
- Windows: `%USERPROFILE%\.agent-playbook\user-profile.md`

Ask a compact set of questions. Let the user skip any question or end the conversation at any point:

1. What response style and level of detail work best?
2. Are there topics or tools where a brief explanation is especially useful?
3. Are there command, shell or path conventions to follow?
4. Any strong workflow preferences or constraints that should apply across projects?

Do not infer answers from the user's name, location, repositories or past messages. Do not ask for secrets, sensitive personal details, or project-specific information. A preference can be omitted if it is unclear or only applies to one task.

Draft concise profile text from the user's answers and show it to them. Do not write anything until they explicitly approve the draft.

After approval:

1. Read the current profile if it exists. Preserve any content the user did not ask to change, and show the merged result for approval before writing if it changes existing content.
2. If the file exists, make a timestamped plain-text backup beside it before replacing it.
3. Write only to the installed profile path for the current environment. If its parent folder does not exist, ask before creating it.
4. Tell the user the path and remind them to rerun the Agent Playbook installer so the updated profile is included in each tool's instructions.

Never write this profile into a project repository or the Agent Playbook repository.
