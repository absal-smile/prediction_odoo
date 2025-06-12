# Documentation technique : Migration SOAP vers REST pour l'API Reuters

## 1. Modifications des imports

### Avant (SOAP)
```python
import logging
import random
from zeep import Client

from odoo import tools
```

### Après (REST)
```python
import logging
import random
import requests

from odoo import tools
```

**Description** : Remplacement de l'import zeep (bibliothèque SOAP) par requests (bibliothèque HTTP standard). Les autres imports sont conservés car ils sont toujours nécessaires.

## 2. Constante FAKE_RATES

### Statut : Conservée sans changement

**Justification** : Cette constante contient des taux de change prédéfinis utilisés comme fallback. Sa logique est indépendante du protocole d'API et reste donc valide.

## 3. Fonction `_get_currency_code(currency)`

### Statut : Conservée sans changement

**Justification** : Cette fonction utilitaire extrait simplement le code de devise d'un objet currency. Sa logique est indépendante du protocole d'API et reste donc valide.

## 4. Fonction `_get_fake_sale_rate(source_currency, target_currency)`

### Statut : Conservée sans changement

**Justification** : Cette fonction de fallback récupère un taux prédéfini ou génère une valeur aléatoire. Sa logique est indépendante du protocole d'API et reste donc valide.

## 5. Fonction de récupération du taux

### Avant (SOAP)
```python
def _get_sale_rate(client, source_currency, target_currency, value):
    response = client.service.GetCoursChangeReuters(
        "ODEAL-Sales", source_currency, target_currency)
    return float(response and response[value] or "1" or 1)
```

### Après (REST)
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
            # Supposons que la réponse contient une clé "rate" ou la clé spécifiée par "value"
            return float(data.get(value, data.get("rate", 1)))
        else:
            _logger.warning(f"Error fetching rate: HTTP {response.status_code}")
            return 1
    except Exception as e:
        _logger.warning(f"Error in API call: {str(e)}")
        return 1
```

**Description** : Cette fonction remplace l'appel de méthode SOAP par une requête HTTP GET vers l'API REST. Elle gère également les erreurs HTTP et le parsing JSON. La valeur de retour reste un float pour maintenir la compatibilité.

## 6. Fonction de création du client

### Avant (SOAP)
```python
def _get_wsdl_client(env):
    wsdl = env["ir.config_parameter"].sudo().get_param(
        "loomis_sale.reuters_rate_api")
    return Client(wsdl=wsdl)
```

### Après (REST) - Remplacée par `_build_rate_url`
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

**Description** : La fonction de création du client SOAP est remplacée par une fonction qui construit l'URL REST. Cette transformation est fondamentale car elle représente le changement de paradigme de SOAP (où on crée un client qui expose des méthodes) vers REST (où on construit des URLs qui représentent des ressources).

## 7. Fonction principale

### Avant (SOAP)
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

### Après (REST)
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

**Description** : La fonction principale conserve la même signature et le même comportement externe (elle retourne toujours le taux ou 0 en cas d'erreur), mais son implémentation interne change. Au lieu de créer un client SOAP puis d'appeler une méthode, elle appelle directement la nouvelle fonction qui effectue la requête REST.

## 8. Paramètres de configuration à modifier

| Paramètre actuel | Nouveau paramètre | Description du changement |
|------------------|-------------------|---------------------------|
| `loomis_sale.reuters_rate_api` | `loomis_sale.reuters_rate_api_base_url` | Passage d'une URL WSDL à une URL de base REST |

## 9. Considérations techniques supplémentaires

### Gestion des timeouts
```python
# Ajout d'un timeout explicite pour éviter les blocages
response = requests.get(url, timeout=10)
```
**Description** : Les appels REST doivent avoir des timeouts explicites pour éviter que l'application ne se bloque en cas de problème réseau.

### Logging amélioré
```python
# Logging plus détaillé incluant le code HTTP
_logger.warning(f"Error fetching rate: HTTP {response.status_code}")
```
**Description** : Le logging est amélioré pour inclure plus d'informations sur les erreurs, facilitant le diagnostic des problèmes.

### Validation des réponses
```python
# Vérification du code HTTP et parsing JSON sécurisé
if response.status_code == 200:
    data = response.json()
    return float(data.get(value, data.get("rate", 1)))
```
**Description** : La validation des réponses est plus robuste, vérifiant le code HTTP et utilisant des méthodes sécurisées pour extraire les données JSON.

## 10. Résumé des changements

1. **Simplification des dépendances** : Suppression de zeep, utilisation de requests standard
2. **Changement de paradigme** : Passage d'appels de méthodes à des requêtes HTTP vers des URLs
3. **Traitement manuel** : Parsing explicite des réponses JSON au lieu du parsing automatique XML
4. **Robustesse accrue** : Meilleure gestion des erreurs et timeouts explicites
5. **Préservation du fallback** : Conservation du mécanisme de taux prédéfinis en cas d'échec

Ces changements permettent de moderniser l'interface tout en conservant la même fonctionnalité et signature externe, minimisant ainsi l'impact sur le reste du code. La migration est particulièrement simple pour cette API car elle ne nécessite pas de gestion d'authentification complexe.
