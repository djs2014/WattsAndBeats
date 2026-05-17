# ConnectIQ Datafield displaying Cardio Efficiency, Pacing Smoothness and Torque.

Calc current EF, VI, Torque
With Fixed 30-Minute Blocks
Settings menu
    - show text
    - show graph (bars / avg per 30 min (x))
    - targets
    - rolling buffer 180 sec
    - history buffer 30 / 60 / 90 minutes

callback on block complete

version with graphics / table

Arrows or Color Codes

EF Indicator: If trendEF == -1, draw a Red Down Arrow $\downarrow$ next to the EF value. This warns the rider they are "aerobically decoupling" (heart rate is skyrocketing relative to power output). They need to drink water or back off the pace.

VI Indicator: If trendVI == -1, draw a Yellow Warning Mark or make the background yellow. This indicates they are surging too hard on hills compared to their first 30 minutes.

Torque Indicator: If trendTorque == -1, show an Up Arrow $\uparrow$. This lets the rider know their leg force is significantly higher than their baseline, warning them that they are entering a muscular fatigue zone and should spin a lighter gear.

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

How to use trendTorque = 1 in the UIOn the Garmin screen, this gives the rider incredibly useful feedback:
trendTorque = -1 (Red Up Arrow $\uparrow$): "Warning: Your leg force is getting too heavy. Shift down and spin faster to save your muscles."trendTorque = 0 (Neutral Dot or Dash ─): "You are maintaining the same pedaling style as your baseline.
"trendTorque = 1 (Green Down Arrow $\downarrow$): "Great job: You've dropped your torque load. You are relying on your cardio system rather than killing your legs."

trendVI = 1
trendVI = 0
trendVI = -1 draw a Yellow Warning Mark or make the background yellow. This indicates they are surging too hard on hills compared to their first 30 minutes.


// Setting EF Display Color
switch (trendEF) {
    case 1:
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        efArrow = "↑";
        break;
    case -1:
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        efArrow = "↓";
        break;
    default:
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        efArrow = "─";
        break;
}