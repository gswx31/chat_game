"""Turn a finished game's scoreboard into per-player history rows."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass


@dataclass(frozen=True)
class PlayerResult:
    user_id: str
    score: int
    rank: int


def is_worth_recording(scores: Mapping[str, int]) -> bool:
    """A game nobody scored in (a lone tester poking around, everyone left) is noise."""
    return any(score > 0 for score in scores.values())


def rank_players(scores: Mapping[str, int]) -> list[PlayerResult]:
    """Competition ranking: highest score first, ties share a rank (1, 1, 3)."""
    ordered = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
    results: list[PlayerResult] = []
    for index, (user_id, score) in enumerate(ordered):
        if index > 0 and score == ordered[index - 1][1]:
            rank = results[-1].rank
        else:
            rank = index + 1
        results.append(PlayerResult(user_id, score, rank))
    return results


def is_win(rank: int, score: int, player_count: int) -> bool:
    """A win needs an opponent and an actual point; a solo game can't be won."""
    return rank == 1 and score > 0 and player_count >= 2
