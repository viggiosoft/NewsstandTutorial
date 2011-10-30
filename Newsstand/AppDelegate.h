//
//  AppDelegate.h
//  Newsstand
//
//  Created by Carlo Vigiani on 17/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@class StoreViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    UINavigationController *nav;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) StoreViewController *store;

@end
