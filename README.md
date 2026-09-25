# FX Daily System (Nairobi)

A forex day-trading system built only on the **free** platforms from the
"Trading platforms that will make you 10k/mo" list. All times are **Nairobi (EAT, UTC+3)**.

- `mt5/FX_Daily_System.mq5`: a MetaTrader 5 program that runs the morning routine
  for you. It never places trades.
- This README: which platforms are used and why, the daily schedule, the setups,
  the risk rules and the installation steps.

> Not financial advice. Most retail forex traders lose money. Run this on an MT5
> **demo account** for at least 20 trading days before using real money.

---

## 1. The 10 platforms: what is free and what each one does here

| # | Platform | Free? | Forex? | Used in the system as |
|---|---|---|---|---|
| 8 | **MetaTrader 5** | Yes, the platform and demo accounts are free | Yes | **The core.** Charts, execution, built-in economic calendar, runs `FX_Daily_System`, push alerts to your phone |
| 6 | **Finviz** (free version) | Yes (delayed data; Elite is paid) | Forex performance page, currency futures charts, economic calendar | Second opinion on currency strength and the calendar |
| 10 | **Koyfin** (free plan) | Yes | Forex, macro dashboards, economic calendar with forecasts | "FX Morning" dashboard: dollar index, US 10-year yield, S&P 500, VIX, gold, oil |
| 9 | **Benzinga** (free benzinga.com, not Pro) | benzinga.com is free; Pro is paid (14-day trial) | Forex news section, economic calendar | Why a currency is moving (news behind the strength) |
| 4 | **Interactive Brokers** | Free paper-trading account; no minimum for a cash account | Yes | Optional. Only if you want IBKR as your broker. It does **not** run MT5, so this program won't work there |
| 2 | TrendSpider | **No** (paid 14-day trial, plans from about $54/month) | Not needed | Not used |
| 3 | Trade Ideas | Paid | **No**, US stocks only | Not used |
| 5 | TradeZella | **No** (7-day trial only) | Yes | Not used. The MT5 program writes your trade journal instead |
| 7 | Unusual Whales | Limited, delayed free tier | Stock options flow; forex data only in paid API | Not used |
| 1 | ClickTrade (Click.Trade) | Unknown | Unknown | Not used. The site gives no details of features or pricing. **Do not confuse it with "ClickTrades"**, a separate offshore broker (Seychelles) with many complaints |

**Broker:** MT5 runs through a broker. From Kenya, use a broker licensed by the
**Capital Markets Authority (CMA)** that offers MT5. Open a demo account there first.

Sources: [TrendSpider pricing (StockBrokers.com)](https://www.stockbrokers.com/review/tools/trendspider),
[Trade Ideas review (propfirmapp)](https://propfirmapp.com/trading-tools/trade-ideas),
[TradeZella pricing](https://www.tradezella.com/blog/tradezella-pricing),
[Unusual Whales pricing](https://unusualwhales.com/pricing),
[MQL5 economic calendar functions](https://www.mql5.com/en/docs/calendar),
[Finviz forex performance](https://finviz.com/forex_performance),
[Finviz currency futures charts](https://finviz.com/futures_charts?t=CURRENCIES&p=d),
[Koyfin free plan (Bullish Bears)](https://bullishbears.com/koyfin-review/),
[Benzinga forex news](https://www.benzinga.com/markets/forex),
[Benzinga economic calendar](https://www.benzinga.com/calendars/economic),
[IBKR paper trading](https://www.interactivebrokers.com/campus/trading-lessons/how-to-open-an-ibkr-paper-trading-account/),
[Click.Trade](https://click.trade/en),
[ClickTrades review (Forex Peace Army)](https://www.forexpeacearmy.com/forex-reviews/16198/clicktrades-review).

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
| **09:00 (10:00)** | Open MT5. The program has already run steps 1–5 (see below). Read the panel | MT5 |
| **09:30 (10:30)** | Push brief arrives on your phone: picks + today's red news | MT5 mobile |
| 09:00 – 09:40 | **Cross-check, 10 minutes:** | |
| | a) Does the strongest/weakest currency on the **Finviz forex performance** page agree with the MT5 panel? If they disagree, trade half size or skip | Finviz |
| | b) **Koyfin "FX Morning" dashboard:** dollar index and US 10-year yield rising → USD strength is backed. S&P 500 falling + VIX rising (risk-off) → JPY/CHF strong, AUD/NZD weak. Does that fit the picks? | Koyfin |
| | c) **Benzinga forex news:** find the headline behind the strongest and weakest currency. No news behind the move → it's more likely to fade: use setup B or skip | Benzinga |
| 09:40 – 10:00 | Open a 15-minute chart for each pick. The levels appear automatically. Write your entry, stop and target | MT5 |
| **10:00 – 13:00 (11:00 – 14:00)** | **London window:** setups A and B | MT5 |
| 13:00 – 15:00 | Manage open trades. Mind BoE 14:00 / ECB 15:15 on those days | MT5 |
| **14:30 (15:30)** | Second push brief before New York | MT5 mobile |
| **15:30 (16:30)** | US data. No entries 15:15 – 15:45 | MT5 alert |
| **15:45 – 19:00 (16:45 – 20:00)** | **Overlap window:** setups C, D, E | MT5 |
| **19:00 (20:00)** | No new trades. Journal: fill in "Setup" and "Followed plan" in `FX_Journal.csv` | MT5 / Excel |
| **Weekend** | Weekly review of the journal. Check next week's red events (MT5 calendar, week view) | MT5 |

### What the MT5 program does automatically (steps 1–5)

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

## 6. Journal (replaces TradeZella)

Every closed trade is written to `MQL5\Files\FX_Journal.csv` (in MT5: File → Open Data Folder
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
6. **Phone alerts:** install the MT5 mobile app, then go to Settings → Messages and copy your
   **MetaQuotes ID**. In desktop MT5, go to Tools → Options → Notifications, tick "Enable push
   notifications", paste the ID and press Test.
7. Open 15-minute charts of the pairs you want levels on. To see the line names, right-click the
   chart → Properties → Show → tick **"Show object descriptions"**.
8. Keep MT5 running during your trading hours. The panel updates every minute.
