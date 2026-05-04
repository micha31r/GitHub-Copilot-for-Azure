"""Regex-based redaction for ARG content.

Used at the boundary of any external call (web search, doc fetch,
sub-agent prompt) and any logging path that might quote ARG data. Phase
1 sub-agents see only resource type names — never customer ARG content
— but this module is the safety net for the rare case where developer
code accidentally tries to log or transmit raw ARG.

API:
  redact(text: str) -> str
  redact_json(obj: Any) -> Any   # walks dict/list, redacts string leaves
  is_safe(text: str) -> bool     # True if redact(text) == text

Privacy contract: redact() is conservative — it errs on the side of
over-redaction. Callers should never bypass it for "performance".
"""

from __future__ import annotations

import re
from typing import Any, Iterable

# Each pattern produces a single ``[REDACTED:<tag>]`` placeholder so the
# output is still readable for debugging without leaking content.
_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    # Common Azure secret-bearing strings -------------------------------
    (
        "connection-string",
        re.compile(
            r"(?i)\b(?:AccountKey|SharedAccessKey|SharedAccessSignature|"
            r"AccountName|EndpointSuffix|DefaultEndpointsProtocol|"
            r"BlobEndpoint|QueueEndpoint|TableEndpoint|FileEndpoint|"
            r"HostName|DeviceId|ServiceBusEndpoint|EntityPath)\s*=\s*"
            r"[^;\s\"']+"
        ),
    ),
    (
        "sas-token",
        re.compile(
            r"(?i)\?(?:[A-Za-z0-9_\-]+=[^&\s\"']*&){2,}"
            r"sig=[A-Za-z0-9%+/=_\-]+"
        ),
    ),
    (
        "bearer-token",
        re.compile(
            r"(?i)\bBearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+"
        ),
    ),
    (
        "jwt",
        re.compile(r"\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\b"),
    ),
    # Long base64-ish blobs (cert / key material) ------------------------
    (
        "pem-block",
        re.compile(
            r"-----BEGIN [A-Z ]+-----[\s\S]+?-----END [A-Z ]+-----",
            re.MULTILINE,
        ),
    ),
    (
        "long-base64",
        re.compile(r"\b[A-Za-z0-9+/]{80,}={0,2}\b"),
    ),
    # Private endpoint FQDNs ---------------------------------------------
    (
        "privatelink-fqdn",
        re.compile(
            r"\b[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.privatelink\."
            r"[A-Za-z0-9\-.]+\b"
        ),
    ),
    # IPv4 / IPv6 addresses (catch-all; loopback excluded by post-filter)-
    (
        "ipv4",
        re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    ),
    (
        "ipv6",
        re.compile(r"\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}\b"),
    ),
]

# Field-name keywords that, if found as a JSON/YAML key or query string
# parameter, indicate the *value* should be redacted regardless of
# format. Matched case-insensitively against the bare field name.
_SECRET_FIELD_KEYWORDS: tuple[str, ...] = (
    "key",
    "secret",
    "password",
    "passwd",
    "pwd",
    "connectionstring",
    "connection_string",
    "sastoken",
    "sas_token",
    "primarykey",
    "primary_key",
    "secondarykey",
    "secondary_key",
    "token",
    "credential",
    "cert",
    "certificate",
    "thumbprint",
    "fingerprint",
    "principalid",
    "principal_id",
    "objectid",
    "object_id",
    "tenantid",
    "tenant_id",
    "clientid",
    "client_id",
    "clientsecret",
    "client_secret",
)

# IPv4 strings that are never sensitive — keep them in the output.
_IPV4_ALLOWLIST = frozenset(
    {"0.0.0.0", "127.0.0.1", "255.255.255.255", "::1"}
)


def _is_secret_field(name: str) -> bool:
    """True if a field name *looks* like it carries a secret value."""
    bare = re.sub(r"[^a-z0-9]", "", name.lower())
    return any(kw in bare for kw in _SECRET_FIELD_KEYWORDS)


def redact(text: str) -> str:
    """Apply every redaction pattern to ``text`` and return the result.

    Idempotent — calling ``redact(redact(x))`` returns the same string as
    ``redact(x)``. Allowlisted loopback addresses are preserved.
    """
    if not isinstance(text, str) or not text:
        return text

    out = text
    for tag, pattern in _PATTERNS:
        if tag == "ipv4":
            out = pattern.sub(lambda m: m.group(0) if m.group(0) in _IPV4_ALLOWLIST else f"[REDACTED:{tag}]", out)
        elif tag == "ipv6":
            out = pattern.sub(lambda m: m.group(0) if m.group(0) in _IPV4_ALLOWLIST else f"[REDACTED:{tag}]", out)
        else:
            out = pattern.sub(f"[REDACTED:{tag}]", out)
    return out


def redact_json(obj: Any, _path: tuple[str, ...] = ()) -> Any:
    """Recursively walk ``obj`` and redact string leaves.

    For dicts, the *key name* is also inspected: values under
    secret-looking keys (``key``, ``secret``, ``connectionString``, etc.)
    are unconditionally replaced with ``"[REDACTED:secret-field]"`` even
    if the value itself doesn't match any pattern.
    """
    if isinstance(obj, dict):
        return {
            k: (
                "[REDACTED:secret-field]"
                if isinstance(k, str) and _is_secret_field(k) and v is not None and not isinstance(v, (dict, list))
                else redact_json(v, _path + (str(k),))
            )
            for k, v in obj.items()
        }
    if isinstance(obj, list):
        return [redact_json(v, _path) for v in obj]
    if isinstance(obj, str):
        return redact(obj)
    return obj


def is_safe(text: str) -> bool:
    """True if ``text`` survives ``redact`` unchanged."""
    return redact(text) == text


def assert_safe(values: Iterable[str], context: str = "") -> None:
    """Raise ``ValueError`` if any of ``values`` would be redacted.

    Use this as a defence-in-depth check before sending data to a
    sub-agent or external service. Never catches the exception silently.
    """
    for v in values:
        if not is_safe(v):
            preview = (v[:60] + "...") if len(v) > 60 else v
            raise ValueError(
                f"refusing to send unsafe content"
                f"{f' ({context})' if context else ''}: {preview!r}"
            )
