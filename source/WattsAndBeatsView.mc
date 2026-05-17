import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class WattsAndBeatsView extends WatchUi.DataField {
    hidden var mDebug as Boolean = false;
    hidden var mDemoCounter as Number = 0;
    hidden var mDemoDuration as Number = 360; // 6 minutes of demo data
    hidden var mPaused as Boolean = true;

    hidden var mEf as EdgeField;
    hidden var mDarkBackground as Boolean = false;

    hidden var mTrendEngine as TrendEngine = new TrendEngine();
    hidden var mCycloData as CycloData = new CycloData();
    hidden var mActivityStarted as Boolean = false;
    hidden var mBlockCompletedCounter as Number = 0;

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

            mActivityStarted = info.timerState != Activity.TIMER_STATE_OFF;
        }

        if (mActivityStarted || mTrendEngine.isDemo()) {
            processTrendEngine(info);
        } else {
            mTrendEngine.reset();
            mCycloData = new CycloData();
        }
    }

    hidden function processTrendEngine(info as Activity.Info) as Void {
        var cadence = $.getActivityValue(info, :currentCadence, 0) as Number;
        var power = $.getActivityValue(info, :currentPower, 0) as Number;
        var heartRate =
            $.getActivityValue(info, :currentHeartRate, 0) as Number;

        if (mTrendEngine.isDemo()) {
            var fakeData = $.generateFakeData(mDemoCounter);
            cadence = fakeData[0];
            power = fakeData[1];
            heartRate = fakeData[2];
            mDemoCounter = mDemoCounter + 1;
            if (mDemoCounter > mDemoDuration) {
                mDemoCounter = 0;
                mTrendEngine.setDemo(false);
                mTrendEngine.setDefaults();
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

        drawTrends(dc);
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
    function drawTrends(dc as Dc) as Void {
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

        // 0. DRAW THE BOTTOM WARNING BAR - so its in the background.
        updateWarningMessage(trendEF, trendVI, trendTorque);
        if (mWarningMessage.length() > 0) {
            var barHeight = (height * 0.16).toNumber();
            if (mEf == EfSmall) {
                // 2 lines on small field
                barHeight = barHeight * 2;
            }
            var barY = height - barHeight;

            // Draw the background bounding block for the alert
            dc.setColor(mWarningColor, mWarningColor);
            dc.fillRectangle(0, barY, width, barHeight);

            // Use dark text on light alerts (Yellow) and white text on Red alerts
            if (mWarningColor == Graphics.COLOR_YELLOW) {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            }

            var fontWarning = Graphics.FONT_XTINY;
            dc.drawText(
                width / 2,
                barY + barHeight / 2, // / 4,
                fontWarning,
                mWarningMessage,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
        // ---

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

    function drawDebugInfo(dc as Dc) as Void {
        var color = getThemeColor(mDarkBackground);
        dc.setColor(color[:text], Graphics.COLOR_TRANSPARENT);

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
        text +=
            "Buffer Size: " +
            $.secondsToHourMinutesSeconds(mCycloData.BufferSize) +
            "\n";

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
