//
//  MRBlurView.m
//  MRProgress
//
//  Created by Marius Rackwitz on 10.10.13.
//  Copyright (c) 2013 Marius Rackwitz. All rights reserved.
//

#import "MRBlurView.h"
#import <Accelerate/Accelerate.h>


vImage_Buffer vImage_BufferForCGImageRef(CGImageRef imageRef, void *data) {
    return (vImage_Buffer){
        .width = CGImageGetWidth(imageRef),
        .height = CGImageGetHeight(imageRef),
        .rowBytes = CGImageGetBytesPerRow(imageRef),
        .data = data
    };
}


@interface MRBlurView ()

@end


@implementation MRBlurView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.clipsToBounds = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.image = [self blurredImageFromImage:[self windowBelowDialogViewSnapshot]];
}


#pragma mark - Image helper

- (UIImage *)windowBelowDialogViewSnapshot {
    CGPoint origin = [self convertPoint:self.frame.origin toView:UIApplication.sharedApplication.keyWindow];
    UIGraphicsBeginImageContext(self.frame.size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, -origin.x, -origin.y);
    [UIApplication.sharedApplication.delegate.window.layer renderInContext:ctx];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)blurredImageFromImage:(UIImage *)sourceImage {
    int boxSize = 129; // Must be odd!
    
    CGImageRef sourceImageRef = sourceImage.CGImage;
    CGDataProviderRef inProvider = CGImageGetDataProvider(sourceImageRef);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    void *pixelBuffer = malloc(CGImageGetBytesPerRow(sourceImageRef) * CGImageGetHeight(sourceImageRef));
    if (pixelBuffer == NULL) {
        return nil;
    }
    
    vImage_Buffer inBuffer = vImage_BufferForCGImageRef(sourceImageRef, (void *)CFDataGetBytePtr(inBitmapData));
    vImage_Buffer outBuffer = vImage_BufferForCGImageRef(sourceImageRef, pixelBuffer);
    vImage_Error error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    if (error) {
        return nil;
    }
    free(pixelBuffer);
    
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             (int)kCGImageAlphaNoneSkipLast);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    
    // Clean up
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    CFRelease(inBitmapData);
    CGImageRelease(imageRef);
    
    return returnImage;
}

@end
