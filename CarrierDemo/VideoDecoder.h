#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

//#define USE_FFMPEG

@protocol VideoDecoderDelegate;

@interface VideoDecoder : NSObject

- (void)decode:(NSData *)data;
- (void)end;

@property (weak, nonatomic) id<VideoDecoderDelegate> delegate;

@end

@protocol VideoDecoderDelegate

@optional
- (void)videoDecoder:(VideoDecoder *)decoder gotVideoImage:(UIImage *)image;
- (void)videoDecoder:(VideoDecoder *)decoder gotSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)videoDecoder:(VideoDecoder *)decoder error:(NSString *)error;

@end
