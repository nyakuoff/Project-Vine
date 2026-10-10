// Host check of shims/httpdate.h. Run: cc -o /tmp/hd tests/host/httpdate_test.c && /tmp/hd
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../../shims/httpdate.h"
static double t(const char *s) { return vine_http_date(s, s + strlen(s)); }
int main(void) {
    assert(t("Thu, 01 Jan 2001 00:00:00 GMT") == 0);                 // CFAbsoluteTime epoch
    assert(t("Wed, 21 Oct 2015 07:28:00 GMT") == 1445412480.0 - 978307200.0);
    assert(t("Sat, 29 Feb 2048 23:59:59 GMT") == 2466633599.0 - 978307200.0);   // leap day
    assert(t("Wednesday, 21-Oct-15 07:28:00 GMT") == 1445412480.0 - 978307200.0);
    assert(t("garbage") == 0);
    puts("httpdate: all checks passed");
    return 0;
}
