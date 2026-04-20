"""
Forecasting engine: trains SARIMA and Holt-Winters on each mandi's price
history and exports a compact JSON lookup table the Flutter app ships with.

Design choice: forecasts are pre-computed offline and bundled as a static
asset. This trades staleness (app needs a weekly update) for dead-simple
on-device inference — zero statsmodels on the phone, just a dict lookup.

The ensemble is a simple average of SARIMA and Holt-Winters, which is a
well-known, cheap variance-reducer when neither model clearly dominates.
"""

from __future__ import annotations

import json
import warnings
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.statespace.sarimax import SARIMAX

warnings.filterwarnings("ignore")

HORIZON_DAYS = 14      # forecast this many days ahead
HIST_DAYS    = 30      # include recent history in the JSON for chart rendering
TRAIN_DAYS   = 540     # train on ~18 months to keep fit fast


def fit_sarima(series: pd.Series) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Weekly-seasonal SARIMA. Returns (forecast, lower_95, upper_95)."""
    model = SARIMAX(
        series,
        order=(1, 1, 1),
        seasonal_order=(1, 1, 1, 7),
        enforce_stationarity=False,
        enforce_invertibility=False,
    )
    fit = model.fit(disp=False, maxiter=50)
    fc = fit.get_forecast(steps=HORIZON_DAYS)
    mean = fc.predicted_mean.to_numpy()
    ci = fc.conf_int(alpha=0.05).to_numpy()
    return mean, ci[:, 0], ci[:, 1]


def fit_holt_winters(series: pd.Series) -> np.ndarray:
    """Additive Holt-Winters with weekly seasonality."""
    model = ExponentialSmoothing(
        series,
        trend="add",
        seasonal="add",
        seasonal_periods=7,
        initialization_method="estimated",
    )
    fit = model.fit(optimized=True)
    return fit.forecast(HORIZON_DAYS).to_numpy()


def forecast_mandi(prices: pd.DataFrame, mandi: str) -> dict:
    """Fit both models for one mandi and build the JSON record."""
    series = (
        prices[prices["mandi"] == mandi]
        .sort_values("date")
        .set_index("date")["price_per_kg"]
        .tail(TRAIN_DAYS)
    )

    sarima_mean, sarima_low, sarima_high = fit_sarima(series)
    hw_mean = fit_holt_winters(series)

    # Ensemble: average of the two point forecasts
    ensemble = (sarima_mean + hw_mean) / 2.0

    last_date = series.index.max()
    future_dates = pd.date_range(
        last_date + pd.Timedelta(days=1), periods=HORIZON_DAYS, freq="D"
    )

    history = series.tail(HIST_DAYS).reset_index()
    history.columns = ["date", "price"]

    return {
        "mandi": mandi,
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "unit": "INR_per_kg",
        "history": [
            {"date": d.strftime("%Y-%m-%d"), "price": round(float(p), 2)}
            for d, p in zip(history["date"], history["price"])
        ],
        "forecast": [
            {
                "date": d.strftime("%Y-%m-%d"),
                "price": round(float(e), 2),
                "sarima": round(float(s), 2),
                "holt_winters": round(float(h), 2),
                "low_95": round(float(lo), 2),
                "high_95": round(float(hi), 2),
            }
            for d, e, s, h, lo, hi in zip(
                future_dates, ensemble, sarima_mean, hw_mean, sarima_low, sarima_high
            )
        ],
    }


def build_all() -> dict:
    src = Path(__file__).parent / "data" / "mandi_prices.csv"
    prices = pd.read_csv(src, parse_dates=["date"])

    print(f"Training forecasts on {len(prices):,} rows...")
    out = {}
    for mandi in sorted(prices["mandi"].unique()):
        print(f"  → {mandi}")
        out[mandi] = forecast_mandi(prices, mandi)
    return out


if __name__ == "__main__":
    forecasts = build_all()

    out_path = Path(__file__).parent / "data" / "forecasts.json"
    out_path.write_text(json.dumps(forecasts, indent=2))

    # Also drop it where the Flutter app and web prototype expect it.
    flutter_assets = Path(__file__).parent.parent / "flutter_app" / "assets" / "forecasts.json"
    flutter_assets.parent.mkdir(parents=True, exist_ok=True)
    flutter_assets.write_text(json.dumps(forecasts, indent=2))

    web_assets = Path(__file__).parent.parent / "web_prototype" / "forecasts.json"
    web_assets.parent.mkdir(parents=True, exist_ok=True)
    web_assets.write_text(json.dumps(forecasts, indent=2))

    print()
    print(f"✓ Wrote forecasts to {out_path}")
    print(f"✓ Copied to {flutter_assets}")
    print(f"✓ Copied to {web_assets}")
    print()
    print("Nashik forecast preview (next 7 days):")
    for row in forecasts["Nashik"]["forecast"][:7]:
        print(
            f"  {row['date']}  ensemble ₹{row['price']:5.2f}"
            f"   95% CI [₹{row['low_95']:5.2f}, ₹{row['high_95']:5.2f}]"
        )
