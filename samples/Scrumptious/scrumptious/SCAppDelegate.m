/*
 * Copyright 2012 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <FBiOSSDK/FacebookSDK.h>
#import "SCAppDelegate.h"
#import "SCViewController.h"
#import "SCLoginViewController.h"

NSString *const SCSessionStateChangedNotification = @"com.facebook.Scrumptious:SCSessionStateChangedNotification";

@interface SCAppDelegate ()

@property (strong, nonatomic) UINavigationController *navController;
@property (strong, nonatomic) SCViewController *mainViewController;

- (FBSession*)createNewSession;
- (void)showLoginViewWithError:(BOOL)error;

@end

@implementation SCAppDelegate

@synthesize window = _window;
@synthesize mainViewController = _viewController;
@synthesize navController = _navController;

#pragma mark -
#pragma mark Facebook Login Code

- (void)showLoginViewWithError:(BOOL)error {
    UIViewController *topViewController = [self.navController topViewController];
    UIViewController *modalViewController = [topViewController modalViewController];
    
    // FBSample logic
    // If the login screen is not already displayed, display it. If we got an error, notify
    // the controller.
    if (![modalViewController isKindOfClass:[SCLoginViewController class]]) {
        SCLoginViewController* loginViewController = [[SCLoginViewController alloc]initWithNibName:@"SCLoginViewController" 
                                                                                            bundle:nil];
        [topViewController presentModalViewController:loginViewController animated:NO];
    } 
    if (error) {
        SCLoginViewController* loginViewController = (SCLoginViewController*)modalViewController;
        [loginViewController loginFailed];
    }
}

- (void)sessionStateChanged:(FBSession *)session 
                      state:(FBSessionState)state
                      error:(NSError *)error
{
    // FBSample logic
    // Any time the session is closed, we want to display the login controller (the user
    // cannot use the application unless they are logged in to Facebook). When the session
    // is opened successfully, hide the login controller and show the main UI.
    switch (state) {
        case FBSessionStateOpen: {
                UIViewController *topViewController = [self.navController topViewController];
                if ([[topViewController modalViewController] isKindOfClass:[SCLoginViewController class]]) {
                    [topViewController dismissModalViewControllerAnimated:YES];
                }
                
                // FBSample logic
                // Pre-fetch and cache the friends for the friend picker as soon as possible
                FBCacheDescriptor *cacheDescriptor = [FBFriendPickerViewController cacheDescriptor];
                [cacheDescriptor prefetchAndCacheForSession:session];
            }
            break;
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            // FBSample logic
            // Once the user has logged in, we want them to be looking at the root view.
            [self.navController popToRootViewControllerAnimated:NO];
            
            [FBSession.activeSession closeAndClearTokenInformation];
            
            [self showLoginViewWithError:(state == FBSessionStateClosedLoginFailed)];
            break;
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SCSessionStateChangedNotification 
                                                        object:session];
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }    
}

- (void)openSession {
    NSArray *permissions = [NSArray arrayWithObjects:@"publish_actions", @"user_photos", nil];
    [FBSession sessionOpenWithPermissions:permissions completionHandler:
     ^(FBSession *session, FBSessionState state, NSError *error) {
         [self sessionStateChanged:session state:state error:error];
     }];    
}

- (BOOL)application:(UIApplication *)application 
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication 
         annotation:(id)annotation {
    // FBSample logic
    // We need to handle URLs by passing them to FBSession in order for SSO authentication
    // to work.
    return [FBSession.activeSession handleOpenURL:url]; 
}

- (void)applicationDidBecomeActive:(UIApplication *)application	{	
    // this means the user switched back to this app without completing a login in Safari/Facebook App
    if (FBSession.activeSession.state == FBSessionStateCreatedOpening) {	
        [FBSession.activeSession close]; // so we close our session and start over	
    }	
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // BUG WORKAROUND:
    // Nib files require the type to have been loaded before they can do the
    // wireup successfully.  
    // http://stackoverflow.com/questions/1725881/unknown-class-myclass-in-interface-builder-file-error-at-runtime
    [FBProfilePictureView class];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.mainViewController = [[SCViewController alloc] initWithNibName:@"SCViewController" bundle:nil];
    self.navController = [[UINavigationController alloc]initWithRootViewController:self.mainViewController];
    self.window.rootViewController = self.navController;
    
    [self.window makeKeyAndVisible];
    
    // FBSample logic
    // See if we have a valid token for the current state.
    if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
        // Yes, so just open the session (this won't display any UX).
        [self openSession];
    } else {
        // No, display the login page.
        [self showLoginViewWithError:NO];
    }
    
    return YES;
}

@end
