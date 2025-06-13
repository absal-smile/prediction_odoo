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

## 3. Modifications pour l'API Balance Client

### 3.1 Fonctions conservées sans modification
- `_get_account_auth` : Récupère les identifiants d'authentification
- `_get_client_balance_environment` : Récupère l'environnement configuré
- `_import_balance_client` : Méthode du modèle res.partner qui met à jour tous les soldes
- Cron quotidien : Conservé pour maintenir la mise à jour automatique des soldes

### 3.2 Fonctions à supprimer
- `_get_client` : Crée un client SOAP (remplacée par une construction d'URL REST)

### 3.3 Nouvelles fonctions
- `_build_balance_url` : Construit l'URL REST pour l'API de solde client

### 3.4 Fonction principale modifiée
- `get_balance_client` : Fonction principale qui récupère le solde
  - Remplace l'appel SOAP par une requête HTTP GET
  - Ajoute un timeout explicite pour éviter les blocages
  - Vérifie le code de statut HTTP
  - Parse la réponse JSON avec gestion des erreurs
  - Améliore le logging pour faciliter le diagnostic

### 3.5 Paramètres de configuration
- Nouveau paramètre : `loomis_partner.client_balance_api_base_url`
- Paramètres conservés :
  - `loomis_partner.client_balance_environment`
  - `loomis_partner.client_balance_username`
  - `loomis_partner.client_balance_password`

## 4. Modifications pour l'API Reuters

### 4.1 Fonctions conservées sans modification
- `_get_currency_code` : Extrait le code de devise
- `_get_fake_sale_rate` : Récupère un taux prédéfini (fallback)
- `FAKE_RATES` : Constante contenant des taux prédéfinis

### 4.2 Fonctions à supprimer
- `_get_wsdl_client` : Crée un client SOAP
- `_get_sale_rate` : Appelle la méthode SOAP `GetCoursChangeReuters`

### 4.3 Nouvelles fonctions
- `_build_rate_url` : Construit l'URL REST pour l'API de taux de change
- `_get_rate_from_api` : Récupère le taux depuis l'API REST
- `get_reuters_rate` : Méthode du modèle res.currency pour récupérer un taux en temps réel
- `get_reuters_rates_data` : Méthode du modèle res.currency pour générer les données de taux

### 4.4 Fonction principale modifiée
- `get_course_change_reuters` : Fonction principale qui récupère le taux de change
  - Conserve la logique de vérification des devises identiques et du fallback
  - Remplace l'appel SOAP par une requête HTTP GET
  - Améliore la gestion des erreurs et le logging

### 4.5 Méthodes modifiées dans les modèles
- `_onchange_currency_reuters_rate_serialized` (modèle sale.order) :
  - Utilise la nouvelle méthode `get_reuters_rates_data` pour obtenir les taux
  - Conserve la logique de fusion des taux existants et nouveaux
  - Améliore la gestion des erreurs lors du parsing JSON

- `_compute_reuters_rate` (modèle sale.order.line) :
  - Conserve la logique de récupération des taux depuis les données sérialisées
  - Ajoute une récupération en temps réel si le taux n'est pas trouvé dans les données sérialisées
  - Améliore la gestion des erreurs lors du parsing JSON

### 4.6 Paramètres de configuration
- Nouveau paramètre : `loomis_sale.reuters_rate_api_base_url`
- Paramètres conservés :
  - `loomis_sale.global_threshold_margin`
  - `loomis_sale.rate_volatility_percentage`

## 5. Nouveaux paramètres de configuration

| Ancien paramètre | Nouveau paramètre | Description |
|------------------|-------------------|-------------|
| `loomis_partner.client_balance_api` | `loomis_partner.client_balance_api_base_url` | URL de base de l'API Balance Client |
| `loomis_sale.reuters_rate_api` | `loomis_sale.reuters_rate_api_base_url` | URL de base de l'API Reuters |

### Valeurs suggérées
- Environnement UAT : `https://uat-apps.cprb.fr/crow.api`
- Environnement Production : `https://apps.cprb.fr/crow.api`

## 6. Améliorations apportées

### 6.1 Performance
- Réduction de la taille des messages échangés
- Diminution du temps de traitement
- Récupération plus efficace des données

### 6.2 Maintenance
- Code plus simple et plus lisible
- Réduction des dépendances externes
- Meilleure gestion des erreurs
- Logs plus détaillés pour faciliter le diagnostic

### 6.3 Sécurité
- Conservation de l'authentification NTLM pour l'API Balance Client
- Timeouts explicites pour éviter les blocages
- Vérification des codes de statut HTTP

## 7. Conclusion

Cette migration des APIs SOAP vers REST apporte de nombreux avantages :

1. **Modernisation** : Alignement sur les standards actuels d'API
2. **Simplification** : Architecture plus légère et plus facile à maintenir
3. **Performance** : Réduction des temps de traitement et de la charge serveur
4. **Fiabilité** : Meilleure gestion des erreurs et des cas limites

Pour l'API Balance Client, nous conservons le cron quotidien et la méthode `_import_balance_client` pour maintenir la compatibilité avec les processus existants, tout en améliorant l'implémentation sous-jacente.

Pour l'API Reuters, nous conservons le mécanisme de fallback avec `FAKE_RATES` pour assurer la continuité du service en cas d'indisponibilité de l'API. Les méthodes `_onchange_currency_reuters_rate_serialized` et `_compute_reuters_rate` ont été adaptées pour utiliser la nouvelle API REST tout en maintenant la compatibilité avec les processus existants.

Cette évolution s'inscrit dans notre stratégie globale de modernisation des systèmes d'information et prépare le terrain pour de futures améliorations.
