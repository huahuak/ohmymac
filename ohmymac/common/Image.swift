//
//  Image.swift
//  ohmymac
//
//  Created by huahua on 2024/4/2.
//

import Foundation
import Cocoa


extension NSImage {
    func convertToGrayScale() -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorControls")!
        filter.setDefaults()
        filter.setValue(ciImage, forKey: "inputImage")
        filter.setValue(0.0, forKey: "inputSaturation")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: self.size)
        nsImage.addRepresentation(rep)

        return nsImage
    }
}

func iconAddSubscript(img: NSImage, sub: NSImage) -> NSImage {
    let image = NSImage(size: img.size)
    image.lockFocus()
    img.draw(in: NSRect(x: 0, y: 0, width: Int(img.size.width), height: Int(img.size.height)),
             from: NSRect.zero, operation: .copy, fraction: 1.0)
    let margin = 1
    sub.draw(in: NSRect(x: Int(img.size.width - sub.size.width) - margin, y: margin,
                        width: Int(sub.size.width), height: Int(sub.size.height)),
             from: NSRect.zero, operation: .darken, fraction: 0.6)
    image.unlockFocus()
    return image
}
