.. |badge1| image:: https://img.shields.io/badge/licence-AGPL--3-blue.svg
    :alt: License: AGPL-3

.. |badge2| image:: https://img.shields.io/badge/github-Smile--SA%2Fodoo_addons-lightgray.png?logo=github
    :target: https://github.com/Smile-SA/odoo_addons/tree/18.0/smile_wsqueue
    :alt: Smile-SA/odoo_addons

|badge1| |badge2|

================
Smile WSQueue
================

This module provides a job queue system for managing asynchronous tasks in Odoo. It allows you to define, execute, and monitor jobs with retry mechanisms and error handling.

.. contents:: Table of contents
   :local:

Requirements
============

This module depends on the following modules:

- base
- mail

Usage
=====

To use this module, follow these steps:

1. **Define a job by inheriting the `Job` model:**
   - Create a new model that inherits from `Job`.
   - Implement your custom logic in the job execution method.

   Example:
   .. code-block:: python

      class MyJob(models.Model):
          _inherit = 'queue.job'

          def my_custom_method(self):
              # Your custom logic here
              return "Success", 200

2. **Send email notifications for failed jobs:**
   - Override the `get_job_failure_mail_template` method to define a custom email template for job failure notifications.

3. **Monitor the job queue:**
   - Use the Odoo backend to monitor the status of jobs in the queue.

Configuration
=============

To configure this module:

1. Ensure that the email server is properly configured in Odoo.
2. Define a mail template for job failure notifications by overriding the `get_job_failure_mail_template` method.

Bug Tracker
===========

Bugs are tracked on `GitHub Issues <https://github.com/Smile-SA/odoo_addons/issues>`_.
In case of trouble, please check there if your issue has already been reported.
If you spotted it first, help us smash it by providing detailed and welcomed feedback
`here <https://github.com/Smile-SA/odoo_addons/issues/new?body=module:%20smile_wsqueue%0Aversion:%2018.0%0A%0A**Steps%20to%20reproduce**%0A-%20...%0A%0A**Current%20behavior**%0A%0A**Expected%20behavior**>`_.

Do not contact contributors directly about support or help with technical issues.

Credits
=======

Contributors
------------

Smile SA Development Team

Maintainer
----------

This module is maintained by Smile SA.

Since 1991 Smile has been a pioneer of technology and also the European expert in open source solutions.
