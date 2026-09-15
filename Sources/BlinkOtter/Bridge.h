#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BOPlayerView : NSOpenGLView <NSDraggingDestination>
@property (nonatomic, copy, nullable) void (^onOpen)(NSURL *url);
@end

@interface BOEngine : NSObject
- (nullable instancetype)initWithView:(BOPlayerView *)view;
- (BOOL)loadFile:(NSString *)path;
- (void)togglePause;
- (void)seekTo:(double)seconds;
- (void)jumpBy:(int)seconds;
- (double)timePosition;
- (double)duration;
- (BOOL)isPaused;
@end

NS_ASSUME_NONNULL_END
