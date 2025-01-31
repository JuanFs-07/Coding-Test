#property copyright "Juan Fernandez"
#property version   "1.04"  // Indicator version
#property indicator_chart_window  // The indicator is displayed in the chart window
#property strict  // Enable strict mode to avoid compilation errors
// Input parameters
input color TextColor = clrAqua;          // Text color for overlays and watermark
input color PnL_PosColor = clrBlue;       // Color for positive PnL
input color PnL_NegColor = clrRed;        // Color for negative PnL
input int Refresh_MilliSeconds = 500;     // Refresh interval in milliseconds
input color watermarkColor = clrBeige;    // Watermark color
input bool showAsk = true;                // Show the Ask price (yes/no)
input bool showText = true;               // Show text on the chart (yes/no)
// Global variables
double myPoint = 0;                      // Market point size
double lastPrice = 0.0;                  // Last bar price
double currentPrice = 0.0;               // Current price
datetime nextCandleTime;                 // Time of the next candle
string activeSymbol;                     // Active symbol
int activeTimeframe;                     // Active timeframe
double currentPnL = 0.0;                 // Current PnL
int totalPips = 0;                       // Total pips of the operation
double profit = 0;                       // Total profit
// Trendline
string trendlineName = "DynamicTrendline";
// Initialization function
int OnInit()
{
    EventSetMillisecondTimer(Refresh_MilliSeconds);  // Set the timer with the specified interval
    myPoint = Point;  // Assign the "Point" value to the myPoint variable
    activeSymbol = Symbol();  // Get the current symbol
    activeTimeframe = Period();  // Get the current timeframe
    nextCandleTime = Time[0] + PeriodSeconds();  // Calculate the time for the next candle
    lastPrice = iClose(activeSymbol, activeTimeframe, 0);  // Set the initial price
    // Draw initial overlays
    DrawOverlay();
    DrawWatermark();
    CreateTrendline();
    return(INIT_SUCCEEDED);
}
// Deinitialization function
void OnDeinit(const int reason)
{
    EventKillTimer();  // Disable the timer
    DeleteObjects();   // Delete created graphic objects
}
// Main calculation function
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
    // Update the trendline and overlays on each tick
    UpdateTrendline();
    DrawOverlay();
    DrawWatermark();    
    // Update countdown timer and PnL display if there is an open position
    nextCandleTime = Time[0] + PeriodSeconds();
    if (OrdersTotal() > 0) {  // If there are open positions
        CalculatePnL();  // Calculate the PnL
    }   
    // Update trendline label position with PnL and countdown
    DrawTrendlineLabel();
    DrawPnLDisplay();  // Show PnL on each tick
    return rates_total;  // Return the number of bars calculated
}
// Timer function
void OnTimer()
{
    UpdateTrendline();  // Update the trendline
    DrawOverlay();      // Draw the text overlay
    DrawWatermark();    // Draw the watermark
    DrawTrendlineLabel();  // Draw the trendline label
    DrawPnLDisplay();   // Update PnL every time the timer is triggered
}
// Function to format the remaining countdown time
string FormatTimeRemaining(datetime timeLeft)
{
    int secondsRemaining = (int)(timeLeft - TimeCurrent());  // Calculate remaining seconds
    int minutes = secondsRemaining / 60;  // Get remaining minutes
    int seconds = secondsRemaining % 60;  // Get remaining seconds
    return StringFormat("Time Left: %dm %ds", minutes, seconds);  // Format the text
}
// Function to calculate and draw the PnL display
void CalculatePnL()
{
    profit = 0;  // Reset profit
    totalPips = 0;  // Reset total pips
    int orders = OrdersTotal();  // Get the number of open orders
    for (int i = 0; i < orders; i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {  // Select the order by position
            if (OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL)) {  // If the order is for the current symbol and is a buy or sell order
                double orderProfit = 0;  // Order profit
                int orderPips = 0;  // Order pips
                if (OrderType() == OP_BUY) {  // If the order is a buy
                    orderProfit = (Bid - OrderOpenPrice()) * OrderLots() * Point;  // Calculate buy profit
                    orderPips = (int)((Bid - OrderOpenPrice()) / Point);  // Calculate buy pips
                } else if (OrderType() == OP_SELL) {  // If the order is a sell
                    orderProfit = (OrderOpenPrice() - Ask) * OrderLots() * Point;  // Calculate sell profit
                    orderPips = (int)((OrderOpenPrice() - Ask) / Point);  // Calculate sell pips
                }
                profit += orderProfit;  // Add the order profit to the total
                totalPips += orderPips;  // Add the order pips to the total
            }
        }
    }
    currentPnL = profit;  // Update the current PnL
}
// Function to create a dynamic trendline
void CreateTrendline()
{
    ObjectCreate(trendlineName, OBJ_TREND, 0, Time[1], iClose(activeSymbol, activeTimeframe, 1), Time[0], iClose(activeSymbol, activeTimeframe, 0));  // Create the trendline
    ObjectSet(trendlineName, OBJPROP_COLOR, clrBlue);  // Set the trendline color (default blue)
    ObjectSet(trendlineName, OBJPROP_STYLE, STYLE_SOLID);  // Set the line style to solid
    ObjectSet(trendlineName, OBJPROP_WIDTH, 4);  // Set the line thickness
}
// Function to update the dynamic trendline
void UpdateTrendline()
{
    currentPrice = iClose(activeSymbol, activeTimeframe, 0);  // Get the current price
    // Adjust the trendline end point
    ObjectMove(trendlineName, 0, Time[1], lastPrice);  // Move the first point
    ObjectMove(trendlineName, 1, Time[0], currentPrice);  // Move the second point
    // Change the line color based on price movement
    color trendlineColor = (currentPrice >= lastPrice) ? PnL_PosColor : PnL_NegColor;  // Define the line color
    ObjectSet(trendlineName, OBJPROP_COLOR, trendlineColor);  // Apply the color to the line
    lastPrice = currentPrice;  // Update the last price
}
// Function to draw a label on the trendline (with PnL and countdown)
void DrawTrendlineLabel()
{
    string labelName = "TrendlineLabel";  // Label name
    
    // Format the PnL or "No Active Position" text
    string pnlText;
    if (OrdersTotal() == 0) {  // If there are no open positions
        pnlText = "No Active Position";  // Show no position message
    } else {
        pnlText = StringConcatenate(" :: P/L: ", DoubleToStr(currentPnL, 2), " ", AccountCurrency(), " (", totalPips, " pips)");  // Show PnL and pips
    } 
    // Format the remaining time
    string timeRemaining = FormatTimeRemaining(nextCandleTime); 
    
    // Combine PnL text and remaining time
    string fullText = StringFormat("%s | %s", pnlText, timeRemaining);
    
    // Adjust the text position on the trendline
    double xPosition = Time[0] + 70;  // Move the text to the right (adjustable)
    double yPosition = currentPrice;  // Place the text at the trend price level
    
    // Determine the text color based on the PnL value
    color textColor;
    if (currentPnL < 0) {
        textColor = clrRed;  // If PnL is negative, the text will be red
    } else {
        textColor = clrBlue; // If PnL is positive, the text will be blue
    } 
    // Create or update the trendline label
    if (ObjectFind(labelName) < 0) {  // If the label doesn't exist
        ObjectCreate(labelName, OBJ_TEXT, 0, xPosition, yPosition);  // Create the label
        ObjectSetText(labelName, fullText, 10, "Arial", textColor);  // Set the text and color
    } else {
        ObjectSetText(labelName, fullText, 10, "Arial", textColor);  // Update the label text
        ObjectMove(labelName, 0, xPosition, yPosition);  // Move the label
    }
    // Ensure the text stays behind other objects in the chart
    ObjectSet(labelName, OBJPROP_BACK, true);
    ObjectSet(labelName, OBJPROP_XDISTANCE, 10);  // Adjust the X distance
    ObjectSet(labelName, OBJPROP_YDISTANCE, 10);  // Adjust the Y distance
}

// Function to draw the PnL display on the screen (shows PnL or "No Active Position")
void DrawPnLDisplay()
{
    string objName = "PnLDisplay";  // Object name
    if (OrdersTotal() == 0) {  // If there are no open positions
        // Adjust position to the trendline level
        double trendlinePrice = iClose(activeSymbol, activeTimeframe, 0);  // Current bar price
        // Create the text object near the trendline (adjust X and Y positions)
        ObjectCreate(objName, OBJ_LABEL, 0, Time[0], trendlinePrice);  // Position at current time and price
        // Adjust relative positions on the chart
        ObjectSet(objName, OBJPROP_XDISTANCE, 10);  // X distance from the bar
        ObjectSet(objName, OBJPROP_YDISTANCE, 20);  // Y distance from the trendline price
    }    
}
// Function to draw the text overlay
void DrawOverlay()
{
    string objName = "OverlayText";  // Object name
    string overlayText = StringFormat("Yenny Rodriguez: Active Pair %s \nTimeframe: %s", activeSymbol, TimeframeToString(activeTimeframe));  // Overlay text
    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);  // Create the text object
    ObjectSetText(objName, overlayText, 10, "Arial", TextColor);  // Set the text and color
    ObjectSet(objName, OBJPROP_CORNER, 1);  // Top-left corner
    ObjectSet(objName, OBJPROP_XDISTANCE, 10);  // X distance
    ObjectSet(objName, OBJPROP_YDISTANCE, 10);  // Y distance
}
// Function to draw the watermark
void DrawWatermark()
{
    string objName = "Watermark";  // Object name
    string watermarkText = "@Yenny_Trader";  // Watermark text
    ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);  // Create the text object
    ObjectSetText(objName, watermarkText, 10, "Arial", watermarkColor);  // Set the text and color
    ObjectSet(objName, OBJPROP_CORNER, 3);  // Bottom-right corner
    ObjectSet(objName, OBJPROP_XDISTANCE, 10);  // X distance
    ObjectSet(objName, OBJPROP_YDISTANCE, 10);  // Y distance
}
// Function to delete all graphic objects
void DeleteObjects()
{
    ObjectDelete("OverlayText");  // Delete the overlay text
    ObjectDelete("Watermark");    // Delete the watermark
    ObjectDelete(trendlineName);  // Delete the trendline
    ObjectDelete("TrendlineLabel");  // Delete the trendline label
    ObjectDelete("PnLDisplay");   // Delete the PnL display
}
// Function to convert the timeframe to string
string TimeframeToString(int timeframe)
{
    switch (timeframe) {
        case PERIOD_M1: return "M1";  // 1 minute
        case PERIOD_M5: return "M5";  // 5 minutes
        case PERIOD_M15: return "M15";  // 15 minutes
        case PERIOD_M30: return "M30";  // 30 minutes
        case PERIOD_H1: return "H1";  // 1 hour
        case PERIOD_H4: return "H4";  // 4 hours
        case PERIOD_D1: return "D1";  // 1 day
        case PERIOD_W1: return "W1";  // 1 week
        case PERIOD_MN1: return "MN1";  // 1 month
        default: return "Unknown";  // Unknown timeframe
    }
}
