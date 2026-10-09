// Visual test (runs inside Darling): NSOpenGLContext on an NSView, clear to red, flushBuffer.
// argv[1] = "layer": view is layer-backed first (Roblox calls setWantsLayer:).
// argv[1] = "thread": render + flushBuffer on a secondary thread.
// argv[1] = "noupdate": never call -update (Roblox doesn't; 60 flushBuffer/s on the main thread).
// Check with: import -window root (expect a red 400x300 area).
#include "../../shims/vine.h"
int printf(const char *, ...);
char *getenv(const char *);
double strtod(const char *, char **);
unsigned int sleep(unsigned int);
typedef double CGFloat;
typedef struct { CGFloat x, y, w, h; } NSRect;
@interface NSApplication : NSObject + (id)sharedApplication; - (void)finishLaunching; - (void)activateIgnoringOtherApps:(BOOL)f; @end
@interface NSView : NSObject - (id)initWithFrame:(NSRect)r; - (void)setWantsLayer:(BOOL)b; @end
@interface NSWindow : NSObject
- (id)initWithContentRect:(NSRect)r styleMask:(unsigned long)s backing:(unsigned long)b defer:(BOOL)d;
- (void)setContentView:(NSView *)v; - (void)makeKeyAndOrderFront:(id)s; - (void)display;
@end
@interface NSOpenGLPixelFormat : NSObject - (id)initWithAttributes:(const unsigned int *)a; @end
@interface NSOpenGLContext : NSObject
- (id)initWithFormat:(NSOpenGLPixelFormat *)f shareContext:(id)s; - (void)setView:(NSView *)v;
- (void)makeCurrentContext; - (void)update; - (void)flushBuffer;
@end
@interface NSRunLoop : NSObject + (id)currentRunLoop; - (void)runUntilDate:(id)d; @end
@interface NSDate : NSObject + (id)dateWithTimeIntervalSinceNow:(double)s; @end
void glClearColor(float, float, float, float); void glClear(unsigned int); void glFinish(void);
const unsigned char *glGetString(unsigned int);
int pthread_create(void **, void *, void *(*)(void *), void *);
static NSOpenGLContext *ctx;
static int noupdate;
static void frames(void) {
    for (int i = 0; i < 40; i++) {
        if (!noupdate) [ctx update];
        glClearColor(1, 0, 0, 1); glClear(0x4000); [ctx flushBuffer];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}
static void *render_thread(void *a) { [ctx makeCurrentContext]; printf("thread GL_RENDERER %s\n", glGetString(0x1F01)); frames(); return 0; }
int main(int argc, char **argv) {
    int threaded = argc > 1 && argv[1][0] == 't';
    noupdate = argc > 1 && argv[1][0] == 'n';
    id app = [NSApplication sharedApplication]; [app finishLaunching];
    double W = getenv("VINE_W") ? strtod(getenv("VINE_W"), 0) : 400, H = getenv("VINE_H") ? strtod(getenv("VINE_H"), 0) : 300;
    NSRect r = {100, 100, W, H};
    NSWindow *w = [[NSWindow alloc] initWithContentRect:r styleMask:15 backing:2 defer:0];
    NSView *v = [[NSView alloc] initWithFrame:(NSRect){0, 0, W, H}];
    if (argc > 1 && argv[1][0] == 'l') [v setWantsLayer:1];
    [w setContentView:v]; [w makeKeyAndOrderFront:0];
    unsigned int attrs[] = {99 /*OpenGLProfile*/, 0x3200 /*3.2 core*/, 73 /*ColorSize*/, 24, 5 /*DoubleBuffer*/, 0};
    NSOpenGLContext *c = [[NSOpenGLContext alloc] initWithFormat:[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] shareContext:0];
    printf("context %p\n", c);
    [c setView:v]; ctx = c;
    if (threaded) {
        void *t; pthread_create(&t, 0, render_thread, 0);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:6]];
    } else { [c makeCurrentContext]; printf("GL_RENDERER %s\n", glGetString(0x1F01)); frames(); }
    printf("done\n");
    return 0;
}
