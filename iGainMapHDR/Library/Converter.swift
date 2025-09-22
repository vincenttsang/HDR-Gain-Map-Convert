//
//  Converter.swift
//  HDR Gain Map Convert
//
//  Created by Vincent Tsang on 21/11/2024.
//

//
//  main.swift
//  PQHDR_to_GainMapHDR
//  This code will convert PQ HDR file to luminance gain map HDR heic file.
//
//  Created by Luyao Peng on 2024/9/27.
//

import CoreImage
import Foundation
import CoreImage.CIFilterBuiltins

class Converter {
    var src: String
    var dest: String
    var imageQuality: Double
    var colorSpace: String
    var colorDepth: Int
    var SDR: Bool
    var PQ: Bool
    var HLG: Bool
    var MonoGainMap: Bool
    /**
     * outputType: 0: HEIF, 1: JPEG, 2: PNG, 3: TIFF
     */
    var outputType: Int
    
    // Shared context for better resource management
    private static let sharedContext: CIContext = {
        // Create context with safe options - avoid problematic outputColorSpace
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false
        ]
        return CIContext(options: options)
    }()
    
    init(
        src: String, dest: String, imageQuality: Double, colorSpace: String, colorDepth: Int,
        SDR: Bool, PQ: Bool, HLG: Bool, Google: Bool, outputType: Int
    ) {
        self.src = src
        self.dest = dest
        self.imageQuality = imageQuality
        self.colorSpace = colorSpace
        self.colorDepth = colorDepth
        self.SDR = SDR
        self.PQ = PQ
        self.HLG = HLG
        self.MonoGainMap = Google
        self.outputType = outputType
    }
    
    deinit {
        // Ensure cleanup of any retained resources
        // The shared context will handle its own cleanup
    }
    
    func convert() -> Int {
        if MonoGainMap {
            return self.convertMonoGainMap()
        } else {
            return self.convertDefault()
        }
    }
    
    private func getFileName(url: URL) -> String {
        switch self.outputType {
        case 0:
            return url.deletingPathExtension().appendingPathExtension("HEIC")
                .lastPathComponent
        case 1:
            return url.deletingPathExtension().appendingPathExtension("JPG")
                .lastPathComponent
        case 2:
            return url.deletingPathExtension().appendingPathExtension("PNG")
                .lastPathComponent
        case 3:
            return url.deletingPathExtension().appendingPathExtension("TIFF")
                .lastPathComponent
        default:
            return url.lastPathComponent
        }
    }
    
    private func convertDefault() -> Int {
        let ctx = Converter.sharedContext // Use shared context for better resource management
        
        let url_hdr = URL(fileURLWithPath: self.src)
        let filename = self.getFileName(url: url_hdr)
        let path_export = URL(fileURLWithPath: self.dest)
        let url_export_image = path_export.appendingPathComponent(filename)
        //let imageoptions
        
        var imagequality: Double? = 0.85
        var sdr_export: Bool = false
        var pq_export: Bool = false
        var hlg_export: Bool = false
        var bit_depth = CIFormat.RGBA8
        
        let hdr_image = CIImage(contentsOf: url_hdr, options: [.expandToHDR: true])
        let tonemapped_sdrimage = hdr_image?.applyingFilter(
            "CIToneMapHeadroom", parameters: ["inputTargetHeadroom": 1.0])
        let export_options = NSDictionary(dictionary: [
            kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.85,
            CIImageRepresentationOption.hdrImage: hdr_image!,
        ])
        
        var sdr_color_space = CGColorSpace.displayP3
        var hdr_color_space = CGColorSpace.displayP3_PQ
        var hlg_color_space = CGColorSpace.displayP3_HLG
        
        let image_color_space = String(describing: hdr_image?.colorSpace)
        
        if image_color_space.contains("709") {
            sdr_color_space = CGColorSpace.itur_709
            hdr_color_space = CGColorSpace.itur_709_PQ
            hlg_color_space = CGColorSpace.itur_709_HLG
        }
        if image_color_space.contains("sRGB") {
            sdr_color_space = CGColorSpace.itur_709
            hdr_color_space = CGColorSpace.itur_709_PQ
            hlg_color_space = CGColorSpace.itur_709_HLG
        }
        if image_color_space.contains("2100") {
            sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
            hdr_color_space = CGColorSpace.itur_2100_PQ
            hlg_color_space = CGColorSpace.itur_2100_HLG
        }
        if image_color_space.contains("2020") {
            sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
            hdr_color_space = CGColorSpace.itur_2100_PQ
            hlg_color_space = CGColorSpace.itur_2100_HLG
        }
        if image_color_space.contains("Adobe RGB") {
            sdr_color_space = CGColorSpace.adobeRGB1998
            hdr_color_space = CGColorSpace.adobeRGB1998
            hlg_color_space = CGColorSpace.adobeRGB1998
        }
        
        
        if self.imageQuality > 1 {
            imagequality = self.imageQuality / 100
        } else {
            imagequality = self.imageQuality
        }
        
        if self.SDR {
            if self.PQ || self.HLG {
                debugPrint("Error: Only one type of export can be specified.")
                return -1
            }
            sdr_export = true
        }
        
        if self.PQ {
            if self.SDR || self.HLG {
                debugPrint("Error: Only one type of export can be specified.")
                return -1
            }
            pq_export = true
        }
        
        if self.HLG {
            if self.SDR || self.PQ {
                debugPrint("Error: Only one type of export can be specified.")
                return -1
            }
            hlg_export = true
        }
        
        if self.colorDepth == 10 {
            bit_depth = CIFormat.RGB10
        }
        
        if self.colorDepth == 16 {
            bit_depth = CIFormat.RGBX16
        }
        
        switch self.colorSpace {
        case "srgb", "709", "rec709", "rec.709", "bt709", "bt,709", "itu709", "sRGB":
            sdr_color_space = CGColorSpace.itur_709
            hdr_color_space = CGColorSpace.itur_709_PQ
            hlg_color_space = CGColorSpace.itur_709_HLG
        case "p3", "dcip3", "dci-p3", "dci.p3", "displayp3", "P3":
            sdr_color_space = CGColorSpace.displayP3
            hdr_color_space = CGColorSpace.displayP3_PQ
            hlg_color_space = CGColorSpace.displayP3_HLG
        case "rec2020", "2020", "rec.2020", "bt2020", "itu2020", "2100", "rec2100", "rec.2100",
            "Rec. 2020":
            sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
            hdr_color_space = CGColorSpace.itur_2100_PQ
            hlg_color_space = CGColorSpace.itur_2100_HLG
        default:
            debugPrint(
                "Error: The colorSpace argument requires color space argument. (srgb, p3, rec2020)")
        }
        
        while sdr_export {
            let sdr_export_options = NSDictionary(dictionary: [
                kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.90
            ])
            switch self.outputType {
            case 0:
                do {
                    try ctx.writeHEIFRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     format: bit_depth,
                                                     colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                     options: sdr_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing SDR HEIF: \(error)")
                    return -1
                }
            case 1:
                do {
                    try ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                     options: sdr_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing SDR JPEG: \(error)")
                    return -1
                }
            case 2:
                do {
                    try ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                    to: url_export_image,
                                                    format: bit_depth,
                                                    colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                    options: sdr_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing SDR PNG: \(error)")
                    return -1
                }
            case 3:
                do {
                    try ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     format: bit_depth,
                                                     colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                     options: sdr_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing SDR TIFF: \(error)")
                    return -1
                }
            default:
                return -1
            }
            return 0
        }
        
        while hlg_export {
            let hlg_export_options = NSDictionary(dictionary: [
                kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.85
            ])
            switch self.outputType {
            case 0:
                do {
                    try ctx.writeHEIF10Representation(
                        of: hdr_image!,
                        to: url_export_image,
                        colorSpace: CGColorSpace(name: hlg_color_space)!,
                        options: hlg_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing HLG HEIF: \(error)")
                    return -1
                }
            case 1:
                do {
                    try ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                     options: hlg_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing HLG JPEG: \(error)")
                    return -1
                }
            case 2:
                do {
                    try ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                    to: url_export_image,
                                                    format: bit_depth,
                                                    colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                    options: hlg_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing HLG PNG: \(error)")
                    return -1
                }
            case 3:
                do {
                    try ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     format: bit_depth,
                                                     colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                     options: hlg_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing HLG TIFF: \(error)")
                    return -1
                }
            default:
                return -1
            }
            return 0
        }
        
        while pq_export {
            let pq_export_options = NSDictionary(dictionary: [
                kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.85
            ])
            switch self.outputType {
            case 0:
                do {
                    try ctx.writeHEIF10Representation(
                        of: hdr_image!,
                        to: url_export_image,
                        colorSpace: CGColorSpace(name: hdr_color_space)!,
                        options: pq_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing PQ HEIF: \(error)")
                    return -1
                }
            case 1:
                do {
                    try ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                     options: pq_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing PQ JPEG: \(error)")
                    return -1
                }
            case 2:
                do {
                    try ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                    to: url_export_image,
                                                    format: bit_depth,
                                                    colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                    options: pq_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing PQ PNG: \(error)")
                    return -1
                }
            case 3:
                do {
                    try ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                     to: url_export_image,
                                                     format: bit_depth,
                                                     colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                     options: pq_export_options as! [CIImageRepresentationOption: Any])
                } catch {
                    print("Error writing PQ TIFF: \(error)")
                    return -1
                }
            default:
                return -1
            }
            return 0
        }
        
        switch self.outputType {
        case 0:
            do {
                try ctx.writeHEIFRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing HEIF: \(error)")
                return -1
            }
        case 1:
            do {
                try ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing JPEG: \(error)")
                return -1
            }
        case 2:
            do {
                try ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                to: url_export_image,
                                                format: bit_depth,
                                                colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                options: export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing PNG: \(error)")
                return -1
            }
        case 3:
            do {
                try ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing TIFF: \(error)")
                return -1
            }
        default:
            return -1
        }
        
        return 0
    }
    
    /** Export monochromatic gain map photo which is compatible with Google Photos.
     * HDR images converted using CIImageRepresentationOption.hdrImage will have an RGB gain map.
     * Image generated by CIImageRepresentationOption.hdrGainMapImage will have a monochromatic gain map, which is compatible with Android devices.
     */
    private func convertMonoGainMap() -> Int {
        
        let ctx = Converter.sharedContext // Use shared context for better resource management
        
        // CIFilter and custom filter

        func areaMinMax(inputImage: CIImage) -> CIImage {
            let filter = CIFilter.areaMinMax()
            filter.inputImage = inputImage
            filter.extent = inputImage.extent
            return filter.outputImage!
        }

        func areaMaximum(inputImage: CIImage) -> CIImage {
            let filter = CIFilter.areaMaximum()
            filter.inputImage = inputImage
            filter.extent = CGRect(
                x: 1,
                y: 0,
                width: 1,
                height: 1)
             return filter.outputImage!
        }

        func ciImageToPixelBuffer(ciImage: CIImage) -> CVPixelBuffer? {
            let attributes: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                1,
                1,
                kCVPixelFormatType_64RGBALE,
                attributes as CFDictionary,
                &pixelBuffer
            )
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                return nil
            }
            ctx.render(ciImage, to: buffer)
            return buffer
        }

        func extractPixelData(from pixelBuffer: CVPixelBuffer) -> (r: UInt16, g: UInt16, b: UInt16)? {
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            }
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return nil
            }
            
            let pixelData = baseAddress.assumingMemoryBound(to: UInt16.self)
            let r = pixelData[0]
            let g = pixelData[1]
            let b = pixelData[2]
            return (r, g, b)
        }

        func getGainMap(hdr_input: CIImage,sdr_input: CIImage,hdr_max: Float) -> CIImage {
            // Temporary implementation until custom filters are properly linked
            // This provides a basic gain map calculation using built-in filters
            let ratio = hdr_input.applyingFilter("CIDivideBlendMode", parameters: [
                kCIInputBackgroundImageKey: sdr_input
            ])
            return ratio.applyingFilter("CIColorClamp", parameters: [
                "inputMinComponents": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
                "inputMaxComponents": CIVector(x: CGFloat(hdr_max), y: CGFloat(hdr_max), z: CGFloat(hdr_max), w: 1.0)
            ])
        }

        func getHDRmax(hdr_input: CIImage) -> CIImage {
            // Temporary implementation until custom filters are properly linked
            // This returns the maximum channel value using area operations
            return hdr_input.applyingFilter("CIAreaMaximum", parameters: [
                "inputExtent": CIVector(cgRect: hdr_input.extent)
            ])
        }

        func uint16ToFloat(value: UInt16) -> Float {
            return Float(value) / Float(UInt16.max)
        }
        
        
        
        let url_hdr = URL(fileURLWithPath: self.src)
        let filename = self.getFileName(url: url_hdr)
        let path_export = URL(fileURLWithPath: self.dest)
        let url_export_image = path_export.appendingPathComponent(filename)
        //let imageoptions
        
        var imagequality: Double? = 0.90
        var bit_depth = CIFormat.RGBA8
        
        let hdr_image = CIImage(contentsOf: url_hdr, options: [.expandToHDR: true])
        let tonemapped_sdrimage = hdr_image?.applyingFilter(
            "CIToneMapHeadroom", parameters: ["inputTargetHeadroom": 1.0])
        
        // calculate HDR headroom

        let hdr_max = getHDRmax(hdr_input: hdr_image!).applyingFilter("CIToneMapHeadroom", parameters: ["inputSourceHeadroom":1.0,"inputTargetHeadroom":1.0])
        let hdr_min_max = areaMinMax(inputImage:hdr_max)
        let hdr_max_pixel = areaMaximum(inputImage:hdr_min_max)
        let hdr_max_pixel_data = extractPixelData(from: ciImageToPixelBuffer(ciImage: hdr_max_pixel)!)
        let hdr_max_pixel_data_max = max(hdr_max_pixel_data!.r, hdr_max_pixel_data!.g, hdr_max_pixel_data!.b)
        let hdr_max_value = uint16ToFloat(value:hdr_max_pixel_data_max)

        let hdr_headroom = pow(2.0, -16.7702 + 20.209*hdr_max_value) + 4.88701*hdr_max_value + 0.2935 //empirical

        let pic_headroom = min(max(2.0, hdr_headroom),16.0)
        
        var sdr_color_space = CGColorSpace.displayP3
        
        let image_color_space = String(describing: hdr_image?.colorSpace)
        
        if image_color_space.contains("709") {
            sdr_color_space = CGColorSpace.itur_709
        }
        if image_color_space.contains("sRGB") {
            sdr_color_space = CGColorSpace.itur_709
        }
        if image_color_space.contains("2100") {
            sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
        }
        if image_color_space.contains("2020") {
            sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
        }
        if image_color_space.contains("Adobe RGB") {
            sdr_color_space = CGColorSpace.adobeRGB1998
        }
        
        
        if self.imageQuality > 1 {
            imagequality = self.imageQuality / 100
        } else {
            imagequality = self.imageQuality
        }
        
        if self.colorDepth == 10 {
            bit_depth = CIFormat.RGB10
        }
        
        if self.colorDepth == 16 {
            bit_depth = CIFormat.RGBX16
        }
        
        switch self.colorSpace {
        case "srgb", "709", "rec709", "rec.709", "bt709", "bt,709", "itu709", "sRGB":
            sdr_color_space = CGColorSpace.itur_709
        case "p3", "dcip3", "dci-p3", "dci.p3", "displayp3", "P3":
            sdr_color_space = CGColorSpace.displayP3
        case "rec2020", "2020", "rec.2020", "bt2020", "itu2020", "2100", "rec2100", "rec.2100",
            "Rec. 2020":
            sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
        default:
            debugPrint(
                "Error: The colorSpace argument requires color space argument. (srgb, p3, rec2020)")
        }
        
        // start converting
        let gain_map = getGainMap(hdr_input: hdr_image!, sdr_input: tonemapped_sdrimage!, hdr_max: pic_headroom)
        let gain_map_sdr = gain_map.applyingFilter("CIToneMapHeadroom", parameters: ["inputSourceHeadroom":1.0,"inputTargetHeadroom":1.0])
        let stops = log2(pic_headroom)
        var imageProperties = hdr_image!.properties
        var makerApple = imageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]

        switch stops {
        case let x where x >= 2.303:
            makerApple["33"] = 1.0
            makerApple["48"] = (3.0 - stops)/70.0
        case 1.8..<3:
            makerApple["33"] = 1.0
            makerApple["48"] = (2.303 - stops)/0.303
        case 1.6..<1.8:
            makerApple["33"] = 0.0
            makerApple["48"] = (1.80 - stops)/20.0
        default:
            makerApple["33"] = 0.0
            makerApple["48"] = (1.601 - stops)/0.101
        }

        /*
        makerApple["33"] = 1.0
        makerApple["48"] = (3.0 - 4.0)/70.0
        */
        imageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerApple
        let modifiedImage = tonemapped_sdrimage!.settingProperties(imageProperties)

        let alt_export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.85, CIImageRepresentationOption.hdrGainMapImage:gain_map_sdr])
        
        switch self.outputType {
        case 0:
            do {
                try ctx.writeHEIFRepresentation(of: modifiedImage,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: alt_export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing MonoGainMap HEIF: \(error)")
                return -1
            }
        case 1:
            do {
                try ctx.writeJPEGRepresentation(of: modifiedImage,
                                                 to: url_export_image,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: alt_export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing MonoGainMap JPEG: \(error)")
                return -1
            }
        case 2:
            do {
                try ctx.writePNGRepresentation(of: modifiedImage,
                                                to: url_export_image,
                                                format: bit_depth,
                                                colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                options: alt_export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing MonoGainMap PNG: \(error)")
                return -1
            }
        case 3:
            do {
                try ctx.writeTIFFRepresentation(of: modifiedImage,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: alt_export_options as! [CIImageRepresentationOption: Any])
            } catch {
                print("Error writing MonoGainMap TIFF: \(error)")
                return -1
            }
        default:
            return -1
        }
        return 0
    }
}
