import os
import logging
import ssl
import smtplib
import requests
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Primary SMTP Notification Function with Fallback API
def send_email_notification(subject, body, recipient_email, email_notify=True, is_html=False):
    """
    Sends an email notification with a fallback to API if SMTP fails.

    :param subject: The email subject line.
    :param body: The main content of the email.
    :param recipient_email: Email address of the recipient.
    :param email_notify: Boolean, whether to send the email.
    :param is_html: Boolean, if True, sends the email as HTML.
    """
    if not email_notify:
        logging.info("Email notifications are disabled.")
        return

    # Attempt to send via SMTP
    if send_via_smtp(subject, body, recipient_email, is_html):
        return
    else:
        # Fallback to API if SMTP fails
        logging.warning("SMTP failed; attempting to send via fallback API.")
        send_via_api(subject, body, recipient_email, is_html)

# SMTP Send Method
def send_via_smtp(subject, body, recipient_email, is_html):
    sender = os.getenv('MAIL_DEFAULT_SENDER', 'no-reply@yourdomain.com')
    mail_server = os.getenv('MAIL_SERVER')
    mail_port = int(os.getenv('MAIL_PORT', 465))  # Default to SSL port if not specified
    mail_username = os.getenv('MAIL_USERNAME')
    mail_password = os.getenv('MAIL_PASSWORD')

    if not all([sender, mail_server, mail_port, mail_username, mail_password]):
        logging.error("Missing email configuration in environment variables.")
        return False

    # Set up the email message
    msg = MIMEMultipart()
    msg['From'] = sender
    msg['To'] = recipient_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'html' if is_html else 'plain'))

    try:
        context = ssl.create_default_context()
        if mail_port == 465:
            with smtplib.SMTP_SSL(mail_server, mail_port, context=context) as smtp:
                smtp.login(mail_username, mail_password)
                smtp.sendmail(sender, recipient_email, msg.as_string())
                logging.info(f"Email sent successfully via SMTP to {recipient_email}")
                return True
        elif mail_port == 587:
            with smtplib.SMTP(mail_server, mail_port) as smtp:
                smtp.starttls(context=context)
                smtp.login(mail_username, mail_password)
                smtp.sendmail(sender, recipient_email, msg.as_string())
                logging.info(f"Email sent successfully via SMTP to {recipient_email}")
                return True
    except smtplib.SMTPException as e:
        logging.error(f"SMTP failed: {e}")
        return False

# API Fallback Method (e.g., Mailgun)
def send_via_api(subject, body, recipient_email, is_html):
    api_key = os.getenv('MAILGUN_API_KEY')
    domain = os.getenv('MAILGUN_DOMAIN')
    sender = os.getenv('MAILGUN_DEFAULT_SENDER', 'no-reply@your-domain.com')

    if not all([api_key, domain]):
        logging.error("Missing API configuration for fallback email.")
        return

    data = {
        "from": sender,
        "to": [recipient_email],
        "subject": subject,
        "html" if is_html else "text": body,
    }

    try:
        response = requests.post(
            f"https://api.mailgun.net/v3/{domain}/messages",
            auth=("api", api_key),
            data=data
        )
        if response.status_code == 200:
            logging.info(f"Email sent successfully via API to {recipient_email}")
        else:
            logging.error(f"Failed to send email via API: {response.text}")
    except requests.RequestException as e:
        logging.error(f"API request failed: {e}")

# Send migration summary
def send_migration_summary(failed_tables, email_notify, recipient_email):
    """
    Sends a summary email after migration, detailing success or failure of tables.

    :param failed_tables: List of tables that failed migration.
    :param email_notify: Boolean, whether to send email notifications.
    :param recipient_email: Email address for notifications.
    """
    subject = "Database Migration Summary"
    if failed_tables:
        body = "Migration completed with errors. The following tables failed to migrate:\n" + "\n".join(failed_tables)
        logging.error("Some tables failed to migrate. Summary email sent with details.")
    else:
        body = "Migration completed successfully for all tables."
        logging.info("Migration completed successfully. Summary email sent with details.")

    if email_notify and recipient_email:
        send_email_notification(subject, body, recipient_email, email_notify=email_notify)

# Send targeted error notification
def send_error_notification(error_type, table_name, recipient_email, details=None):
    """
    Sends a targeted email notification about a specific migration error.

    :param error_type: Type of error encountered.
    :param table_name: Table related to the error.
    :param recipient_email: Email address to receive the error notification.
    :param details: Additional details about the error.
    """
    subject = f"Migration Error: {error_type} in {table_name}"
    body = f"An error of type '{error_type}' occurred during migration of table '{table_name}'."
    if details:
        body += f"\n\nDetails:\n{details}"
    
    logging.warning(f"Sending error notification for {error_type} in table '{table_name}'")
    send_email_notification(subject, body, recipient_email, email_notify=True)
