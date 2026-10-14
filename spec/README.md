# Spec

The INTERCAL reference manual below is the primary source of truth for CIWAPA. It is licensed under the GPL, so it isn't committed here. Download it into this folder (`spec/*.pdf` is gitignored) and check the hash:

```sh
curl -fsSL -o spec/intercal.pdf https://www.cs.virginia.edu/~asb/teaching/cs415-fall05/docs/intercal.pdf
shasum -a 256 spec/intercal.pdf
```

| | |
|---|---|
| Title | The INTERCAL Programming Language Revised Reference Manual (Donald R. Woods and James M. Lyon) |
| Edition | C-INTERCAL 0.15 (revisions by Louis Howell and Eric S. Raymond, 1996) |
| License | GPL |
| Redistribution | University of Virginia, CS 415, Fall 2005 |
| Origin URL | https://www.cs.virginia.edu/~asb/teaching/cs415-fall05/docs/intercal.pdf |
| Created | 2005-12-04 (groff 1.10 / ESP Ghostscript 815.0) |
| Pages | 43 |
| SHA-256 | `793b6c1e6483640b76543396657bbbfade8fdc051477816dc976638330ba62b2` |

Don't edit the PDF. Every rule it defines is a checkbox in [`docs/SPEC_CHECKLIST.md`](../docs/SPEC_CHECKLIST.md), and every interpretation is recorded in [`docs/SPEC_DECISIONS.md`](../docs/SPEC_DECISIONS.md).

The system library listing in §8.3 is off limits to anyone working on CIWAPA's own library, which is a clean-room implementation written only from the §7.2 routine descriptions.
