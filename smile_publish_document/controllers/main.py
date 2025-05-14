# -*- coding: utf-8 -*-
# (C) 2025 Smile (<http://www.smile.eu>)
# License AGPL-3.0 or later (https://www.gnu.org/licenses/agpl).
import base64

from odoo import http, _
from odoo.http import request
from werkzeug.utils import redirect


class WebsiteAttachmentPage(http.Controller):

    def get_attachments(self):
        attachment_ids = request.env['ir.attachment'].sudo().search(
            [('website_published', '=', True)])
        documents = {}
        for record in attachment_ids:
            document_type = record.document_type_id and record.document_type_id.name or _('Others')  # noqa E501
            if document_type in documents:
                documents[document_type].append(record)
            else:
                vals = {document_type: [record]}
                documents.update(vals)
        return documents

    @http.route('/Attachments', type='http', auth="public", website=True)
    def attachment_details(self, **kw):
        return request.render('smile_publish_document.attachment_template',
                              {'attachments': self.get_attachments()})

    @http.route(['/attachment/download'], type='http', auth='public')
    def download_attachment(self, attachment_id, **kw):
        fields = ["store_fname",
                  "datas",
                  "mimetype",
                  "res_model",
                  "res_id",
                  "type",
                  "url"]
        attachment = request.env['ir.attachment'].sudo().search_read(
            [('id', '=', int(attachment_id))], fields)
        if not attachment:
            return redirect('/Attachments')
        attachment = attachment[0]
        if attachment["type"] == "url":
            if attachment["url"]:
                return redirect(attachment["url"])
            else:
                return request.not_found()
        if attachment["datas"]:
            data = base64.b64decode(attachment["datas"])
            response = request.make_response(data, [
                ('Content-Type',
                 attachment['mimetype'] or 'application/octet-stream'),
                ('Content-Disposition',
                 f'attachment; filename="{attachment["store_fname"]}"'),
            ])
            return response
