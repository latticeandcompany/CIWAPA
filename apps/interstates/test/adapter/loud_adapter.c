/* A user adapter for the tests: SQLite's own adapter under the scheme loud:, which writes each
 * statement it runs to stderr, so a test can see that ActiveCassette went through it. */
/* SQLite sets its feature macros before any system header, so it comes first. */
#include "activecassette.c"

#include <stdio.h>
#include <string.h>

#ifdef _WIN32
#define LOUD_EXPORT __declspec(dllexport)
#else
#define LOUD_EXPORT __attribute__((visibility("default")))
#endif

static const ioi_adapter *quiet;
static ioi_adapter loud;

static void *loud_connect(const char *url) {
  if (strncmp(url, "loud:", 5) != 0) return NULL;
  char sqlite_url[4096];
  snprintf(sqlite_url, sizeof sqlite_url, "sqlite:%s", url + 5);
  fprintf(stderr, "loud: connect %s\n", url + 5);
  return quiet->connect(sqlite_url);
}

static void *loud_query(void *db, const char *sql, const ioi_value *params, size_t count) {
  fprintf(stderr, "loud: %s (%u parameters)\n", sql, (unsigned)count);
  return quiet->query(db, sql, params, count);
}

LOUD_EXPORT const ioi_adapter *ioi_adapter_entry(void) {
  quiet = ioi_sqlite_adapter();
  loud = *quiet;
  loud.connect = loud_connect;
  loud.query = loud_query;
  return &loud;
}
