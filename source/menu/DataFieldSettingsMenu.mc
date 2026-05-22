import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class DataFieldSettingsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Settings" });
  }
}

//! Handles menu input and stores the menu data
class DataFieldSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
  hidden var _currentMenuItem as MenuItem?;
  hidden var _view as DataFieldSettingsView;

  function initialize(view as DataFieldSettingsView) {
    Menu2InputDelegate.initialize();
    _view = view;
  }

  function onSelect(item as MenuItem) as Void {
    _currentMenuItem = item;
    var id = item.getId();

    if (id instanceof String && item instanceof ToggleMenuItem) {
      $.StorageSetValue(id as String, item.isEnabled());
      return;
    }

    if (id instanceof String && id.equals("lock_data")) {
      var lockMenu = new WatchUi.Menu2({ :title => "Lock data setings" });

      var mi = new WatchUi.MenuItem(
        "Lock interval sec|180-",
        null,
        "lock_interval_sec",
        null
      );
      mi.setSubLabel($.getStorageNumberAsString(mi.getId() as String));
      lockMenu.addItem(mi);

      var boolean;
      boolean = $.getStorageValue("lock_onlapkey", false) as Boolean;
      lockMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Lock on lap key",
          null,
          "lock_onlapkey",
          boolean,
          null
        )
      );
      boolean = $.getStorageValue("lock_onautolap", false) as Boolean;
      lockMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Lock on auto lap",
          null,
          "lock_onautolap",
          boolean,
          null
        )
      );

      WatchUi.pushView(
        lockMenu,
        new $.GeneralMenuDelegate(self, lockMenu),
        WatchUi.SLIDE_UP
      );
      return;
    }

    if (id instanceof String && id.equals("alerts")) {
      var alertMenu = new WatchUi.Menu2({ :title => "Alerts" });

      var boolean;

      boolean = Storage.getValue("backlight_onalert") ? false : false;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "Backlight on alert",
          null,
          "backlight_onalert",
          boolean,
          null
        )
      );

      // When pressed the lap key
      boolean = Storage.getValue("beep_onlap") ? false : false;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "On lap (beep)",
          null,
          "beep_onlap",
          boolean,
          null
        )
      );

      boolean = $.getStorageValue("beep_onlock", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "On lock (beep)",
          null,
          "beep_onlock",
          boolean,
          null
        )
      );

      boolean = $.getStorageValue("beep_onEFwarning", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "EF warning (beep)",
          null,
          "beep_onEFwarning",
          boolean,
          null
        )
      );
      boolean = $.getStorageValue("toast_onEFwarning", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "EF warning (toast)",
          null,
          "toast_onEFwarning",
          boolean,
          null
        )
      );
      boolean = $.getStorageValue("beep_onVIwarning", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "VI warning (beep)",
          null,
          "beep_onVIwarning",
          boolean,
          null
        )
      );
      boolean = $.getStorageValue("toast_onVIwarning", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "VI warning (toast)",
          null,
          "toast_onVIwarning",
          boolean,
          null
        )
      );
      boolean = $.getStorageValue("beep_onTQwarning", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "TQ warning (beep)",
          null,
          "beep_onTQwarning",
          boolean,
          null
        )
      );
      boolean = $.getStorageValue("toast_onTQwarning", false) as Boolean;
      alertMenu.addItem(
        new WatchUi.ToggleMenuItem(
          "TQ warning (toast)",
          null,
          "toast_onTQwarning",
          boolean,
          null
        )
      );

      // on ef warning beep_onEFwarning
      // on vi warning beep_onVIwarning
      // on torque warning beep_onTQwarning

      // toast options warnings

      WatchUi.pushView(
        alertMenu,
        new $.GeneralMenuDelegate(self, alertMenu),
        WatchUi.SLIDE_UP
      );
      return;
    }
  }

  function onSelectedSelection(
    storageKey as String,
    value as Application.PropertyValueType
  ) as Void {
    $.StorageSetValue(storageKey, value);
  }
}

class GeneralMenuDelegate extends WatchUi.Menu2InputDelegate {
  hidden var _delegate as DataFieldSettingsMenuDelegate;
  hidden var _item as MenuItem?;
  hidden var _debug as Boolean = false;

  function initialize(
    delegate as DataFieldSettingsMenuDelegate,
    menu as WatchUi.Menu2
  ) {
    Menu2InputDelegate.initialize();
    _delegate = delegate;
  }

  function onSelect(item as MenuItem) as Void {
    _item = item;
    var id = item.getId() as String;

    if (id instanceof String && item instanceof ToggleMenuItem) {
      $.StorageSetValue(id as String, item.isEnabled());
      // item.setSubLabel($.subMenuToggleMenuItem(id as String));
      return;
    }

    // Numeric input
    var prompt = item.getLabel();
    var value = $.getStorageValue(id as String, 0) as Numeric;
    var view = $.getNumericInputView(prompt, value);
    view.setOnAccept(self, :onAcceptNumericinput);
    view.setOnKeypressed(self, :onNumericinput);

    Toybox.WatchUi.pushView(
      view,
      new $.NumericInputDelegate(view),
      WatchUi.SLIDE_RIGHT
    );
  }

  function onAcceptNumericinput(value as Numeric, subLabel as String) as Void {
    try {
      if (_item != null) {
        var storageKey = _item.getId() as String;

        Storage.setValue(storageKey, value);
        (_item as MenuItem).setSubLabel(subLabel);
      }
    } catch (ex) {
      ex.printStackTrace();
    }
  }

  function onNumericinput(
    editData as Array<Char>,
    cursorPos as Number,
    insert as Boolean,
    negative as Boolean,
    opt as NumericOptions
  ) as Void {
    // Hack to refresh screen
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    var view = new $.NumericInputView("", 0);
    view.processOptions(opt);
    view.setEditData(editData, cursorPos, insert, negative);
    view.setOnAccept(self, :onAcceptNumericinput);
    view.setOnKeypressed(self, :onNumericinput);

    Toybox.WatchUi.pushView(
      view,
      new $.NumericInputDelegate(view),
      WatchUi.SLIDE_IMMEDIATE
    );
  }

  //! Handle the back key being pressed

  function onBack() as Void {
    WatchUi.popView(WatchUi.SLIDE_DOWN);
  }

  //! Handle the done item being selected

  function onDone() as Void {
    WatchUi.popView(WatchUi.SLIDE_DOWN);
  }

  // --

  function onSelectedSelection(
    storageKey as String,
    value as Application.PropertyValueType
  ) as Void {
    Storage.setValue(storageKey, value);
  }
}

function getStorageNumberAsString(key as String) as String {
  return (getStorageValue(key, 0) as Number).format("%0d");
}

function getStorageFloatAsString(key as String) as String {
  return (getStorageValue(key, 0) as Float).format("%.1f");
}
