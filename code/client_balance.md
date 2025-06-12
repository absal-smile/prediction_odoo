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

-----

# Mise à jour des paramètres de configuration pour la migration REST

Pour compléter la migration SOAP vers REST, vous devez mettre à jour les paramètres de configuration dans les fichiers XML. Voici les modifications nécessaires pour les deux fichiers que vous avez identifiés.

## 1. Mise à jour du fichier de paramètres de configuration

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data noupdate="1">
        <!-- Ancien paramètre SOAP - à conserver temporairement pour compatibilité -->
        <record id="client_balance_api" model="ir.config_parameter">
            <field name="key">loomis_partner.client_balance_api</field>
            <field name="value">http://appint.cprb.fr/Scribux/Svc/Unit4CodaService.svc?wsdl</field>
        </record>
        
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

## 2. Le cron reste inchangé

Le cron que vous avez identifié n'a pas besoin d'être modifié car il appelle simplement la méthode `_import_balance_client()` sur le modèle `res_partner`. C'est cette méthode qui utilise la fonction `get_balance_client()` que nous avons migrée.

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo noupdate="1">
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
</odoo>
```

## 3. Stratégie de déploiement des paramètres

Pour une migration en douceur, je recommande la stratégie suivante :

1. **Phase 1 : Préparation**
   - Ajouter le nouveau paramètre `loomis_partner.client_balance_api_base_url`
   - Conserver l'ancien paramètre `loomis_partner.client_balance_api`
   - Déployer le nouveau code qui utilise l'API REST

2. **Phase 2 : Validation**
   - Vérifier que les soldes clients sont correctement importés
   - Comparer les résultats avec l'ancienne implémentation si possible
   - Résoudre les éventuels problèmes

3. **Phase 3 : Nettoyage (après validation complète)**
   - Supprimer l'ancien paramètre `loomis_partner.client_balance_api`
   - Mettre à jour la documentation

## 4. Paramètres pour l'API Reuters

De la même manière, vous devrez mettre à jour les paramètres pour l'API Reuters. Si vous avez un fichier similaire pour cette API, voici comment il devrait être modifié :

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data noupdate="1">
        <!-- Ancien paramètre SOAP - à conserver temporairement pour compatibilité -->
        <record id="reuters_rate_api" model="ir.config_parameter">
            <field name="key">loomis_sale.reuters_rate_api</field>
            <field name="value">http://appint.cprb.fr/Scribux/Svc/ReutersService.svc?wsdl</field>
        </record>
        
        <!-- Nouveau paramètre REST - URL de base de l'API -->
        <record id="reuters_rate_api_base_url" model="ir.config_parameter">
            <field name="key">loomis_sale.reuters_rate_api_base_url</field>
            <field name="value">https://uat-apps.cprb.fr/crow.api</field>
        </record>
    </data>
</odoo>
```

## 5. Considérations importantes

### Environnements multiples
Assurez-vous que les valeurs des URLs sont correctes pour chaque environnement (développement, test, production). Vous pourriez avoir besoin de différentes configurations pour chaque environnement.

### Sécurité
Vérifiez que les nouvelles URLs utilisent HTTPS pour une communication sécurisée, surtout si elles transmettent des informations sensibles.

### Monitoring
Après le déploiement, surveillez attentivement les logs pour détecter d'éventuelles erreurs liées aux appels API.

### Documentation
Mettez à jour la documentation interne pour refléter ces changements de configuration, afin que les futurs développeurs comprennent la structure.

Ces modifications de configuration complètent la migration du code que nous avons effectuée précédemment, en garantissant que le système pointe vers les bonnes URLs d'API REST.

Le risque est minimisé par le fait que la fonction principale conserve la même signature, ce qui évite tout impact sur le code appelant. L'authentification représente le principal défi de cette migration et devra être adaptée selon les spécifications exactes de la nouvelle API REST.
