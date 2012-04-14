//
//  DRAppDelegate.m
//  EarthViewExample
//
//  Created by Ross Anderson on 4/14/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "DRAppDelegate.h"

#import "RASceneGraphController.h"

#define SAMPLE_DATASET 4


@implementation DRAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[RASceneGraphController alloc] initWithNibName:@"SceneView_iPhone" bundle:nil];
    } else {
        self.viewController = [[RASceneGraphController alloc] initWithNibName:@"SceneView_iPad" bundle:nil];
    }
    
    // setup the tile set used
    RATileDatabase * database = self.viewController.database;
    switch( SAMPLE_DATASET ) {
        case 1:
            // Sample database from: http://a.tiles.mapbox.com/v3/mapbox.blue-marble-topo-jul-bw.jsonp
            database.baseUrlString = @"http://a.tiles.mapbox.com/v3/mapbox.blue-marble-topo-jul-bw/{z}/{x}/{y}.png";
            database.maxzoom = 8;
            break;
        case 2:
            // Sample database from: http://a.tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul.jsonp
            database.baseUrlString = @"http://a.tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul/{z}/{x}/{y}.png";
            database.maxzoom = 8;
            break;
        case 3:
            // OpenStreetMap
            database.baseUrlString = @"http://c.tile.openstreetmap.org/{z}/{x}/{y}.png";
            database.maxzoom = 18;
            break;
        case 4:
            // MapBox Streets
            database.baseUrlString = @"http://b.tiles.mapbox.com/v3/mapbox.mapbox-streets/{z}/{x}/{y}.png";
            database.maxzoom = 17;
            break;
        case 5:
        default:
            // Stamen Maps Watercolor - http://maps.stamen.com/watercolor
            database.baseUrlString = @"http://tile.stamen.com/watercolor/{z}/{x}/{y}.png";
            database.maxzoom = 17;
    }
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
