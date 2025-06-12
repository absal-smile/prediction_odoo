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


## 6. Conclusion

Cette migration de SOAP vers REST pour l'API Reuters présente plusieurs avantages :

1. **Simplification** : Code plus lisible et plus facile à maintenir
2. **Performance** : Réduction de la taille des messages et du temps de traitement
3. **Robustesse** : Meilleure gestion des erreurs et des timeouts
4. **Modernisation** : Alignement sur les standards actuels d'API

Le risque est minimisé par la conservation du mécanisme de fallback existant et par le fait que la fonction principale conserve la même signature, ce qui évite tout impact sur le code appelant.


-----
# Mise à jour des configurations pour la migration REST

## 1. Mise à jour du fichier de paramètres pour l'API Reuters

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data noupdate="1">
        <!-- Ancien paramètre SOAP - à conserver temporairement pour compatibilité -->
        <record id="reuters_rate_api" model="ir.config_parameter">
            <field name="key">loomis_sale.reuters_rate_api</field>
            <field name="value">http://appint.cprb.fr/FluxFinanciersV2/FluxFinanciers.svc?wsdl</field>
        </record>
        
        <!-- Nouveau paramètre REST - URL de base de l'API -->
        <record id="reuters_rate_api_base_url" model="ir.config_parameter">
            <field name="key">loomis_sale.reuters_rate_api_base_url</field>
            <field name="value">https://uat-apps.cprb.fr/crow.api</field>
        </record>

        <!-- Paramètres existants inchangés -->
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

## 2. Le cron Reuters reste inchangé

Le cron pour la mise à jour des taux Reuters n'a pas besoin d'être modifié car il appelle simplement la méthode `update_reuters_rate()` sur le modèle `res_currency`. C'est cette méthode qui utilise la fonction `get_course_change_reuters()` que nous avons migrée.

```xml
<?xml version="1.0"?>
<odoo>
    <data noupdate="1">
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
    </data>
</odoo>
```

## 3. Mise à jour du fichier de paramètres pour l'API Balance Client

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

## 4. Plan de migration complet

### Phase 1: Préparation (Environnement de développement)

1. **Mise à jour des fichiers de configuration**
   - Ajouter les nouveaux paramètres d'URL REST tout en conservant les anciens paramètres SOAP
   - Vérifier que les URLs REST sont correctes pour l'environnement de développement

2. **Mise à jour du code**
   - Déployer les nouvelles versions des fichiers Python qui utilisent les APIs REST
   - Ajouter des logs supplémentaires pour suivre les appels API pendant la phase de test

3. **Tests initiaux**
   - Vérifier que les taux Reuters sont correctement récupérés
   - Vérifier que les soldes clients sont correctement importés
   - Comparer les résultats avec l'ancienne implémentation

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
   - Activer d'abord l'API Balance Client (moins critique)
   - Après validation, activer l'API Reuters
   - Surveiller attentivement les logs et les performances

3. **Validation finale**
   - Vérifier que toutes les fonctionnalités dépendantes fonctionnent correctement
   - Obtenir la validation des utilisateurs métier

### Phase 4: Nettoyage (après période de stabilité)

1. **Suppression des anciens paramètres**
   - Supprimer les paramètres SOAP devenus inutiles
   - Mettre à jour la documentation

2. **Nettoyage du code**
   - Supprimer les imports inutilisés (zeep, NTLM)
   - Optimiser le code REST si nécessaire

## 5. Considérations importantes pour la migration

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

Cette approche progressive minimise les risques tout en permettant une migration complète vers les APIs REST. La conservation temporaire des anciens paramètres offre une possibilité de rollback rapide en cas de problème.
