class AppDelegate
  def application(application, didFinishLaunchingWithOptions:launchOptions)
    welcomeViewController = AVCamViewController.alloc.init #WithNibName('WelcomeViewController', bundle:nil)
    navController = UINavigationController.alloc.initWithRootViewController(welcomeViewController)
    @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    @window.rootViewController = navController
    @window.makeKeyAndVisible

    true
  end
end
