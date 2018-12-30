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

extension CGImage {
    func colors(at: [CGPoint]) -> [UIColor]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo),
            let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
        }
        
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return at.map { p in
            let i = bytesPerRow * Int(p.y) + bytesPerPixel * Int(p.x)
            
            let a = CGFloat(ptr[i + 3]) / 255.0
            let r = (CGFloat(ptr[i]) / a) / 255.0
            let g = (CGFloat(ptr[i + 1]) / a) / 255.0
            let b = (CGFloat(ptr[i + 2]) / a) / 255.0
            
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
    }
}

class TouchHeatmapRenderer {
    
    class func renderTouches(image: UIImage, touches: [TouchHeatmap.Touch]) -> (UIImage,Bool) {
        
        // Size variables
        let size = image.size
        let width = size.width
        let height = size.height
        let touchradius : CGFloat = 70.0

        // Create the Density Matrix
        let count = Int(width*height)
        var density = [Float](repeating: 0.0, count: count)
        var touchDensity = self.createTouchSquare(radius: touchradius)
        
        // Iterate through all touches
        for touch in touches {
            
            // Add the touch square at the touch location
            self.addTouchSquareToDensity(density: &density, width: Int(width), height: Int(height), touchDensity: &touchDensity, radius: Int(touchradius), center: touch.point)
        }
        
        // Normalize between zero and one
        let maxDensity = max(x: density)
        
        // Density Check if we have no touches
        if maxDensity == 0.0 {
            return (image,false)
        }
        
        // Create the RGBA matrix
        var rgba = [UInt8](repeating: 0, count: count*4)
        
        // Render Density Info into raw RGBA pixels
        self.renderDensityMatrix(density: &density, rgba: &rgba, width: Int(width), height: Int(height), max: maxDensity)
        
        // Clear matrices
        density.removeAll()
        touchDensity.removeAll()
        
        // Generate UIImage from RGB data
        let touchImage = self.generateImageFromRGBAMatrix(rgba: &rgba, width: Int(width), height: Int(height))
        return (touchImage,true)
    }
    
    private class func generateImageFromRGBAMatrix( rgba: inout [UInt8], width: Int, height: Int) -> UIImage {
        
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let bitmapContext = CGContext(data: &rgba,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8, // bitsPerComponent
            bytesPerRow: 4 * width, // bytesPerRow
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue);
        
        let cgImage = bitmapContext!.makeImage();
        let image = UIImage(cgImage: cgImage!)
        return image
    }
    
    private class func renderDensityMatrix( density: inout [Float], rgba: inout [UInt8], width: Int, height: Int, max: Float) {
        
        let bytesPerRow = 4 * width
        
        for x in stride(from: 0, to: width, by: 1) {
            for y in stride(from: 0, to: height, by: 1) {
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
    
    private class func addTouchSquareToDensity( density: inout [Float], width: Int, height: Int, touchDensity: inout [Float], radius: Int, center: CGPoint) {
        
        let centerX = Int(center.x)
        let centerY = Int(center.y)
        
        for x in stride(from: 0, to: radius, by: 1) {
            for y in stride(from: 0, to: radius, by: 1) {

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
        
        let filter = CIFilter(name: "CIGaussianGradient", parameters: parameters)!
        var ciImage = filter.outputImage!
        
        // Now crop, as we have infinite dimensions
        let cropRect = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: radius, height: radius))
        var cropParameters = [String : AnyObject]()
        cropParameters["inputImage"] = ciImage
        cropParameters["inputRectangle"] = CIVector(cgRect: cropRect)
        ciImage = CIFilter(name: "CICrop", parameters: cropParameters)!.outputImage!
        
        // Create the CGImage
        let ctx = CIContext(options:nil)
        let cgImage = ctx.createCGImage(ciImage, from:ciImage.extent)
        
        // Get the Pixel Data //
        let pixelData = cgImage?.dataProvider?.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
                
        // Set the Pixel Data in the Array
        let radiusInt = Int(radius)
        let count = radius*radius
        var density = [Float](repeating: 0.0, count: Int(count))
        
        for x in stride(from: 0, to: radiusInt, by: 1) {
            for y in stride(from: 0, to: radiusInt, by: 1) {

                
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
