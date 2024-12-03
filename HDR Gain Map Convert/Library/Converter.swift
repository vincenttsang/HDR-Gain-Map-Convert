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
        let ctx = CIContext()
        
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
                try! ctx.writeHEIFRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: sdr_export_options as! [CIImageRepresentationOption: Any])
            case 1:
                try! ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: sdr_export_options as! [CIImageRepresentationOption: Any])
            case 2:
                try! ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                to: url_export_image,
                                                format: bit_depth,
                                                colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                options: sdr_export_options as! [CIImageRepresentationOption: Any])
            case 3:
                try! ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: sdr_color_space)!,
                                                 options: sdr_export_options as! [CIImageRepresentationOption: Any])
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
                try! ctx.writeHEIF10Representation(
                    of: hdr_image!,
                    to: url_export_image,
                    colorSpace: CGColorSpace(name: hlg_color_space)!,
                    options: hlg_export_options as! [CIImageRepresentationOption: Any])
            case 1:
                try! ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                 options: hlg_export_options as! [CIImageRepresentationOption: Any])
            case 2:
                try! ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                to: url_export_image,
                                                format: bit_depth,
                                                colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                options: hlg_export_options as! [CIImageRepresentationOption: Any])
            case 3:
                try! ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                 options: hlg_export_options as! [CIImageRepresentationOption: Any])
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
                try! ctx.writeHEIF10Representation(
                    of: hdr_image!,
                    to: url_export_image,
                    colorSpace: CGColorSpace(name: hdr_color_space)!,
                    options: pq_export_options as! [CIImageRepresentationOption: Any])
            case 1:
                try! ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                 options: pq_export_options as! [CIImageRepresentationOption: Any])
            case 2:
                try! ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                                to: url_export_image,
                                                format: bit_depth,
                                                colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                options: pq_export_options as! [CIImageRepresentationOption: Any])
            case 3:
                try! ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                                 to: url_export_image,
                                                 format: bit_depth,
                                                 colorSpace: CGColorSpace(name: hdr_color_space)!,
                                                 options: pq_export_options as! [CIImageRepresentationOption: Any])
            default:
                return -1
            }
            return 0
        }
        
        switch self.outputType {
        case 0:
            try! ctx.writeHEIFRepresentation(of: tonemapped_sdrimage!,
                                             to: url_export_image,
                                             format: bit_depth,
                                             colorSpace: CGColorSpace(name: sdr_color_space)!,
                                             options: export_options as! [CIImageRepresentationOption: Any])
        case 1:
            try! ctx.writeJPEGRepresentation(of: tonemapped_sdrimage!,
                                             to: url_export_image,
                                             colorSpace: CGColorSpace(name: sdr_color_space)!,
                                             options: export_options as! [CIImageRepresentationOption: Any])
        case 2:
            try! ctx.writePNGRepresentation(of: tonemapped_sdrimage!,
                                            to: url_export_image,
                                            format: bit_depth,
                                            colorSpace: CGColorSpace(name: sdr_color_space)!,
                                            options: export_options as! [CIImageRepresentationOption: Any])
        case 3:
            try! ctx.writeTIFFRepresentation(of: tonemapped_sdrimage!,
                                             to: url_export_image,
                                             format: bit_depth,
                                             colorSpace: CGColorSpace(name: sdr_color_space)!,
                                             options: export_options as! [CIImageRepresentationOption: Any])
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
        
        let ctx = CIContext()
        
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
                kCVPixelFormatType_32ARGB,
                attributes as CFDictionary,
                &pixelBuffer
            )
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                return nil
            }
            ctx.render(ciImage, to: buffer)
            return buffer
        }
        
        func extractPixelData(from pixelBuffer: CVPixelBuffer) -> [UInt32]? {
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            }
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return nil
            }
            
            
            let pixelData = baseAddress.assumingMemoryBound(to: UInt32.self)
            let size = 4
            
            var pixelArray: [UInt32] = []
            for i in 0..<size {
                pixelArray.append(pixelData[i])
            }
            return pixelArray
        }
        
        func AdjustGainMap(inputImage: CIImage, inputEV: Float) -> CIImage {
            let filter = gmAdjustFilter()
            filter.inputImage = inputImage
            filter.inputEV = inputEV
            let outputImage = filter.outputImage
            return outputImage!
        }
        
        
        func getGainMap(hdr_input: CIImage,sdr_input: CIImage) -> CIImage {
            let filter = GainMapFilter()
            filter.HDRImage = hdr_input
            filter.SDRImage = sdr_input
            let outputImage = filter.outputImage
            return outputImage!
        }
        
        
        func uint32ToFloat(value: UInt32) -> Float {
            return Float(value) / Float(UInt32.max)
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
        let gain_map = getGainMap(hdr_input: hdr_image!, sdr_input: tonemapped_sdrimage!)
        let gain_map_sdr = getGainMap(hdr_input: hdr_image!, sdr_input: tonemapped_sdrimage!).applyingFilter("CIToneMapHeadroom", parameters: ["inputSourceHeadroom":1.0,"inputTargetHeadroom":1.0])
        
        
        let gain_map_min_max = areaMinMax(inputImage:gain_map_sdr)
        let gain_map_pixel = areaMaximum(inputImage:gain_map_min_max)
        let gain_map_pixel_data = extractPixelData(from: ciImageToPixelBuffer(ciImage: gain_map_pixel)!)?.first
        let max_ratio = uint32ToFloat(value:gain_map_pixel_data!)
        let stops = pow(max_ratio,2.2)*4.0
        let headroom = pow(2.0,stops)
        
        let gain_map_adj = AdjustGainMap(inputImage: gain_map, inputEV: headroom + pow(10,-5)).applyingFilter("CIToneMapHeadroom", parameters: ["inputSourceHeadroom":1.0,"inputTargetHeadroom":1.0])
        
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
        
        imageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerApple
        let modifiedImage = tonemapped_sdrimage!.settingProperties(imageProperties)
        
        let alt_export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.90, CIImageRepresentationOption.hdrGainMapImage:gain_map_adj])
        
        switch self.outputType {
        case 0:
            try! ctx.writeHEIFRepresentation(of: modifiedImage,
                                             to: url_export_image,
                                             format: bit_depth,
                                             colorSpace: CGColorSpace(name: sdr_color_space)!,
                                             options: alt_export_options as! [CIImageRepresentationOption: Any])
        case 1:
            try! ctx.writeJPEGRepresentation(of: modifiedImage,
                                             to: url_export_image,
                                             colorSpace: CGColorSpace(name: sdr_color_space)!,
                                             options: alt_export_options as! [CIImageRepresentationOption: Any])
        case 2:
            try! ctx.writePNGRepresentation(of: modifiedImage,
                                            to: url_export_image,
                                            format: bit_depth,
                                            colorSpace: CGColorSpace(name: sdr_color_space)!,
                                            options: alt_export_options as! [CIImageRepresentationOption: Any])
        case 3:
            try! ctx.writeTIFFRepresentation(of: modifiedImage,
                                             to: url_export_image,
                                             format: bit_depth,
                                             colorSpace: CGColorSpace(name: sdr_color_space)!,
                                             options: alt_export_options as! [CIImageRepresentationOption: Any])
        default:
            return -1
        }
        return 0
    }
}
