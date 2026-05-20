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
        var reset = $.getStorageValue("resetDefaults", false);
        if (reset == null || (reset as Boolean)) {
            $.StorageSetValue("resetDefaults", false);
            $.StorageSetValue("lock_window_sec", 1800);
            $.StorageSetValue("demoMode", false);
            $.StorageSetValue("debugMode", false);
        }

            // TODO
        $.gDebug = $.getStorageValue("debugMode", false) as Boolean;
        $.gOnLapKeyLockData = $.getStorageValue("onlapkey_lockdata", false) as Boolean;

        var trendEngine = getTrendEngine();
        
        $.gLockWindowSec =
            $.getStorageValue("lock_window_sec", $.gLockWindowSec) as Number;
        
        trendEngine.setLockWindowSec($.gLockWindowSec);

        var demo = $.getStorageValue("demoMode", false) as Boolean;
        if (demo != trendEngine.isDemo()) {
            trendEngine.setDemo(demo);
            if (!demo) {
                // Restore defaults when exiting demo mode
                trendEngine.setLockWindowSec($.gLockWindowSec);
                trendEngine.reset();
            }
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
var gOnLapKeyLockData as Boolean = false;
var gLockWindowSec as Number = 1800;
