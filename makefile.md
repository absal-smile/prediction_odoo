```markdown
# File: /home/smile/Bureau/testgit/makefile.md
# Makefile Documentation for Git Management

## Overview

This Makefile provides a simplified interface for common Git operations, allowing easy management of a Git repository without having to memorize complex Git commands. It is particularly useful for Odoo projects, with a default configuration targeting a folder named `smile-addons`.

## Prerequisites

- Make installed on your system
- Terminal access
- Sudo rights (for automatic Git installation if necessary)

## Available Commands

To see all available commands, run:

```bash
make help
```

### Initialization and Cloning

#### Clone an existing repository

```bash
make build c=https://repository-url.git [b=branch-name] [p=target-folder]
```

- `c=` : URL of the repository to clone (required)
- `b=` : Name of the branch to checkout (optional, uses default branch if not specified)
- `p=` : Target folder (optional, defaults to `smile-addons`)

#### Initialize a new repository

```bash
make build r=https://repository-url.git b=branch-name [p=target-folder]
```

- `r=` : URL of the remote repository to configure
- `b=` : Name of the branch to create/use
- `p=` : Target folder (optional, defaults to `smile-addons`)

### Branch Management

```bash
make branch branch-name
```

Intelligently manages branch creation or switching:

- If the branch exists locally:
  - Switches to this branch
  - If a branch with the same name exists on the remote repository, offers to:
    1. Keep the local branch as is
    2. Reset the local branch to match the remote branch
    3. Pull changes from the remote branch

- If the branch doesn't exist locally:
  - If a branch with the same name exists on the remote repository, creates a local branch that tracks the remote branch
  - Otherwise, creates a new local branch and offers to push it to the remote repository

This approach avoids divergence issues between local and remote branches.

### Change Management

#### Check repository status

```bash
make status [p=target-folder]
```

Displays the current state of the Git repository, including modified files and active branch.

#### Update from remote repository

```bash
make update [p=target-folder] [m="commit message"]
```

Fetches the latest changes from the remote repository. If you have local modifications, you'll have the option to:
1. Commit them before updating
2. Stash them, then reapply after the update
3. Cancel the operation

#### Commit and push changes

```bash
make push [m="commit message"] [p=target-folder]
```

Adds, commits, and pushes all changes to the remote repository. If no message is specified, uses "Automatic commit from Makefile".

In case of conflict during push, you'll have several options:
1. Fetch and merge remote changes
2. Force push (use with caution)
3. Cancel the operation

### Repository Configuration

#### Configure/modify remote repository URL

```bash
make remote r=https://repository-url.git [p=target-folder]
```

Configures or updates the remote repository URL.

#### Clean local repository

```bash
make clean [p=target-folder]
```

Completely removes the local repository folder after confirmation.

## Common Parameters

- `p=` : Specifies the target folder (defaults to `smile-addons`)
- `m=` : Commit message (defaults to "Automatic commit from Makefile")
- `r=` : Remote repository URL
- `b=` : Branch name
- `c=` : Repository URL to clone

## Usage Examples

### Starting a new project

```bash
# Clone an existing repository into the smile-addons folder
make build c=https://git.smile.fr/absal/myproject.git b=main

# Initialize a new repository
make build r=https://git.smile.fr/absal/myproject.git b=main
```

### Daily workflow

```bash
# Check repository status
make status

# Fetch latest changes
make update

# Create or switch to a branch
make branch feature/new-feature

# After making changes, commit and push them
make push m="Add new feature"
```

### Working with multiple projects

```bash
# Clone another project into a different folder
make build c=https://git.smile.fr/other-project.git p=other-project

# Check this project's status
make status p=other-project

# Push changes for this project
make push p=other-project m="Bug fix"
```

### Intelligent branch management

```bash
# Create a new local branch and push it to the remote repository
make branch new-branch
# (Answer "y" to the question to push the branch)

# Switch to an existing branch on the remote repository
make branch remote-branch
# (The local branch will be automatically configured to track the remote branch)

# Update a local branch that also exists on the remote repository
make branch existing-branch
# (Choose option 3 to pull changes from the remote branch)
```

## Advanced Features

- Automatic Git installation if necessary
- Automatic Git identity configuration (user.name and user.email) if not configured
- Intelligent conflict handling during push/pull operations
- Verification of branch presence on remote repository
- Options to handle uncommitted changes during updates
- Intelligent synchronization of local branches with remote branches

## Important Notes

- Use `make clean` with caution as this command completely removes the local folder
- The `make push` command with force push option can overwrite remote changes
- If you work on multiple projects, always use the `p=` parameter to specify the target folder
- The `branch` command now automatically checks if a branch exists on the remote repository to avoid divergences

This Makefile is designed to simplify common Git operations while offering advanced options to handle complex cases, with particular attention to proper synchronization of local and remote branches.
```
