#import "Bridge.h"
#import <mpv/client.h>
#import <mpv/render_gl.h>
#import <OpenGL/gl.h>

static void *getGLProc(void *context, const char *name) {
    CFStringRef symbol = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingASCII);
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    void *address = bundle ? CFBundleGetFunctionPointerForName(bundle, symbol) : NULL;
    CFRelease(symbol);
    return address;
}

@interface BOPlayerView ()
@property (nonatomic, assign) mpv_render_context *renderContext;
@end

@implementation BOPlayerView
- (instancetype)initWithFrame:(NSRect)frame {
    NSOpenGLPixelFormatAttribute attributes[] = {NSOpenGLPFADoubleBuffer, NSOpenGLPFAAccelerated, 0};
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    self = [super initWithFrame:frame pixelFormat:format];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
        GLint interval = 1;
        [[self openGLContext] setValues:&interval forParameter:NSOpenGLCPSwapInterval];
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    [[self openGLContext] makeCurrentContext];
    if (_renderContext) {
        NSSize pixels = [self convertSizeToBacking:self.bounds.size];
        mpv_opengl_fbo fbo = {.fbo = 0, .w = (int)pixels.width, .h = (int)pixels.height};
        int flip = 1;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
            {MPV_RENDER_PARAM_FLIP_Y, &flip},
            {MPV_RENDER_PARAM_INVALID, NULL}
        };
        mpv_render_context_render(_renderContext, params);
    } else {
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    [[self openGLContext] flushBuffer];
}
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [NSURL URLFromPasteboard:sender.draggingPasteboard] ? NSDragOperationCopy : NSDragOperationNone;
}
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSURL *url = [NSURL URLFromPasteboard:sender.draggingPasteboard];
    if (!url.fileURL) return NO;
    if (self.onOpen) self.onOpen(url);
    return YES;
}
@end

static void requestDraw(void *context) {
    BOPlayerView *view = (__bridge BOPlayerView *)context;
    dispatch_async(dispatch_get_main_queue(), ^{ [view setNeedsDisplay:YES]; });
}

@implementation BOEngine {
    mpv_handle *_mpv;
    mpv_render_context *_renderContext;
    __weak BOPlayerView *_view;
}
- (instancetype)initWithView:(BOPlayerView *)view {
    self = [super init];
    if (!self) return nil;
    _view = view;
    _mpv = mpv_create();
    if (!_mpv) return nil;
    mpv_set_option_string(_mpv, "hwdec", "auto-safe");
    mpv_set_option_string(_mpv, "keep-open", "yes");
    if (mpv_initialize(_mpv) < 0) return nil;
    if (mpv_set_option_string(_mpv, "vo", "libmpv") < 0) return nil;
    [[view openGLContext] makeCurrentContext];
    mpv_opengl_init_params gl = {.get_proc_address = getGLProc};
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl},
        {MPV_RENDER_PARAM_INVALID, NULL}
    };
    if (mpv_render_context_create(&_renderContext, _mpv, params) < 0) return nil;
    view.renderContext = _renderContext;
    mpv_render_context_set_update_callback(_renderContext, requestDraw, (__bridge void *)view);
    return self;
}
- (void)dealloc {
    if (_renderContext) {
        mpv_render_context_set_update_callback(_renderContext, NULL, NULL);
        _view.renderContext = NULL;
        mpv_render_context_free(_renderContext);
    }
    if (_mpv) mpv_terminate_destroy(_mpv);
}
- (BOOL)loadFile:(NSString *)path {
    const char *args[] = {"loadfile", path.UTF8String, "replace", NULL};
    return mpv_command_async(_mpv, 0, args) >= 0;
}
- (void)togglePause { const char *args[] = {"cycle", "pause", NULL}; mpv_command_async(_mpv, 0, args); }
- (void)seekTo:(double)seconds {
    NSString *time = [NSString stringWithFormat:@"%.3f", seconds];
    const char *args[] = {"seek", time.UTF8String, "absolute", "exact", NULL};
    mpv_command_async(_mpv, 0, args);
}
- (void)jumpBy:(int)seconds {
    NSString *time = [NSString stringWithFormat:@"%d", seconds];
    const char *args[] = {"seek", time.UTF8String, "relative", NULL};
    mpv_command_async(_mpv, 0, args);
}
- (double)getDouble:(const char *)name {
    double value = 0;
    return mpv_get_property(_mpv, name, MPV_FORMAT_DOUBLE, &value) >= 0 ? value : 0;
}
- (double)timePosition { return [self getDouble:"time-pos"]; }
- (double)duration { return [self getDouble:"duration"]; }
- (BOOL)isPaused {
    int paused = 0;
    return mpv_get_property(_mpv, "pause", MPV_FORMAT_FLAG, &paused) >= 0 && paused;
}
@end
