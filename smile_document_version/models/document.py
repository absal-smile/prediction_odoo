# -*- coding: utf-8 -*-
# (C) 2025 Smile (<http://www.smile.eu>)
# License AGPL-3.0 or later (https://www.gnu.org/licenses/agpl).
from odoo import models, fields, api


class IrAttachment(models.Model):
    _inherit = 'ir.attachment'

    version_number = fields.Integer(readonly=True, string="Version number")

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if 'datas' in vals:
                vals['version_number'] = 1
        records = super().create(vals_list)
        return records

    def write(self, vals):
        res = super().write(vals)
        if vals.get('datas'):
            for attachment in self:
                attachment.version_number += 1
        return res
