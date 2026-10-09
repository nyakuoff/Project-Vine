// Pure C, shared by shims/frameworks.m and tests/host/httpdate_test.c.
#pragma once
// HTTP date (RFC 1123 "Wed, 21 Oct 2015 07:28:00 GMT", also "21-Oct-2015") -> CFAbsoluteTime; 0 if unparsable.
static double vine_http_date(const char *s, const char *e) {
    static const char *mon = "JanFebMarAprMayJunJulAugSepOctNovDec";
    int day = -1, month = -1, year = -1, hh = 0, mm = 0, ss = 0;
    while (s < e && !(*s >= '0' && *s <= '9')) s++;                       // skip weekday
    if (s < e) { day = 0; while (s < e && *s >= '0' && *s <= '9') day = day * 10 + (*s++ - '0'); }
    while (s < e && (*s == ' ' || *s == '-')) s++;
    for (int i = 0; i < 12 && e - s >= 3; i++)
        if ((s[0] | 32) == (mon[3 * i] | 32) && (s[1] | 32) == mon[3 * i + 1] && (s[2] | 32) == mon[3 * i + 2]) month = i;
    while (s < e && !(*s >= '0' && *s <= '9')) s++;
    if (s < e) { year = 0; while (s < e && *s >= '0' && *s <= '9') year = year * 10 + (*s++ - '0'); }
    if (year >= 0 && year < 70) year += 2000; else if (year >= 70 && year < 100) year += 1900;
    while (s < e && *s == ' ') s++;
    if (e - s >= 8) { hh = (s[0] - '0') * 10 + s[1] - '0'; mm = (s[3] - '0') * 10 + s[4] - '0'; ss = (s[6] - '0') * 10 + s[7] - '0'; }
    if (day < 1 || month < 0 || year < 1970) return 0;
    // days since 1970-01-01 (civil-from-days inverse), then shift to the 2001 epoch
    int y = year - (month < 2), m = month < 2 ? month + 10 : month - 2;
    long era = y / 400, yoe = y - era * 400, doy = (153 * m + 2) / 5 + day - 1, doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    double unix_days = era * 146097 + doe - 719468;
    return unix_days * 86400 + hh * 3600 + mm * 60 + ss - 978307200.0;
}
