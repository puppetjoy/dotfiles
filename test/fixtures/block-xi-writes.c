/* Diagnostic interposer for Falcon's isolated-config kcminit reproduction
 * Suppress ALL XI property writes and root cursor changes, not just logging
 * cc -shared -fPIC -Wall -Werror block-xi-writes.c -o block-xi-writes.so -lX11
 */
#include <stdio.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/extensions/XInput2.h>

void XIChangeProperty(Display *display, int deviceid, Atom property,
                      Atom type, int format, int mode,
                      unsigned char *data, int count)
{
    char *name = XGetAtomName(display, property);
    if (name && !strcmp(name, "libinput Accel Profile Enabled")) {
        fprintf(stderr, "BLOCKED XIChangeProperty device=%d property=%s values=", deviceid, name);
        for (int i = 0; i < count; ++i) fprintf(stderr, "%s%d", i ? "," : "", data[i]);
        fprintf(stderr, "\n");
    }
    if (name) XFree(name);
}

int XDefineCursor(Display *display, Window window, Cursor cursor)
{
    return 1;
}
