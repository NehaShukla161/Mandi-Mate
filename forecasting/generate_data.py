"""
Synthetic Maharashtra tomato mandi price generator.

Produces plausible daily price series for 5 mandis over 2 years, with the real
characteristics of tomato markets: strong seasonal swings, weekday effects,
long-term inflation trend, and occasional supply shocks.

In the real build, replace this with a scrape / API pull from Agmarknet
(agmarknet.gov.in) or data.gov.in's mirror. The downstream code is schema-
compatible, so only this file changes.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from pathlib import Path

# 5 major Maharashtra tomato mandis, with approximate base prices (₹/kg)
# and relative volatility. Nashik is the big one — national price-setter.
MANDIS = {
    "Nashik":      {"base": 24.0, "vol": 1.00, "lat": 19.9975, "lon": 73.7898},
    "Pune":        {"base": 27.5, "vol": 0.95, "lat": 18.5204, "lon": 73.8567},
    "Aurangabad":  {"base": 22.0, "vol": 1.10, "lat": 19.8762, "lon": 75.3433},
    "Nagpur":      {"base": 23.5, "vol": 1.05, "lat": 21.1458, "lon": 79.0882},
    "Kolhapur":    {"base": 26.0, "vol": 0.90, "lat": 16.7050, "lon": 74.2433},
}

START = pd.Timestamp("2024-01-01")
END   = pd.Timestamp("2026-04-15")
RNG   = np.random.default_rng(seed=42)


def _seasonal_component(dates: pd.DatetimeIndex) -> np.ndarray:
    """Tomato prices peak Jul–Oct (monsoon hurts supply), trough Feb–Apr."""
    day_of_year = dates.dayofyear.to_numpy()
    # Sine wave peaking around day 240 (late August)
    phase = 2 * np.pi * (day_of_year - 60) / 365.0
    return 1.0 + 0.45 * np.sin(phase)


def _weekday_component(dates: pd.DatetimeIndex) -> np.ndarray:
    """Weekends have slightly thinner trade → more volatile, marginally higher."""
    weekday = dates.weekday.to_numpy()
    bumps = np.array([0.00, -0.01, -0.02, -0.01, 0.00, 0.03, 0.02])
    return 1.0 + bumps[weekday]


def _trend_component(dates: pd.DatetimeIndex) -> np.ndarray:
    """~6% annual agricultural inflation."""
    days_elapsed = (dates - START).days.to_numpy()
    return 1.0 + 0.06 * (days_elapsed / 365.0)


def _supply_shocks(n: int, vol: float) -> np.ndarray:
    """Rare but brutal price spikes — disease, unseasonal rain, transport strikes."""
    shocks = np.ones(n)
    n_shocks = RNG.poisson(lam=n / 120)
    for _ in range(n_shocks):
        start = RNG.integers(0, n)
        duration = RNG.integers(4, 14)
        magnitude = 1.0 + RNG.uniform(0.25, 0.80) * vol
        end = min(start + duration, n)
        # smooth ramp up and decay
        ramp = np.linspace(0, 1, (end - start) // 2 + 1)
        decay = np.linspace(1, 0, (end - start) - len(ramp) + 1)
        envelope = np.concatenate([ramp, decay[1:]])[:end - start]
        shocks[start:end] *= 1 + (magnitude - 1) * envelope
    return shocks


def generate_mandi_series(mandi: str, params: dict) -> pd.DataFrame:
    dates = pd.date_range(START, END, freq="D")
    n = len(dates)

    seasonal = _seasonal_component(dates)
    weekday = _weekday_component(dates)
    trend = _trend_component(dates)
    shocks = _supply_shocks(n, params["vol"])
    noise = RNG.normal(1.0, 0.04 * params["vol"], n)

    price = params["base"] * seasonal * weekday * trend * shocks * noise
    # Floor at ₹5 — tomatoes never go truly free, even in gluts.
    price = np.maximum(price, 5.0)

    df = pd.DataFrame({
        "date": dates,
        "mandi": mandi,
        "price_per_kg": price.round(2),
        "arrivals_quintals": (RNG.gamma(3.0, 50.0, n) * seasonal).round(0).astype(int),
    })
    return df


def generate_all() -> pd.DataFrame:
    frames = [generate_mandi_series(m, p) for m, p in MANDIS.items()]
    return pd.concat(frames, ignore_index=True).sort_values(["date", "mandi"]).reset_index(drop=True)


if __name__ == "__main__":
    out_dir = Path(__file__).parent / "data"
    out_dir.mkdir(exist_ok=True)

    df = generate_all()
    out_path = out_dir / "mandi_prices.csv"
    df.to_csv(out_path, index=False)

    print(f"Generated {len(df):,} rows across {df['mandi'].nunique()} mandis")
    print(f"Date range: {df['date'].min().date()} to {df['date'].max().date()}")
    print(f"Price range: ₹{df['price_per_kg'].min():.2f} to ₹{df['price_per_kg'].max():.2f}")
    print(f"Written to {out_path}")
    print()
    print("Sample (latest week, all mandis):")
    latest = df[df["date"] >= df["date"].max() - pd.Timedelta(days=6)]
    print(latest.pivot(index="date", columns="mandi", values="price_per_kg").to_string())
