import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class WattsAndBeatsView extends WatchUi.DataField {
    hidden var mDebug as Boolean = false;
    hidden var mDemoCounter as Number = 0;
    hidden var mDemoDuration as Number = 360; // 6 minutes of demo data
    hidden var mPaused as Boolean = true;
    hidden var mDemoPaused as Boolean = false;

    hidden var mEf as EdgeField;
    hidden var mDarkBackground as Boolean = false;

    hidden var mTrendEngine as TrendEngine = new TrendEngine();
    hidden var mTestGenerator as TrendEngineGenerator = new TrendEngineGenerator();

    hidden var mCycloData as CycloData = new CycloData();
    hidden var mActivityStarted as Boolean = false;
    hidden var mBlockCompletedCounter as Number = 0;

    hidden var mFirstBlockEF as Float = -1.0f;
    hidden var mLatestBlockEF as Float = 0.0f;
    hidden var mAveragePower as Number = 0;
    hidden var mAverageCadence as Number = 0;

    function initialize() {
        DataField.initialize();
        mTrendEngine = getTrendEngine();
        mTrendEngine.setOnBlockCompleted(self, :onBlockCompleted);
    }

    function onBlockCompleted(data as Array<Float>) as Void {
        System.println(["Block completed: ", data]);
        mCycloData.BlockCompleted = Time.now().value();
        mCycloData.LockedEF = data[0];
        mCycloData.LockedVI = data[1];
        mCycloData.LockedTorque = data[2];

        if (mFirstBlockEF < 0) {
            mFirstBlockEF = data[0];
        }
        mLatestBlockEF = data[0];
        mBlockCompletedCounter = mBlockCompletedCounter + 1;
    }

    function onLayout(dc as Dc) as Void {
        // fix for leaving menu, draw complete screen, large field
        dc.clearClip();

        mEf = $.getEdgeField(dc);
    }

    function compute(info as Activity.Info) as Void {
        mPaused = false;
        if (info has :timerState) {
            mPaused =
                info.timerState == Activity.TIMER_STATE_PAUSED or
                info.timerState == Activity.TIMER_STATE_OFF;

            if (!mActivityStarted) {
                mActivityStarted = info.timerState != Activity.TIMER_STATE_OFF;
                if (mActivityStarted) {
                    System.println("Activity started - resetting trend engine");
                    mTrendEngine.reset();
                    mCycloData = new CycloData();
                }
            } else if (
                mActivityStarted and
                info.timerState == Activity.TIMER_STATE_OFF
            ) {
                System.println("Activity stopped");
                mActivityStarted = false;
            }
        }
        
        mAveragePower = $.getActivityValue(info, :averagePower, 0) as Number;
        mAverageCadence =
            $.getActivityValue(info, :averageCadence, 0) as Number;

        if (mTrendEngine.isDemo()) {
            
            // if (mDemoCounter <= 0) {
            //     // Reset the demo state when starting a new demo
            //     // TODO -> demo logic in generator class
            //     mDemoPaused = false;
            // }
            // Always start demo, when press activity started then paused to show the paused screen with data, 
            // TODO 
            // when press lap key // TODO add separate button for starting demo instead of overloading lap key
            // TODO and display LAP==PAUSE screen with the data from the demo, then on next press of lap key, start the demo with the fake data and trends,
            // then unpause to resume the demo and show the trends and warning messages


            //if (!mPaused) {
                processTrendEngine(info);
            //}
            // Override the averages with the generated demo data averages to show realistic values during the demo
            var averages = mTestGenerator.getAverages(mDemoCounter-1);
            mAverageCadence = averages[0].toNumber();
            mAveragePower = averages[1].toNumber();
        }
        else if (!mPaused  ) {
            processTrendEngine(info);
        }
        
    }

    // This event fires instantly when a lap is recorded, only when activity is started.
    function onTimerLap() {        
        System.println("Lap button pressed - toggling demo paused state");
        mDemoPaused = !mDemoPaused;
        // // 1. Play a subtle system alert tone so the rider knows the app registered the lap
        // if (Attention has :playTone) {
        //     Attention.playTone(Attention.TONE_LAP);
        // }

        // 2. FORCIBLY RE-LOCK YOUR BASELINES IMMEDIATELY
        // This lets the rider manually reset their target averages for a new interval/hill climb!
        // lockedEF = actualEF;
        // lockedVI = actualVI;
        // lockedTorque = actualTorque;

        // Reset your localized active second timer if you want lap-specific intervals
        // totalActiveSeconds = 0; 
    }

    hidden function processTrendEngine(info as Activity.Info) as Void {
        var cadence = $.getActivityValue(info, :currentCadence, 0) as Number;
        var power = $.getActivityValue(info, :currentPower, 0) as Number;
        var heartRate =
            $.getActivityValue(info, :currentHeartRate, 0) as Number;

        if (mTrendEngine.isDemo()) {
            var fakeData = mTestGenerator.getFakeData(mDemoCounter);
            cadence = fakeData[0];
            power = fakeData[1];
            heartRate = fakeData[2];
            mDemoCounter = mDemoCounter + 1;
            if (mDemoCounter > mDemoDuration) {
                mDemoCounter = 0;
                mDemoPaused = false;
                mTrendEngine.setDemo(false);
                mTrendEngine.setLockWindowSec($.gLockWindowSec);
                mTrendEngine.reset();
            }
        }
        var data = mTrendEngine.compute(cadence, power, heartRate);
        if (data == null) {
            return;
        }

        mCycloData.ActualEF = data[0] as Float;
        mCycloData.ActualVI = data[1] as Float;
        mCycloData.ActualTorque = data[2] as Float;
        mCycloData.TrendEF = data[3] as Number;
        mCycloData.TrendVI = data[4] as Number;
        mCycloData.TrendTorque = data[5] as Number;
        mCycloData.Locked = mTrendEngine.isLocked();
        mCycloData.Elapsed = mTrendEngine.getElapsedSeconds();
        mCycloData.BufferSize = mTrendEngine.getBufferSize();
    }
    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc as Dc) as Void {
        if ($.gExitedMenu) {
            // fix for leaving menu, draw complete screen, large field
            dc.clearClip();
            $.gExitedMenu = false;
        }

        var backgroundColor = getBackgroundColorOrWarningColor();
        dc.setColor(backgroundColor, backgroundColor);
        dc.clear();
        mDarkBackground = backgroundColor == Graphics.COLOR_BLACK;

        if (mTrendEngine.isDemo()) {
            $.drawDemoBackground(
                dc,
                dc.getWidth(),
                dc.getHeight(),
                mDemoDuration,
                mDemoCounter
            );
        }
        if (mDebug) {
            drawDebugInfo(dc);
            return;
        }

        if (
            mActivityStarted &&
            mPaused &&
            mFirstBlockEF > 0 &&
            mLatestBlockEF > 0
        ) {
            // Only show when valid data
            drawPausedState(dc);
            return;
        }

        // 4. Draw Warning Bar (Always present at the very bottom of the screen)
        drawBottomWarningBar(dc, dc.getWidth(), dc.getHeight());

        // if ($.gCurrentLayout == LAYOUT_ROWS) {
        if (mEf == EfWide || mEf == EfLarge) {
            drawTrendsInColumns(dc);
        } else {
            drawTrendsInRows(dc);
        }
    }

    function drawPausedState(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        var width = dc.getWidth();
        var height = dc.getHeight();

        var centerX = width / 2;
        var startY = (height * 0.15).toNumber();
        var spacing = (height * 0.22).toNumber();

        var textHeader = "RIDE SUMMARY (PAUSED)";
        var textEF = "DECOUPLING (EF):";
        var textVI = "PACING (VI):";
        var textTorque = "AVG TORQUE:";
        if (mEf == EfSmall) {
            textHeader = "SUMMARY";
            textEF = "EF";
            textVI = "VI";
            textTorque = "TQ";
        }


        var textPaused = "PAUSED";
        // Pause indicator in the center
        var font = Graphics.FONT_SYSTEM_LARGE;
        dc.setColor(color[:faded], Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            font,
            textPaused,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Header
        dc.setColor(color[:header], Graphics.COLOR_TRANSPARENT);
        var fontHeader = Graphics.FONT_SMALL;
        dc.drawText(
            centerX,
            startY,
            fontHeader,
            textHeader,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Subtle divider line
        dc.setColor(color[:faded], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(width * 0.1, startY + 25, width * 0.9, startY + 25);

        var fontText = Graphics.FONT_SMALL;
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);

        // STAT 1: Cardiorespiratory Decoupling
        var decouplingText = "---";
        if (mFirstBlockEF > 0 && mLatestBlockEF > 0) {
            // Formula: ((Latest - First) / First) * 100
            var pctDrop =
                ((mLatestBlockEF - mFirstBlockEF) / mFirstBlockEF) * 100.0;

            // Set color based on how severe the decoupling is
            if (pctDrop < -10.0) {
                dc.setColor(color[:warning], Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(color[:good], Graphics.COLOR_TRANSPARENT);
            }

            decouplingText = pctDrop.format("%.1f") + "%";
        }
        dc.drawText(
            width * 0.15,
            startY + spacing,
            fontText,
            textEF, // Cardio decoupling
            Graphics.TEXT_JUSTIFY_LEFT
        );
        dc.drawText(
            width * 0.85,
            startY + spacing,
            fontText,
            decouplingText,
            Graphics.TEXT_JUSTIFY_RIGHT
        );

        // STAT 2: Global Session VI (Pacing)
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        var globalVI = 1.0;
        if (mAveragePower > 0) {
            var globalNP = mTrendEngine.getNormalizedPower();
            globalVI = globalNP / mAveragePower;

        System.println(["Avg cadence:", mAverageCadence,
         "Avg power:", mAveragePower, "Global NP:", globalNP
        ]);

        }
        dc.drawText(
            width * 0.15,
            startY + spacing * 2,
            fontText,
            textVI, // Global pacing
            Graphics.TEXT_JUSTIFY_LEFT
        );
        dc.drawText(
            width * 0.85,
            startY + spacing * 2,
            fontText,
            globalVI.format("%.2f"),
            Graphics.TEXT_JUSTIFY_RIGHT
        ); // Example or computed value
        // TODO explain value and color code based on thresholds (e.g., >1.05 is bad pacing, <1.02 is good pacing)

        // STAT 3: Average Torque
        var avgTorqueText = "---";
        if (mAverageCadence > 0) {
            var sessionAvgTorque = mAveragePower / (mAverageCadence * 0.10472);
            avgTorqueText = sessionAvgTorque.format("%.1f") + " Nm";
        }
        dc.drawText(
            width * 0.15,
            startY + spacing * 3,
            fontText,
            textTorque,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        dc.drawText(
            width * 0.85,
            startY + spacing * 3,
            fontText,
            avgTorqueText,
            Graphics.TEXT_JUSTIFY_RIGHT
        );
    }

    function getBackgroundColorOrWarningColor() as ColorType {
        var darkMode = getBackgroundColor() == Graphics.COLOR_BLACK;

        // Use inverted background if any serious alerts, otherwise normal background
        if (mCycloData.TrendEF == -1 || mCycloData.TrendTorque == -1) {
            return darkMode ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        } else {
            return darkMode ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        }
    }
    function drawBottomWarningBar(
        dc as Dc,
        width as Number,
        height as Number
    ) as Void {
        var color = getThemeColor(mDarkBackground);

        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTorque = mCycloData.TrendTorque;
        var locked = mCycloData.Locked;

        // 0. DRAW THE BOTTOM WARNING/PROGRESS BAR - so its in the background.
        updateWarningMessage(trendEF, trendVI, trendTorque);

        var hasWarning = mWarningMessage.length() > 0;
        var infoMessage;
        var barHeight = (height * 0.16).toNumber();
        if (mEf == EfSmall) {
            // 2 lines on small field
            barHeight = barHeight * 2;
        }
        var barY = height - barHeight;
        if (hasWarning) {
            infoMessage = mWarningMessage;

            // Draw the background bounding block for the alert
            dc.setColor(mWarningColor, mWarningColor);
            dc.fillRectangle(0, barY, width, barHeight);

            // Use dark text on light alerts (Yellow) and white text on Red alerts
            if (mWarningColor == Graphics.COLOR_YELLOW) {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            }
        } else {
            dc.setColor(color[:header], Graphics.COLOR_TRANSPARENT);
            // Get progress until next block as a time
            infoMessage =
                (locked ? "NEXT" : "FIRST") + " LOCK IN: " +
                $.secondsToHourMinutesSeconds(
                    mTrendEngine.getSecondsToNextLock()
                );
        }
        
        var fontInfoMessage = Graphics.FONT_XTINY;
        dc.drawText(
            width / 2,
            barY + barHeight / 2, // / 4,
            fontInfoMessage,
            infoMessage,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
    function drawTrendsInRows(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);

        var width = dc.getWidth();
        var height = dc.getHeight();

        // Layout Columns
        var labelX = (width * 0.1).toNumber(); // Left side for labels
        var decimalX = (width * 0.52).toNumber(); // The anchor line for the decimal dot
        var trendX = (width * 0.8).toNumber(); // Right side for trend vector shapes

        // Set row heights based on screen size (saving bottom 20% for the warning bar)
        var rowHeight = ((height * 0.75) / 4).toNumber(); // 4 rows: header + 3 metrics
        var startY = (height * 0.08).toNumber();
        var shapeSize = (rowHeight * 0.45).toNumber();
        var headerOffset = (rowHeight * 0.4).toNumber(); // Header text is a bit higher than metric rows

        // 2. DRAW THE HEADER ROW
        dc.setColor(color[:header], Graphics.COLOR_TRANSPARENT);

        var fontHeader = Graphics.FONT_XTINY;
        dc.drawText(
            labelX,
            startY - headerOffset,
            fontHeader,
            "METRIC",
            Graphics.TEXT_JUSTIFY_LEFT
        );
        dc.drawText(
            decimalX,
            startY - headerOffset,
            fontHeader,
            "ACTUAL",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            trendX,
            startY - headerOffset,
            fontHeader,
            "TREND",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // 3. DRAW DATA ROWS (Example for EF)
        var fontData = Graphics.FONT_SYSTEM_MEDIUM;

        var actualEF = mCycloData.ActualEF;
        var actualVI = mCycloData.ActualVI;
        var actualTorque = mCycloData.ActualTorque;
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTorque = mCycloData.TrendTorque;

        // --- ROW 1: EF ---
        var yEF = startY + rowHeight;

        var efString = actualEF.format("%.2f");
        var efParts = $.splitStringAtDot(efString); // ["1", "58"]

        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            labelX,
            yEF,
            fontData,
            "EF",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            decimalX,
            yEF,
            fontData,
            efParts[0],
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            decimalX,
            yEF,
            fontData,
            "." + efParts[1],
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Assign specific trend color/icon for EF
        setTrendDisplayColor(
            dc,
            trendEF,
            color[:good],
            color[:bad],
            color[:neutral]
        );
        var drawUpTriangleForBad = false; // EF dropping is bad, so trend arrow points down for bad trend
        drawTrendArrow(
            dc,
            trendX,
            yEF,
            trendEF,
            shapeSize,
            drawUpTriangleForBad
        );

        // --- ROW 2: VI ---
        var yVI = startY + rowHeight * 2;
        var viString = actualVI.format("%.2f");
        var viParts = $.splitStringAtDot(viString);

        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            labelX,
            yVI,
            fontData,
            "VI",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            decimalX,
            yVI,
            fontData,
            viParts[0],
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            decimalX,
            yVI,
            fontData,
            "." + viParts[1],
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        setTrendDisplayColor(
            dc,
            trendVI,
            color[:good],
            color[:warning],
            color[:neutral]
        );
        drawUpTriangleForBad = true; // VI spiking is bad, so trend arrow points up for bad trend
        drawTrendArrow(
            dc,
            trendX,
            yVI,
            trendVI,
            shapeSize,
            drawUpTriangleForBad
        );

        // --- ROW 3: TQ ---
        var yTQ = startY + rowHeight * 3;
        var tqString = actualTorque.format("%.2f");
        var tqParts = $.splitStringAtDot(tqString);

        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            labelX,
            yTQ,
            fontData,
            "TQ",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            decimalX,
            yTQ,
            fontData,
            tqParts[0],
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            decimalX,
            yTQ,
            fontData,
            "." + tqParts[1],
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        setTrendDisplayColor(
            dc,
            trendTorque,
            color[:good],
            color[:bad],
            color[:neutral]
        );
        drawUpTriangleForBad = true; // Torque spiking is bad, so trend arrow points up for bad trend
        drawTrendArrow(
            dc,
            trendX,
            yTQ,
            trendTorque,
            shapeSize,
            drawUpTriangleForBad
        );
    }
    function drawTrendsInColumns(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);

        var width = dc.getWidth();
        var height = dc.getHeight();

        // Define our X positions for the 3 columns
        var col1X = (width * 0.18).toNumber();
        var col2X = (width * 0.5).toNumber();
        var col3X = (width * 0.82).toNumber();

        // Define our standard Y baselines for perfect horizontal alignment
        var headerY = (height * 0.12).toNumber();
        var actualsY = (height * 0.38).toNumber();
        var baselinesY = (height * 0.7).toNumber();

        // --- STEP 1: DRAW HEADERS (Labels + Unicode Symbols) ---
        var headerFont = Graphics.FONT_SMALL;
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            col1X,
            headerY,
            headerFont,
            "EF",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            col2X,
            headerY,
            headerFont,
            "VI",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            col3X,
            headerY,
            headerFont,
            "TQ",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // --- STEP 2: DRAW DOCK DIVIDER LINES ---
        dc.setColor(color[:faded], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Horizontal rule under headers
        dc.drawLine(width * 0.05, actualsY - 5, width * 0.95, actualsY - 5);
        // Vertical column separation grids
        dc.drawLine(
            (width * 0.34).toNumber(),
            headerY,
            (width * 0.34).toNumber(),
            height * 0.85
        );
        dc.drawLine(
            (width * 0.66).toNumber(),
            headerY,
            (width * 0.66).toNumber(),
            height * 0.85
        );

        // --- STEP 3: DRAW LIVE MOVING ACTUALS (Large, crisp text) ---
        var fontActuals = Graphics.FONT_LARGE;
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);

        var actualEF = mCycloData.ActualEF;
        var actualVI = mCycloData.ActualVI;
        var actualTorque = mCycloData.ActualTorque;
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTorque = mCycloData.TrendTorque;
        var lockedEF = mCycloData.LockedEF;
        var lockedVI = mCycloData.LockedVI;
        var lockedTorque = mCycloData.LockedTorque;

        // Use your decimal-aligned formatting strategy here
        dc.drawText(
            col1X,
            actualsY,
            fontActuals,
            actualEF.format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            col2X,
            actualsY,
            fontActuals,
            actualVI.format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            col3X,
            actualsY,
            fontActuals,
            actualTorque.format("%.1f"),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // --- STEP 4: DRAW LOCKED BASELINES & TREND ALERTS ---
        var lockedFont = Graphics.FONT_TINY;

        // Column 1: EF Baseline + Trend Arrow
        setTrendDisplayColor(
            dc,
            trendEF,
            color[:good],
            color[:bad],
            color[:neutral]
        );
        var drawUpTriangleForBad = false; // EF dropping is bad, so trend arrow points down for bad trend
        dc.drawText(
            col1X,
            baselinesY,
            lockedFont,
            lockedEF.format("%.2f") +
                " " +
                getTrendArrow(trendEF, drawUpTriangleForBad),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Column 2: VI Baseline + Trend Arrow
        setTrendDisplayColor(
            dc,
            trendVI,
            color[:good],
            color[:warning],
            color[:neutral]
        );
        drawUpTriangleForBad = true;
        dc.drawText(
            col2X,
            baselinesY,
            lockedFont,
            lockedVI.format("%.2f") +
                " " +
                getTrendArrow(trendVI, drawUpTriangleForBad),
            Graphics.TEXT_JUSTIFY_CENTER 
        );

        // Column 3: Torque Baseline + Trend Arrow
        setTrendDisplayColor(
            dc,
            trendTorque,
            color[:good],
            color[:bad],
            color[:neutral]
        );
        drawUpTriangleForBad = false; // Torque dropping is bad, so trend arrow points down for bad trend
        dc.drawText(
            col3X,
            baselinesY,
            lockedFont,
            lockedTorque.format("%.1f") +
                " " +
                getTrendArrow(trendTorque, drawUpTriangleForBad),
            Graphics.TEXT_JUSTIFY_CENTER 
        );
    }

    function getTrendArrow(
        trend as Number,
        drawUpTriangleForBad as Boolean
    ) as String {
        // trend -1 is bad, +1 is good, 0 is neutral.
        if (drawUpTriangleForBad and trend < 0) {
            // Invert the trend for display purposes if up triangle indicates bad trend
            trend = -1 * trend;
        }

        if (trend == 1) {
            return "▲";
        } // Improving or rising
        if (trend == -1) {
            return "▼";
        } // Degraging or dropping
        return "•"; // Stable baseline
    }

    function drawDebugInfo(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);

        var globalNP = mTrendEngine.getNormalizedPower();

        var blockCompletedString = "No";
        if (mCycloData.BlockCompleted > 0) {
            var time = new Time.Moment(mCycloData.BlockCompleted);
            blockCompletedString = $.getLongTimeString(time);
        }
        var text = "Actual EF: " + mCycloData.ActualEF.format("%.2f") + "\n";
        text += "Actual VI: " + mCycloData.ActualVI.format("%.2f") + "\n";
        text +=
            "Actual Torque: " +
            mCycloData.ActualTorque.format("%.1f") +
            "Nm" +
            "\n";

        text +=
            "Block " +
            mBlockCompletedCounter.format("%02d") +
            " Completed at: \n" +
            blockCompletedString +
            "\n";

        text += "Locked: " + (mCycloData.Locked ? "Yes" : "No") + "\n";
        text += "Locked EF: " + mCycloData.LockedEF.format("%.2f") + "\n";
        text += "Locked VI: " + mCycloData.LockedVI.format("%.2f") + "\n";
        text +=
            "Locked Torque: " +
            mCycloData.LockedTorque.format("%.1f") +
            "Nm" +
            "\n";

        text += "Trend EF: " + mCycloData.TrendEF.format("%d") + "\n";
        text += "Trend VI: " + mCycloData.TrendVI.format("%d") + "\n";
        text += "Trend Torque: " + mCycloData.TrendTorque.format("%d") + "\n";

        text +=
            "Elapsed: " +
            $.secondsToHourMinutesSeconds(mCycloData.Elapsed) +
            "\n";
        text += "Global NP: " + globalNP.format("%.2f") + "\n";

        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_SYSTEM_MEDIUM,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
    function getThemeColor(darkBackground) as Dictionary<String, ColorType> {
        return {
            :text => darkBackground
                ? Graphics.COLOR_WHITE
                : Graphics.COLOR_BLACK,
            :header => darkBackground
                ? Graphics.COLOR_LT_GRAY
                : Graphics.COLOR_LT_GRAY,
            :faded => darkBackground
                ? Graphics.COLOR_DK_GRAY
                : Graphics.COLOR_LT_GRAY,
            :strong => darkBackground
                ? Graphics.COLOR_WHITE
                : Graphics.COLOR_DK_GRAY,
            :neutral => darkBackground
                ? Graphics.COLOR_WHITE
                : Graphics.COLOR_BLACK,
            :good => darkBackground
                ? Graphics.COLOR_GREEN
                : Graphics.COLOR_GREEN,
            :warning => darkBackground
                ? Graphics.COLOR_YELLOW
                : Graphics.COLOR_ORANGE,
            :bad => darkBackground
                ? Graphics.COLOR_PINK
                : Graphics.COLOR_PURPLE,
        };
    }

    function setTrendDisplayColor(
        dc as Dc,
        trend as Number,
        colorGood as ColorType,
        colorBad as ColorType,
        colorNeutral as ColorType
    ) {
        if (trend > 0) {
            dc.setColor(colorGood, Graphics.COLOR_TRANSPARENT);
        } else if (trend < 0) {
            dc.setColor(colorBad, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(colorNeutral, Graphics.COLOR_TRANSPARENT);
        }
    }

    function drawTrendArrow(
        dc as Dc,
        x as Number,
        y as Number,
        trend as Number,
        size as Number,
        drawUpTriangleForBad as Boolean
    ) {
        // trend -1 is bad, +1 is good, 0 is neutral.
        if (drawUpTriangleForBad and trend < 0) {
            // Invert the trend for display purposes if up triangle indicates bad trend
            trend = -1 * trend;
        }

        if (trend > 0) {
            $.drawUpTriangle(dc, x, y, size);
        } else if (trend < 0) {
            $.drawDownTriangle(dc, x, y, size);
        } else {
            $.drawSteadyCircle(dc, x, y, size);
        }
    }

    // Class-level string variable
    var mWarningMessage = "";
    var mWarningColor = Graphics.COLOR_LT_GRAY;

    function updateWarningMessage(
        trendEF as Number,
        trendVI as Number,
        trendTorque as Number
    ) as Void {
        var sep = " ";
        if (mEf == EfSmall) {
            // Small screen - 2 lines of warning message
            sep = "\n";
        }
        // Priority 1: Serious Cardiorespiratory Fatigue (EF dropping)
        if (trendEF == -1) {
            mWarningMessage = "DECOUPLING DETECTED:" + sep + "HYDRATE & PACE";
            mWarningColor = Graphics.COLOR_RED;
        }
        // Priority 2: High Muscle Strain (Torque too high)
        else if (trendTorque == -1) {
            mWarningMessage = "LEGS MASHING:" + sep + "SHIFT DOWN & SPIN";
            mWarningColor = Graphics.COLOR_RED; // Or COLOR_ORANGE if preferred
        }
        // Priority 3: Erratic pacing (VI spiking)
        else if (trendVI == -1) {
            mWarningMessage = "BURNING MATCHES:" + sep + "SMOOTH EFFORT";
            mWarningColor = Graphics.COLOR_YELLOW;
        }
        // Default State
        else {
            mWarningMessage = "";
            mWarningColor = Graphics.COLOR_LT_GRAY;
        }
    }
}

class CycloData {
    public var ActualEF as Float = 0.0f;
    public var ActualVI as Float = 0.0f;
    public var ActualTorque as Float = 0.0f;

    public var LockedEF as Float = 0.0f;
    public var LockedVI as Float = 0.0f;
    public var LockedTorque as Float = 0.0f;

    public var TrendEF as Number = 0;
    public var TrendVI as Number = 0;
    public var TrendTorque as Number = 0;

    public var Locked as Boolean = false;
    public var BlockCompleted as Number = 0;

    public var Elapsed as Number = 0;
    public var BufferSize as Number = 0;

    // public var AveragePower as Number = 0;
    // public var AverageCadence as Number = 0;

    function initialize() {}

    public function toString() as String {
        return (
            "EF: " +
            ActualEF.format("%.2f") +
            ", VI: " +
            ActualVI.format("%.2f") +
            ", Torque: " +
            ActualTorque.format("%.1f") +
            "Nm"
        );
    }
}
