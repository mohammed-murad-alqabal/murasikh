# ChromaDB Security Advisory Evidence

**Repository:** `mohammed-murad-alqabal/murasikh`  
**Affected dependency:** `chromadb==1.5.9`  
**Advisories:**

| Advisory | Severity | Affected range | Fix status at review time |
|---|---|---|---|
| GHSA-f4j7-r4q5-qw2c / CVE-2026-45829 | Critical | `>=1.0.0` through `1.5.9` | No patched PyPI release reported |
| GHSA-36p7-vc44-83pf / CVE-2026-45833 | Critical | `>=0.4.17` through `1.5.9` | No patched PyPI release reported |
| GHSA-xph7-9rjv-w5fr / CVE-2026-45831 | High | `>=0.5.0` through `1.5.9` | No patched PyPI release reported |
| GHSA-2wm9-hf6c-p5cr / CVE-2026-45830 | High | `>=0.4.17` through `1.5.9` | No patched PyPI release reported |

The project uses `chromadb.PersistentClient` for a local embedded vector store and does not start a Chroma server or use `chromadb.HttpClient`. The dependency is therefore pinned to `0.4.16`, the last release before the affected `0.4.17+` ranges, until an upstream patched release is available.

ChromaDB 0.4.16 uses NumPy APIs removed in NumPy 2.x. The requirements therefore pin NumPy to `1.26.4` and use the compatible audio-analysis set `librosa==0.10.2.post1`, `numba==0.59.1`, `llvmlite==0.42.0`, and `scipy==1.11.4` so the complete Backend dependency set remains resolvable.

The CI pipeline also runs `pip-audit` against `backend/requirements.txt` so future vulnerable dependency resolutions fail the build instead of remaining silent.

## Sources

- [GitHub Advisory Database: GHSA-f4j7-r4q5-qw2c](https://github.com/advisories/GHSA-f4j7-r4q5-qw2c)
- [GitHub Advisory Database: GHSA-36p7-vc44-83pf](https://github.com/advisories/GHSA-36p7-vc44-83pf)
- [GitHub Advisory Database: GHSA-xph7-9rjv-w5fr](https://github.com/advisories/GHSA-xph7-9rjv-w5fr)
- [GitHub Advisory Database: GHSA-2wm9-hf6c-p5cr](https://github.com/advisories/GHSA-2wm9-hf6c-p5cr)
- [OSV vulnerability API](https://api.osv.dev/v1/vulns/GHSA-f4j7-r4q5-qw2c)
- [ChromaDB 0.4.16 package metadata](https://pypi.org/pypi/chromadb/0.4.16/json)
