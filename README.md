# TouchHeatmap

This repository contains a iOS project written in Swift 2.0 in order to create Touch-Heatmaps for applications. The Example folder contains a XCode example project, the Source folder contains all the necessary source files. Simply drag and drop them into your project.

All you then have to do is call a static function of the TouchHeatmap object

```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    TouchHeatmap.start()
    return true
}
```

Right now, rendered images are stored to the camera roll of the simulator/device when the app is put into background. This could also be replaced by a function to send it to a remote REST api for instance. This implementation hooks into UIApplication and UIViewController and overwrites the ```sendEvent``` and ```viewDidAppear``` method in order to track touches and notify the TouchHeatmap object when a new screenshot is necessary. It also tracks which controllers are opened in terms of sequence, although there is currently no visualization of this feature. Furthermore, right now screens that have no touches are not rendered to the camera roll.

This project was meant as a test and might contain bugs etc., as it is not actively maintained. Please use at your own risk. 

Below are two example screenshots

Screenshot1             |  Screenshot2
:-------------------------:|:-------------------------:
![](https://raw.github.com/christopherhelf/TouchHeatmap/master/Images/screen1.png)  |  ![](https://raw.github.com/christopherhelf/TouchHeatmap/master/Images/screen2.png)




