//
//  PQHDR_to_GainMapHDR.swift
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
        
        func subtractBlendMode(inputImage: CIImage, backgroundImage: CIImage) -> CIImage {
            let colorBlendFilter = CIFilter.subtractBlendMode()
            colorBlendFilter.inputImage = inputImage
            colorBlendFilter.backgroundImage = backgroundImage
            return colorBlendFilter.outputImage!
        }

        func linearTosRGB(inputImage: CIImage) -> CIImage {
            let linearTosRGB = CIFilter.linearToSRGBToneCurve()
            linearTosRGB.inputImage = inputImage
            return linearTosRGB.outputImage!
        }

        func exposureAdjust(inputImage: CIImage, inputEV: Float) -> CIImage {
            let exposureAdjustFilter = CIFilter.exposureAdjust()
            exposureAdjustFilter.inputImage = inputImage
            exposureAdjustFilter.ev = inputEV
            return exposureAdjustFilter.outputImage!
        }

        func maximumComponent(inputImage: CIImage) -> CIImage {
            let maximumComponentFilter = CIFilter.maximumComponent()
            maximumComponentFilter.inputImage = inputImage
            return maximumComponentFilter.outputImage!
        }

        func toneCurve1(inputImage: CIImage) -> CIImage {
            let toneCurveFilter = CIFilter.toneCurve()
            toneCurveFilter.inputImage = inputImage
            toneCurveFilter.point0 = CGPoint(x: 0.0, y: 0.61)
            toneCurveFilter.point1 = CGPoint(x: 0.5, y: 0.63)
            toneCurveFilter.point2 = CGPoint(x: 0.75, y: 0.76)
            toneCurveFilter.point3 = CGPoint(x: 0.9, y: 0.91)
            toneCurveFilter.point4 = CGPoint(x: 1.0, y: 1.0)
            return toneCurveFilter.outputImage!
        }

        func colorClamp(inputImage: CIImage) -> CIImage {
            let colorClampFilter = CIFilter.colorClamp()
            colorClampFilter.inputImage = inputImage
            colorClampFilter.minComponents = CIVector(x: 0.04, y: 0.04, z: 0.04, w: 0)
            colorClampFilter.maxComponents = CIVector (x: 1, y: 1, z: 1, w: 1)
            return colorClampFilter.outputImage!
        }

        func gammaAdjust(inputImage: CIImage) -> CIImage {
            let gammaAdjustFilter = CIFilter.gammaAdjust()
            gammaAdjustFilter.inputImage = inputImage
            gammaAdjustFilter.power = 1/2.2
            return gammaAdjustFilter.outputImage!
        }

        func hdrtosdr(inputImage: CIImage) -> CIImage {
            let imagedata = ctx.tiffRepresentation(of: inputImage,
                                                   format: CIFormat.RGBA8,
                                                   colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!
            )
            let sdrimage = CIImage(data: imagedata!)
            return sdrimage!
        }
        
        let ctx = CIContext()
        
        let url_hdr = URL(fileURLWithPath: self.src)
        let filename = self.getFileName(url: url_hdr)
        let path_export = URL(fileURLWithPath: self.dest)
        let url_export_image = path_export.appendingPathComponent(filename)
        //let imageoptions
        
        var imagequality: Double? = 0.85
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
        
        let sdr_image = hdrtosdr(inputImage:hdr_image!)
        let subtracted_image = subtractBlendMode(
            inputImage:exposureAdjust(inputImage:sdr_image,inputEV: -3),backgroundImage: exposureAdjust(inputImage:hdr_image!,inputEV: -3)
        )
        let gain_map = gammaAdjust(inputImage:colorClamp(inputImage:maximumComponent(inputImage:subtracted_image)))
        let tone_mapped_gain_map = toneCurve1(inputImage:gain_map)

        var imageProperties = hdr_image!.properties
        var makerApple = imageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]
        makerApple["33"] = 1.0
        makerApple["48"] = 0.0
        imageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerApple

        let modifiedImage = tonemapped_sdrimage!.settingProperties(imageProperties)
        let alt_export_options = NSDictionary(dictionary:[kCGImageDestinationLossyCompressionQuality:imagequality ?? 0.90, CIImageRepresentationOption.hdrGainMapImage:tone_mapped_gain_map])

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
