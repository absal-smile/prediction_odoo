# -*- coding: utf-8 -*-

import logging

_logger = logging.getLogger(__name__)


def post_init(env):
    """Post-init hook called by Odoo after module installation."""
    save_installed_checksums(env)


def save_installed_checksums(env):
    """Save checksums of all installed modules."""
    IrModuleModule = env['ir.module.module']
    # TODO: save checksum only if module is installed *after*
    # database initialization via smile_upgrade
    _logger.info("Save checksums of all installed modules...")
    IrModuleModule._save_installed_checksums()
    _logger.info("Checksums of all installed modules saved.")
