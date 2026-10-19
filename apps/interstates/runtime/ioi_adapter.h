/* ActiveCassette's adapter interface (R7, Q146), version 1.
 *
 * An adapter connects ActiveCassette to one kind of database. Every Interstates program can use one,
 * whichever compiler built it: ioi-llvm programs call it natively and ioi-dart programs through
 * dart:ffi. SQLite's adapter is built in; any other is a shared library that exports
 * ioi_adapter_entry, and a program uses it for a DATABASE_URL whose scheme is SCHEME when the
 * environment variable IOI_ADAPTER_SCHEME (the scheme in capitals) names the library.
 *
 * ActiveCassette sends standard SQL: identifiers in double quotes, and each value a ? parameter, in
 * order. An adapter whose database spells either differently translates them. */
#ifndef IOI_ADAPTER_H
#define IOI_ADAPTER_H

#include <stddef.h>
#include <stdint.h>

#define IOI_ADAPTER_VERSION 1

enum { IOI_NULL = 0, IOI_INTEGER = 1, IOI_TEXT = 2 };

/* A parameter or a column's value. Text is UTF-8, of [length] bytes, not NUL-terminated. */
typedef struct {
  int32_t kind;
  int64_t integer;
  const char *text;
  size_t length;
} ioi_value;

typedef struct {
  /* IOI_ADAPTER_VERSION. */
  uint32_t version;
  /* A connection for [url] (the whole DATABASE_URL), or NULL; error(NULL) then says why. */
  void *(*connect)(const char *url);
  /* Why the last call on [db] failed, as UTF-8, until the next call; NULL when it didn't. */
  const char *(*error)(void *db);
  void (*disconnect)(void *db);
  /* Rows of one text column: the database's tables, in its own order (the order they were made,
   * where it has one). NULL on failure. */
  void *(*tables)(void *db);
  /* Rows of one text column: [table]'s columns, in order. NULL on failure. */
  void *(*columns)(void *db, const char *table);
  /* Runs [sql] with its [count] parameters. The rows it returns, if any, come from next; a
   * statement that returns none gives rows with none. NULL on failure. */
  void *(*query)(void *db, const char *sql, const ioi_value *params, size_t count);
  /* Moves to the next row: 1 for a row, 0 at the end, -1 on failure (error says why). */
  int (*next)(void *rows);
  /* How many columns each row has. */
  size_t (*width)(void *rows);
  /* Column [i] of the current row, in [out], valid until the next call on [rows]. */
  void (*column)(void *rows, size_t i, ioi_value *out);
  /* Ends the rows, a query's or a statement's. */
  void (*finish)(void *rows);
  /* How many rows the last statement on [db] inserted, changed or deleted. */
  int64_t (*changes)(void *db);
} ioi_adapter;

/* What a user adapter's shared library exports. */
const ioi_adapter *ioi_adapter_entry(void);

#endif
