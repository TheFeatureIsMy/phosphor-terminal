"""Social/news data adapter (Layer D) — Twitter, Telegram, Reddit, sentiment, trends."""
from __future__ import annotations

import math
import random
from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class SocialSnapshot:
    """Point-in-time social/news data for a symbol."""
    timestamp: str = ""
    twitter_mentions_1h: int = 0
    twitter_mentions_24h: int = 0
    mention_velocity: float = 0.0          # vs 7-day average
    kol_mention_count: int = 0
    kol_avg_followers: int = 0
    telegram_message_velocity: float = 0.0
    reddit_posts_24h: int = 0
    sentiment_score: float = 0.0           # -1.0 (extreme fear) to 1.0 (extreme greed)
    fear_greed_index: int = 50             # 0-100
    google_trend_zscore: float = 0.0
    data_quality: float = 0.40

    def to_dict(self) -> dict:
        return {
            "twitter_mentions_1h": self.twitter_mentions_1h,
            "twitter_mentions_24h": self.twitter_mentions_24h,
            "mention_velocity": self.mention_velocity,
            "kol_mention_count": self.kol_mention_count,
            "kol_avg_followers": self.kol_avg_followers,
            "telegram_message_velocity": self.telegram_message_velocity,
            "reddit_posts_24h": self.reddit_posts_24h,
            "sentiment_score": self.sentiment_score,
            "fear_greed_index": self.fear_greed_index,
            "google_trend_zscore": self.google_trend_zscore,
            "data_quality": self.data_quality,
        }


class SocialAdapter(ABC):
    @abstractmethod
    def get_snapshot(self, symbol: str) -> SocialSnapshot:
        """Get current social data snapshot for a symbol."""
        ...

    @abstractmethod
    def get_history(self, symbol: str, limit: int = 48) -> list[SocialSnapshot]:
        """Get historical social data snapshots."""
        ...


class MockSocialAdapter(SocialAdapter):
    """Mock adapter simulating a KOL pump scenario:
    low activity → sudden KOL mention spike → retail FOMO follows →
    mentions peak then decline while price still up → silence."""

    def get_snapshot(self, symbol: str) -> SocialSnapshot:
        base_mentions = self._base_mentions(symbol)
        return SocialSnapshot(
            twitter_mentions_1h=int(base_mentions * random.uniform(0.8, 1.2)),
            twitter_mentions_24h=int(base_mentions * 24 * random.uniform(0.9, 1.1)),
            mention_velocity=random.uniform(0.8, 1.2),
            kol_mention_count=random.randint(0, 3),
            kol_avg_followers=random.randint(50_000, 500_000),
            telegram_message_velocity=random.uniform(0.8, 1.3),
            reddit_posts_24h=random.randint(5, 30),
            sentiment_score=random.uniform(-0.2, 0.3),
            fear_greed_index=random.randint(40, 60),
            google_trend_zscore=random.gauss(0, 0.5),
        )

    def get_history(self, symbol: str, limit: int = 48) -> list[SocialSnapshot]:
        snapshots: list[SocialSnapshot] = []
        base_mentions = self._base_mentions(symbol)
        kol_count = 0
        retail_mentions = base_mentions
        sentiment = 0.1
        google_z = 0.0

        for i in range(limit):
            phase = i / limit

            if phase < 0.3:
                # Phase 1: Low baseline activity
                kol_count = random.randint(0, 1)
                retail_mentions = base_mentions * random.uniform(0.8, 1.2)
                sentiment = random.uniform(-0.1, 0.2)
                google_z = random.gauss(0, 0.3)
                tg_vel = random.uniform(0.7, 1.1)
            elif phase < 0.45:
                # Phase 2: KOL spike — coordinated KOL mentions appear suddenly
                kol_count = random.randint(5, 12)
                retail_mentions = base_mentions * random.uniform(1.2, 2.0)  # retail hasn't caught on yet
                sentiment = random.uniform(0.3, 0.7)
                google_z = random.gauss(1.0, 0.5)
                tg_vel = random.uniform(2.0, 4.0)
            elif phase < 0.6:
                # Phase 3: Retail FOMO — mentions explode as retail follows KOLs
                kol_count = random.randint(3, 8)  # KOLs still active but tapering
                retail_mentions = base_mentions * random.uniform(4.0, 8.0)
                sentiment = random.uniform(0.6, 0.95)
                google_z = random.gauss(3.0, 0.8)
                tg_vel = random.uniform(5.0, 10.0)
            elif phase < 0.75:
                # Phase 4: Peak & distribution — mentions at peak, KOLs going silent
                kol_count = random.randint(0, 2)  # KOLs disappear (distribution)
                retail_mentions = base_mentions * random.uniform(5.0, 10.0)  # retail peak
                sentiment = random.uniform(0.4, 0.8)
                google_z = random.gauss(2.5, 1.0)
                tg_vel = random.uniform(4.0, 7.0)
            else:
                # Phase 5: Decline — retail mentions fading, KOLs silent, price still elevated
                kol_count = random.randint(0, 1)
                fade = 1.0 - ((phase - 0.75) / 0.25)  # linear fade
                retail_mentions = base_mentions * random.uniform(1.5, 3.0) * max(fade, 0.3)
                sentiment = random.uniform(-0.1, 0.3)
                google_z = random.gauss(0.5, 0.5)
                tg_vel = random.uniform(1.0, 2.0)

            mentions_1h = max(1, int(retail_mentions))
            mentions_24h = max(1, int(retail_mentions * 24 * random.uniform(0.8, 1.2)))
            mention_vel = retail_mentions / max(base_mentions, 1)

            snapshots.append(SocialSnapshot(
                timestamp=f"T-{limit - i}",
                twitter_mentions_1h=mentions_1h,
                twitter_mentions_24h=mentions_24h,
                mention_velocity=mention_vel,
                kol_mention_count=max(0, kol_count),
                kol_avg_followers=random.randint(100_000, 2_000_000) if kol_count > 0 else 0,
                telegram_message_velocity=tg_vel,
                reddit_posts_24h=max(0, int(retail_mentions * 0.3 + random.gauss(0, 3))),
                sentiment_score=max(-1.0, min(1.0, sentiment)),
                fear_greed_index=max(0, min(100, int(50 + sentiment * 40 + random.gauss(0, 5)))),
                google_trend_zscore=google_z,
            ))

        return snapshots

    def _base_mentions(self, symbol: str) -> float:
        """Baseline hourly Twitter mentions per symbol."""
        bases = {"BTC": 500, "ETH": 300, "SOL": 120, "AVAX": 40, "DOGE": 200, "PEPE": 80}
        for prefix, count in bases.items():
            if prefix in symbol.upper():
                return count * random.uniform(0.9, 1.1)
        return 30.0
