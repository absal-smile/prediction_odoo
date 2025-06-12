# Documentation technique : Changements structurels pour la migration SOAP vers REST

## 1. Structure générale des modules

### Modifications communes aux deux modules

| Aspect | Avant (SOAP) | Après (REST) |
|--------|--------------|--------------|
| **Imports** | `from zeep import Client, Transport` | `import requests` |
| **Authentification** | Classes spécifiques (HttpNtlmAuth) | Headers HTTP standards |
| **Traitement des réponses** | Automatique via zeep | Parsing JSON manuel |

## 2. Module de solde client (`client_balance.py`)

### Structure actuelle
```
_get_account_auth()
_get_client_balance_environment()
_get_client()
get_balance_client()
```

### Structure proposée
```
_get_auth_credentials()
_get_client_environment()
_get_auth_headers()
_build_balance_url()
get_balance_client()
```

### Changements détaillés

#### 2.1 Fonction d'authentification
**Avant:**
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

**Après:**
```python
def _get_auth_headers(env):
    username, password = _get_auth_credentials(env)
    # Option 1: Basic Auth
    auth_str = f"{username}:{password}"
    auth_bytes = auth_str.encode('ascii')
    auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
    return {
        "Authorization": f"Basic {auth_b64}",
        "Content-Type": "application/json"
    }
    
    # Option 2: Bearer Token (si l'API utilise OAuth)
    # token = _get_token(env, username, password)
    # return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
```

#### 2.2 Fonction principale
**Avant:**
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

**Après:**
```python
def get_balance_client(env, account, devise):
    response = 0
    if config.get('enable_import_client_balance'):
        headers = _get_auth_headers(env)
        company = _get_client_environment(env)
        url = _build_balance_url(env, company, account, devise)
        try:
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                data = response.json()
                response = data.get("balance", 0)
            else:
                _logger.error(f"Error on API of import Balance client: {response.status_code}")
        except Exception as e:
            _logger.error(f"Error on API of import Balance client: {str(e)}")
    return response
```

#### 2.3 Nouvelle fonction pour construire l'URL
```python
def _build_balance_url(env, company, account, currency):
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/accounting/balance/{company}/{account}/{currency}"
```

## 3. Module de taux Reuters (`reuters.py`)

### Structure actuelle
```
_get_currency_code()
_get_fake_sale_rate()
_get_sale_rate()
_get_wsdl_client()
get_course_change_reuters()
```

### Structure proposée
```
_get_currency_code()
_get_fake_sale_rate()
_get_rate_from_api()
_build_rate_url()
get_course_change_reuters()
```

### Changements détaillés

#### 3.1 Fonction d'appel API
**Avant:**
```python
def _get_sale_rate(client, source_currency, target_currency, value):
    response = client.service.GetCoursChangeReuters(
        "ODEAL-Sales", source_currency, target_currency)
    return float(response and response[value] or "1" or 1)
```

**Après:**
```python
def _get_rate_from_api(env, source_currency, target_currency, value="CoursVente"):
    url = _build_rate_url(env, source_currency, target_currency)
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            # Adapter selon la structure réelle de la réponse
            return float(data.get(value, data.get("rate", 1)))
        else:
            _logger.error(f"Error fetching rate: {response.status_code}")
            return 1
    except Exception as e:
        _logger.error(f"Error in API call: {str(e)}")
        return 1
```

#### 3.2 Fonction principale
**Avant:**
```python
def get_course_change_reuters(
        env, settlement_currency, sale_currency, value="CoursVente"):
    source_currency = _get_currency_code(settlement_currency)
    target_currency = _get_currency_code(sale_currency)
    if source_currency == target_currency:
        return 1
    if not tools.config.get("enable_reuters_calcul"):
        return _get_fake_sale_rate(source_currency, target_currency)
    try:
        client = _get_wsdl_client(env)
        return _get_sale_rate(client, source_currency, target_currency, value)
    except Exception:
        _logger.error("Error on API fetching Reuters rate")
        return 0
```

**Après:**
```python
def get_course_change_reuters(
        env, settlement_currency, sale_currency, value="CoursVente"):
    source_currency = _get_currency_code(settlement_currency)
    target_currency = _get_currency_code(sale_currency)
    if source_currency == target_currency:
        return 1
    if not tools.config.get("enable_reuters_calcul"):
        return _get_fake_sale_rate(source_currency, target_currency)
    try:
        return _get_rate_from_api(env, source_currency, target_currency, value)
    except Exception:
        _logger.error("Error on API fetching Reuters rate")
        return 0
```

#### 3.3 Nouvelle fonction pour construire l'URL
```python
def _build_rate_url(env, source_currency, target_currency):
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_sale.reuters_rate_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/rate/{source_currency}/{target_currency}"
```

## 4. Différences structurelles entre SOAP et REST

### SOAP (structure actuelle)
- **Corps de message XML complexe** avec enveloppe, en-tête et corps
- **Méthodes explicites** appelées sur le service (`client.service.GetCoursChangeReuters`)
- **Paramètres** passés comme arguments de méthode
- **Transport** géré par la bibliothèque zeep
- **Parsing automatique** des réponses XML

### REST (nouvelle structure)
- **URL significative** contenant les ressources et identifiants
- **Méthodes HTTP** standard (GET, POST, etc.)
- **Paramètres** intégrés dans l'URL ou en query string
- **En-têtes HTTP** pour l'authentification et le type de contenu
- **Parsing manuel** des réponses JSON

## 5. Paramètres de configuration à modifier

| Module | Ancien paramètre | Nouveaux paramètres |
|--------|------------------|---------------------|
| **Reuters** | `loomis_sale.reuters_rate_api` | `loomis_sale.reuters_rate_api_base_url` |
| **Balance Client** | `loomis_partner.client_balance_api` | `loomis_partner.client_balance_api_base_url` |
| | `loomis_partner.client_balance_username` | (inchangé ou adapté selon l'authentification) |
| | `loomis_partner.client_balance_password` | (inchangé ou adapté selon l'authentification) |
| | `loomis_partner.client_balance_environment` | (inchangé, utilisé comme paramètre d'URL) |

## 6. Considérations techniques supplémentaires

- **Gestion des timeouts** : Ajouter des paramètres de timeout explicites pour les appels REST
- **Retry mechanism** : Considérer l'ajout d'une logique de réessai pour les appels échoués
- **Validation des réponses** : Ajouter des validations plus strictes des structures JSON reçues
- **Logging amélioré** : Enregistrer plus de détails sur les erreurs HTTP
- **Métriques** : Ajouter des mesures de performance pour surveiller les temps de réponse
- **Cache** : Considérer l'implémentation d'un cache pour réduire les appels API

Cette documentation technique détaille les changements structurels nécessaires pour migrer les deux modules de SOAP vers REST, en préservant la logique métier existante tout en adaptant les mécanismes d'appel API.
