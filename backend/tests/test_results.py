from app.game.results import is_win, is_worth_recording, rank_players


def test_ranks_by_score_descending():
    ranked = rank_players({"a": 3, "b": 7, "c": 5})
    assert [(r.user_id, r.rank) for r in ranked] == [("b", 1), ("c", 2), ("a", 3)]


def test_ties_share_a_rank_and_the_next_rank_skips():
    ranked = rank_players({"a": 5, "b": 5, "c": 2})
    assert [r.rank for r in ranked] == [1, 1, 3]


def test_a_single_player_is_rank_one():
    assert [(r.user_id, r.rank) for r in rank_players({"solo": 4})] == [("solo", 1)]


def test_empty_scoreboard_is_empty():
    assert rank_players({}) == []


def test_games_nobody_scored_in_are_not_recorded():
    assert not is_worth_recording({})
    assert not is_worth_recording({"a": 0, "b": 0})
    assert is_worth_recording({"a": 0, "b": 1})


def test_win_needs_first_place_a_point_and_an_opponent():
    assert is_win(rank=1, score=7, player_count=3)
    assert not is_win(rank=2, score=5, player_count=3)
    assert not is_win(rank=1, score=0, player_count=3)  # tied for first at zero
    assert not is_win(rank=1, score=20, player_count=1)  # solo practice can't be "won"
