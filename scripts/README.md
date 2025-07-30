# Scripts Documentation

## Create and Merge PR Script

The `create-and-merge-pr.sh` script automates the GitHub Pull Request workflow, allowing you to quickly create PRs and optionally merge them immediately.

### Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- Git repository with changes on a feature branch
- Write access to the repository

### Usage

#### Option 1: Via npm script (Recommended)

```bash
npm run create-pr
```

#### Option 2: Direct execution

```bash
./scripts/create-and-merge-pr.sh
```

### How it works

1. **Validation**: Checks for required tools and proper git state
2. **Input Collection**: Prompts for PR title and description
3. **PR Creation**: Creates the PR using GitHub CLI
4. **Optional Merge**: Asks if you want to merge immediately
5. **Merge Options**: Choose merge strategy (merge commit, squash, rebase)
6. **Cleanup**: Optionally delete the feature branch after merge

### Features

- ✅ **Interactive prompts** with colored output
- ✅ **Multiline description support**
- ✅ **Multiple merge strategies** (merge, squash, rebase)
- ✅ **Branch cleanup** option
- ✅ **Safety validation** (prevents merging from main branch)
- ✅ **Error handling** with helpful messages

### Example Workflow

```bash
# 1. Create and switch to feature branch
git checkout -b feat/new-feature

# 2. Make your changes and commit
git add .
git commit -m "Add new feature"

# 3. Push the branch
git push -u origin feat/new-feature

# 4. Run the PR script
npm run create-pr

# 5. Follow the interactive prompts:
#    - Enter PR title
#    - Enter PR description (supports markdown)
#    - Confirm PR creation
#    - Choose to merge immediately (optional)
#    - Select merge strategy
#    - Choose to delete branch after merge
```

### Sample Interaction

```
🚀 GitHub PR Creation and Merge Script

[INFO] Current branch: feat/new-feature

📝 PR Details

Enter PR title:
> Fix: Improve real-time connection stability

Enter PR description (multiline supported):
(Press Ctrl+D when finished, or type 'END' on a new line)
> ## Problem
> Fixed connection issues in chat CLI
>
> ## Solution
> Added reconnection logic
> END

📋 PR Summary
Title: Fix: Improve real-time connection stability
Description: ## Problem...
Branch: feat/new-feature

Create PR with these details? (y/N): y

[SUCCESS] PR created successfully!
https://github.com/zachboyd/pantry/pull/11

[INFO] PR #11 is ready for review.

Do you want to merge this PR immediately? (y/N): y

[INFO] Select merge strategy:
1) Merge commit (default)
2) Squash and merge
3) Rebase and merge

Enter choice (1-3, default: 1): 1

Delete feature branch after merge? (y/N): y

[SUCCESS] PR #11 merged successfully! 🎉
[INFO] Switched back to main branch.

🚀 All done! Your changes are now live on main.
```

### Error Handling

The script includes comprehensive error checking:

- ❌ GitHub CLI not installed or authenticated
- ❌ Not in a git repository
- ❌ Uncommitted changes (with override option)
- ❌ Attempting to create PR from main/master branch
- ❌ Empty PR title
- ❌ Failed PR creation or merge

### Tips

1. **Branch Naming**: Use descriptive branch names like `feat/feature-name` or `fix/bug-description`
2. **Commit First**: Make sure your changes are committed before running the script
3. **Review**: Even with immediate merge option, you can still review the PR on GitHub
4. **Templates**: Consider creating PR templates in `.github/pull_request_template.md` for consistent descriptions
