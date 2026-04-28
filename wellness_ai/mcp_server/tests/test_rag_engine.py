"""
Unit tests for RAG Engine — vector store seeding, retrieval, and context formatting.
"""

import sys
import os
import shutil
import pytest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Use a temp DB for tests
TEST_DB = str(Path(__file__).parent / "test_rag_db")

from rag_engine import RAGEngine, retrieve, format_context


@pytest.fixture(scope="module")
def rag():
    """Create a fresh RAG engine with test DB."""
    engine = RAGEngine(db_path=TEST_DB)
    yield engine
    shutil.rmtree(TEST_DB, ignore_errors=True)


# ── Seeding ───────────────────────────────────────────────────────────────────

class TestRAGSeeding:
    def test_collection_seeded_on_init(self, rag):
        assert rag.count() > 0

    def test_all_docs_indexed(self, rag):
        from rag_engine import WELLNESS_DOCS
        assert rag.count() == len(WELLNESS_DOCS)


# ── Retrieval ─────────────────────────────────────────────────────────────────

class TestRAGRetrieval:
    def test_retrieve_returns_results(self, rag):
        docs = rag.retrieve("how to sleep better", top_k=3)
        assert len(docs) > 0

    def test_retrieve_respects_top_k(self, rag):
        docs = rag.retrieve("wellness tips", top_k=2)
        assert len(docs) <= 2

    def test_retrieve_returns_dict_structure(self, rag):
        docs = rag.retrieve("stress reduction", top_k=1)
        assert len(docs) == 1
        doc = docs[0]
        assert "id" in doc
        assert "text" in doc
        assert "topic" in doc
        assert "relevance_score" in doc

    def test_retrieve_relevance_score_range(self, rag):
        docs = rag.retrieve("sleep tips", top_k=3)
        for doc in docs:
            assert -1.0 <= doc["relevance_score"] <= 1.0

    def test_retrieve_sleep_query_returns_sleep_docs(self, rag):
        docs = rag.retrieve("I can't sleep at night", top_k=3, topic="sleep")
        for doc in docs:
            assert doc["topic"] == "sleep"

    def test_retrieve_stress_query_relevant(self, rag):
        docs = rag.retrieve("I feel very stressed and anxious", top_k=3)
        topics = [d["topic"] for d in docs]
        # Should return stress or mindfulness related docs
        assert any(t in ["stress", "mindfulness"] for t in topics)

    def test_retrieve_empty_query_still_returns(self, rag):
        docs = rag.retrieve("", top_k=2)
        assert isinstance(docs, list)


# ── Context formatting ────────────────────────────────────────────────────────

class TestFormatContext:
    def test_format_context_non_empty(self, rag):
        docs = rag.retrieve("sleep better", top_k=2)
        context = rag.format_context(docs)
        assert len(context) > 0
        assert "---" in context

    def test_format_context_empty_docs(self, rag):
        context = rag.format_context([])
        assert context == ""

    def test_format_context_contains_doc_text(self, rag):
        docs = rag.retrieve("box breathing", top_k=1)
        context = rag.format_context(docs)
        # The retrieved text should appear in context
        assert docs[0]["text"][:20] in context


# ── Module-level functions ────────────────────────────────────────────────────

class TestModuleFunctions:
    def test_module_retrieve_works(self):
        docs = retrieve("exercise benefits", top_k=2)
        assert isinstance(docs, list)

    def test_module_format_context_works(self):
        docs = retrieve("mindfulness meditation", top_k=2)
        ctx = format_context(docs)
        assert isinstance(ctx, str)
