#!/usr/bin/env python3
"""Forex day-trading morning scanner and position-size calculator.

Runs the playbook's morning routine (see FOREX_PLAYBOOK.md):
  1. ForexFactory high-impact news for today, with 15-minute no-trade windows
  2. Currency strength: strongest vs weakest, rejecting strong/strong and weak/weak pairs
  3. ADR check: skip pairs that have already used too much of their average daily range
  4. Key levels: Asian, previous-day and previous-week high/low, round numbers
  5. Picks 2-3 pairs, skipping any that duplicate a trade already picked

    pip install yfinance pandas numpy
    python fx_scanner.py [PAIRS ...] [--picks 3] [--max-adr 75] [--demo]
    python fx_scanner.py size --account 2000 --risk 1 --stop 15 --pair EURUSD
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
import urllib.request
import zlib
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

CURRENCIES = ["USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"]

# Pairs used to measure currency strength: every currency appears several times.
STRENGTH_PAIRS = [
    "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDJPY", "USDCAD", "USDCHF",
    "EURGBP", "EURJPY", "GBPJPY", "AUDJPY", "EURAUD", "GBPAUD", "EURCHF",
    "CADJPY", "AUDNZD", "GBPCAD", "NZDJPY", "CHFJPY", "EURCAD",
]

# Candidates for today's picks: the strength pairs plus gold.
DEFAULT_WATCHLIST = STRENGTH_PAIRS + ["XAUUSD"]

DEMO_PRICES = {
    "EURUSD": 1.17, "GBPUSD": 1.34, "USDJPY": 148.0, "AUDUSD": 0.66, "NZDUSD": 0.58,
    "USDCAD": 1.39, "USDCHF": 0.80, "EURGBP": 0.87, "EURCHF": 0.93, "EURAUD": 1.77,
    "GBPAUD": 2.03, "AUDNZD": 1.14, "GBPCAD": 1.86, "EURCAD": 1.63, "XAUUSD": 3700.0,
}

ASIAN_START, ASIAN_END = "00:00", "06:59"  # UTC

CALENDAR_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
CACHE_DIR = Path(__file__).resolve().parent / ".fx_cache"
CALENDAR_MAX_AGE = 60 * 60  # the feed is rate limited: refetch at most hourly

# Two picks whose daily returns correlate above this (in the traded direction)
# are treated as the same trade.
MAX_CORRELATION = 0.7


def pip_size(pair: str) -> float:
    if pair.startswith("XAU"):
        return 0.1
    return 0.01 if pair.endswith("JPY") else 0.0001


def contract_size(pair: str) -> float:
    return 100 if pair.startswith("XAU") else 100_000


def yahoo_symbol(pair: str) -> str:
    return "GC=F" if pair == "XAUUSD" else f"{pair}=X"


def fmt(pair: str, value: float) -> str:
    decimals = 2 if pair.startswith("XAU") else 3 if pair.endswith("JPY") else 5
    return f"{value:.{decimals}f}"


# --- 1. News -----------------------------------------------------------------

@dataclass
class NewsEvent:
    time: pd.Timestamp  # UTC
    currency: str
    title: str

    def affects(self, pair: str) -> bool:
        return self.currency in (pair[:3], pair[3:], "ALL")


def parse_calendar(items: list[dict]) -> list[NewsEvent]:
    """Keep the high-impact (red) events from the ForexFactory weekly feed."""
    events = []
    for item in items:
        if item.get("impact") != "High":
            continue
        try:
            when = pd.Timestamp(item["date"]).tz_convert("UTC")
        except (KeyError, ValueError, TypeError):
            continue
        events.append(NewsEvent(when, item.get("country", "").upper(), item.get("title", "")))
    return sorted(events, key=lambda e: e.time)


def fetch_calendar() -> list[NewsEvent]:
    cache = CACHE_DIR / "ff_calendar_thisweek.json"
    if cache.exists() and time.time() - cache.stat().st_mtime < CALENDAR_MAX_AGE:
        return parse_calendar(json.loads(cache.read_text()))

    request = urllib.request.Request(CALENDAR_URL, headers={"User-Agent": "fx_scanner/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read()
    items = json.loads(raw)
    CACHE_DIR.mkdir(exist_ok=True)
    cache.write_bytes(raw)
    return parse_calendar(items)


def demo_calendar(now: pd.Timestamp) -> list[NewsEvent]:
    day = now.normalize()
    return [
        NewsEvent(day + pd.Timedelta(hours=6), "GBP", "GDP q/q"),
        NewsEvent(now + pd.Timedelta(minutes=10), "EUR", "ECB President Lagarde Speaks"),
        NewsEvent(day + pd.Timedelta(hours=12, minutes=30), "USD", "Core PCE Price Index m/m"),
        NewsEvent(day + pd.Timedelta(hours=14), "USD", "Revised UoM Consumer Sentiment"),
    ]


def news_window(pair: str, events: list[NewsEvent], now: pd.Timestamp, minutes: int) -> tuple[NewsEvent | None, NewsEvent | None]:
    """Return (event blocking entries right now, next upcoming event) for a pair."""
    window = pd.Timedelta(minutes=minutes)
    relevant = [e for e in events if e.affects(pair)]
    blocking = next((e for e in relevant if abs(e.time - now) <= window), None)
    upcoming = next((e for e in relevant if e.time > now), None)
    return blocking, upcoming


# --- 2. Currency strength ------------------------------------------------------

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


def strength_tiers(strength: dict[str, float], size: int = 3) -> dict[str, str]:
    """Top `size` currencies are strong, bottom `size` weak, the rest neutral."""
    ranked = sorted(strength, key=strength.get, reverse=True)
    return {c: "strong" if i < size else "weak" if i >= len(ranked) - size else "neutral"
            for i, c in enumerate(ranked)}


def strength_direction(pair: str, tiers: dict[str, str]) -> tuple[int, str]:
    """+1 buy / -1 sell when the pair is strong vs weak, else 0 and the reason."""
    base, quote = tiers.get(pair[:3]), tiers.get(pair[3:])
    if base is None:  # e.g. gold: only the quote currency is ranked
        return {"weak": (1, ""), "strong": (-1, "")}.get(quote, (0, f"{pair[3:]} neutral"))
    if base == "strong" and quote == "weak":
        return 1, ""
    if base == "weak" and quote == "strong":
        return -1, ""
    if base == quote:
        return 0, f"both {base}"
    return 0, f"{pair[:3]} {base} / {pair[3:]} {quote}"


# --- 3 & 4. ADR and levels -----------------------------------------------------

@dataclass
class PairView:
    pair: str
    price: float
    direction: int
    adr_pips: float
    adr_used_pct: float
    trend: str
    strength_gap: float
    levels: dict[str, float]
    score: float
    status: str = "PASS"
    blocking: NewsEvent | None = None
    upcoming: NewsEvent | None = None
    notes: list[str] = field(default_factory=list)


def ema(series: pd.Series, length: int) -> float:
    return float(series.ewm(span=length, adjust=False).mean().iloc[-1])


def daily_trend(daily: pd.DataFrame, price: float) -> str:
    fast, slow = ema(daily["Close"], 20), ema(daily["Close"], 50)
    if price > fast > slow:
        return "up"
    if price < fast < slow:
        return "down"
    return "range"


def previous_week(daily: pd.DataFrame, today: pd.Timestamp) -> pd.DataFrame:
    monday = pd.Timestamp(today.date()) - pd.Timedelta(days=today.weekday())
    dates = pd.to_datetime(daily.index.date)
    return daily[(dates >= monday - pd.Timedelta(days=7)) & (dates < monday)]


def round_levels(pair: str, price: float) -> tuple[float, float]:
    """Nearest round number below and above price (every 50 pips)."""
    step = pip_size(pair) * 50
    below = math.floor(price / step) * step
    return below, below + step


def key_levels(pair: str, daily: pd.DataFrame, today: pd.DataFrame) -> dict[str, float]:
    asian = today.between_time(ASIAN_START, ASIAN_END)
    if asian.empty:
        asian = today
    prev_day = daily.iloc[-1]
    week = previous_week(daily, today.index[-1])
    price = float(today["Close"].iloc[-1])
    round_below, round_above = round_levels(pair, price)
    levels = {
        "Asian high": float(asian["High"].max()),
        "Asian low": float(asian["Low"].min()),
        "Prev-day high": float(prev_day["High"]),
        "Prev-day low": float(prev_day["Low"]),
    }
    if not week.empty:
        levels["Prev-week high"] = float(week["High"].max())
        levels["Prev-week low"] = float(week["Low"].min())
    levels["Round above"] = round_above
    levels["Round below"] = round_below
    return levels


def analyze(pair: str, daily: pd.DataFrame, intraday: pd.DataFrame,
            strength: dict[str, float], tiers: dict[str, str]) -> PairView | None:
    """daily: completed daily bars. intraday: 15-min bars in UTC ending now."""
    if len(daily) < 50 or intraday.empty:
        return None

    pip = pip_size(pair)
    today = split_today(intraday)
    price = float(today["Close"].iloc[-1])

    adr_pips = float((daily["High"] - daily["Low"]).tail(14).mean()) / pip
    today_pips = (float(today["High"].max()) - float(today["Low"].min())) / pip
    adr_used = today_pips / adr_pips * 100 if adr_pips else 0.0

    direction, reason = strength_direction(pair, tiers)
    gap = strength.get(pair[:3], 0.0) - strength.get(pair[3:], 0.0)
    trend = daily_trend(daily, price)
    aligned = (trend == "up" and direction > 0) or (trend == "down" and direction < 0)

    view = PairView(
        pair=pair,
        price=price,
        direction=direction,
        adr_pips=adr_pips,
        adr_used_pct=adr_used,
        trend=trend,
        strength_gap=gap,
        levels=key_levels(pair, daily, today),
        score=abs(gap) * 10 + max(0.0, 100 - adr_used) / 20 + (2 if aligned else 0),
    )
    if direction == 0:
        view.status = f"skip: {reason}"
    elif not aligned:
        view.notes.append("counter to the daily trend: half size")
    return view


# --- 5. Picks ------------------------------------------------------------------

def exposures(pair: str, direction: int) -> dict[str, int]:
    """Currency exposure of a trade: buying EURUSD is +EUR and -USD."""
    return {pair[:3]: direction, pair[3:]: -direction}


def choose_picks(views: list[PairView], returns: pd.DataFrame, max_picks: int) -> list[PairView]:
    """Best-scoring passing pairs, skipping any that repeat an existing pick's trade."""
    picks: list[PairView] = []
    for view in sorted(views, key=lambda v: v.score, reverse=True):
        if view.status != "PASS":
            continue
        if len(picks) >= max_picks:
            view.status = "reserve"
            continue
        for pick in picks:
            shared = [c for c, d in exposures(view.pair, view.direction).items()
                      if exposures(pick.pair, pick.direction).get(c) == d]
            corr = 0.0
            if view.pair in returns and pick.pair in returns:
                corr = float(returns[view.pair].corr(returns[pick.pair])) * view.direction * pick.direction
            if shared or corr > MAX_CORRELATION:
                why = f"same {'/'.join(shared)} exposure" if shared else f"corr {corr:.2f}"
                view.status = f"skip: duplicates {pick.pair} ({why})"
                break
        else:
            picks.append(view)
    return picks


def setup_idea(view: PairView) -> str:
    side = "long" if view.direction > 0 else "short"
    asian_range = (view.levels["Asian high"] - view.levels["Asian low"]) / pip_size(view.pair)
    if asian_range < view.adr_pips * 0.5:
        return f"Tight Asian range: Asian breakout {side} (A), then 20 EMA pullbacks (C)"
    return f"20 EMA pullback {side} (C) or break-and-retest of a marked level (D)"


# --- Data ------------------------------------------------------------------------

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


# --- Report ------------------------------------------------------------------------

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
    now = max(intraday.index[-1] for _, intraday in data.values()) if args.demo else pd.Timestamp.now(tz="UTC")

    # 1. News
    print(f"\n1. HIGH-IMPACT NEWS TODAY (ForexFactory, UTC)  -- now {now:%a %H:%M} UTC")
    try:
        events = demo_calendar(now) if args.demo else fetch_calendar()
    except Exception as exc:
        events = None
        print(f"  Could not load the calendar ({exc}). Check forexfactory.com manually before trading!")
    if events is not None:
        todays = [e for e in events if e.time.date() == now.date()]
        if not todays:
            print("  No red events today.")
        for e in todays:
            start = e.time - pd.Timedelta(minutes=args.news_window)
            end = e.time + pd.Timedelta(minutes=args.news_window)
            state = "PASSED" if end < now else "NOW" if start <= now else ""
            print(f"  {e.time:%H:%M}  {e.currency:<4} {e.title:<40} no entries {start:%H:%M}-{end:%H:%M}  {state}")

    # 2. Strength
    strength = currency_strength(changes)
    tiers = strength_tiers(strength)
    ranked = sorted(strength.items(), key=lambda kv: kv[1], reverse=True)
    print("\n2. CURRENCY STRENGTH (% vs other majors since 00:00 UTC)")
    for cur, value in ranked:
        bar = ("+" if value > 0 else "-") * min(20, int(abs(value) * 40))
        print(f"  {cur}  {value:+.2f}  {tiers[cur]:<8} {bar}")
    print(f"  Best match: strongest {ranked[0][0]} vs weakest {ranked[-1][0]}")

    # 3. Screen every candidate: strength, ADR, news
    views = []
    for pair in pairs:
        if pair not in data:
            print(f"  skip {pair}: no data", file=sys.stderr)
            continue
        view = analyze(pair, *data[pair], strength, tiers)
        if view is None:
            print(f"  skip {pair}: not enough history", file=sys.stderr)
            continue
        if events is not None:
            view.blocking, view.upcoming = news_window(pair, events, now, args.news_window)
        if view.status == "PASS" and view.adr_used_pct >= args.max_adr:
            view.status = f"skip: {view.adr_used_pct:.0f}% of ADR used"
        views.append(view)

    returns = pd.DataFrame({p: d["Close"].pct_change() for p, (d, _) in data.items()}).tail(60)
    picks = choose_picks(views, returns, args.picks)

    print(f"\n3. SCREEN  (strong vs weak, ADR used < {args.max_adr:.0f}%, no duplicate trades)\n")
    print(f"{'Pair':<8}{'Side':<6}{'ADR':>5}{'Used%':>7}{'Trend':>7}{'Gap':>7}  Status")
    print("-" * 72)
    order = {"PASS": 0, "reserve": 1}
    for v in sorted(views, key=lambda v: (order.get(v.status, 2), -v.score)):
        side = {1: "BUY", -1: "SELL"}.get(v.direction, "-")
        status = "PICK" if v in picks else v.status
        print(f"{v.pair:<8}{side:<6}{v.adr_pips:>5.0f}{v.adr_used_pct:>7.0f}{v.trend:>7}{v.strength_gap:>+7.2f}  {status}")

    # 4 & 5. Picks with levels
    print(f"\n4. TODAY'S PICKS ({len(picks)}) AND LEVELS TO MARK")
    if not picks:
        print("  Nothing passes today. No trade is a valid trade.")
    elif len(picks) < 2:
        print("  Only one pair qualifies. Don't force a second one.")
    for v in picks:
        side = "BUY" if v.direction > 0 else "SELL"
        print(f"\n{v.pair}  {side} @ {fmt(v.pair, v.price)}   ADR {v.adr_pips:.0f} pips, {v.adr_used_pct:.0f}% used")
        for name, level in sorted(v.levels.items(), key=lambda kv: -kv[1]):
            print(f"  {name:<15}{fmt(v.pair, level)}")
        print(f"  Setup: {setup_idea(v)}")
        print(f"  Stop guide ~{v.adr_pips * 0.2:.0f} pips (20% ADR); 2R target ~{v.adr_pips * 0.4:.0f} pips")
        if v.blocking:
            print(f"  !! NEWS NOW: {v.blocking.currency} {v.blocking.title} at {v.blocking.time:%H:%M}. "
                  f"Wait until {v.blocking.time + pd.Timedelta(minutes=args.news_window):%H:%M}.")
        elif v.upcoming:
            print(f"  Next red news: {v.upcoming.currency} {v.upcoming.title} at {v.upcoming.time:%a %H:%M}. "
                  f"No entries from {v.upcoming.time - pd.Timedelta(minutes=args.news_window):%H:%M}.")
        elif events is None:
            print("  News: calendar unavailable. Check ForexFactory before entering.")
        for note in v.notes:
            print(f"  Note: {note}")
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

    p = argparse.ArgumentParser(description="Forex morning scanner: news, strength, ADR, levels, picks")
    p.add_argument("pairs", nargs="*", help="candidate pairs, e.g. EURUSD GBPJPY (default: 20 majors/crosses + gold)")
    p.add_argument("--picks", type=int, default=3, help="max pairs to pick (default 3)")
    p.add_argument("--max-adr", type=float, default=75, help="skip pairs that used this %% of ADR (default 75)")
    p.add_argument("--news-window", type=int, default=15, help="no-entry minutes around red news (default 15)")
    p.add_argument("--demo", action="store_true", help="use synthetic prices and news (no network)")
    return scan(p.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
