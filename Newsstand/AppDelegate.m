//
//  AppDelegate.m
//  Newsstand
//
//  Created by Carlo Vigiani on 17/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "AppDelegate.h"
#import "StoreViewController.h"
#import <NewsstandKit/NewsstandKit.h>
#import <UAirship.h>
#import <UAPush.h>

@implementation AppDelegate

@synthesize window = _window;
@synthesize store;

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

-(void)setupPushWithOptions:(NSDictionary *)launchOptions {
    
#warning   SETUP YOUR PUSH NOTIFICATIONS
    //URBAN AIRSHIP PUSH NOTIFICATION CONFIGURATION
    //Init Airship launch options
    NSMutableDictionary *airshipConfigOptions = [[[NSMutableDictionary alloc] init] autorelease];
    [airshipConfigOptions setValue:@"YOUR DEVELOPMENT APP KEY" forKey:@"DEVELOPMENT_APP_KEY"];
    [airshipConfigOptions setValue:@"YOUR DEVELOPMENT APP SECRECT" forKey:@"DEVELOPMENT_APP_SECRET"];
    //[airshipConfigOptions setValue:@"Your production app key" forKey:@"PRODUCTION_APP_KEY"];
    //[airshipConfigOptions setValue:@"Your production app secret" forKey:@"PRODUCTION_APP_SECRET"];
    
#ifdef DEBUG
    [airshipConfigOptions setValue:@"NO" forKey:@"APP_STORE_OR_AD_HOC_BUILD"];
#else
    [airshipConfigOptions setValue:@"YES" forKey:@"APP_STORE_OR_AD_HOC_BUILD"];
#endif
    
    NSMutableDictionary *takeOffOptions = [[[NSMutableDictionary alloc] init] autorelease];
    [takeOffOptions setValue:launchOptions forKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    [takeOffOptions setValue:airshipConfigOptions forKey:UAirshipTakeOffOptionsAirshipConfigKey];    
    
    // Create Airship singleton that's used to talk to Urban Airship servers.
    // Please replace these with your info from http://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];
    
    [[UAPush shared] resetBadge];//zero badge on startup    
    [[UAPush shared] registerForRemoteNotificationTypes:UIRemoteNotificationTypeNewsstandContentAvailability|UIRemoteNotificationTypeAlert]; // register for Newsstand and Alerts
    
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // allows more than one new content notification per day (development)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NKDontThrottleNewsstandContentNotifications"];
    
    NSLog(@"LAUNCH OPTIONS = %@",launchOptions);
    
    // initialize the Store view controller - required for all Newsstand functionality
    self.store = [[[StoreViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    nav = [[UINavigationController alloc] initWithRootViewController:store];
 
    // StoreKit transaction observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self.store];
    //[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
    // check if the application will run in background after being called by a push notification
    NSDictionary *payload = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    //if(payload && [payload objectForKey:@"content-available"]) {
    if(payload) {
        // schedule for issue downloading in background
        // in this tutorial we hard-code background download of magazine-2, but normally the magazine to be downloaded
        // has to be provided in the push notification custom payload
        NKIssue *issue4 = [[NKLibrary sharedLibrary] issueWithName:@"Magazine-2"];
        if(issue4) {
            NSURL *downloadURL = [NSURL URLWithString:@"http://www.viggiosoft.com/media/data/blog/newsstand/magazine-2.pdf"];
            NSURLRequest *req = [NSURLRequest requestWithURL:downloadURL];
            NKAssetDownload *assetDownload = [issue4 addAssetWithRequest:req];
            [assetDownload downloadWithDelegate:store];
        }
        
    }
    
    
    // setup the window
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window addSubview:nav.view];
    [self.window makeKeyAndVisible];
    
    // when the app is relaunched, it is better to restore pending downloading assets as abandoned downloadings will be cancelled
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    for(NKAssetDownload *asset in [nkLib downloadingAssets]) {
        NSLog(@"Asset to downlaod: %@",asset);
        [asset downloadWithDelegate:store];            
    }
    
    [self setupPushWithOptions:launchOptions];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *deviceTokenString = [[[[deviceToken description]
                                     stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                    stringByReplacingOccurrencesOfString: @">" withString: @""]
                                   stringByReplacingOccurrencesOfString: @" " withString: @""];    
    NSLog(@"Registered with device token: %@",deviceTokenString);
    [[UAPush shared] registerDeviceToken:deviceToken]; 
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Failing in APNS registration: %@",error);
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    UALOG(@"Received remote notification: %@", userInfo);
    
    /*
    [[UAPush shared] handleNotification:userInfo applicationState:application.applicationState];
    [[UAPush shared] resetBadge]; // zero badge after push received   
    */
    
    // Now check if it is new content; if so we show an alert
    if([userInfo objectForKey:@"content-available"]) {
        if([[UIApplication sharedApplication] applicationState]==UIApplicationStateActive) {
            // active app -> display an alert
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New issue!"
                                                            message:@"There is a new issue available."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Close"
                                                  otherButtonTitles:nil];
            [alert show];
            [alert release];            
        } else {
            // inactive app -> do something else (e.g. download the latest issue)
        }
    }
}

@end
