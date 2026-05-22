import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.UserProfile;

class TrendEngine {
    var buffer180 as Number = 180; // 3 minutes
    var lockStep1800 as Number = 1800; // 30 minutes in seconds
    var hasFirstBaseline = false;

    var powerHistory as Array<Number> = new [buffer180];
    var hrHistory as Array<Number> = new [buffer180];
    var torqueHistory as Array<Float> = new [buffer180];
    var writeIndex as Number = 0;

    var isBufferFull as Boolean = false;

    // Total elapsed seconds of active riding
    var elapsedSeconds = 0;

    // Locked Snapshots (from the previous 30-minute block)
    var lockedEF as Float = 0.0f;
    var lockedVI as Float = 0.0f;
    var lockedTQ as Float = 0.0f;
    var lockNowOnLap as Boolean = false;

    // Trend Outputs (-1 = Decoupling/Failing, 0 = Steady, 1 = Improving)
    var trendEF as Number = 0;
    var trendVI as Number = 0;
    var trendTQ as Number = 0;

    // Peak and Max tracking variables
    var maxInstantTorque = 0.0;
    var peakRollingEF = 0.0;
    var maxRollingVI = 0.0; // Captures their most chaotic 3-minute surging window

    var useDemoData as Boolean = false;

    // TODO
    var maxTorque as Float = 0.0f;

    var previousPower as Float = 0.0f;
    var previousHR as Float = 0.0f;
    var previousTorque as Float = 0.0f;
    var previousEF as Float = 0.0f;

    function initialize() {
        AppBase.initialize();
        // OH. dummy call otherwise removed by the compiler.
        lockNow();
    }

    hidden var methodBlockCompleted as Method?;
    function setOnBlockCompleted(
        objInstance as Object?,
        callback as Symbol
    ) as Void {
        methodBlockCompleted = new Lang.Method(objInstance, callback) as Method;
    }
    function isDemo() as Boolean {
        return useDemoData;
    }
    function setDemo(isDemo as Boolean) as Void {
        useDemoData = isDemo;
        if (isDemo) {
            lockStep1800 = 180;
        }
    }
    function setLockWindowSec(lockWindowSec as Number) as Void {
        if (lockWindowSec < buffer180) {
            lockWindowSec = 2 *buffer180;
        }
        lockStep1800 = lockWindowSec;
    }
    function getLockWindowSec() as Number {
        return lockStep1800;
    }

    function getNormalizedPower() as Number {
        return globalNP;
    }

    function lockNow() as Boolean {
        if (!hasFirstBaseline) {
            System.println(
                "Cannot manually lock trend snapshot before first baseline is established"
            );
            return false;
        }

        System.println("Manually locking trend snapshot");
        lockNowOnLap = true;
        return true;
    }

    // Calculated per second, when activity paused, do not compute!
    function compute(
        cadence as Number,
        power as Number,
        heartRate as Number
    ) as Array<Float or Number>? {
        // Skip TQ calculation if power is 0
        // Skip EF calculation if power is 0
        // Keep VI calculation if power is 0 or HR is 0 Because average power must include 0 values

        // Update global NP tracking
        globalNP = calculateNormalizedPower(calculatePower30(power));
        // System.println(["Global NP", globalNP]);

        // 1. Calculate Instantaneous Torque (Nm)
        var currentTQ = 0.0;
        // 2 * Math.PI / 60 simplifies to a constant of roughly 0.10472
        var angularVelocity = cadence * 0.104719755;
        if (angularVelocity > 0) {
            currentTQ = power / angularVelocity;
            if (currentTQ > maxTorque) {
                maxTorque = currentTQ;
            }
            // System.println(["Power", power, "angularVelocity", angularVelocity, "Torque", currentTQ]);
        }

        // 2. Feed the 180-second Rolling Buffers (not ignoring the zeros)
        powerHistory[writeIndex] = power;
        hrHistory[writeIndex] = heartRate;
        torqueHistory[writeIndex] = currentTQ;

        writeIndex = (writeIndex + 1) % buffer180;
        if (writeIndex == 0) {
            isBufferFull = true;
        }
        elapsedSeconds++;

        // 3. Process actual rolling metrics (>Only if we have data)
        var limit = isBufferFull ? buffer180 : writeIndex;
        if (limit < 10) {
            // Wait for baseline data
            return null;
        }

        var sumPowerForVI = 0.0; // Includes zeros
        var sumPowerForEF = 0.0; // Excludes zeros
        var sumHRForEF = 0.0; // Excludes zeros
        var sumTorque = 0.0; // Excludes zeros

        var validEffortCount = 0; // Counts how many seconds we were actually pedaling

        // Unified loop to compute sums for all metrics
        for (var i = 0; i < limit; i++) {
            var p = powerHistory[i];

            // Global tracking for VI (Must include zeros)
            sumPowerForVI += p;

            // Conditional filtering for EF and Torque (Skip zeros)
            if (p > 0) {
                sumPowerForEF += p;
                sumHRForEF += hrHistory[i];
                sumTorque += torqueHistory[i];
                validEffortCount++;
            }
        }

        // Compute Actual 3-Min Averages
        // Pacing (VI) uses the full time window
        var actualPowerGlobal = sumPowerForVI / limit;
        // For a 3-minute window, a rough 4th-power scaling works well for pacing trends
        var actualVI = calculateRollingVI(actualPowerGlobal);

        var actualPower;
        var actualHR;
        var actualTQ;
        var actualEF;
        // Efficiency (EF) and Mechanics (Torque) only use working seconds
        if (validEffortCount >= 5) {
            // Ensure we have a tiny bit of pedaling data
            actualPower = sumPowerForEF / validEffortCount;
            actualHR = sumHRForEF / validEffortCount;
            actualTQ = sumTorque / validEffortCount;
            actualEF = actualHR > 0 ? actualPower / actualHR : 0.0;
            previousPower = actualPower;
            previousHR = actualHR;
            previousTorque = actualTQ;
            previousEF = actualEF;
        } else {
            // If they coasted for almost the entire last 3 minutes,
            // hold the previous valid calculation to prevent diving to 0
            actualPower = previousPower;
            actualHR = previousHR;
            actualTQ = previousTorque;
            actualEF = previousEF;
        }

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

        // Check lock now
        if (lockNowOnLap && hasFirstBaseline) {
            System.println("Manually locking trend snapshot on lap key press");
            lockNowOnLap = false; // Reset the flag after locking
            lockedEF = actualEF;
            lockedVI = actualVI;
            lockedTQ = actualTQ;
            elapsedSeconds = 0; // Reset the block timer to give them a full lock window after manual lock

            if (methodBlockCompleted != null) {
                methodBlockCompleted.invoke([lockedEF, lockedVI, lockedTQ]);
            }
        }

        // 4. THE 3-MINUTE (buffer full) AND 30-MINUTE LOCK TRIGGER
        if (!hasFirstBaseline && isBufferFull) {
            hasFirstBaseline = true;
            lockedEF = actualEF;
            lockedVI = actualVI;
            lockedTQ = actualTQ;
            if (methodBlockCompleted != null) {
                methodBlockCompleted.invoke([lockedEF, lockedVI, lockedTQ]);
            }
        } else if (elapsedSeconds > 0 && elapsedSeconds % lockStep1800 == 0) {
            System.println("LOCKING TREND SNAPSHOT");
            lockedEF = actualEF;
            lockedVI = actualVI;
            lockedTQ = actualTQ;

            if (methodBlockCompleted != null) {
                methodBlockCompleted.invoke([lockedEF, lockedVI, lockedTQ]);
            }
        }

        // 5. EVALUATE TRENDS (Compare Actual vs Locked)
        if (lockedEF > 0) {
            // EF Trend: Higher is better (Aerobic improvement or steady state)
            // A 5% drop is the standard scientific definition of Aerobic Decoupling, making it the perfect threshold for a red arrow.
            if (actualEF < lockedEF * 0.95) {
                trendEF = -1;
            } // Cardiorespiratory fatigue / Decoupling
            else if (actualEF > lockedEF * 1.05) {
                trendEF = 1;
            } // Improving efficiency
            else {
                trendEF = 0;
            } // Stable

            // VI Trend: Closer to 1.00 is better pacing
            // A 5% increase (e.g., moving from 1.02 to 1.07) indicates the rider is starting to throw micro-sprints into their pacing and needs a warning.
            if (actualVI > lockedVI * 1.05) {
                trendVI = -1;
            } // Pacing is getting chaotic / surging too much
            else if (actualVI < lockedVI * 0.95) {
                trendVI = 1;
            } // Pacing is smoothing out
            else {
                trendVI = 0; // Stable
            }

            // Torque Trend: Dropping torque at the same power means user is shifting to a spinning cadence
            // A 10% increase at the same power output means their cadence has dropped by roughly 8–10 RPM, meaning they are starting to bog down and drag their legs.
            if (actualTQ > lockedTQ * 1.1) {
                trendTQ = -1; // Torque jumped over 10% -> "Mashing"
            } // Mashing gears too hard (muscle fatigue)
            else if (actualTQ < lockedTQ * 0.9) {
                trendTQ = 1; // Torque dropped over 10% -> "Spinning efficiently"
            } else {
                trendTQ = 0; // Within the stable 10% dead-zone
            }

            // System.println(
            //     "Locked EF: " +
            //         lockedEF.format("%.2f") +
            //         ", Actual EF: " +
            //         actualEF.format("%.2f") +
            //         ", Trend EF: " +
            //         trendEF
            // );
            // System.println(
            //     "Locked VI: " +The 3-Minute (180s) Milestone
            //         lockedVI.format("%.2f") +
            //         ", Actual VI: " +
            //         actualVI.format("%.2f") +
            //         ", Trend VI: " +
            //         trendVI
            // );
            // System.println(
            //     "Locked Torque: " +
            //         lockedTQ.format("%.2f") +
            //         ", Actual Torque: " +
            //         actualTQ.format("%.2f") +
            //         ", Trend Torque: " +
            //         trendTQ
            // );
        }

        return [
            actualEF,
            actualVI,
            actualTQ,
            trendEF,
            trendVI,
            trendTQ,
        ];
    }

    function calculateRollingVI(avgPower as Float) as Float {
        // Prevent division by zero if the rider is completely stopped/coasting
        if (avgPower <= 0.0) {
            return 1.0;
        }

        var maxElements = isBufferFull ? 180 : writeIndex;

        // Safety check: We need at least 30 seconds of data to compute a valid NP baseline
        if (maxElements < 30) {
            return 1.0;
        }

        var sumFourthPower = 0.0;
        var stepCount = 0;

        // Step 1 & 2: Loop through the 180s buffer using 30-second discrete blocks
        // This replicates the 30-second physiological smoothing window
        for (var i = 0; i <= maxElements - 30; i += 5) {
            // Step by 5 seconds to get a clean rolling sample
            var chunkSum = 0.0;

            // Sum a 30-second block of power
            for (var j = 0; j < 30; j++) {
                chunkSum += powerHistory[i + j];
            }

            // Calculate the average for this 30-second block
            var avg30s = chunkSum / 30.0;

            // Raise that 30s average to the 4th power to heavily penalize surges
            var fourthPower = avg30s * avg30s * avg30s * avg30s;

            sumFourthPower += fourthPower;
            stepCount++;
        }

        if (stepCount == 0) {
            return 1.0;
        }

        // Step 3: Average the 4th power values
        var meanFourthPower = sumFourthPower / stepCount;

        // Step 4: Take the 4th root to convert back to Watts (Normalized Power)
        // Monkey C doesn't have a native Math.root4(), so we use Math.pow(x, 0.25)
        var rollingNP = Math.pow(meanFourthPower, 0.25);

        // Step 5: Calculate and return Variability Index
        var rollingVI = rollingNP / avgPower;

        // Cap the minimum at 1.00 (Math anomalies can occasionally cause 0.999)
        if (rollingVI < 1.0) {
            rollingVI = 1.0;
        }

        return rollingVI;
    }

    function getSecondsToNextLock() as Number {
        if (elapsedSeconds == 0) {
            return buffer180;
        }
        if (!hasFirstBaseline) {
            // If we haven't even established our first baseline, show a countdown to that instead (180s)
            var secondsIntoCurrentBlock = elapsedSeconds % buffer180;
            return buffer180 - secondsIntoCurrentBlock;
        }
        var secondsIntoCurrentBlock = elapsedSeconds % lockStep1800;
        return lockStep1800 - secondsIntoCurrentBlock;
    }

    function getTrends() as Array<Number> {
        return [trendEF, trendVI, trendTQ];
    }
    function getMaxValues() as Array<Float> {
        return [peakRollingEF, maxRollingVI, maxInstantTorque];
    }
    function getElapsedSeconds() as Number {
        return elapsedSeconds;
    }

    function isLocked() as Boolean {
        return lockedEF > 0;
    }

    function isBlockComplete() as Boolean {
        return elapsedSeconds > 0 && elapsedSeconds % lockStep1800 == 0;
    }

    function getBufferSize() as Number {
        return buffer180;
    }

    function reset() as Void {
        powerHistory = new [buffer180];
        hrHistory = new [buffer180];
        torqueHistory = new [buffer180];
        writeIndex = 0;
        isBufferFull = false;
        hasFirstBaseline = false;
        elapsedSeconds = 0;
        lockedEF = 0.0f;
        lockedVI = 0.0f;
        lockedTQ = 0.0f;
        trendEF = 0;
        trendVI = 0;
        trendTQ = 0;
        // Rest global NP tracking
        // mPowerTicks = 0;
        globalNP = 0;
    }

    // hidden var mPowerTicks as Number = 0;
    // hidden function addAverageNP(
    //     averagePower as Double,
    //     power as Number or Double
    // ) as Double {
    //     // [ avg' * (n-1) + x ] / n
    //     mPowerTicks = mPowerTicks + 1;
    //     averagePower =
    //         (averagePower * (mPowerTicks - 1) + power) / mPowerTicks.toDouble();

    //     // System.println(Lang.format("p $1$ ticks $2$ avg $3$", [power, mPowerTicks, averagePower]));
    //     return averagePower;
    // }

    // Normalized power
    hidden var mPowerDataPer30Sec as Array<Number> = [] as Array<Number>;
    hidden var mAvgPowerToFourthPer30Sec as Array<Decimal> =
        [] as Array<Decimal>;
    hidden var globalNP as Number = 0;

    hidden function calculateNormalizedPower(PowerPer30 as Number) as Number {
        if (mAvgPowerToFourthPer30Sec.size() >= 30) {
            mAvgPowerToFourthPer30Sec = mAvgPowerToFourthPer30Sec.slice(1, 30);
        }

        mAvgPowerToFourthPer30Sec.add(Math.pow(PowerPer30, 4));

        if (mAvgPowerToFourthPer30Sec.size() < 30) {
            return 0;
        }
        var avg = Math.mean(
            mAvgPowerToFourthPer30Sec as Array<Numeric>
        ).toDouble();
        return Math.pow(avg, 0.25).toNumber();
    }

    hidden function calculatePower30(power as Number) as Number {
        if (mPowerDataPer30Sec.size() >= 30) {
            mPowerDataPer30Sec = mPowerDataPer30Sec.slice(1, 30);
        }
        mPowerDataPer30Sec.add(power);

        if (mPowerDataPer30Sec.size() == 0) {
            return 0;
        }
        return Math.mean(mPowerDataPer30Sec as Array<Numeric>).toNumber();
    }
}
