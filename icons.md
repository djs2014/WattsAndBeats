Method 1: The Custom Font Approach (Recommended)
This is the industry standard for Connect IQ data fields. You use a tool like IcoMoon to turn SVG icons of a gear, pedal, or wrench into a custom .ttf font file. Then, you simply draw the icon as if it were a text string.

https://icomoon.io/

1. Define the font in your resources.xml:

<resources>
    <font id="IconFont" filename="fonts/my_icons.ttf" glyphs="⚙🔧 pedal" />
</resources>

import Toybox.Graphics;
import Toybox.Application;

function drawIconFont(dc as Dc, x as Number, y as Number) as Void {
    // Load the custom font from resources
    var iconFont = Application.loadResource() 1(Rez.Fonts.IconFont);
    
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    
    // Map your icons to specific characters (e.g., 'G' for Gear)
    dc.drawText(x, y, iconFont, "G", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
}

Why it’s great: It scales perfectly to any size without losing quality, supports any color you want via dc.setColor(), and uses almost zero processing power.


check ttf with 
https://fontdrop.info/#/?darkmode=true

F0D2 == gear
F109 == bullseye
F436 == heart

Assign ligatures to the glyphs. Like h -> hart icon font.

-------------------------------------------------------------

The absolute best approach—and the industry standard for Garmin Connect IQ development—is to convert your TrueType Font (.ttf) into a pre-rendered Bitmap Font format (.fnt and .png) before compiling.

While it sounds counterintuitive to turn a vector font into a bitmap, Garmin's low-power processors cannot dynamically parse and render standard vector .ttf files on the fly. Monkey C strictly expects bitmap font maps to optimize battery life and layout calculations.


The Workflow PipelineStep 1: 

Use https://icomoon.io/

Map your Icons to Standard ASCII CharactersInside your custom .ttf file (using a tool like IcoMoon or FontForge), map your custom metrics symbols to simple, printable ASCII characters. This makes it incredibly easy to reference them directly inside your source code string parameters.

Map your Variability Target $\rightarrow$ to character "V"
Map your Torque Curved Arrow $\rightarrow$ to character "T"
Map your Efficiency Heart/Bolt $\rightarrow$ to character "E"

Step 2: Convert to Bitmap Font Pair

You need to convert your .ttf into a paired text descriptor (.fnt) and texture atlas file (.png).

Windows Option: Use BMFont (AngelCode), the official tool recommended by Garmin. Set Export Options texture output to PNG and channel configuration A to glyph.

Mac/Linux Option: Use the open-source command line tool fontbm via terminal:
https://github.com/vladimirgamalyan/fontbm

```
fontbm --font-file icons.ttf --font-size 24 --output cyclo_icons
```

This generates two output assets: cyclo_icons.fnt and cyclo_icons_0.png.

Integrating the Font into Resources

Move both of your newly generated files directly into your project's internal resource architecture folder: resources/fonts/.

Next, modify your central layout resource manager XML configuration file (resources/resources.xml) so the build compiler initializes the asset allocation bundle:

<resources>
    <fonts>
        <font id="iconFont" filename="fonts/cyclo_icons.fnt" filter="EVT" />
        <font id="my_icon_font" filename="my_font.fnt" filter="&#xF000;&#xF001;&#xF002;" />
    </fonts>
</resources>
No need for filter if contains only the icon.


Critical Pro-Tip: Always add the filter attribute containing only the specific characters you mapped. If you omit the filter attribute, Garmin's compiler will generate data definitions for all 256 structural character slots, bloating your compiled app container size. Filtering drops your asset resource footprint down to practically zero bytes.

Loading & Drawing Icons via Source Code


Now that your resource declaration is active, load the asset tracking reference into device RAM memory during the class initiation phase (initialize()).

Once cached, draw the custom graphics assets inside your active drawColumnLayout block:


class CycloMetricsView extends WatchUi.DataField {
    private var customIconsFont = null;

    // Mapping the icons to variables using their hex codes
    // Check in BMFont generator, hovering over icons
    hidden var mHheartIcon as String = "\uF000";
    hidden var mBulletIcon as String = "\uF001";
    hidden var mTorqueIcon as String = "\uF002";

    function initialize() {
        DataField.initialize();
        // Load the system resource memory pointer once to preserve battery efficiency
        customIconsFont = WatchUi.loadResource(Rez.Fonts.iconFont);
    }

    function drawColumnLayout(dc, width, height) {
        var col1X = (width * 0.18).toNumber();
        var col2X = (width * 0.50).toNumber();
        var col3X = (width * 0.82).toNumber();
        var headerY = (height * 0.12).toNumber();
        
        var jCenter = Graphics.TEXT_JUSTIFY_CENTER;

        // Set the active text rendering color configuration state
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);

        // Draw your custom icons using the string characters mapped in step 1!
        dc.drawText(col1X, headerY, customIconsFont, "E", jCenter); // Renders your EF Icon
        dc.drawText(col2X, headerY, customIconsFont, "V", jCenter); // Renders your VI Icon
        dc.drawText(col3X, headerY, customIconsFont, "T", jCenter); // Renders your TQ Icon
        
        // Switch back to stock fonts below for metrics numerical text rendering...
    }
}


Dynamic Native Tinting: Unlike loading independent static PNG image files via drawBitmap(), loading an asset bundle as a custom font lets you call dc.setColor() immediately before executing the layout text statement. Your icons will automatically tint dynamically to any color state (Green/Red alert profiles) instantly.

Sub-pixel Anti-Aliasing: The pre-computed BMFont raster descriptor structures character padding rules perfectly, ensuring shapes remain crisp on compact memory-display screens without pixelation or clipping boundaries.


== Using BMFont
Connect IQ ERROR: font does not have characters in the given filter 'VET'.


Step 1: Add 'VET' to BMFont
Open your font project back up in BMFont.

In the main grid, locate the uppercase letters V, E, and T.

Click on each of them so they turn bright blue/cyan (meaning they are selected).

Go to Options > Save bitmap font as... and overwrite your existing .fnt and .png files.

