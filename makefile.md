# Documentation du Makefile pour la gestion Git

## Vue d'ensemble

Ce Makefile fournit une interface simplifiée pour les opérations Git courantes, permettant de gérer facilement un dépôt Git sans avoir à mémoriser les commandes Git complexes. Il est particulièrement utile pour les projets Odoo, avec une configuration par défaut ciblant un dossier nommé `smile-addons`.

## Prérequis

- Make installé sur votre système
- Accès à un terminal
- Droits sudo (pour l'installation automatique de Git si nécessaire)

## Commandes disponibles

Pour voir toutes les commandes disponibles, exécutez :

```bash
make help
```

### Initialisation et clonage

#### Cloner un dépôt existant

```bash
make build c=https://url-du-depot.git [b=nom-de-branche] [p=dossier-cible]
```

- `c=` : URL du dépôt à cloner (obligatoire)
- `b=` : Nom de la branche à extraire (optionnel, utilise la branche par défaut si non spécifié)
- `p=` : Dossier cible (optionnel, par défaut `smile-addons`)

#### Initialiser un nouveau dépôt

```bash
make build r=https://url-du-depot.git b=nom-de-branche [p=dossier-cible]
```

- `r=` : URL du dépôt distant à configurer
- `b=` : Nom de la branche à créer/utiliser
- `p=` : Dossier cible (optionnel, par défaut `smile-addons`)

### Gestion des branches

```bash
make branch nom-de-branche
```

Gère intelligemment la création ou le basculement vers une branche :

- Si la branche existe localement :
  - Bascule vers cette branche
  - Si une branche du même nom existe sur le dépôt distant, propose de :
    1. Garder la branche locale telle quelle
    2. Réinitialiser la branche locale pour qu'elle corresponde à la branche distante
    3. Tirer (pull) les changements de la branche distante

- Si la branche n'existe pas localement :
  - Si une branche du même nom existe sur le dépôt distant, crée une branche locale qui suit la branche distante
  - Sinon, crée une nouvelle branche locale et propose de la pousser vers le dépôt distant

Cette approche évite les problèmes de divergence entre branches locales et distantes.

### Gestion des modifications

#### Vérifier l'état du dépôt

```bash
make status [p=dossier-cible]
```

Affiche l'état actuel du dépôt Git, y compris les fichiers modifiés et la branche active.

#### Mettre à jour depuis le dépôt distant

```bash
make update [p=dossier-cible] [m="message de commit"]
```

Récupère les dernières modifications depuis le dépôt distant. Si vous avez des modifications locales, vous aurez la possibilité de :
1. Les commiter avant de mettre à jour
2. Les mettre de côté (stash), puis les réappliquer après la mise à jour
3. Annuler l'opération

#### Commiter et pousser les modifications

```bash
make push [m="message de commit"] [p=dossier-cible]
```

Ajoute, commite et pousse toutes les modifications vers le dépôt distant. Si aucun message n'est spécifié, utilise "Automatic commit from Makefile".

En cas de conflit lors du push, vous aurez plusieurs options :
1. Récupérer et fusionner les modifications distantes
2. Forcer le push (à utiliser avec précaution)
3. Annuler l'opération

### Configuration du dépôt

#### Configurer/modifier l'URL du dépôt distant

```bash
make remote r=https://url-du-depot.git [p=dossier-cible]
```

Configure ou met à jour l'URL du dépôt distant.

#### Nettoyer le dépôt local

```bash
make clean [p=dossier-cible]
```

Supprime complètement le dossier du dépôt local après confirmation.

## Paramètres communs

- `p=` : Spécifie le dossier cible (par défaut `smile-addons`)
- `m=` : Message de commit (par défaut "Automatic commit from Makefile")
- `r=` : URL du dépôt distant
- `b=` : Nom de la branche
- `c=` : URL du dépôt à cloner

## Exemples d'utilisation

### Démarrer un nouveau projet

```bash
# Cloner un dépôt existant dans le dossier smile-addons
make build c=https://git.smile.fr/absal/myproject.git b=main

# Initialiser un nouveau dépôt
make build r=https://git.smile.fr/absal/myproject.git b=main
```

### Workflow quotidien

```bash
# Vérifier l'état du dépôt
make status

# Récupérer les dernières modifications
make update

# Créer ou basculer vers une branche
make branch feature/nouvelle-fonctionnalite

# Après avoir effectué des modifications, les commiter et les pousser
make push m="Ajout de la nouvelle fonctionnalité"
```

### Travailler avec plusieurs projets

```bash
# Cloner un autre projet dans un dossier différent
make build c=https://git.smile.fr/autre-projet.git p=autre-projet

# Vérifier l'état de ce projet
make status p=autre-projet

# Pousser les modifications de ce projet
make push p=autre-projet m="Correction de bug"
```

### Gestion intelligente des branches

```bash
# Créer une nouvelle branche locale et la pousser vers le dépôt distant
make branch nouvelle-branche
# (Répondre "o" à la question pour pousser la branche)

# Basculer vers une branche existante sur le dépôt distant
make branch branche-distante
# (La branche locale sera automatiquement configurée pour suivre la branche distante)

# Mettre à jour une branche locale qui existe aussi sur le dépôt distant
make branch branche-existante
# (Choisir l'option 3 pour tirer les changements de la branche distante)
```

## Fonctionnalités avancées

- Installation automatique de Git si nécessaire
- Configuration automatique de l'identité Git (user.name et user.email) si non configurée
- Gestion intelligente des conflits lors des push/pull
- Vérification de la présence des branches sur le dépôt distant
- Options pour gérer les modifications non commitées lors des mises à jour
- Synchronisation intelligente des branches locales avec les branches distantes

## Notes importantes

- Utilisez `make clean` avec précaution car cette commande supprime complètement le dossier local
- La commande `make push` avec l'option de force push peut écraser les modifications distantes
- Si vous travaillez sur plusieurs projets, utilisez toujours le paramètre `p=` pour spécifier le dossier cible
- La commande `branch` vérifie maintenant automatiquement si une branche existe sur le dépôt distant pour éviter les divergences

Ce Makefile est conçu pour simplifier les opérations Git courantes tout en offrant des options avancées pour gérer les cas complexes, avec une attention particulière à la synchronisation correcte des branches locales et distantes.
