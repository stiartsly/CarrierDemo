#import "VideoDecoder.h"
#include "CRtpUnpack.h"

#ifdef USE_FFMPEG
extern "C" {
#include "avcodec.h"
#include "avformat.h"
#include "avutil.h"
#include "swscale.h"
#include "frame.h"
#include "opt.h"
};
#else
#import <VideoToolbox/VideoToolbox.h>
#endif

@implementation VideoDecoder
{
    dispatch_queue_t queue;
    CRtpUnpack *rtpUnpack;
#ifdef USE_FFMPEG
    // for ffmpeg decoder
    AVCodecContext  *pCodecCtx;
    AVFrame         *pFrame;
#else
    NSData *spsData;
    NSData *ppsData;
    CMVideoFormatDescriptionRef videoFormatDescription;
    VTDecompressionSessionRef decompressionSession;
#endif
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Custom initialization
        queue = dispatch_queue_create("videoDecoder", NULL);
#ifdef USE_FFMPEG
        [self initFFmpegDecoder];
#endif
    }
    return self;
}

- (void)dealloc
{
    [self stop];

#ifdef USE_FFMPEG
    if (pFrame) {
        av_frame_free(&pFrame);
        pFrame = NULL;
    }

    if (pCodecCtx) {
        avcodec_close(pCodecCtx);
        avcodec_free_context(&pCodecCtx);
        pCodecCtx = NULL;
    }
#endif

    queue = NULL;
}

- (void)decode:(NSData *)data
{
    dispatch_async(queue, ^{
        
        if (rtpUnpack == NULL) {
            int initError;
            rtpUnpack = new CRtpUnpack(initError);
            if (initError != 0) {
                delete rtpUnpack;
                rtpUnpack = NULL;
                
                NSLog(@"RTP: Create CRtpUnpack error: %d", initError);
                [self.delegate videoDecoder:self error:@"Create CRtpUnpack failed"];
                return;
            }
        }
        
        unsigned short rtpLength = data.length;
        unsigned char *pRtpData = new unsigned char[rtpLength];
        [data getBytes:pRtpData length:rtpLength];
        
        unsigned int frameLength = 0;
        unsigned int timestamp = 0;
        unsigned char *pFrameData = rtpUnpack->Parse_RTP_Packet(pRtpData, rtpLength, &frameLength, &timestamp);
        if (pFrameData != NULL && frameLength > 4)
        {
#ifdef USE_FFMPEG
            [self ffmpegDecodeFrameData:pFrameData length:frameLength withTimestamp:timestamp];
#else
            [self hardwareDecodeFrameData:pFrameData length:frameLength];
#endif
        }
        
        delete [] pRtpData;
        pRtpData = NULL;
    });
}

#ifdef USE_FFMPEG
- (BOOL)initFFmpegDecoder
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        avcodec_register_all();
    });

    AVCodec *pCodec = avcodec_find_decoder(CODEC_ID_H264);
    if (pCodec == NULL) {
        NSLog(@"codec not found");
        return NO;
    }

    if (pCodecCtx == NULL) {
        pCodecCtx = avcodec_alloc_context3(pCodec);
        if (pCodecCtx == NULL) {
            NSLog(@"Allocate codec context failed");
            return NO;
        }

        av_opt_set(pCodecCtx->priv_data, "tune", "zerolatency", 0);
    }

    int ret = avcodec_open2(pCodecCtx, pCodec, NULL);
    if (ret != 0) {
        NSLog(@"open codec error :%d", ret);
        return NO;
    }

    if (pFrame == NULL) {
        pFrame = av_frame_alloc();
        if (pFrame == NULL) {
            NSLog(@"av_frame_alloc failed");
            return NO;
        }
    }
    return YES;
}

- (void)ffmpegDecodeFrameData:(unsigned char*)pFrameData length:(unsigned int)length withTimestamp:(unsigned int)timestamp
{
    if (pFrameData == NULL || length == 0) {
        return;
    }

    int decoderFrameOK = 0;
    int result = 0;

    @synchronized(self) {
        AVPacket packet;
        av_new_packet(&packet, length);
        memcpy(packet.data, pFrameData, length);
        result = avcodec_decode_video2(pCodecCtx, pFrame, &decoderFrameOK, &packet);
        av_free_packet(&packet);
    }

    if (result >=0 && decoderFrameOK && pFrame) {
        UIImage *image = [self imageFromAVFrame:pFrame];
        if (image) {
            [self.delegate videoDecoder:self gotVideoImage:image];
        }
    }
}

- (UIImage*)imageFromAVFrame:(AVFrame *)avFrame
{
    // float scale = MIN(_outputSize.width / avFrame->width, _outputSize.height / avFrame->height);
    float width = avFrame->width; // scale * avFrame->width;
    float height = avFrame->height; //scale * avFrame->height;
    AVPicture avPicture;
    avpicture_alloc(&avPicture, AV_PIX_FMT_RGB24, width, height);

    struct SwsContext * imgConvertCtx = sws_getContext(avFrame->width,
                                                       avFrame->height,
                                                       PIX_FMT_YUV420P,
                                                       width,
                                                       height,
                                                       AV_PIX_FMT_RGB24,
                                                       SWS_FAST_BILINEAR,
                                                       NULL,
                                                       NULL,
                                                       NULL);
    if(imgConvertCtx == nil) return nil;

    sws_scale(imgConvertCtx,
              avFrame->data,
              avFrame->linesize,
              0,
              avFrame->height,
              avPicture.data,
              avPicture.linesize);
    sws_freeContext(imgConvertCtx);

    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                  avPicture.data[0],
                                  avPicture.linesize[0] * height);

    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       avPicture.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);

    avpicture_free(&avPicture);
    return image;
}

#else

- (void)hardwareDecodeFrameData:(unsigned char*)pFrameData length:(unsigned int)frameLength
{
    int naluType = ((uint8_t)pFrameData[4] & 0x1F);
    //NSLog(@"RTP: timestamp: %d, nalu header: %x, type: %d, size: %d", timestamp, pFrameData[4], naluType, length);
    
    if ((naluType == 7 || naluType == 8) && videoFormatDescription == NULL) {
        if (naluType == 7) {
            spsData = [NSData dataWithBytes:pFrameData + 4 length:frameLength - 4];
        }
        
        if (naluType == 8) {
            ppsData = [NSData dataWithBytes:pFrameData + 4 length:frameLength - 4];
        }
        
        if (spsData != nil && ppsData != nil) {
            const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[2] = { spsData.length, ppsData.length };
            
            //construct h.264 parameter set
            CMVideoFormatDescriptionRef formatDesc = NULL;
            OSStatus formatCreateResult = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &formatDesc);
            if (formatCreateResult == noErr) {
                videoFormatDescription = formatDesc;
                if (decompressionSession == NULL || VTDecompressionSessionCanAcceptFormatDescription(decompressionSession, formatDesc) == NO) {
                    [self createDecompSession];
                }
            }
            else {
                NSLog(@"H264 decode: CMVideoFormatDescriptionCreateFromH264ParameterSets error : %d", (int)formatCreateResult);
                [self stop];
                [self.delegate videoDecoder:self error:@"Create video format description failed"];
            }
        }
    }
    else if ((naluType == 1 || naluType == 5) && videoFormatDescription) {

        unsigned char* nal_start = pFrameData;
        do {
            unsigned char* nal_end = avc_find_startcode(nal_start + 4, pFrameData + frameLength);
            uint32_t nal_len = htonl(nal_end - nal_start - 4);
            memcpy (nal_start, &nal_len, sizeof(uint32_t));
//            uint32_t nal_len = nal_end - nal_start - 4;
//            nal_start[0] = (uint8_t)(nal_len >> 24);
//            nal_start[1] = (uint8_t)(nal_len >> 16);
//            nal_start[2] = (uint8_t)(nal_len >> 8 );
//            nal_start[3] = (uint8_t)(nal_len);
            nal_start = nal_end;
        } while (nal_start < pFrameData + frameLength);
        
        CMBlockBufferRef blockBuffer = NULL;
//        OSStatus status = CMBlockBufferCreateEmpty(NULL, 0, kCMBlockBufferAlwaysCopyDataFlag, &blockBuffer);
//        if (status == kCMBlockBufferNoErr) {
//            status = CMBlockBufferAppendMemoryBlock(blockBuffer,
//                                                    pFrameData,
//                                                    frameLength,
//                                                    NULL,
//                                                    NULL,
//                                                    0,
//                                                    frameLength,
//                                                    kCMBlockBufferAlwaysCopyDataFlag);
//        }
//        else {
//            DLogError(@"Create empty block buffer failed : %d", status);
//        }
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, pFrameData, frameLength, kCFAllocatorNull, NULL, 0, frameLength, 0, &blockBuffer);
        if (status == kCMBlockBufferNoErr) {
            const size_t sampleSize = frameLength; // CMBlockBufferGetDataLength(blockBuffer);
            CMSampleBufferRef sampleBuffer = NULL;
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,
                                               videoFormatDescription,
                                               1,
                                               0,
                                               NULL,
                                               1,
                                               &sampleSize,
                                               &sampleBuffer);
            if (status == noErr) {
                // set some values of the sample buffer's attachments
                CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
                CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
                CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);

                [self.delegate videoDecoder:self gotSampleBuffer:sampleBuffer];
                //[self render:sampleBuffer];
                
                CFRelease(sampleBuffer);
            }
            else {
                NSLog(@"H264 decode: CMSampleBufferCreate error : %d", (int)status);
                [self stop];
                [self.delegate videoDecoder:self error:@"Create sample buffer failed"];
            }
            
            CFRelease(blockBuffer);
        }
        else {
            NSLog(@"H264 decode: CMBlockBufferCreateWithMemoryBlock error : %d", (int)status);
            [self stop];
            [self.delegate videoDecoder:self error:@"Create block buffer failed"];
        }
    }
}

-(void) createDecompSession
{
    // make sure to destroy the old VTD session
    decompressionSession = NULL;
    
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decompressionSessionDecodeFrameCallback;
    // this is necessary if you need to make calls to Objective C "self" from within in the callback method.
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    
    // you can set some desired attributes for the destination pixel buffer.  I didn't use this but you may
    // if you need to set some attributes, be sure to uncomment the dictionary in VTDecompressionSessionCreate
    NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],(id)kCVPixelBufferOpenGLESCompatibilityKey,
                                                     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey,nil];
    
    OSStatus status =  VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                    videoFormatDescription,
                                                    NULL,
                                                    (__bridge CFDictionaryRef)(destinationImageBufferAttributes), // attrs, // NULL
                                                    &callBackRecord,
                                                    &decompressionSession);
    NSLog(@"Video Decompression Session Create: \t %@", (status == noErr) ? @"successful!" : @"failed...");
    if(status != noErr) NSLog(@"\t\t VTD ERROR type: %d", (int)status);
}

- (void) render:(CMSampleBufferRef)sampleBuffer
{
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression; // kVTDecodeFrame_1xRealTimePlayback;
    VTDecodeInfoFlags flagOut = 0;
    VTDecompressionSessionDecodeFrame(decompressionSession,
                                      sampleBuffer,
                                      flags,
                                      NULL,
                                      &flagOut);
}

void decompressionSessionDecodeFrameCallback(void *decompressionOutputRefCon,
                                             void *sourceFrameRefCon,
                                             OSStatus status,
                                             VTDecodeInfoFlags infoFlags,
                                             CVImageBufferRef imageBuffer,
                                             CMTime presentationTimeStamp,
                                             CMTime presentationDuration)
{
    if (status != noErr || !imageBuffer)
    {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Decompressed error: %@", error);
    }
    else
    {
        CVImageBufferRef buffer = imageBuffer;
        
        /* Lock Buffer */
        CVPixelBufferLockBaseAddress(buffer, 0);
        
        //从 CVImageBufferRef 取得影像的细部信息
        uint8_t *base;
        size_t width, height, bytesPerRow;
        base = (uint8_t*)CVPixelBufferGetBaseAddress(buffer);
        width = CVPixelBufferGetWidth(buffer);
        height = CVPixelBufferGetHeight(buffer);
        bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
        size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
        
        //利用取得影像细部信息格式化 CGContextRef
        CGColorSpaceRef colorSpace;
        colorSpace = CGColorSpaceCreateDeviceRGB();
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, base, bufferSize, NULL);
        
        CGImageRef cgImage = CGImageCreate(width,
                                           height,
                                           8,
                                           32,
                                           bytesPerRow,
                                           colorSpace,
                                           kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little,
                                           provider,
                                           NULL,
                                           true,
                                           kCGRenderingIntentDefault);
        
        UIImage *image;
        image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpace);
        /* UnLock buffre */
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        
        if (image) {
            VideoDecoder* decoder = (__bridge VideoDecoder*)decompressionOutputRefCon;
            [decoder.delegate videoDecoder:decoder gotVideoImage:image];
        }
    }
}

uint8_t *avc_find_startcode(uint8_t *p, uint8_t *end)
{
    uint8_t *out= avc_find_startcode_internal(p, end);
    if(p<out && out<end && !out[-1]) out--;
    return out;
}

uint8_t *avc_find_startcode_internal(uint8_t *p, uint8_t *end)
{
    const uint8_t *a = p + 4 - ((intptr_t)p & 3);

    for (end -= 3; p < a && p < end; p++) {
        if (p[0] == 0 && p[1] == 0 && p[2] == 1)
            return p;
    }

    for (end -= 3; p < end; p += 4) {
        uint32_t x = *(const uint32_t*)p;
        //if ((x - 0x01000100) & (~x) & 0x80008000) { // little endian
        //if ((x - 0x00010001) & (~x) & 0x00800080) { // big endian
        if ((x - 0x01010101) & (~x) & 0x80808080) { // generic
            if (p[1] == 0) {
                if (p[0] == 0 && p[2] == 1)
                    return p;
                if (p[2] == 0 && p[3] == 1)
                    return p+1;
            }
            if (p[3] == 0) {
                if (p[2] == 0 && p[4] == 1)
                    return p+2;
                if (p[4] == 0 && p[5] == 1)
                    return p+3;
            }
        }
    }

    for (end += 3; p < end; p++) {
        if (p[0] == 0 && p[1] == 0 && p[2] == 1)
            return p;
    }

    return end + 3;
}

#endif

- (void)end
{
    dispatch_async(queue, ^{
        [self stop];
    });
}

- (void)stop {
    if (rtpUnpack) {
        delete rtpUnpack;
        rtpUnpack = NULL;
    }

#ifndef USE_FFMPEG
    if (decompressionSession) {
        CFRelease(decompressionSession);
        decompressionSession = NULL;
    }
    
    if (videoFormatDescription) {
        CFRelease(videoFormatDescription);
        videoFormatDescription = NULL;
    }
    
    spsData = nil;
    ppsData = nil;
#endif
}

@end
