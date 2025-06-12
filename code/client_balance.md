# Documentation technique : Migration SOAP vers REST pour l'API Balance Client

## 1. Contexte et objectifs

L'API Balance Client est utilisée pour récupérer les soldes des comptes clients. Actuellement implémentée avec le protocole SOAP et une authentification NTLM, cette API doit être migrée vers une architecture REST plus moderne, plus légère et plus facile à maintenir.

## 2. Analyse de l'existant

### Structure actuelle
Le module actuel utilise la bibliothèque `zeep` pour créer un client SOAP avec authentification NTLM qui appelle la méthode `GetSoldeCompteComptable` sur le service distant. La configuration est gérée via des paramètres système.

### Points forts à conserver
- La gestion des identifiants via paramètres système
- La configuration de l'environnement
- L'interface externe de la fonction principale
- Le flag d'activation/désactivation

## 3. Modifications techniques

### 3.1 Imports
**Avant :**
```python
import logging
from odoo.tools import config
from requests import Session
from requests_ntlm import HttpNtlmAuth
from odoo.tools.zeep import Client, Transport
```

**Après :**
```python
import logging
import requests
import base64
from odoo.tools import config
```

**Justification :** Remplacement des bibliothèques spécifiques à SOAP et NTLM par la bibliothèque HTTP standard `requests` et ajout de `base64` pour l'authentification.

### 3.2 Fonctions d'authentification et d'environnement

Ces fonctions sont conservées sans modification car leur logique reste valide :
- `_get_account_auth()` : Récupération des identifiants
- `_get_client_balance_environment()` : Récupération de l'environnement

### 3.3 Nouvelle fonction pour les en-têtes d'authentification

```python
def _get_auth_headers(env):
    """
    Crée les en-têtes d'authentification pour l'API REST.
    Remplace la logique d'authentification NTLM par des en-têtes HTTP standards.
    """
    username, password = _get_account_auth(env)
    
    # Option 1: Basic Auth
    auth_str = f"{username}:{password}"
    auth_bytes = auth_str.encode('ascii')
    auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
    return {
        "Authorization": f"Basic {auth_b64}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    # Option 2 (alternative): Bearer Token
    # token = _get_token(env, username, password)
    # return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
```

**Justification :** Cette nouvelle fonction transforme les identifiants en en-têtes HTTP appropriés pour l'API REST. Elle remplace la logique d'authentification NTLM qui était gérée par la bibliothèque zeep.

### 3.4 Fonction de création du client

**Avant :**
```python
def _get_client(env):
    wsdl = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_api")
    username, password = _get_account_auth(env)
    session = Session()
    session.auth = HttpNtlmAuth(username, password)
    transport = Transport(session=session)
    return Client(wsdl=wsdl, transport=transport)
```

**Après - Remplacée par :**
```python
def _build_balance_url(env, company, account, currency):
    """
    Construit l'URL REST pour l'API de solde client.
    Remplace la création du client SOAP par la construction d'une URL REST.
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/accounting/balance/{company}/{account}/{currency}"
```

**Justification :** Au lieu de créer un client SOAP basé sur un WSDL, nous construisons maintenant une URL REST qui pointe directement vers la ressource demandée (le solde d'un compte client).

### 3.5 Fonction principale

**Avant :**
```python
def get_balance_client(env, account, devise):
    response = 0
    if config.get('enable_import_client_balance'):
        client = _get_client(env)
        client_balance_environment = _get_client_balance_environment(env)
        try:
            response = client.service.GetSoldeCompteComptable(
                client_balance_environment, account, devise)
        except Exception:
            _logger.error("Error on API of import Balance client")
    return response
```

**Après :**
```python
def get_balance_client(env, account, devise):
    """
    Récupère le solde client via l'API REST.
    Conserve la même signature et comportement externe, mais utilise REST au lieu de SOAP.
    """
    response = 0
    if config.get('enable_import_client_balance'):
        headers = _get_auth_headers(env)
        company = _get_client_balance_environment(env)
        url = _build_balance_url(env, company, account, devise)
        
        try:
            api_response = requests.get(url, headers=headers, timeout=10)
            if api_response.status_code == 200:
                data = api_response.json()
                # Adapter selon la structure réelle de la réponse JSON
                response = data.get("balance", 0)
            else:
                _logger.error(f"Error on API of import Balance client: HTTP {api_response.status_code}")
                if api_response.text:
                    _logger.error(f"Response details: {api_response.text[:200]}")
        except Exception as e:
            _logger.error(f"Error on API of import Balance client: {str(e)}")
    
    return response
```

**Justification :** La fonction principale conserve la même signature et le même comportement externe, mais son implémentation interne change pour utiliser une requête HTTP GET au lieu d'un appel de méthode SOAP. Elle ajoute également :
- Un timeout explicite pour éviter les blocages
- Une vérification du code de statut HTTP
- Un parsing JSON avec gestion des erreurs
- Un logging amélioré pour faciliter le diagnostic

## 4. Configuration système

### Paramètres à modifier
| Paramètre actuel | Nouveau paramètre | Description |
|------------------|-------------------|-------------|
| `loomis_partner.client_balance_api` | `loomis_partner.client_balance_api_base_url` | URL de base de l'API REST |

### Paramètres conservés
- `loomis_partner.client_balance_username` : Nom d'utilisateur
- `loomis_partner.client_balance_password` : Mot de passe
- `loomis_partner.client_balance_environment` : Environnement (utilisé comme partie de l'URL)

### Valeurs suggérées
- Environnement UAT : `https://uat-apps.cprb.fr/crow.api`
- Environnement Production : `https://apps.cprb.fr/crow.api`

## 5. Considérations de déploiement

### Stratégie de migration
1. Déployer d'abord en environnement de test
2. Exécuter des tests parallèles (comparer les résultats des deux implémentations)
3. Surveiller les performances et les taux de réussite
4. Déployer en production avec une période de surveillance renforcée

### Risques et mitigations
- **Risque** : Différence dans les soldes retournés
  - **Mitigation** : Vérification préalable avec l'équipe API pour confirmer la structure des réponses

- **Risque** : Problèmes d'authentification
  - **Mitigation** : Tester différentes méthodes d'authentification (Basic, Bearer) selon les spécifications de la nouvelle API

- **Risque** : Impact sur les performances
  - **Mitigation** : Ajouter des métriques de temps de réponse et surveiller attentivement


## 6. Améliorations futures possibles

### Cache
```python
def get_balance_client(env, account, devise, force_refresh=False):
    # Vérifier d'abord le cache
    cache_key = f"balance_{account}_{devise}"
    cached_value = env.cache.get(cache_key) if hasattr(env, 'cache') else None
    if cached_value is not None and not force_refresh:
        return cached_value
    
    # Logique existante...
    
    # Mettre en cache le résultat
    if hasattr(env, 'cache') and response != 0:
        env.cache.set(cache_key, response, ttl=300)  # 5 minutes
    
    return response
```

### Retry mechanism
```python
def get_balance_client(env, account, devise):
    # Logique existante...
    
    for attempt in range(3):  # 3 tentatives maximum
        try:
            api_response = requests.get(url, headers=headers, timeout=10)
            # Traitement de la réponse...
            break  # Sortir de la boucle si succès
        except (requests.ConnectionError, requests.Timeout) as e:
            _logger.warning(f"Attempt {attempt+1} failed: {str(e)}")
            if attempt < 2:  # Ne pas attendre après la dernière tentative
                time.sleep(1 * (attempt + 1))  # Attente progressive
    
    return response
```

## 7. Conclusion

Cette migration de SOAP vers REST pour l'API Balance Client présente plusieurs avantages :

1. **Simplification** : Code plus lisible et plus facile à maintenir
2. **Performance** : Réduction de la taille des messages et du temps de traitement
3. **Robustesse** : Meilleure gestion des erreurs et des timeouts
4. **Modernisation** : Alignement sur les standards actuels d'API

Le risque est minimisé par le fait que la fonction principale conserve la même signature, ce qui évite tout impact sur le code appelant. L'authentification représente le principal défi de cette migration et devra être adaptée selon les spécifications exactes de la nouvelle API REST.
