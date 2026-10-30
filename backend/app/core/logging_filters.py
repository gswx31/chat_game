import logging
import re

_TOKEN_RE = re.compile(r"(token=)[^&\s\"']+")


class RedactTokens(logging.Filter):
    """Mask ``token=<JWT>`` in log lines.

    The WebSocket login token travels in the URL query string (``/ws/rooms/{id}?token=…``)
    and uvicorn logs the full request line, which would otherwise write a working login
    token for every player into the server logs.
    """

    def filter(self, record: logging.LogRecord) -> bool:
        message = record.getMessage()
        if "token=" in message:
            record.msg = _TOKEN_RE.sub(r"\1***", message)
            record.args = ()
        return True
