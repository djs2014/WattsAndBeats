readme

beep or toast on warning
get nice png files for ef,vi,tq
demo -> calc average power / average cadence
-> sep class for global data or in trendengine?

set lockwindow
set different block window 10 - 60 minutes

x reset to defaults 30

layout: EF trend  actual value
EF  Metabolic economy, fuel efficiency, heart-to-watt connection. $\heartsuit \rightarrow \lightning$
VI Smoothness, pacing discipline, tracking surges vs. steady riding. ~ line or target/bullseye
TQ Rotational force, muscle grinding, pure crank pressure. paired with a Circular Vector Arrow ($\circlearrowright$) or a Wrench/Gear.
    arc 

-- layout 2

[ 📈 EF ]      [ 🎯 VI ]      [ ↻ TQ ]   <-- Clean Icons + Labels in Header
  ----------------------------------------
     1.48           1.02           18.5     <-- Moving Actuals
     1.55 •         1.01 •         16.2 •   <-- Baselines + Trend Dots



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

