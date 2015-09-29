# TouchHeatmap

This repository contains a iOS project written in Swift 2.0 in order to create Touch-Heatmaps for applications. The Example folder contains a XCode example project, the Source folder contains all the necessary source files. 

All you have to do is call a static function of the TouchHeatmap object

```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    TouchHeatmap.start()
    return true
}
```

Below are two example screenshots

<img src="https://raw.github.com/christopherhelf/TouchHeatmap/master/Images/screen1.png" width="400">
<img src="https://raw.github.com/christopherhelf/TouchHeatmap/master/Images/screen2.png" width="400">




