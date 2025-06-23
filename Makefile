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
