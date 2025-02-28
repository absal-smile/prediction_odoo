.. |badge1| image:: https://img.shields.io/badge/licence-AGPL--3-blue.svg
    :alt: License: AGPL-3

.. |badge2| image:: https://img.shields.io/badge/github-Smile--SA%2Fodoo_addons-lightgray.png?logo=github
    :target: https://github.com/Smile-SA/odoo_addons/tree/18.0/smile_ux_feedback
    :alt: Smile-SA/odoo_addons

|badge1| |badge2|

==================
Smile UX Feedback
==================

The `ux_feedback` module is designed to collect user feedback on various aspects of the Odoo back office. It provides an easy-to-use interface for users to submit their performance, conformity, satisfaction ratings, and additional feedback.

## Features
============

- Icon integration: A thumbs-up icon `<i class="fa fa-thumbs-up"></i>` is displayed on each page of the back office.
- Feedback pop-up: Users can input their feedback through a modal that collects:
  - Performance (Many2one)
  - Conformity (Many2one)
  - Satisfaction (Many2one)
  - Feedback (free text)
- Pre-filled fields:
  - User
  - Timestamp
  - URL (with the name of the concerned view)

## Installation
================

1. Clone the repository or download the module files.
2. Place the `ux_feedback` directory in your Odoo addons path.
3. Update the app list in Odoo.
4. Install the `ux_feedback` module from the Odoo apps interface.

## Usage
========

Once installed, the thumbs-up icon will appear on every page of the back office. Clicking the icon will open a pop-up modal where users can provide their feedback. All submitted feedback will be stored and can be reviewed by administrators.

## Contributing
===============

Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## Maintainer
=============

This module is maintained by Smile SA.

Since 1991 Smile has been a pioneer of technology and also the European expert in open source solutions.
