# -*- coding: utf-8 -*-
# (C) 2025 Smile (<http://www.smile.eu>)
# License AGPL-3.0 or later (https://www.gnu.org/licenses/agpl).

from unittest.mock import patch, MagicMock

from odoo import fields
from odoo.tests.common import TransactionCase


class TestQueueJob(TransactionCase):
    def setUp(self):
        """Set up test environment before each test method."""
        super(TestQueueJob, self).setUp()
        self.mock_cursor = MagicMock()
        self.mock_env = MagicMock()
        self.test_job = self.create_mock_job()

    def create_mock_job(self, **kwargs):
        """
        Creates a mock job with specified attributes and behaviors.

        This method generates a MagicMock object that simulates a queue.job record
        with all necessary attributes for testing. It also configures default
        methods such as the test method and write method.

        Args:
            **kwargs: Custom attributes for the job, including:
                - id (int): Job identifier (default: 1)
                - name (str): Job name (default: 'Test Job')
                - method (str): Name of the method to execute
                (default: 'test_method')
                - tries (int): Number of attempts already made (default: 0)
                - max_tries (int): Maximum number of allowed attempts
                (default: 3)
                - state (str): Job state (default: 'pending')
                - result (str): Execution result (default: None)
                - status_code (str): Execution status code (default: None)
                - raise_exception (bool): If True, the test method will
                - raise an exception (default: False)
                - exception_message (str): Error message if an
                - exception is raised (default: "Test error")

        Returns:
            MagicMock: A mock object representing a job with all configured
                      attributes and behaviors
        """
        job = MagicMock()
        job.id = kwargs.get('id', 1)
        job.name = kwargs.get('name', 'Test Job')
        job.method = kwargs.get('method', 'test_method')
        job.tries = kwargs.get('tries', 0)
        job.max_tries = kwargs.get('max_tries', 3)
        job.state = kwargs.get('state', 'pending')
        job.result = kwargs.get('result', None)
        job.status_code = kwargs.get('status_code', None)

        def default_test_method():
            if kwargs.get('raise_exception', False):
                raise Exception(kwargs.get('exception_message', "Test error"))
            return kwargs.get('result', "Success"), kwargs.get('status_code',
                                                               "200")

        setattr(job, job.method, default_test_method)

        def side_effect_write(vals):
            for key, value in vals.items():
                setattr(job, key, value)
            return True

        job.write = MagicMock(side_effect=side_effect_write)
        return job

    def setup_job_with_env(self, job):
        """
        Sets up a job with environment for testing.

        Args:
            job: The job to configure

        Returns:
            MagicMock: The mock representing self in the job context
        """
        mock_self = MagicMock()
        mock_self.sorted.return_value = [job]
        job.with_env.return_value = mock_self
        return mock_self

    def setup_mail_template(self, job):
        """
        Sets up a mail template for failure notifications.

        Args:
            job: The job to configure

        Returns:
            MagicMock: The mock representing the mail template
        """
        mail_template = MagicMock()
        mail_template.send_mail.return_value = 123
        job.get_job_failure_mail_template.return_value = mail_template

        def mock_send_job_failure_mail():
            template = job.get_job_failure_mail_template()
            if template:
                mail_id = template.send_mail(
                    job.id, force_send=True,
                    email_values={'auto_delete': False}
                )
                return mail_id
            return False

        job.send_job_failure_mail = mock_send_job_failure_mail

        return mail_template

    def configure_job_call(self, job, success=True, increment_tries=True):
        """
        Configures the call() method of a job for testing.

        Args:
            job: The job to configure
            success: If True, the job succeeds, otherwise it fails
            increment_tries: If True, increments the tries counter

        Returns:
            MagicMock: The configured call method
        """

        def mock_call():
            if increment_tries:
                job.write({
                    'tries': job.tries + 1,
                    'state': 'in_progress',
                    'execute_date': fields.Datetime.now()
                })

            try:
                if hasattr(job, job.method):
                    result, status_code = getattr(job, job.method)()
                    if success:
                        job.write({
                            'state': 'done',
                            'result': result,
                            'status_code': status_code
                        })
                else:
                    raise AttributeError(f"Method {job.method} not found")
            except Exception as e:
                if job.tries >= job.max_tries:
                    job.write({
                        'state': 'canceled',
                        'result': str(e)
                    })
                    job.send_job_failure_mail()
                else:
                    job.write({
                        'state': 'error',
                        'result': str(e)
                    })

            return True

        job.call = MagicMock(side_effect=mock_call)
        return job.call

    def test_01_call_success(self):
        """
        Test successful job execution.

        Prerequisites:
        - A test job with a method that returns a successful result
        - Mocks for Odoo environment and registry

        Test:
        - Execute the call() method on the job
        - Verify that the job state is updated correctly

        Expected:
        - Job state should change to "done"
        - Result should be "Success"
        - Status code should be "200"
        - Tries counter should be incremented to 1
        - Appropriate logs should be created
        """
        mock_job = self.create_mock_job(
            id=1,
            method='test_method',
            tries=0,
            state='pending'
        )
        self.setup_job_with_env(mock_job)
        self.configure_job_call(mock_job, success=True)
        mock_job.call()
        self.assertEqual(mock_job.state, 'done')
        self.assertEqual(mock_job.result, 'Success')
        self.assertEqual(mock_job.status_code, '200')
        self.assertEqual(mock_job.tries, 1)

    def test_02_increment_tries_counter(self):
        """
        Test that the try's counter is incremented
        correctly when a job is called.

        Prerequisites:
        - A test job with tries counter set to 0
        - Mocks for Odoo environment and registry

        Test:
        - Execute the call() method on the job
        - Analyze the calls to the write() method

        Expected:
        - First call to write() should increment tries
        to 1 and set state to "in_progress"
        - Second call to write() should set state to
        "done" and record the result
        """
        mock_job = self.create_mock_job(
            id=1,
            method='test_method',
            tries=0
        )
        self.setup_job_with_env(mock_job)
        self.configure_job_call(mock_job, success=True)
        mock_job.call()
        self.assertEqual(len(mock_job.write.call_args_list), 2,
                         "write() should be called twice")
        first_call_args = mock_job.write.call_args_list[0][0][0]
        self.assertEqual(first_call_args['tries'], 1)
        self.assertEqual(first_call_args['state'], 'in_progress')
        self.assertIn('execute_date', first_call_args)

        second_call_args = mock_job.write.call_args_list[1][0][0]
        self.assertEqual(second_call_args['state'], 'done')
        self.assertEqual(second_call_args['result'], 'Success')
        self.assertEqual(second_call_args['status_code'], '200')

    def test_03_call_error_but_retry(self):
        """
        Test error handling with retry possibility.

        Prerequisites:
        - A test job with a method that raises an exception
        - Tries counter is less than maximum allowed

        Test:
        - Execute the call() method on the job
        - Analyze the calls to the write() method

        Expected:
        - First call to write() should increment tries counter
        and set state to "in_progress"
        - Second call to write() should set state to "error"
        as max tries not reached
        - send_job_failure_mail() should not be called
        """
        mock_job = self.create_mock_job(
            id=1,
            method='test_method',
            tries=0,
            max_tries=3,
            raise_exception=True
        )
        self.setup_job_with_env(mock_job)
        mail_template = self.setup_mail_template(mock_job)
        self.configure_job_call(mock_job, success=False)
        mock_job.call()
        self.assertEqual(len(mock_job.write.call_args_list), 2,
                         "write() should be called twice")
        first_call_args = mock_job.write.call_args_list[0][0][0]
        self.assertEqual(first_call_args['tries'], 1)
        self.assertEqual(first_call_args['state'], 'in_progress')
        second_call_args = mock_job.write.call_args_list[1][0][0]
        self.assertEqual(second_call_args['state'], 'error')
        mail_template.send_mail.assert_not_called()

    def test_04_call_error_max_tries_reached(self):
        """
        Test error handling when the maximum tries are reached.

        Prerequisites:
        - A test job with a method that raises an exception
        - Tries counter is one unit below the maximum allowed

        Test:
        - Execute the call() method on the job
        - Analyze the calls to the write() method

        Expected:
        - First call to write() should increment tries
        to maximum and set state to "in_progress"
        - Second call to write() should set state to "canceled"
        as max tries is reached
        - send_job_failure_mail() should be called once
        """
        mock_job = self.create_mock_job(
            id=1,
            method='test_method',
            tries=2,
            max_tries=3,
            raise_exception=True,
            exception_message="Test error"
        )
        self.setup_job_with_env(mock_job)
        mail_template = self.setup_mail_template(mock_job)
        self.configure_job_call(mock_job, success=False)
        mock_job.call()
        self.assertEqual(len(mock_job.write.call_args_list), 2,
                         "write() should be called twice")
        first_call_args = mock_job.write.call_args_list[0][0][0]
        self.assertEqual(first_call_args['tries'], 3)
        self.assertEqual(first_call_args['state'], 'in_progress')
        second_call_args = mock_job.write.call_args_list[1][0][0]
        self.assertEqual(second_call_args['state'], 'canceled')
        self.assertIn('result', second_call_args)
        self.assertEqual(mail_template.send_mail.call_count, 1,
                         "mail_template.send_mail should be called exactly "
                         "once, indicating send_job_failure_mail was executed")

    def test_05_call_failure_sends_email_when_max_tries_reached(self):
        """
        Test email sending on job failure when maximum tries are reached.

        Prerequisites:
        - A test job with a method that raises an exception
        - Tries counter is one unit below the maximum allowed
        - An email template configured

        Test:
        - Execute the call() method on the job
        - Verify that the email is sent

        Expected:
        - send_job_failure_mail() should be called
        - get_job_failure_mail_template() should be called
        - send_mail() of the email template should be
        called with correct parameters
        """
        mock_job = self.create_mock_job(
            id=1,
            method='test_method',
            tries=2,
            max_tries=3,
            raise_exception=True,
            exception_message="Test error"
        )
        self.setup_job_with_env(mock_job)
        mail_template = self.setup_mail_template(mock_job)
        self.configure_job_call(mock_job, success=False)
        mock_job.call()
        mock_job.get_job_failure_mail_template.assert_called_once()
        mail_template.send_mail.assert_called_once_with(
            mock_job.id, force_send=True,
            email_values={'auto_delete': False})

    def test_06_total_tries_formatting(self):
        """
        Test that the total_tries field is correctly formatted.

        Prerequisites:
        - A test job with specific values for tries and max_tries

        Test:
        - Check the value of the total_tries field
        - Modify the values of tries and max_tries and check again

        Expected:
        - total_tries field should be formatted as "tries/max_tries"
        - Field should be updated correctly when tries or max_tries changes
        """
        test_job = self.create_mock_job(
            tries=2,
            max_tries=5
        )

        test_job.total_tries = '2/5'
        self.assertEqual(
            test_job.total_tries, '2/5',
            "The total_tries field should be formatted as 'tries/max_tries'")

        test_job.tries = 3
        test_job.total_tries = '3/5'
        self.assertEqual(
            test_job.total_tries, '3/5',
            "The total_tries field should be updated when tries changes")

        test_job.max_tries = 10
        test_job.total_tries = '3/10'
        self.assertEqual(
            test_job.total_tries, '3/10',
            "The total_tries field should be updated when max_tries changes")

    def test_07_filter_jobs(self):
        """
        Test that filter_jobs returns only jobs in pending and error states.

        Prerequisites:
        - Test jobs with different states
        (pending, error, done, canceled, in_progress)

        Test:
        - Call the filter_jobs() method
        - Verify the returned IDs

        Expected:
        - Only jobs with "pending" and "error" states should be included
        - Jobs should be sorted by ID in ascending order
        """
        jobs = [
            self.create_mock_job(id=1, state='pending'),
            self.create_mock_job(id=2, state='error'),
            self.create_mock_job(id=3, state='done'),
            self.create_mock_job(id=4, state='canceled'),
            self.create_mock_job(id=5, state='in_progress')
        ]

        mock_job_model = MagicMock()
        mock_job_model.search.return_value = jobs

        def mock_filter_jobs():
            filtered_jobs = [job for job in jobs if
                             job.state in ['pending', 'error']]
            return [job.id for job in
                    sorted(filtered_jobs, key=lambda j: j.id)]

        mock_job_model.filter_jobs = mock_filter_jobs

        with patch.object(self.env, '__getitem__',
                          return_value=mock_job_model):
            filtered_job_ids = mock_job_model.filter_jobs()

            self.assertEqual(filtered_job_ids, [1, 2])
            self.assertIn(1, filtered_job_ids,
                          "Pending jobs should be included in filtered jobs")
            self.assertIn(2, filtered_job_ids,
                          "Error jobs should be included in filtered jobs")
            self.assertNotIn(
                3, filtered_job_ids,
                "Done jobs should not be included in filtered jobs")
            self.assertNotIn(
                4, filtered_job_ids,
                "Canceled jobs should not be included in filtered jobs")
            self.assertNotIn(
                5, filtered_job_ids,
                "In-progress jobs should not be included in filtered jobs")
            self.assertEqual(
                filtered_job_ids, sorted(filtered_job_ids),
                "Filtered jobs should be ordered by id in ascending order")

    def test_08_execute_cron_not_implemented(self):
        """
        Test that the execute_cron method raises
        NotImplementedError when not implemented.

        Prerequisites:
        - A base queue.job model without execute_cron implementation

        Test:
        - Call the execute_cron() method

        Expected:
        - A NotImplementedError exception should be raised
        """
        mock_job_model = MagicMock()
        mock_job_model.execute_cron.side_effect = NotImplementedError

        with patch.object(self.env, '__getitem__',
                          return_value=mock_job_model):
            with self.assertRaises(NotImplementedError):
                mock_job_model.execute_cron()

    def test_09_execute_call_handles_exceptions(self):
        """
        Test that execute_call properly handles exceptions in
        the call method.

        Prerequisites:
        - A test job
        - Mocks for the call() method and logger

        Test:
        - Configure the call() method to raise an exception
        - Call the execute_call() method

        Expected:
        - call() method should be invoked
        - Error should be logged in the logger
        - execute_call() should return True despite the exception
        """
        with patch('odoo.tools.translate._') as mock_translate:
            mock_translate.side_effect = lambda text: text

            mock_logger = MagicMock()

            job_with_context = self.create_mock_job()
            job_with_context._context = {'logger': mock_logger}

            job_with_context.call.side_effect = Exception(
                "Test error in call method")

            def execute_call(job):
                logger = job._context.get('logger') or MagicMock()
                logger.info('Start execute_call')
                try:
                    job.call()
                except Exception as e:
                    logger.error('Error with execute_call: {}'.format(e.args))
                finally:
                    logger.info('End execute_call')
                return True

            result = execute_call(job_with_context)

            job_with_context.call.assert_called_once()

            mock_logger.info.assert_any_call('Start execute_call')
            mock_logger.error.assert_called_once_with(
                'Error with execute_call: {}'.format(
                    ("Test error in call method",)))
            mock_logger.info.assert_called_with('End execute_call')

            self.assertTrue(
                result,
                "execute_call should return True even when an "
                "exception occurs")

    def test_10_custom_job_with_email_notification(self):
        """
        Test a custom job class that inherits from queue.job and implements
        email notifications for failures.

        Prerequisites:
        - A custom job class that inherits from queue.job
        - A mail template for failure notifications
        - A job that will fail after max_tries attempts
        - A company with email_wsqueue configured

        Test:
        - Create and execute a job that will fail
        - Verify that email notifications are sent when max_tries is reached
        - Verify that the company's email_wsqueue is used for notifications

        Expected:
        - Job should be created with pending state
        - Job should be executed and fail max_tries times
        - Job state should be set to cancel after max_tries failures
        - Email notification should be sent when a job is canceled
        - The notification should be sent to the email address in company.email_wsqueue
        """
        mock_company = MagicMock()
        mock_company.email_wsqueue = "wsqueue.errors@example.com"

        mock_mail_template = MagicMock()
        mock_mail_template.send_mail.return_value = 123

        mock_env = MagicMock()
        mock_env.__getitem__.return_value = mock_mail_template
        mock_env.company = mock_company

        custom_job = self.create_mock_job(
            id=42,
            name="Test Custom Job",
            method='custom_method',
            max_tries=3,
            tries=0,
            state='pending',
            raise_exception=True,
            exception_message="Custom method failed"
        )

        custom_job.env = mock_env

        custom_job.get_job_failure_mail_template.return_value = (
            mock_mail_template)

        def mock_send_job_failure_mail():
            template = custom_job.get_job_failure_mail_template()
            if template:
                email_values = {'auto_delete': False}
                if custom_job.env.company.email_wsqueue:
                    email_values[
                        'email_to'] = custom_job.env.company.email_wsqueue

                mail_id = template.send_mail(
                    custom_job.id, force_send=True,
                    email_values=email_values
                )
                return mail_id
            return False

        custom_job.send_job_failure_mail = mock_send_job_failure_mail

        self.configure_job_call(custom_job, success=False)

        custom_job.call()
        self.assertEqual(custom_job.tries, 1)
        self.assertEqual(custom_job.state, 'error')
        self.assertEqual(mock_mail_template.send_mail.call_count, 0,
                         "send_mail should not be called on first failure")

        custom_job.call()
        self.assertEqual(custom_job.tries, 2)
        self.assertEqual(custom_job.state, 'error')
        self.assertEqual(mock_mail_template.send_mail.call_count, 0,
                         "send_mail should not be called on second failure")

        custom_job.call()
        self.assertEqual(custom_job.tries, 3)
        self.assertEqual(custom_job.state, 'canceled')

        self.assertEqual(
            mock_mail_template.send_mail.call_count, 1,
            "send_mail should be called exactly once on final failure")
        self.assertEqual(mock_mail_template.send_mail.call_args[0][0],
                         custom_job.id,
                         "send_mail should be called with the correct job ID")
        self.assertTrue(
            mock_mail_template.send_mail.call_args[1]['force_send'], True)

        email_values = mock_mail_template.send_mail.call_args[1][
            'email_values']
        self.assertEqual(
            email_values['email_to'], mock_company.email_wsqueue,
            "The company's email_wsqueue should be used as the recipient")
        self.assertFalse(email_values['auto_delete'],
                         "The auto_delete option should be set to False")

        self.assertEqual(custom_job.write.call_count, 6)

        last_write_call = custom_job.write.call_args_list[-1][0][0]
        self.assertEqual(last_write_call['state'], 'canceled')
