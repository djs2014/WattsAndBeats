sync field_utils

alarm werkt?
xchange backgr on alert
xoption  white/black text red / yellow /orange alert

EF warning klopt het?
font groter bij pauze op groter veld?

xaantal sec eerste lock - default 180 sec
xon lap eerste keer set eerste lock
xon lap manual hide -> werkt niet


xcheck the use of critical/high/warning colors
debug on, show only on big screen extra!
todo show demo phase

settings: warning / show progressbar until warning reached.
-> max duration EF warning (default 5min is max)
-> TQ max duration 
-> VI -> smooth out in kilometers max is 1 km ..

setting: on lap key: lock new baseline (after x sec)
    If a rider cruises through a 20-minute valley flat and then suddenly hits the base of a massive alpine climb, they can press the Lap Key.

    Your app will immediately overwrite the old flat-land baseline variables with their current 3-minute rolling actuals as they begin the climb. Their trend indicators and arrows will instantly recalibrate to show how well they are managing their mechanical efficiency specifically up the mountain, ignoring the preceding recovery valley.

show progress bar tiny option on next lock


update readme
EF  Metabolic economy, fuel efficiency, heart-to-watt connection. $\heartsuit \rightarrow \lightning$
VI Smoothness, pacing discipline, tracking surges vs. steady riding. ~ line or target/bullseye
TQ Rotational force, muscle grinding, pure crank pressure. paired with a Circular Vector Arrow ($\circlearrowright$) or a Wrench/Gear.


-> MAX values on pause screen

TQ
Max Torque ($TQ_{max}$) — EssentialWhy it's great: This is the ultimate bragging-rights metric for a cyclist. It represents the absolute maximum raw muscular force they smashed into the pedals (e.g., during a massive sprint or a steep out-of-the-saddle kick).How to track it: Simply update a global variable whenever the instantaneous torque exceeding the current max.


EF
Max Efficiency Factor ($EF_{max}$) — Skip It (Use a Peak Buffer)
Do: Track the Peak 3-Minute Rolling EF. This represents the best, most sustained aerobic block of the entire ride.

VI:
Track Global Session VI (to show overall pacing discipline) and highlight Max Power instead.


[ RIDE SUMMARY (PAUSED) ]
  -------------------------------------------------------------
  METRIC    |   AVG    |   PEAK   |  INTERPRETATION
  -------------------------------------------------------------
  EF        |   1.48   |   1.22   |  🔴 Decoupling detected (-17.5%)
  VI        |   1.03   |   1.18   |  🟢 Excellent Global Pacing
  TQ        |  24.2 Nm |  68.1 Nm |  🟡 High Peak Muscle Strain



---
// 1. Capture the absolute max torque smash of the ride
if (currentTQ > maxInstantTorque) {
    maxInstantTorque = currentTQ;
}

// 2. Capture the best sustained 3-minute aerobic efficiency block
if (actualEF > peakRollingEF) {
    peakRollingEF = actualEF;
}

// 3. Capture their most erratic pacing window (highest rolling VI)
if (actualVI > maxRollingVI) {
    maxRollingVI = actualVI;
}
---

function drawColumnLayout(dc, width, height) {
    // Define our X positions for the 3 columns
    var col1X = (width * 0.18).toNumber();
    var col2X = (width * 0.50).toNumber();
    var col3X = (width * 0.82).toNumber();

    // Define our standard Y baselines for perfect horizontal alignment
    var headerY    = (height * 0.12).toNumber();
    var actualsY   = (height * 0.38).toNumber();
    var baselinesY = (height * 0.70).toNumber();

    // Cache fonts to keep the draw text lines cleaner
    var fTiny   = Graphics.FONT_TINY;
    var fSmall  = Graphics.FONT_SMALL;
    var fLarge  = Graphics.FONT_LARGE;
    var jCenter = Graphics.TEXT_JUSTIFY_CENTER;

    // --- STEP 1: DRAW HEADERS (Labels) ---
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.drawText(col1X, headerY, fSmall, "EF", jCenter);
    dc.drawText(col2X, headerY, fSmall, "VI", jCenter);
    dc.drawText(col3X, headerY, fSmall, "TQ", jCenter);

    // --- STEP 2: DRAW DOCK DIVIDER LINES ---
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(1);
    // Horizontal rule under headers
    dc.drawLine(width * 0.05, actualsY - 5, width * 0.95, actualsY - 5);
    // Vertical column separation grids
    dc.drawLine((width * 0.34).toNumber(), headerY, (width * 0.34).toNumber(), height * 0.85);
    dc.drawLine((width * 0.66).toNumber(), headerY, (width * 0.66).toNumber(), height * 0.85);

    // --- STEP 3: DRAW LIVE MOVING ACTUALS ---
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(col1X, actualsY, fLarge, actualEF.format("%.2f"), jCenter);
    dc.drawText(col2X, actualsY, fLarge, actualVI.format("%.2f"), jCenter);
    dc.drawText(col3X, actualsY, fLarge, actualTQ.format("%.1f"), jCenter);

    // --- STEP 4: DRAW LOCKED BASELINES & TREND ALERTS ---
    
    // Column 1: EF Baseline + Trend Arrow
    setTrendColor(dc, trendEF); 
    dc.drawText(col1X, baselinesY, fTiny, lockedEF.format("%.2f") + " " + getTrendArrow(trendEF), jCenter);

    // Column 2: VI Baseline + Trend Arrow
    setTrendColor(dc, trendVI);
    dc.drawText(col2X, baselinesY, fTiny, lockedVI.format("%.2f") + " " + getTrendArrow(trendVI), jCenter);

    // Column 3: Torque Baseline + Trend Arrow
    setTrendColor(dc, trendTQ);
    dc.drawText(col3X, baselinesY, fTiny, lockedTorque.format("%.1f") + " " + getTrendArrow(trendTQ), jCenter);
}

function drawPauseLayout(dc, width, height) {
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    var colLabel   = (width * 0.12).toNumber();
    var colAvg     = (width * 0.50).toNumber();
    var colPeak    = (width * 0.88).toNumber();
    
    var titleY     = (height * 0.10).toNumber();
    var startY     = (height * 0.35).toNumber();
    var rowSpacing = (height * 0.20).toNumber();

    var fXTiny  = Graphics.FONT_XTINY;
    var fSmall  = Graphics.FONT_SMALL;
    var jLeft   = Graphics.TEXT_JUSTIFY_LEFT;
    var jRight  = Graphics.TEXT_JUSTIFY_RIGHT;
    var jCenter = Graphics.TEXT_JUSTIFY_CENTER;

    // Title Banner
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    dc.drawText(width / 2, titleY, fSmall, "RIDE SUMMARY (PAUSED)", jCenter);

    // Sub-headers
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.drawText(colAvg, startY - 20, fXTiny, "AVG", jRight);
    dc.drawText(colPeak, startY - 20, fXTiny, "MAX/PK", jRight);

    // Divider
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.drawLine(width * 0.05, startY - 5, width * 0.95, startY - 5);

    // ROW 1: EF
    var y = startY;
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(colLabel, y, fSmall, "EF", jLeft);
    dc.drawText(colAvg, y, fSmall, actualEF.format("%.2f"), jRight); 
    dc.drawText(colPeak, y, fSmall, peakRollingEF.format("%.2f"), jRight);

    // ROW 2: VI
    y += rowSpacing;
    var sessionVI = "1.00";
    var activityInfo = Activity.getActivityInfo();
    if (activityInfo != null && activityInfo.averagePower != null && activityInfo.averagePower > 0) {
        sessionVI = (globalNP / activityInfo.averagePower).format("%.2f");
    }
    dc.drawText(colLabel, y, fSmall, "VI", jLeft);
    dc.drawText(colAvg, y, fSmall, sessionVI, jRight);
    dc.drawText(colPeak, y, fSmall, maxRollingVI.format("%.2f"), jRight);

    // ROW 3: Torque
    y += rowSpacing;
    dc.drawText(colLabel, y, fSmall, "TQ", jLeft);
    dc.drawText(colAvg, y, fSmall, actualTQ.format("%.1f") + " Nm", jRight);
    dc.drawText(colPeak, y, fSmall, maxInstantTorque.format("%.1f"), jRight);
}
---


Stats:
1. What Stats Matter Most When Paused?When a cyclist pulls over for a break or a traffic light, they don't want to look at a 3-minute rolling average. They want to check their overall macro trends for the entire ride so far:Aerobic Decoupling ($EF\text{ Drop}$): The ultimate endurance metric. Compare their very first 30-minute baseline block to their most recent completed 30-minute block. If it has dropped by $12\%$, their cardio system is heavily fatiguing.Global VI: Their pacing score for the whole ride.Average Torque: The total muscular work done per pedal stroke across the ride.

Tracking the First and Last Blocks in Code

To calculate the overall $EF$ drop, your compute logic needs to remember the very first baseline established at minute 3, and constantly update a variable with the most recent baseline.Add these tracking variables at the class level:

var firstBlockEF = 0.0;
var latestBlockEF = 0.0;
if (totalActiveSeconds == 180) {
    firstBlockEF = actualEF; // Lock in the "fresh" baseline forever
    latestBlockEF = actualEF;
} else if (totalActiveSeconds > 180 && totalActiveSeconds % 1800 == 0) {
    latestBlockEF = actualEF; // Update with the most recent block baseline
}


+-------------------------------------+
|            RIDE PAUSED              |
| ----------------------------------- |
| CARDIO DECOUPLING:    -7.4%         |
| GLOBAL PACING (VI):    1.04         |
| SESSION AVG TORQUE:   28.2 Nm       |
+-------------------------------------+

Color Psychology: Rendering a massive Red "-14.2%" Decoupling text at a rest stop tells the rider immediately that they are under-fueling or heavily fatigued, prompting them to eat a gel or take a longer break before spinning back up.


--------------
Arrows or Color Codes

EF Indicator: If trendEF == -1, draw a Red Down Arrow $\downarrow$ next to the EF value. This warns the rider they are "aerobically decoupling" (heart rate is skyrocketing relative to power output). They need to drink water or back off the pace.

VI Indicator: If trendVI == -1, draw a Yellow Warning Mark or make the background yellow. This indicates they are surging too hard on hills compared to their first 30 minutes.

Torque Indicator: If trendTQ == -1, show an Up Arrow $\uparrow$. This lets the rider know their leg force is significantly higher than their baseline, warning them that they are entering a muscular fatigue zone and should spin a lighter gear.

Handling the First 30 Minutes

For the first 30 minutes of the ride, lockedEF and the other historical values will be empty. In your rendering code (onUpdate), check if lockedEF == 0.0. If it is, display a neutral icon (like a flat bar ─) to let the rider know CycloMetrics is establishing its initial baseline block.


----------- UI trends

trendEF (Cardio Efficiency)

Since higher EF is better (more watts per heartbeat) and lower EF is bad (aerobic decoupling/fatigue), your UI indicators should reflect a gauge of "fuel economy."

Trend Value,Meaning,Recommended Icon,Recommended Text Color
1,Improving: Cardiovascular efficiency is increasing.,Up Arrow (↑) or +,Green
0,Stable: Baseline efficiency is holding steady.,Flat Bar (─) or Dot (•),White / Leaf Output
-1,Decoupling: Fatigue is setting in; HR is rising relative to power.,Down Arrow (↓) or !,Red
    -> Fix "start drinking fluids and drop the intensity."

trendVI (Pacing Smoothness)

The logic for $VI$ is inverted compared to $EF$: lower (closer to 1.00) is better, while higher (surging) is bad. Your UI should look like a "smoothness" or "chaos" radar.

Trend Value,Meaning,Recommended Icon,Recommended Text Color
1,Smoothing out: Effort is becoming steadier and more metered.,Checkmark (✓) or Down Arrow (↓),Green
0,Stable pacing: The rhythm matches the baseline block.,Flat Bar (─),White
-1,"Erratic / Surging: Spiking too many watts, burning matches.",Warning Triangle (△) or Up Arrow (↑),Yellow or Orange
-> Fix "start drinking fluids and drop the intensity."






TQ

How to use trendTQ = 1 in the UIOn the Garmin screen, this gives the rider incredibly useful feedback:
trendTQ = -1 (Red Up Arrow $\uparrow$): "Warning: Your leg force is getting too heavy. Shift down and spin faster to save your muscles."trendTQ = 0 (Neutral Dot or Dash ─): "You are maintaining the same pedaling style as your baseline.
"trendTQ = 1 (Green Down Arrow $\downarrow$): "Great job: You've dropped your torque load. You are relying on your cardio system rather than killing your legs."

trendVI = 1
trendVI = 0
trendVI = -1 draw a Yellow Warning Mark or make the background yellow. This indicates they are surging too hard on hills compared to their first 30 minutes.


good values ..

1. What is a "Good" Efficiency Factor (EF)?EF is a direct window into your aerobic fitness ($EF = \text{Normalized Power} \div \text{Heart Rate}$). It represents how many watts you produce per single heartbeat.Because raw power scales heavily with size, a 90 kg elite rider will have a much higher absolute EF number than a 50 kg elite rider, even if their fitness is identical. Here is what typical EF numbers look like during a steady Zone 2 (Endurance) ride:Below 1.20: Typical for absolute beginners, unconditioned riders, or someone suffering from extreme systemic fatigue. The heart is beating very fast to produce minimal wattage.1.30 – 1.50: A solid, healthy baseline for recreational club riders and amateur racers during standard endurance base training.1.50 – 1.80: Excellent aerobic fitness. This range is common for highly trained master's athletes and amateur racers with years of consistent endurance base-building.2.00 to 3.00+: Elite/Professional endurance engine. These riders can spin at 280W while keeping their heart rate at a relaxed 130 bpm.💡 The Rule of Thumb for your App:For EF, the absolute number doesn't matter as much as the trend. If a rider's personal baseline is $1.40$, a "good" ride is one where their actual EF stays above $1.33$ (less than a 5% drop, meaning zero aerobic decoupling).

2. What is a "Good" Torque Value (TQ)?Torque measures the actual physical twisting force applied to the pedals ($Nm$). Unlike power, which is force multiplied by speed, torque strictly tells you how hard your leg muscles are crushing the pedals.During standard, flat riding at a smooth, standard cadence (85–95 RPM), torque naturally sits in a modest "comfort zone":12 – 22 Nm: Standard, safe cruising torque. Your legs are relying on the cardiorespiratory system and momentum, saving your muscle fibers from tearing or accumulating heavy acid.25 – 35 Nm: Pushing hard. This occurs when riding into a headwind, climbing a mild false-flat, or pulling a heavy turn at the front of a group.When Torque Gets High (The "Danger Zone")When a rider hits a steep hill or drops their cadence down to a heavy gear grind (40–60 RPM):Torque will instantly skyrocket to 40 – 60+ Nm.For targeted "Big Gear/Torque Intervals," elite male athletes aim for roughly 1.5 Nm per kilogram of body weight (about 110 Nm for a 75 kg rider) for short 4-minute bursts.💡 The Rule of Thumb for your App:For standard endurance riding, lower torque at the same power is better because it protects the muscles from fatigue.If your app displays an actual torque value that is 10% higher than the locked 30-minute baseline, it warns the rider to change gears. It means they have dropped their cadence and are creating a "grinding" scenario that will prematurely burn out their legs.




When Torque Gets High (The "Danger Zone")

When a rider hits a steep hill or drops their cadence down to a heavy gear grind (40–60 RPM):

    Torque will instantly skyrocket to 40 – 60+ Nm.

    For targeted "Big Gear/Torque Intervals," elite male athletes aim for roughly 1.5 Nm per kilogram of body weight (about 110 Nm for a 75 kg rider) for short 4-minute bursts.


The Rule of Thumb for your App:

For standard endurance riding, lower torque at the same power is better because it protects the muscles from fatigue.

If your app displays an actual torque value that is 10% higher than the locked 30-minute baseline, it warns the rider to change gears. It means they have dropped their cadence and are creating a "grinding" scenario that will prematurely burn out their legs.




funny
if (alertState == ALERT_VI) {
    // Make it pulse using the native clock system time seconds!
    var seconds = System.getClockTime().sec;
    if (seconds % 2 == 0) {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle((col2X - 32).toNumber(), (actualsY - 22).toNumber(), 64, 44, 6);
    }
}