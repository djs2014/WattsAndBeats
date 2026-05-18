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

    if (id instanceof String && id.equals("advanced")) {
      var advMenu = new WatchUi.Menu2({ :title => "Advanced" });

      var mi = new WatchUi.MenuItem(
        "Lock window sec|180-",
        null,
        "lock_window_sec",
        null
      );
      mi.setSubLabel($.getStorageNumberAsString(mi.getId() as String));
      advMenu.addItem(mi);

      // var boolean = Storage.getValue("layout_rows") ? false : false;
      // advMenu.addItem(
      //   new WatchUi.ToggleMenuItem(
      //     "Layout rows",
      //     null,
      //     "layout_rows",
      //     boolean,
      //     null
      //   )
      // );

      WatchUi.pushView(
        advMenu,
        new $.GeneralMenuDelegate(self, advMenu),
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
