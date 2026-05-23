# Watts and beats

A ConnectIQ Datafield displaying Cardio Efficiency, Pacing Smoothness and Torque.

Watts and beats turns raw power and heart rate data into actionable technique adjustments while you ride.

Rather than relying on post-ride software to see where your performance dropped, CycloMetrics establishes a baseline every 30 minutes and tracks your real-time trends against it.

## What it monitors:

    Efficiency Factor (EF): Tracks your aerobic fuel economy. A dropping trend warns you of aerobic decoupling, letting you know it’s time to hydrate or back off the pace.

    Variability Index (VI): Measures your pacing discipline over a 3-minute rolling window. It alerts you if you are surging too hard on hills or riding erratically.

    Torque (TQ): Keeps tabs on your mechanical efficiency. It subtly alerts you if you are grinding a gear too hard (causing premature muscle fatigue) or spinning fluidly.


*Note: Requires a paired Power Meter and Heart Rate Monitor.*


## What to do

### The Efficiency Factor (EF) Alert

The Problem: Your EF ($EF = \frac{\text{Normalized Power}}{\text{Heart Rate}}$) is dropping. This means the rider's heart rate is climbing, but their power output is either staying flat or actively falling. The rider's aerobic system is decoupling, likely due to overheating, dehydration, or deep fatigue.

Rider Action Checklist:

    - Back Off the Pace: Drop power output by 10–15% for the next 5 to 10 minutes to bring the heart rate back under control before hitting a hard physiological ceiling.

    - Hydrate and Fuel: Take a long drink of fluids and consume simple carbohydrates. Dehydration causes blood volume to drop, forcing the heart to beat faster just to maintain the same power output.

    - Cool Down: Zip down the jersey, dump water on the neck, or drop your head slightly into the clean airflow to dump core body heat.

### The Variability Index (VI) Alert

The Problem: Your VI ($VI = \frac{\text{Normalized Power}}{\text{Average Power}}$) is climbing too high (e.g., ticking past 1.05 on a flat route or 1.10 on a rolling route). This indicates highly erratic, "punchy" riding. The rider is burning matches by surging over rollers, stomping out of corners, or fighting the wind.

Rider Action Checklist:

    - Smooth Out the Power: Cap maximum power on uphill rollers. Instead of charging up a hill, drop a gear, maintain steady target power, and accept a slight drop in speed.

    - Tuck Into Wheels / Paceline: If riding in a group, close the gap and stay tightly tucked in the draft to eliminate the micro-surges required to hold a position.

    - Commit to Steady-State: Think like a time-trialist. Treat the pedals like a dimmer switch rather than an on/off toggle.

The Torque (TQ) Alert

The Problem: High Torque combined with low cadence. The rider is "mashing" a massive gear, placing an intense mechanical load on their knee joints and heavily recruiting fast-twitch muscle fibers, which burn through glycogen reserves rapidly.

Rider Action Checklist:

    - Shift Down Immediately: Click down 1 or 2 gears on the cassette to instantly lower the mechanical resistance.

    - Spin to Win: Push the cadence up into the 85–95 RPM sweet spot. This shifts the metabolic stress away from the skeletal muscles and onto the highly resilient cardiovascular system.

    - Stand Up Strategically: If out of gears on a steep climb, stand up cleanly out of the saddle to leverage body weight to rotate the cranks, easing the acute strain on the quadriceps.


The Deadly Combinations (Multi-Metric Alerts) 💥

If your engine monitors combinations of these numbers, you can catch critical pacing errors before they ruin a long endurance ride:


------------------------------
|Combination | 
--------------

High VI + Dropping EF
The rider is riding erratically (surging) and their cardiovascular system is paying a massive penalty for it.
Fix
Total Reset: Lower overall target power immediately, shift to a smoother gear, and stop chasing wheels.

High TQ + High VI
The rider is constantly stomping on a heavy gear out of corners or forcing a massive gear up short hills.
Fix
Gear Management: Shift before the hill or corner starts. Focus on keeping a high, fluid cadence.

Dropping EF + High TQ
The rider's muscles are failing, so they are losing the ability to spin a fast cadence, forcing them to mash a heavy gear, which spikes heart rate further.
Fix
Survival Mode: Drop to the absolute easiest gear, find a steady rhythm, and focus entirely on nutrition and recovery.


## The Data Field Tactical Cheat Sheet

Metric Indicators

EF (Efficiency Factor): Your physiological fuel gauge.

    Green/High: You are burning clean fuel efficiently.

    Red/Dropping: Your engine is overheating or running out of water/carbs. Fix: Back off 10%, drink, and eat.

VI (Variability Index): Your pacing smooth-o-meter.
    Green/Close to 1.0: You are a smooth, steady machine.

    Red/Climbing (> 1.05): You are riding erratically, burning critical energy reserves. Fix: Cap your power on hills, stop surging.

TQ (Torque): Your joint and muscle strain monitor.
    Green/Low: Light, easy spinning on the cardiovascular system.

    Red/High: Mashing heavy gears, burning out your leg muscles. Fix: Shift down, spin at 85+ RPM.

The Multi-Metric System Failures

HIGH VI  +  DROPPING EF 
  [ Erratic Riding ]  [ Heart Rate Spiking ]
           ⬇
   CRITICAL RISK: Burning matches you can't afford.
   ACTION: Drop target power immediately and find a smooth wheel to follow.

HIGH TQ  +  HIGH VI 
  [ Heavy Mashing ]  [ Punchy Surges ]
           ⬇
   CRITICAL RISK: Rapidly destroying leg muscles out of corners or on rollers.
   ACTION: Anticipate the terrain! Shift to an easier gear BEFORE the slope hits.

The Golden Rule for Your App:

    High VI means you are fighting the terrain incorrectly.

    High TQ means you are fighting your gears incorrectly.

    Dropping EF means your body is losing the fight against fatigue.












# The Alert Severity Matrix

Metric,Urgency Level,Danger Profile,Best Alert Color
EF (Efficiency),🔴 CRITICAL (Red),Aerobic decoupling/bonking. A sudden drop means cardiac drift is spiking relative to output.,Graphics.COLOR_RED
TQ (Torque),🟠 HIGH (Orange/Yellow),"Neuromuscular fatigue, chain snapping, or leg blowout from grinding too heavy a gear.",Graphics.COLOR_ORANGE(or COLOR_YELLOW)
VI (Variability),🟡 WARNING (Yellow),"Tactical pacing error. Surging too hard on hills, but fixable over the next few minutes.",Graphics.COLOR_YELLOW

Why This Hierarchy Works Physically1. EF (Efficiency Factor) = 🔴 Red AlertThe Threat: If a rider's EF collapses, they are blowing up aerobically. Their heart rate is skyrocketing while their power output is dropping.The Action: They need to back off immediately, eat carbs, and lower their core temperature. If they ignore a red EF block for more than 5 minutes, their entire ride is toast.2. TQ (Torque) = 🟠 Orange AlertThe Threat: High torque spikes mean the rider is smashing the pedals at a low cadence (grinding). This rapidly drains anaerobic glycogen stores and destroys the knee joints.The Action: They don't necessarily need to slow down, but they need to shift gears immediately to spin a higher cadence. Orange signals a mechanical/neuromuscular adjustment.3. VI (Variability Index) = 🟡 Yellow AlertThe Threat: A high VI (e.g., $> 1.05$ on a steady endurance ride) means the rider is burning matches by surging up short rollers and coasting down the other side.The Action: This is a systemic pacing warning. It takes time for VI to creep up, and it takes time to smooth it back out. Yellow tells them to "smooth out the pedal strokes over the next couple of kilometers."


# Settings
Start activity will reset
