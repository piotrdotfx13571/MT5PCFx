#property strict

#include <Trade\Trade.mqh>

input int       lotSize = 0.1;    // Rozmiar pozycji
input int       MagicNumber = 10001;
input double    tpRatio = 1;
input double    slRatio = 1;

// Definicje zmiennych globalnych
double haOpenBuffer[];
double haHighBuffer[];
double haLowBuffer[];
double haCloseBuffer[];

// Deklaracje zmiennych OnCalculate
double ExtLBuffer[];
double ExtHBuffer[];
double ExtOBuffer[];
double ExtCBuffer[];

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
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const int &Spread[])
{
    int limit;
    if (prev_calculated == 0)
    {
        ExtLBuffer[0] = Low[0];
        ExtHBuffer[0] = High[0];
        ExtOBuffer[0] = Open[0];
        ExtCBuffer[0] = Close[0];
        limit = 1;
    }
    else
    {
        limit = prev_calculated - 1;
    }

    for (int i = limit; i < rates_total && !IsStopped(); i++)
    {
        double haOpen = (ExtOBuffer[i - 1] + ExtCBuffer[i - 1]) / 2;
        double haClose = (Open[i] + High[i] + Low[i] + Close[i]) / 4;
        double haHigh = MathMax(High[i], MathMax(haOpen, haClose));
        double haLow = MathMin(Low[i], MathMin(haOpen, haClose));

        ExtLBuffer[i] = haLow;
        ExtHBuffer[i] = haHigh;
        ExtOBuffer[i] = haOpen;
        ExtCBuffer[i] = haClose;
    }

    return (rates_total);
}

void OnTick()
{
    CTrade trade;
    trade.SetExpertMagicNumber(MagicNumber);

    if (iBars(_Symbol, PERIOD_CURRENT) < 2)
        return;

    OnCalculate(iBars(_Symbol, PERIOD_CURRENT), 0, ArraySetAsSeries(Time, true), Open, High, Low, Close, ArraySetAsSeries(TickVolume, true), Spread);

    double haOpen = haOpenBuffer[0];
    double haClose = haCloseBuffer[0];
    double haLow = haLowBuffer[0];

    if (haLow > haOpen && haLow > haClose)
    {
        double entryPrice = haClose;
        double stopLoss = haLow - (haClose - haLow) * slRatio;
        double takeProfit = haClose + (haClose - haLow) * tpRatio;

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, entryPrice, stopLoss, takeProfit, "Bullish HA");
    }
}
