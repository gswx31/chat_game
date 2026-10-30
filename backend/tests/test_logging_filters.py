import logging

from app.core.logging_filters import RedactTokens

JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.signature_part"


def _record(fmt: str, *args: object) -> logging.LogRecord:
    return logging.LogRecord("uvicorn", logging.INFO, "", 0, fmt, args, None)


def test_masks_the_token_in_a_uvicorn_access_line():
    rec = _record(
        '%s - "%s %s HTTP/%s" %d', "1.2.3.4:0", "GET", f"/ws/rooms/abc?token={JWT}", "1.1", 200
    )
    assert RedactTokens().filter(rec) is True
    out = rec.getMessage()
    assert JWT not in out and "eyJ" not in out
    assert "/ws/rooms/abc?token=***" in out


def test_masks_the_token_in_the_websocket_accepted_line():
    rec = _record('%s - "WebSocket %s" [accepted]', "1.2.3.4:0", f"/ws/rooms/abc?token={JWT}")
    RedactTokens().filter(rec)
    assert JWT not in rec.getMessage()
    assert rec.getMessage().endswith("[accepted]")


def test_keeps_other_query_parameters():
    rec = _record("GET %s", f"/ws/rooms/abc?token={JWT}&v=2")
    RedactTokens().filter(rec)
    assert rec.getMessage() == "GET /ws/rooms/abc?token=***&v=2"


def test_leaves_unrelated_lines_untouched():
    rec = _record("GET %s %d", "/questions/count", 200)
    RedactTokens().filter(rec)
    assert rec.getMessage() == "GET /questions/count 200"
    assert rec.args == ("/questions/count", 200)
