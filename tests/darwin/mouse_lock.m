// Darwin test (runs in Darling, needs DISPLAY): with the mouse locked (CGAssociate...(false)) the
// app gets the mouse's movement as event deltas, without jumps when the pointer is recentred.
// Prints "LOCKED", then after the host has moved the mouse (tests/darwin/mouse_lock.sh) the sums.
#include "../../shims/vine.h"
int printf(const char *, ...); int fflush(void *); extern void *__stdoutp; void exit(int);
int CGAssociateMouseAndMouseCursorPosition(unsigned int);
typedef id (^Mon)(id);
typedef struct { double x, y; } TPoint; typedef struct { double w, h; } TSize; typedef struct { TPoint o; TSize s; } TRect;
@interface NSObject (T)
+ (id)sharedApplication; - (void)run; - (void)activateIgnoringOtherApps:(BOOL)b;
- (id)initWithContentRect:(TRect)r styleMask:(unsigned long)s backing:(unsigned long)b defer:(BOOL)d;
- (void)makeKeyAndOrderFront:(id)s; + (id)addLocalMonitorForEventsMatchingMask:(unsigned long long)m handler:(Mon)h;
- (double)deltaX; - (double)deltaY; - (unsigned long)type;
@end
typedef struct dispatch_queue_s *dq; extern struct dispatch_queue_s _dispatch_main_q;
void dispatch_after(uint64_t when, dq q, void (^b)(void)); uint64_t dispatch_time(uint64_t, int64_t);
int main(void) {
    id app = [objc_getClass("NSApplication") sharedApplication];
    id win = [[objc_getClass("NSWindow") alloc] initWithContentRect:(TRect){{100, 100}, {800, 600}} styleMask:15 backing:2 defer:0];
    [win makeKeyAndOrderFront:0]; [app activateIgnoringOtherApps:1];
    __block double sx = 0, sy = 0, maxjump = 0; __block int n = 0, locked = 0, any = 0; static int pre[40], post[40];
    [objc_getClass("NSEvent") addLocalMonitorForEventsMatchingMask:~0ULL handler:^id(id e) {
        uint64_t mach_absolute_time(void); static int shown; if ([e type] == 5 && shown++ < 3) { printf("  moved at %.3f s locked=%d dx=%.0f\n", mach_absolute_time() / 1e9, locked, [e deltaX]); fflush(__stdoutp); }
        any++; unsigned long ty = [e type]; if (ty < 40) (locked ? post : pre)[ty]++;
        if (locked && ([e type] == 5 || [e type] == 6 || [e type] == 7)) {
            double dx = [e deltaX], dy = [e deltaY];
            sx += dx; sy += dy; n++;
            if (dx * dx + dy * dy > maxjump) maxjump = dx * dx + dy * dy;
        }
        return e;
    }];
    dispatch_after(dispatch_time(0, 2000000000LL), &_dispatch_main_q, ^{
        CGAssociateMouseAndMouseCursorPosition(0); locked = 1;
        uint64_t mach_absolute_time(void); printf("LOCKED at %.3f s\n", mach_absolute_time() / 1e9); fflush(__stdoutp);
    dispatch_after(dispatch_time(0, 7000000000LL), &_dispatch_main_q, ^{
            printf("(all events %d) events %d, total dx %.0f dy %.0f, largest single step %.0f px\n", any, n, sx, sy, __builtin_sqrt(maxjump));
            for (int i = 0; i < 40; i++) if (pre[i] || post[i]) printf("  type %d: %d before lock, %d after\n", i, pre[i], post[i]);
            fflush(__stdoutp); exit(0);
        });
    });

    [app run];
    return 0;
}
