EarthView 3D Globe Visualization for iOS
========================================

EarthView is an open-source 3D visualization of the Earth globe for iOS that uses map tiles for imagery and OpenGL ES and GLKit for rendering. I built it for a side-project that may never go anywhere, so I figured it might be educational or useful to other developers.

The project uses a quad-tree to page in map tiles that conform to the Tile Map Service standard (or, the flipped Google equivalent). The level of detail to display is determined by the estimated screen-space error of a given page.

Besides fixing the bugs listed below, I am interested in adding topographical terrain detail to the map. I intend to load heightmap data using the same map tile system as the visible content.

Enjoy!

![](https://github.com/RossAnderson/EarthView/raw/master/Screenshot-iphone.png)

How to Use
----------

Move the globe around by dragging with your finger. You can flick the globe to spin it further. Zoom in and out using a pinch gesture, or by double-tapping. Tilt or rotate the globe by dragging a finger along the right or bottom edges of the screen, respectively.

There is currently no way to select which map layer is displayed at runtime. See DRAppDelegate.m to select which hardcoded layer is used.

About the Author
----------------

I build advanced airborne 3D imagers at my day job, which leaves me with the creative itch to build something a bit more tactile in my free time. Feel free to contact me at my e-mail (ross.w.anderson@gmail.com) if you have questions, comments, or an interesting business opportunity. Let me know if you use EarthView in your app!

License
-------

The overall license for this project is BSD. TPPropertyAnimation by Michael Tyson is also BSD licensed and is included in the Source folder. Please see the license file for specific rights and restrictions.

Requirements and Dependancies
-----------------------------

This project has no dependencies beyond the iOS 5 SDK. It has been tested to work correctly on an iPad (3rd generation) and iPhone 4.

The example application connects to various map tile services over the web such as MapBox or OpenSteetMap as defined in DRAppDelegate.m. There is no local data stored with the application, so an Internet connection on your device is required.

Bugs and Limitations
--------------------

- The light position lags by 1 frame for some reason.
- There are holes in the globe at the poles because there is no map tile content there.
- The tilt control should bounce when you hit the hard stops.
- Add support for MBTiles (http://mapbox.com/mbtiles-spec/) for locally stored/cached content.
