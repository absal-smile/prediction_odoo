# Code modifié pour la migration SOAP vers REST

## 1. Fichier client_balance.py (API Balance Client)

```python
# File: /home/smile/Bureau/workspace/loomis/loomis-addons/loomis_client_account/tools/client_balance.py
import logging
import requests
from odoo.tools import config
from requests_ntlm import HttpNtlmAuth
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


def _build_balance_url(env, account, devise):
    """
    Construit l'URL REST pour l'API de solde client.
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_partner.client_balance_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    company = _get_client_balance_environment(env)
    return f"{base_url}/accounting/balance/{company}/{account}/{devise}"


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

## 2. Fichier res_partner.py (Modèle Partner)

```python
# File: /path/to/res_partner.py
from odoo import fields, models, _
import logging
from ..tools import client_balance

_logger = logging.getLogger(__name__)


class ResPartner(models.Model):
    _inherit = 'res.partner'

    client_account_ids = fields.One2many(
        'client.account', 'partner_id', 'Client accounts')

    def _import_balance_client(self):
        accounts = self.env['client.account'].search([])
        _logger.info(f"Starting balance import for {len(accounts)} accounts.")
        for account in accounts:
            account.balance = client_balance.get_balance_client(
                self.env, account.name, account.currency_id.name)
        _logger.info("Balance import done.")
        return accounts
```

## 3. Fichier ir_config_parameter.xml (API Balance Client)

```xml
<!-- File: /path/to/ir_config_parameter.xml -->
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

## 4. Fichier reuters.py (API Reuters)

```python
# File: /path/to/reuters.py
import logging
import random
import requests
from odoo import tools

_logger = logging.getLogger(__name__)

# Conservé sans modification
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
    """
    base_url = env["ir.config_parameter"].sudo().get_param(
        "loomis_sale.reuters_rate_api_base_url", 
        "https://uat-apps.cprb.fr/crow.api")
    return f"{base_url}/rate/{source_currency}/{target_currency}"


def _get_rate_from_api(env, source_currency, target_currency, value="CoursVente"):
    """
    Récupère le taux de change depuis l'API REST.
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


def get_course_change_reuters(
        env, settlement_currency, sale_currency, value="CoursVente"):
    """
    Récupère le taux de change Reuters via l'API REST.
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

## 5. Fichier res_currency.py (Modèle Currency)

```python
# File: /path/to/res_currency.py
from odoo import models, api

class ResCurrency(models.Model):
    _inherit = 'res.currency'

    def get_reuters_rate(self, product_currency):
        """Get Reuters rate between currency and product currency in real-time"""
        from odoo.addons.loomis_order.tools.reuters import get_course_change_reuters
        
        if isinstance(product_currency, str):
            # Si c'est déjà un code de devise
            product_currency_code = product_currency
        else:
            # Si c'est un recordset (product.template ou res.currency)
            product_currency_code = product_currency.default_code if hasattr(product_currency, 'default_code') else product_currency.name
        
        return get_course_change_reuters(self.env, self, product_currency_code)

    def get_reuters_rates_data(self, product_templates=None):
        """Generate Reuters rates data for all product templates or specified ones"""
        if not product_templates:
            product_templates = self.env['product.template'].search([])
        
        result = []
        for product in product_templates:
            rate = self.get_reuters_rate(product)
            result.append({
                'product_tmpl_id': product.default_code,
                'currency': self.name,
                'reuters': rate
            })
        
        return result
```

## 6. Fichier ir_config_parameter.xml (API Reuters)

```xml
<!-- File: /path/to/ir_config_parameter.xml -->
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data noupdate="1">
        <!-- Nouveau paramètre REST - URL de base de l'API -->
        <record id="reuters_rate_api_base_url" model="ir.config_parameter">
            <field name="key">loomis_sale.reuters_rate_api_base_url</field>
            <field name="value">https://uat-apps.cprb.fr/crow.api</field>
        </record>

        <!-- Paramètres existants conservés -->
        <record id="global_threshold_margin" model="ir.config_parameter">
            <field name="key">loomis_sale.global_threshold_margin</field>
            <field name="value">0.15</field>
        </record>

        <record id="rate_volatility_percentage" model="ir.config_parameter">
            <field name="key">loomis_sale.rate_volatility_percentage</field>
            <field name="value">0.05</field>
        </record>
    </data>
</odoo>
```

## 7. Fichier sale_order.py (Modèle Sale Order)

```python
# File: /path/to/sale_order.py
from odoo import models, api
import json

class SaleOrder(models.Model):
    _inherit = 'sale.order'

    @api.onchange('settlement_currency_id')
    def _onchange_currency_reuters_rate_serialized(self):
        if not self.settlement_currency_id:
            return
        
        # Récupérer les taux existants s'il y en a
        existing_rates = []
        if self.order_currency_reuters_rate_serialized:
            try:
                existing_rates = json.loads(self.order_currency_reuters_rate_serialized)
            except (ValueError, json.JSONDecodeError):
                existing_rates = []
        
        # Filtrer pour enlever les entrées avec la devise actuelle
        filtered_rates = [r for r in existing_rates if r.get('currency') != self.settlement_currency_id.name]
        
        # Obtenir les nouveaux taux pour la devise actuelle
        new_rates = self.settlement_currency_id.get_reuters_rates_data()
        
        # Combiner les taux
        combined_rates = filtered_rates + new_rates
        
        # Mettre à jour le champ sérialisé
        self.order_currency_reuters_rate_serialized = json.dumps(combined_rates)
```

## 8. Fichier sale_order_line.py (Modèle Sale Order Line)

```python
# File: /path/to/sale_order_line.py
from odoo import models, api, fields
import json

class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    reuters_rate = fields.Float(compute='_compute_reuters_rate', store=True)

    @api.depends("order_id.order_currency_reuters_rate_serialized",
                "product_tmp_id", "order_id.settlement_currency_id")
    def _compute_reuters_rate(self):
        for line in self:
            line.reuters_rate = 1
            if not line.product_tmp_id or not line.order_id.settlement_currency_id:
                continue
                
            product_tmpl_iso_code = line.product_tmp_id.default_code
            
            # Essayer d'abord d'obtenir le taux depuis les données sérialisées
            if reuters_couple_serialized := line.order_id.order_currency_reuters_rate_serialized:
                try:
                    reuters_couple = json.loads(reuters_couple_serialized)
                    for rc in reuters_couple:
                        if rc['product_tmpl_id'] == product_tmpl_iso_code \
                            and rc['currency'] == line.order_id.settlement_currency_id.name:
                            line.reuters_rate = rc['reuters']
                            break
                except (ValueError, json.JSONDecodeError):
                    pass
            
            # Si aucun taux n'a été trouvé, obtenir le taux en temps réel
            if line.reuters_rate == 1 and line.product_tmp_id and line.order_id.settlement_currency_id:
                from odoo.addons.loomis_order.tools.reuters import get_course_change_reuters
                line.reuters_rate = get_course_change_reuters(
                    line.env, 
                    line.order_id.settlement_currency_id, 
                    line.product_tmp_id
                )
```
