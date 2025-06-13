# Documentation technique : Migration des APIs SOAP vers REST

## 1. Contexte et objectifs

Dans le cadre de la modernisation de notre infrastructure, nous devons migrer deux APIs actuellement implémentées en SOAP vers des APIs REST :

1. **API Balance Client** : Utilisée pour récupérer les soldes des comptes clients
2. **API Reuters** : Utilisée pour récupérer les taux de change entre différentes devises

Cette migration vise à :
- Simplifier l'architecture technique
- Améliorer les performances
- Faciliter la maintenance
- Moderniser notre stack technologique

## 2. Analyse de l'existant

### API Balance Client
- Utilise actuellement le protocole SOAP avec authentification NTLM
- Les soldes sont récupérés via un cron quotidien qui met à jour les enregistrements
- Configuration via paramètres système

### API Reuters
- Utilise actuellement le protocole SOAP
- Les taux sont stockés dans des champs sérialisés
- Mise à jour périodique via un cron
- Mécanisme de fallback avec des taux prédéfinis

## 3. Fonctions modifiées et nouvelles fonctions

### 3.1 API Balance Client

#### Fonctions conservées sans modification
- `_get_account_auth` : Récupère les identifiants d'authentification
- `_get_client_balance_environment` : Récupère l'environnement configuré

#### Fonctions à supprimer
- `_get_client` : Crée un client SOAP (remplacée par une construction d'URL REST)

#### Fonctions modifiées
- `get_balance_client` : Fonction principale qui récupère le solde
  - **Avant** : Utilise un client SOAP pour appeler `GetSoldeCompteComptable`
  - **Après** : Utilise une requête HTTP GET vers l'API REST
  - **Pourquoi** : Simplification du code et alignement sur les standards modernes

#### Nouvelles fonctions
- `_build_balance_url` : Construit l'URL REST pour l'API de solde client
  - **Remplace** : La logique de création du client SOAP dans `_get_client`
  - **Pourquoi** : Nécessaire pour construire l'URL REST avec les paramètres appropriés

- `get_account_balance` (dans le modèle res.partner) : Récupère le solde à la demande
  - **Remplace** : La méthode `_import_balance_client` qui était appelée par le cron
  - **Pourquoi** : Passage d'un modèle périodique à un modèle à la demande

- `refresh_balance` (dans le modèle client.account) : Bouton pour rafraîchir le solde
  - **Nouvelle fonction** : N'existait pas dans l'ancienne implémentation
  - **Pourquoi** : Permet à l'utilisateur de mettre à jour manuellement le solde

### 3.2 API Reuters

#### Fonctions conservées sans modification
- `_get_currency_code` : Extrait le code de devise
- `_get_fake_sale_rate` : Récupère un taux prédéfini (fallback)
- `FAKE_RATES` : Constante contenant des taux prédéfinis

#### Fonctions à supprimer
- `_get_wsdl_client` : Crée un client SOAP (remplacée par une construction d'URL REST)
- `_get_sale_rate` : Appelle la méthode SOAP `GetCoursChangeReuters`

#### Fonctions modifiées
- `get_course_change_reuters` : Fonction principale qui récupère le taux de change
  - **Avant** : Utilise un client SOAP pour appeler `GetCoursChangeReuters`
  - **Après** : Utilise une requête HTTP GET vers l'API REST
  - **Pourquoi** : Simplification du code et alignement sur les standards modernes

- `_onchange_currency_reuters_rate_serialized` : Déclenché lors du changement de devise
  - **Avant** : Lit les taux depuis le champ sérialisé de la devise
  - **Après** : Récupère les taux en temps réel via l'API REST
  - **Pourquoi** : Les taux ne sont plus stockés mais récupérés à la demande

- `_compute_reuters_rate` : Calcule le taux pour une ligne de commande
  - **Avant** : Lit principalement depuis les données sérialisées
  - **Après** : Peut récupérer le taux en temps réel si non trouvé dans les données sérialisées
  - **Pourquoi** : Assure la disponibilité des taux même si non présents dans les données sérialisées

- `_get_default` : Initialise les valeurs par défaut d'une commande
  - **Avant** : Appelle `update_reuters_rate` pour mettre à jour les taux
  - **Après** : Appelle directement `_onchange_currency_reuters_rate_serialized`
  - **Pourquoi** : La méthode `update_reuters_rate` est supprimée

#### Nouvelles fonctions
- `_build_rate_url` : Construit l'URL REST pour l'API de taux de change
  - **Remplace** : La logique de création du client SOAP dans `_get_wsdl_client`
  - **Pourquoi** : Nécessaire pour construire l'URL REST avec les paramètres appropriés

- `_get_rate_from_api` : Récupère le taux depuis l'API REST
  - **Remplace** : La fonction `_get_sale_rate` qui utilisait SOAP
  - **Pourquoi** : Adaptation à l'API REST

- `get_reuters_rate` (dans le modèle res.currency) : Récupère un taux en temps réel
  - **Nouvelle fonction** : Permet d'obtenir un taux spécifique à la demande
  - **Pourquoi** : Remplace la logique de stockage des taux

- `get_reuters_rates_data` (dans le modèle res.currency) : Génère les données de taux
  - **Remplace** : Une partie de la logique de `update_reuters_rate`
  - **Pourquoi** : Nécessaire pour générer les données de taux à la demande

## 4. Éléments à supprimer

### API Balance Client
- Cron `ir_cron_balance_client`
- Fonction `_get_client` dans le module client_balance
- Méthode `_import_balance_client` dans le modèle res.partner
- Paramètre `loomis_partner.client_balance_api`

### API Reuters
- Cron `update_reuters_rate`
- Fonction `_get_wsdl_client` dans le module reuters
- Fonction `_get_sale_rate` dans le module reuters
- Méthode `update_reuters_rate` dans le modèle res.currency
- Champ `currency_reuters_rate_serialized` dans le modèle res.currency
- Paramètre `loomis_sale.reuters_rate_api`

## 5. Nouveaux paramètres de configuration

| Ancien paramètre | Nouveau paramètre | Description |
|------------------|-------------------|-------------|
| `loomis_partner.client_balance_api` | `loomis_partner.client_balance_api_base_url` | URL de base de l'API Balance Client |
| `loomis_sale.reuters_rate_api` | `loomis_sale.reuters_rate_api_base_url` | URL de base de l'API Reuters |




## 6. Conclusion

Cette migration des APIs SOAP vers REST apporte de nombreux avantages :

1. **Modernisation** : Alignement sur les standards actuels d'API
2. **Simplification** : Architecture plus légère et plus facile à maintenir
3. **Performance** : Réduction des temps de traitement et de la charge serveur
4. **Fiabilité** : Meilleure gestion des erreurs et des cas limites

L'approche progressive de déploiement minimise les risques tout en permettant une migration complète. La conservation temporaire des anciens mécanismes offre une possibilité de rollback rapide en cas de problème.

Cette évolution s'inscrit dans notre stratégie globale de modernisation des systèmes d'information et prépare le terrain pour de futures améliorations.
