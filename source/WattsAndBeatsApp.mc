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
            // TODO
        }

        $.gDebug = $.getStorageValue("debugMode", false) as Boolean;
        
        var trendEngine = getTrendEngine();
        var demo = $.getStorageValue("demoMode", false) as Boolean;
        if (demo != trendEngine.isDemo()) {
            trendEngine.setDemo(demo);
            if (!demo) {
                // Restore defaults when exiting demo mode
                trendEngine.setDefaults();
            }
        }        
        if (demo) {
            // Demo will run once
            $.StorageSetValue("demoMode", false);
        }
    }
}

var gDebug as Boolean = false;

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