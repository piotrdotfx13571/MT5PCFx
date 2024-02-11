#property strict

#include <Trade\Trade.mqh>

input int       lotSize = 0.1;    // Rozmiar pozycji
input int      MagicNumber=10001;
input string   StartTime = "05:00";
input string   EndTime = "13:30";
input double   tpRatio = 1;
input double   slRatio = 1;

// Definicje zmiennych globalnych
double haOpenBuffer[];
double haHighBuffer[];
double haLowBuffer[];
double haCloseBuffer[];

// Funkcja do generowania świec Heiken Ashi
void GenerateHeikenAshi(int start, int count)
{
    for (int i = start; i >= 0; i--)
    {
        haCloseBuffer[i] = (iOpen(_Symbol, PERIOD_CURRENT, i) + iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 4.0;

        if (i == 0)
        {
            haOpenBuffer[i] = (iOpen(_Symbol, PERIOD_CURRENT, i - 1) + iClose(_Symbol, PERIOD_CURRENT, i - 1)) / 2.0;
            haHighBuffer[i] = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpenBuffer[i], haCloseBuffer[i]));
            haLowBuffer[i] = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpenBuffer[i], haCloseBuffer[i]));
        }
        else
        {
            haOpenBuffer[i] = (haOpenBuffer[i - 1] + haCloseBuffer[i - 1]) / 2.0;
            haHighBuffer[i] = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpenBuffer[i], haCloseBuffer[i]));
            haLowBuffer[i] = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpenBuffer[i], haCloseBuffer[i]));
        }
    }
}

// Funkcja OnCalculate, która jest wywoływana podczas generowania nowych świec
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Sprawdź, czy potrzebujemy więcej danych
    int limit = rates_total - prev_calculated;
    if (limit > 0)
    {
        // Zainicjuj bufory dla świec Heiken Ashi
        ArraySetAsSeries(haOpenBuffer, true);
        ArraySetAsSeries(haHighBuffer, true);
        ArraySetAsSeries(haLowBuffer, true);
        ArraySetAsSeries(haCloseBuffer, true);

        // Skopiuj wcześniejsze dane do bufora
        ArraySetAsSeries(open, false);
        ArraySetAsSeries(high, false);
        ArraySetAsSeries(low, false);
        ArraySetAsSeries(close, false);

        ArrayCopySeries(open, 0, haOpenBuffer, prev_calculated, limit);
        ArrayCopySeries(high, 0, haHighBuffer, prev_calculated, limit);
        ArrayCopySeries(low, 0, haLowBuffer, prev_calculated, limit);
        ArrayCopySeries(close, 0, haCloseBuffer, prev_calculated, limit);

        // Wygeneruj świece Heiken Ashi
        GenerateHeikenAshi(limit - 1, limit);
    }

    return rates_total;
}


void OnTick() {
    CTrade trade;
    trade.SetExpertMagicNumber(MagicNumber);

    // Sprawdź, czy dostępne są co najmniej dwie świece
    if (iBars(_Symbol, PERIOD_CURRENT) < 2)
        return;

    // Wygeneruj świecę Heiken Ashi
    OnCalculate(iBars(_Symbol, PERIOD_CURRENT), 0, ArraySetAsSeries(_Close, true), _High, _Low, _Close, _TickVolume, _Volume, _Spread);

    // Pobierz wartości świec Heiken Ashi
    double haOpen = haOpenBuffer[0];
    double haClose = haCloseBuffer[0];
    double haLow = haLowBuffer[0];
    
    // Sprawdź warunek wejścia
    if (haLow > haOpen && haLow > haClose)
    {
        double entryPrice = haClose;
        double stopLoss = haLow - (haClose - haLow) * slRatio;
        double takeProfit = haClose + (haClose - haLow) * tpRatio;

        // Otwórz pozycję długą (kupno)
        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, entryPrice, stopLoss, takeProfit, "Bullish HA");
    }
}



//+------------------------------------------------------------------+
