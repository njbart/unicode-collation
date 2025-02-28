# unicode-collation

[![GitHub
CI](https://github.com/jgm/unicode-collation/workflows/CI%20tests/badge.svg)](https://github.com/jgm/unicode-collation/actions)
[![Hackage](https://img.shields.io/hackage/v/unicode-collation.svg?logo=haskell)](https://hackage.haskell.org/package/unicode-collation)
[![BSD-2-Clause license](https://img.shields.io/badge/license-BSD--2--Clause-blue.svg)](LICENSE)

Haskell implementation of [unicode collation algorithm].

[unicode collation algorithm]:  https://www.unicode.org/reports/tr10

## Motivation

Previously there was no way to do correct unicode collation
(sorting) in Haskell without depending on the C library `icu`
and the barely maintained Haskell wrapper `text-icu`.  This
library offers a pure Haskell solution.

## Conformance

The library passes UCA conformance tests (except for tests
involving unmatched surrogates and a few Tibetan characters,
which seem to be changed in unexpected ways by Text.pack or
normalization).

Locale-specific tailorings are supported, but in a limited
way.  We do not yet support `[reorder..]`.

## Performance

```
  sort a list of 10000 random Texts: OK (2.21s)
    8.2 ms ± 637 μs,  27 MB allocated, 903 KB copied
  sort same list with text-icu:      OK (2.10s)
    2.0 ms ± 114 μs, 7.1 MB allocated, 148 KB copied
```

## Data files

Version 13.0.0 of the Unicode data is used:
<http://www.unicode.org/Public/UCA/13.0.0/>

Locale-specific tailorings are taken from
<http://unicode.org/Public/cdr/38.1/>
(download the zip and extract the collation subdirectory).

## Executable

The package includes an executable component, `unicode-collate`,
which may be used for testing and for collating in scripts.
For usage instructions, `unicode-collate --help`.

## References

- Unicode Technical Standard #35:
  Unicode Locale Data Markup Language (LDML):
  <http://www.unicode.org/reports/tr35/>
- Unicode Technical Standard #10:
  Unicode Collation Algorithm:
  <https://www.unicode.org/reports/tr10>

