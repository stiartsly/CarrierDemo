import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
//    var backgroundTaskIdentifier : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        application.isIdleTimerDisabled = true
        
        let navigationController = self.window!.rootViewController as! UINavigationController
        let splitViewController = navigationController.viewControllers[0] as! UISplitViewController
        splitViewController.preferredDisplayMode = .allVisible
        splitViewController.delegate = self
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
//        self.backgroundTaskIdentifier = application.beginBackgroundTask(expirationHandler: {
//            application.endBackgroundTask(self.backgroundTaskIdentifier)
//            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
//        })
//        
//        if self.backgroundTaskIdentifier != UIBackgroundTaskInvalid {
//            // Do something
//            application.endBackgroundTask(self.backgroundTaskIdentifier)
//            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
//        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
//        if self.backgroundTaskIdentifier != UIBackgroundTaskInvalid {
//            application.endBackgroundTask(self.backgroundTaskIdentifier)
//            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
//        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let primaryNavController = primaryViewController as? UINavigationController else { return false }
        guard let primaryTableController = primaryNavController.topViewController as? UITableViewController else { return false }
        
        if primaryTableController.tableView.indexPathForSelectedRow == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        
        return false
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        var detailVC = primaryViewController.separateSecondaryViewController(for: splitViewController)
        
        if detailVC == nil {
            guard let primaryNavController = primaryViewController as? UINavigationController else { return nil }
            guard let primaryTableController = primaryNavController.topViewController as? UITableViewController else { return nil }
            primaryTableController.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
            
            detailVC = splitViewController.storyboard!.instantiateViewController(withIdentifier: "detailVC")
        }
        
        return detailVC
    }
}

