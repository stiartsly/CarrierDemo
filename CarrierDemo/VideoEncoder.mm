#import <Foundation/Foundation.h>
#import "VideoEncoder.h"
#import "CRtpStream.h"

static const int fps = 20;

#define CROP_IMAGE 0

#if CROP_IMAGE
#import <CoreImage/CoreImage.h>

static const CGFloat width = 320;
static const CGFloat height = 240;
#endif

@implementation VideoEncoder
{
    dispatch_queue_t queue;
    VTCompressionSessionRef encodingSession;
#if CROP_IMAGE
    CVPixelBufferRef renderBuffer;
    CIContext *ciContext;
#endif
    CRtpStream *rtp;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Custom initialization
        queue = dispatch_queue_create("videoEncoder", NULL);
    }
    return self;
}

- (void)dealloc
{
    [self end];
    queue = NULL;
}

void didRtpStreamOut(void *callbackRefCon, const uint8_t *data, int length)
{
    VideoEncoder* encoder = (__bridge VideoEncoder*)callbackRefCon;
    [encoder->_delegate videoEncoder:encoder appendBytes:data length:length];
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
//    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != noErr) {
        NSLog(@"H264 encode: encoding video error: %d", (int)status);
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"H264 encode: didCompressH264 data is not ready");
        return;
    }
    
    NSMutableData *streamData = [NSMutableData data];
    VideoEncoder* encoder = (__bridge VideoEncoder*)outputCallbackRefCon;
    
    // This is the start code that we will write to
    // the elementary stream before every NAL unit
    static const size_t startCodeLength = 4;
    static const uint8_t startCode[] = {0x00, 0x00, 0x00, 0x01};
    
    // Find out if the sample buffer contains an I-Frame.
    // If so we will write the SPS and PPS NAL units to the elementary stream.
    //bool isIFrame = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    BOOL isIFrame = NO;
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (CFArrayGetCount(attachmentsArray)) {
        CFBooleanRef notSync;
        CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(attachmentsArray, 0);
        BOOL keyExists = CFDictionaryGetValueIfPresent(dict, kCMSampleAttachmentKey_NotSync, (const void **)&notSync);
        // An I-Frame is a sync frame
        isIFrame = !keyExists || !CFBooleanGetValue(notSync);
    }
    
    if (isIFrame) {
        CMFormatDescriptionRef description = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // Find out how many parameter sets there are
        size_t parameterSetCount;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, 0, NULL, NULL, &parameterSetCount, NULL);
        if (statusCode == noErr) {
            // Write each parameter set to the elementary stream
            for (int i = 0; i < parameterSetCount; i++) {
                const uint8_t *parameterSetPointer;
                size_t parameterSetSize;
                OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, i, &parameterSetPointer, &parameterSetSize, NULL, NULL);
                if (statusCode == noErr) {
                    // Write the parameter set to the elementary stream
                    [streamData appendBytes:startCode length:startCodeLength];
                    [streamData appendBytes:parameterSetPointer length:parameterSetSize];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t totalLength;
    uint8_t *dataPointer = NULL;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, NULL, &totalLength, (char **)&dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            // Write start code to the elementary stream
            [streamData appendBytes:startCode length:startCodeLength];
            // Write the NAL unit without the AVCC length header to the elementary stream
            [streamData appendBytes:dataPointer + bufferOffset + AVCCHeaderLength length:NALUnitLength];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
    
    if (streamData.length > 0) {
        CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        uint32_t timestamp = (uint32_t)(presentationTimeStamp.value * 1000 / presentationTimeStamp.timescale);
        encoder->rtp->streamOut((const uint8_t *)streamData.bytes, (int)streamData.length, timestamp);
    }
}

- (void)encode:(CMSampleBufferRef)sampleBuffer
{
    dispatch_sync(queue, ^{
#if !CROP_IMAGE
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
#endif
        
        if (encodingSession == NULL) {
#if CROP_IMAGE
            // Create the compression session
            NSDictionary* pixelBufferOptions = @{(__bridge NSString*) kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                                                 (__bridge NSString*) kCVPixelBufferWidthKey:@(width),
                                                 (__bridge NSString*) kCVPixelBufferHeightKey:@(height),
                                                 (__bridge NSString*) kCVPixelBufferOpenGLESCompatibilityKey : @YES,
                                                 (__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey : @{}};
            OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                         width,
                                                         height,
                                                         kCMVideoCodecType_H264,
                                                         NULL,
                                                         (__bridge CFDictionaryRef)pixelBufferOptions,
                                                         NULL,
                                                         didCompressH264,
                                                         (__bridge void *)(self),
                                                         &encodingSession);
#else
            CGFloat width = CVPixelBufferGetWidth(imageBuffer) * 0.75;
            CGFloat height = CVPixelBufferGetHeight(imageBuffer) * 0.75;
            NSLog(@"Video width : %.0f, height : %.0f", width, height);
            
            // Create the compression session
            OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &encodingSession);
#endif
            if (status != 0) {
                NSLog(@"H264 encode: VTCompressionSessionCreate error: %d", (int)status);
                [self.delegate videoEncoder:self error:@"Unable to create a H264 compression session"];
                return;
            }
            
            // Set the properties
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
            // ProfileLevel，h264的协议等级，不同的清晰度使用不同的ProfileLevel
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
            // 关闭重排Frame，因为有了B帧（双向预测帧，根据前后的图像计算出本帧）后，编码顺序可能跟显示顺序不同
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
            // 视频帧率
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(fps));
            // 关键帧最大间隔，1为每个都是关键帧，数值越大压缩率越高。此处表示关键帧最大间隔为1s
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(fps));
            // 设置需要的平均编码率
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(width*height*10));
            VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_SourceFrameCount, (__bridge CFTypeRef)@(1));
            
            // Tell the encoder to start encoding
            VTCompressionSessionPrepareToEncodeFrames(encodingSession);
            
            rtp = new CRtpStream(didRtpStreamOut, (__bridge void *)(self));
        }
        
#if CROP_IMAGE
        if (renderBuffer == NULL) {
            CVReturn result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, VTCompressionSessionGetPixelBufferPool(encodingSession), &renderBuffer);
            if (result != kCVReturnSuccess) {
                NSLog(@"H264 encode: CVPixelBufferPoolCreatePixelBuffer error : %d", result);
                [self.delegate videoEncoder:self error:@"CVPixelBufferPoolCreatePixelBuffer failed"];
                return;
            }
        }

        if (ciContext == NULL) {
            EAGLContext *glCtx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
            ciContext = [CIContext contextWithEAGLContext:glCtx options:@{kCIContextWorkingColorSpace:[NSNull null]}];
        }

        // Get the CV Image buffer
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CGFloat bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
        CGFloat bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
        CGFloat scaleX = width / bufferWidth, scaleY = height / bufferHeight;
        if (scaleX > scaleY) {
            CGFloat ty = (height - bufferHeight * scaleX) / 2;
            CGAffineTransform transform = CGAffineTransformMakeTranslation(0, ty);
            transform = CGAffineTransformScale(transform, scaleX, scaleX);
            ciImage = [ciImage imageByApplyingTransform:transform];
            ciImage = [ciImage imageByCroppingToRect:CGRectMake(0, 0, width, height)];
        }
        else if (scaleX < scaleY) {
            CGFloat tx = (width - bufferWidth * scaleY) / 2;
            CGAffineTransform transform = CGAffineTransformMakeTranslation(tx, 0);
            transform = CGAffineTransformScale(transform, scaleY, scaleY);
            ciImage = [ciImage imageByApplyingTransform:transform];
            ciImage = [ciImage imageByCroppingToRect:CGRectMake(0, 0, width, height)];
        }
        else if (scaleX != 1) {
            CGAffineTransform transform = CGAffineTransformMakeScale(scaleX, scaleY);
            ciImage = [ciImage imageByApplyingTransform:transform];
        }

        CVPixelBufferLockBaseAddress(renderBuffer, 0);
        [ciContext render:ciImage toCVPixelBuffer:renderBuffer bounds:ciImage.extent colorSpace:nil];
        CVPixelBufferUnlockBaseAddress(renderBuffer, 0);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
#endif

        // Create properties
        CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession,
#if CROP_IMAGE
                                                              renderBuffer,
#else
                                                              imageBuffer,
#endif
                                                              presentationTimeStamp,
                                                              duration,
                                                              NULL, NULL, &flags);

        // Check for error
        if (statusCode != noErr) {
//            // End the session
//            VTCompressionSessionInvalidate(encodingSession);
//            CFRelease(encodingSession);
//            encodingSession = NULL;
//            
//            if (rtp) {
//                delete rtp;
//                rtp = NULL;
//            }
            
            NSLog(@"H264 encode: VTCompressionSessionEncodeFrame error : %d", (int)statusCode);
            [self.delegate videoEncoder:self error:@"VTCompressionSessionEncodeFrame failed"];
        }
    });
}

- (void)end
{
    if (encodingSession != NULL) {
        // Mark the completion
        VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
        
        // End the session
        VTCompressionSessionInvalidate(encodingSession);
        CFRelease(encodingSession);
        encodingSession = NULL;
    }
    
#if CROP_IMAGE
    if (renderBuffer != NULL) {
        CFRelease(renderBuffer);
        renderBuffer = NULL;
    }
#endif

    if (rtp) {
        delete rtp;
        rtp = NULL;
    }
}

@end
