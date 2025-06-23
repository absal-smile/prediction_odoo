# Git Automation Makefile

This Makefile provides simple commands to automate common Git operations such as cloning, branching, pushing, pulling, and cleaning up repositories.

---

## Prerequisites

### On Ubuntu/Linux

- **Git** and **Make** must be installed.
- Install them with:
  ```sh
  sudo apt update
  sudo apt install git make
  ```

### On Windows

- **Git Bash** is recommended for running this Makefile.
- **GNU Make** is required.

#### 1. Install Git Bash

- Download and install [Git for Windows](https://gitforwindows.org/).
- After installation, open **Git Bash** from the Start menu.

#### 2. Install GNU Make for Windows

- Download the latest `make` for Windows from [ezwinports](https://sourceforge.net/projects/ezwinports/files/).
- Extract the ZIP (e.g., `make-4.3-bin.zip`) to a folder like `C:\make`.
- Add this folder to your Windows `PATH` environment variable:
  - Open Start, search for "Environment Variables", and edit the `Path` variable to include `C:\make`.
- Restart Git Bash or your terminal.

#### 3. Verify Installation

In **Git Bash** or your terminal, run:
```sh
git --version
make --version
```
Both commands should print version information.

---

## Usage

Open a terminal (**Git Bash** on Windows, or any terminal on Linux) in the folder containing the `Makefile`.

Run:
```sh
make help
```
to see all available commands and usage examples.

### Common Commands

- **Clone a repository and checkout a branch:**
  ```sh
  make build c=https://github.com/username/repo.git b=main
  ```
- **Initialize a repo, set remote, and create/switch branch:**
  ```sh
  make build r=https://github.com/username/repo.git b=main
  ```
- **Switch or create a branch:**
  ```sh
  make branch branch-name
  ```
- **Commit and push all changes:**
  ```sh
  make push m="your commit message"
  ```
- **Set or update remote origin:**
  ```sh
  make remote r=https://github.com/username/repo.git
  ```
- **Show status:**
  ```sh
  make status
  ```
- **Pull latest changes:**
  ```sh
  make update
  ```
- **Delete the working folder:**
  ```sh
  make clean
  ```

---

## Notes

- On **Windows**, always use **Git Bash** (not PowerShell or CMD) for best compatibility.
- On **Linux**, you can use any terminal.
- If you get a "missing separator" error, make sure all Makefile command lines are indented with a **tab**, not spaces.
- If you encounter permission issues, try running your terminal as administrator (Windows) or with `sudo` (Linux).

---

## Troubleshooting

- **Git or Make not found:**  
  Make sure both are installed and available in your `PATH`.
- **Command not recognized:**  
  Use Git Bash on Windows, not PowerShell or CMD.
- **Other issues:**  
  Run `make help` for usage hints and check the Makefile comments.

---

Happy coding!
