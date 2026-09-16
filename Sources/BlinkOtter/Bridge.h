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
- (double)volume;
- (void)setVolume:(double)value;
- (BOOL)isMuted;
- (void)toggleMute;
- (double)speed;
- (void)setSpeed:(double)value;
- (NSInteger)subtitleTrackCount;
- (NSString *)subtitleTrackLabelAt:(NSInteger)index;
- (NSInteger)subtitleTrackIDAt:(NSInteger)index;
- (void)setSubtitleTrack:(NSInteger)trackID;
- (NSInteger)audioTrackCount;
- (NSString *)audioTrackLabelAt:(NSInteger)index;
- (NSInteger)audioTrackIDAt:(NSInteger)index;
- (void)setAudioTrack:(NSInteger)trackID;
- (NSInteger)selectedSubtitleTrack;
- (NSInteger)selectedAudioTrack;
@end

NS_ASSUME_NONNULL_END
