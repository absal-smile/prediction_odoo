# Code complet pour la migration de l'API Balance Client (SOAP vers REST)

```python
# File: /home/smile/Bureau/workspace/loomis/loomis-addons/loomis_client_account/tools/client_balance.py

import logging
import requests
import base64
from odoo.tools import config

_logger = logging.getLogger(__name__)


def _get_account_auth(env):
    username = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_username")
    password = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_password")
    if not username or not password:
        _logger.error("Username or Password doesn't exist")
    return username, password


def _get_client_balance_environment(env):
    client_balance_environment = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_environment")
    if not client_balance_environment:
        _logger.error("Client balance environment doesn't exist")
    return client_balance_environment


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


def _build_balance_url(env, company, account, currency):
    """
    Construit l'URL REST pour l'API de solde client.
    Remplace la création du client SOAP par la construction d'une URL REST.
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/accounting/balance/{company}/{account}/{currency}"


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

# Code complet pour la migration de l'API Reuters (SOAP vers REST)

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

Ces deux fichiers complets représentent la migration des API SOAP vers REST tout en maintenant la même interface externe. Les principales modifications sont :

1. Remplacement des bibliothèques SOAP par requests
2. Création de nouvelles fonctions pour construire les URLs REST
3. Ajout de fonctions pour gérer l'authentification via en-têtes HTTP
4. Amélioration de la gestion des erreurs et du logging
5. Parsing manuel des réponses JSON

Les paramètres système devront également être mis à jour pour pointer vers les nouvelles URLs de base REST au lieu des URLs WSDL.
