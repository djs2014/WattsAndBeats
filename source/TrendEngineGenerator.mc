import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

public class TrendEngineGenerator {
    function initialize() {
        System.println("Trend Engine Generator Initialized");
    }

    function getFakeData(elapsedSeconds as Number) as Array<Number> {
        var t = elapsedSeconds;
        var currentCadence = 0;
        var currentPower = 0;
        var currentHeartRate = 0;

        var info = t.format("%02d");
        // SCENARIO 0: Initialization Phase (0 - 15s)
        if (t <= 15) {
            System.println("Initialization Phase - No data - " + info);
            return [currentCadence, currentPower, currentHeartRate];
        }

        // SCENARIO 1: Steady Baseline (16s - 180s)
        // Target: 200W, 140bpm, 90rpm. (Baseline EF ~1.42, VI ~1.00, TQ ~21Nm)
        else if (t > 15 && t <= 180) {
            System.println("Steady Baseline Phase - " + info);
            currentCadence = 90;
            currentPower = 200;
            currentHeartRate = 140;
        }

        // SCENARIO 2: Test VI Warning (181s - 240s)
        // We wildly alternate power between 100W and 380W every few seconds
        // to spike the rolling Normalized Power, while keeping HR flat.
        else if (t > 180 && t <= 240) {
            System.println("VI Warning Phase - " + info);
            currentCadence = 90;
            currentPower = t % 10 < 5 ? 100 : 380;
            currentHeartRate = 142;
        }

        // SCENARIO 3: Test Torque Warning (241s - 300s)
        // Power stays close to baseline (210W), but cadence drops to a heavy grind (50 RPM).
        // This will cause torque to skyrocket from ~21Nm to ~40Nm.
        else if (t > 240 && t <= 300) {
            System.println("Torque Warning Phase - " + info);
            currentPower = 210;
            currentHeartRate = 145;
            currentCadence = 50;
        }

        // SCENARIO 4: Test EF Warning / Aerobic Decoupling (301s+)
        // Power collapses down to 130W, but heart rate climbs up to 165bpm.
        // EF drops drastically from 1.42 down to 0.78, triggering the critical alert.
        else if (t > 300) {
            System.println("EF Warning / Aerobic Decoupling Phase - " + info);
            currentPower = 130;
            currentHeartRate = 165;
            currentCadence = 85;
        }

        //        System.println("Generated Data: Cadence=" + data[0] + " RPM, Power=" + data[1] + " W, Heart Rate=" + data[2] + " bpm");
        return [currentCadence, currentPower, currentHeartRate];
    }
    function getCurrentPhase(elapsedSeconds as Number) as String {
        var t = elapsedSeconds;
        if (t <= 15) {
            return "Init";
        } else if (t > 15 && t <= 180) {
            return "Baseline";
        } else if (t > 180 && t <= 240) {
            return "VI Warning";
        } else if (t > 240 && t <= 300) {
            return "TQ Warning";
        } else {
            return "EF Warning";
        }
    }

    hidden var mNTicks as Number = 0;
    hidden var mAverageCadence as Double = 0.0d;
    hidden var mAveragePower as Double = 0.0d;
    hidden var mAverageHeartRate as Double = 0.0d;
    function getAverages(elapsedSeconds as Number) as Array<Double> {
        if (elapsedSeconds <= 1) {
            System.println("Resetting averages at start - " + elapsedSeconds.format("%02d"));
            // reset
            mNTicks = 0;
            mAverageCadence = 0.0d;
            mAveragePower = 0.0d;
            mAverageHeartRate = 0.0d;            
        }
        var data = getFakeData(elapsedSeconds);

        mNTicks = mNTicks + 1;
        mAverageCadence = addAverageValue(mAverageCadence, data[0], mNTicks);
        mAveragePower = addAverageValue(mAveragePower, data[1], mNTicks);
        mAverageHeartRate = addAverageValue(
            mAverageHeartRate,
            data[2],
            mNTicks
        );
        System.println(
            "Averages after " + mNTicks.format("%d") + " ticks: Cadence=" + mAverageCadence.format("%.2f") + " RPM, Power=" + mAveragePower.format("%.2f") + " W, Heart Rate=" + mAverageHeartRate.format("%.2f") + " bpm"
        );
        return [mAverageCadence, mAveragePower, mAverageHeartRate];
    }

    // Rolling average ( avg' * (n-1) + x ) / n
    hidden function addAverageValue(
        average as Double,
        value as Number,
        ticks as Number
    ) as Double {
        if (ticks <= 0) {
            return 0.0d;
        }
        // [ avg' * (n-1) + x ] / n
        return (average * (ticks - 1) + value) / ticks.toDouble();
    }
}
