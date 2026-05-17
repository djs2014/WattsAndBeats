import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.UserProfile;

class TrendEngine {
    var buffer180 as Number = 180; // 3 minutes
    var lockStep1800 as Number = 1800; // 30 minutes in seconds

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
    var lockedTorque as Float = 0.0f;

    // Trend Outputs (-1 = Decoupling/Failing, 0 = Steady, 1 = Improving)
    var trendEF as Number = 0;
    var trendVI as Number = 0;
    var trendTorque as Number = 0;

    var useDemoData as Boolean = false;
    // TODO
    var maxTorque as Float = 0.0f;
    var maxPower as Number = 0;
    var maxCadence as Number = 0;
    var maxHeartRate as Number = 0;

    function initialize() {
        AppBase.initialize();
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
            buffer180 = 180;
            lockStep1800 = 180;
        }
        reset();
    }
    function setDefaults() as Void {
        buffer180 = 180;
        lockStep1800 = 1800;
        reset();
    }

    // Default buffer 3 minutes (180 seconds) and lock step of 30 minutes (1800 seconds)
    function setBufferAndLockStepSize(
        bufferSize as Number,
        lockStepSize as Number
    ) as Void {
        buffer180 = bufferSize;
        lockStep1800 = lockStepSize;
        reset();
    }

    // Calculated per second
    function compute(
        cadence as Number,
        power as Number,
        heartRate as Number
    ) as Array<Float or Number>? {
        // System.println(
        //     "Received Data - Power: " + power + "W, Cadence: " + cadence + "RPM, Heart Rate: " + heartRate + "bpm"
        // );

        // 1. Calculate Instantaneous Torque (Nm)
        var currentTorque = 0.0;
        // 2 * Math.PI / 60 simplifies to a constant of roughly 0.10472
        var angularVelocity = cadence * 0.104719755;
        if (angularVelocity > 0) {
            currentTorque = power / angularVelocity;
            if (currentTorque > maxTorque) {
                maxTorque = currentTorque;
            }
        }

        // 2. Feed the 180-second Rolling Buffers
        powerHistory[writeIndex] = power;
        hrHistory[writeIndex] = heartRate;
        torqueHistory[writeIndex] = currentTorque;

        writeIndex = (writeIndex + 1) % buffer180;
        if (writeIndex == 0) {
            isBufferFull = true;
        }
        elapsedSeconds++;

        // 3. Process actual rolling metrics (>Only if we have data)
        var limit = isBufferFull ? buffer180 : writeIndex;
        if (limit < 10) {
            return null;
        } // Wait for baseline data

        var sumPower = 0.0;
        var sumHR = 0.0;
        var sumTorque = 0.0;

        // Mathematical variables for rolling VI
        // var sumOfFourths = 0.0;

        for (var i = 0; i < limit; i++) {
            sumPower += powerHistory[i];
            sumHR += hrHistory[i];
            sumTorque += torqueHistory[i];
        }

        // Compute Actual 3-Min Averages
        var actualPower = sumPower / limit;
        var actualHR = sumHR / limit;
        var actualTorque = sumTorque / limit;
        var actualEF = actualHR > 0 ? actualPower / actualHR : 0.0;

        // Approximate rolling VI over the 3-minute window
        // For a 3-minute window, a rough 4th-power scaling works well for pacing trends
        var actualVI = 1.0;
        var actualNP = 0;
        if (actualPower > 0) {
            actualNP = calculateNormalizedPower(calculatePower30(power));
            actualVI = actualNP / actualPower;
        }

        // 4. THE 30-MINUTE LOCK TRIGGER
        // 30 minutes = 1800 seconds
        if (elapsedSeconds > 0 && elapsedSeconds % lockStep1800 == 0) {
            System.println("LOCKING TREND SNAPSHOT");
            lockedEF = actualEF;
            lockedVI = actualVI;
            lockedTorque = actualTorque;
            if (methodBlockCompleted != null) {
                methodBlockCompleted.invoke([lockedEF, lockedVI, lockedTorque]);
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
            if (actualTorque > lockedTorque * 1.1) {
                trendTorque = -1; // Torque jumped over 10% -> "Mashing"
            } // Mashing gears too hard (muscle fatigue)
            else if (actualTorque < lockedTorque * 0.9) {
                trendTorque = 1; // Torque dropped over 10% -> "Spinning efficiently"
            } else {
                trendTorque = 0; // Within the stable 10% dead-zone
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
            //     "Locked VI: " +
            //         lockedVI.format("%.2f") +
            //         ", Actual VI: " +
            //         actualVI.format("%.2f") +
            //         ", Trend VI: " +
            //         trendVI
            // );
            // System.println(
            //     "Locked Torque: " +
            //         lockedTorque.format("%.2f") +
            //         ", Actual Torque: " +
            //         actualTorque.format("%.2f") +
            //         ", Trend Torque: " +
            //         trendTorque
            // );
        }

        return [actualEF, actualVI, actualTorque, trendEF, trendVI, trendTorque];
    }

    function getTrends() as Array<Number> {
        return [trendEF, trendVI, trendTorque];
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
        elapsedSeconds = 0;
        lockedEF = 0.0f;
        lockedVI = 0.0f;
        lockedTorque = 0.0f;
        trendEF = 0;
        trendVI = 0;
        trendTorque = 0;
    }

    // Normalized power
    hidden var mPowerDataPer30Sec as Array<Number> = [] as Array<Number>;
    hidden var mAvgPowerToFourthPer30Sec as Array<Decimal> =
        [] as Array<Decimal>;
    hidden var mNPSkipZero as Boolean = false;
    hidden var mPowerTicks as Number = 0;
    hidden var mCurrentNP as Double = 0.0d;

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
