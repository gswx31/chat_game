from app.rooms.cleanup import EMPTY_GRACE_SECONDS, find_abandoned


def _sweep(rooms: dict[str, int], state: dict[str, float], now: float, running=()) -> list[str]:
    return find_abandoned(rooms, lambda r: rooms[r], lambda r: r in running, state, now)


def test_an_empty_room_is_only_abandoned_after_the_grace_period():
    rooms, state = {"ghost": 0}, {}
    assert _sweep(rooms, state, now=100.0) == []  # first seen empty: start the clock
    assert _sweep(rooms, state, now=100.0 + EMPTY_GRACE_SECONDS - 1) == []
    assert _sweep(rooms, state, now=100.0 + EMPTY_GRACE_SECONDS) == ["ghost"]


def test_rooms_with_people_are_never_abandoned():
    rooms, state = {"busy": 3}, {}
    for t in (0.0, 100.0, 10_000.0):
        assert _sweep(rooms, state, now=t) == []
    assert state == {}


def test_somebody_coming_back_restarts_the_clock():
    rooms, state = {"r": 0}, {}
    _sweep(rooms, state, now=0.0)
    rooms["r"] = 1  # a player reconnects
    assert _sweep(rooms, state, now=EMPTY_GRACE_SECONDS) == []
    assert "r" not in state
    rooms["r"] = 0  # and leaves again: counted from the moment they left
    assert _sweep(rooms, state, now=EMPTY_GRACE_SECONDS + 1) == []
    assert _sweep(rooms, state, now=EMPTY_GRACE_SECONDS * 2) == []
    assert _sweep(rooms, state, now=EMPTY_GRACE_SECONDS * 2 + 1) == ["r"]


def test_a_game_loop_that_is_still_winding_down_keeps_its_room():
    rooms, state = {"r": 0}, {}
    assert _sweep(rooms, state, now=0.0, running={"r"}) == []
    assert _sweep(rooms, state, now=1000.0, running={"r"}) == []


def test_rooms_that_no_longer_exist_are_forgotten():
    state: dict[str, float] = {}
    _sweep({"gone": 0}, state, now=0.0)
    assert "gone" in state
    _sweep({}, state, now=1.0)
    assert state == {}
