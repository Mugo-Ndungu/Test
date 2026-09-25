//+------------------------------------------------------------------+
//| FX_Daily_System.mq5                                              |
//| Forex morning routine inside MetaTrader 5, in Nairobi time (EAT).|
//|                                                                  |
//|  0. Your daily bias from the Bias Scorecard filters every pick    |
//|  1. Red (high-impact) news from the MT5 economic calendar, with  |
//|     no-entry windows                                             |
//|  2. Currency strength: only strong-vs-weak pairs pass            |
//|  3. ADR check: skip pairs that already used too much of it       |
//|  4. Key levels drawn on your charts                              |
//|  5. 2-3 picks without duplicate trades, lot size per pick        |
//|  + push alerts to MT5 mobile, daily stop, trade journal (CSV)    |
//|                                                                  |
//| This program never opens, modifies or closes trades.             |
//+------------------------------------------------------------------+
#property copyright "FX Daily System"
#property version   "1.00"
#property description "Morning routine for forex day trading in Nairobi time: MT5 calendar news, currency strength, ADR, key levels, 2-3 picks, alerts and a trade journal. Does not trade."

input group "Pairs"
input string InpPairs        = "EURUSD,GBPUSD,AUDUSD,NZDUSD,USDJPY,USDCAD,USDCHF,EURGBP,EURJPY,GBPJPY,AUDJPY,EURAUD,GBPAUD,EURCHF,CADJPY,AUDNZD,GBPCAD,NZDJPY,CHFJPY,EURCAD,XAUUSD"; // Pairs (use PAIR=SYMBOL if your broker names differ, e.g. XAUUSD=GOLD)
input string InpSuffix       = "";     // Broker symbol suffix, e.g. m or .pro
input group "Daily bias (from the Bias Scorecard)"
input string InpBias         = "";     // Paste today's bias, e.g. USD+6,EUR-2,GBP+1,JPY-5,AUD+3,NZD+1,CAD0,CHF-2
input double InpMinBias      = 3;      // Minimum pair bias (base minus quote) to allow a pick
input group "Rules"
input double InpMaxAdrUsed   = 75;     // Skip pairs that used this % of ADR
input int    InpAdrDays      = 14;     // ADR period (days)
input int    InpNewsWindow   = 15;     // No entries this many minutes before/after red news
input int    InpMaxPicks     = 3;      // Max pairs to pick
input double InpMaxCorr      = 0.70;   // Picks correlated above this count as the same trade
input group "Risk"
input double InpRiskPct      = 1.0;    // Risk per trade, % of balance
input double InpStopAdrPct   = 20;     // Stop guide, % of ADR
input double InpDailyStopPct = 2.0;    // Stop trading after losing this % today
input int    InpMaxTrades    = 3;      // Max trades per day
input group "Alerts and display"
input bool   InpPush         = true;   // Push notifications to MT5 mobile
input int    InpNewsAlertMin = 30;     // Warn this many minutes before red news on a pick
input bool   InpDrawLevels   = true;   // Draw key levels on open charts of scanned pairs
input bool   InpJournal      = true;   // Log closed trades to MQL5\Files\FX_Journal.csv
input int    InpLocalOffset  = 3;      // Your UTC offset (Nairobi = 3, no daylight saving)

#define PREFIX "FXDS_"

string Currencies[8] = {"USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"};

struct PairInfo
  {
   string            pair;      // e.g. EURUSD
   string            symbol;    // broker symbol, e.g. EURUSDm
   bool              ok;        // symbol exists at this broker
   bool              valid;     // enough data for this refresh
   int               digits;
   double            pip;
   double            price;
   double            adrPips;
   double            usedPct;
   double            gap;       // base strength - quote strength
   double            score;
   int               dir;       // +1 buy, -1 sell, 0 no trade
   bool              counter;   // against the daily trend
   string            trend;
   string            status;
   double            asianHi, asianLo, pdh, pdl, pwh, pwl, roundUp, roundDn;
   double            stopPips, lots;
   double            bias;      // your daily bias for the pair: base minus quote
  };

struct NewsItem
  {
   datetime          gmt;
   string            cur;
   string            name;
   bool              tentative;
  };

PairInfo P[];
int      Picks[];
double   Strength[8];
string   Tier[8];
double   Bias[8];
bool     HasBias = false;
NewsItem News[];
datetime LastNewsLoad = 0;
bool     NewsOk = false;
string   Sent[];          // alert keys already sent today
int      SentDay = -1;
double   DayPl = 0, DayPlPct = 0;
int      DayTrades = 0;

//--- time helpers ----------------------------------------------------
int ServerOffset() { return (int)MathRound((double)(TimeTradeServer() - TimeGMT()) / 1800.0) * 1800; }
datetime ToServer(datetime gmt) { return gmt + ServerOffset(); }
datetime ToGmt(datetime server) { return server - ServerOffset(); }
datetime DayStart(datetime t) { return t - t % 86400; }
string Local(datetime gmt) { return TimeToString(gmt + InpLocalOffset * 3600, TIME_MINUTES); }

datetime MakeDate(int year, int month, int day)
  {
   MqlDateTime t;
   ZeroMemory(t);
   t.year = year;
   t.mon = month;
   t.day = day;
   return StructToTime(t);
  }

int DayOfWeek(datetime t)
  {
   MqlDateTime x;
   TimeToStruct(t, x);
   return x.day_of_week;
  }

int YearOf(datetime t)
  {
   MqlDateTime x;
   TimeToStruct(t, x);
   return x.year;
  }

datetime LastSunday(int year, int month)
  {
   datetime last = (month == 12) ? MakeDate(year + 1, 1, 1) - 86400 : MakeDate(year, month + 1, 1) - 86400;
   return last - DayOfWeek(last) * 86400;
  }

datetime NthSunday(int year, int month, int n)
  {
   datetime first = MakeDate(year, month, 1);
   return first + ((7 - DayOfWeek(first)) % 7 + 7 * (n - 1)) * 86400;
  }

// UK summer time: last Sunday of March to last Sunday of October, 01:00 GMT
bool UkSummer(datetime gmt)
  {
   int y = YearOf(gmt);
   return gmt >= LastSunday(y, 3) + 3600 && gmt < LastSunday(y, 10) + 3600;
  }

// US summer time: second Sunday of March 07:00 GMT to first Sunday of November 06:00 GMT
bool UsSummer(datetime gmt)
  {
   int y = YearOf(gmt);
   return gmt >= NthSunday(y, 3, 2) + 7 * 3600 && gmt < NthSunday(y, 11, 1) + 6 * 3600;
  }

datetime LondonOpen(datetime gmt) { return DayStart(gmt) + (UkSummer(gmt) ? 7 : 8) * 3600; }
datetime NyOpen(datetime gmt) { return DayStart(gmt) + (UsSummer(gmt) ? 12 : 13) * 3600; }

string SessionOf(datetime gmt)
  {
   datetime lo = LondonOpen(gmt), ny = NyOpen(gmt), lc = lo + 9 * 3600;
   if(gmt < lo)
      return "Asian";
   if(gmt < ny)
      return "London";
   if(gmt < lc)
      return "Overlap";
   return "New York";
  }

//--- symbol helpers --------------------------------------------------
string Base(string pair) { return StringSubstr(pair, 0, 3); }
string Quote(string pair) { return StringSubstr(pair, 3, 3); }

int CurIndex(string c)
  {
   for(int i = 0; i < 8; i++)
      if(Currencies[i] == c)
         return i;
   return -1;
  }

double PipSize(string pair, string sym)
  {
   if(Base(pair) == "XAU")
      return 0.1;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   return (digits == 3 || digits == 5) ? point * 10 : point;
  }

string Px(const PairInfo &p, double v) { return DoubleToString(v, p.digits); }

double Ema(const double &c[], int len)
  {
   double k = 2.0 / (len + 1), e = c[0];
   for(int i = 1; i < ArraySize(c); i++)
      e = c[i] * k + e * (1 - k);
   return e;
  }

double LotsFor(string sym, double stopDistance)
  {
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(tickSize <= 0 || tickValue <= 0 || step <= 0 || stopDistance <= 0)
      return 0;
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   double lossPerLot = stopDistance / tickSize * tickValue;
   // round down so the trade never risks more than planned
   double lots = MathFloor(risk / lossPerLot / step + 1e-9) * step;
   return lots < minLot ? 0 : lots;
  }

//--- 1. news ----------------------------------------------------------
void LoadNews()
  {
   ArrayResize(News, 0);
   datetime day = DayStart(TimeGMT());
   datetime from = ToServer(day), to = ToServer(day + 2 * 86400);
   NewsOk = false;
   for(int c = 0; c < 8; c++)
     {
      MqlCalendarValue values[];
      if(!CalendarValueHistory(values, from, to, NULL, Currencies[c]))
         continue;
      NewsOk = true;
      for(int i = 0; i < ArraySize(values); i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev) || ev.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;
         if(ev.time_mode != CALENDAR_TIMEMODE_DATETIME && ev.time_mode != CALENDAR_TIMEMODE_TENTATIVE)
            continue;
         int n = ArraySize(News);
         ArrayResize(News, n + 1);
         News[n].gmt = ToGmt(values[i].time);
         News[n].cur = Currencies[c];
         News[n].name = ev.name;
         News[n].tentative = ev.time_mode == CALENDAR_TIMEMODE_TENTATIVE;
        }
     }
   // sort by time
   for(int i = 0; i < ArraySize(News); i++)
      for(int j = i + 1; j < ArraySize(News); j++)
         if(News[j].gmt < News[i].gmt)
           {
            NewsItem t = News[i];
            News[i] = News[j];
            News[j] = t;
           }
   LastNewsLoad = TimeGMT();
  }

bool Affects(string pair, string cur) { return Base(pair) == cur || Quote(pair) == cur; }

int BlockingNews(string pair, datetime now)
  {
   for(int i = 0; i < ArraySize(News); i++)
      if(Affects(pair, News[i].cur) && MathAbs((double)(News[i].gmt - now)) <= InpNewsWindow * 60)
         return i;
   return -1;
  }

int NextNews(string pair, datetime now)
  {
   for(int i = 0; i < ArraySize(News); i++)
      if(Affects(pair, News[i].cur) && News[i].gmt > now)
         return i;
   return -1;
  }

//--- daily bias -------------------------------------------------------
// Parses "USD+6,EUR-2,..." from the Bias Scorecard into Bias[]
void ParseBias()
  {
   ArrayInitialize(Bias, 0);
   HasBias = false;
   string parts[];
   int n = StringSplit(InpBias, ',', parts);
   for(int i = 0; i < n; i++)
     {
      string token = parts[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      StringToUpper(token);
      if(StringLen(token) < 4)
         continue;
      int c = CurIndex(StringSubstr(token, 0, 3));
      if(c < 0)
         continue;
      string num = StringSubstr(token, 3);
      if(StringGetCharacter(num, 0) == '+')
         num = StringSubstr(num, 1);
      Bias[c] = StringToDouble(num);
      HasBias = true;
     }
  }

double PairBias(string pair)
  {
   int b = CurIndex(Base(pair)), q = CurIndex(Quote(pair));
   if(q < 0)
      return 0;
   // gold has no score of its own: it moves against the quote currency (USD)
   return (b >= 0 ? Bias[b] : 0) - Bias[q];
  }

//--- 2. strength ------------------------------------------------------
void UpdateStrength()
  {
   double sum[8];
   int cnt[8];
   ArrayInitialize(sum, 0);
   ArrayInitialize(cnt, 0);
   for(int i = 0; i < ArraySize(P); i++)
     {
      if(!P[i].ok)
         continue;
      int b = CurIndex(Base(P[i].pair)), q = CurIndex(Quote(P[i].pair));
      if(b < 0 || q < 0)
         continue;
      double open = iOpen(P[i].symbol, PERIOD_D1, 0), close = iClose(P[i].symbol, PERIOD_D1, 0);
      if(open <= 0 || close <= 0)
         continue;
      double chg = (close / open - 1) * 100;
      sum[b] += chg;
      cnt[b]++;
      sum[q] -= chg;
      cnt[q]++;
     }
   int idx[8];
   for(int i = 0; i < 8; i++)
     {
      Strength[i] = cnt[i] > 0 ? sum[i] / cnt[i] : 0;
      idx[i] = i;
     }
   for(int i = 0; i < 8; i++)
      for(int j = i + 1; j < 8; j++)
         if(Strength[idx[j]] > Strength[idx[i]])
           {
            int t = idx[i];
            idx[i] = idx[j];
            idx[j] = t;
           }
   for(int r = 0; r < 8; r++)
      Tier[idx[r]] = r < 3 ? "strong" : (r >= 5 ? "weak" : "neutral");
  }

int Direction(string pair, string &reason)
  {
   int b = CurIndex(Base(pair)), q = CurIndex(Quote(pair));
   if(q < 0)
     {
      reason = "quote currency not ranked";
      return 0;
     }
   if(b < 0)   // gold: only the quote currency is ranked
     {
      if(Tier[q] == "weak")
         return 1;
      if(Tier[q] == "strong")
         return -1;
      reason = Quote(pair) + " neutral";
      return 0;
     }
   if(Tier[b] == "strong" && Tier[q] == "weak")
      return 1;
   if(Tier[b] == "weak" && Tier[q] == "strong")
      return -1;
   reason = (Tier[b] == Tier[q]) ? "both " + Tier[b] : Base(pair) + " " + Tier[b] + " / " + Quote(pair) + " " + Tier[q];
   return 0;
  }

//--- 3 & 4. ADR and levels -------------------------------------------
bool Analyze(PairInfo &p)
  {
   string s = p.symbol;
   p.digits = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
   p.pip = PipSize(p.pair, s);
   p.price = SymbolInfoDouble(s, SYMBOL_BID);
   if(p.pip <= 0 || p.price <= 0)
      return false;

   double hi[], lo[], c[];
   if(CopyHigh(s, PERIOD_D1, 1, InpAdrDays, hi) != InpAdrDays || CopyLow(s, PERIOD_D1, 1, InpAdrDays, lo) != InpAdrDays)
      return false;
   if(CopyClose(s, PERIOD_D1, 1, 120, c) < 60)
      return false;
   double sum = 0;
   for(int i = 0; i < InpAdrDays; i++)
      sum += hi[i] - lo[i];
   p.adrPips = sum / InpAdrDays / p.pip;
   double today = iHigh(s, PERIOD_D1, 0) - iLow(s, PERIOD_D1, 0);
   p.usedPct = p.adrPips > 0 ? today / p.pip / p.adrPips * 100 : 0;

   p.pdh = iHigh(s, PERIOD_D1, 1);
   p.pdl = iLow(s, PERIOD_D1, 1);
   p.pwh = iHigh(s, PERIOD_W1, 1);
   p.pwl = iLow(s, PERIOD_W1, 1);

   // Asian range: 00:00 GMT (03:00 Nairobi) until the London open
   datetime now = TimeGMT();
   double ah[], al[];
   datetime aEndGmt = LondonOpen(now) < now ? LondonOpen(now) : now;
   datetime aStart = ToServer(DayStart(now)), aEnd = ToServer(aEndGmt) - 1;
   p.asianHi = 0;
   p.asianLo = 0;
   if(aEnd > aStart && CopyHigh(s, PERIOD_M15, aStart, aEnd, ah) > 0 && CopyLow(s, PERIOD_M15, aStart, aEnd, al) > 0)
     {
      p.asianHi = ah[ArrayMaximum(ah)];
      p.asianLo = al[ArrayMinimum(al)];
     }

   double step = p.pip * 50;
   p.roundDn = MathFloor(p.price / step) * step;
   p.roundUp = p.roundDn + step;

   double fast = Ema(c, 20), slow = Ema(c, 50);
   p.trend = (p.price > fast && fast > slow) ? "up" : ((p.price < fast && fast < slow) ? "down" : "range");

   string reason = "";
   p.dir = Direction(p.pair, reason);
   int b = CurIndex(Base(p.pair)), q = CurIndex(Quote(p.pair));
   p.gap = (b >= 0 ? Strength[b] : 0) - (q >= 0 ? Strength[q] : 0);
   bool aligned = (p.trend == "up" && p.dir > 0) || (p.trend == "down" && p.dir < 0);
   p.counter = p.dir != 0 && !aligned;
   p.bias = PairBias(p.pair);
   p.score = MathAbs(p.gap) * 10 + MathMax(0.0, 100 - p.usedPct) / 20 + (aligned ? 2 : 0) + MathAbs(p.bias) / 2;

   p.status = "PASS";
   if(p.dir == 0)
      p.status = "skip: " + reason;
   else
      if(p.usedPct >= InpMaxAdrUsed)
         p.status = StringFormat("skip: %.0f%% of ADR used", p.usedPct);
      else
         if(HasBias && p.bias * p.dir < 0)
            p.status = StringFormat("skip: against your daily bias (%+.0f)", p.bias);
         else
            if(HasBias && MathAbs(p.bias) < InpMinBias)
               p.status = StringFormat("skip: daily bias too weak (%+.0f)", p.bias);

   p.stopPips = MathMax(5.0, p.adrPips * InpStopAdrPct / 100);
   p.lots = LotsFor(s, p.stopPips * p.pip);
   return true;
  }

//--- 5. picks ---------------------------------------------------------
double Correlation(string s1, string s2)
  {
   double a[], b[];
   int n = 61;
   if(CopyClose(s1, PERIOD_D1, 1, n, a) != n || CopyClose(s2, PERIOD_D1, 1, n, b) != n)
      return 0;
   double ra[60], rb[60], ma = 0, mb = 0;
   for(int i = 0; i < 60; i++)
     {
      ra[i] = a[i + 1] / a[i] - 1;
      rb[i] = b[i + 1] / b[i] - 1;
      ma += ra[i];
      mb += rb[i];
     }
   ma /= 60;
   mb /= 60;
   double cov = 0, va = 0, vb = 0;
   for(int i = 0; i < 60; i++)
     {
      cov += (ra[i] - ma) * (rb[i] - mb);
      va += (ra[i] - ma) * (ra[i] - ma);
      vb += (rb[i] - mb) * (rb[i] - mb);
     }
   return (va > 0 && vb > 0) ? cov / MathSqrt(va * vb) : 0;
  }

// Same currency held on the same side, e.g. buying EURUSD and selling USDCHF are both short USD
bool SameExposure(const PairInfo &a, const PairInfo &b, string &cur)
  {
   string ab = Base(a.pair), aq = Quote(a.pair), bb = Base(b.pair), bq = Quote(b.pair);
   if(ab == bb && a.dir == b.dir)
     { cur = ab; return true; }
   if(ab == bq && a.dir == -b.dir)
     { cur = ab; return true; }
   if(aq == bb && a.dir == -b.dir)
     { cur = aq; return true; }
   if(aq == bq && a.dir == b.dir)
     { cur = aq; return true; }
   return false;
  }

void ChoosePicks()
  {
   ArrayResize(Picks, 0);
   int n = ArraySize(P);
   int order[];
   ArrayResize(order, n);
   for(int i = 0; i < n; i++)
      order[i] = i;
   for(int i = 0; i < n; i++)
      for(int j = i + 1; j < n; j++)
         if(P[order[j]].score > P[order[i]].score)
           {
            int t = order[i];
            order[i] = order[j];
            order[j] = t;
           }
   for(int k = 0; k < n; k++)
     {
      int i = order[k];
      if(!P[i].ok || !P[i].valid || P[i].status != "PASS")
         continue;
      if(ArraySize(Picks) >= InpMaxPicks)
        {
         P[i].status = "reserve";
         continue;
        }
      bool dup = false;
      for(int m = 0; m < ArraySize(Picks) && !dup; m++)
        {
         PairInfo pick = P[Picks[m]];
         string cur = "";
         if(SameExposure(P[i], pick, cur))
           {
            P[i].status = "skip: same " + cur + " exposure as " + pick.pair;
            dup = true;
           }
         else
           {
            double corr = Correlation(P[i].symbol, pick.symbol) * P[i].dir * pick.dir;
            if(corr > InpMaxCorr)
              {
               P[i].status = StringFormat("skip: moves with %s (corr %.2f)", pick.pair, corr);
               dup = true;
              }
           }
        }
      if(!dup)
        {
         int s = ArraySize(Picks);
         ArrayResize(Picks, s + 1);
         Picks[s] = i;
        }
     }
  }

//--- risk: today's results --------------------------------------------
void UpdateDay()
  {
   datetime serverNow = TimeTradeServer();
   DayPl = 0;
   DayTrades = 0;
   if(!HistorySelect(DayStart(serverNow), serverNow + 60))
      return;
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong t = HistoryDealGetTicket(i);
      long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      if(entry == DEAL_ENTRY_IN)
         DayTrades++;
      DayPl += HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_COMMISSION) + HistoryDealGetDouble(t, DEAL_SWAP);
     }
   double startBalance = AccountInfoDouble(ACCOUNT_BALANCE) - DayPl;
   DayPlPct = startBalance > 0 ? DayPl / startBalance * 100 : 0;
  }

//--- alerts -----------------------------------------------------------
bool AlreadySent(string key)
  {
   int today = (int)(TimeGMT() / 86400);
   if(today != SentDay)
     {
      ArrayResize(Sent, 0);
      SentDay = today;
     }
   for(int i = 0; i < ArraySize(Sent); i++)
      if(Sent[i] == key)
         return true;
   int n = ArraySize(Sent);
   ArrayResize(Sent, n + 1);
   Sent[n] = key;
   return false;
  }

void Notify(string msg)
  {
   if(StringLen(msg) > 255)
      msg = StringSubstr(msg, 0, 252) + "...";
   Print(msg);
   Alert(msg);
   if(InpPush && TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      SendNotification(msg);
  }

string PicksText()
  {
   if(ArraySize(Picks) == 0)
      return "No pair passes - no trade is a valid trade.";
   string s = "";
   for(int k = 0; k < ArraySize(Picks); k++)
     {
      PairInfo p = P[Picks[k]];
      s += (k > 0 ? ", " : "") + p.pair + (p.dir > 0 ? " BUY" : " SELL");
     }
   return s;
  }

string TodaysNewsText(datetime now)
  {
   string s = "";
   for(int i = 0; i < ArraySize(News); i++)
      if(DayStart(News[i].gmt) == DayStart(now) && News[i].gmt > now)
         s += (s == "" ? "" : "; ") + Local(News[i].gmt) + " " + News[i].cur + " " + News[i].name;
   return s == "" ? "none" : s;
  }

void CheckAlerts()
  {
   datetime now = TimeGMT();
   int dow = DayOfWeek(now);
   if(dow == 0 || dow == 6)
      return;

   // briefs 30 minutes before the London open and the New York open
   datetime briefs[2];
   briefs[0] = LondonOpen(now) - 1800;
   briefs[1] = NyOpen(now) - 1800;
   string names[2] = {"London", "New York"};
   for(int b = 0; b < 2; b++)
      if(now >= briefs[b] && now < briefs[b] + 600 && !AlreadySent("brief" + (string)b))
         Notify(StringFormat("FX brief %s (%s opens %s): %s | Red news: %s", Local(now), names[b],
                             Local(briefs[b] + 1800), PicksText(), TodaysNewsText(now)));

   // red news coming up on a pick
   for(int i = 0; i < ArraySize(News); i++)
     {
      long until = (long)(News[i].gmt - now);
      if(until <= 0 || until > InpNewsAlertMin * 60)
         continue;
      string pairs = "";
      for(int k = 0; k < ArraySize(Picks); k++)
         if(Affects(P[Picks[k]].pair, News[i].cur))
            pairs += (pairs == "" ? "" : "/") + P[Picks[k]].pair;
      if(pairs != "" && !AlreadySent("news" + (string)(long)News[i].gmt + News[i].cur))
         Notify(StringFormat("Red news %s %s %s. No new %s entries %s-%s.", Local(News[i].gmt), News[i].cur,
                             News[i].name, pairs, Local(News[i].gmt - InpNewsWindow * 60),
                             Local(News[i].gmt + InpNewsWindow * 60)));
     }

   if(DayPlPct <= -InpDailyStopPct && !AlreadySent("dailystop"))
      Notify(StringFormat("DAILY STOP HIT (%.1f%%). Stop trading for today.", DayPlPct));
   if(DayTrades >= InpMaxTrades && !AlreadySent("maxtrades"))
      Notify(StringFormat("Max %d trades reached. No more entries today.", InpMaxTrades));
  }

//--- display ----------------------------------------------------------
void DrawLine(long chart, string name, double price, color clr, ENUM_LINE_STYLE style, string text)
  {
   if(price <= 0)
      return;
   string obj = PREFIX + name;
   if(ObjectFind(chart, obj) < 0)
      ObjectCreate(chart, obj, OBJ_HLINE, 0, 0, price);
   else
      ObjectMove(chart, obj, 0, 0, price);
   ObjectSetInteger(chart, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, obj, OBJPROP_STYLE, style);
   ObjectSetInteger(chart, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart, obj, OBJPROP_BACK, true);
   ObjectSetString(chart, obj, OBJPROP_TEXT, text);
  }

void DrawLevels()
  {
   for(long id = ChartFirst(); id >= 0; id = ChartNext(id))
      for(int i = 0; i < ArraySize(P); i++)
        {
         if(!P[i].valid || ChartSymbol(id) != P[i].symbol)
            continue;
         DrawLine(id, "AsianHigh", P[i].asianHi, clrOrange, STYLE_SOLID, "Asian high");
         DrawLine(id, "AsianLow", P[i].asianLo, clrOrange, STYLE_SOLID, "Asian low");
         DrawLine(id, "PrevDayHigh", P[i].pdh, clrDodgerBlue, STYLE_SOLID, "Prev-day high");
         DrawLine(id, "PrevDayLow", P[i].pdl, clrDodgerBlue, STYLE_SOLID, "Prev-day low");
         DrawLine(id, "PrevWeekHigh", P[i].pwh, clrMagenta, STYLE_DASH, "Prev-week high");
         DrawLine(id, "PrevWeekLow", P[i].pwl, clrMagenta, STYLE_DASH, "Prev-week low");
         DrawLine(id, "RoundUp", P[i].roundUp, clrGray, STYLE_DOT, "Round number");
         DrawLine(id, "RoundDown", P[i].roundDn, clrGray, STYLE_DOT, "Round number");
         ChartRedraw(id);
        }
  }

void DrawPanel()
  {
   datetime now = TimeGMT();
   datetime lo = LondonOpen(now), ny = NyOpen(now);
   string t = "FX DAILY SYSTEM    " + Local(now) + " Nairobi\n";
   t += StringFormat("Sessions (Nairobi): Asian %s-%s | London %s-%s | Overlap %s-%s | New York %s-%s\n",
                     Local(DayStart(now)), Local(lo), Local(lo), Local(lo + 9 * 3600), Local(ny),
                     Local(lo + 9 * 3600), Local(ny), Local(ny + 9 * 3600));

   string risk = StringFormat("Today: %+.2f%% | trades %d/%d", DayPlPct, DayTrades, InpMaxTrades);
   if(DayPlPct <= -InpDailyStopPct)
      risk += "   >>> DAILY STOP HIT - STOP TRADING <<<";
   else
      if(DayTrades >= InpMaxTrades)
         risk += "   >>> MAX TRADES - NO MORE ENTRIES <<<";
   t += risk + "\n";
   if(HasBias)
     {
      string b = "Your daily bias: ";
      for(int i = 0; i < 8; i++)
         b += StringFormat("%s %+.0f  ", Currencies[i], Bias[i]);
      t += b + StringFormat("(picks need %.0f+ in their direction)\n\n", InpMinBias);
     }
   else
      t += "No daily bias entered. Fill in the Bias Scorecard and paste it into the InpBias input.\n\n";

   t += "1. RED NEWS TODAY (MT5 calendar, Nairobi time)\n";
   if(!NewsOk)
      t += "   Calendar not loaded yet - open View > Toolbox > Calendar once, and check it manually.\n";
   int shown = 0;
   for(int i = 0; i < ArraySize(News); i++)
     {
      if(DayStart(News[i].gmt) != DayStart(now))
         continue;
      string state = "";
      if(News[i].gmt + InpNewsWindow * 60 < now)
         state = "  (passed)";
      else
         if(News[i].gmt - InpNewsWindow * 60 <= now)
            state = "  <<< NOW";
      t += StringFormat("   %s%s %s %s   no entries %s-%s%s\n", Local(News[i].gmt), News[i].tentative ? "~" : "",
                        News[i].cur, News[i].name, Local(News[i].gmt - InpNewsWindow * 60),
                        Local(News[i].gmt + InpNewsWindow * 60), state);
      shown++;
     }
   if(NewsOk && shown == 0)
      t += "   No red events today.\n";

   t += "\n2. CURRENCY STRENGTH (since today's open)\n   ";
   int idx[8];
   for(int i = 0; i < 8; i++)
      idx[i] = i;
   for(int i = 0; i < 8; i++)
      for(int j = i + 1; j < 8; j++)
         if(Strength[idx[j]] > Strength[idx[i]])
           {
            int x = idx[i];
            idx[i] = idx[j];
            idx[j] = x;
           }
   for(int r = 0; r < 8; r++)
      t += StringFormat("%s %+.2f%s", Currencies[idx[r]], Strength[idx[r]], r == 2 || r == 4 ? "  |  " : "   ");
   t += "\n   Best match: " + Currencies[idx[0]] + " vs " + Currencies[idx[7]] + "\n";

   t += StringFormat("\n3-5. TODAY'S PICKS (strong vs weak, ADR used < %.0f%%, no duplicate trades)\n", InpMaxAdrUsed);
   if(ArraySize(Picks) == 0)
      t += "   No pair passes. No trade is a valid trade.\n";
   else
      if(ArraySize(Picks) == 1)
         t += "   Only one pair qualifies. Don't force a second one.\n";
   for(int k = 0; k < ArraySize(Picks); k++)
     {
      PairInfo p = P[Picks[k]];
      t += StringFormat("   %d) %s %s @ %s   ADR %.0f pips, %.0f%% used, trend %s%s%s\n", k + 1, p.pair,
                        p.dir > 0 ? "BUY" : "SELL", Px(p, p.price), p.adrPips, p.usedPct, p.trend,
                        HasBias ? StringFormat(", bias %+.0f", p.bias) : "",
                        p.counter ? " (counter-trend: half size)" : "");
      t += StringFormat("      Asian H %s / L %s | Prev-day H %s / L %s | Prev-week H %s / L %s | Round %s / %s\n",
                        Px(p, p.asianHi), Px(p, p.asianLo), Px(p, p.pdh), Px(p, p.pdl), Px(p, p.pwh), Px(p, p.pwl),
                        Px(p, p.roundUp), Px(p, p.roundDn));
      t += StringFormat("      Stop guide %.0f pips -> %s lots at %.1f%% risk | 2R target %.0f pips\n", p.stopPips,
                        p.lots > 0 ? DoubleToString(p.lots, 2) : "below min lot, skip", InpRiskPct, p.stopPips * 2);
      int b = BlockingNews(p.pair, now), nx = NextNews(p.pair, now);
      if(b >= 0)
         t += StringFormat("      !! NEWS NOW: %s %s at %s. Wait until %s.\n", News[b].cur, News[b].name,
                           Local(News[b].gmt), Local(News[b].gmt + InpNewsWindow * 60));
      else
         if(nx >= 0)
            t += StringFormat("      Next red news: %s %s at %s. No entries from %s.\n", News[nx].cur, News[nx].name,
                              Local(News[nx].gmt), Local(News[nx].gmt - InpNewsWindow * 60));
     }

   t += "\nSKIPPED\n";
   int listed = 0;
   for(int i = 0; i < ArraySize(P) && listed < 6; i++)
     {
      if(!P[i].ok || !P[i].valid || P[i].status == "PASS")
         continue;
      t += StringFormat("   %-7s %s\n", P[i].pair, P[i].status);
      listed++;
     }
   string missing = "";
   for(int i = 0; i < ArraySize(P); i++)
      if(!P[i].ok)
         missing += " " + P[i].symbol;
   if(missing != "")
      t += "   Not found at your broker:" + missing + " (check the suffix input)\n";
   Comment(t);
  }

//--- journal ------------------------------------------------------------
void LogClosedDeal(ulong deal)
  {
   if(!HistoryDealSelect(deal))
      return;
   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;
   string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
   long posId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   double exitPx = HistoryDealGetDouble(deal, DEAL_PRICE);
   double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double pl = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_SWAP);
   datetime closeGmt = ToGmt((datetime)HistoryDealGetInteger(deal, DEAL_TIME));
   string comment = HistoryDealGetString(deal, DEAL_COMMENT);

   double entryPx = 0, sl = 0;
   datetime openGmt = 0;
   int side = 0;
   if(HistorySelectByPosition(posId))
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong t = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(t, DEAL_ENTRY) != DEAL_ENTRY_IN)
            continue;
         entryPx = HistoryDealGetDouble(t, DEAL_PRICE);
         sl = HistoryDealGetDouble(t, DEAL_SL);
         openGmt = ToGmt((datetime)HistoryDealGetInteger(t, DEAL_TIME));
         side = HistoryDealGetInteger(t, DEAL_TYPE) == DEAL_TYPE_BUY ? 1 : -1;
         break;
        }

   string pair = sym;
   bool picked = false;
   for(int i = 0; i < ArraySize(P); i++)
      if(P[i].symbol == sym)
        {
         pair = P[i].pair;
         for(int k = 0; k < ArraySize(Picks); k++)
            picked = picked || Picks[k] == i;
        }
   double pip = PipSize(pair, sym);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pips = (side != 0 && pip > 0) ? (exitPx - entryPx) * side / pip : 0;
   string r = "";
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE), tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   if(sl > 0 && entryPx > 0 && tickSize > 0)
     {
      double riskMoney = MathAbs(entryPx - sl) / tickSize * tickValue * vol;
      if(riskMoney > 0)
         r = DoubleToString(pl / riskMoney, 2);
     }

   int h = FileOpen("FX_Journal.csv", FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(h == INVALID_HANDLE)
     {
      Print("Journal: cannot open FX_Journal.csv, error ", GetLastError());
      return;
     }
   if(FileSize(h) == 0)
      FileWrite(h, "Date", "Open (Nairobi)", "Close (Nairobi)", "Session", "Pair", "Side", "Lots", "Entry", "Exit",
                "Stop", "Pips", "Profit", "R", "System pick", "Setup (A-E)", "Followed plan (Y/N)", "Notes");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString(closeGmt + InpLocalOffset * 3600, TIME_DATE),
             openGmt > 0 ? Local(openGmt) : "", Local(closeGmt), openGmt > 0 ? SessionOf(openGmt) : "",
             pair, side > 0 ? "BUY" : (side < 0 ? "SELL" : ""), DoubleToString(vol, 2),
             DoubleToString(entryPx, digits), DoubleToString(exitPx, digits), sl > 0 ? DoubleToString(sl, digits) : "none",
             DoubleToString(pips, 1), DoubleToString(pl, 2), r, picked ? "Y" : "N", "", "", comment);
   FileClose(h);
  }

//--- main -----------------------------------------------------------------
void Refresh()
  {
   // the calendar is rate limited: refresh every 15 minutes, retry after 5 if it failed
   if(TimeGMT() - LastNewsLoad >= (NewsOk ? 900 : 300))
      LoadNews();
   UpdateStrength();
   for(int i = 0; i < ArraySize(P); i++)
      P[i].valid = P[i].ok && Analyze(P[i]);
   ChoosePicks();
   UpdateDay();
   DrawPanel();
   if(InpDrawLevels)
      DrawLevels();
   CheckAlerts();
  }

int OnInit()
  {
   string parts[];
   int n = StringSplit(InpPairs, ',', parts);
   ArrayResize(P, 0);
   for(int i = 0; i < n; i++)
     {
      string token = parts[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      StringToUpper(token);
      if(token == "")
         continue;
      int k = ArraySize(P);
      ArrayResize(P, k + 1);
      int eq = StringFind(token, "=");
      if(eq > 0)
        {
         P[k].pair = StringSubstr(token, 0, eq);
         P[k].symbol = StringSubstr(parts[i], StringFind(parts[i], "=") + 1);
         StringTrimLeft(P[k].symbol);
         StringTrimRight(P[k].symbol);
        }
      else
        {
         P[k].pair = token;
         P[k].symbol = token + InpSuffix;
        }
      P[k].ok = SymbolSelect(P[k].symbol, true);
      P[k].valid = false;
      P[k].status = "";
     }
   ParseBias();
   EventSetTimer(60);
   Refresh();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
   for(long id = ChartFirst(); id >= 0; id = ChartNext(id))
      ObjectsDeleteAll(id, PREFIX);
  }

void OnTimer() { Refresh(); }

void OnTick() { }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!InpJournal || trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   LogClosedDeal(trans.deal);
  }
//+------------------------------------------------------------------+
