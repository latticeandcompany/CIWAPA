/* ActiveCassette's built-in SQLite adapter (R7, Q95, Q99). It is compiled together with the SQLite
 * amalgamation: into ioi-llvm programs, and into the shared library ioi-dart programs load. A
 * DATABASE_URL of sqlite:path opens (or makes) the file at path. */
#include <stdlib.h>
#include <string.h>

#include "ioi_adapter.h"
#include "sqlite3.h"

#ifdef _WIN32
#define IOI_EXPORT __declspec(dllexport)
#else
#define IOI_EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
  sqlite3 *db;
  char *error;
  int64_t changes;
} connection;

typedef struct {
  connection *c;
  sqlite3_stmt *statement;
  int done;
  /* Whether finishing it sets changes: only for the statements a program runs. */
  int counts;
  int64_t total;
} rows;

static char *connect_error;

static void set_error(char **slot, const char *message) {
  free(*slot);
  *slot = NULL;
  if (!message) return;
  size_t n = strlen(message);
  *slot = malloc(n + 1);
  if (*slot) memcpy(*slot, message, n + 1);
}

static void *sqlite_connect(const char *url) {
  set_error(&connect_error, NULL);
  if (strncmp(url, "sqlite:", 7) != 0 || strncmp(url, "sqlite://", 9) == 0) {
    set_error(&connect_error, "a sqlite URL is sqlite:path, such as sqlite:./app.db or sqlite:/srv/app.db");
    return NULL;
  }
  connection *c = calloc(1, sizeof *c);
  if (!c) return NULL;
  if (sqlite3_open_v2(url + 7, &c->db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL) != SQLITE_OK) {
    set_error(&connect_error, c->db ? sqlite3_errmsg(c->db) : "out of memory");
    sqlite3_close(c->db);
    free(c);
    return NULL;
  }
  sqlite3_busy_timeout(c->db, 5000);
  /* SQLite opens lazily, so a file that isn't a database would otherwise fail its first statement. */
  if (sqlite3_exec(c->db, "SELECT 1 FROM sqlite_schema LIMIT 0", NULL, NULL, NULL) != SQLITE_OK) {
    set_error(&connect_error, sqlite3_errmsg(c->db));
    sqlite3_close(c->db);
    free(c);
    return NULL;
  }
  return c;
}

static const char *sqlite_error(void *db) { return db ? ((connection *)db)->error : connect_error; }

static void sqlite_disconnect(void *db) {
  connection *c = db;
  sqlite3_close(c->db);
  free(c->error);
  free(c);
}

static void *run(connection *c, const char *sql, const ioi_value *params, size_t count, int counts) {
  set_error(&c->error, NULL);
  sqlite3_stmt *statement;
  const char *tail;
  if (sqlite3_prepare_v2(c->db, sql, -1, &statement, &tail) != SQLITE_OK) {
    set_error(&c->error, sqlite3_errmsg(c->db));
    return NULL;
  }
  while (*tail == ' ' || *tail == '\t' || *tail == '\r' || *tail == '\n' || *tail == ';') tail++;
  if (!statement || *tail) {
    set_error(&c->error, statement ? "one statement at a time" : "no statement");
    sqlite3_finalize(statement);
    return NULL;
  }
  for (size_t i = 0; i < count; i++) {
    int at = (int)i + 1, status;
    switch (params[i].kind) {
    case IOI_INTEGER: status = sqlite3_bind_int64(statement, at, params[i].integer); break;
    case IOI_TEXT:
      status = sqlite3_bind_text64(statement, at, params[i].text, params[i].length, SQLITE_TRANSIENT, SQLITE_UTF8);
      break;
    default: status = sqlite3_bind_null(statement, at); break;
    }
    if (status != SQLITE_OK) {
      set_error(&c->error, sqlite3_errmsg(c->db));
      sqlite3_finalize(statement);
      return NULL;
    }
  }
  rows *r = calloc(1, sizeof *r);
  if (!r) {
    sqlite3_finalize(statement);
    return NULL;
  }
  r->c = c;
  r->statement = statement;
  r->counts = counts;
  r->total = sqlite3_total_changes64(c->db);
  /* A statement that returns no rows runs now, so its changes count even if nobody steps it. */
  if (sqlite3_column_count(statement) == 0) {
    int status = sqlite3_step(statement);
    r->done = 1;
    if (status != SQLITE_DONE && status != SQLITE_ROW) {
      set_error(&c->error, sqlite3_errmsg(c->db));
      sqlite3_finalize(statement);
      free(r);
      return NULL;
    }
  }
  return r;
}

static void *sqlite_query(void *db, const char *sql, const ioi_value *params, size_t count) {
  return run(db, sql, params, count, 1);
}

static void *sqlite_tables(void *db) {
  return run(db,
             "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' ORDER BY rowid",
             NULL, 0, 0);
}

/* The columns SELECT * returns, generated ones included, in its order. */
static void *sqlite_columns(void *db, const char *table) {
  ioi_value name = {IOI_TEXT, 0, table, strlen(table)};
  return run(db, "SELECT name FROM pragma_table_xinfo(?) WHERE hidden <> 1 ORDER BY cid", &name, 1, 0);
}

static int sqlite_next(void *handle) {
  rows *r = handle;
  if (r->done) return 0;
  int status = sqlite3_step(r->statement);
  if (status == SQLITE_ROW) return 1;
  r->done = 1;
  if (status == SQLITE_DONE) return 0;
  set_error(&r->c->error, sqlite3_errmsg(r->c->db));
  return -1;
}

static size_t sqlite_width(void *handle) { return (size_t)sqlite3_column_count(((rows *)handle)->statement); }

static void sqlite_column(void *handle, size_t i, ioi_value *out) {
  sqlite3_stmt *s = ((rows *)handle)->statement;
  int at = (int)i;
  switch (sqlite3_column_type(s, at)) {
  case SQLITE_NULL: *out = (ioi_value){IOI_NULL, 0, NULL, 0}; break;
  case SQLITE_INTEGER: *out = (ioi_value){IOI_INTEGER, sqlite3_column_int64(s, at), NULL, 0}; break;
  default: {
    const unsigned char *text = sqlite3_column_text(s, at);
    *out = (ioi_value){IOI_TEXT, 0, (const char *)text, (size_t)sqlite3_column_bytes(s, at)};
  }
  }
}

static void sqlite_finish(void *handle) {
  rows *r = handle;
  sqlite3_finalize(r->statement);
  /* sqlite3_changes64 keeps the last INSERT, UPDATE or DELETE's count through any other statement. */
  if (r->counts) {
    r->c->changes = sqlite3_total_changes64(r->c->db) == r->total ? 0 : sqlite3_changes64(r->c->db);
  }
  free(r);
}

static int64_t sqlite_changes(void *db) { return ((connection *)db)->changes; }

static const ioi_adapter adapter = {
    IOI_ADAPTER_VERSION, sqlite_connect, sqlite_error,  sqlite_disconnect, sqlite_tables, sqlite_columns,
    sqlite_query,        sqlite_next,    sqlite_width,  sqlite_column,     sqlite_finish, sqlite_changes,
};

IOI_EXPORT const ioi_adapter *ioi_sqlite_adapter(void) { return &adapter; }
