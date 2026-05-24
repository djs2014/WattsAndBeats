import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.UserProfile;

class WattsAndBeatsApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {}

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {}

    //! Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        onSettingsChanged();
        return [new WattsAndBeatsView()];
    }

    //! Return the settings view and delegate for the app
    //! @return Array Pair [View, Delegate]
    function getSettingsView() as [WatchUi.Views] or
        [WatchUi.Views, WatchUi.InputDelegates] or
        Null {
        return [
            new $.DataFieldSettingsView(),
            new $.DataFieldSettingsDelegate(),
        ];
    }

    function onSettingsChanged() {
        if ($.getStorageValue("Urban_gate_distance_m", null) == null) {
            $.StorageSetValue("Urban_gate_distance_m", 5000);
            $.StorageSetValue("Urban_gate_time_sec", 900);
            $.StorageSetValue("EF_warning_threshold_sec", 300); // 5 minutes
            $.StorageSetValue("VI_warning_threshold_sec", 300); // 5 minutes
            $.StorageSetValue("TQ_warning_threshold_sec", 600); // 10 minutes
        }
        var reset = $.getStorageValue("resetDefaults", null);
        if (reset == null || (reset as Boolean)) {
            $.StorageSetValue("resetDefaults", false);
            $.StorageSetValue("lock_interval_sec", 1800);
            $.StorageSetValue("smoothing_window_sec", 20);
            $.StorageSetValue("initial_ef_sec", 900);
            $.StorageSetValue("initial_ef_on_lap", false);

            $.StorageSetValue("demoMode", false);
            $.StorageSetValue("debugMode", false);
            // $.StorageSetValue("lock_onlapkey", false);
            $.StorageSetValue("lock_onautolap", true);
            $.StorageSetValue("beep_onlock", false);

            $.StorageSetValue("Urban_gate_distance_m", 5000);
            $.StorageSetValue("Urban_gate_time_sec", 900);

            $.StorageSetValue("beep_onEFwarning", true);
            $.StorageSetValue("beep_onVIwarning", true);
            $.StorageSetValue("beep_onTQwarning", true);
            $.StorageSetValue("EF_warning_threshold_sec", 300); // 5 minutes
            $.StorageSetValue("VI_warning_threshold_sec", 300); // 5 minutes
            $.StorageSetValue("TQ_warning_threshold_sec", 600); // 10 minutes

            $.StorageSetValue("backlight_onalert", false);
            $.StorageSetValue("background_onalert", false);
            $.StorageSetValue("text_whiteonred", true);
            $.StorageSetValue("text_whiteonorange", true);
            $.StorageSetValue("text_whiteonyellow", true);

            $.StorageSetValue("showPauseScreen", true);
        }

        // TODO
        $.gDebug = $.getStorageValue("debugMode", false) as Boolean;
        $.gShowPauseScreen =
            $.getStorageValue("showPauseScreen", true) as Boolean;

        // TODO $.gLockOnLapKey = $.getStorageValue("lock_onlapkey", false) as Boolean;
        $.gLockOnAutoLap = $.getStorageValue("lock_onautolap", true) as Boolean;
        $.gBeepOnLock = $.getStorageValue("beep_onlock", false) as Boolean;

        $.gUrbanGateDistanceMeter =
            $.getStorageValue("Urban_gate_distance_m", 5000) as Number;
        $.gUrbanGateTimeSec =
            $.getStorageValue("Urban_gate_time_sec", 900) as Number;

        $.gBeepOnEFWarning =
            $.getStorageValue("beep_onEFwarning", false) as Boolean;
        $.gBeepOnVIWarning =
            $.getStorageValue("beep_onVIwarning", false) as Boolean;
        $.gBeepOnTQWarning =
            $.getStorageValue("beep_onTQwarning", false) as Boolean;
        $.gEFWarningThresholdSec =
            $.getStorageValue("EF_warning_threshold_sec", 300) as Number;
        $.gVIWarningThresholdSec =
            $.getStorageValue("VI_warning_threshold_sec", 300) as Number;
        $.gTQWarningThresholdSec =
            $.getStorageValue("TQ_warning_threshold_sec", 600) as Number;

        $.gBacklightOnAlert =
            $.getStorageValue("backlight_onalert", false) as Boolean;
        $.gBackgroundOnAlert =
            $.getStorageValue("background_onalert", false) as Boolean;
        $.gTextWhiteOnRed =
            $.getStorageValue("text_whiteonred", true) as Boolean;
        $.gTextWhiteOnOrange =
            $.getStorageValue("text_whiteonorange", true) as Boolean;
        $.gTextWhiteOnYellow =
            $.getStorageValue("text_whiteonyellow", true) as Boolean;

        var trendEngine = getTrendEngine();

        $.gLockIntervalSec =
            $.getStorageValue("lock_interval_sec", $.gLockIntervalSec) as
            Number;
        trendEngine.setLockWindowSec($.gLockIntervalSec);
        var actualIntervalSec = trendEngine.getLockWindowSec();
        if (actualIntervalSec != $.gLockIntervalSec) {
            $.gLockIntervalSec = actualIntervalSec;
            $.StorageSetValue("lock_interval_sec", actualIntervalSec);
        }

        var smoothingWindowSec =
            $.getStorageValue("smoothing_window_sec", 20) as Number;
        trendEngine.setSmoothingWindowSec(smoothingWindowSec);
        var actualSmoothingWindowSec = trendEngine.getSmoothingWindowSec();
        if (actualSmoothingWindowSec != smoothingWindowSec) {
            $.StorageSetValue("smoothing_window_sec", actualSmoothingWindowSec);
        }

        var initialEFSec = $.getStorageValue("initial_ef_sec", 900) as Number;
        trendEngine.setInitialEFSec(initialEFSec);

        $.gInitialEFOnLap =
            $.getStorageValue("initial_ef_on_lap", false) as Boolean;

        var demo = $.getStorageValue("demoMode", false) as Boolean;
        if (demo != trendEngine.isDemo()) {
            trendEngine.setDemo(demo);
            if (!demo) {
                // Restore defaults when exiting demo mode
                trendEngine.setLockWindowSec($.gLockIntervalSec);
            }
            trendEngine.reset();
        }

        if (demo) {
            // Demo will run once
            $.StorageSetValue("demoMode", false);
        }
    }
}

function getApp() as WattsAndBeatsApp {
    return Application.getApp() as WattsAndBeatsApp;
}
function getTrendEngine() as TrendEngine {
    if (gTrendEngine == null) {
        $.gTrendEngine = new TrendEngine();
    }
    return $.gTrendEngine as TrendEngine;
}
var gTrendEngine as TrendEngine?;

var gDebug as Boolean = false;
var gShowPauseScreen as Boolean = true;
var gLockOnLapKey as Boolean = false;
var gLockOnAutoLap as Boolean = true;
var gLockIntervalSec as Number = 1800;
var gInitialEFOnLap as Boolean = false;

var gUrbanGateDistanceMeter as Number = 5000;
var gUrbanGateTimeSec as Number = 900;
var gBeepOnLock as Boolean = false;
var gBeepOnEFWarning as Boolean = false;
var gBeepOnVIWarning as Boolean = false;
var gBeepOnTQWarning as Boolean = false;
var gEFWarningThresholdSec as Number = 300;
var gVIWarningThresholdSec as Number = 300;
var gTQWarningThresholdSec as Number = 600;
var gBacklightOnAlert as Boolean = false;
var gBackgroundOnAlert as Boolean = false;
var gTextWhiteOnRed as Boolean = true;
var gTextWhiteOnOrange as Boolean = true;
var gTextWhiteOnYellow as Boolean = true;
