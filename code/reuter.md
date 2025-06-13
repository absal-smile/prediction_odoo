# Documentation technique : Migration SOAP vers REST pour l'API Reuters

## 1. Contexte et objectifs

L'API Reuters est utilisée pour récupérer les taux de change entre différentes devises. Actuellement implémentée avec le protocole SOAP, cette API doit être migrée vers une architecture REST plus moderne, plus légère et plus facile à maintenir.

## 2. Analyse de l'existant

### Structure actuelle
Le module actuel utilise la bibliothèque `zeep` pour créer un client SOAP qui appelle la méthode `GetCoursChangeReuters` sur le service distant. Les taux sont stockés dans le champ `currency_reuters_rate_serialized` du modèle `res.currency` et dans le champ `order_currency_reuters_rate_serialized` des modèles de commande.

### Points forts à conserver
- Le mécanisme de fallback avec `FAKE_RATES`
- La gestion des cas particuliers (devises identiques)
- La configuration via paramètres système
- L'interface externe de la fonction principale `get_course_change_reuters`

## 3. Modifications techniques

### 3.1 Imports et dépendances
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

### 3.6 Nouvelles méthodes dans le modèle res.currency

Pour remplacer la méthode `update_reuters_rate` qui sera supprimée, nous ajoutons deux nouvelles méthodes:

```python
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

**Justification :** Ces méthodes permettent d'obtenir les taux de change en temps réel sans avoir à les stocker dans le champ `currency_reuters_rate_serialized`.

## 4. Champs impactés

### 4.1 Champs à supprimer

- `currency_reuters_rate_serialized` dans le modèle `res.currency`
  - Ce champ n'est plus nécessaire car les taux sont maintenant récupérés en temps réel

### 4.2 Champs à conserver

- `order_currency_reuters_rate_serialized` dans les modèles de commande
  - Ce champ est conservé pour maintenir la compatibilité avec le code existant
  - Il sera rempli à la volée lors de la création ou modification des commandes

## 5. Méthodes impactées

### 5.1 Méthodes à supprimer

- `update_reuters_rate()` dans le modèle `res.currency`
  - Cette méthode n'est plus nécessaire car les taux sont récupérés en temps réel

### 5.2 Méthodes à adapter

#### _onchange_currency_reuters_rate_serialized

```python
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
Impact: Méthode déclenchée lors du changement de devise de règlement. Doit être modifiée pour récupérer les taux en temps réel au lieu de les lire depuis currency_reuters_rate_serialized.

#### _compute_reuters_rate

```python
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
Impact: Méthode calculée qui détermine le taux de change pour une ligne de commande. Doit être adaptée pour obtenir le taux en temps réel si non trouvé dans les données sérialisées.

#### _get_default

```python
def _get_default(self, order):
    order._set_default_settlement_currency()
    # Supprimer l'appel à update_reuters_rate
    # self.env["res.currency"].update_reuters_rate()
    
    # Appeler directement la méthode onchange pour mettre à jour les taux
    order._onchange_currency_reuters_rate_serialized()
    order.write({'pricelist_id': order.authorized_pricelist_ids[0].id})
    order.order_line[0]._set_default_margin_percent()
```
Impact: Méthode appelée lors de la création d'une commande. L'appel à update_reuters_rate() doit être supprimé.

## 6. Configuration système

### Paramètres à modifier
| Paramètre actuel | Nouveau paramètre | Description |
|------------------|-------------------|-------------|
| `loomis_sale.reuters_rate_api` | `loomis_sale.reuters_rate_api_base_url` | URL de base de l'API REST |

### Valeurs suggérées
- Environnement UAT : `https://uat-apps.cprb.fr/crow.api`
- Environnement Production : `https://apps.cprb.fr/crow.api`

## 7. Cron à supprimer

Le cron suivant n'est plus nécessaire car les taux sont maintenant récupérés en temps réel:

```xml
<record id="update_reuters_rate" model="ir.cron">
    <field name="name">Update Reuters Rate</field>
    <field name="priority" eval="5" />
    <field name="interval_number">2</field>
    <field name="interval_type">minutes</field>
    <field name="state">code</field>
    <field name="active" eval="True" />
    <field name="model_id" ref="loomis_order.model_res_currency" />
    <field name="code">model.update_reuters_rate()</field>
</record>
```

## 8. Plan de migration

### Phase 1: Préparation (Environnement de développement)

1. **Mise à jour des fichiers de configuration**
   - Ajouter les nouveaux paramètres d'URL REST tout en conservant les anciens paramètres SOAP
   - Vérifier que les URLs REST sont correctes pour l'environnement de développement

2. **Mise à jour du code**
   - Modifier le fichier `reuters.py` pour utiliser l'API REST
   - Ajouter les nouvelles méthodes au modèle `res.currency`
   - Adapter les méthodes qui utilisent les taux de change
   - Ajouter des logs supplémentaires pour suivre les appels API pendant la phase de test

3. **Tests initiaux**
   - Vérifier que les taux Reuters sont correctement récupérés
   - Vérifier que les commandes existantes continuent de fonctionner
   - Vérifier que les nouvelles commandes obtiennent correctement les taux

### Phase 2: Déploiement en UAT (Test)

1. **Mise à jour des fichiers de configuration**
   - Adapter les URLs REST pour l'environnement UAT
   - Conserver les anciens paramètres SOAP comme fallback

2. **Tests approfondis**
   - Exécuter des tests de charge pour vérifier les performances
   - Vérifier le comportement en cas d'erreur ou d'indisponibilité de l'API
   - Valider les résultats avec les utilisateurs métier

3. **Monitoring**
   - Mettre en place une surveillance spécifique des logs d'erreur liés aux APIs
   - Suivre les temps de réponse des appels API

### Phase 3: Déploiement en Production

1. **Mise à jour des fichiers de configuration**
   - Adapter les URLs REST pour l'environnement de production
   - Conserver temporairement les anciens paramètres SOAP

2. **Déploiement progressif**
   - Déployer d'abord les modifications de code
   - Activer la nouvelle API REST
   - Surveiller attentivement les logs et les performances

3. **Validation finale**
   - Vérifier que toutes les fonctionnalités dépendantes fonctionnent correctement
   - Obtenir la validation des utilisateurs métier

### Phase 4: Nettoyage (après période de stabilité)

1. **Suppression des éléments obsolètes**
   - Supprimer le cron `update_reuters_rate`
   - Supprimer le champ `currency_reuters_rate_serialized`
   - Supprimer les paramètres SOAP devenus inutiles
   - Mettre à jour la documentation

2. **Nettoyage du code**
   - Supprimer les imports inutilisés (zeep)
   - Optimiser le code REST si nécessaire

## 9. Considérations importantes

### Environnements multiples
Les URLs REST doivent être adaptées pour chaque environnement :
- Développement: `https://dev-apps.cprb.fr/crow.api`
- UAT: `https://uat-apps.cprb.fr/crow.api`
- Production: `https://apps.cprb.fr/crow.api`

### Sécurité
- Assurez-vous que les nouvelles URLs utilisent HTTPS
- Vérifiez que les identifiants d'authentification sont correctement gérés et sécurisés
- Validez que les droits d'accès aux nouvelles APIs sont correctement configurés

### Monitoring et alertes
- Configurez des alertes spécifiques pour les erreurs d'API pendant la période de migration
- Suivez les métriques de performance pour détecter d'éventuelles dégradations

### Documentation
- Mettez à jour la documentation technique avec les nouvelles URLs et structures de réponse
- Documentez la procédure de rollback en cas de problème majeur

### Formation
- Informez l'équipe de support des changements effectués
- Préparez-les à diagnostiquer les problèmes potentiels liés aux nouvelles APIs

## 10. Conclusion

Cette migration de SOAP vers REST pour l'API Reuters présente plusieurs avantages :

1. **Simplification** : Code plus lisible et plus facile à maintenir
2. **Performance** : Réduction de la taille des messages et du temps de traitement
3. **Robustesse** : Meilleure gestion des erreurs et des timeouts
4. **Modernisation** : Alignement sur les standards actuels d'API

Le risque est minimisé par la conservation du mécanisme de fallback existant et par le fait que la fonction principale conserve la même signature, ce qui évite tout impact sur le code appelant.

Cette approche progressive minimise les risques tout en permettant une migration complète vers les APIs REST. La conservation temporaire des anciens paramètres offre une possibilité de rollback rapide en cas de problème.
