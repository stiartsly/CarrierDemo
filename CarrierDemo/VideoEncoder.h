#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@protocol VideoEncoderDelegate;

@interface VideoEncoder : NSObject

- (void)encode:(CMSampleBufferRef)sampleBuffer;
- (void)end;

@property (weak, nonatomic) id<VideoEncoderDelegate> delegate;

@end

@protocol VideoEncoderDelegate

- (void)videoEncoder:(VideoEncoder *)encoder appendBytes:(const void *)bytes length:(NSInteger)length;
- (void)videoEncoder:(VideoEncoder *)encoder error:(NSString *)error;

@end
