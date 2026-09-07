#!/usr/bin/env python3
"""Read-only GiveChain Mobile API smoke test based on the backend guide.

Credentials are read from environment variables or requested interactively.
No token/password is written to disk. The script never calls create/update/delete
endpoints; it only logs in and executes documented GET endpoints.
"""
from __future__ import annotations

import getpass
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any

BASE = os.getenv("GIVECHAIN_BASE_URL", "https://givechain.runasp.net").rstrip("/")
EMAIL = os.getenv("GIVECHAIN_TEST_EMAIL", "")
USERNAME = os.getenv("GIVECHAIN_TEST_USERNAME", "")
PASSWORD = os.getenv("GIVECHAIN_TEST_PASSWORD", "")
TIMEOUT = int(os.getenv("GIVECHAIN_HTTP_TIMEOUT", "30"))
INSECURE = os.getenv("GIVECHAIN_INSECURE_TLS", "0") == "1"
CONTEXT = ssl._create_unverified_context() if INSECURE else ssl.create_default_context()


@dataclass(frozen=True)
class Check:
    name: str
    path: str
    auth: bool = False


def request(method: str, path: str, *, body: Any = None, token: str = "") -> tuple[int, Any]:
    url = f"{BASE}/{path.lstrip('/')}"
    payload = None
    headers = {"Accept": "application/json, text/plain, */*", "User-Agent": "GiveChain-Mobile-Smoke/2.0"}
    if body is not None:
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=payload, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=CONTEXT) as res:
            raw = res.read().decode("utf-8", errors="replace")
            return res.status, decode(raw)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        return exc.code, decode(raw)
    except urllib.error.URLError as exc:
        return 0, {
            "isSuccess": False,
            "message": f"Network error: {exc.reason}",
            "errors": [str(exc.reason)],
        }


def decode(text: str) -> Any:
    text = text.strip()
    if not text:
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return text


def envelope_ok(payload: Any) -> tuple[bool, str]:
    if not isinstance(payload, dict):
        return True, "non-envelope response"
    if "isSuccess" not in payload:
        return True, "response without isSuccess"
    if payload.get("isSuccess") is True:
        return True, "isSuccess=true"
    errors = payload.get("errors")
    message = payload.get("message") or "isSuccess=false"
    if errors:
        message = f"{message}: {errors}"
    return False, str(message)


def main() -> int:
    global EMAIL, USERNAME, PASSWORD
    if not EMAIL and not USERNAME:
        EMAIL = input("Test email (or leave empty to use username): ").strip()
        if not EMAIL:
            USERNAME = input("Test username: ").strip()
    if not PASSWORD:
        PASSWORD = getpass.getpass("Test password: ")

    status, login = request(
        "POST",
        "/api/mobile/auth/login",
        body={"email": EMAIL, "userName": USERNAME, "password": PASSWORD},
    )
    ok, detail = envelope_ok(login)
    data = login.get("data") if isinstance(login, dict) else None
    token = data.get("token", "") if isinstance(data, dict) else ""
    print(f"{'PASS' if 200 <= status < 300 and ok and token else 'FAIL'} login HTTP {status}: {detail}")
    if not (200 <= status < 300 and ok and token):
        return 1

    public = [
        Check("home", "/api/mobile/home"),
        Check("campaigns", "/api/mobile/campaigns?page=1&pageSize=2"),
        Check("cases", "/api/mobile/cases?page=1&pageSize=2"),
        Check("charities", "/api/mobile/charities?page=1&pageSize=2"),
        Check("countries", "/api/lookup/countries"),
        Check("cities", "/api/lookup/cities"),
        Check("case categories", "/api/lookup/case-categories"),
        Check("campaign types", "/api/lookup/campaign-types"),
        Check("registration info fields", "/api/mobile/auth/info-fields"),
        Check("version", "/api/version"),
    ]
    protected = [
        Check("profile", "/api/mobile/profile", True),
        Check("profile info answers", "/api/mobile/profile/info-answers", True),
        Check("my donations", "/api/mobile/donations?page=1&pageSize=2", True),
        Check("all donation trace", "/api/mobile/donations/trace", True),
        Check("my benefits", "/api/mobile/benefits?page=1&pageSize=2", True),
        Check("my complaints", "/api/mobile/complaints?page=1&pageSize=2", True),
        Check("notifications", "/api/mobile/notifications?page=1&pageSize=2", True),
        Check("unread count", "/api/mobile/notifications/unread-count", True),
    ]

    failures = 0
    payloads: dict[str, Any] = {}
    for check in [*public, *protected]:
        status, payload = request("GET", check.path, token=token if check.auth else "")
        ok, detail = envelope_ok(payload)
        passed = 200 <= status < 300 and ok
        print(f"{'PASS' if passed else 'FAIL'} {check.name:<28} HTTP {status}: {detail}")
        if not passed:
            failures += 1
        payloads[check.name] = payload

    # Read documented detail/nested endpoints using ids returned by list calls.
    dynamic: list[Check] = []
    for key, base in (("campaigns", "/api/mobile/campaigns"), ("cases", "/api/mobile/cases"), ("charities", "/api/mobile/charities")):
        item_id = first_id(payloads.get(key))
        if not item_id:
            continue
        dynamic.append(Check(f"{key} detail", f"{base}/{urllib.parse.quote(item_id)}"))
        if key == "charities":
            encoded = urllib.parse.quote(item_id)
            dynamic.extend([
                Check("charity campaigns", f"/api/mobile/charities/{encoded}/campaigns?page=1&pageSize=2"),
                Check("charity cases", f"/api/mobile/charities/{encoded}/cases?page=1&pageSize=2"),
                Check("charity benefit types", f"/api/mobile/charities/{encoded}/benefit-types"),
            ])
    for check in dynamic:
        status, payload = request("GET", check.path)
        ok, detail = envelope_ok(payload)
        passed = 200 <= status < 300 and ok
        print(f"{'PASS' if passed else 'FAIL'} {check.name:<28} HTTP {status}: {detail}")
        if not passed:
            failures += 1

    print(f"\nRead-only checks complete: {failures} failure(s). No write operation was executed.")
    return 1 if failures else 0


def first_id(payload: Any) -> str:
    if not isinstance(payload, dict):
        return ""
    data = payload.get("data")
    items = data.get("items") if isinstance(data, dict) else data
    if isinstance(items, list) and items and isinstance(items[0], dict):
        return str(items[0].get("id") or "")
    return ""


if __name__ == "__main__":
    raise SystemExit(main())
