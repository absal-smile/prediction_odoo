.PHONY: help buildwin branch push update status clean remote

p ?= smile-addons
m ?=
DEFAULT_MESSAGE ?= "Automatic commit from Makefile"
MESSAGE ?= $(if $(m),$(m),$(DEFAULT_MESSAGE))
REPO_URL ?=
BRANCH ?=

SHELL := pwsh
.SHELLFLAGS := -Command

help:
	Write-Host ""
	Write-Host "Simple Git Commands (via Makefile)" -ForegroundColor Cyan
	Write-Host "========================================="
	Write-Host "Usage:" -ForegroundColor Yellow
	Write-Host "  make buildwin c=https://... [b=dev]" -ForegroundColor Green
	Write-Host "      → Clone repo into 'smile-addons' (or p=...) and checkout branch"
	Write-Host ""
	Write-Host "  make build r=https://... b=main" -ForegroundColor Green
	Write-Host "      → Init repo in 'smile-addons' (or p=...), set remote, create/switch to branch"
	Write-Host ""
	Write-Host "  make branch branch-name" -ForegroundColor Green
	Write-Host "      → Create or switch to branch 'branch-name' in folder 'smile-addons'"
	Write-Host ""
	Write-Host "  make push [m=\""commit msg\""]" -ForegroundColor Green
	Write-Host "      → Commit all changes and push with message"
	Write-Host ""
	Write-Host "  make remote r=https://..." -ForegroundColor Green
	Write-Host "      → Set or update remote origin URL"
	Write-Host ""
	Write-Host "  make status" -ForegroundColor Green
	Write-Host "      → Show Git status in folder 'smile-addons'"
	Write-Host ""
	Write-Host "  make update" -ForegroundColor Green
	Write-Host "      → Pull latest changes in folder 'smile-addons'"
	Write-Host ""
	Write-Host "  make clean" -ForegroundColor Green
	Write-Host "      → Remove the 'smile-addons' folder (or p=...) to start fresh"

buildwin:
	Write-Host "Checking if Git is installed..."
	if (!(Get-Command git -ErrorAction SilentlyContinue)) {
	    Write-Host "Git is not installed. Installing Git..." -ForegroundColor Yellow
	    try {
	        # Vérifier si winget est disponible (Windows 10/11)
	        if (Get-Command winget -ErrorAction SilentlyContinue) {
	            Write-Host "Installing Git using winget..."
	            winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
	        }
	        # Vérifier si chocolatey est disponible
	        elseif (Get-Command choco -ErrorAction SilentlyContinue) {
	            Write-Host "Installing Git using Chocolatey..."
	            choco install git -y
	        }
	        # Vérifier si scoop est disponible
	        elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
	            Write-Host "Installing Git using Scoop..."
	            scoop install git
	        }
	        else {
	            Write-Host "No package manager found. Please install Git manually:" -ForegroundColor Red
	            Write-Host "1. Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
	            Write-Host "2. Or install a package manager like winget, chocolatey, or scoop" -ForegroundColor Yellow
	            exit 1
	        }

	        Write-Host "Verifying Git installation..."
	        Start-Sleep -Seconds 3
	        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
	        
	        if (Get-Command git -ErrorAction SilentlyContinue) {
	            Write-Host "Git installed successfully!" -ForegroundColor Green
	        } else {
	            Write-Host "Git installation may have failed. Please restart your terminal and try again." -ForegroundColor Red
	            Write-Host "Or install Git manually from: https://git-scm.com/download/win" -ForegroundColor Yellow
	            exit 1
	        }
	    } catch {
	        Write-Host "Failed to install Git automatically. Error: $($_.Exception.Message)" -ForegroundColor Red
	        Write-Host "Please install Git manually from: https://git-scm.com/download/win" -ForegroundColor Yellow
	        exit 1
	    }
	} else {
	    Write-Host "Git is already installed." -ForegroundColor Green
	}

	Write-Host "Checking Git global user config..."
	try {
	    $userName = git config --global user.name 2>$null
	    $userEmail = git config --global user.email 2>$null
	    if (-not $userName -or -not $userEmail) {
	        if (-not $userName) {
	            $userName = Read-Host "Please enter your Git user.name"
	            git config --global user.name "$userName"
	        }
	        if (-not $userEmail) {
	            $userEmail = Read-Host "Please enter your Git user.email"
	            git config --global user.email "$userEmail"
	        }
	    } else {
	        Write-Host "Git user.name is set to '$userName'"
	        Write-Host "Git user.email is set to '$userEmail'"
	    }
	
	} catch {
		Write-Host "Error configuring Git user settings" -ForegroundColor Red
		exit 1
	}
	if ("$(c)") {
		if (Test-Path "$(p)/.git") {
			Write-Host "Folder '$(p)' is already a Git repo."
			$$currentBranch = git -C $(p) branch --show-current
			if ("$(b)") {
				if ($$currentBranch -eq "$(b)") {
					git -C $(p) pull
				} else {
					if (git -C $(p) show-ref --verify --quiet refs/heads/$(b)) {
						git -C $(p) checkout $(b)
						git -C $(p) pull origin $(b)
					} else {
						if (git -C $(p) ls-remote --exit-code origin $(b)) {
							git -C $(p) fetch origin $(b)
							git -C $(p) checkout -b $(b) origin/$(b)
						} else {
							git -C $(p) checkout -b $(b)
						}
					}
				}
			}
		} elseif (Test-Path "$(p)") {
			$$answer = Read-Host "Folder exists but not a repo. Delete? (y/n)"
			if ($$answer -in @("y", "Y")) {
				Remove-Item -Recurse -Force "$(p)"
				if ("$(b)") {
					git clone --branch "$(b)" "$(c)" "$(p)"
				} else {
					git clone "$(c)" "$(p)"
				}
			} else {
				Write-Host "Operation canceled."
				exit 1
			}
		} else {
			if ("$(b)") {
				git clone --branch "$(b)" "$(c)" "$(p)"
			} else {
				git clone "$(c)" "$(p)"
			}
		}
	} else {
		if (!(Test-Path "$(p)")) {
			New-Item -ItemType Directory -Path "$(p)" -Force | Out-Null
		}
		git -C $(p) init
		if ("$(r)") {
			if (git -C $(p) remote | Select-String "origin") {
				git -C $(p) remote set-url origin "$(r)"
			} else {
				git -C $(p) remote add origin "$(r)"
			}
		}
		if ("$(b)") {
			if (git -C $(p) show-ref --verify --quiet refs/heads/$(b)) {
				git -C $(p) checkout $(b)
			} else {
				git -C $(p) checkout -b $(b)
			}
		}
	}
	Write-Host "Git build completed in folder '$(p)'" -ForegroundColor Green

branch:
	$$branchName = "$(filter-out $@,$(MAKECMDGOALS))"
	if (-not $$branchName) {
		Write-Host "Please provide a branch name: make branch branch-name" -ForegroundColor Red
		exit 1
	}
	if (!(Test-Path "$(p)/.git")) {
		Write-Host "'$(p)' is not a Git repository." -ForegroundColor Red
		exit 1
	}
	if (git -C $(p) rev-parse --verify $$branchName 2>$$null) {
		git -C $(p) checkout $$branchName
	} elseif (git -C $(p) ls-remote --exit-code --heads origin $$branchName 2>$$null) {
		git -C $(p) checkout -b $$branchName origin/$$branchName
	} else {
		git -C $(p) checkout -b $$branchName
	}

push:
	if (!(Test-Path "$(p)/.git")) {
		Write-Host "This is not a Git repository: $(p)" -ForegroundColor Red
		exit 1
	}
	$$hasChanges = git -C $(p) status --porcelain
	if (-not $$hasChanges) {
		Write-Host "No changes to commit." -ForegroundColor Yellow
		exit 0
	}
	Write-Host "Adding and committing with message: $(MESSAGE)"
	git -C $(p) add .
	try {
		git -C $(p) commit -m "$(MESSAGE)"
	} catch {
		Write-Host "Commit failed. Please check the error message above." -ForegroundColor Red
		exit 1
	}
	$$currentBranch = git -C $(p) branch --show-current
	Write-Host "Checking if remote 'origin' is configured..."
	try {
		git -C $(p) remote get-url origin | Out-Null
	} catch {
		Write-Host "Remote 'origin' is not configured." -ForegroundColor Yellow
		$$remoteUrl = Read-Host "Please enter the remote repository URL (e.g., https://github.com/username/repo.git)"
		if (-not $$remoteUrl) {
			Write-Host "No URL provided. Your changes have been committed locally."
			Write-Host "You can set a remote URL later with: make remote r=https://your-repo-url.git"
			exit 0
		}
		Write-Host "Adding remote 'origin' with URL '$$remoteUrl'..."
		try {
			git -C $(p) remote add origin $$remoteUrl
		} catch {
			Write-Host "Failed to add remote. Your changes have been committed locally."
			Write-Host "You can set a remote URL later with: make remote r=https://your-repo-url.git"
			exit 0
		}
	}
	Write-Host "Pushing to origin/$$currentBranch..."
	try {
		git -C $(p) push -u origin $$currentBranch
		Write-Host "Changes pushed successfully to origin/$$currentBranch." -ForegroundColor Green
	} catch {
		Write-Host "Push failed. Checking for common issues..." -ForegroundColor Yellow
		$$choice = Read-Host "Do you want to: `n1) Pull remote changes and merge`n2) Force push (CAUTION!)`n3) Cancel`nChoose [1/2/3]"
		switch ($$choice) {
			"1" {
				Write-Host "Pulling remote changes..."
				git -C $(p) pull --rebase origin $$currentBranch
				Write-Host "Pushing changes..."
				git -C $(p) push -u origin $$currentBranch
			}
			"2" {
				$$confirm = Read-Host "WARNING: Force pushing will OVERWRITE remote changes! Are you sure? [y/n]"
				if ($$confirm -eq "y") {
					git -C $(p) push -f -u origin $$currentBranch
				} else {
					Write-Host "Force push canceled."
				}
			}
			Default {
				Write-Host "Push canceled. Your changes are committed locally."
			}
		}
	}

remote:
	if (!(Test-Path "$(p)/.git")) {
		Write-Host "This is not a Git repository: $(p)" -ForegroundColor Red
		exit 1
	}
	if (-not "$(r)") {
		Write-Host "Please provide a remote URL with r=https://..." -ForegroundColor Red
		Write-Host "Example: make remote r=https://github.com/username/repo.git"
		exit 1
	}
	if (git -C $(p) remote | Select-String -Pattern "origin") {
		Write-Host "Remote 'origin' exists. Updating URL to '$(r)'..."
		git -C $(p) remote set-url origin "$(r)"
	} else {
		Write-Host "Adding remote 'origin' with URL '$(r)'..."
		git -C $(p) remote add origin "$(r)"
	}
	Write-Host "Remote 'origin' configured successfully." -ForegroundColor Green
	Write-Host "Current remotes:"
	git -C $(p) remote -v



update:
	if (!(Test-Path "$(p)/.git")) {
		Write-Host "'$(p)' is not a Git repo." -ForegroundColor Red
		exit 1
	}
	$$currentBranch = git -C $(p) branch --show-current
	Write-Host "Checking for uncommitted changes..."
	$$hasChanges = git -C $(p) status --porcelain
	if ($$hasChanges) {
		Write-Host "You have uncommitted changes. Choose an option:"
		Write-Host "  1) Commit changes before pulling"
		Write-Host "  2) Stash changes, pull, then reapply changes"
		Write-Host "  3) Cancel update operation"
		$$choice = Read-Host "Enter choice (1/2/3)"
		switch ($$choice) {
			"1" {
				if (-not "$(m)") {
					$$commitMsg = Read-Host "Please enter a commit message"
					if (-not $$commitMsg) { $$commitMsg = "$(DEFAULT_MESSAGE)" }
				} else {
					$$commitMsg = "$(m)"
				}
				Write-Host "Committing changes with message: $$commitMsg"
				git -C $(p) add .
				try {
					git -C $(p) commit -m "$$commitMsg"
				} catch {
					Write-Host "Commit failed. Update canceled." -ForegroundColor Red
					exit 1
				}
			}
			"2" {
				Write-Host "Stashing changes..."
				git -C $(p) stash
				Write-Host "Pulling latest changes from origin/$$currentBranch in folder '$(p)'..."
				try {
					git -C $(p) pull origin $$currentBranch
					Write-Host "Pull successful. Reapplying your changes..."
					git -C $(p) stash pop
					Write-Host "Changes reapplied successfully." -ForegroundColor Green
				} catch {
					Write-Host "Pull failed or conflicts occurred. Your changes are still in stash." -ForegroundColor Red
					Write-Host "You can apply them with: git -C $(p) stash pop"
					exit 1
				}
			}
			Default {
				Write-Host "Update canceled."
				exit 0
			}
		}
	} else {
		Write-Host "Pulling latest changes from origin/$$currentBranch in folder '$(p)'..."
		git -C $(p) pull origin $$currentBranch
	}

status:
	if (!(Test-Path "$(p)/.git")) {
		Write-Host "'$(p)' is not a Git repo." -ForegroundColor Red
		exit 1
	}
	Write-Host "======================="
	Write-Host "Git Status & Branches in '$(p)':" -ForegroundColor Cyan
	Write-Host "======================="
	git -C $(p) status
	Write-Host ""
	$$currentBranch = git -C $(p) branch --show-current
	Write-Host "Current branch: $$currentBranch" -ForegroundColor Yellow
	Write-Host ""
	Write-Host "Local branches:"
	git -C $(p) branch
	Write-Host ""
	$$remotes = git -C $(p) remote -v
	if ($$remotes) {
		Write-Host "Remote repositories:"
		$$remotes | Sort-Object -Unique | ForEach-Object { Write-Host $$_ }
		Write-Host ""
		if ($$currentBranch) {
			Write-Host "Remote tracking information for current branch:"
			$$remoteBranch = git -C $(p) for-each-ref --format='%(upstream:short)' $$(git -C $(p) symbolic-ref -q HEAD) 2>$$null
			if ($$remoteBranch) {
				Write-Host "$$currentBranch is tracking $$remoteBranch"
				$$ahead = git -C $(p) rev-list --count $$remoteBranch..$$currentBranch 2>$$null
				$$behind = git -C $(p) rev-list --count $$currentBranch..$$remoteBranch 2>$$null
				if ($$ahead -gt 0 -and $$behind -gt 0) {
					Write-Host "Your branch is ahead by $$ahead commit(s) and behind by $$behind commit(s)" -ForegroundColor Yellow
				} elseif ($$ahead -gt 0) {
					Write-Host "Your branch is ahead by $$ahead commit(s)" -ForegroundColor Green
				} elseif ($$behind -gt 0) {
					Write-Host "Your branch is behind by $$behind commit(s)" -ForegroundColor Red
				} else {
					Write-Host "Your branch is up to date with $$remoteBranch" -ForegroundColor Green
				}
			} else {
				Write-Host "$$currentBranch is not tracking any remote branch" -ForegroundColor Yellow
			}
		}
	} else {
		Write-Host "No remote repositories configured"
	}

clean:
	if (Test-Path "$(p)") {
		Write-Host "Caution: This command will delete the folder '$(p)'." -ForegroundColor Red
		$$answer = Read-Host "Are you sure you want to continue? (o/n)"
		if ($$answer -in @("o", "O", "y", "Y")) {
			Write-Host "Deleting folder '$(p)'..."
			Remove-Item -Recurse -Force "$(p)"
			Write-Host "Folder '$(p)' deleted." -ForegroundColor Green
		} else {
			Write-Host "Operation canceled."
		}
	} else {
		Write-Host "Folder '$(p)' does not exist." -ForegroundColor Yellow
	}

%:
	@:
