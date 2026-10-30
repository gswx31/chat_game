"""WebSocket message protocol.

All messages are JSON objects with a ``type`` field. Clients connect to
``/ws/rooms/{room_id}?token=<JWT>``.

Client -> Server
----------------
- ``{ "type": "chat", "text": "..." }``
  Free chat. Server also tests the text against current question's answer.
  The text "스킵" (or its 초성 "ㅅㅋ") is not an answer but a vote to skip the question.
- ``{ "type": "start_game" }``
  Owner only; transitions room from waiting -> playing.
- ``{ "type": "skip" }``
  Vote to skip current round. It passes when MORE than half of the room voted (two players
  must both agree).

Server -> Client
----------------
- ``room_state``: full snapshot on connect.
- ``player_join`` / ``player_leave``
- ``chat`` echo
- ``game_start``
- ``round_start`` { round, prompt, category, difficulty, deadline_ts }
- ``hint`` { round, hint }
- ``skip_progress`` { votes, needed }
- ``correct`` { round, user_id, nickname, answer }
- ``round_end`` { round, reason: "timeout"|"skipped", answer }
- ``score_update`` { scores: [{user_id, nickname, score}, ...] }
- ``game_over`` { scores, winner_id }
- ``error`` { message }
"""

# Client -> Server
C_CHAT = "chat"
C_START = "start_game"
C_SKIP = "skip"
C_REMATCH = "rematch"
C_KICK = "kick"

# Server -> Client
S_ROOM_STATE = "room_state"
S_PLAYER_JOIN = "player_join"
S_PLAYER_LEAVE = "player_leave"
S_CHAT = "chat"
S_GAME_START = "game_start"
S_ROUND_START = "round_start"
S_HINT = "hint"
S_SKIP_PROGRESS = "skip_progress"
S_CORRECT = "correct"
S_ROUND_END = "round_end"
S_SCORE_UPDATE = "score_update"
S_GAME_OVER = "game_over"
S_PLAYER_KICKED = "player_kicked"
S_ERROR = "error"
