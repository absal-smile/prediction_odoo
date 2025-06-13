# Documentation technique : Migration SOAP vers REST pour l'API Balance Client

## 1. Contexte et objectifs

L'API Balance Client est utilisée pour récupérer les soldes des comptes clients. Actuellement implémentée avec le protocole SOAP et une authentification NTLM, cette API doit être migrée vers une architecture REST plus moderne, plus légère et plus facile à maintenir. Nous conserverons le cron quotidien pour maintenir la compatibilité avec les processus existants.

## 2. Analyse de l'existant

### Structure actuelle
Le module actuel utilise la bibliothèque `zeep` pour créer un client SOAP avec authentification NTLM qui appelle la méthode `GetSoldeCompteComptable` sur le service distant. Les soldes sont récupérés via un cron quotidien qui met à jour les enregistrements `client.account`.

### Points forts à conserver
- La gestion des identifiants via paramètres système
- La configuration de l'environnement
- L'interface externe de la fonction principale
- Le flag d'activation/désactivation
- Le cron quotidien pour la mise à jour automatique des soldes

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
from odoo.tools import config
from requests_ntlm import HttpNtlmAuth
```

**Justification :** Suppression de l'import de `zeep` et simplification des imports. Nous conservons `HttpNtlmAuth` car l'API REST utilise toujours l'authentification NTLM.

### 3.2 Fonctions d'authentification et d'environnement

Ces fonctions sont conservées sans modification car leur logique reste valide :
- `_get_account_auth()` : Récupération des identifiants
- `_get_client_balance_environment()` : Récupération de l'environnement

### 3.3 Fonction de construction de l'URL

**Nouvelle fonction :**
```python
def _build_balance_url(env, account, devise):
    """
    Construit l'URL REST pour l'API de solde client.
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    company = _get_client_balance_environment(env)
    return f"{base_url}/accounting/balance/{company}/{account}/{devise}"
```

**Justification :** Cette fonction remplace la création du client SOAP en construisant directement l'URL REST.

### 3.4 Fonction de création du client (à supprimer)

**Fonction à supprimer :**
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

**Justification :** Cette fonction n'est plus nécessaire car nous utilisons directement des requêtes HTTP avec l'authentification NTLM.

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
    Récupère le solde d'un compte client via l'API REST.
    """
    response = 0
    if config.get('enable_import_client_balance'):
        try:
            url = _build_balance_url(env, account, devise)
            username, password = _get_account_auth(env)
            
            session = requests.Session()
            session.auth = HttpNtlmAuth(username, password)
            
            api_response = session.get(url, timeout=10)
            
            if api_response.status_code == 200:
                data = api_response.json()
                # Adapter selon la structure réelle de la réponse JSON
                response = float(data.get("balance", 0))
            else:
                _logger.warning(f"Error fetching balance: HTTP {api_response.status_code}")
                if api_response.text:
                    _logger.warning(f"Response details: {api_response.text[:200]}")
        except Exception as e:
            _logger.error(f"Error on API of import Balance client: {str(e)}")
    return response
```

**Justification :** Cette fonction remplace l'appel SOAP par une requête HTTP GET. Elle ajoute également :
- Un timeout explicite pour éviter les blocages
- Une vérification du code de statut HTTP
- Un parsing JSON avec gestion des erreurs
- Un logging amélioré pour faciliter le diagnostic

### 3.6 Méthode _import_balance_client (à conserver mais modifier)

La méthode `_import_balance_client` du modèle `res.partner` est conservée pour maintenir la compatibilité avec le cron existant, mais elle utilisera la nouvelle implémentation REST :

```python
def _import_balance_client(self):
    accounts = self.env['client.account'].search([])
    _logger.info(f"Starting balance import for {len(accounts)} accounts.")
    for account in accounts:
        # Utilise la même fonction get_balance_client mais avec l'implémentation REST
        account.balance = client_balance.get_balance_client(
            self.env, account.name, account.currency_id.name)
    _logger.info("Balance import done.")
    return accounts
```

## 4. Champs et paramètres impactés

### 4.1 Paramètres à modifier

| Paramètre actuel | Nouveau paramètre | Description |
|------------------|-------------------|-------------|
| `loomis_partner.client_balance_api` | `loomis_partner.client_balance_api_base_url` | URL de base de l'API REST |

### 4.2 Paramètres à conserver

- `loomis_partner.client_balance_environment` - Toujours utilisé pour identifier l'environnement/société
- `loomis_partner.client_balance_username` - Toujours utilisé pour l'authentification
- `loomis_partner.client_balance_password` - Toujours utilisé pour l'authentification

### 4.3 Champs du modèle

Aucun champ du modèle `client.account` ou `res.partner` n'est impacté par cette migration. La structure des données reste identique.

## 5. Éléments à conserver

### 5.1 Cron à conserver

Le cron `ir_cron_balance_client` est conservé pour maintenir la mise à jour quotidienne des soldes :

```xml
<record id="ir_cron_balance_client" model="ir.cron">
    <field name="name">Balance Client Import</field>
    <field name="interval_number">1</field>
    <field name="interval_type">days</field>
    <field name="nextcall"
           eval="(DateTime.now().replace(hour=5, minute=0) + timedelta(days=1)).strftime('%Y-%m-%d %H:%M:%S')" />
    <field name="model_id" ref="model_res_partner"/>
    <field name="code">model._import_balance_client()</field>
    <field name="state">code</field>
</record>
```

### 5.2 Méthode à conserver mais modifier

La méthode `_import_balance_client` du modèle `res.partner` est conservée mais utilisera la nouvelle implémentation REST.

### 5.3 Imports à supprimer

Dans le fichier `client_balance.py` :

```python
from odoo.tools.zeep import Client, Transport
```

## 6. Configuration système

### 6.1 Mise à jour des paramètres XML

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data noupdate="1">
        <!-- Nouveau paramètre REST - URL de base de l'API -->
        <record id="client_balance_api_base_url" model="ir.config_parameter">
            <field name="key">loomis_partner.client_balance_api_base_url</field>
            <field name="value">https://uat-apps.cprb.fr/crow.api</field>
        </record>
        
        <!-- Paramètre d'environnement - conservé et toujours utilisé -->
        <record id="client_balance_environment" model="ir.config_parameter">
            <field name="key">loomis_partner.client_balance_environment</field>
            <field name="value">ztest6</field>
        </record>
    </data>
</odoo>
```

### 6.2 Valeurs suggérées pour le nouveau paramètre
- Environnement UAT : `https://uat-apps.cprb.fr/crow.api`
- Environnement Production : `https://apps.cprb.fr/crow.api`


## 7. Conclusion

Cette migration de SOAP vers REST pour l'API Balance Client présente plusieurs avantages :

1. **Simplification** : Code plus lisible et plus facile à maintenir
2. **Performance** : Réduction de la charge serveur et des temps de réponse
3. **Modernisation** : Alignement sur les standards actuels d'API
4. **Meilleure gestion des erreurs** : Logging amélioré et timeouts explicites

En conservant le cron existant et la méthode `_import_balance_client`, nous assurons une transition en douceur sans perturber les processus métier existants. 

Le risque est minimisé par une approche progressive et la possibilité de revenir temporairement à l'ancien système si nécessaire.
