"""
Explanation generation service using OpenAI GPT API.

Generates Dutch and English explanations for sentences and extracts vocabulary.
"""

import asyncio
import json
from typing import List, Dict, Any, Optional

from openai import AsyncOpenAI

from app.config import settings


class ExplanationError(Exception):
    """Raised when explanation generation fails."""
    pass


class Explainer:
    """
    Service for generating explanations using OpenAI GPT API.

    Generates Dutch and English explanations for sentences and
    extracts key vocabulary words with meanings.

    Example:
        explainer = Explainer()
        results = await explainer.explain_batch(["Hallo, hoe gaat het?", "Ik ben blij."])
        for result in results:
            print(f"NL: {result['explanation_nl']}")
            print(f"EN: {result['explanation_en']}")
            for keyword in result['keywords']:
                print(f"  - {keyword['word']}: {keyword['meaning_en']}")
    """

    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize the explainer.

        Args:
            api_key: OpenAI API key. Uses settings.openai_api_key if not provided.

        Raises:
            ExplanationError: If API key is not configured.
        """
        self.api_key = api_key or settings.openai_api_key

        if not self.api_key:
            raise ExplanationError(
                "OpenAI API key not configured. Set OPENAI_API_KEY in .env file."
            )

        self.client = AsyncOpenAI(api_key=self.api_key)
        self.model = settings.gpt_model
        self.batch_size = settings.explanation_batch_size

    def _build_prompt(self, sentences: List[str]) -> str:
        """
        Build the prompt for explanation generation.

        Args:
            sentences: List of Dutch sentences to explain.

        Returns:
            str: The prompt for the GPT API.
        """
        sentences_json = json.dumps(sentences, ensure_ascii=False, indent=2)

        return f"""You are an expert Dutch language teacher helping students learn Dutch.

For each of the following Dutch sentences, provide:
1. A complete and accurate English translation of the sentence
2. A simple explanation in Dutch (1-2 sentences explaining the context and any grammar points)
3. An explanation in English (1-2 sentences about usage, context, or grammar notes - NOT a translation)
4. Extract 2-4 key vocabulary words with their meanings in both Dutch and English

IMPORTANT:
- The translation_en should be a direct, accurate translation of the Dutch sentence
- The explanation_en should provide context, usage notes, or grammar tips - NOT repeat the translation
- Keep explanations simple and helpful for language learners
- Focus on commonly used words and expressions
- For keywords, include the base/dictionary form of verbs and nouns

Respond ONLY with a valid JSON object in this exact format:
{{
  "sentences": [
    {{
      "translation_en": "Complete English translation here",
      "explanation_nl": "Dutch explanation here",
      "explanation_en": "English usage/context explanation here (not a translation)",
      "keywords": [
        {{"word": "dutch_word", "meaning_nl": "Dutch meaning", "meaning_en": "English meaning"}}
      ]
    }}
  ]
}}

Dutch sentences to explain:
{sentences_json}"""

    async def explain_batch(
        self,
        sentences: List[str],
    ) -> List[Dict[str, Any]]:
        """
        Generate explanations for a batch of sentences.

        Args:
            sentences: List of Dutch sentences to explain.

        Returns:
            List of explanations, each containing:
                - explanation_nl: Dutch explanation
                - explanation_en: English explanation
                - keywords: List of vocabulary words with meanings

        Raises:
            ExplanationError: If explanation generation fails.
        """
        if not sentences:
            return []

        prompt = self._build_prompt(sentences)

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system",
                        "content": "You are a Dutch language teacher. Always respond with valid JSON only.",
                    },
                    {
                        "role": "user",
                        "content": prompt,
                    },
                ],
                temperature=0.3,
                max_tokens=4000,
                response_format={"type": "json_object"},
            )

            # Parse response
            content = response.choices[0].message.content
            result = json.loads(content)

            explanations = result.get("sentences", [])

            # Validate we got explanations for all sentences
            if len(explanations) != len(sentences):
                # Pad with empty explanations if needed
                while len(explanations) < len(sentences):
                    explanations.append({
                        "explanation_nl": "",
                        "explanation_en": "",
                        "keywords": [],
                    })

            return explanations

        except json.JSONDecodeError as e:
            raise ExplanationError(f"Failed to parse GPT response as JSON: {str(e)}")
        except Exception as e:
            if isinstance(e, ExplanationError):
                raise
            raise ExplanationError(f"Explanation generation failed: {str(e)}")

    async def explain_all(
        self,
        sentences: List[str],
        on_progress: Optional[callable] = None,
    ) -> List[Dict[str, Any]]:
        """
        Generate explanations for all sentences in batches.

        Args:
            sentences: List of all Dutch sentences to explain.
            on_progress: Optional callback function(processed_count, total_count).

        Returns:
            List of explanations for all sentences.

        Raises:
            ExplanationError: If explanation generation fails.
        """
        all_explanations = []
        total = len(sentences)

        for i in range(0, total, self.batch_size):
            batch = sentences[i:i + self.batch_size]

            try:
                batch_explanations = await self.explain_batch(batch)
                all_explanations.extend(batch_explanations)

                if on_progress:
                    on_progress(len(all_explanations), total)

            except ExplanationError:
                # Add empty explanations for failed batch
                for _ in batch:
                    all_explanations.append({
                        "explanation_nl": "",
                        "explanation_en": "",
                        "keywords": [],
                    })

                if on_progress:
                    on_progress(len(all_explanations), total)

        return all_explanations

    async def explain_with_retry(
        self,
        sentences: List[str],
        max_retries: int = 3,
        retry_delay: float = 1.0,
    ) -> List[Dict[str, Any]]:
        """
        Generate explanations with automatic retry on failure.

        Args:
            sentences: List of Dutch sentences to explain.
            max_retries: Maximum number of retry attempts.
            retry_delay: Initial delay between retries (exponential backoff).

        Returns:
            List of explanations.

        Raises:
            ExplanationError: If all retries fail.
        """
        last_error = None

        for attempt in range(max_retries):
            try:
                return await self.explain_batch(sentences)
            except ExplanationError as e:
                last_error = e

                if attempt < max_retries - 1:
                    delay = retry_delay * (2 ** attempt)
                    await asyncio.sleep(delay)

        raise ExplanationError(
            f"Explanation generation failed after {max_retries} attempts: {last_error}"
        )
