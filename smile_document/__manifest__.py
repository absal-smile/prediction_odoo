# -*- coding: utf-8 -*-
# (C) 2025 Smile (<http://www.smile.eu>)
# License AGPL-3.0 or later (https://www.gnu.org/licenses/agpl).


{
    'name': 'Smile Document',
    'version': '18.0.1.0.0',
    'depends': [
        'attachment_indexation',
    ],
    'author': 'Smile',
    'description': """
        Document Management
    """,
    'license': 'AGPL-3',
    'summary': 'Smile Document',
    'website': 'http://www.smile.fr',
    'category': 'Document Management',
    'sequence': 10,
    'data': [
        'views/document_view.xml',
        'views/menus.xml',
        'security/document_security.xml',
        'security/ir.model.access.csv',
        'data/ir_cron.xml',
    ],
    'demo_xml': [],
    'test': [],
    'auto_install': False,
    'installable': True,
    'application': False,
}
