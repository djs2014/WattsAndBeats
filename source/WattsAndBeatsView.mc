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
    hidden var mTestGenerator as TrendEngineGenerator =
        new TrendEngineGenerator();

    hidden var mCycloData as CycloData = new CycloData();
    hidden var mActivityStarted as Boolean = false;
    hidden var mBlockCompletedCounter as Number = 0;

    hidden var mFirstBlockEF as Float = -1.0f;
    hidden var mLatestBlockEF as Float = 0.0f;
    hidden var mAveragePower as Number = 0;
    hidden var mAverageCadence as Number = 0;

    hidden var mHeaderFont as Graphics.FontType = Graphics.FONT_MEDIUM;

    hidden var mBeepOnEFWarningHandled as Boolean = false;
    hidden var mBeepOnVIWarningHandled as Boolean = false;
    hidden var mBeepOnTQWarningHandled as Boolean = false;

    hidden var mColorCritical as ColorType = Graphics.COLOR_RED;
    hidden var mColorHigh as ColorType = Graphics.COLOR_YELLOW;
    hidden var mColorWarning as ColorType = Graphics.COLOR_YELLOW;
    hidden var mColorNeutral as ColorType = Graphics.COLOR_LT_GRAY;

    function initialize() {
        DataField.initialize();
        mTrendEngine = getTrendEngine();
        mTrendEngine.setOnBlockCompleted(self, :onBlockCompleted);

        var edgeVersion = $.getEdgeVersion();

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

        mAveragePower = $.getActivityValue(info, :averagePower, 0) as Number;
        mAverageCadence =
            $.getActivityValue(info, :averageCadence, 0) as Number;

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
        processTrendEngineWarnings();
    }

    function onTimerLap2(trigger as DataField.LapInfoType) as Lang.Boolean {
        System.println(["Lap triggered: ", trigger]);
        if (trigger == DataField.LAP_TRIGGER_MANUAL) {
            System.println("Lap button pressed");
            if ($.gBeepOnLap) {
                alertOnEvent(Attention.TONE_LAP);
            }
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
        if ($.gLockOnAutoLap) {
            if ($.gBeepOnLap) {
                alertOnEvent(Attention.TONE_LAP);
            }
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
            Attention.playTone(Attention.TONE_LAP);
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
        mCycloData.ActualTorque = data[2] as Float;
        mCycloData.TrendEF = data[3] as Number;
        mCycloData.TrendVI = data[4] as Number;
        mCycloData.TrendTorque = data[5] as Number;
        mCycloData.Locked = mTrendEngine.isLocked();
        mCycloData.Elapsed = mTrendEngine.getElapsedSeconds();
        mCycloData.BufferSize = mTrendEngine.getBufferSize();
    }

    function processTrendEngineWarnings() as Void {
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTorque = mCycloData.TrendTorque;
        var hasWarning = trendEF == -1 || trendVI == -1 || trendTorque == -1;

        // Reset handled state if trend is no longer in warning state
        if (trendEF != -1 && mBeepOnEFWarningHandled) {
            mBeepOnEFWarningHandled = false;
        }
        if (trendVI != -1 && mBeepOnVIWarningHandled) {
            mBeepOnVIWarningHandled = false;
        }
        if (trendTorque != -1 && mBeepOnTQWarningHandled) {
            mBeepOnTQWarningHandled = false;
        }

        if (!hasWarning) {
            return;
        }
        // There is a warning
        if ($.gBacklightOnAlert) {
            backlightOnAlert();
        }

        // Prio EF over Torque over Vi
        if (trendEF == -1 and !mBeepOnEFWarningHandled) {
            if ($.gBeepOnEFWarning) {
                alertOnEvent(Attention.TONE_ALARM);
            }
            if ($.gToastOnEFWarning) {
                toastOnEvent("Aerobic decoupling! (EF)");
            }
            mBeepOnEFWarningHandled = true;
        } else if (
            $.gBeepOnTQWarning and
            trendTorque == -1 and
            !mBeepOnTQWarningHandled
        ) {
            if ($.gBeepOnTQWarning) {
                alertOnEvent(Attention.TONE_ALARM);
            }
            if ($.gToastOnTQWarning) {
                toastOnEvent("Torque Warning! (TQ)");
            }
            mBeepOnTQWarningHandled = true;
        } else if (trendVI == -1 and !mBeepOnVIWarningHandled) {
            if ($.gBeepOnVIWarning) {
                alertOnEvent(Attention.TONE_ALARM);
            }
            if ($.gToastOnVIWarning) {
                toastOnEvent("Pacing! (VI)");
            }
            mBeepOnVIWarningHandled = true;
        }
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

    // TODO sublabel explaining the EF/VI/TQ
    // Display Avg, intepretation drop etc, MAX
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

            System.println([
                "Avg cadence:",
                mAverageCadence,
                "Avg power:",
                mAveragePower,
                "Global NP:",
                globalNP,
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
        var trendTorque = mCycloData.TrendTorque;
        var locked = mCycloData.Locked;

        // 0. DRAW THE BOTTOM WARNING/PROGRESS BAR - so its in the background.
        updateWarningMessage(trendEF, trendVI, trendTorque);

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
        var warningPillWidth = (width * 0.95).toNumber();
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
        var actualTorque = mCycloData.ActualTorque;
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTorque = mCycloData.TrendTorque;

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
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
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
            Graphics.COLOR_WHITE,
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
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
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
            Graphics.COLOR_BLACK,
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

        if (trendTorque == -1) {
            // Draw warning highlight for TQ row ORANGE
            dc.setColor(mColorHigh, mColorHigh);
            dc.fillRectangle(
                warningPillx,
                yTQ - warningPillYoffset,
                warningPillWidth,
                warningPillHeight
            );
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
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
            trendTorque,
            color[:good],
            Graphics.COLOR_BLACK,
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

        // Highlight box when any of the metrics is in warning state
        var barYAndHeight = getBottomWarningBarYAndHeight(height);
        var barY = barYAndHeight[0];
        var barHeight = barYAndHeight[1];

        var warningPillY = (height * 0.05).toNumber();
        var warningPillWidth = (width * 0.3).toNumber();
        var warningPillHeight =
            height - barHeight - (warningPillY * 2).toNumber();
        // var warningPillY = (height * 0.3).toNumber();

        // --- STEP 1: DRAW HEADERS (Labels + icons) ---
        var textEF = "EF";
        var textVI = "VI";
        var textTQ = "TQ";

        var actualEF = mCycloData.ActualEF;
        var actualVI = mCycloData.ActualVI;
        var actualTorque = mCycloData.ActualTorque;
        var trendEF = mCycloData.TrendEF;
        var trendVI = mCycloData.TrendVI;
        var trendTorque = mCycloData.TrendTorque;
        var lockedEF = mCycloData.LockedEF;
        var lockedVI = mCycloData.LockedVI;
        var lockedTorque = mCycloData.LockedTorque;

        // Default
        var yCenter = headerY;
        var headerFont = mHeaderFont;
        var alignHeaderText = Graphics.TEXT_JUSTIFY_CENTER;

        var EFwarning = trendEF == -1;
        var VIwarning = trendVI == -1;
        var TQwarning = trendTorque == -1;

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
            Graphics.COLOR_WHITE,
            color[:faded]
        );
        drawHeartIcon(dc, col1X - fontHeight, iconY, fontHeight, heartColor);

        var targetColor = getTrendDisplayColor(
            trendVI,
            color[:faded],
            Graphics.COLOR_BLACK,
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
            trendTorque,
            color[:faded],
            Graphics.COLOR_BLACK,
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
        var colorTextEF = EFwarning ? Graphics.COLOR_WHITE : color[:text];
        var colorTextVI = VIwarning ? Graphics.COLOR_BLACK : color[:text];
        var colorTextTQ = TQwarning ? Graphics.COLOR_BLACK : color[:text];

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
            Graphics.COLOR_WHITE,
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
            Graphics.COLOR_BLACK,
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
            Graphics.COLOR_BLACK,
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
                : Graphics.COLOR_GREEN,
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
            mWarningColor = mColorCritical;
        }
        // Priority 2: High Muscle Strain (Torque too high)
        else if (trendTorque == -1) {
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
        // dc.drawRoundedRectangle(
        //     bodyX,
        //     bodyY,
        //     bodyWidth,
        //     bodyHeight,
        //     cornerRadius
        // );
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

    function drawScalablePedal(dc, cx, cy, size, isLeftPedal) {
        // Set line thickness proportional to the size of the pedal
        var penWidth = (size * 0.06).toNumber();
        if (penWidth < 1) {
            penWidth = 1;
        }
        dc.setPenWidth(penWidth);

        // 1. Calculate dimensions relative to our master size variable
        var axleLength = (size * 0.35).toNumber();
        var axleWidth = (size * 0.12).toNumber();
        var bodyWidth = (size * 0.65).toNumber();
        var bodyHeight = (size * 0.85).toNumber();
        var cornerRadius = (size * 0.15).toNumber();

        // 2. Adjust orientation based on whether it's the left or right pedal
        var direction = isLeftPedal ? -1 : 1;

        // 3. Draw the Axle Spindle (Connecting the crank pivot to the pedal body)
        var axleX = isLeftPedal ? cx - axleLength : cx;
        var axleY = cy - axleWidth / 2;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(axleX, axleY, axleLength, axleWidth);

        // 4. Draw the Spindle Cap/Pivot point at the crank arm
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (axleWidth * 1.2).toNumber());

        // 5. Draw the Main Pedal Body Frame
        var bodyX = isLeftPedal ? cx - axleLength - bodyWidth : cx + axleLength;
        var bodyY = cy - bodyHeight / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(
            bodyX,
            bodyY,
            bodyWidth,
            bodyHeight,
            cornerRadius
        );

        // 6. Draw Internal Grip Cutouts (The pedal "window" details)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var windowWidth = (bodyWidth * 0.7).toNumber();
        var windowHeight = (bodyHeight * 0.3).toNumber();
        var windowX = bodyX + (bodyWidth - windowWidth) / 2;

        // Upper window cutout
        var windowY1 = bodyY + (bodyHeight * 0.15).toNumber();
        dc.drawRoundedRectangle(
            windowX,
            windowY1,
            windowWidth,
            windowHeight,
            (cornerRadius * 0.5).toNumber()
        );

        // Lower window cutout
        var windowY2 = bodyY + (bodyHeight * 0.55).toNumber();
        dc.drawRoundedRectangle(
            windowX,
            windowY2,
            windowWidth,
            windowHeight,
            (cornerRadius * 0.5).toNumber()
        );
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
