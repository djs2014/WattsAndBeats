import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class WattsAndBeatsView extends WatchUi.DataField {
    hidden var mDemoCounter as Number = 0;
    hidden var mDemoDuration as Number = 360; // 6 minutes of demo data
    hidden var mPaused as Boolean = true;
    hidden var mDemoPaused as Boolean = false;

    hidden var mEf as EdgeField;
    hidden var mDarkBackground as Boolean = false;

    hidden var mTrendEngine as TrendEngine = new TrendEngine();
    hidden var mTestGenerator as TrendEngineGenerator =
        new TrendEngineGenerator();

    hidden var mCycloData as CycloData = new CycloData();
    hidden var mActivityStarted as Boolean = false;
    hidden var mBlockCompletedCounter as Number = 0;

    hidden var mFirstBlockEF as Float = -1.0f;
    hidden var mLatestBlockEF as Float = 0.0f;

    hidden var mElapsedSeconds as Number = 0;
    hidden var mElapsedDistanceMeter as Float = 0.0f;
    hidden var mAveragePower as Number = 0;
    hidden var mAverageCadence as Number = 0;
    hidden var mCurrentPower as Number = 0;
    hidden var mCurrentHeartRate as Number = 0;

    hidden var mPreviousValidGlobalNP as Number = 0;

    hidden var mHeaderFont as Graphics.FontType = Graphics.FONT_MEDIUM;

    hidden var mColorCritical as ColorType = Graphics.COLOR_RED;
    hidden var mColorHigh as ColorType = Graphics.COLOR_YELLOW;
    hidden var mColorWarning as ColorType = Graphics.COLOR_YELLOW;
    hidden var mColorNeutral as ColorType = Graphics.COLOR_LT_GRAY;
    function initialize() {
        DataField.initialize();
        mTrendEngine = getTrendEngine();
        mTrendEngine.setOnBlockCompleted(self, :onBlockCompleted);

        // 30 series no orange
        if (Graphics has :COLOR_ORANGE) {
            mColorHigh = Graphics.COLOR_ORANGE;
        }
    }

    function onBlockCompleted(data as Array<Float>) as Void {
        System.println(["Block completed: ", data]);
        mCycloData.BlockCompleted = Time.now().value();
        mCycloData.LockedEF = data[0];
        mCycloData.LockedVI = data[1];
        mCycloData.LockedTorque = data[2];

        // TODO -> use it here or remove?
        if (mFirstBlockEF < 0) {
            mFirstBlockEF = data[0];
        }
        mLatestBlockEF = data[0];
        mBlockCompletedCounter = mBlockCompletedCounter + 1;

        if ($.gBeepOnLock) {
            alertOnEvent(Attention.TONE_INTERVAL_ALERT);
        }
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
                    if (mTrendEngine.isDemo()) {
                        System.println("Engine in demo mode");
                    } else {
                        System.println(
                            "Activity started - resetting trend engine"
                        );
                        mTrendEngine.reset();
                        mCycloData = new CycloData();
                    }
                }
            } else if (
                mActivityStarted and
                info.timerState == Activity.TIMER_STATE_OFF
            ) {
                System.println("Activity stopped");
                mActivityStarted = false;
            }
        }

        mElapsedSeconds =
            ($.getActivityValue(info, :timerTime, 0) as Number) / 1000; // Convert to seconds
        mElapsedDistanceMeter =
            $.getActivityValue(info, :elapsedDistance, 0.0f) as Float;

        mCurrentPower = $.getActivityValue(info, :currentPower, 0) as Number;
        mCurrentHeartRate =
            $.getActivityValue(info, :currentHeartRate, 0) as Number;

        var averagePower = $.getActivityValue(info, :averagePower, 0) as Number;
        var averageCadence =
            $.getActivityValue(info, :averageCadence, 0) as Number;
        if (!mPaused) {
            // Pause screen will use the last valid averages to show a stable value
            // instead of fluctuating values when pausing/unpausing
            mAveragePower = averagePower;
            mAverageCadence = averageCadence;
        }

        if (mTrendEngine.isDemo()) {
            if (!mPaused) {
                processTrendEngine(info);
            }
            // Override the averages with the generated demo data averages to show realistic values during the demo
            var averages = mTestGenerator.getAverages(mDemoCounter - 1);
            mAverageCadence = averages[0].toNumber();
            mAveragePower = averages[1].toNumber();
        } else if (!mPaused) {
            processTrendEngine(info);
        }
        if (!mPaused) {
            evaluateAlertEscalations(info);
        }
    }

    // TODO
    function onTimerLap2(trigger as DataField.LapInfoType) as Lang.Boolean {
        System.println(["Lap triggered: ", trigger]);
        if (trigger == DataField.LAP_TRIGGER_MANUAL) {
            System.println("Lap button pressed");
            if ($.gLockOnLapKey) {
                var locked = mTrendEngine.lockNow();
                if (locked) {
                    // Handled, do no trigger onTimerLap();
                    return true;
                }
                // Handled, do no trigger onTimerLap() to try another lockNow() attempt;
                return $.gLockOnAutoLap;
            }
        }
        return false;
    }

    function onTimerLap() as Void {
        System.println("Lap event triggered");
        if ($.gInitialEFOnLap) {
            var locked = mTrendEngine.lockInitialEF();
            if (locked) {
                System.println("Initial locked on lap");
            }
        }
        if ($.gLockOnAutoLap) {
            var locked = mTrendEngine.lockNow();
            if (locked) {
                System.println("Data locked on auto lap");
            }
        }
    }

    hidden function alertOnEvent(
        options as
            Attention.Tone or
                {
                :toneProfile as Lang.Array<Attention.ToneProfile>,
                :repeatCount as Lang.Number,
            }
    ) as Void {
        // Example of playing a tone on a specific event (e.g., lock)
        if (Attention has :playTone && System.getDeviceSettings().tonesOn) {
            // TONE_LAP is nearly silent on the 1050 speaker hardware.
            // TONE_CANARY or TONE_LOUD_BEEP will actually cut through the wind!
            Attention.playTone(options);
        }
    }

    hidden function toastOnEvent(message as String) as Void {
        if (WatchUi has :showToast) {
            // TODO icon per kind of warning
            WatchUi.showToast(message, null);
        }
    }

    hidden function backlightOnAlert() as Void {
        if (Attention has :backlight) {
            try {
                Attention.backlight(true);
            } catch (ex) {
                System.println("Attention.backlight(true) failed");
                ex.printStackTrace();
            }
        }
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
                mTrendEngine.setLockWindowSec($.gLockIntervalSec);
                mTrendEngine.reset();
            }
        }
        var data = mTrendEngine.compute(cadence, power, heartRate);
        if (data == null) {
            return;
        }

        mCycloData.ActualEF = data[0] as Float;
        mCycloData.ActualVI = data[1] as Float;
        mCycloData.ActualTQ = data[2] as Float;
        mCycloData.TrendEF = data[3] as Number;
        mCycloData.TrendVI = data[4] as Number;
        mCycloData.TrendTQ = data[5] as Number;
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

        var backgroundColor;
        if ($.gBackgroundOnAlert) {
            backgroundColor = getBackgroundColorOrWarningColor();
        } else {
            backgroundColor = getBackgroundColor();
        }
        dc.setColor(backgroundColor, backgroundColor);
        dc.clear();
        mDarkBackground = backgroundColor == Graphics.COLOR_BLACK;

        if (mTrendEngine.isDemo()) {
            drawDemoBackground(
                dc,
                dc.getWidth(),
                dc.getHeight(),
                mDemoDuration,
                mDemoCounter
            );
        }
        if ($.gDebug && mEf == EfOne) {
            drawDebugInfo(dc);
            return;
        }

        if (mPaused && mActivityStarted && $.gShowPauseScreen) {
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
        if (!mPaused) {
            drawSafeZoneProgressBar(dc);
        }
    }

    function drawPausedState(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);
        var width = dc.getWidth();
        var height = dc.getHeight();

        // 1. Scalable Column X Anchors
        var colLabel = (width * 0.06).toNumber();
        var colAvg = (width * 0.32).toNumber();
        var colPeak = (width * 0.54).toNumber();
        var colDesc = (width * 0.64).toNumber(); // Left anchor for coaching string

        // 2. Scalable Vertical Rows
        var titleY = (height * 0.08).toNumber();
        var subHeaderY = (height * 0.22).toNumber();
        var startY = (height * 0.36).toNumber();
        var rowSpacing = (height * 0.18).toNumber();

        // Tweaks per field size
        var isSmallScreen = mEf == EfSmall;
        var showTitle = mEf == EfLarge || mEf == EfOne;
        var showAvgColumn = mEf != EfSmall;
        var shiftDescColumn = mEf == EfWide || mEf == EfLarge || mEf == EfOne;
        if (shiftDescColumn) {
            // Shift to left, more room for text on larger screens
            colDesc = (width * 0.6).toNumber();
        }

        var fXTiny = Graphics.FONT_XTINY;
        var fSmall = Graphics.FONT_SMALL;
        var jLeft = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var jRight =
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;

        // --- TITLE ---
        if (showTitle) {
            dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width / 2,
                titleY,
                fSmall,
                "RIDE SUMMARY (PAUSED)",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        // --- SUB-HEADERS ---
        dc.setColor(color[:header], Graphics.COLOR_TRANSPARENT);
        if (showAvgColumn) {
            dc.drawText(colAvg, subHeaderY, fXTiny, "AVG", jRight);
        }
        dc.drawText(colPeak, subHeaderY, fXTiny, "MAX", jRight);
        dc.drawText(colDesc, subHeaderY, fXTiny, "STATUS", jLeft);

        // Divider Rule
        dc.setColor(color[:faded], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(
            width * 0.04,
            subHeaderY + 12,
            width * 0.96,
            subHeaderY + 12
        );

        // During pause these values can be null
        var safeAvgPower = mAveragePower != null ? mAveragePower : 0.0;
        var safeAvgCadence = mAverageCadence != null ? mAverageCadence : 0.0;

        // Calculate dynamic session metrics
        var currentSessionVI = 1.0;
        if (safeAvgPower > 0) {
            var globalNP = mTrendEngine.getNormalizedPower();
            System.println("Global NP: " + globalNP.format("%.2f") + " W");
            currentSessionVI = (globalNP / safeAvgPower).toFloat();
        }

        var actualEF = mCycloData.ActualEF;
        var globalInitialEF = mTrendEngine.getGlobalInitialEF();
        var maxValues = mTrendEngine.getMaxValues();
        var maxRollingEF = 0.0f;
        var maxRollingVI = 0.0f;
        var maxInstantTorque = 0.0f;
        if (
            maxValues != null &&
            maxValues.size() >= 3 &&
            maxValues[0] != null &&
            maxValues[1] != null &&
            maxValues[2] != null
        ) {
            maxRollingEF = maxValues[0];
            maxRollingVI = maxValues[1];
            maxInstantTorque = maxValues[2];
        }

        // Evaluate statuses
        var efStatus = evaluateEFDecoupling(
            globalInitialEF,
            actualEF,
            isSmallScreen
        );
        var viStatus = evaluateVIPacing(currentSessionVI, isSmallScreen);

        var averageTorqueAccumulator = 0.0f;
        if (safeAvgCadence > 0) {
            averageTorqueAccumulator = (
                safeAvgPower /
                (safeAvgCadence * 0.10472)
            ).toFloat();
        }

        var tqStatus = evaluateTorqueStrain(
            averageTorqueAccumulator,
            maxInstantTorque,
            isSmallScreen
        );

        // ========================================================
        // ROW 1: EF
        // ========================================================
        var y = startY;
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLabel, y, fSmall, "EF", jLeft);
        if (showAvgColumn) {
            dc.drawText(
                colAvg,
                y,
                fSmall,
                globalInitialEF.format("%.2f"),
                jRight
            ); // Historical anchor baseline
        }
        dc.drawText(colPeak, y, fSmall, maxRollingEF.format("%.2f"), jRight); // Current performance point

        dc.setColor(efStatus[:color], Graphics.COLOR_TRANSPARENT);
        dc.drawText(colDesc, y, fXTiny, efStatus[:text], jLeft);

        // ========================================================
        // ROW 2: VI
        // ========================================================
        y += rowSpacing;
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLabel, y, fSmall, "VI", jLeft);
        if (showAvgColumn) {
            dc.drawText(
                colAvg,
                y,
                fSmall,
                currentSessionVI.format("%.2f"),
                jRight
            );
        }
        dc.drawText(colPeak, y, fSmall, maxRollingVI.format("%.2f"), jRight);

        dc.setColor(viStatus[:color], Graphics.COLOR_TRANSPARENT);
        dc.drawText(colDesc, y, fXTiny, viStatus[:text], jLeft);

        // ========================================================
        // ROW 3: TORQUE
        // ========================================================
        y += rowSpacing;
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        dc.drawText(colLabel, y, fSmall, "TQ", jLeft);
        if (showAvgColumn) {
            dc.drawText(
                colAvg,
                y,
                fSmall,
                averageTorqueAccumulator.format("%.0f"),
                jRight
            );
        }
        dc.drawText(
            colPeak,
            y,
            fSmall,
            maxInstantTorque.format("%.0f"),
            jRight
        );

        dc.setColor(tqStatus[:color], Graphics.COLOR_TRANSPARENT);
        dc.drawText(colDesc, y, fXTiny, tqStatus[:text], jLeft);
    }

    function getBackgroundColorOrWarningColor() as ColorType {
        var darkMode = getBackgroundColor() == Graphics.COLOR_BLACK;

        // Use inverted background if any serious alerts, otherwise normal background
        if (mCycloData.TrendEF == -1 || mCycloData.TrendTQ == -1) {
            return darkMode ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        } else {
            return darkMode ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        }
    }

    function getBottomWarningBarYAndHeight(height as Number) as Array<Number> {
        var barHeight = (height * 0.16).toNumber();
        if (mEf == EfSmall) {
            // 2 lines on small field
            barHeight = (barHeight * 2).toNumber();
        }
        var barY = height - barHeight;
        return [barY, barHeight];
    }
    function drawBottomWarningBar(
        dc as Dc,
        width as Number,
        height as Number
    ) as Void {
        var color = getThemeColor(mDarkBackground);

        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTQ = mCycloData.TrendTQ;
        var locked = mCycloData.Locked;

        // 0. DRAW THE BOTTOM WARNING/PROGRESS BAR - so its in the background.
        updateWarningMessage(trendEF, trendVI, trendTQ);

        var hasWarning = mWarningMessage.length() > 0;
        var infoMessage;

        var barYAndHeight = getBottomWarningBarYAndHeight(height);
        var barY = barYAndHeight[0];
        var barHeight = barYAndHeight[1];
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
                (locked ? "NEXT" : "FIRST") +
                " LOCK IN: " +
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
        var shapeSize = (rowHeight * 0.5).toNumber();
        var headerOffset = (rowHeight * 0.4).toNumber(); // Header text is a bit higher than metric rows

        // Highlight box when any of the metrics is in warning state
        var warningPillx = (width * 0.05).toNumber();
        var warningPillWidth = (width * 0.9).toNumber();
        var warningPillHeight = (rowHeight * 1.05).toNumber();
        var warningPillYoffset = (rowHeight * 0.7).toNumber();

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
        var actualTQ = mCycloData.ActualTQ;
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTQ = mCycloData.TrendTQ;

        var criticalTextColor = $.gTextWhiteOnRed
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;
        var highTextColor = $.gTextWhiteOnOrange
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;
        var warningTextColor = $.gTextWhiteOnYellow
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;

        // --- ROW 1: EF ---
        var yEF = startY + rowHeight;
        var efString = actualEF.format("%.2f");
        var efParts = $.splitStringAtDot(efString); // ["1", "58"]

        if (trendEF == -1) {
            // Draw warning highlight for EF row RED
            dc.setColor(mColorCritical, mColorCritical);
            dc.fillRectangle(
                warningPillx,
                yEF - warningPillYoffset,
                warningPillWidth,
                warningPillHeight
            );
            dc.setColor(criticalTextColor, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        }
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
            criticalTextColor,
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

        if (trendVI == -1) {
            // Draw warning highlight for VI row YELLOW
            dc.setColor(mColorWarning, mColorWarning);
            dc.fillRectangle(
                warningPillx,
                yVI - warningPillYoffset,
                warningPillWidth,
                warningPillHeight
            );
            dc.setColor(warningTextColor, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        }

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
            warningTextColor,
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
        var tqString = actualTQ.format("%.2f");
        var tqParts = $.splitStringAtDot(tqString);

        if (trendTQ == -1) {
            // Draw warning highlight for TQ row ORANGE
            dc.setColor(mColorHigh, mColorHigh);
            dc.fillRectangle(
                warningPillx,
                yTQ - warningPillYoffset,
                warningPillWidth,
                warningPillHeight
            );
            dc.setColor(highTextColor, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);
        }

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
            trendTQ,
            color[:good],
            highTextColor,
            color[:neutral]
        );
        drawUpTriangleForBad = true; // Torque spiking is bad, so trend arrow points up for bad trend
        drawTrendArrow(
            dc,
            trendX,
            yTQ,
            trendTQ,
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

        // Highlight box when any of the metrics is in warning state
        var barYAndHeight = getBottomWarningBarYAndHeight(height);
        var barY = barYAndHeight[0];
        var barHeight = barYAndHeight[1];

        var warningPillY = (height * 0.05).toNumber();
        var warningPillWidth = (width * 0.3).toNumber();
        var warningPillHeight =
            height - barHeight - (warningPillY * 2).toNumber();
        // var warningPillY = (height * 0.3).toNumber();

        var criticalTextColor = $.gTextWhiteOnRed
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;
        var highTextColor = $.gTextWhiteOnOrange
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;
        var warningTextColor = $.gTextWhiteOnYellow
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;

        // --- STEP 1: DRAW HEADERS (Labels + icons) ---
        var textEF = "EF";
        var textVI = "VI";
        var textTQ = "TQ";

        var actualEF = mCycloData.ActualEF;
        var actualVI = mCycloData.ActualVI;
        var actualTQ = mCycloData.ActualTQ;
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTQ = mCycloData.TrendTQ;
        var lockedEF = mCycloData.LockedEF;
        var lockedVI = mCycloData.LockedVI;
        var lockedTorque = mCycloData.LockedTorque;

        // Default
        var yCenter = headerY;
        var headerFont = mHeaderFont;
        var alignHeaderText = Graphics.TEXT_JUSTIFY_CENTER;

        var EFwarning = trendEF == -1;
        var VIwarning = trendVI == -1;
        var TQwarning = trendTQ == -1;

        if (EFwarning) {
            // Draw warning highlight for EF column RED
            dc.setColor(mColorCritical, mColorCritical);
            dc.fillRectangle(
                col1X - warningPillWidth / 2,
                warningPillY,
                warningPillWidth,
                warningPillHeight
            );
        }
        if (VIwarning) {
            // Draw warning highlight for VI column YELLOW
            dc.setColor(mColorWarning, mColorWarning);
            dc.fillRectangle(
                col2X - warningPillWidth / 2,
                warningPillY,
                warningPillWidth,
                warningPillHeight
            );
        }
        if (TQwarning) {
            // Draw warning highlight for TQ column RED
            dc.setColor(mColorHigh, mColorHigh);
            dc.fillRectangle(
                col3X - warningPillWidth / 2,
                warningPillY,
                warningPillWidth,
                warningPillHeight
            );
        }
        var fontHeight = dc.getFontHeight(headerFont);
        var iconY = yCenter + (fontHeight * 0.33).toNumber();
        var heartColor = getTrendDisplayColor(
            trendEF,
            color[:faded],
            criticalTextColor,
            color[:faded]
        );
        drawHeartIcon(dc, col1X - fontHeight, iconY, fontHeight, heartColor);

        var targetColor = getTrendDisplayColor(
            trendVI,
            color[:faded],
            warningTextColor,
            color[:faded]
        );
        var targetColorInner = color[:background];
        if (VIwarning) {
            // Is background warning pill
            targetColorInner = mColorWarning;
        }
        drawTargetIcon(
            dc,
            col2X - fontHeight,
            iconY,
            (fontHeight / 2).toNumber(),
            targetColor,
            targetColorInner
        );

        var torqueColor = getTrendDisplayColor(
            trendTQ,
            color[:faded],
            highTextColor,
            color[:faded]
        );
        var torqueOffsetY = (fontHeight * 0.4).toNumber();
        var torqueOffsetX = (fontHeight * 0.5).toNumber();
        drawScalablePedalFaded(
            dc,
            col3X - torqueOffsetX,
            iconY - torqueOffsetY,
            (fontHeight * 0.8).toNumber(),
            true,
            torqueColor
        );
        drawScalablePedalFaded(
            dc,
            col3X + torqueOffsetX,
            iconY + torqueOffsetY,
            (fontHeight * 0.8).toNumber(),
            false,
            torqueColor
        );

        // Header text
        var colorTextEF = EFwarning ? criticalTextColor : color[:text];
        var colorTextVI = VIwarning ? warningTextColor : color[:text];
        var colorTextTQ = TQwarning ? highTextColor : color[:text];

        dc.setColor(colorTextEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(col1X, yCenter, headerFont, textEF, alignHeaderText);
        dc.setColor(colorTextVI, Graphics.COLOR_TRANSPARENT);
        dc.drawText(col2X, yCenter, headerFont, textVI, alignHeaderText);
        dc.setColor(colorTextTQ, Graphics.COLOR_TRANSPARENT);

        dc.drawText(col3X, yCenter, headerFont, textTQ, alignHeaderText);

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

        dc.setColor(colorTextEF, Graphics.COLOR_TRANSPARENT);
        // Use your decimal-aligned formatting strategy here
        dc.drawText(
            col1X,
            actualsY,
            fontActuals,
            actualEF.format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.setColor(colorTextVI, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            col2X,
            actualsY,
            fontActuals,
            actualVI.format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.setColor(colorTextTQ, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            col3X,
            actualsY,
            fontActuals,
            actualTQ.format("%.1f"),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // --- STEP 4: DRAW LOCKED BASELINES & TREND ALERTS ---
        var lockedFont = Graphics.FONT_TINY;

        // Column 1: EF Baseline + Trend Arrow
        setTrendDisplayColor(
            dc,
            trendEF,
            color[:good],
            criticalTextColor,
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
            warningTextColor,
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
            trendTQ,
            color[:good],
            highTextColor,
            color[:neutral]
        );
        drawUpTriangleForBad = true;
        dc.drawText(
            col3X,
            baselinesY,
            lockedFont,
            lockedTorque.format("%.1f") +
                " " +
                getTrendArrow(trendTQ, drawUpTriangleForBad),
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

    // Reordered to match pause screen and maintain a consistent sequence across screens (EF, VI, TQ)
    function drawDebugInfo(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);

        var font = Graphics.FONT_SYSTEM_TINY;
        var fontHeight = dc.getFontHeight(font);

        // Start drawing near the top boundary of the large data field layout
        var xPos = dc.getWidth() / 2;
        var yPos = 10;
        var justify = Graphics.TEXT_JUSTIFY_CENTER;

        // --- 1. ACTUAL CURRENT VALUES (EF -> VI -> TQ) ---
        dc.drawText(
            xPos,
            yPos,
            font,
            "--- ACTUALS (EF | VI | TQ) ---",
            justify
        );
        yPos += fontHeight;
        dc.drawText(
            xPos,
            yPos,
            font,
            "EF: " +
                mCycloData.ActualEF.format("%.2f") +
                " | VI: " +
                mCycloData.ActualVI.format("%.2f") +
                " | TQ: " +
                mCycloData.ActualTQ.format("%.1f") +
                "Nm",
            justify
        );
        yPos += fontHeight + 4;

        // --- 2. LOCKED BASELINE VALUES (EF -> VI -> TQ) ---
        dc.drawText(
            xPos,
            yPos,
            font,
            "--- LOCKED BASELINES [Locked: " +
                (mCycloData.Locked ? "Yes" : "No") +
                "] ---",
            justify
        );
        yPos += fontHeight;
        dc.drawText(
            xPos,
            yPos,
            font,
            "EF: " +
                mCycloData.LockedEF.format("%.2f") +
                " | VI: " +
                mCycloData.LockedVI.format("%.2f") +
                " | TQ: " +
                mCycloData.LockedTorque.format("%.1f") +
                "Nm",
            justify
        );
        yPos += fontHeight + 4;

        // --- 3. TREND DIRECTIONAL INTEGER OUTPUTS (EF -> VI -> TQ) ---
        dc.drawText(
            xPos,
            yPos,
            font,
            "--- TREND CODES (EF | VI | TQ) ---",
            justify
        );
        yPos += fontHeight;
        dc.drawText(
            xPos,
            yPos,
            font,
            "EF: " +
                mCycloData.TrendEF.format("%d") +
                " | VI: " +
                mCycloData.TrendVI.format("%d") +
                " | TQ: " +
                mCycloData.TrendTQ.format("%d"),
            justify
        );
        yPos += fontHeight + 4;

        // --- 4. GLOBAL HISTORICAL AVERAGES & RUNNING SESSION STATS ---
        dc.drawText(xPos, yPos, font, "--- SESSION RUNNING STATS ---", justify);
        yPos += fontHeight;
        // Session EF
        var globalInitialEF = mTrendEngine.getGlobalInitialEF();
        var drift = 0.0;
        if (globalInitialEF > 0) {
            drift =
                ((mCycloData.ActualEF - globalInitialEF) / globalInitialEF) *
                100.0;
        }

        dc.drawText(
            xPos,
            yPos,
            font,
            "Init EF: " +
                globalInitialEF.format("%.2f") +
                " | Curr EF: " +
                mCycloData.ActualEF.format("%.2f") +
                " | Drift: " +
                drift.format("%.1f") +
                "%",
            justify
        );

        yPos += fontHeight;

        var globalNP = mTrendEngine.getNormalizedPower();

        // Latch logic: If the engine returns 0 (recalculating),
        // fall back to a backup variable so your screen doesn't show a sudden drop
        var latched = false;
        if (globalNP <= 0.0 && mCycloData.LockedEF > 0) {
            globalNP = mPreviousValidGlobalNP;
            latched = true;
        } else {
            mPreviousValidGlobalNP = globalNP; // Save the active running value
        }

        var currentSessionVI =
            mAveragePower > 0 ? globalNP / mAveragePower : 1.0;
        dc.drawText(
            xPos,
            yPos,
            font,
            "NP: " +
                globalNP.format("%.1f") +
                "W" +
                (latched ? " (latched)" : "") +
                " | Avg Pwr: " +
                mAveragePower.format("%.1f") +
                "W | Sess VI: " +
                currentSessionVI.format("%.2f"),
            justify
        );
        yPos += fontHeight;

        var averageTorqueAccumulator = 0.0;
        if (mAverageCadence > 0) {
            averageTorqueAccumulator =
                mAveragePower / (mAverageCadence * 0.10472);
        }
        dc.drawText(
            xPos,
            yPos,
            font,
            "Avg Cad: " +
                mAverageCadence.format("%.0f") +
                " RPM | Avg TQ: " +
                averageTorqueAccumulator.format("%.1f") +
                " Nm",
            justify
        );

        yPos += fontHeight;
        // Session TQ
        var maxValues = mTrendEngine.getMaxValues();
        var torqueRatio = 0.0;
        if (averageTorqueAccumulator > 0) {
            var maxTorque = maxValues[2];
            torqueRatio = maxTorque / averageTorqueAccumulator;
        }
        dc.drawText(
            xPos,
            yPos,
            font,
            "Max/ Avg TQ Ratio: " + torqueRatio.format("%.2f"),
            justify
        );
        yPos += fontHeight + 4;

        // --- 5. PEAK / RECORDED HISTORICAL MAXES ---
        dc.drawText(xPos, yPos, font, "--- HISTORICAL MAXES ---", justify);
        yPos += fontHeight;
        dc.drawText(
            xPos,
            yPos,
            font,
            "Max EF: " +
                maxValues[0].format("%.2f") +
                " | Max VI: " +
                maxValues[1].format("%.2f") +
                " | Max TQ: " +
                maxValues[2].format("%.1f") +
                "Nm",
            justify
        );
        yPos += fontHeight + 4;

        // --- 6. ENGINE SYSTEM TIMERS & INFRASTRUCTURE ---
        dc.drawText(xPos, yPos, font, "--- SYSTEM & TIMERS ---", justify);
        yPos += fontHeight;

        dc.drawText(
            xPos,
            yPos,
            font,
            "Blk " +
                mBlockCompletedCounter.format("%02d") +
                " at: " +
                $.getLongTimeString(
                    new Time.Moment(mCycloData.BlockCompleted)
                ) +
                " | Next In: " +
                $.secondsToHourMinutesSeconds(
                    mTrendEngine.getSecondsToNextLock()
                ),
            justify
        );
        yPos += fontHeight;

        dc.drawText(
            xPos,
            yPos,
            font,
            "Init EF on " +
                $.secondsToHourMinutesSeconds(
                    mTrendEngine.getInitialEFlockedAt()
                ),
            justify
        );
        yPos += fontHeight;

        var smoothingWindowSec = mTrendEngine.getSmoothingWindowSec();
        dc.drawText(
            xPos,
            yPos,
            font,
            "Smooth: " +
                smoothingWindowSec.format("%.0f") +
                "s | Elapsed: " +
                $.secondsToHourMinutesSeconds(mCycloData.Elapsed),
            justify
        );

        // If validEffortCount freezes at 30 or suddenly drops to 0 unexpectedly,
        yPos += fontHeight;
        var sumPowerForEF = mTrendEngine.getSumPowerForEF();
        var validEffortCount = mTrendEngine.getValidEffortCount();
        dc.drawText(
            xPos,
            yPos,
            font,
            "Buffer Count: " +
                validEffortCount.format("%d") +
                " | Raw Sum: " +
                sumPowerForEF.format("%.0f"),
            justify
        );

        // TODO Calculate rolling NP for the last 30s and display alongside global NP
        // to see how current effort compares to overall session trend.
        // It allows you to check whether a high VI alert triggered because your
        // rolling NP rocketed up or because your average power plummeted.
        // yPos += fontHeight;
        // var rollingNP = mTrendEngine.getRollingNormalizedPower(); // If you have a 30s NP method
        // dc.drawText(
        //     xPos,
        //     yPos,
        //     font,
        //     "Roll NP: " +
        //         rollingNP.format("%.1f") +
        //         "W | Glob NP: " +
        //         globalNP.format("%.1f") +
        //         "W",
        //     justify
        // );

        yPos += fontHeight;
        dc.drawText(
            xPos,
            yPos,
            font,
            "Raw Pwr: " +
                mCurrentPower.format("%d") +
                "W | Raw HR: " +
                mCurrentHeartRate.format("%d") +
                " bpm",
            justify
        );
    }

    function getThemeColor(darkBackground) as Dictionary<String, ColorType> {
        return {
            :text => darkBackground
                ? Graphics.COLOR_WHITE
                : Graphics.COLOR_BLACK,
            :background => darkBackground
                ? Graphics.COLOR_BLACK
                : Graphics.COLOR_WHITE,
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
                : Graphics.COLOR_DK_GREEN,
            :critial => mColorCritical,
            :high => mColorHigh,
            :warning => mColorWarning,
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

    function getTrendDisplayColor(
        trend as Number,
        colorGood as ColorType,
        colorBad as ColorType,
        colorNeutral as ColorType
    ) as ColorType {
        if (trend > 0) {
            return colorGood;
        } else if (trend < 0) {
            return colorBad;
        } else {
            return colorNeutral;
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
        trendTQ as Number
    ) as Void {
        var sep = " ";
        if (mEf == EfSmall) {
            // Small screen - 2 lines of warning message
            sep = "\n";
        }
        // Priority 1: Serious Cardiorespiratory Fatigue (EF dropping)
        if (trendEF == -1) {
            mWarningMessage = "DECOUPLING DETECTED:" + sep + "HYDRATE & PACE";
            mWarningColor = mColorCritical;
        }
        // Priority 2: High Muscle Strain (Torque too high)
        else if (trendTQ == -1) {
            mWarningMessage = "LEGS MASHING:" + sep + "SHIFT DOWN & SPIN";
            mWarningColor = mColorHigh;
        }
        // Priority 3: Erratic pacing (VI spiking)
        else if (trendVI == -1) {
            mWarningMessage = "BURNING MATCHES:" + sep + "SMOOTH EFFORT";
            mWarningColor = mColorWarning;
        }
        // Default State
        else {
            mWarningMessage = "";
            mWarningColor = mColorNeutral;
        }
    }

    // Draws a scalable bullseye/target icon centered at (cx, cy)
    function drawTargetIcon(
        dc as Dc,
        cx as Number,
        cy as Number,
        maxRadius as Number,
        colorOuter as ColorType,
        colorInner as ColorType
    ) as Void {
        // 1. Outer Ring (Red)
        dc.setColor(colorOuter, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, maxRadius);

        // 2. Middle Ring (White / Background color)
        // Scales down to 66% of the max radius
        dc.setColor(colorInner, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (maxRadius * 0.66).toNumber());

        // 3. Center Bullseye (Red)
        // Scales down to 33% of the max radius
        dc.setColor(colorOuter, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (maxRadius * 0.33).toNumber());
    }

    // Draws a scalable heart icon centered at (cx, cy)
    function drawHeartIcon(
        dc as Dc,
        cx as Number,
        cy as Number,
        size as Number,
        color as ColorType
    ) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        // Calculate dimensions based on the target size
        var radius = (size / 4).toNumber();
        var circleY = cy - radius;

        // Left and Right circle centers
        var leftCircleX = cx - (radius * 0.7).toNumber();
        var rightCircleX = cx + (radius * 0.7).toNumber();

        // 1. Draw the two upper rounded lobes
        dc.fillCircle(leftCircleX, circleY, radius);
        dc.fillCircle(rightCircleX, circleY, radius);

        // 2. Draw the bottom V-shape using a polygon (triangle)
        // Point 1: Leftmost edge of the left circle
        // Point 2: Rightmost edge of the right circle
        // Point 3: The bottom tip of the heart
        var points =
            [
                [leftCircleX - (radius * 1.1).toNumber(), circleY] as
                    Array<Number>,
                [rightCircleX + (radius * 1.1).toNumber(), circleY] as
                    Array<Number>,
                [cx, cy + (radius * 1.5).toNumber()] as Array<Number>,
            ] as Array<Array<Number> >;

        dc.fillPolygon(points);
    }

    function drawScalablePedalFaded(dc, cx, cy, size, isLeftPedal, color) {
        // Keep line weights thin so they stay in the background
        dc.setPenWidth(1);

        var axleLength = (size * 0.3).toNumber();
        var bodyWidth = (size * 0.6).toNumber();
        var bodyHeight = (size * 0.45).toNumber();
        var cornerRadius = (size * 0.1).toNumber();

        var bodyX = isLeftPedal ? cx - axleLength - bodyWidth : cx + axleLength;
        var bodyY = cy - bodyHeight / 2;

        // Use DARK_GRAY for a beautiful, subtle watermark on a black screen
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        drawPedalWithInsetFill(
            dc,
            bodyX,
            bodyY,
            bodyWidth,
            bodyHeight,
            cornerRadius,
            color
        );

        // Draw the tiny connecting spindle axle in dark gray too
        var axleX = isLeftPedal ? cx - axleLength : cx;
        dc.fillRectangle(axleX, cy - 2, axleLength, 4);
    }

    function drawPedalWithInsetFill(
        dc,
        bodyX,
        bodyY,
        bodyWidth,
        bodyHeight,
        cornerRadius,
        color
    ) {
        // 1. Define your internal spacing gap (e.g., 4 pixels of padding space)
        var gap = 4;

        // 2. Calculate the Inner Fill Dimensions
        var innerX = bodyX + gap;
        var innerY = bodyY + gap;
        var innerWidth = bodyWidth - gap * 2; // Shrinks both left & right edges
        var innerHeight = bodyHeight - gap * 2; // Shrinks both top & bottom edges

        // Proportional inner radius keeps the curves tracking beautifully parallel
        var innerRadius = cornerRadius - gap;
        if (innerRadius < 0) {
            innerRadius = 0;
        }

        // 3. DRAW LAYER 1: The Outer Wireframe Line
        dc.setPenWidth(1);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(
            bodyX,
            bodyY,
            bodyWidth,
            bodyHeight,
            cornerRadius
        );

        // 4. DRAW LAYER 2: The Inner Floating Solid Fill
        // Use a slightly different shade or color palette state to create depth!
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(
            innerX,
            innerY,
            innerWidth,
            innerHeight,
            innerRadius
        );
    }

    // Returns an interpretation object for EF (Aerobic Efficiency)
    // For smaller screen max 8 characters
    function evaluateEFDecoupling(avgEF, currentEF, isSmallScreen as Boolean) {
        if (avgEF == null || currentEF == null || avgEF == 0) {
            return {
                :text => isSmallScreen ? "Calc..." : "Calculating...",
                :color => mDarkBackground
                    ? Graphics.COLOR_DK_GRAY
                    : Graphics.COLOR_LT_GRAY,
            };
        }

        // Decoupling = (Initial/Average EF vs Current Moving EF)
        // A drop in EF means higher heart rate for the same power output
        var drift = ((currentEF - avgEF) / avgEF) * 100.0;
        if (drift < -10.0) {
            return {
                :text => isSmallScreen
                    ? drift.format("%.0f") + "% Dcop"
                    : "Decoupling (" + drift.format("%.1f") + "%)",
                :color => mColorCritical,
            };
        } else if (drift < -5.0) {
            return {
                :text => isSmallScreen
                    ? drift.format("%.0f") + "% Drft"
                    : "Mild Drift (" + drift.format("%.1f") + "%)",
                :color => mColorWarning,
            };
        }
        return {
            :text => isSmallScreen ? "Stable" : "Aerobic Stable",
            :color => mDarkBackground
                ? Graphics.COLOR_GREEN
                : Graphics.COLOR_DK_GREEN,
        };
    }

    // Returns an interpretation object for VI (Pacing Variability)
    function evaluateVIPacing(sessionVI, isSmallScreen as Boolean) {
        if (sessionVI == null || sessionVI == 0) {
            return {
                :text => "No Data",
                :color => mDarkBackground
                    ? Graphics.COLOR_DK_GRAY
                    : Graphics.COLOR_LT_GRAY,
            };
        }

        if (sessionVI > 1.08) {
            return {
                :text => isSmallScreen ? "Surged" : "Poor Pacing (Surged)",
                :color => mColorCritical,
            };
        } else if (sessionVI > 1.04) {
            return {
                :text => isSmallScreen ? "Spiky" : "Stochastic Ride",
                :color => mColorWarning,
            };
        }
        return {
            :text => isSmallScreen ? "Steady" : "Steady Pacing",
            :color => mDarkBackground
                ? Graphics.COLOR_GREEN
                : Graphics.COLOR_DK_GREEN,
        };
    }

    // Returns an interpretation object for Torque
    function evaluateTorqueStrain(
        avgTorque,
        maxTorque,
        isSmallScreen as Boolean
    ) {
        if (
            avgTorque == null ||
            maxTorque == null ||
            maxTorque == 0 ||
            avgTorque == 0
        ) {
            return {
                :text => "No Data",
                :color => mDarkBackground
                    ? Graphics.COLOR_DK_GRAY
                    : Graphics.COLOR_LT_GRAY,
            };
        }

        var ratio = maxTorque / avgTorque;

        if (ratio > 4.0) {
            // High Neuromuscular Strain
            return {
                :text => isSmallScreen ? "Strain" : "High N-M Strain",
                :color => mColorCritical,
            };
        } else if (ratio > 2.5) {
            return {
                // Heavy Neuromuscular Strain
                :text => isSmallScreen ? "Heavy" : "Heavy N-M Strain",
                :color => mColorHigh,
            };
        }
        return {
            :text => isSmallScreen ? "Smooth" : "Smooth Delivery",
            :color => mDarkBackground
                ? Graphics.COLOR_GREEN
                : Graphics.COLOR_DK_GREEN,
        };
    }

    function drawDemoBackground(
        dc as Dc,
        width as Number,
        height as Number,
        demoDuration as Number,
        elapsedSeconds as Number
    ) as Void {
        var color = getThemeColor(mDarkBackground);
        // 1. Calculate how many seconds are left in our 6-minute (360s) test loop
        var secondsLeft = demoDuration - elapsedSeconds;
        if (secondsLeft < 0) {
            secondsLeft = 0;
        }

        var centerX = (width / 2).toNumber();
        var phase = mTestGenerator.getCurrentPhase(elapsedSeconds);

        dc.setColor(color[:strong], Graphics.COLOR_TRANSPARENT);

        // Format seconds left into MM:SS
        var minutes = (secondsLeft / 60).toNumber();
        var seconds = secondsLeft % 60;
        var countdownStr =
            "DEMO - " +
            phase +
            " | " +
            minutes.format("%d") +
            ":" +
            seconds.format("%02d");

        dc.drawText(
            centerX,
            (height * 0.02).toNumber(),
            Graphics.FONT_XTINY,
            countdownStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    // Set your threshold limits (e.g., 3 minutes = 180 seconds)
    const ESCALATION_THRESHOLD_SEC = 180; // TODO setting

    hidden var mEfWarningSeconds as Number = 0;
    hidden var mViWarningSeconds as Number = 0;
    hidden var mTqWarningSeconds as Number = 0;

    function evaluateAlertEscalations(info as Activity.Info) as Void {
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTQ = mCycloData.TrendTQ;

        if (
            $.gBacklightOnAlert &&
            (trendEF == -1 || trendVI == -1 || trendTQ == -1)
        ) {
            backlightOnAlert();
        }

        if (!(Attention has :playTone && System.getDeviceSettings().tonesOn)) {
            return;
        }

        // 2. THE URBAN GATE: Check if we are still in the start-of-ride window
        var elapsedSec =
            ($.getActivityValue(info, :timerTime, 0) as Number) / 1000; // Convert to seconds
        var elapsedDistanceMeter =
            $.getActivityValue(info, :elapsedDistance, 0.0f) as Float;

        if (
            elapsedSec < $.gUrbanGateTimeSec &&
            elapsedDistanceMeter < $.gUrbanGateDistanceMeter
        ) {
            System.println(
                "Within Urban Gate window: " +
                    elapsedSec.format("%.1f") +
                    "s, " +
                    elapsedDistanceMeter.format("%.1f") +
                    "m. No alerts will sound."
            );
            // Reset our warning accumulators so they don't build up background time
            mEfWarningSeconds = 0;
            mViWarningSeconds = 0;
            mTqWarningSeconds = 0;
            return; // Exit the function early without making a sound
        }

        // 1. EVALUATE EFFICIENCY FACTOR (EF)
        if (trendEF == -1) {
            // Replace with your actual boolean check
            mEfWarningSeconds++;
            if (mEfWarningSeconds == 1) {
                Attention.playTone(Attention.TONE_LOUD_BEEP); // Soft initial warning
            } else if (
                $.gEFWarningThresholdSec > 0 &&
                mEfWarningSeconds >= $.gEFWarningThresholdSec &&
                mEfWarningSeconds % 60 == 0
            ) {
                Attention.playTone(Attention.TONE_CANARY); // Piercing escalation every minute after limit
            }
        } else {
            mEfWarningSeconds = 0; // Reset instantly if they fix their pace/hydration
        }

        // 2. EVALUATE VARIABILITY INDEX (VI)
        if (trendVI == -1) {
            mViWarningSeconds++;
            if (mViWarningSeconds == 1) {
                Attention.playTone(Attention.TONE_LOUD_BEEP);
            } else if (
                $.gVIWarningThresholdSec > 0 &&
                mViWarningSeconds >= $.gVIWarningThresholdSec &&
                mViWarningSeconds % 60 == 0
            ) {
                Attention.playTone(Attention.TONE_CANARY);
            }
        } else {
            mViWarningSeconds = 0;
        }

        // 3. EVALUATE TORQUE (TQ)
        if (trendTQ == -1) {
            mTqWarningSeconds++;
            if (mTqWarningSeconds == 1) {
                Attention.playTone(Attention.TONE_LOUD_BEEP);
            } else if (
                $.gTQWarningThresholdSec > 0 &&
                mTqWarningSeconds >= $.gTQWarningThresholdSec &&
                mTqWarningSeconds % 60 == 0
            ) {
                Attention.playTone(Attention.TONE_CANARY);
            }
        } else {
            mTqWarningSeconds = 0;
        }
    }

    function drawSafeZoneProgressBar(dc as Dc) as Void {
        var elapsedSec = mElapsedSeconds;
        var elapsedDist = mElapsedDistanceMeter;

        // 1. Get settings values (handling conversions)
        var targetTime = $.gUrbanGateTimeSec;
        var targetDist = $.gUrbanGateDistanceMeter;

        // 2. Guard: If ANY gates are breached, the safe zone is over. Draw nothing!
        if (elapsedSec >= targetTime || elapsedDist >= targetDist) {
            return;
        }

        // 3. Calculate percentages for both gates (capped between 0.0 and 1.0)
        var timeProgress =
            targetTime > 0 ? elapsedSec.toDouble() / targetTime : 1.0;
        var distProgress =
            targetDist > 0 ? elapsedDist.toDouble() / targetDist : 1.0;

        // 4. Determine which gate is closer to opening up the alerts (the higher percentage)
        var overallProgress =
            timeProgress > distProgress ? timeProgress : distProgress;
        if (overallProgress > 1.0) {
            overallProgress = 1.0;
        }

        // 5. Layout coordinates for the bottom bar
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        var barHeight = 22; // Compact but highly readable thickness
        var barY = screenHeight - barHeight - 4; // Positioned just above the absolute bottom bezel
        var barWidth = (screenWidth * 0.8).toNumber(); // Center the bar at 80% screen width
        var barX = (screenWidth - barWidth) / 2;

        // 6. DRAW THE BOUNDING BOX (Background)
        var color = getThemeColor(mDarkBackground);
        dc.setColor(color[:strong], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barWidth, barHeight);

        // 7. DRAW THE PROGRESS FILL (Shrinks or fills based on choice. Let's make it a filling bar)
        var fillWidth = (barWidth * overallProgress).toNumber();
        if (fillWidth > 0) {
            dc.setColor(mColorWarning, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX + 1, barY + 1, fillWidth - 2, barHeight - 2);
        }

        // 8. OVERLAY THE TEXT
        // Calculate countdown value to display (e.g., remaining percentage or just simple text)
        dc.setColor(color[:background], Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            screenWidth / 2,
            barY + 1,
            Graphics.FONT_XTINY,
            "Active in " + ((1.0 - overallProgress) * 100).toNumber() + "%",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}

class CycloData {
    public var ActualEF as Float = 0.0f;
    public var ActualVI as Float = 0.0f;
    public var ActualTQ as Float = 0.0f;

    public var LockedEF as Float = 0.0f;
    public var LockedVI as Float = 0.0f;
    public var LockedTorque as Float = 0.0f;

    public var TrendEF as Number = 0;
    public var TrendVI as Number = 0;
    public var TrendTQ as Number = 0;

    public var Locked as Boolean = false;
    public var BlockCompleted as Number = 0;

    public var Elapsed as Number = 0;
    public var BufferSize as Number = 0;

    function initialize() {}

    public function toString() as String {
        return (
            "EF: " +
            ActualEF.format("%.2f") +
            ", VI: " +
            ActualVI.format("%.2f") +
            ", Torque: " +
            ActualTQ.format("%.1f") +
            "Nm"
        );
    }
}
