//
//  TouchHeatmapRenderer.swift
//  TouchHeatmap
//
//  Created by Christopher Helf on 29.09.15.
//  Copyright © 2015 Christopher Helf. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

class TouchHeatmapRenderer {
    
    class func renderTouches(image: UIImage, touches: [TouchHeatmap.Touch]) -> (UIImage,Bool) {
        
        // Size variables
        let size = image.size
        let width = size.width
        let height = size.height
        let touchradius : CGFloat = 70.0

        // Create the Density Matrix
        let count = Int(width*height)
        var density = [Float](count: count, repeatedValue: 0.0)
        var touchDensity = self.createTouchSquare(touchradius)
        
        // Iterate through all touches
        for touch in touches {
            
            // Add the touch square at the touch location
            self.addTouchSquareToDensity(&density, width: Int(width), height: Int(height), touchDensity: &touchDensity, radius: Int(touchradius), center: touch.point)
        }
        
        // Normalize between zero and one
        let maxDensity = max(density)
        
        // Density Check if we have no touches
        if maxDensity == 0.0 {
            return (image,false)
        }
        
        // Create the RGBA matrix
        var rgba = [UInt8](count: count*4, repeatedValue: 0)
        
        // Render Density Info into raw RGBA pixels
        self.renderDensityMatrix(&density, rgba: &rgba, width: Int(width), height: Int(height), max: maxDensity)
        
        // Clear matrices
        density.removeAll()
        touchDensity.removeAll()
        
        // Generate UIImage from RGB data
        let touchImage = self.generateImageFromRGBAMatrix(&rgba, width: Int(width), height: Int(height))
        return (touchImage,true)
    }
    
    private class func generateImageFromRGBAMatrix(inout rgba: [UInt8], width: Int, height: Int) -> UIImage {
        
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrderDefault.rawValue)
        
        let bitmapContext = CGBitmapContextCreate(&rgba,
            width,
            height,
            8, // bitsPerComponent
            4 * width, // bytesPerRow
            colorSpace,
            bitmapInfo.rawValue);
        
        let cgImage = CGBitmapContextCreateImage(bitmapContext);
        let image = UIImage(CGImage: cgImage!)
        return image
    }
    
    private class func renderDensityMatrix(inout density: [Float], inout rgba: [UInt8], width: Int, height: Int, max: Float) {
        
        let bytesPerRow = 4 * width
        
        for(var x = 0; x < width; x++) {
            for(var y = 0; y < height; y++) {
                
                // Get the density index
                let densityIndex = width * y + x
                
                // Get the density value and normalize
                let densityValue = density[densityIndex] / max
                
                // Do not do anything if we have zero
                guard densityValue > 0 else {
                    continue
                }
                
                // Get the Byteindex of the rgba data
                let byteIndex = (bytesPerRow * y) + x * 4
                
                // Set the color values     
                rgba[byteIndex] = UInt8(densityValue * 255)
                rgba[byteIndex+3] = rgba[byteIndex]
                
                // Green component
                if (densityValue >= 0.75) {
                    rgba[byteIndex+1] = rgba[byteIndex];
                } else if (densityValue >= 0.5) {
                    rgba[byteIndex+1] = UInt8((densityValue - 0.5) * 255 * 3);
                }
                
                // Blue component
                if (densityValue >= 0.8) {
                    rgba[byteIndex+2] = UInt8((densityValue - 0.8) * 255 * 5);
                }
            }
        }
        
        
        
    }
    
    private class func max(x: [Float]) -> Float {
        var result: Float = 0.0
        vDSP_maxv(x, 1, &result, vDSP_Length(x.count))
        return result
    }
    
    private class func min(x: [Float]) -> Float {
        var result: Float = 0.0
        vDSP_minv(x, 1, &result, vDSP_Length(x.count))
        return result
    }
    
    private class func addTouchSquareToDensity(inout density: [Float], width: Int, height: Int, inout touchDensity: [Float], radius: Int, center: CGPoint) {
        
        let centerX = Int(center.x)
        let centerY = Int(center.y)
        
        for(var x = 0; x < radius; x++) {
            for(var y = 0; y < radius; y++) {
                
                let densityX = centerX - radius/2 + x
                let densityY = centerY - radius/2 + y
                
                // Check whether we are within the image
                guard (densityX >= 0 && densityX < width && densityY >= 0 && densityY < height) else {
                    continue
                }
                
                // Add the Density
                let densityIndex = width * densityY + densityX
                let touchSquareIndex = radius * y + x
                
                let densityValue = touchDensity[touchSquareIndex]
                
                density[densityIndex] += densityValue

            }
        }
    }
    
    private class func createTouchSquare(radius: CGFloat) -> [Float] {
        
        // Input parameters for CIGaussianGradient
        let center = CIVector(x: radius/2, y: radius/2)
        let centerColor = CIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let outerColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        // First create the Gradient
        var parameters = [String : AnyObject]()
        parameters["inputCenter"] = center
        parameters["inputColor0"] = centerColor
        parameters["inputColor1"] = outerColor
        parameters["inputRadius"] = radius-radius/2 as NSNumber
        
        let filter = CIFilter(name: "CIGaussianGradient", withInputParameters: parameters)!
        var ciImage = filter.outputImage!
        
        // Now crop, as we have infinite dimensions
        let cropRect = CGRectMake(0.0, 0.0, radius, radius);
        var cropParameters = [String : AnyObject]()
        cropParameters["inputImage"] = ciImage
        cropParameters["inputRectangle"] = CIVector(CGRect: cropRect)
        ciImage = CIFilter(name: "CICrop", withInputParameters: cropParameters)!.outputImage!
        
        // Create the CGImage
        let ctx = CIContext(options:nil)
        let cgImage = ctx.createCGImage(ciImage, fromRect:ciImage.extent)
        
        // Get the Pixel Data
        let pixelData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage))
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        // Set the Pixel Data in the Array
        let radiusInt = Int(radius)
        let count = radius*radius
        var density = [Float](count: Int(count), repeatedValue: 0.0)
        
        for(var x = 0; x < radiusInt; x++) {
            for(var y = 0; y < radiusInt; y++) {
                
                // Get the Pixel Info in the Red Channel
                let pixelInfo: Int = ((radiusInt * y) + x) * 4
                let r = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
                
                // Set it in the Density Matrix
                let pos : Int = (radiusInt * y) + x
                density[pos] = Float(r)
                
            }
        }
        
        return density
        
    }
    
    
}