# Documentation technique : Migration SOAP vers REST

## 1. Modifications des imports

### Avant (SOAP)
```python
import logging
from odoo.tools import config
from requests import Session
from requests_ntlmauth import HttpNtlmAuth
from odoo.tools.zeep import Client, Transport
```

### Après (REST)
```python
import logging
import requests
import base64  # Nouveau pour l'encodage Basic Auth
from odoo.tools import config
```

**Description** : Suppression des imports spécifiques à SOAP (zeep, NTLM) et simplification avec la bibliothèque requests standard. L'import base64 est ajouté pour gérer l'authentification Basic si nécessaire.

## 2. Fonctions d'authentification

### Fonction `_get_account_auth(env)`
**Statut** : Conservée sans changement

**Justification** : Cette fonction récupère simplement les identifiants depuis les paramètres système. Sa logique reste valide indépendamment du protocole d'API utilisé.

### Nouvelle fonction `_get_auth_headers(env)`
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

**Description** : Nouvelle fonction qui transforme les identifiants en en-têtes HTTP appropriés pour l'API REST. Remplace la logique d'authentification NTLM qui était gérée par la bibliothèque zeep.

## 3. Fonction d'environnement

### Fonction `_get_client_balance_environment(env)`
**Statut** : Conservée sans changement

**Justification** : Cette fonction récupère simplement un paramètre de configuration qui sera toujours nécessaire, même s'il sera utilisé différemment (comme partie de l'URL plutôt que comme paramètre de méthode).

## 4. Fonction de création du client

### Avant (SOAP)
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

### Après (REST) - Remplacée par `_build_balance_url`
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

**Description** : La fonction de création du client SOAP est remplacée par une fonction qui construit l'URL REST. Cette transformation est fondamentale car elle représente le changement de paradigme de SOAP (où on crée un client qui expose des méthodes) vers REST (où on construit des URLs qui représentent des ressources).

## 5. Fonction principale

### Avant (SOAP)
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

### Après (REST)
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
        except Exception as e:
            _logger.error(f"Error on API of import Balance client: {str(e)}")
    
    return response
```

**Description** : La fonction principale conserve la même signature et le même comportement externe (elle retourne toujours le solde ou 0 en cas d'erreur), mais son implémentation interne change radicalement. Au lieu d'appeler une méthode sur un client SOAP, elle effectue une requête HTTP GET vers une URL REST, puis extrait le solde de la réponse JSON.

## 6. Paramètres de configuration à modifier

| Paramètre actuel | Nouveau paramètre | Description du changement |
|------------------|-------------------|---------------------------|
| `loomis_partner.client_balance_api` | `loomis_partner.client_balance_api_base_url` | Passage d'une URL WSDL à une URL de base REST |
| `loomis_partner.client_balance_username` | (inchangé) | Conservé car toujours nécessaire pour l'authentification |
| `loomis_partner.client_balance_password` | (inchangé) | Conservé car toujours nécessaire pour l'authentification |
| `loomis_partner.client_balance_environment` | (inchangé) | Conservé mais utilisé comme partie de l'URL plutôt que comme paramètre |

## 7. Considérations techniques supplémentaires

### Gestion des timeouts
```python
# Ajout d'un timeout explicite pour éviter les blocages
api_response = requests.get(url, headers=headers, timeout=10)
```
**Description** : Les appels REST doivent avoir des timeouts explicites pour éviter que l'application ne se bloque en cas de problème réseau.

### Logging amélioré
```python
# Logging plus détaillé incluant le code HTTP
_logger.error(f"Error on API of import Balance client: HTTP {api_response.status_code}")
```
**Description** : Le logging est amélioré pour inclure plus d'informations sur les erreurs, facilitant le diagnostic des problèmes.

### Validation des réponses
```python
# Vérification du code HTTP et parsing JSON sécurisé
if api_response.status_code == 200:
    data = api_response.json()
    response = data.get("balance", 0)  # Utilisation de get() avec valeur par défaut
```
**Description** : La validation des réponses est plus robuste, vérifiant le code HTTP et utilisant des méthodes sécurisées pour extraire les données JSON.

## 8. Résumé des changements

1. **Simplification des dépendances** : Suppression de zeep et NTLM, utilisation de requests standard
2. **Changement de paradigme** : Passage d'appels de méthodes à des requêtes HTTP vers des URLs
3. **Traitement manuel** : Parsing explicite des réponses JSON au lieu du parsing automatique XML
4. **Authentification adaptée** : Passage de NTLM à Basic Auth ou Bearer Token via en-têtes HTTP
5. **Robustesse accrue** : Meilleure gestion des erreurs et timeouts explicites

Ces changements permettent de moderniser l'interface tout en conservant la même fonctionnalité et signature externe, minimisant ainsi l'impact sur le reste du code.
