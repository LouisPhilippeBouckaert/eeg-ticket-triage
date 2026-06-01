"""Voorbeeld QA-connectie helper voor de ticket-triage agent.

Kopieer naar conn.py en lever credentials aan via omgevingsvariabelen of een
lokale config.py. COMMIT conn.py / config.py NOOIT (zie .gitignore).
"""
import os
import ssl
import xmlrpc.client

# Lees uit omgevingsvariabelen (of vervang door je lokale config-import).
URL = os.environ.get("ODOO_QA_URL", "https://odoo-qa.eeg.be")
DB = os.environ.get("ODOO_QA_DB", "")          # roteert maandelijks; zie list_databases()
USER = os.environ.get("ODOO_USER", "")
PWD = os.environ.get("ODOO_PASSWORD", "")

_ctx = ssl.create_default_context()


def list_databases():
    """De QA DB-naam roteert maandelijks; vraag de lijst dynamisch op."""
    db_proxy = xmlrpc.client.ServerProxy(f"{URL}/xmlrpc/2/db", context=_ctx)
    return db_proxy.list()


def connect():
    common = xmlrpc.client.ServerProxy(f"{URL}/xmlrpc/2/common", context=_ctx)
    uid = common.authenticate(DB, USER, PWD, {})
    if not uid:
        raise RuntimeError("Authenticatie mislukt - controleer credentials/DB-naam")
    models = xmlrpc.client.ServerProxy(f"{URL}/xmlrpc/2/object", context=_ctx)

    def execute(model, method, *args, **kw):
        return models.execute_kw(DB, uid, PWD, model, method, list(args), kw)

    return uid, execute


if __name__ == "__main__":
    print("Beschikbare databases:", list_databases())
    uid, execute = connect()
    print("Auth OK, uid =", uid)
