# FX Daily System (Nairobi)

A forex day-trading system that combines the platforms from the "Trading platforms that
will make you 10k/mo" list. Each platform answers a different question about the market.
You score those answers into one **daily bias**, and MetaTrader 5 only lets through trades
that agree with it. All times are **Nairobi (EAT, UTC+3)**.

- **[Bias Scorecard](https://claude.ai/artifact/JV5vQefpof3cUgLxNwbSRG)** (also `bias/scorecard.html`):
  score each currency across 7 layers every morning, see the pairs to focus on, and copy the
  bias into MT5.
- `mt5/FX_Daily_System.mq5`: the MT5 program. It applies your bias, and handles news windows,
  currency strength, ADR, levels, picks, lot sizes, alerts and the journal. It never places trades.

> Not financial advice. Most retail forex traders lose money. Run this on an MT5
> **demo account** for at least 20 trading days before using real money.

---

## 1. How the platforms combine

The edge comes from agreement between different kinds of evidence: interest rates
(fundamentals), positioning, news, risk mood, trend and today's price action. When most layers
point the same way for a currency, you trade it against the currency where most point the other way.

| Layer (weight) | Question it answers | Platform and what exactly to use | When (Nairobi) |
|---|---|---|---|
| **Rate differentials** (×2) | Where is money being pulled by interest rates? | **Koyfin**: charts of each country's 2-year yield minus the US 2-year (e.g. Germany 2Y − US 2Y for EUR), US 10-year, dollar index. Custom formulas and dashboards | 09:00 |
| **Central banks and headlines** (×2) | What's driving the currency today? | **Benzinga Pro**: audio squawk and real-time headlines on central banks, data and geopolitics | 09:00, then live |
| **Positioning** (×1) | Who is already long or short? | **Finviz**: currency futures pages (COT data). **Interactive Brokers**: CME currency futures volume and open interest in TWS; the only *real* volume in forex | Weekend (COT is released Friday) |
| **Options flow** (×1) | Are big players betting on a move? | **Unusual Whales**: sweeps and blocks on currency funds: UUP (USD), FXE (EUR), FXB (GBP), FXY (JPY), FXA (AUD), FXC (CAD), FXF (CHF) | Previous US session, 16:30–23:00 |
| **Risk mood** (×1) | Risk-on or risk-off? | **Koyfin**: S&P 500 futures, VIX. **Trade Ideas**: relative volume in defensive (XLU, XLP) vs cyclical (XLK, XLY) funds and in the currency funds | 09:00, recheck 16:30 |
| **Higher-timeframe trend** (×1) | Which way is the bigger trend? | **TrendSpider**: multi-timeframe analysis, automatic trendlines, seasonality by hour/day/month. **Finviz**: forex performance by week and month | Weekend, check at 09:00 |
| **Today's strength** (×2) | What is price actually doing today? | **MetaTrader 5** (FX Daily System panel): currency strength across 20 pairs | 09:30 and 14:30 |
| **Review** | Does the bias actually give an edge? | **TradeZella**: MT5 auto-sync, tag each trade with its bias score and setup, playbooks, backtesting on forex data | After 19:00, weekends |
| Execution | | **MetaTrader 5** through your broker. **Interactive Brokers** as an alternative broker (it doesn't run MT5) | |

**Left out: Click.Trade.** It trades Solana memecoin pools (Raydium, Meteora, Pumpswap)
and has no forex market. Don't confuse it with "ClickTrades", an offshore broker
(Seychelles) with many complaints.

**Scoring.** Each layer gives each currency +1, 0 or −1, multiplied by its weight, so a
currency scores from −10 to +10. **Pair bias = base score − quote score.**
- Under 3: no trade.
- 3–5: half size.
- 6 or more: full size.

The scorecard lists the strongest-vs-weakest pairs. Paste its bias string into MT5 and the
program skips any pick with a bias under 3 or one that points against the trade.

**Cost.** MT5, Finviz and Koyfin have useful free versions. Interactive Brokers costs nothing
to open. TrendSpider, Trade Ideas, TradeZella, Benzinga Pro and Unusual Whales are paid, with
trials or limited free tiers. If you drop one, set its row to 0 and the rest still work.

**Broker.** From Kenya, use an MT5 broker licensed by the **Capital Markets Authority (CMA)**.

Sources: [Koyfin fixed income and yields](https://www.koyfin.com/data-coverage/fixed-income/),
[Koyfin custom formulas](https://www.koyfin.com/help/custom-formulas/),
[Benzinga Pro squawk](https://www.benzinga.com/pro/feature/squawk),
[Finviz forex performance](https://finviz.com/forex_performance),
[Finviz currency futures](https://finviz.com/futures_charts?t=CURRENCIES&p=d),
[IBKR market scanners](https://interactivebrokers.com/en/?f=%2Fen%2Fsoftware%2Fpdfhighlights%2FPDF-marketscanners.php),
[CME FX volume and open interest](https://www.cmegroup.com/market-data/browse-data/fx-volume.html),
[Unusual Whales flow alerts](https://unusualwhales.com/option-flow-alerts),
[Trade Ideas relative volume](https://www.trade-ideas.com/learning-center/stock-scanning/relative-volume-scanner-strategies/),
[TrendSpider charting](https://trendspider.com/product/analyze-and-chart-any-market-asset/),
[TradeZella MT4/MT5 auto-sync](https://www.tradezella.com/blog/metatrader-4-and-metatrader-5-broker-auto-sync),
[MQL5 economic calendar](https://www.mql5.com/en/docs/calendar),
[Click.Trade (Latitude.sh case study)](https://www.latitude.sh/customers/click-trade).

---

## 2. Sessions and news times in Nairobi

Nairobi has no daylight saving, but London and New York do, so their hours shift
for you. The MT5 program works this out automatically.

| | **Now until 25 Oct 2026** | **26 Oct – 1 Nov 2026** | **From 2 Nov 2026 to March** |
|---|---|---|---|
| Asian range (Tokyo) | 03:00 – 10:00 | 03:00 – 11:00 | 03:00 – 11:00 |
| **London** | **10:00** – 19:00 | **11:00** – 20:00 | **11:00** – 20:00 |
| **New York** | **15:00** – 00:00 | **15:00** – 00:00 | **16:00** – 01:00 |
| **London–New York overlap (best)** | **15:00 – 19:00** | 15:00 – 20:00 | **16:00 – 20:00** |
| Rollover (wide spreads, don't trade) | 23:45 – 01:00 | 23:45 – 01:00 | 00:45 – 02:00 |

| Red news (typical) | Summer | Winter |
|---|---|---|
| RBA / BoJ (Australia, Japan central banks) | 06:00 – 08:00 | 06:00 – 08:00 |
| UK data (CPI, GDP, jobs) | 09:00 | 10:00 |
| Eurozone PMIs, CPI | 10:30 – 12:00 | 11:30 – 13:00 |
| Bank of England decision | 14:00 | 15:00 |
| ECB decision | 15:15 | 16:15 |
| **US data (NFP, CPI, retail sales)** and Canada data | **15:30** | **16:30** |
| US 10:00 data (ISM, consumer sentiment) | 17:00 | 18:00 |
| **FOMC (Fed) decision** | **21:00** | **22:00** |

The exact list for each day comes from the MT5 calendar, and the program shows it for you.

---

## 3. The daily routine (Nairobi time; winter times in brackets)

| Time | What you do | Platform |
|---|---|---|
| **Weekend** | Positioning: COT on the Finviz currency futures pages, CME open interest in IBKR. Higher-timeframe trend: TrendSpider daily/4-hour trendlines and seasonality for your pairs, Finviz week/month performance. Enter these two rows in the scorecard on Monday. Review last week in TradeZella. Check next week's red events in the MT5 calendar | Finviz, IBKR, TrendSpider, TradeZella, MT5 |
| **08:30 – 09:00 (09:30 – 10:00)** | **Rate differentials:** open the Koyfin dashboard with the 2-year yield spreads, US 10-year and dollar index. **Risk mood:** S&P 500 futures and VIX on Koyfin | Koyfin |
| 08:30 – 09:00 | **News:** Benzinga Pro headlines since the US close; turn on the squawk. **Options flow:** last US session's sweeps and blocks on UUP, FXE, FXB, FXY, FXA, FXC, FXF | Benzinga Pro, Unusual Whales |
| **09:00 – 09:30 (10:00 – 10:30)** | **Today's strength** from the MT5 panel. Score all 7 rows in the **Bias Scorecard**, then copy the bias string into MT5 (FX_Daily_System inputs → InpBias) | Scorecard, MT5 |
| **09:30 (10:30)** | Push brief on your phone: picks that pass your bias, plus today's red news | MT5 mobile |
| 09:30 – 10:00 | Open a 15-minute chart for each pick; levels appear automatically. In TrendSpider, check the pick's trendlines on the same timeframe. Write entry, stop and target | MT5, TrendSpider |
| **10:00 – 13:00 (11:00 – 14:00)** | **London window:** setups A and B. Squawk on | MT5, Benzinga Pro |
| 13:00 – 15:00 | Manage open trades. Watch for BoE at 14:00 and ECB at 15:15 on meeting days | MT5 |
| **14:30 (15:30)** | Second brief. Update **Today's strength** in the scorecard and re-paste if a currency flipped | MT5, Scorecard |
| **15:30 (16:30)** | US data. No entries 15:15 – 15:45 | MT5 alert |
| **16:30 (17:30)** | US stock market opens: recheck **risk mood** with Trade Ideas relative volume (defensive vs cyclical funds, currency funds) and live Unusual Whales flow on currency funds | Trade Ideas, Unusual Whales |
| **15:45 – 19:00 (16:45 – 20:00)** | **Overlap window:** setups C, D, E | MT5 |
| **19:00 (20:00)** | No new trades. In TradeZella, tag each synced trade with its setup and pair bias score | TradeZella |

### What the MT5 program does automatically

0. **Your bias:** skips any pair whose bias from the scorecard points against the trade or is
   below 3, and ranks stronger-bias pairs higher.
1. **News:** reads today's **high-impact** events from the MT5 economic calendar for the
   8 major currencies, shows each with its no-entry window (±15 min) and flags picks inside
   a window **now**. Sends a push alert 30 minutes before red news on any pick.
2. **Strongest vs weakest:** ranks USD, EUR, GBP, JPY, AUD, NZD, CAD, CHF by today's move
   across 20 pairs. Top 3 = strong, bottom 3 = weak. **Only strong-vs-weak pairs pass**;
   strong/strong, weak/weak or anything with a neutral currency is skipped (reason shown).
3. **Daily range left:** skips any pair that has used **75 %** or more of its 14-day average
   daily range (ADR).
4. **Levels:** draws on every open chart of a scanned pair: Asian high/low (orange),
   previous-day high/low (blue), previous-week high/low (magenta, dashed), nearest round
   numbers (grey, dotted). Also listed in the panel.
5. **2–3 picks:** takes the best-scoring pairs and skips any that repeat a trade already
   picked, meaning the same currency on the same side (e.g. buying EURUSD and selling USDCHF
   are both "short USD") or pairs whose daily moves correlate above 0.7. Shows the **lot
   size** for each pick at your risk %, calculated from your broker's own contract values.

It also tracks today's result: it warns you when you hit the **daily stop (−2 %)** or
**3 trades**. And it writes every closed trade to the journal.

---

## 4. The setups

Only take trades on the picks. Start with **A and C**.

**A — Asian range breakout (10:00 – 12:00, winter 11:00 – 13:00)**
Asian range is tight (less than half the ADR). Entry: a 15-minute candle **closes** outside the
Asian range in the pick's direction. Stop: middle of the Asian range. Target: 2× risk. Take half
at 1× risk, then move the stop to entry.

**B — London fake-out (10:00 – 12:00)**
Price spikes beyond the Asian high/low or previous-day high/low, then closes back inside
on a 15-minute candle with a long wick. Enter in the pick's direction when the next candle breaks
that candle. Stop: beyond the spike. Target: the other side of the Asian range.

**C — Pullback to the 20 EMA (any window)**
Pick is trending on the 1-hour chart (price above the 20 and 50 EMA for buys). On the 15-minute
chart, wait for a pullback to the 20 EMA or a broken level, then enter on a bullish engulfing
candle (bearish for sells). Stop: beyond the pullback's swing. Target: last high, then trail.

**D — Break and retest (overlap, 15:45 – 19:00)**
Price breaks a marked level (previous-day or previous-week high/low, round number) and comes back to
it. Enter when the retest holds. Stop: the other side of the level. Target: next marked level, at
least 2× risk.

**E — After US news (from 15:45, winter 16:45)**
Never trade the spike at 15:30. Wait 15 minutes, mark the post-news high/low, and trade a
break-and-retest in the direction of the first move. Half size.

**Take the trade only if all of these are true:** it's a pick, you're inside a window,
you're outside every news window, it's one of A–E, the stop is at a marked level, there's room
for 2× risk, and you're under the daily stop and the trade limit. If anything is missing,
skip it or use half size.

---

## 5. Risk rules (the program shows each one)

- Risk **1 %** per trade (change `InpRiskPct`). The panel shows the lot size for a stop of
  20 % ADR. If you use a different stop, lots = risk ÷ (stop pips × pip value).
- Stop for the day at **−2 %** or after **3 trades**. Stop for the week at −5 %.
- At least **2:1** reward to risk. Never move a stop further away, and never add to a losing trade.
- Picks marked "counter-trend" (against the daily trend): half size.

---

## 6. Journal (TradeZella plus a backup CSV)

TradeZella is the main journal: connect MT5 auto-sync and tag every trade with its **setup
(A–E)** and **pair bias score**. Each week, compare trades with bias 6+ against trades with
bias 3–5. If the strong-bias trades don't earn more R, change the layer weights.

As a backup that always works, every closed trade is also written to `MQL5\Files\FX_Journal.csv` (in MT5: File → Open Data Folder
→ MQL5 → Files). Each row has: date, open and close time (Nairobi), session, pair, side, lots,
entry, exit, stop, pips, profit, **R multiple**, and whether it was a system pick. Two columns
are for you to fill in: **Setup (A–E)** and **Followed plan (Y/N)**.

Open it in Excel or Google Sheets every weekend and answer:
1. Which setup and which window made the most R? Do more of that.
2. What did trades that weren't picks, or where you didn't follow the plan, cost you?
3. Which pairs keep losing? Remove them from `InpPairs`.

---

## 7. Installation

1. **Install MT5** from your (CMA-licensed) broker and open a **demo** account.
2. In MT5: **File → Open Data Folder → MQL5 → Experts**. Copy `mt5/FX_Daily_System.mq5` there.
3. Press **F4** (MetaEditor), open the file and press **F7** (Compile). It should say 0 errors.
   If it shows errors, send me the text.
4. Back in MT5, right-click **Navigator → Expert Advisors → Refresh**. Drag **FX_Daily_System**
   onto an empty chart (any symbol). The panel appears on that chart.
5. **Inputs to check:**
   - `InpSuffix`: if your broker's symbols look like `EURUSDm` or `EURUSD.pro`, enter `m` or `.pro`.
   - Gold: if your broker calls it `GOLD`, change `XAUUSD` in `InpPairs` to `XAUUSD=GOLD`.
   - `InpRiskPct`, `InpDailyStopPct`, `InpMaxTrades`: your risk rules.
   - `InpBias`: paste today's string from the Bias Scorecard, for example
     `USD+9,EUR-6,GBP+8,JPY+7,AUD-10,NZD-6,CAD-3,CHF+2`. To change it during the day, open the
     program's properties (double-click it in the chart's top-right corner or press F7 on the chart).
     `InpMinBias` (default 3) is the minimum pair bias a pick needs.
6. **Phone alerts:** install the MT5 mobile app, then go to Settings → Messages and copy your
   **MetaQuotes ID**. In desktop MT5, go to Tools → Options → Notifications, tick "Enable push
   notifications", paste the ID and press Test.
7. Open 15-minute charts of the pairs you want levels on. To see the line names, right-click the
   chart → Properties → Show → tick **"Show object descriptions"**.
8. Keep MT5 running during your trading hours. The panel updates every minute.
