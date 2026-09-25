# Forex Day-Trading Playbook

A repeatable daily system: know **when** to trade (sessions and news),
**what** to trade (strong currency vs weak currency, with room left to move),
and **how** to trade it (a few written setups with fixed risk).

> Not financial advice. Leveraged forex trading loses most retail traders money.
> Demo trade this system for at least 20 sessions and keep a journal before
> risking real money.

All times are **UTC**. Add your own offset (for example UTC+3: London open
07:00 UTC = 10:00 local). Times shown are for European/US summer time; from late
October/early November to March, London and New York times move **one hour later**.

---

## 1. When to trade: the sessions

| Session | UTC (summer) | Character |
|---|---|---|
| Sydney | 21:00 – 06:00 | Quiet. Wide spreads around 21:00 rollover |
| Tokyo (Asian) | 00:00 – 09:00 | Ranges. JPY, AUD, NZD pairs move most. **Builds the Asian range** |
| **London** | **07:00 – 16:00** | Biggest volume. Breakouts from the Asian range; the day's trend often starts here |
| **New York** | **12:00 – 21:00** | US data at 12:30. Continuation or reversal of the London move |
| **London–NY overlap** | **12:00 – 16:00** | Highest liquidity and tightest spreads |

**Your trading windows:** London open (07:00–10:00) and the overlap (12:00–16:00).
Outside these, most pairs chop and spreads are wider. Avoid 20:45–22:00 UTC (rollover).

---

## 2. Daily timeline

| Time (UTC) | Task |
|---|---|
| **Sunday / weekend** | Weekly review. Mark previous-week high/low on your pairs. Check the week's calendar for central-bank meetings, CPI, NFP |
| **06:00 – 06:45** | Economic calendar (ForexFactory: red = high impact). Note every red event for your currencies today |
| **06:15 – 06:45** | Run `fx_scanner.py`: currency strength, ADR used, Asian range, key levels. Pick **2–3 pairs** |
| **06:45 – 07:00** | Mark levels on each pair and write the plan: setup, entry trigger, stop, target, and the news times to avoid |
| **07:00 – 10:00** | London session: Asian-range breakout / sweep setups |
| **10:00 – 12:00** | Manage open trades; few new entries |
| **12:00 – 16:00** | Overlap: trend pullbacks and break-and-retest setups. Be flat or protected before 12:30 US data |
| **After 16:00** | Stop taking new trades (unless you have a tested NY setup). Journal everything |

---

## 3. What to watch every morning

1. **Economic calendar.** High-impact events move pairs 30–100+ pips in seconds:
   - US: NFP (first Friday, 12:30), CPI (12:30), FOMC decision (18:00), retail sales, ISM PMI (14:00)
   - UK: CPI / GDP (06:00), BoE decision (11:00)
   - Eurozone: CPI / PMIs (~08:00–09:00), ECB decision (12:15)
   - Japan: BoJ decision (Asian session, no fixed time); Australia RBA; Canada BoC; Swiss SNB
   - **Rule:** no new entries 15 minutes before a red event on either currency of your pair; close or move stop to breakeven.
2. **Currency strength.** Which currency is strongest and which is weakest today?
   The best pair is **strong vs weak** (e.g. strong GBP, weak JPY → buy GBPJPY).
   Avoid pairing two strong or two weak currencies — they chop.
3. **Risk sentiment.** Stock indexes up / VIX down = "risk-on" → AUD, NZD strong;
   JPY, CHF weak. Risk-off is the reverse. USD often strengthens on risk-off.
4. **US 10-year yield and DXY (dollar index).** Rising yields usually = stronger USD.
5. **Gold (XAUUSD)**: if you trade it, it usually moves opposite to USD and yields.

---

## 4. What to look for in a pair

| Filter | Rule | Why |
|---|---|---|
| **Strength gap** | Base and quote currency at opposite ends of the strength ranking | Clean directional move |
| **Daily trend** | Price above 20 & 50-day EMA for longs, below for shorts | Trade with the bigger flow |
| **ADR room** | Today's range < 70 % of the 14-day **average daily range** | If 80–100 % of ADR is used, the move is probably done |
| **Asian range** | Tight (< ~50 % of ADR) for breakout setups | Tight range = energy for London |
| **Spread** | ≤ 1.5 pips on majors | Spread is a cost on every trade |
| **Clean levels** | Clear prev-day / prev-week high-low, round numbers nearby | Defined entries and stops |
| **No red news** | No high-impact news on either currency in the next 2 hours (unless trading post-news setup) | Avoid random spikes |

**Correlation:** EURUSD, GBPUSD, AUDUSD, NZDUSD all move largely with (inverse) USD.
Being long two of them is almost the same trade twice — **double risk**. Pick one.

### Levels to mark on every pair
- Asian session high / low (00:00–07:00 UTC)
- Previous day high / low / close, and today's open
- Previous week high / low
- Round numbers (1.1000, 1.0950, 150.00…)
- Major daily/4H support and resistance, 20 & 50 EMA

### Suggested starting list
Master **2–4 pairs** rather than watching 20: **EURUSD, GBPUSD, USDJPY**, plus one of
GBPJPY / AUDUSD / XAUUSD (gold) once you are consistent. Gold and GBPJPY move a lot —
use smaller size.

---

## 5. The setups

Start with **A and C**. Add others only after 20+ journaled trades show an edge.

### A — Asian Range Breakout (London open)
- **Setup:** Asian range is tight (< ~50 % of ADR). Pair has a strength gap and a daily trend.
- **Entry:** A 15-minute candle **closes** outside the Asian range in the trend direction
  between 07:00 and 09:00. Conservative: wait for a retest of the range edge.
- **Stop:** Back inside the range — at the range midpoint, or the opposite side if the range is small.
- **Target:** 2R, or a distance equal to the range height. Take half at 1R+, move stop to breakeven.
- **Skip if:** the breakout candle is huge (chasing), or red news is due within 60 min.

### B — London Liquidity Sweep (fake-out reversal)
- **Setup:** In the first 1–2 hours of London, price spikes **above the Asian high** (or the
  previous-day high) — taking stops — then **closes back inside** the range.
- **Entry:** On a 5 or 15-min rejection candle (long wick, close back inside), or on the break
  of that candle's low. Mirror for sweeps of the low.
- **Stop:** A few pips beyond the sweep's extreme.
- **Target:** Asian range midpoint, then the opposite side of the Asian range.
- **Best when:** the sweep goes **against** the daily trend / strength picture.

### C — Trend Pullback to the 20 EMA
- **Setup:** Pair trending on 1H (higher highs and higher lows, price above the 20 & 50 EMA,
  EMAs pointing up). Strong currency vs weak currency.
- **Entry:** Price pulls back to the 20 EMA / previous breakout level on the 15-min chart; enter on
  a bullish engulfing or the break of the pullback's high.
- **Stop:** Below the pullback swing low.
- **Target:** Previous high for partial, then trail under 15-min swing lows.
- **Skip if:** ADR is > 80 % used or the pullback breaks the last higher low.

### D — Break and Retest of a Key Level
- **Setup:** Price breaks the previous-day high/low or a round number with momentum
  (usually London or the overlap).
- **Entry:** When price **returns to the broken level and holds** (rejection candle at the level).
- **Stop:** On the other side of the level, beyond the retest wick.
- **Target:** Next key level (prev-week high, next round number), minimum 2R.

### E — Post-News Continuation (advanced)
- **Never trade the spike itself** — spreads widen and slippage is severe.
- Wait **15 minutes** after the release. Mark the post-news high/low.
- Enter on a break and retest of that range **in the direction of the initial move**.
- Stop beyond the opposite side of the post-news range. Half size.

### A+ checklist — every box must be ticked for full size
- [ ] Trading inside my window (London open or the overlap)
- [ ] Strong vs weak currency, in the direction of the daily trend
- [ ] Less than 70 % of ADR used
- [ ] No red news on either currency in the next 60 minutes
- [ ] Clear level for the stop, at least 2R of room to the next level
- [ ] It's one of my written setups
- [ ] Not already in a correlated trade; under my daily loss limit

Anything missing → half size or no trade.

---

## 6. Risk management

**Position size** (always calculate — never pick a lot size by feel):

```
lots = (account × risk %) ÷ (stop in pips × pip value per 1 lot)
```

| Lot | Units | Pip value on EURUSD / GBPUSD (USD account) |
|---|---|---|
| Standard 1.00 | 100,000 | $10.00 |
| Mini 0.10 | 10,000 | $1.00 |
| Micro 0.01 | 1,000 | $0.10 |

Example: $2,000 account, 1 % risk = $20, stop 15 pips on EURUSD →
20 ÷ (15 × 10) = **0.13 lots**. `python fx_scanner.py size --account 2000 --risk 1 --stop 15 --pair EURUSD`
does this for you (including USDJPY, XAUUSD, and cross pairs).

**Rules**
- Risk **0.5 – 1 %** of the account per trade.
- **Daily stop:** −2 % (or 2 losing trades). **Weekly stop:** −5 %. Hit it → stop trading.
- Max **3 trades per day**, max **1 position per currency** exposure.
- Minimum **2:1** reward-to-risk to the first target.
- Never widen a stop, never add to a loser, never trade to "win it back".
- Leverage: however much your broker offers, keep your total open position under ~10× your account.
- Use a **regulated broker** (e.g. FCA, ASIC, CySEC, or your own country's financial regulator).
  Avoid "account managers", signal groups promising fixed monthly returns, and anyone who
  asks for your login.

---

## 7. Journal and weekly review

Log: date, pair, session, setup (A–E), strength picture, entry, stop, exit, pips, **R result**,
screenshot before and after, "followed my plan? Y/N".

Every weekend:
1. Which setup and which session made the most R? Do more of that.
2. Which pair suits you? Drop the ones that consistently lose.
3. How much did rule-breaking trades cost?
4. One rule to focus on next week.

---

## 8. Tools

| Job | Tool |
|---|---|
| Charts & execution | **MetaTrader 5** (from the reel — offered by most forex brokers), or TradingView connected to your broker |
| Economic calendar | ForexFactory.com (free), Investing.com |
| Currency strength / levels | `fx_scanner.py` (this repo), or a strength meter indicator in MT5/TradingView |
| Journal | TradeZella (from the reel), or a spreadsheet |
| Advanced charting / alerts | TrendSpider or TradingView alerts on your marked levels |

From the reel, Trade Ideas, Finviz, Unusual Whales and Benzinga Pro are stock-market tools — you
don't need them for forex. And no platform "makes you $10k/mo": your setups, risk control and
journal do.

---

## 9. Using `fx_scanner.py`

```bash
pip install yfinance pandas numpy

python fx_scanner.py                          # scan default pairs: strength + watchlist + levels
python fx_scanner.py EURUSD GBPJPY XAUUSD     # scan your own pairs
python fx_scanner.py --demo                   # offline demo with synthetic data

python fx_scanner.py size --account 2000 --risk 1 --stop 15 --pair EURUSD
python fx_scanner.py size --account 2000 --risk 1 --stop 25 --pair USDJPY --price 148.50
python fx_scanner.py size --account 2000 --risk 1 --stop 20 --pair EURGBP --quote-usd 1.34
```

Run the scan around **06:15–06:45 UTC** (before London) and again around **11:45 UTC**
(before the overlap). It prints:

1. **Currency strength ranking** for today (USD, EUR, GBP, JPY, AUD, NZD, CAD, CHF).
2. **Watchlist**, ranked by strength gap and ADR room: today's change, ADR in pips,
   % of ADR used, daily trend, and a suggested setup.
3. **Key levels** for each pair: Asian high/low, previous-day high/low, today's open.

Data comes from Yahoo Finance and can be delayed or differ slightly from your broker —
always confirm levels on your MT5 chart before trading.
