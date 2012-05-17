//
//  DRAppDelegate.m
//  EarthViewExample
//
//  Created by Ross Anderson on 4/14/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "DRAppDelegate.h"

#import "RASceneGraphController.h"

// NOTICE:
// The imagery tile sets below are for example use only. Please consult with the 
// individual copyright holder of each tile set before using it in your app. The
// Dancing Robots tile sets (the defaults below) may not be used in your own 
// app without permission.
#define IMAGERY_DATASET 1
#define TERRAIN_DATASET 1


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
    
    // allow caching for tile images
    [[NSURLCache sharedURLCache] setMemoryCapacity:4*1024*1024];
    [[NSURLCache sharedURLCache] setDiskCapacity:128*1024*1024];
    
    // setup the tile set used
    RATileDatabase * database = [RATileDatabase new];
    database.bounds = CGRectMake( -180,-90,360,180 );
    database.googleTileConvention = YES;
    database.minzoom = 2;
    
    switch( IMAGERY_DATASET ) {
        case 1:
            if ( [[UIScreen mainScreen] scale] > 1.5 ) {
                NSLog(@"Retina");
                // Dancing Robots Streets Retina: https://tiles.mapbox.com/v3/dancingrobots.map-lqzbpv0l.jsonp
                database.baseUrlStrings = [NSArray arrayWithObjects:
                   @"http://a.tiles.mapbox.com/v3/dancingrobots.map-lqzbpv0l/{z}/{x}/{y}.png",
                   @"http://b.tiles.mapbox.com/v3/dancingrobots.map-lqzbpv0l/{z}/{x}/{y}.png",
                   @"http://c.tiles.mapbox.com/v3/dancingrobots.map-lqzbpv0l/{z}/{x}/{y}.png",
                   @"http://d.tiles.mapbox.com/v3/dancingrobots.map-lqzbpv0l/{z}/{x}/{y}.png",
                   nil];
            } else {
                // Dancing Robots Streets: https://tiles.mapbox.com/v3/dancingrobots.map-zlkx39ti.jsonp
                database.baseUrlStrings = [NSArray arrayWithObjects:
                   @"http://a.tiles.mapbox.com/v3/dancingrobots.map-zlkx39ti/{z}/{x}/{y}.png",
                   @"http://b.tiles.mapbox.com/v3/dancingrobots.map-zlkx39ti/{z}/{x}/{y}.png",
                   @"http://c.tiles.mapbox.com/v3/dancingrobots.map-zlkx39ti/{z}/{x}/{y}.png",
                   @"http://d.tiles.mapbox.com/v3/dancingrobots.map-zlkx39ti/{z}/{x}/{y}.png",
                   nil];
            }
            database.maxzoom = 17;
            break;
            
        case 2:
            // MapBox Streets: http://tiles.mapbox.com/v3/mapbox.mapbox-streets.jsonp
            database.baseUrlStrings = [NSArray arrayWithObjects:
                                       @"http://a.tiles.mapbox.com/v3/mapbox.mapbox-streets/{z}/{x}/{y}.png",
                                       @"http://b.tiles.mapbox.com/v3/mapbox.mapbox-streets/{z}/{x}/{y}.png",
                                       @"http://c.tiles.mapbox.com/v3/mapbox.mapbox-streets/{z}/{x}/{y}.png",
                                       @"http://d.tiles.mapbox.com/v3/mapbox.mapbox-streets/{z}/{x}/{y}.png",
                                       nil];
            database.maxzoom = 17;
            break;
            
        case 3:
            // Sample database from: http://tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul.jsonp
            database.baseUrlStrings = [NSArray arrayWithObjects:
               @"http://a.tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul/{z}/{x}/{y}.png",
               @"http://b.tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul/{z}/{x}/{y}.png",
               @"http://c.tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul/{z}/{x}/{y}.png",
               @"http://d.tiles.mapbox.com/v3/mapbox.blue-marble-topo-bathy-jul/{z}/{x}/{y}.png",
               nil];
            database.maxzoom = 8;
            break;
            
        case 4:
            // OpenStreetMap
            database.baseUrlStrings = [NSArray arrayWithObjects:
               @"http://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
               @"http://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
               @"http://c.tile.openstreetmap.org/{z}/{x}/{y}.png",
               nil];
            database.maxzoom = 18;
            break;
            
        case 5:
            // Stamen Maps Watercolor - http://maps.stamen.com/watercolor
            database.baseUrlStrings = [NSArray arrayWithObjects:
                @"http://a.tile.stamen.com/watercolor/{z}/{x}/{y}.png",
                @"http://b.tile.stamen.com/watercolor/{z}/{x}/{y}.png",
                @"http://c.tile.stamen.com/watercolor/{z}/{x}/{y}.png",
                nil];
            database.maxzoom = 17;
            break;
            
        default:
            database = nil;
            break;
    }
    self.viewController.pager.imageryDatabase = database;
    
    // setup height tile dataset
    database = [RATileDatabase new];
    database.bounds = CGRectMake( -180,-90,360,180 );
    database.googleTileConvention = YES;
    database.minzoom = 2;
    
    switch ( TERRAIN_DATASET ) {
        case 1:
            // Dancing Robots Topography: http://a.tiles.mapbox.com/v3/dancingrobots.globe-topo.json
            // Based on NOAA GLOBE dataset: http://www.ngdc.noaa.gov/mgg/topo/gltiles.html
            database.baseUrlStrings = [NSArray arrayWithObjects:
                @"http://a.tiles.mapbox.com/v3/dancingrobots.globe-topo/{z}/{x}/{y}.png",
                @"http://b.tiles.mapbox.com/v3/dancingrobots.globe-topo/{z}/{x}/{y}.png",
                @"http://c.tiles.mapbox.com/v3/dancingrobots.globe-topo/{z}/{x}/{y}.png",
                @"http://d.tiles.mapbox.com/v3/dancingrobots.globe-topo/{z}/{x}/{y}.png",
                nil];
            database.maxzoom = 8;
            break;
            
        default:
            database = nil;
            break;
    }
    self.viewController.pager.terrainDatabase = database;
    
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
