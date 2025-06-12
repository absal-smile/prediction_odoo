# -*- coding: utf-8 -*-
# (C) 2025 Smile (<http://www.smile.eu>)
# License AGPL-3.0 or later (https://www.gnu.org/licenses/agpl).

{
    'name': 'Smile Document Version',
    'version': '18.0.0.0.0',
    'depends': [
        'smile_document'
    ],
    'author': 'Smile',
    'description': """
        Display document version
    """,
    'summary': 'Smile Document Version',
    'website': 'http://www.smile.fr',
    'category': 'Document Management',
    'sequence': 10,
    'data': [
        'views/document_view.xml',
    ],
    'demo_xml': [],
    "images": ["static/description/banner.gif"],
    'test': [],
    'auto_install': False,
    'installable': True,
    'application': False,
    'license': 'AGPL-3',
}
