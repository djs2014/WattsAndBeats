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
        var reset = $.getStorageValue("resetDefaults", null);
        if (reset == null || (reset as Boolean)) {
            $.StorageSetValue("resetDefaults", false);
            $.StorageSetValue("lock_interval_sec", 1800);
            $.StorageSetValue("demoMode", false);
            $.StorageSetValue("debugMode", false);
            $.StorageSetValue("lock_onlapkey", false);
            $.StorageSetValue("lock_onautolap", false);
            $.StorageSetValue("beep_onlap", false);
            $.StorageSetValue("beep_onlock", false);
            $.StorageSetValue("beep_onEFwarning", false);
            $.StorageSetValue("beep_onVIwarning", false);
            $.StorageSetValue("beep_onTQwarning", false);
            $.StorageSetValue("toast_onEFwarning", false);
            $.StorageSetValue("toast_onVIwarning", false);
            $.StorageSetValue("toast_onTQwarning", false);
            $.StorageSetValue("backlight_onalert", false);
        }

        // TODO
        $.gDebug = $.getStorageValue("debugMode", false) as Boolean;

        $.gLockOnLapKey = $.getStorageValue("lock_onlapkey", false) as Boolean;
        $.gLockOnAutoLap =
            $.getStorageValue("lock_onautolap", false) as Boolean;
        $.gBeepOnLap = $.getStorageValue("beep_onlap", false) as Boolean;
        $.gBeepOnLock = $.getStorageValue("beep_onlock", false) as Boolean;
        $.gBeepOnEFWarning =
            $.getStorageValue("beep_onEFwarning", false) as Boolean;
        $.gBeepOnVIWarning =
            $.getStorageValue("beep_onVIwarning", false) as Boolean;
        $.gBeepOnTQWarning =
            $.getStorageValue("beep_onTQwarning", false) as Boolean;
        $.gToastOnEFWarning =
            $.getStorageValue("toast_onEFwarning", false) as Boolean;
        $.gToastOnVIWarning =
            $.getStorageValue("toast_onVIwarning", false) as Boolean;
        $.gToastOnTQWarning =
            $.getStorageValue("toast_onTQwarning", false) as Boolean;
        $.gBacklightOnAlert =
            $.getStorageValue("backlight_onalert", false) as Boolean;


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
var gLockOnLapKey as Boolean = false;
var gLockOnAutoLap as Boolean = false;
var gLockIntervalSec as Number = 1800;
var gBeepOnLap as Boolean = false;
var gBeepOnLock as Boolean = false;
var gBeepOnEFWarning as Boolean = false;
var gBeepOnVIWarning as Boolean = false;
var gBeepOnTQWarning as Boolean = false;
var gToastOnEFWarning as Boolean = false;
var gToastOnVIWarning as Boolean = false;
var gToastOnTQWarning as Boolean = false;
var gBacklightOnAlert as Boolean = false;