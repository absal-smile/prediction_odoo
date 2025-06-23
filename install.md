# Installation de Make sur Windows 11 avec PowerShell

Pour installer Make sur Windows 11 via PowerShell, vous avez plusieurs options. Je vais vous présenter les méthodes les plus courantes :

## Option 1 : Installer Make via Chocolatey

Chocolatey est un gestionnaire de paquets pour Windows. C'est probablement la méthode la plus simple.

1. D'abord, installez Chocolatey si vous ne l'avez pas déjà :

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

2. Ensuite, installez Make avec Chocolatey :

```powershell
choco install make
```

## Option 2 : Installer via MSYS2

MSYS2 fournit un environnement Unix-like sur Windows.

1. Téléchargez et installez MSYS2 depuis [https://www.msys2.org/](https://www.msys2.org/)

2. Ouvrez le terminal MSYS2 et exécutez :

```bash
pacman -S make
```

3. Ajoutez le chemin de MSYS2 à votre PATH Windows pour utiliser make depuis PowerShell.

## Option 3 : Installer via Windows Subsystem for Linux (WSL)

Si vous avez WSL installé :

1. Installez WSL si ce n'est pas déjà fait :

```powershell
wsl --install
```

2. Ouvrez votre distribution Linux (Ubuntu par défaut) et installez make :

```bash
sudo apt update
sudo apt install make
```

## Option 4 : Installer GnuWin32

1. Téléchargez Make depuis GnuWin32 : [http://gnuwin32.sourceforge.net/packages/make.htm](http://gnuwin32.sourceforge.net/packages/make.htm)

2. Installez-le et ajoutez son chemin à votre variable PATH.

## Vérification de l'installation

Après l'installation, vérifiez que make est correctement installé en exécutant :

```powershell
make --version
```

Si vous voyez la version de Make, l'installation a réussi.
