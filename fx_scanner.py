#!/usr/bin/env python3
"""Forex day-trading scanner and position-size calculator.

Prints today's currency strength ranking, a watchlist ranked by strength gap
and ADR room, and the key levels to mark. See FOREX_PLAYBOOK.md.

    pip install yfinance pandas numpy
    python fx_scanner.py [PAIRS ...] [--top 6] [--demo]
    python fx_scanner.py size --account 2000 --risk 1 --stop 15 --pair EURUSD
"""

from __future__ import annotations

import argparse
import math
import sys
import zlib
from dataclasses import dataclass

import numpy as np
import pandas as pd

CURRENCIES = ["USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"]

# Pairs used to measure currency strength: every currency appears several times.
STRENGTH_PAIRS = [
    "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDJPY", "USDCAD", "USDCHF",
    "EURGBP", "EURJPY", "GBPJPY", "AUDJPY", "EURAUD", "GBPAUD", "EURCHF",
    "CADJPY", "AUDNZD", "GBPCAD", "NZDJPY", "CHFJPY", "EURCAD",
]

DEFAULT_WATCHLIST = [
    "EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD",
    "GBPJPY", "EURJPY", "EURGBP", "AUDJPY", "XAUUSD",
]

DEMO_PRICES = {
    "EURUSD": 1.17, "GBPUSD": 1.34, "USDJPY": 148.0, "AUDUSD": 0.66, "NZDUSD": 0.58,
    "USDCAD": 1.39, "USDCHF": 0.80, "EURGBP": 0.87, "EURCHF": 0.93, "EURAUD": 1.77,
    "GBPAUD": 2.03, "AUDNZD": 1.14, "GBPCAD": 1.86, "EURCAD": 1.63, "XAUUSD": 3700.0,
}

ASIAN_START, ASIAN_END = "00:00", "06:59"  # UTC


def pip_size(pair: str) -> float:
    if pair.startswith("XAU"):
        return 0.1
    return 0.01 if pair.endswith("JPY") else 0.0001


def contract_size(pair: str) -> float:
    return 100 if pair.startswith("XAU") else 100_000


def yahoo_symbol(pair: str) -> str:
    return "GC=F" if pair == "XAUUSD" else f"{pair}=X"


@dataclass
class PairView:
    pair: str
    price: float
    change_pct: float
    adr_pips: float
    today_pips: float
    adr_used_pct: float
    trend: str
    strength_gap: float
    asian_high: float
    asian_low: float
    prev_high: float
    prev_low: float
    today_open: float
    score: float
    idea: str


def ema(series: pd.Series, length: int) -> float:
    return float(series.ewm(span=length, adjust=False).mean().iloc[-1])


def daily_trend(daily: pd.DataFrame, price: float) -> str:
    fast, slow = ema(daily["Close"], 20), ema(daily["Close"], 50)
    if price > fast > slow:
        return "up"
    if price < fast < slow:
        return "down"
    return "range"


def split_today(intraday: pd.DataFrame) -> pd.DataFrame:
    """Bars since 00:00 UTC of the latest trading day."""
    today = intraday.index[-1].date()
    return intraday[intraday.index.date == today]


def change_today(intraday: pd.DataFrame) -> float:
    today = split_today(intraday)
    return (float(today["Close"].iloc[-1]) / float(today["Open"].iloc[0]) - 1) * 100


def currency_strength(changes: dict[str, float]) -> dict[str, float]:
    """Average % move of each currency across the pairs it appears in."""
    totals = {c: [] for c in CURRENCIES}
    for pair, chg in changes.items():
        base, quote = pair[:3], pair[3:]
        if base in totals:
            totals[base].append(chg)
        if quote in totals:
            totals[quote].append(-chg)
    return {c: float(np.mean(v)) for c, v in totals.items() if v}


def trade_idea(trend: str, gap: float, adr_used: float, asian_range_pct: float) -> str:
    if adr_used >= 80:
        return "ADR mostly used: no new trades, wait for tomorrow"
    direction = "long" if gap > 0 else "short"
    aligned = (trend == "up" and gap > 0) or (trend == "down" and gap < 0)
    if abs(gap) < 0.1:
        return "No strength gap: pass or range-trade the Asian high/low (B)"
    if aligned and asian_range_pct < 50:
        return f"Tight Asian range + trend: Asian breakout {direction} (A), then 20 EMA pullbacks (C)"
    if aligned:
        return f"Trend + strength agree: 20 EMA pullback {direction} (C) or break-retest (D)"
    return f"Strength vs daily trend conflict: watch for a liquidity sweep (B), half size"


def analyze(pair: str, daily: pd.DataFrame, intraday: pd.DataFrame, strength: dict[str, float]) -> PairView | None:
    """daily: completed daily bars. intraday: 15-min bars in UTC ending now."""
    if len(daily) < 50 or intraday.empty:
        return None

    pip = pip_size(pair)
    today = split_today(intraday)
    price = float(today["Close"].iloc[-1])
    today_open = float(today["Open"].iloc[0])
    prev = daily.iloc[-1]

    adr_pips = float((daily["High"] - daily["Low"]).tail(14).mean()) / pip
    today_pips = (float(today["High"].max()) - float(today["Low"].min())) / pip
    adr_used = today_pips / adr_pips * 100 if adr_pips else 0.0

    asian = today.between_time(ASIAN_START, ASIAN_END)
    if asian.empty:
        asian = today
    asian_high, asian_low = float(asian["High"].max()), float(asian["Low"].min())
    asian_range_pct = (asian_high - asian_low) / pip / adr_pips * 100 if adr_pips else 0.0

    base, quote = pair[:3], pair[3:]
    gap = strength.get(base, 0.0) - strength.get(quote, 0.0)
    trend = daily_trend(daily, price)

    # Prefer big strength gaps with plenty of ADR left, aligned with the daily trend.
    aligned = (trend == "up" and gap > 0) or (trend == "down" and gap < 0)
    score = abs(gap) * 10 + max(0.0, 100 - adr_used) / 20 + (2 if aligned else 0)

    return PairView(
        pair=pair,
        price=price,
        change_pct=(price / today_open - 1) * 100,
        adr_pips=adr_pips,
        today_pips=today_pips,
        adr_used_pct=adr_used,
        trend=trend,
        strength_gap=gap,
        asian_high=asian_high,
        asian_low=asian_low,
        prev_high=float(prev["High"]),
        prev_low=float(prev["Low"]),
        today_open=today_open,
        score=score,
        idea=trade_idea(trend, gap, adr_used, asian_range_pct),
    )


def fetch(pair: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Return (completed daily bars, 15-min bars in UTC) from Yahoo Finance."""
    import yfinance as yf

    t = yf.Ticker(yahoo_symbol(pair))
    daily = t.history(period="6mo", interval="1d")
    intraday = t.history(period="5d", interval="15m")
    if daily.empty or intraday.empty:
        return pd.DataFrame(), pd.DataFrame()
    intraday = intraday.tz_convert("UTC")
    today = intraday.index[-1].date()
    daily = daily[daily.index.date < today]
    return daily, intraday


def demo_data(pair: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Synthetic bars so the scanner can be tried without market data access."""
    rng = np.random.default_rng(zlib.crc32(pair.encode()))
    start = DEMO_PRICES.get(pair, 150.0 if pair.endswith("JPY") else 1.0)
    closes = start * np.cumprod(1 + rng.normal(0.0002, 0.005, 120))
    daily = pd.DataFrame(
        {
            "Open": closes * (1 + rng.normal(0, 0.001, 120)),
            "High": closes * (1 + rng.uniform(0.001, 0.006, 120)),
            "Low": closes * (1 - rng.uniform(0.001, 0.006, 120)),
            "Close": closes,
        },
        index=pd.bdate_range(end="2026-09-24", periods=120),
    )
    drift = rng.normal(0, 0.00015)
    path = closes[-1] * np.cumprod(1 + rng.normal(drift, 0.0003, 40))
    intraday = pd.DataFrame(
        {"Open": np.r_[closes[-1], path[:-1]], "High": path * 1.0006, "Low": path * 0.9994, "Close": path},
        index=pd.date_range("2026-09-25 00:00", periods=40, freq="15min", tz="UTC"),
    )
    return daily, intraday


def fmt(pair: str, value: float) -> str:
    decimals = 2 if pair.startswith("XAU") else 3 if pair.endswith("JPY") else 5
    return f"{value:.{decimals}f}"


def scan(args: argparse.Namespace) -> int:
    pairs = [p.upper().replace("/", "") for p in args.pairs] or DEFAULT_WATCHLIST
    loader = demo_data if args.demo else fetch

    data: dict[str, tuple[pd.DataFrame, pd.DataFrame]] = {}
    for pair in dict.fromkeys(STRENGTH_PAIRS + pairs):
        try:
            daily, intraday = loader(pair)
        except Exception as exc:  # one bad symbol should not stop the scan
            print(f"  skip {pair}: {exc}", file=sys.stderr)
            continue
        if not intraday.empty:
            data[pair] = (daily, intraday)

    changes = {p: change_today(data[p][1]) for p in STRENGTH_PAIRS if p in data}
    if not changes:
        print("No market data. Check your internet connection, or try --demo.")
        return 1
    strength = currency_strength(changes)

    print("\nCURRENCY STRENGTH TODAY (% vs other majors since 00:00 UTC)")
    ranked = sorted(strength.items(), key=lambda kv: kv[1], reverse=True)
    for cur, value in ranked:
        bar = "+" * min(20, int(abs(value) * 40)) if value > 0 else "-" * min(20, int(abs(value) * 40))
        print(f"  {cur}  {value:+.2f}  {bar}")
    print(f"  Strongest: {ranked[0][0]}   Weakest: {ranked[-1][0]}   "
          f"-> look at {ranked[0][0]}/{ranked[-1][0]} first")

    views = []
    for pair in pairs:
        if pair not in data:
            print(f"  skip {pair}: no data", file=sys.stderr)
            continue
        view = analyze(pair, *data[pair], strength)
        if view is None:
            print(f"  skip {pair}: not enough history", file=sys.stderr)
        else:
            views.append(view)

    views.sort(key=lambda v: v.score, reverse=True)
    views = views[: args.top]

    print(f"\nWATCHLIST (top {len(views)})  -- check the calendar for red news on both currencies\n")
    print(f"{'Pair':<8}{'Price':>11}{'Chg%':>7}{'ADR':>7}{'Used%':>7}{'Trend':>7}{'StrGap':>8}")
    print("-" * 55)
    for v in views:
        print(f"{v.pair:<8}{fmt(v.pair, v.price):>11}{v.change_pct:>+7.2f}{v.adr_pips:>7.0f}"
              f"{v.adr_used_pct:>7.0f}{v.trend:>7}{v.strength_gap:>+8.2f}")

    print("\nKEY LEVELS & PLAN")
    for v in views:
        print(f"\n{v.pair}: Asian H {fmt(v.pair, v.asian_high)} / L {fmt(v.pair, v.asian_low)} | "
              f"prev-day H {fmt(v.pair, v.prev_high)} / L {fmt(v.pair, v.prev_low)} | "
              f"today open {fmt(v.pair, v.today_open)}")
        print(f"  Idea: {v.idea}")
        print(f"  Stop guide ~{v.adr_pips * 0.2:.0f} pips (20% ADR); 2R target ~{v.adr_pips * 0.4:.0f} pips")
    print()
    return 0


def position_size(pair: str, account: float, risk_pct: float, stop_pips: float,
                  price: float | None, quote_usd: float | None) -> tuple[float, float, float]:
    """Return (lots, risk amount, pip value per lot) for a USD-denominated account."""
    pair = pair.upper().replace("/", "")
    base, quote = pair[:3], pair[3:]
    pip_value_quote = pip_size(pair) * contract_size(pair)  # in quote currency

    if quote == "USD":
        pip_value = pip_value_quote
    elif base == "USD":
        if not price:
            raise ValueError(f"--price is required for {pair} (current {pair} rate)")
        pip_value = pip_value_quote / price
    else:
        if not quote_usd:
            raise ValueError(f"--quote-usd is required for {pair} (current {quote}USD rate)")
        pip_value = pip_value_quote * quote_usd

    risk = account * risk_pct / 100
    # Round down to the 0.01 lot step so the trade never risks more than planned.
    lots = math.floor(risk / (stop_pips * pip_value) * 100 + 1e-9) / 100
    return lots, risk, pip_value


def size(args: argparse.Namespace) -> int:
    try:
        lots, risk, pip_value = position_size(args.pair, args.account, args.risk, args.stop,
                                              args.price, args.quote_usd)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    print(f"Risk: ${risk:.2f}  |  Pip value per 1.00 lot: ${pip_value:.2f}")
    unit = "oz" if args.pair.upper().startswith("XAU") else "units"
    print(f"Position size: {lots:.2f} lots  ({lots * contract_size(args.pair.upper()):,.0f} {unit})")
    if lots < 0.01:
        print("Below the 0.01 minimum lot: skip this trade (never raise your risk to fit it).")
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] == "size":
        p = argparse.ArgumentParser(prog="fx_scanner.py size", description="Position-size calculator (USD account)")
        p.add_argument("--account", type=float, required=True, help="account balance in USD")
        p.add_argument("--risk", type=float, default=1.0, help="risk per trade in %% (default 1)")
        p.add_argument("--stop", type=float, required=True, help="stop-loss distance in pips")
        p.add_argument("--pair", required=True)
        p.add_argument("--price", type=float, help="current rate, needed for USDxxx pairs")
        p.add_argument("--quote-usd", type=float, help="quote currency to USD rate, needed for crosses")
        return size(p.parse_args(argv[1:]))

    p = argparse.ArgumentParser(description="Forex currency-strength and watchlist scanner")
    p.add_argument("pairs", nargs="*", help="pairs to scan, e.g. EURUSD GBPJPY (default: built-in list)")
    p.add_argument("--top", type=int, default=6, help="how many pairs to show (default 6)")
    p.add_argument("--demo", action="store_true", help="use synthetic data (no network)")
    return scan(p.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
