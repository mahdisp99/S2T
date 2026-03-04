from __future__ import annotations

import sqlite3
import threading
from datetime import datetime
from typing import Any

from .config import database_file_path


class TranscriptStorage:
    def __init__(self) -> None:
        self._conn = sqlite3.connect(database_file_path(), check_same_thread=False)
        self._conn.execute("PRAGMA foreign_keys = ON;")
        self._lock = threading.Lock()
        self._create_tables()

    def _create_tables(self) -> None:
        with self._lock:
            self._conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS recording_sessions (
                    id TEXT PRIMARY KEY,
                    full_persian_text TEXT NOT NULL,
                    full_english_text TEXT,
                    language_pasted TEXT NOT NULL,
                    started_at TEXT NOT NULL,
                    ended_at TEXT NOT NULL,
                    duration_seconds REAL NOT NULL,
                    word_count_persian INTEGER NOT NULL,
                    word_count_english INTEGER NOT NULL,
                    character_count_persian INTEGER NOT NULL,
                    character_count_english INTEGER NOT NULL,
                    sentence_count INTEGER NOT NULL,
                    hotkey_used TEXT
                );

                CREATE TABLE IF NOT EXISTS transcription_chunks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    chunk_text TEXT NOT NULL,
                    chunk_order INTEGER NOT NULL,
                    is_final INTEGER NOT NULL,
                    translation_status TEXT NOT NULL,
                    received_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES recording_sessions(id) ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_sessions_started_at
                    ON recording_sessions(started_at);
                CREATE INDEX IF NOT EXISTS idx_chunks_session_id
                    ON transcription_chunks(session_id);
                """
            )
            self._conn.commit()

    def save_chunk(
        self,
        session_id: str,
        chunk_text: str,
        chunk_order: int,
        is_final: bool,
        translation_status: str,
    ) -> None:
        with self._lock:
            self._conn.execute(
                """
                INSERT INTO transcription_chunks
                (session_id, chunk_text, chunk_order, is_final, translation_status)
                VALUES (?, ?, ?, ?, ?);
                """,
                (session_id, chunk_text, chunk_order, 1 if is_final else 0, translation_status),
            )
            self._conn.commit()

    def save_session(
        self,
        session_id: str,
        full_persian_text: str,
        full_english_text: str,
        language_pasted: str,
        started_at: datetime,
        ended_at: datetime,
        hotkey_used: str,
    ) -> None:
        duration_seconds = max((ended_at - started_at).total_seconds(), 0.0)
        word_count_persian = _count_words(full_persian_text)
        word_count_english = _count_words(full_english_text)
        character_count_persian = len(full_persian_text)
        character_count_english = len(full_english_text)
        sentence_count = _count_sentences(full_persian_text)

        with self._lock:
            self._conn.execute(
                """
                INSERT INTO recording_sessions (
                    id,
                    full_persian_text,
                    full_english_text,
                    language_pasted,
                    started_at,
                    ended_at,
                    duration_seconds,
                    word_count_persian,
                    word_count_english,
                    character_count_persian,
                    character_count_english,
                    sentence_count,
                    hotkey_used
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    session_id,
                    full_persian_text,
                    full_english_text,
                    language_pasted,
                    started_at.isoformat(),
                    ended_at.isoformat(),
                    duration_seconds,
                    word_count_persian,
                    word_count_english,
                    character_count_persian,
                    character_count_english,
                    sentence_count,
                    hotkey_used,
                ),
            )
            self._conn.commit()

    def get_today_stats(self) -> dict[str, Any]:
        with self._lock:
            cursor = self._conn.execute(
                """
                SELECT
                    COUNT(*) AS session_count,
                    COALESCE(SUM(word_count_persian + word_count_english), 0) AS total_words,
                    COALESCE(SUM(duration_seconds), 0) AS total_duration
                FROM recording_sessions
                WHERE DATE(started_at, 'localtime') = DATE('now', 'localtime');
                """
            )
            row = cursor.fetchone()

        return {
            "session_count": int(row[0]) if row else 0,
            "total_words": int(row[1]) if row else 0,
            "total_duration": float(row[2]) if row else 0.0,
        }

    def close(self) -> None:
        with self._lock:
            self._conn.close()


def _count_words(text: str) -> int:
    return len([part for part in text.split() if part.strip()])


def _count_sentences(text: str) -> int:
    separators = ".!?؟"
    sentence_count = 0
    buffer = []
    for char in text:
        buffer.append(char)
        if char in separators:
            if "".join(buffer).strip():
                sentence_count += 1
            buffer = []
    if "".join(buffer).strip():
        sentence_count += 1
    return sentence_count

