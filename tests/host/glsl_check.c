// Compile GLSL files with the host's Mesa (headless EGL, OpenGL 3.2 core like Roblox's GL path) and
// report which fail and why. Files are named by Mesa's MESA_SHADER_DUMP_PATH: VS_*/FS_*/GS_*.
// Build: cc -O2 -o glsl_check tests/host/glsl_check.c -lEGL -lGL
// Usage: glsl_check <file>...        exit status = number of failures
#define EGL_EGLEXT_PROTOTYPES
#include <EGL/egl.h>
#include <EGL/eglext.h>
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f);
    char *s = malloc(n + 1);
    s[fread(s, 1, n, f)] = 0;
    fclose(f);
    return s;
}

int main(int argc, char **argv) {
    EGLDisplay d = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, 0);
    if (!eglInitialize(d, 0, 0)) { fprintf(stderr, "no EGL display\n"); return 99; }
    eglBindAPI(EGL_OPENGL_API);
    EGLint cfg_attr[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT, EGL_NONE}, n;
    EGLConfig cfg;
    eglChooseConfig(d, cfg_attr, &cfg, 1, &n);
    EGLint ctx_attr[] = {EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 2,
                         EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT, EGL_NONE};
    EGLContext c = eglCreateContext(d, n ? cfg : 0, EGL_NO_CONTEXT, ctx_attr);
    if (!c || !eglMakeCurrent(d, EGL_NO_SURFACE, EGL_NO_SURFACE, c)) { fprintf(stderr, "no GL context\n"); return 99; }

    int failed = 0;
    for (int i = 1; i < argc; i++) {
        const char *base = strrchr(argv[i], '/') ? strrchr(argv[i], '/') + 1 : argv[i];
        GLenum type = !strncmp(base, "FS", 2) ? GL_FRAGMENT_SHADER : !strncmp(base, "GS", 2) ? GL_GEOMETRY_SHADER : GL_VERTEX_SHADER;
        char *src = slurp(argv[i]);
        if (!src) continue;
        GLuint s = glCreateShader(type);
        glShaderSource(s, 1, (const char *const *)&src, 0);
        glCompileShader(s);
        GLint ok;
        glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
        if (!ok) {
            char log[4096];
            glGetShaderInfoLog(s, sizeof log, 0, log);
            printf("FAIL %s\n%s", base, log);
            failed++;
        }
        glDeleteShader(s);
        free(src);
    }
    fprintf(stderr, "%d of %d failed\n", failed, argc - 1);
    return failed;
}
