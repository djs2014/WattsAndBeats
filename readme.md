# Watts and beats

A ConnectIQ Datafield displaying Cardio Efficiency, Pacing Smoothness and Torque.

Watts and beats turns raw power and heart rate data into actionable technique adjustments while you ride.

Rather than relying on post-ride software to see where your performance dropped, CycloMetrics establishes a baseline every 30 minutes and tracks your real-time trends against it.

## What it monitors:

    Efficiency Factor (EF): Tracks your aerobic fuel economy. A dropping trend warns you of aerobic decoupling, letting you know it’s time to hydrate or back off the pace.

    Variability Index (VI): Measures your pacing discipline over a 3-minute rolling window. It alerts you if you are surging too hard on hills or riding erratically.

    Torque (TQ): Keeps tabs on your mechanical efficiency. It subtly alerts you if you are grinding a gear too hard (causing premature muscle fatigue) or spinning fluidly.


*Note: Requires a paired Power Meter and Heart Rate Monitor.*



# The Alert Severity Matrix

Metric,Urgency Level,Danger Profile,Best Alert Color
EF (Efficiency),🔴 CRITICAL (Red),Aerobic decoupling/bonking. A sudden drop means cardiac drift is spiking relative to output.,Graphics.COLOR_RED
TQ (Torque),🟠 HIGH (Orange/Yellow),"Neuromuscular fatigue, chain snapping, or leg blowout from grinding too heavy a gear.",Graphics.COLOR_ORANGE(or COLOR_YELLOW)
VI (Variability),🟡 WARNING (Yellow),"Tactical pacing error. Surging too hard on hills, but fixable over the next few minutes.",Graphics.COLOR_YELLOW

Why This Hierarchy Works Physically1. EF (Efficiency Factor) = 🔴 Red AlertThe Threat: If a rider's EF collapses, they are blowing up aerobically. Their heart rate is skyrocketing while their power output is dropping.The Action: They need to back off immediately, eat carbs, and lower their core temperature. If they ignore a red EF block for more than 5 minutes, their entire ride is toast.2. TQ (Torque) = 🟠 Orange AlertThe Threat: High torque spikes mean the rider is smashing the pedals at a low cadence (grinding). This rapidly drains anaerobic glycogen stores and destroys the knee joints.The Action: They don't necessarily need to slow down, but they need to shift gears immediately to spin a higher cadence. Orange signals a mechanical/neuromuscular adjustment.3. VI (Variability Index) = 🟡 Yellow AlertThe Threat: A high VI (e.g., $> 1.05$ on a steady endurance ride) means the rider is burning matches by surging up short rollers and coasting down the other side.The Action: This is a systemic pacing warning. It takes time for VI to creep up, and it takes time to smooth it back out. Yellow tells them to "smooth out the pedal strokes over the next couple of kilometers."


# Settings
Start activity will reset
