//
//  Bokeh.swift
//  Filterpedia
//
//  Created by Simon Gladman on 30/04/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import CoreImage

// MARK: Core Image Kernel Languag based bokeh

class MaskedVariableHexagonalBokeh: MaskedVariableCircularBokeh {
    override func displayName() -> String {
        return "Masked Variable Hexagonal Bokeh"
    }
    
    // MaskedVariableHexagonalBokeh
    override func withinProbe() -> String {
        return "float withinProbe = ((xx > h || yy > v * 2.0) ? 1.0 : ((2.0 * v * h - v * xx - h * yy) >= 0.0) ? 0.0 : 1.0);"
    }
}

class MaskedVariableCircularBokeh: CIFilter {
	
    var inputImage: CIImage?
    var inputBokehMask: CIImage?
    var inputMaxBokehRadius: CGFloat = 20
	var inputBlurRadius: CGFloat = 2
	
    override var attributes: [String: Any] {
        return [
            kCIAttributeFilterDisplayName: displayName(),
            
           kCIInputImageKey: [kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Image",
                kCIAttributeType: kCIAttributeTypeImage],
            
            "inputBokehMask": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Image",
                kCIAttributeType: kCIAttributeTypeImage],
            
            "inputMaxBokehRadius": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 20,
                kCIAttributeDisplayName: "Bokeh Radius",
                kCIAttributeMin: 1,
                kCIAttributeSliderMin: 1,
                kCIAttributeSliderMax: 50,
                kCIAttributeType: kCIAttributeTypeScalar],
            
            "inputBlurRadius": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 2,
                kCIAttributeDisplayName: "Blur Radius",
                kCIAttributeMin: 1,
                kCIAttributeSliderMin: 1,
                kCIAttributeSliderMax: 5,
                kCIAttributeType: kCIAttributeTypeScalar]
        ]
    }
    
    lazy var maskedVariableBokeh: CIKernel = {
        return CIKernel(source:
            "kernel vec4 lumaVariableBlur(sampler image, sampler bokehMask, float maxBokehRadius) " +
                "{ " +
                "    vec2 d = destCoord(); " +
                "    vec3 bokehMaskPixel = sample(bokehMask, samplerCoord(bokehMask)).rgb; " +
                "    float bokehMaskPixelLuma = dot(bokehMaskPixel, vec3(0.2126, 0.7152, 0.0722)); " +
                "    int radius = int(bokehMaskPixelLuma * maxBokehRadius); " +
                "    vec3 brightestPixel = sample(image, samplerCoord(image)).rgb; " +
                "    float brightestLuma = 0.0;" +
                
                "    float v = float(radius) / 2.0;" +
                "    float h = v * sqrt(3.0);" +
                
                "    for (int x = -radius; x <= radius; x++)" +
                "    { " +
                "        for (int y = -radius; y <= radius; y++)" +
                "        { " +
                "            float xx = abs(float(x));" +
                "            float yy = abs(float(y));" +
                
                self.withinProbe() +
                "            vec2 workingSpaceCoordinate = d + vec2(x,y);" +
                "            vec2 imageSpaceCoordinate = samplerTransform(image, workingSpaceCoordinate); " +
                "            vec3 color = sample(image, imageSpaceCoordinate).rgb; " +
                "            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722)); " +
                "            if (withinProbe == 0.0 && luma > brightestLuma) {brightestLuma = luma; brightestPixel = color; } "  +
                "        } " +
                "    } " +
                "    return vec4(brightestPixel, 1.0); " +
            "} ")!
    }()
    
    func displayName() -> String {
        return "Masked Variable Circular Bokeh"
    }
    
    // MaskedVariableCircularBokeh
    func withinProbe() -> String {
        return "float withinProbe = length(vec2(xx, yy)) < float(radius) ? 0.0 : 1.0; "
    }
    
    override var outputImage: CIImage? {
		guard let inputImage = inputImage, let inputBlurMask = inputBokehMask else {
            return nil
        }
        
        let extent = inputImage.extent
        
		let blur = maskedVariableBokeh.apply(
			extent: extent,
            roiCallback: {
                (index, rect) in
                return rect
            },
            arguments: [inputImage, inputBlurMask, inputMaxBokehRadius])
        
        return blur?
			.applyingFilter("CIMaskedVariableBlur", parameters: ["inputMask": inputBlurMask, "inputRadius": inputBlurRadius])
			.cropped(to: extent)
    }
}
