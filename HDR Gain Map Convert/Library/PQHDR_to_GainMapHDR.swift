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

class Converter {
    var src: String
    var dest: String
    var imageQuality: Double
    var colorSpace: String
    var colorDepth: Int
    var SDR: Bool
    var PQ: Bool
    var HLG: Bool

    init(
        src: String, dest: String, imageQuality: Double, colorSpace: String, colorDepth: Int,
        SDR: Bool, PQ: Bool, HLG: Bool
    ) {
        self.src = src
        self.dest = dest
        self.imageQuality = imageQuality
        self.colorSpace = colorSpace
        self.colorDepth = colorDepth
        self.SDR = SDR
        self.PQ = PQ
        self.HLG = HLG
    }

    func convert() -> Int {
        let ctx = CIContext()

        /*
         let arguments = CommandLine.arguments
         guard arguments.count > 2 else {
         print("Usage: PQHDRtoGMHDR <source file> <destination folder> <options>\n       options:\n         -q <value>: image quality (default: 0.85)\n         -c <color space>: specify output color space (srgb, p3, rec2020)\n         -d <color depth>: specify output color depth (default: 8)\n         -s: export tone mapped SDR image without HDR gain map\n         -p: export 10bit PQ HDR heic image")
         exit(1)
         }
         */

        let url_hdr = URL(fileURLWithPath: self.src)
        let filename = url_hdr.deletingPathExtension().appendingPathExtension("heic")
            .lastPathComponent
        let path_export = URL(fileURLWithPath: self.dest)
        let url_export_heic = path_export.appendingPathComponent(filename)
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
        
        let image_color_space = hdr_image?.colorSpace!
        let image_color_space_name = hdr_image?.colorSpace?.name
    
        if image_color_space_name == nil {
            sdr_color_space = CGColorSpace.adobeRGB1998
            hdr_color_space = CGColorSpace.adobeRGB1998
            hlg_color_space = CGColorSpace.adobeRGB1998
        } else {
            if (image_color_space_name! as NSString).contains("709") {
                sdr_color_space = CGColorSpace.itur_709
                hdr_color_space = CGColorSpace.itur_709_PQ
                hlg_color_space = CGColorSpace.itur_709_HLG
            }
            if (image_color_space_name! as NSString).contains("sRGB") {
                sdr_color_space = CGColorSpace.itur_709
                hdr_color_space = CGColorSpace.itur_709_PQ
                hlg_color_space = CGColorSpace.itur_709_HLG
            }
            if (image_color_space_name! as NSString).contains("2100") {
                sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
                hdr_color_space = CGColorSpace.itur_2100_PQ
                hlg_color_space = CGColorSpace.itur_2100_HLG
            }
            if (image_color_space_name! as NSString).contains("2020") {
                sdr_color_space = CGColorSpace.itur_2020_sRGBGamma
                hdr_color_space = CGColorSpace.itur_2100_PQ
                hlg_color_space = CGColorSpace.itur_2100_HLG
            }
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
                kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.85
            ])
            try! ctx.writeHEIFRepresentation(
                of: tonemapped_sdrimage!,
                to: url_export_heic,
                format: bit_depth,
                colorSpace: CGColorSpace(name: sdr_color_space)!,
                options: sdr_export_options as! [CIImageRepresentationOption: Any])
            return 0
        }

        while hlg_export {
            let hlg_export_options = NSDictionary(dictionary: [
                kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.85
            ])
            try! ctx.writeHEIFRepresentation(
                of: hdr_image!,
                to: url_export_heic,
                format: bit_depth,
                colorSpace: CGColorSpace(name: hlg_color_space)!,
                options: hlg_export_options as! [CIImageRepresentationOption: Any])
            return 0
        }

        while pq_export {
            let pq_export_options = NSDictionary(dictionary: [
                kCGImageDestinationLossyCompressionQuality: imagequality ?? 0.85
            ])
            try! ctx.writeHEIF10Representation(
                of: hdr_image!,
                to: url_export_heic,
                colorSpace: CGColorSpace(name: hdr_color_space)!,
                options: pq_export_options as! [CIImageRepresentationOption: Any])
            return 0
        }

        try! ctx.writeHEIFRepresentation(
            of: tonemapped_sdrimage!,
            to: url_export_heic,
            format: bit_depth,
            colorSpace: CGColorSpace(name: sdr_color_space)!,
            options: export_options as! [CIImageRepresentationOption: Any])
        return 0
    }
}
