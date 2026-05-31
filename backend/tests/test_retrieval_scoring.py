from __future__ import annotations

from app.routers.rag import _score_chunk, _extract_chunks


def test_score_chunk_full_match():
    score = _score_chunk("moving average crossover", "Moving average crossover strategy")
    assert score > 0.8


def test_score_chunk_partial_match():
    score = _score_chunk("cross over", "Moving average crossover strategy")
    assert score > 0


def test_score_chunk_no_match():
    score = _score_chunk("machine learning", "Moving average crossover strategy")
    assert score == 0


def test_score_chunk_empty_query():
    score = _score_chunk("", "Some content here")
    assert score == 0


def test_score_chunk_empty_content():
    score = _score_chunk("test query", "")
    assert score == 0


def test_score_chunk_all_words_match():
    score = _score_chunk("Buy Bitcoin now", "Buy Bitcoin now is a good idea")
    assert score > 0.9


def test_score_chunk_is_bounded():
    score = _score_chunk("a b c d e f g h i j k l m n o p", "a b c d e f g h i j k l m n o p q r s t u v")
    assert score <= 0.98


def test_extract_chunks_returns_lines_with_keywords():
    text = "This is a trading strategy that uses RSI indicator\nThis is a risk management approach\nThis is random line"
    chunks = _extract_chunks(text)
    assert len(chunks) >= 2
    assert any("trading strategy" in c for c in chunks)
    assert any("risk management" in c for c in chunks)


def test_extract_chunks_fallback():
    text = "short line" * 100
    chunks = _extract_chunks(text)
    assert len(chunks) >= 1


def test_extract_chunks_fallback_for_no_keywords():
    text = "Hello world foo bar baz qux"
    chunks = _extract_chunks(text)
    assert len(chunks) >= 1
