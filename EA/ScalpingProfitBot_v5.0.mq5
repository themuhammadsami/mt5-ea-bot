//+------------------------------------------------------------------+
//|                          ScalpingProfitBot_v5.2.mq5              |
//+------------------------------------------------------------------+
#property copyright "Wolf"
#property version   "5.2"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

// ==== INPUT PARAMETERS (Tuned for XAUUSD M15 on $1000 balance) ====
input double RiskPercent         = 1.0;
input double RewardRiskRatio     = 2.5;
input int    EMA_Fast            = 8;
input int    EMA_Slow            = 21;
input int    RSI_Period          = 14;
input int    MACD_Fast           = 12;
input int    MACD_Slow           = 26;
input int    MACD_Signal         = 9;
input int    Stoch_K             = 5;
input int    Stoch_D             = 3;
input int    ATR_Period          = 14;
input double ATR_Multiplier      = 2.0;
input double BreakevenThreshold  = 0.5;
input double TrailStep           = 0.3;
input double MinBalance          = 1000;
input bool   EnableTimeFilter    = true;
input int    MagicNumber         = 50001;

// ==== TIME FILTER ====
bool IsTradingHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (!EnableTimeFilter || (dt.hour >= 6 && dt.hour <= 19));
}

// ==== INDICATOR GATHERING ====
bool getIndicators(double &ema_fast, double &ema_slow, double &macd_main, double &macd_signal, double &stoch_k, double &stoch_d, double &atr)
{
   ema_fast = iMA(_Symbol, _Period, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   ema_slow = iMA(_Symbol, _Period, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   int macdHandle = iMACD(_Symbol, _Period, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   double macd_buf[2], sig_buf[2];
   if (CopyBuffer(macdHandle, 0, 0, 2, macd_buf) <= 0 || CopyBuffer(macdHandle, 1, 0, 2, sig_buf) <= 0) return false;
   macd_main = macd_buf[0]; macd_signal = sig_buf[0];

   int stochHandle = iStochastic(_Symbol, _Period, Stoch_K, Stoch_D, 3, MODE_SMA, STO_LOWHIGH);
   double stoch_k_buf[1], stoch_d_buf[1];
   if (CopyBuffer(stochHandle, 0, 0, 1, stoch_k_buf) <= 0 || CopyBuffer(stochHandle, 1, 0, 1, stoch_d_buf) <= 0) return false;
   stoch_k = stoch_k_buf[0]; stoch_d = stoch_d_buf[0];

   int atrHandle = iATR(_Symbol, _Period, ATR_Period);
   double atr_buf[1];
   if (CopyBuffer(atrHandle, 0, 0, 1, atr_buf) <= 0) return false;
   atr = atr_buf[0];

   return true;
}

// ==== SIGNAL RULES ====
bool isBuySignal()
{
   double ema_f, ema_s, macd, macd_sig, stoch_k, stoch_d, atr;
   if (!getIndicators(ema_f, ema_s, macd, macd_sig, stoch_k, stoch_d, atr)) return false;
   return (ema_f > ema_s && macd > macd_sig && stoch_k > stoch_d && stoch_k < 80);
}

bool isSellSignal()
{
   double ema_f, ema_s, macd, macd_sig, stoch_k, stoch_d, atr;
   if (!getIndicators(ema_f, ema_s, macd, macd_sig, stoch_k, stoch_d, atr)) return false;
   return (ema_f < ema_s && macd < macd_sig && stoch_k < stoch_d && stoch_k > 20);
}

// ==== LOT SIZE BASED ON FIXED RISK ====
double calculateLotSize(double stopLossPips)
{
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lot = riskAmount / (stopLossPips / tickSize * tickValue);
   lot = MathFloor(lot / lotStep) * lotStep;

   if (lot < minLot) lot = minLot;
   if (lot > maxLot) lot = maxLot;
   return NormalizeDouble(lot, 2);
}

// ==== EXECUTE TRADE ====
void ExecuteTrade(int direction)
{
   double price = (direction == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (AccountInfoDouble(ACCOUNT_BALANCE) < MinBalance) return;

   double atr;
   int atrHandle = iATR(_Symbol, _Period, ATR_Period);
   double atr_buffer[1];
   if (CopyBuffer(atrHandle, 0, 0, 1, atr_buffer) <= 0) return;
   atr = atr_buffer[0];

   double sl_distance = atr * ATR_Multiplier;
   double tp_distance = sl_distance * RewardRiskRatio;

   double lotSize = calculateLotSize(sl_distance);

   double sl = (direction == ORDER_TYPE_BUY) ? price - sl_distance : price + sl_distance;
   double tp = (direction == ORDER_TYPE_BUY) ? price + tp_distance : price - tp_distance;

   if (direction == ORDER_TYPE_BUY)
      trade.Buy(lotSize, _Symbol, price, sl, tp, "Buy Entry");
   else
      trade.Sell(lotSize, _Symbol, price, sl, tp, "Sell Entry");
}

// ==== TRAILING STOP & BREAKEVEN ====
void ManageTrailingStops()
{
   if (!PositionSelect(_Symbol)) return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double current = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double trailTrigger = MathAbs(tp - entry) * BreakevenThreshold;
   double trailAmount = MathAbs(tp - entry) * TrailStep;

   if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if ((current - entry) > trailTrigger && (current - trailAmount) > sl)
         trade.PositionModify(_Symbol, NormalizeDouble(current - trailAmount, _Digits), tp);
   }
   else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      if ((entry - current) > trailTrigger && (current + trailAmount) < sl)
         trade.PositionModify(_Symbol, NormalizeDouble(current + trailAmount, _Digits), tp);
   }
}

// ==== MAIN TICK HANDLER ====
void OnTick()
{
   static datetime lastTrade = 0;
   if (!IsTradingHour() || TimeCurrent() - lastTrade < 300) return;

   if (!PositionSelect(_Symbol))
   {
      if (isBuySignal())
      {
         ExecuteTrade(ORDER_TYPE_BUY);
         lastTrade = TimeCurrent();
      }
      else if (isSellSignal())
      {
         ExecuteTrade(ORDER_TYPE_SELL);
         lastTrade = TimeCurrent();
      }
   }
   else
   {
      ManageTrailingStops();
   }
}
