import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application;

var gExitedMenu as Boolean = false;

//! Initial view for the settings
class DataFieldSettingsView extends WatchUi.View {
  //! Constructor
  function initialize() {
    View.initialize();
  }

  //! Update the view
  //! @param dc Device context
  function onUpdate(dc as Dc) as Void {
    dc.clearClip();
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

    var mySettings = System.getDeviceSettings();
    var version = mySettings.monkeyVersion;
    var versionString = Lang.format("$1$.$2$.$3$", version);
    var partNumber = mySettings.partNumber;

    dc.drawText(
      dc.getWidth() / 2,
      dc.getHeight() / 2 - 30,
      Graphics.FONT_SMALL,
      "Press Menu \nfor settings\nCIQ " + versionString + "\nDevice " + partNumber,
      Graphics.TEXT_JUSTIFY_CENTER
    );
  }
}

//! Handle opening the settings menu
class DataFieldSettingsDelegate extends WatchUi.BehaviorDelegate {
  //! Constructor
  function initialize() {
    BehaviorDelegate.initialize();
  }

  //! Handle the menu event
  //! @return true if handled, false otherwise
  function onMenu() as Boolean {
    var menu = new $.DataFieldSettingsMenu();
    var mi;
    
    mi = new WatchUi.MenuItem("Advanced", null, "advanced", null);
    menu.addItem(mi);

    // mi = new WatchUi.MenuItem("Large field", null, "large_field", null);
    // menu.addItem(mi);
    // mi = new WatchUi.MenuItem("Wide field", null, "wide_field", null);
    // menu.addItem(mi);
    // mi = new WatchUi.MenuItem("Small field", null, "small_field", null);
    // menu.addItem(mi);
    
    var boolean = false;

    boolean = Storage.getValue("demoMode") ? false : false;
    menu.addItem(new WatchUi.ToggleMenuItem("Demo", null, "demoMode", boolean, null));

    boolean = Storage.getValue("debugMode") ? false : false;
    menu.addItem(new WatchUi.ToggleMenuItem("Debug", null, "debugMode", boolean, null));

    boolean = Storage.getValue("resetDefaults") ? false : false;
    menu.addItem(new WatchUi.ToggleMenuItem("Reset", null, "resetDefaults", boolean, null));

    var view = new $.DataFieldSettingsView();
    WatchUi.pushView(menu, new $.DataFieldSettingsMenuDelegate(view), WatchUi.SLIDE_IMMEDIATE);
    return true;
  }

  function onBack() as Boolean {
    $.gExitedMenu = true;
    getApp().onSettingsChanged();
    return false;
  }
}

function subMenuToggleMenuItem(key as String) as String {  
  return "";
}
