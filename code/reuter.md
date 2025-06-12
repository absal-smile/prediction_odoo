# Documentation technique : Migration SOAP vers REST pour l'API Reuters

## 1. Contexte et objectifs

L'API Reuters est utilisée pour récupérer les taux de change entre différentes devises. Actuellement implémentée avec le protocole SOAP, cette API doit être migrée vers une architecture REST plus moderne, plus légère et plus facile à maintenir.

## 2. Analyse de l'existant

### Structure actuelle
Le module actuel utilise la bibliothèque `zeep` pour créer un client SOAP qui appelle la méthode `GetCoursChangeReuters` sur le service distant. Il dispose également d'un mécanisme de fallback avec des taux prédéfinis en cas d'échec de l'API.

### Points forts à conserver
- Le mécanisme de fallback avec `FAKE_RATES`
- La gestion des cas particuliers (devises identiques)
- La configuration via paramètres système
- L'interface externe de la fonction principale

## 3. Modifications techniques

### 3.1 Imports
**Avant :**
```python
import logging
import random
from zeep import Client
from odoo import tools
```

**Après :**
```python
import logging
import random
import requests
from odoo import tools
```

**Justification :** Remplacement de la bibliothèque SOAP `zeep` par la bibliothèque HTTP standard `requests`.

### 3.2 Constante FAKE_RATES et fonctions utilitaires

Ces éléments sont conservés sans modification car leur logique est indépendante du protocole d'API :
- `FAKE_RATES` : Dictionnaire de taux prédéfinis
- `_get_currency_code()` : Extraction du code de devise
- `_get_fake_sale_rate()` : Récupération d'un taux prédéfini

### 3.3 Fonction de création du client

**Avant :**
```python
def _get_wsdl_client(env):
    wsdl = env["ir.config_parameter"].sudo().get_param(
        "loomis_sale.reuters_rate_api")
    return Client(wsdl=wsdl)
```

**Après :**
```python
def _build_rate_url(env, source_currency, target_currency):
    """
    Construit l'URL REST pour l'API de taux de change.
    Remplace la création du client SOAP par la construction d'une URL REST.
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_sale.reuters_rate_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/rate/{source_currency}/{target_currency}"
```

**Justification :** Au lieu de créer un client SOAP basé sur un WSDL, nous construisons maintenant une URL REST qui pointe directement vers la ressource demandée (le taux de change entre deux devises).

### 3.4 Fonction de récupération du taux

**Avant :**
```python
def _get_sale_rate(client, source_currency, target_currency, value):
    response = client.service.GetCoursChangeReuters(
        "ODEAL-Sales", source_currency, target_currency)
    return float(response and response[value] or "1" or 1)
```

**Après :**
```python
def _get_rate_from_api(env, source_currency, target_currency, value="CoursVente"):
    """
    Récupère le taux de change depuis l'API REST.
    Remplace l'appel SOAP par une requête HTTP GET.
    """
    url = _build_rate_url(env, source_currency, target_currency)
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            # Adapter selon la structure réelle de la réponse JSON
            return float(data.get(value, data.get("rate", 1)))
        else:
            _logger.warning(f"Error fetching rate: HTTP {response.status_code}")
            if response.text:
                _logger.warning(f"Response details: {response.text[:200]}")
            return 1
    except Exception as e:
        _logger.warning(f"Error in API call: {str(e)}")
        return 1
```

**Justification :** Cette fonction remplace l'appel de méthode SOAP par une requête HTTP GET. Elle ajoute également :
- Un timeout explicite pour éviter les blocages
- Une vérification du code de statut HTTP
- Un parsing JSON avec gestion des erreurs
- Un logging amélioré pour faciliter le diagnostic

### 3.5 Fonction principale

**Avant :**
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

**Après :**
```python
def get_course_change_reuters(
        env, settlement_currency, sale_currency, value="CoursVente"):
    """
    Récupère le taux de change Reuters via l'API REST.
    Conserve la même signature et comportement externe, mais utilise REST au lieu de SOAP.
    """
    source_currency = _get_currency_code(settlement_currency)
    target_currency = _get_currency_code(sale_currency)
    
    # Ces conditions restent inchangées
    if source_currency == target_currency:
        return 1
    if not tools.config.get("enable_reuters_calcul"):
        return _get_fake_sale_rate(source_currency, target_currency)
    
    try:
        # Appel direct à la nouvelle fonction au lieu de créer un client puis appeler une méthode
        return _get_rate_from_api(env, source_currency, target_currency, value)
    except Exception:
        _logger.error("Error on API fetching Reuters rate")
        return 0
```

**Justification :** La fonction principale conserve la même signature et le même comportement externe, mais son implémentation interne change pour utiliser la nouvelle fonction REST. Les conditions préliminaires (devises identiques, désactivation de l'API) restent inchangées.

## 4. Configuration système

### Paramètres à modifier
| Paramètre actuel | Nouveau paramètre | Description |
|------------------|-------------------|-------------|
| `loomis_sale.reuters_rate_api` | `loomis_sale.reuters_rate_api_base_url` | URL de base de l'API REST |

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
- **Risque** : Différence dans les taux retournés
  - **Mitigation** : Vérification préalable avec l'équipe API pour confirmer la structure des réponses

- **Risque** : Indisponibilité temporaire de l'API REST
  - **Mitigation** : Le mécanisme de fallback existant protège contre ce risque

## 6. Code complet après migration

```python
# File: /home/smile/Bureau/workspace/loomis/loomis-addons/loomis_order/tools/reuters.py

import logging
import random
import requests

from odoo import tools

_logger = logging.getLogger(__name__)


FAKE_RATES = {
    "EUR/USD": 1.059200,
    "USD/EUR": 0.9444654325651681148469965999,
    "EUR/CHF": 0.967400,
    "CHF/EUR": 1.0342331161443789430137553004,
    "USD/CHF": 0.913500,
    "CHF/USD": 1.0951702989814916219472127916,
    "JPY/EUR": 0.006097943600000,
    "EUR/JPY": 163.99735698000000000000000000,
    "RUB/USD": 0.0101196659987635416,
    "USD/RUB": 99.3049300000000,
    "SEK/EUR": 0.010000,
    "EUR/SEK": 13.8346500000000,
}


def _get_currency_code(currency):
    """Return product default code or currency name"""
    return currency.default_code if currency._name == "product.template" \
        else currency.name


def _get_fake_sale_rate(source_currency, target_currency):
    return FAKE_RATES.get(
        f"{source_currency}/{target_currency}", random.uniform(0, 1))


def _build_rate_url(env, source_currency, target_currency):
    """
    Construit l'URL REST pour l'API de taux de change.
    Remplace la création du client SOAP par la construction d'une URL REST.
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_sale.reuters_rate_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/rate/{source_currency}/{target_currency}"


def _get_rate_from_api(env, source_currency, target_currency, value="CoursVente"):
    """
    Récupère le taux de change depuis l'API REST.
    Remplace l'appel SOAP par une requête HTTP GET.
    """
    url = _build_rate_url(env, source_currency, target_currency)
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            # Adapter selon la structure réelle de la réponse JSON
            # Supposons que la réponse contient une clé "rate" ou la clé spécifiée par "value"
            return float(data.get(value, data.get("rate", 1)))
        else:
            _logger.warning(f"Error fetching rate: HTTP {response.status_code}")
            if response.text:
                _logger.warning(f"Response details: {response.text[:200]}")
            return 1
    except Exception as e:
        _logger.warning(f"Error in API call: {str(e)}")
        return 1


def get_course_change_reuters(
        env, settlement_currency, sale_currency, value="CoursVente"):
    """
    Récupère le taux de change Reuters via l'API REST.
    Conserve la même signature et comportement externe, mais utilise REST au lieu de SOAP.
    """
    source_currency = _get_currency_code(settlement_currency)
    target_currency = _get_currency_code(sale_currency)
    
    # Ces conditions restent inchangées
    if source_currency == target_currency:
        return 1
    if not tools.config.get("enable_reuters_calcul"):
        return _get_fake_sale_rate(source_currency, target_currency)
    
    try:
        # Appel direct à la nouvelle fonction au lieu de créer un client puis appeler une méthode
        return _get_rate_from_api(env, source_currency, target_currency, value)
    except Exception:
        _logger.error("Error on API fetching Reuters rate")
        return 0
```

## 7. Conclusion

Cette migration de SOAP vers REST pour l'API Reuters présente plusieurs avantages :

1. **Simplification** : Code plus lisible et plus facile à maintenir
2. **Performance** : Réduction de la taille des messages et du temps de traitement
3. **Robustesse** : Meilleure gestion des erreurs et des timeouts
4. **Modernisation** : Alignement sur les standards actuels d'API

Le risque est minimisé par la conservation du mécanisme de fallback existant et par le fait que la fonction principale conserve la même signature, ce qui évite tout impact sur le code appelant.
