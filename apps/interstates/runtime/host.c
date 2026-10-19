/* The Interstates host that ioi-llvm links into every -s program. ioi_host.dart is its twin; the
 * Interstates suite keeps the two identical in behavior. It reads a request the CGI/1.1 way, from
 * the environment and stdin, and builds the response the program asks for (R2, R4). */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <wchar.h>
#endif

/* runtime.c's host interface, from its "Hosts" section. */
typedef struct {
  uint32_t (*start)(void);
  int (*petition)(uint32_t service, const uint32_t *scalars, uint32_t scalar_count, const uint32_t *arrays,
                  uint32_t array_count, const uint64_t *values, uint32_t value_count, uint32_t next);
  void (*prologue)(void);
} ick_host;

void ick_fatal(uint32_t code, uint32_t next);
uint64_t ick_scalar(uint32_t key);
void ick_set_scalar(uint32_t key, uint64_t value);
const uint32_t *ick_string(uint32_t array, size_t *length, uint32_t next);
void ick_set_string(uint32_t array, const uint16_t *units, size_t length);
void ick_output(const char *bytes, size_t length);
int ick_numeral_rows(uint64_t value, char rows[3][96]);

/* ---- The program's own data, which ioi-llvm appends to this file ----------------------- */

/* A route segment: fixed text, or a :param (length -1). */
typedef struct {
  const uint16_t *units;
  int32_t length;
} ioi_segment;

/* A route, as the compiler ordered them, most specific first and the catch-all last (R3). */
typedef struct {
  const ioi_segment *segments;
  int32_t segment_count; /* -1 for the catch-all */
  uint32_t entry;        /* the ordinal of its WITH ROUTE COME FROM */
  int32_t allowed_count; /* -1 for a public route */
  const uint32_t *allowed;
} ioi_route;

extern const ioi_route ioi_routes[];
extern const uint32_t ioi_route_count;

/* ---- Strings: UTF-16 code units, as the runtime keeps them ------------------------------- */

typedef struct {
  uint16_t *units;
  size_t length;
} ioi_string;

static void *checked(void *p) {
  if (!p) ick_fatal(778, 1);
  return p;
}

static ioi_string str_new(size_t capacity) {
  return (ioi_string){checked(malloc((capacity + 1) * sizeof(uint16_t))), 0};
}

static void str_free(ioi_string *s) {
  free(s->units);
  s->units = NULL;
  s->length = 0;
}

static ioi_string str_ascii(const char *text) {
  size_t n = strlen(text);
  ioi_string s = str_new(n);
  for (size_t i = 0; i < n; i++) s.units[i] = (unsigned char)text[i];
  s.length = n;
  return s;
}

static ioi_string str_copy(ioi_string from) {
  ioi_string s = str_new(from.length);
  memcpy(s.units, from.units, from.length * sizeof(uint16_t));
  s.length = from.length;
  return s;
}

/* A tail array's string. */
static ioi_string str_array(uint32_t array, uint32_t next) {
  size_t length;
  const uint32_t *units = ick_string(array, &length, next);
  ioi_string s = str_new(length);
  for (size_t i = 0; i < length; i++) s.units[i] = (uint16_t)units[i];
  s.length = length;
  return s;
}

static int str_equal(ioi_string a, ioi_string b) {
  return a.length == b.length && !memcmp(a.units, b.units, a.length * sizeof(uint16_t));
}

/* Each unit as UTF-8, a surrogate pair as one character and a lone surrogate as U+FFFD, into a
 * malloc'd buffer of [*length] bytes (NUL-terminated). */
static char *str_utf8(ioi_string s, size_t *length) {
  char *out = checked(malloc(s.length * 3 + 1));
  size_t n = 0;
  for (size_t i = 0; i < s.length; i++) {
    uint32_t c = s.units[i];
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length && s.units[i + 1] >= 0xDC00 &&
        s.units[i + 1] <= 0xDFFF) {
      c = 0x10000 + ((c - 0xD800) << 10) + (s.units[++i] - 0xDC00u);
    } else if (c >= 0xD800 && c <= 0xDFFF) {
      c = 0xFFFD;
    }
    if (c < 0x80) {
      out[n++] = (char)c;
    } else if (c < 0x800) {
      out[n++] = (char)(0xC0 | c >> 6);
      out[n++] = (char)(0x80 | (c & 0x3F));
    } else if (c < 0x10000) {
      out[n++] = (char)(0xE0 | c >> 12);
      out[n++] = (char)(0x80 | ((c >> 6) & 0x3F));
      out[n++] = (char)(0x80 | (c & 0x3F));
    } else {
      out[n++] = (char)(0xF0 | c >> 18);
      out[n++] = (char)(0x80 | ((c >> 12) & 0x3F));
      out[n++] = (char)(0x80 | ((c >> 6) & 0x3F));
      out[n++] = (char)(0x80 | (c & 0x3F));
    }
  }
  out[n] = 0;
  if (length) *length = n;
  return out;
}

/* UTF-8 bytes as code units: a lead byte that starts no sequence, or whose continuation bytes run
 * out or are interrupted, is U+FFFD and uses up only itself; a complete sequence that is overlong,
 * a surrogate or above U+10FFFF is U+FFFD and uses up all its bytes (the Strings block's rules). */
static ioi_string str_decode(const uint8_t *bytes, size_t length) {
  ioi_string s = str_new(length);
  size_t i = 0;
  while (i < length) {
    uint32_t lead = bytes[i];
    if (lead < 0x80) {
      s.units[s.length++] = (uint16_t)lead;
      i++;
      continue;
    }
    uint32_t need = 0, minimum = 0, value = 0;
    if (lead >> 5 == 6) need = 1, minimum = 0x80, value = lead & 0x1F;
    else if (lead >> 4 == 14) need = 2, minimum = 0x800, value = lead & 0x0F;
    else if (lead >> 3 == 30) need = 3, minimum = 0x10000, value = lead & 0x07;
    uint32_t got = 0;
    while (got < need && i + got + 1 < length && bytes[i + got + 1] >> 6 == 2) {
      value = value << 6 | (bytes[i + got + 1] & 0x3F);
      got++;
    }
    if (need == 0 || got < need) {
      s.units[s.length++] = 0xFFFD;
      i++;
      continue;
    }
    i += need + 1;
    if (value < minimum || value > 0x10FFFF || value >> 11 == 27) {
      s.units[s.length++] = 0xFFFD;
    } else if (value >= 0x10000) {
      s.units[s.length++] = (uint16_t)(0xD800 | ((value - 0x10000) >> 10));
      s.units[s.length++] = (uint16_t)(0xDC00 | ((value - 0x10000) & 0x3FF));
    } else {
      s.units[s.length++] = (uint16_t)value;
    }
  }
  return s;
}

/* ---- The request ------------------------------------------------------------------------ */

#ifndef _WIN32
/* Whether [text] is UTF-8, encoded surrogates allowed: Dart leaves out a variable that isn't. */
static int is_utf8(const char *text) {
  const unsigned char *p = (const unsigned char *)text;
  while (*p) {
    uint32_t c = *p++, need = 0, min = 0;
    if (c < 0x80) continue;
    if (c >= 0xC2 && c <= 0xDF) need = 1, min = 0x80, c &= 0x1F;
    else if (c >= 0xE0 && c <= 0xEF) need = 2, min = 0x800, c &= 0x0F;
    else if (c >= 0xF0 && c <= 0xF4) need = 3, min = 0x10000, c &= 0x07;
    else return 0;
    for (uint32_t i = 0; i < need; i++, p++) {
      if ((*p & 0xC0) != 0x80) return 0;
      c = (c << 6) | (*p & 0x3F);
    }
    if (c < min || c > 0x10FFFF) return 0;
  }
  return 1;
}
#endif

/* The environment variable [name] (ASCII), as Dart's Platform.environment has it. */
static int env(const char *name, ioi_string *out) {
#ifdef _WIN32
  size_t n = strlen(name);
  wchar_t *wide = checked(malloc((n + 1) * sizeof(wchar_t)));
  for (size_t i = 0; i <= n; i++) wide[i] = (wchar_t)(unsigned char)name[i];
  const wchar_t *value = _wgetenv(wide);
  free(wide);
  if (!value) return 0;
  size_t length = wcslen(value);
  *out = str_new(length);
  for (size_t i = 0; i < length; i++) out->units[i] = (uint16_t)value[i];
  out->length = length;
  return 1;
#else
  const char *value = getenv(name);
  if (!value || !is_utf8(value)) return 0;
  /* Valid UTF-8 (with surrogates allowed) decodes unit for unit. */
  const unsigned char *p = (const unsigned char *)value;
  *out = str_new(strlen(value));
  while (*p) {
    uint32_t c = *p++, need = 0;
    if (c >= 0xF0) need = 3, c &= 0x07;
    else if (c >= 0xE0) need = 2, c &= 0x0F;
    else if (c >= 0xC0) need = 1, c &= 0x1F;
    while (need--) c = (c << 6) | (*p++ & 0x3F);
    if (c >= 0x10000) {
      c -= 0x10000;
      out->units[out->length++] = (uint16_t)(0xD800 + (c >> 10));
      out->units[out->length++] = (uint16_t)(0xDC00 + (c & 0x3FF));
    } else {
      out->units[out->length++] = (uint16_t)c;
    }
  }
  return 1;
#endif
}

static ioi_string env_or_empty(const char *name) {
  ioi_string s;
  return env(name, &s) ? s : str_new(0);
}

/* A string of 1 to 18 decimal digits, or -1. */
static int64_t digits_value(ioi_string s) {
  if (!s.length || s.length > 18) return -1;
  int64_t value = 0;
  for (size_t i = 0; i < s.length; i++) {
    if (s.units[i] < '0' || s.units[i] > '9') return -1;
    value = value * 10 + (s.units[i] - '0');
  }
  return value;
}

static uint8_t *body;
static size_t body_length;
static int body_read;

/* The request body, read once from stdin: CONTENT_LENGTH bytes, or up to the end of input. */
static void read_body(void) {
  if (body_read) return;
  body_read = 1;
  ioi_string length_text = env_or_empty("CONTENT_LENGTH");
  int64_t length = digits_value(length_text);
  str_free(&length_text);
  size_t capacity = 64;
  body = checked(malloc(capacity));
  while (length < 0 || (int64_t)body_length < length) {
    int c = getchar();
    if (c == EOF) break;
    if (body_length == capacity) body = checked(realloc(body, capacity *= 2));
    body[body_length++] = (uint8_t)c;
  }
}

static uint16_t ascii_upper(uint16_t c) { return c >= 'a' && c <= 'z' ? c - 32 : c; }

static int is_blank(uint16_t c) { return c == ' ' || c == '\t'; }

/* A request header, as CGI passes it: HTTP_ and the name in capitals with - as _, except the two
 * it passes without the prefix. A name that isn't ASCII letters, digits, - and _ finds nothing. */
static int header(ioi_string name, ioi_string *out) {
  char key[256 + 6] = "HTTP_";
  if (name.length == 0 || name.length > 256) return 0;
  char *k = key + 5;
  for (size_t i = 0; i < name.length; i++) {
    uint16_t c = ascii_upper(name.units[i]);
    if (c == '-') c = '_';
    if (!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_')) return 0;
    k[i] = (char)c;
  }
  k[name.length] = 0;
  if (!strcmp(k, "CONTENT_TYPE") || !strcmp(k, "CONTENT_LENGTH")) return env(k, out);
  return env(key, out);
}

/* The units of [s] from [start] to [end], without spaces and tabs at either end. */
static ioi_string trimmed(ioi_string s, size_t start, size_t end) {
  while (start < end && is_blank(s.units[start])) start++;
  while (end > start && is_blank(s.units[end - 1])) end--;
  ioi_string out = str_new(end - start);
  memcpy(out.units, s.units + start, (end - start) * sizeof(uint16_t));
  out.length = end - start;
  return out;
}

static int cookie(ioi_string name, ioi_string *out) {
  ioi_string all = env_or_empty("HTTP_COOKIE");
  int found = 0;
  size_t start = 0;
  for (size_t i = 0; i <= all.length && !found; i++) {
    if (i < all.length && all.units[i] != ';') continue;
    for (size_t j = start; j < i; j++) {
      if (all.units[j] != '=') continue;
      ioi_string key = trimmed(all, start, j);
      if (str_equal(key, name)) {
        *out = trimmed(all, j + 1, i);
        found = 1;
      }
      str_free(&key);
      break;
    }
    start = i + 1;
  }
  str_free(&all);
  return found;
}

static int hex_digit(uint16_t c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

/* %XX is a byte and, with [plus], + is a space; then the bytes are decoded as str_decode does. */
static ioi_string url_decode(const uint8_t *bytes, size_t length, int plus) {
  uint8_t *out = checked(malloc(length + 1));
  size_t n = 0;
  for (size_t i = 0; i < length; i++) {
    int high = i + 2 < length ? hex_digit(bytes[i + 1]) : -1, low = i + 2 < length ? hex_digit(bytes[i + 2]) : -1;
    if (bytes[i] == '+' && plus) {
      out[n++] = ' ';
    } else if (bytes[i] == '%' && high >= 0 && low >= 0) {
      out[n++] = (uint8_t)(high * 16 + low);
      i += 2;
    } else {
      out[n++] = bytes[i];
    }
  }
  ioi_string s = str_decode(out, n);
  free(out);
  return s;
}

/* The first [name] in an application/x-www-form-urlencoded list of bytes, decoded. */
static int field(const uint8_t *encoded, size_t length, ioi_string name, ioi_string *out) {
  size_t start = 0;
  for (size_t i = 0; i <= length; i++) {
    if (i < length && encoded[i] != '&') continue;
    size_t equals = start;
    while (equals < i && encoded[equals] != '=') equals++;
    ioi_string key = url_decode(encoded + start, equals - start, 1);
    int match = str_equal(key, name);
    str_free(&key);
    if (match) {
      *out = equals < i ? url_decode(encoded + equals + 1, i - equals - 1, 1) : str_new(0);
      return 1;
    }
    start = i + 1;
  }
  return 0;
}

/* The body of a form post, or nothing (NULL) for any other kind of body. */
static const uint8_t *form(size_t *length) {
  ioi_string type = env_or_empty("CONTENT_TYPE");
  static const char form_type[] = "application/x-www-form-urlencoded";
  int is_form = type.length >= sizeof form_type - 1;
  for (size_t i = 0; is_form && i < sizeof form_type - 1; i++) {
    uint16_t c = type.units[i];
    is_form = (c >= 'A' && c <= 'Z' ? c + 32 : c) == form_type[i];
  }
  str_free(&type);
  *length = 0;
  if (!is_form) return NULL;
  read_body();
  *length = body_length;
  return body;
}

/* Stores a lookup's result: the string in [into] and status #1, or #2 when there is none. */
static void found(uint32_t status, uint32_t into, int was_found, ioi_string *value) {
  if (was_found) {
    ick_set_string(into, value->units, value->length);
    str_free(value);
  }
  ick_set_scalar(status, was_found ? 1 : 2);
}

/* ---- Strings in ;4400 and ;49221 (R5) ---------------------------------------------------- */

static ioi_string *params;
static size_t param_count;

typedef struct {
  uint64_t index;
  ioi_string value;
} ioi_arg;

static ioi_arg *args;
static size_t arg_count, arg_capacity;

/* ;4400 SUB n: a parameter the route doesn't have is E241. */
static ioi_string param(uint64_t n, uint32_t next) {
  if (n < 1 || n > param_count) ick_fatal(241, next);
  return str_copy(params[n - 1]);
}

/* ;49221 SUB n: one never stored is the empty string. */
static ioi_string arg(uint64_t n, uint32_t next) {
  if (n < 1 || n > 0xFFFFFFFFu) ick_fatal(241, next);
  for (size_t i = 0; i < arg_count; i++) {
    if (args[i].index == n) return str_copy(args[i].value);
  }
  return str_new(0);
}

/* Stores [value], which the arguments then own. */
static void set_arg(uint64_t n, ioi_string value, uint32_t next) {
  if (n < 1 || n > 0xFFFFFFFFu) ick_fatal(241, next);
  for (size_t i = 0; i < arg_count; i++) {
    if (args[i].index == n) {
      str_free(&args[i].value);
      args[i].value = value;
      return;
    }
  }
  if (arg_count == arg_capacity) {
    arg_capacity = arg_capacity ? arg_capacity * 2 : 8;
    args = checked(realloc(args, arg_capacity * sizeof *args));
  }
  args[arg_count++] = (ioi_arg){n, value};
}

static void set_string(uint32_t array, ioi_string value) {
  ick_set_string(array, value.units, value.length);
  str_free(&value);
}

/* ---- The response ------------------------------------------------------------------------ */

static uint64_t status = 200;
static int sent;

typedef struct {
  char *name, *value;
} ioi_header;

static ioi_header *headers;
static size_t header_count, header_capacity;

/* The status and headers can't change once the body has started (E823). */
static void unsent(uint32_t next) {
  if (sent) ick_fatal(823, next);
}

/* A header name is an HTTP token (RFC 9110). */
static int is_token(ioi_string s) {
  if (!s.length) return 0;
  for (size_t i = 0; i < s.length; i++) {
    uint16_t c = s.units[i];
    int ok = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
             (c < 0x80 && c && strchr("!#$%&'*+.^_`|~-", (char)c));
    if (!ok) return 0;
  }
  return 1;
}

/* A header value has no control characters but tabs, so it can't split the response. */
static int is_field_value(ioi_string s) {
  for (size_t i = 0; i < s.length; i++) {
    if ((s.units[i] < 0x20 && s.units[i] != '\t') || s.units[i] == 0x7F) return 0;
  }
  return 1;
}

/* RFC 6265's cookie-octet: ASCII with no controls, spaces, ", comma, ; or backslash, so a value
 * can't add attributes to its cookie. */
static int is_cookie_value(ioi_string s) {
  for (size_t i = 0; i < s.length; i++) {
    uint16_t c = s.units[i];
    if (!(c == 0x21 || (c >= 0x23 && c <= 0x2B) || (c >= 0x2D && c <= 0x3A) || (c >= 0x3C && c <= 0x5B) ||
          (c >= 0x5D && c <= 0x7E)))
      return 0;
  }
  return 1;
}

/* Adds a header that has been checked. The header takes the strings. */
static void add_header(ioi_string name, ioi_string value) {
  if (header_count == header_capacity) {
    header_capacity = header_capacity ? header_capacity * 2 : 8;
    headers = checked(realloc(headers, header_capacity * sizeof *headers));
  }
  headers[header_count++] = (ioi_header){str_utf8(name, NULL), str_utf8(value, NULL)};
  str_free(&name);
  str_free(&value);
}

static const char *reason(uint64_t code) {
  switch (code) {
  case 200: return "OK";
  case 201: return "Created";
  case 204: return "No Content";
  case 301: return "Moved Permanently";
  case 302: return "Found";
  case 303: return "See Other";
  case 304: return "Not Modified";
  case 307: return "Temporary Redirect";
  case 308: return "Permanent Redirect";
  case 400: return "Bad Request";
  case 401: return "Unauthorized";
  case 403: return "Forbidden";
  case 404: return "Not Found";
  case 405: return "Method Not Allowed";
  case 409: return "Conflict";
  case 410: return "Gone";
  case 418: return "I'm a teapot";
  case 422: return "Unprocessable Content";
  case 500: return "Internal Server Error";
  case 501: return "Not Implemented";
  case 503: return "Service Unavailable";
  default: return "Unknown";
  }
}

static int lower_equal(const char *a, const char *b) {
  for (; *a && *b; a++, b++) {
    char x = *a >= 'A' && *a <= 'Z' ? (char)(*a + 32) : *a;
    if (x != *b) return 0;
  }
  return !*a && !*b;
}

/* The CGI response's headers, before the first byte of its body (R2). */
static void prologue(void) {
  sent = 1;
  char line[64];
  int n = snprintf(line, sizeof line, "Status: %llu %s\n", (unsigned long long)status, reason(status));
  ick_output(line, (size_t)n);
  int typed = 0;
  for (size_t i = 0; i < header_count; i++) typed |= lower_equal(headers[i].name, "content-type");
  if (!typed) {
    static const char type[] = "Content-Type: text/html; charset=utf-8\n";
    ick_output(type, sizeof type - 1);
  }
  for (size_t i = 0; i < header_count; i++) {
    ick_output(headers[i].name, strlen(headers[i].name));
    ick_output(": ", 2);
    ick_output(headers[i].value, strlen(headers[i].value));
    ick_output("\n", 1);
  }
  ick_output("\n", 1);
}

/* ---- Services ---------------------------------------------------------------------------- */

static int petition(uint32_t service, const uint32_t *scalars, uint32_t scalar_count, const uint32_t *arrays,
                    uint32_t array_count, const uint64_t *values, uint32_t value_count, uint32_t next) {
  (void)scalar_count;
  (void)array_count;
  (void)value_count;
  ioi_string value;
  switch (service) {
  case 16001: set_string(arrays[0], env_or_empty("REQUEST_METHOD")); break;
  case 16010: set_string(arrays[0], env_or_empty("QUERY_STRING")); break;
  case 16020: {
    ioi_string name = str_array(arrays[0], next);
    int was = header(name, &value);
    str_free(&name);
    found(scalars[0], arrays[1], was, &value);
    break;
  }
  case 16030: {
    ioi_string name = str_array(arrays[0], next);
    int was = cookie(name, &value);
    str_free(&name);
    found(scalars[0], arrays[1], was, &value);
    break;
  }
  case 16040:
  case 16050: {
    size_t length;
    char *query = NULL;
    const uint8_t *encoded;
    if (service == 16040) {
      ioi_string text = env_or_empty("QUERY_STRING");
      query = str_utf8(text, &length);
      str_free(&text);
      encoded = (const uint8_t *)query;
    } else {
      encoded = form(&length);
    }
    ioi_string name = str_array(arrays[0], next);
    int was = field(encoded, length, name, &value);
    str_free(&name);
    free(query);
    found(scalars[0], arrays[1], was, &value);
    break;
  }
  case 16060: {
    read_body();
    ioi_string s = str_new(body_length);
    for (size_t i = 0; i < body_length; i++) s.units[i] = body[i];
    s.length = body_length;
    set_string(arrays[0], s);
    break;
  }
  case 16100:
    unsent(next);
    status = ick_scalar(scalars[0]);
    break;
  case 16110: {
    unsent(next);
    ioi_string name = str_array(arrays[0], next), v = str_array(arrays[1], next);
    if (!is_token(name) || !is_field_value(v)) ick_fatal(828, next);
    add_header(name, v);
    break;
  }
  case 16120: {
    unsent(next);
    ioi_string name = str_array(arrays[0], next), v = str_array(arrays[1], next);
    if (!is_token(name) || !is_cookie_value(v)) ick_fatal(828, next);
    ioi_string cookie_value = str_new(name.length + v.length + 9);
    memcpy(cookie_value.units, name.units, name.length * sizeof(uint16_t));
    cookie_value.length = name.length;
    cookie_value.units[cookie_value.length++] = '=';
    memcpy(cookie_value.units + cookie_value.length, v.units, v.length * sizeof(uint16_t));
    cookie_value.length += v.length;
    static const char path[] = "; Path=/";
    for (size_t i = 0; i < sizeof path - 1; i++) cookie_value.units[cookie_value.length++] = (uint16_t)path[i];
    str_free(&name);
    str_free(&v);
    add_header(str_ascii("Set-Cookie"), cookie_value);
    break;
  }
  case 16130: {
    unsent(next);
    ioi_string location = str_array(arrays[0], next);
    if (!is_field_value(location)) ick_fatal(828, next);
    status = 303;
    add_header(str_ascii("Location"), location);
    break;
  }
  case 16510: set_string(arrays[0], param(values[0], next)); break;
  case 16511: set_string(arrays[0], arg(values[0], next)); break;
  case 16512: set_arg(values[0], str_array(arrays[0], next), next); break;
  case 16513: set_arg(values[0], param(values[1], next), next); break;
  case 16514: set_arg(values[0], arg(values[1], next), next); break;
  case 16520: ick_fatal((uint32_t)values[0], next); break;
  default: return 0;
  }
  return 1;
}

/* ---- Routes (R3, Q113, Q114) ------------------------------------------------------------- */

typedef struct {
  ioi_string *items;
  size_t count;
} ioi_strings;

static void strings_free(ioi_strings *list) {
  for (size_t i = 0; i < list->count; i++) str_free(&list->items[i]);
  free(list->items);
  list->items = NULL;
  list->count = 0;
}

/* A raw path's segments, up to any ? or #, each percent-decoded; 0 unless it starts with /. */
static int segments_of(ioi_string raw, size_t from, ioi_strings *out) {
  size_t end = from;
  while (end < raw.length && raw.units[end] != '?' && raw.units[end] != '#') end++;
  if (from >= end || raw.units[from] != '/') return 0;
  size_t count = 1;
  for (size_t i = from + 1; i < end; i++) count += raw.units[i] == '/';
  out->items = checked(malloc(count * sizeof(ioi_string)));
  out->count = 0;
  size_t start = from + 1;
  for (size_t i = from + 1; i <= end; i++) {
    if (i < end && raw.units[i] != '/') continue;
    size_t length;
    char *bytes = str_utf8((ioi_string){raw.units + start, i - start}, &length);
    out->items[out->count++] = url_decode((const uint8_t *)bytes, length, 0);
    free(bytes);
    start = i + 1;
  }
  return 1;
}

static int scheme_char(uint16_t c, int first) {
  uint16_t lower = c | 32;
  if (lower >= 'a' && lower <= 'z') return 1;
  return !first && ((c >= '0' && c <= '9') || c == '+' || c == '.' || c == '-');
}

/* Where the scheme and authority of an absolute URL end (scheme://authority), or 0 if it has
 * none; [authority] is where the authority starts. */
static size_t after_authority(ioi_string s, size_t *authority) {
  size_t i = 0;
  while (i < s.length && scheme_char(s.units[i], i == 0)) i++;
  if (i == 0 || i + 3 > s.length || s.units[i] != ':' || s.units[i + 1] != '/' || s.units[i + 2] != '/') return 0;
  *authority = i + 3;
  for (i += 3; i < s.length && s.units[i] != '/' && s.units[i] != '?' && s.units[i] != '#'; i++) {
  }
  return i;
}

/* The request's path segments, decoded: from REQUEST_URI as sent, so that %2F stays inside its
 * segment, or failing that from PATH_INFO. */
static int request_path(ioi_strings *out) {
  ioi_string uri;
  if (env("REQUEST_URI", &uri)) {
    size_t authority, from = after_authority(uri, &authority);
    int ok = segments_of(uri, from, out);
    str_free(&uri);
    return ok;
  }
  ioi_string info = env_or_empty("PATH_INFO");
  size_t count = 1, start = 1;
  if (!info.length) {
    str_free(&info);
    info = str_ascii("/");
  }
  for (size_t i = 1; i < info.length; i++) count += info.units[i] == '/';
  out->items = checked(malloc(count * sizeof(ioi_string)));
  out->count = 0;
  for (size_t i = 1; i <= info.length; i++) {
    if (i < info.length && info.units[i] != '/') continue;
    ioi_string segment = str_new(i - start);
    memcpy(segment.units, info.units + start, (i - start) * sizeof(uint16_t));
    segment.length = i - start;
    out->items[out->count++] = segment;
    start = i + 1;
  }
  str_free(&info);
  return 1;
}

static uint16_t ascii_lower(uint16_t c) { return c >= 'A' && c <= 'Z' ? c + 32 : c; }

/* The Referer's path, when it is a page of this same host. */
static int referer_path(ioi_strings *out) {
  ioi_string referer, host;
  if (!env("HTTP_REFERER", &referer)) return 0;
  if (!env("HTTP_HOST", &host)) {
    str_free(&referer);
    return 0;
  }
  size_t authority = 0, end = after_authority(referer, &authority);
  int same = end && end - authority == host.length;
  for (size_t i = 0; same && i < host.length; i++) {
    same = ascii_lower(referer.units[authority + i]) == ascii_lower(host.units[i]);
  }
  int ok = 0;
  if (same) {
    if (end < referer.length && referer.units[end] == '/') {
      ok = segments_of(referer, end, out);
    } else {
      ioi_string root = str_ascii("/");
      ok = segments_of(root, 0, out);
      str_free(&root);
    }
  }
  str_free(&referer);
  str_free(&host);
  return ok;
}

/* The index of the route [segments] lead to, filling [values] with its parameters, or -1. */
static int32_t match(ioi_strings segments, ioi_strings *values) {
  for (uint32_t i = 0; i < ioi_route_count; i++) {
    const ioi_route *r = &ioi_routes[i];
    values->items = NULL;
    values->count = 0;
    if (r->segment_count < 0) return (int32_t)i;
    if ((size_t)r->segment_count != segments.count) continue;
    int fits = 1;
    for (int32_t j = 0; j < r->segment_count && fits; j++) {
      const ioi_segment *p = &r->segments[j];
      if (p->length >= 0) {
        fits = (size_t)p->length == segments.items[j].length &&
               (p->length == 0 || !memcmp(p->units, segments.items[j].units, (size_t)p->length * sizeof(uint16_t)));
      }
    }
    if (!fits) continue;
    values->items = checked(malloc((segments.count ? segments.count : 1) * sizeof(ioi_string)));
    for (int32_t j = 0; j < r->segment_count; j++) {
      if (r->segments[j].length < 0) values->items[values->count++] = str_copy(segments.items[j]);
    }
    return (int32_t)i;
  }
  return -1;
}

/* Where the request's route starts the program: no route is E440 (a 404 page), and a restricted
 * route whose Referer isn't a page that may link to it is E403. */
static uint32_t start(void) {
  ioi_strings path = {NULL, 0}, values = {NULL, 0};
  int32_t index = request_path(&path) ? match(path, &values) : -1;
  strings_free(&path);
  if (index < 0) ick_fatal(440, 1);
  const ioi_route *route = &ioi_routes[index];
  if (route->allowed_count >= 0) {
    ioi_strings referer = {NULL, 0}, ignored = {NULL, 0};
    int32_t from = referer_path(&referer) ? match(referer, &ignored) : -1;
    strings_free(&referer);
    strings_free(&ignored);
    int allowed = 0;
    for (int32_t i = 0; i < route->allowed_count && from >= 0; i++) allowed |= route->allowed[i] == (uint32_t)from;
    if (!allowed) ick_fatal(403, route->entry);
  }
  params = values.items;
  param_count = values.count;
  return route->entry;
}

static const ick_host ioi_host = {start, petition, prologue};

const ick_host *ick_create_host(void) { return &ioi_host; }
