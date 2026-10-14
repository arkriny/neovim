#pragma once

// TODO(arkriny): remove completely
#define _(x) ((char *)(x))  // NOLINT(bugprone-reserved-identifier)
#define N_(x) x
#define NGETTEXT(x, xs, n) ((n) == 1 ? (x) : (xs))
#define bindtextdomain(x, y)  // empty
#define bind_textdomain_codeset(x, y)  // empty
#define textdomain(x)  // empty
