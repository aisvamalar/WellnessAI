"""
RAG Engine — Retrieval-Augmented Generation for wellness knowledge.

Pure Python implementation — no ChromaDB, no onnxruntime, no native DLLs.
Uses TF-IDF cosine similarity for semantic retrieval of wellness knowledge.
Works on Python 3.13+ without any C extensions.
"""

import math
import re
from collections import Counter

# ── Wellness knowledge base ───────────────────────────────────────────────────

WELLNESS_DOCS = [
    {"id": "sleep_1", "text": "Adults need 7-9 hours of sleep per night. Consistent sleep and wake times regulate the circadian rhythm and improve sleep quality.", "topic": "sleep"},
    {"id": "sleep_2", "text": "Blue light from screens suppresses melatonin production. Avoid screens 30-60 minutes before bed to improve sleep onset.", "topic": "sleep"},
    {"id": "sleep_3", "text": "A cool room temperature promotes deeper sleep by lowering core body temperature. Aim for 18-20 degrees Celsius.", "topic": "sleep"},
    {"id": "sleep_4", "text": "Sleep deprivation below 6 hours increases cortisol, impairs memory consolidation, and raises cardiovascular risk.", "topic": "sleep"},
    {"id": "stress_1", "text": "Box breathing 4-4-4-4 pattern activates the parasympathetic nervous system within 2 minutes, reducing cortisol levels.", "topic": "stress"},
    {"id": "stress_2", "text": "Chronic stress shrinks the hippocampus and prefrontal cortex. Regular mindfulness meditation reverses this structural change.", "topic": "stress"},
    {"id": "stress_3", "text": "Cold water exposure such as face splash or cold shower stimulates the vagus nerve and reduces acute stress response.", "topic": "stress"},
    {"id": "stress_4", "text": "Journaling about stressors for 15 minutes reduces rumination and improves emotional regulation over time.", "topic": "stress"},
    {"id": "exercise_1", "text": "150 minutes of moderate aerobic exercise per week reduces all-cause mortality by 31% and improves mood via endorphin release.", "topic": "exercise"},
    {"id": "exercise_2", "text": "High-intensity interval training HIIT for 10 minutes produces similar cardiovascular benefits to 30 minutes of moderate exercise.", "topic": "exercise"},
    {"id": "exercise_3", "text": "Morning exercise increases BDNF brain-derived neurotrophic factor, improving focus and learning for 4-6 hours afterward.", "topic": "exercise"},
    {"id": "exercise_4", "text": "Bodyweight exercises push-ups squats lunges are as effective as gym workouts for building functional strength.", "topic": "exercise"},
    {"id": "mindful_1", "text": "8 weeks of mindfulness-based stress reduction MBSR reduces anxiety by 38% and improves emotional regulation.", "topic": "mindfulness"},
    {"id": "mindful_2", "text": "Gratitude journaling writing 3 things you are grateful for daily increases long-term wellbeing and reduces depression symptoms.", "topic": "mindfulness"},
    {"id": "mindful_3", "text": "Body scan meditation activates the parasympathetic nervous system and reduces muscle tension within a single 15-minute session.", "topic": "mindfulness"},
    {"id": "hydration_1", "text": "Even mild dehydration of 1-2% body weight impairs cognitive performance, mood, and physical endurance.", "topic": "hydration"},
    {"id": "hydration_2", "text": "Drinking 500ml of water immediately after waking rehydrates the body after sleep and boosts metabolism by 24%.", "topic": "hydration"},
    {"id": "nutrition_1", "text": "Eating within a consistent 8-10 hour window time-restricted eating improves metabolic health and sleep quality.", "topic": "nutrition"},
    {"id": "nutrition_2", "text": "Omega-3 fatty acids reduce inflammation and support brain health. Found in fatty fish, walnuts, and flaxseeds.", "topic": "nutrition"},
]


# ── TF-IDF retrieval ──────────────────────────────────────────────────────────

def _tokenize(text: str) -> list[str]:
    return re.findall(r'\b[a-z]{2,}\b', text.lower())


def _tfidf_vectors(docs: list[str]) -> tuple[list[dict], dict]:
    """Build TF-IDF vectors for all documents."""
    tokenized = [_tokenize(d) for d in docs]
    N = len(docs)

    # Document frequency
    df: dict[str, int] = {}
    for tokens in tokenized:
        for t in set(tokens):
            df[t] = df.get(t, 0) + 1

    # IDF
    idf = {t: math.log((N + 1) / (df[t] + 1)) + 1 for t in df}

    # TF-IDF vectors
    vectors = []
    for tokens in tokenized:
        tf = Counter(tokens)
        total = len(tokens) or 1
        vec = {t: (tf[t] / total) * idf.get(t, 1) for t in tf}
        vectors.append(vec)

    return vectors, idf


def _cosine(a: dict, b: dict) -> float:
    common = set(a) & set(b)
    if not common:
        return 0.0
    dot = sum(a[t] * b[t] for t in common)
    norm_a = math.sqrt(sum(v * v for v in a.values())) or 1
    norm_b = math.sqrt(sum(v * v for v in b.values())) or 1
    return dot / (norm_a * norm_b)


class RAGEngine:
    """
    Pure-Python TF-IDF retrieval engine.
    No external dependencies — works on any Python 3.8+ environment.
    """

    def __init__(self):
        texts = [d["text"] for d in WELLNESS_DOCS]
        self._vectors, self._idf = _tfidf_vectors(texts)

    def retrieve(self, query: str, top_k: int = 3, topic: str = None) -> list[dict]:
        """Return top-k most relevant docs for the query."""
        q_tokens = _tokenize(query)
        if not q_tokens:
            return []

        q_tf = Counter(q_tokens)
        total = len(q_tokens)
        q_vec = {t: (q_tf[t] / total) * self._idf.get(t, 1) for t in q_tf}

        scores = []
        for i, doc in enumerate(WELLNESS_DOCS):
            if topic and doc["topic"] != topic:
                continue
            score = _cosine(q_vec, self._vectors[i])
            scores.append((score, i))

        scores.sort(reverse=True)
        results = []
        for score, i in scores[:top_k]:
            doc = WELLNESS_DOCS[i]
            results.append({
                "id": doc["id"],
                "title": doc["id"],
                "text": doc["text"],
                "topic": doc["topic"],
                "relevance_score": round(score, 3),
            })
        return results

    def format_context(self, docs: list[dict]) -> str:
        """Format retrieved docs into a context block for the LLM prompt."""
        if not docs:
            return ""
        lines = ["--- Relevant Wellness Research ---"]
        for d in docs:
            lines.append(f"[{d['topic'].upper()}] {d['text']}")
        lines.append("---")
        return "\n".join(lines)

    def count(self) -> int:
        return len(WELLNESS_DOCS)


# ── Singleton + module-level helpers ─────────────────────────────────────────

_rag: RAGEngine | None = None


def get_rag() -> RAGEngine:
    global _rag
    if _rag is None:
        _rag = RAGEngine()
    return _rag


def retrieve(query: str, top_k: int = 3, topic: str = None) -> list[dict]:
    return get_rag().retrieve(query, top_k=top_k, topic=topic)


def format_context(docs: list[dict]) -> str:
    return get_rag().format_context(docs)
