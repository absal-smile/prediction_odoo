.PHONY: help build branch push update status clean remote

p ?= smile-addons
m ?=
DEFAULT_MESSAGE ?= "Automatic commit from Makefile"
MESSAGE ?= $(if $(m),$(m),$(DEFAULT_MESSAGE))
REPO_URL ?=
BRANCH ?=

help:
	@echo ""
	@echo "\033[1;36mSimple Git Commands (via Makefile)\033[0m"
	@echo "========================================="
	@echo "\033[1;33mUsage:\033[0m"
	@echo "  \033[1;32mmake build c=https://... [b=dev]\033[0m"
	@echo "      → Clone repo into 'smile-addons' (or p=...) and checkout branch"
	@echo ""
	@echo "  \033[1;32mmake build r=https://... b=main\033[0m"
	@echo "      → Init repo in 'smile-addons' (or p=...), set remote, create/switch to branch"
	@echo ""
	@echo "  \033[1;32mmake branch branch-name\033[0m"
	@echo "      → Create or switch to branch 'branch-name' in folder 'smile-addons'"
	@echo ""
	@echo "  \033[1;32mmake push [m=\"commit msg\"]\033[0m"
	@echo "      → Commit all changes and push with message (default: \"Automatic commit from Makefile\")"
	@echo ""
	@echo "  \033[1;32mmake remote r=https://...\033[0m"
	@echo "      → Set or update remote origin URL"
	@echo ""
	@echo "  \033[1;32mmake status\033[0m"
	@echo "      → Show Git status in folder 'smile-addons'"
	@echo ""
	@echo "  \033[1;32mmake update\033[0m"
	@echo "      → Pull latest changes in folder 'smile-addons'"
	@echo ""
	@echo "  \033[1;32mmake clean\033[0m"
	@echo "      → Remove the 'smile-addons' folder (or p=...) to start fresh"
	@echo ""

	@echo "\033[1;34mIn Case of Issues:\033[0m"
	@echo "\033[1;33m- Empty repo or wrong branch?\033[0m"
	@echo "    → Check the repo URL and branch with \033[1;32m'make status'\033[0m"
	@echo ""
	@echo "\033[1;33m- Can't push (non fast-forward)?\033[0m"
	@echo "    → Run \033[1;32m'make update'\033[0m to pull latest changes, then push again"
	@echo ""
	@echo "\033[1;33m- No remote repository set?\033[0m"
	@echo "    → Use \033[1;32m'make remote r=https://...'\033[0m to set or update the remote origin"
	@echo ""
	@echo "\033[1;33m- Wrong folder path?\033[0m"
	@echo "    → Use \033[1;32mp=your-folder-name\033[0m to target the correct directory"
	@echo ""



build:
	@echo "Checking if Git is installed..."
	@if ! command -v git >/dev/null 2>&1; then \
		echo "Git is not installed. Installing..."; \
		sudo apt-get update && sudo apt-get install -y git; \
	else \
		echo "Git is installed."; \
	fi; \
	\
	echo "Checking Git global user config..."; \
	if ! git config --global user.name >/dev/null || ! git config --global user.email >/dev/null; then \
		echo "Git user.name or user.email not configured."; \
		echo "Please enter your Git user.name:"; \
		read username; \
		git config --global user.name "$$username"; \
		echo "Please enter your Git user.email:"; \
		read useremail; \
		git config --global user.email "$$useremail"; \
	else \
		echo "Git user.name is set to '$$(git config --global user.name)'"; \
		echo "Git user.email is set to '$$(git config --global user.email)'"; \
	fi; \
	\
	if [ -n "$(c)" ]; then \
		if [ -d "$(p)/.git" ]; then \
			echo "The folder '$(p)' already exists and is a Git repository."; \
			current_branch=$$(git -C "$(p)" branch --show-current); \
			if [ -n "$(b)" ]; then \
				if [ "$$current_branch" = "$(b)" ]; then \
					echo "Current branch = '$(b)', executing pull..."; \
					git -C "$(p)" pull; \
				else \
					echo "Current branch: '$$current_branch', requested branch: '$(b)'"; \
					echo "Attempting to switch branches..."; \
					if git -C "$(p)" show-ref --verify --quiet refs/heads/$(b); then \
						git -C "$(p)" checkout $(b); \
						git -C "$(p)" pull origin $(b); \
						echo "Switched to existing branch '$(b)'."; \
					else \
						echo "Creating new branch '$(b)' based on origin/$(b) if available..."; \
						if git -C "$(p)" ls-remote --exit-code origin $(b) >/dev/null 2>&1; then \
							git -C "$(p)" fetch origin $(b); \
							git -C "$(p)" checkout -b $(b) origin/$(b); \
							echo "Branch '$(b)' created successfully."; \
						else \
							echo "Branch '$(b)' does not exist on the remote repository."; \
							echo "Creating a new local branch '$(b)'..."; \
							git -C "$(p)" checkout -b $(b); \
							echo "New local branch '$(b)' created."; \
						fi; \
					fi; \
				fi; \
			else \
				echo "No branch specified, pull not performed."; \
			fi; \
		elif [ -d "$(p)" ]; then \
			echo "The folder '$(p)' exists but is not a Git repository."; \
			echo "Do you want to delete this folder and clone the repository? (o/n)"; \
			read answer; \
			if [ "$$answer" = "o" ] || [ "$$answer" = "O" ] || [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
				echo "Deleting folder '$(p)'..."; \
				rm -rf "$(p)"; \
				if [ -n "$(b)" ]; then \
					echo "Cloning '$(c)' into '$(p)' with branch '$(b)'..."; \
					git clone --branch "$(b)" "$(c)" "$(p)"; \
				else \
					echo "Cloning '$(c)' into '$(p)' (default branch)..."; \
					git clone "$(c)" "$(p)"; \
				fi; \
			else \
				echo "Operation canceled."; \
				exit 1; \
			fi; \
		else \
			if [ -n "$(b)" ]; then \
				echo "Cloning '$(c)' into '$(p)' with branch '$(b)'..."; \
				git clone --branch "$(b)" "$(c)" "$(p)"; \
			else \
				echo "Cloning '$(c)' into '$(p)' (default branch)..."; \
				git clone "$(c)" "$(p)"; \
			fi; \
		fi; \
	else \
		if [ ! -d "$(p)" ]; then \
			echo "Creating folder '$(p)'..."; \
			mkdir -p "$(p)"; \
		fi; \
		echo "Initializing new Git repository in '$(p)'..."; \
		git -C "$(p)" init; \
		if [ -n "$(r)" ]; then \
			if git -C "$(p)" remote | grep origin >/dev/null 2>&1; then \
				echo "Remote origin exists. Updating URL to '$(r)'..."; \
				git -C "$(p)" remote set-url origin "$(r)"; \
			else \
				echo "Adding remote origin '$(r)'..."; \
				git -C "$(p)" remote add origin "$(r)"; \
			fi; \
		else \
			echo "No remote URL provided."; \
		fi; \
		if [ -n "$(b)" ]; then \
			echo "Creating/Switching to branch '$(b)'..."; \
			if git -C "$(p)" show-ref --verify --quiet refs/heads/$(b); then \
				git -C "$(p)" checkout $(b); \
			else \
				git -C "$(p)" checkout -b $(b); \
			fi; \
		else \
			echo "No branch specified."; \
		fi; \
	fi; \
	echo "Git build completed in folder '$(p)'."

branch:
	@REPO=$(p); \
	if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Please provide a branch name: make branch branch-name"; \
		exit 1; \
	fi; \
	BRANCH="$(filter-out $@,$(MAKECMDGOALS))"; \
	if [ ! -d "$$REPO/.git" ]; then \
		echo "'$$REPO' is not a Git repository."; exit 1; \
	fi; \
	if git -C $$REPO rev-parse --verify $$BRANCH >/dev/null 2>&1; then \
		echo "Switching to existing local branch '$$BRANCH' in '$$REPO'..."; \
		git -C $$REPO checkout $$BRANCH; \
	elif git -C $$REPO ls-remote --exit-code --heads origin $$BRANCH >/dev/null 2>&1; then \
		echo "Creating local branch '$$BRANCH' from origin/$$BRANCH in '$$REPO'..."; \
		git -C $$REPO checkout -b $$BRANCH origin/$$BRANCH; \
	else \
		echo "Creating new local branch '$$BRANCH' in '$$REPO'..."; \
		git -C $$REPO checkout -b $$BRANCH; \
	fi

push:
	@if [ ! -d "$(p)/.git" ]; then \
		echo "This is not a Git repository: $(p)"; exit 1; \
	fi; \
	if [ -z "$$(git -C $(p) status --porcelain)" ]; then \
		echo "No changes to commit."; exit 0; \
	fi; \
	echo "Adding and committing with message: $(MESSAGE)"; \
	git -C $(p) add .; \
	if ! git -C $(p) commit -m "$$(printf '%s' '$(MESSAGE)')"; then \
		echo "Commit failed. Please check the error message above."; \
		exit 1; \
	fi; \
	BRANCH=$$(git -C $(p) branch --show-current); \
	echo "Checking if remote 'origin' is configured..."; \
	if ! git -C $(p) remote get-url origin >/dev/null 2>&1; then \
		echo "Remote 'origin' is not configured."; \
		echo "Please enter the remote repository URL (e.g., https://github.com/username/repo.git):"; \
		read remote_url; \
		if [ -z "$$remote_url" ]; then \
			echo "No URL provided. Your changes have been committed locally."; \
			echo "You can set a remote URL later with: make remote r=https://your-repo-url.git"; \
			exit 0; \
		fi; \
		echo "Adding remote 'origin' with URL '$$remote_url'..."; \
		if git -C $(p) remote add origin "$$remote_url"; then \
			echo "Remote 'origin' configured successfully."; \
		else \
			echo "Failed to add remote. Your changes have been committed locally."; \
			echo "You can set a remote URL later with: make remote r=https://your-repo-url.git"; \
			exit 0; \
		fi; \
	fi; \
	echo "Pushing to origin/$$BRANCH..."; \
	push_output=$$(git -C $(p) push -u origin $$BRANCH 2>&1); \
	push_status=$$?; \
	echo "$$push_output"; \
	if [ $$push_status -ne 0 ]; then \
		if echo "$$push_output" | grep -q "rejected"; then \
			if echo "$$push_output" | grep -q "fetch first"; then \
				echo "Push rejected: The remote repository contains work that you don't have locally."; \
				echo "Do you want to:"; \
				echo "  1) Pull remote changes and merge with your local changes"; \
				echo "  2) Force push your changes (overwrite remote changes - USE WITH CAUTION!)"; \
				echo "  3) Cancel push operation"; \
				read choice; \
				case $$choice in \
					1) \
						echo "Pulling remote changes..."; \
						if git -C $(p) pull --rebase origin $$BRANCH; then \
							echo "Pull successful. Pushing changes..."; \
							push_output=$$(git -C $(p) push -u origin $$BRANCH 2>&1); \
							push_status=$$?; \
							echo "$$push_output"; \
							if [ $$push_status -eq 0 ]; then \
								echo "Changes pushed successfully to origin/$$BRANCH."; \
								echo "Verifying branch on remote..."; \
								if git -C $(p) ls-remote --exit-code --heads origin $$BRANCH >/dev/null 2>&1; then \
									echo "Branch '$$BRANCH' confirmed on remote."; \
								else \
									echo "Warning: Branch may not have been pushed correctly."; \
								fi; \
							else \
								echo "Push failed after pull. Your changes are committed locally."; \
								echo "You may need to resolve conflicts manually."; \
							fi; \
						else \
							echo "Pull failed. You may have conflicts to resolve."; \
							echo "After resolving conflicts, run 'make push' again."; \
						fi; \
						;; \
					2) \
						echo "WARNING: Force pushing will OVERWRITE remote changes!"; \
						echo "Are you absolutely sure? (o/n)"; \
						read confirm; \
						if [ "$$confirm" = "o" ] || [ "$$confirm" = "O" ] || [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
							echo "Force pushing to origin/$$BRANCH..."; \
							push_output=$$(git -C $(p) push -f -u origin $$BRANCH 2>&1); \
							push_status=$$?; \
							echo "$$push_output"; \
							if [ $$push_status -eq 0 ]; then \
								echo "Changes force pushed successfully to origin/$$BRANCH."; \
								echo "Verifying branch on remote..."; \
								if git -C $(p) ls-remote --exit-code --heads origin $$BRANCH >/dev/null 2>&1; then \
									echo "Branch '$$BRANCH' confirmed on remote."; \
								else \
									echo "Warning: Branch may not have been pushed correctly."; \
								fi; \
							else \
								echo "Force push failed. This could be due to repository permissions."; \
								echo "Your changes are committed locally."; \
							fi; \
						else \
							echo "Force push canceled. Your changes are committed locally."; \
						fi; \
						;; \
					*) \
						echo "Push canceled. Your changes are committed locally."; \
						;; \
				esac; \
			else \
				echo "Push failed. The branch '$$BRANCH' may not exist on the remote repository."; \
				echo "Do you want to create it on the remote? (o/n)"; \
				read answer; \
				if [ "$$answer" = "o" ] || [ "$$answer" = "O" ] || [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
					echo "Creating branch '$$BRANCH' on remote and pushing..."; \
					push_output=$$(git -C $(p) push --set-upstream origin $$BRANCH 2>&1); \
					push_status=$$?; \
					echo "$$push_output"; \
					if [ $$push_status -eq 0 ]; then \
						echo "Branch '$$BRANCH' created on remote and changes pushed successfully."; \
						echo "Verifying branch on remote..."; \
						if git -C $(p) ls-remote --exit-code --heads origin $$BRANCH >/dev/null 2>&1; then \
							echo "Branch '$$BRANCH' confirmed on remote."; \
						else \
							echo "Warning: Branch may not have been pushed correctly."; \
						fi; \
					else \
						echo "Failed to create branch on remote."; \
						echo "This could be due to authentication issues or repository permissions."; \
						echo "Your changes have been committed locally."; \
					fi; \
				else \
					echo "Push canceled. Your changes are committed locally but not pushed to remote."; \
				fi; \
			fi; \
		else \
			echo "Push failed with an unknown error. Your changes are committed locally."; \
		fi; \
	else \
		if echo "$$push_output" | grep -q "Everything up-to-date"; then \
			echo "Everything is already up-to-date. No changes to push."; \
		else \
			echo "Changes pushed successfully to origin/$$BRANCH."; \
			echo "Verifying branch on remote..."; \
			if git -C $(p) ls-remote --exit-code --heads origin $$BRANCH >/dev/null 2>&1; then \
				echo "Branch '$$BRANCH' confirmed on remote."; \
			else \
				echo "Warning: Branch may not have been pushed correctly."; \
			fi; \
		fi; \
	fi


remote:
	@if [ ! -d "$(p)/.git" ]; then \
		echo "This is not a Git repository: $(p)"; exit 1; \
	fi; \
	if [ -z "$(r)" ]; then \
		echo "Please provide a remote URL with r=https://..."; \
		echo "Example: make remote r=https://github.com/username/repo.git"; \
		exit 1; \
	fi; \
	if git -C $(p) remote | grep origin >/dev/null 2>&1; then \
		echo "Remote 'origin' exists. Updating URL to '$(r)'..."; \
		git -C $(p) remote set-url origin "$(r)"; \
	else \
		echo "Adding remote 'origin' with URL '$(r)'..."; \
		git -C $(p) remote add origin "$(r)"; \
	fi; \
	echo "Remote 'origin' configured successfully."; \
	echo "Current remotes:"; \
	git -C $(p) remote -v

update:
	@if [ ! -d "$(p)/.git" ]; then echo "'$(p)' is not a Git repo."; exit 1; fi; \
	BRANCH=$$(git -C $(p) branch --show-current); \
	echo "Checking for uncommitted changes..."; \
	if [ -n "$$(git -C $(p) status --porcelain)" ]; then \
		echo "You have uncommitted changes. Choose an option:"; \
		echo "  1) Commit changes before pulling"; \
		echo "  2) Stash changes, pull, then reapply changes"; \
		echo "  3) Cancel update operation"; \
		read choice; \
		case $$choice in \
			1) \
				if [ -z "$(m)" ]; then \
					echo "Please enter a commit message:"; \
					read commit_msg; \
					if [ -z "$$commit_msg" ]; then \
						commit_msg="$(DEFAULT_MESSAGE)"; \
					fi; \
				else \
					commit_msg="$(m)"; \
				fi; \
				echo "Committing changes with message: $$commit_msg"; \
				git -C $(p) add .; \
				if ! git -C $(p) commit -m "$$commit_msg"; then \
					echo "Commit failed. Update canceled."; \
					exit 1; \
				fi; \
				;; \
			2) \
				echo "Stashing changes..."; \
				git -C $(p) stash; \
				echo "Pulling latest changes from origin/$$BRANCH in folder '$(p)'..."; \
				if git -C $(p) pull origin $$BRANCH; then \
					echo "Pull successful. Reapplying your changes..."; \
					if ! git -C $(p) stash pop; then \
						echo "Warning: Conflicts occurred when reapplying your changes."; \
						echo "Please resolve conflicts manually."; \
						exit 1; \
					fi; \
					echo "Changes reapplied successfully."; \
				else \
					echo "Pull failed. Your changes are still in stash."; \
					echo "You can apply them with: git -C $(p) stash pop"; \
					exit 1; \
				fi; \
				;; \
			*) \
				echo "Update canceled."; \
				exit 0; \
				;; \
		esac; \
	else \
		echo "Pulling latest changes from origin/$$BRANCH in folder '$(p)'..."; \
		git -C $(p) pull origin $$BRANCH; \
	fi

status:
	@if [ ! -d "$(p)/.git" ]; then \
		echo "'$(p)' is not a Git repo."; \
		exit 1; \
	fi; \
	echo "======================="; \
	echo "Git Status & Branches in '$(p)':"; \
	echo "======================="; \
	git -C $(p) status; \
	echo; \
	CURRENT_BRANCH=$$(git -C $(p) branch --show-current); \
	echo "Current branch: $$CURRENT_BRANCH"; \
	echo; \
	echo "Local branches:"; \
	git -C $(p) branch; \
	echo; \
	if git -C $(p) remote -v >/dev/null 2>&1; then \
		echo "Remote repositories:"; \
		git -C $(p) remote -v | awk '!seen[$$1]++' | sed 's/\t/ -> /'; \
		echo; \
		if [ -n "$$CURRENT_BRANCH" ]; then \
			echo "Remote tracking information for current branch:"; \
			REMOTE_BRANCH=$$(git -C $(p) for-each-ref --format='%(upstream:short)' $$(git -C $(p) symbolic-ref -q HEAD)); \
			if [ -n "$$REMOTE_BRANCH" ]; then \
				echo "$$CURRENT_BRANCH is tracking $$REMOTE_BRANCH"; \
				AHEAD=$$(git -C $(p) rev-list --count $$REMOTE_BRANCH..$$CURRENT_BRANCH); \
				BEHIND=$$(git -C $(p) rev-list --count $$CURRENT_BRANCH..$$REMOTE_BRANCH); \
				if [ "$$AHEAD" -gt 0 ] && [ "$$BEHIND" -gt 0 ]; then \
					echo "Your branch is ahead by $$AHEAD commit(s) and behind by $$BEHIND commit(s)"; \
				elif [ "$$AHEAD" -gt 0 ]; then \
					echo "Your branch is ahead by $$AHEAD commit(s)"; \
				elif [ "$$BEHIND" -gt 0 ]; then \
					echo "Your branch is behind by $$BEHIND commit(s)"; \
				else \
					echo "Your branch is up to date with $$REMOTE_BRANCH"; \
				fi; \
			else \
				echo "$$CURRENT_BRANCH is not tracking any remote branch"; \
			fi; \
		fi; \
	else \
		echo "No remote repositories configured"; \
	fi


clean:
	@if [ -d "$(p)" ]; then \
		echo "Caution: This command will delete the folder '$(p)'."; \
		echo "Are you sure you want to continue? (o/n)"; \
		read answer; \
		if [ "$$answer" = "o" ] || [ "$$answer" = "O" ] || [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
			echo "Deleting folder '$(p)'..."; \
			rm -rf "$(p)"; \
			echo "Folder '$(p)' deleted."; \
		else \
			echo "Operation canceled."; \
		fi; \
	else \
		echo "Folder '$(p)' does not exist."; \
	fi

%:
	@:
