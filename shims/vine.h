// Minimal declarations so shims build without an Apple SDK (host clang + ld64.lld).
#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef signed char BOOL;
typedef unsigned long NSUInteger;
typedef const struct __CFString *CFStringRef;
typedef const void *CFTypeRef;
typedef long CFIndex;
typedef unsigned long CFTypeID;
typedef int32_t OSStatus;
typedef id (*IMP)(id, SEL, ...);

int dprintf(int, const char *, ...);
void *malloc(size_t);
void *memcpy(void *, const void *, size_t);
void free(void *);
id objc_msgSend(id, SEL, ...);
char *getenv(const char *);
size_t strlen(const char *);
int strcmp(const char *, const char *);
typedef void *Method;
Class objc_getClass(const char *);
SEL sel_registerName(const char *);
Method class_getInstanceMethod(Class, SEL);
IMP method_setImplementation(Method, IMP);
const char *sel_getName(SEL);
const char *class_getName(Class);
Class object_getClass(id);
BOOL class_addMethod(Class, SEL, IMP, const char *);

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
- (id)init;
@end
@class NSString;

// Every stub logs its first use: "vine-stub: <name>".
#define VINE_LOG_ONCE(name) do { static int done; if (!done) { done = 1; dprintf(2, "vine-stub: %s\n", name); } } while (0)

// A class whose every message returns nil/0 (see VineStub.m).
@interface VineStub : NSObject @end
#define VINE_CLASS(n) @interface n : VineStub @end @implementation n @end

// NSString/CFString constants: value is the symbol's own name, as on macOS.
#define VINE_STR(n) NSString *const n = @#n;

// C function that logs and returns a fixed value; arguments are ignored.
#define VINE_FUNC(ret, n, val) ret n() { VINE_LOG_ONCE(#n); return (ret)(val); }
#define VINE_VOID(n) void n() { VINE_LOG_ONCE(#n); }
