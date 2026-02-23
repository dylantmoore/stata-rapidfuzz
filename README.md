# stata-rapidfuzz

String similarity and fuzzy matching for Stata, powered by [rapidfuzz-cpp](https://github.com/rapidfuzz/rapidfuzz-cpp).

This package wraps the rapidfuzz-cpp header-only C++ library as a Stata plugin, providing 22 string similarity and distance algorithms with native performance.

## Installation

```stata
net install rapidfuzz, from("https://raw.githubusercontent.com/dylantmoore/stata-rapidfuzz/main") replace
```

## Commands

### `rapidfuzz` — Pairwise comparison

Computes string similarity between two variables, observation by observation.

```stata
rapidfuzz name1 name2, gen(score) method(jaro_winkler) nocase
```

### `rapidfuzz_match` — Fuzzy matching

Finds the best match for each observation against a reference dataset.

```stata
rapidfuzz_match name using "reference.dta", gen(score matched_name) method(jaro_winkler) nocase threshold(80)
```

## Methods

**Similarity metrics** (0 = no match, 100 = identical):

| Method | Description |
|--------|-------------|
| `ratio` | Normalized Indel similarity (default) |
| `partial_ratio` | Best substring match |
| `token_sort` | Sorts words before comparing |
| `partial_token_sort` | Partial ratio after sorting words |
| `token_set` | Handles extra words gracefully |
| `partial_token_set` | Partial ratio on word sets |
| `token_ratio` | Best of ratio and token_sort |
| `partial_token_ratio` | Best of partial variants |
| `wratio` | Weighted combination of methods |
| `qratio` | Quick ratio |
| `jaro` | Jaro similarity |
| `jaro_winkler` | Jaro with prefix bonus |
| `norm_lev` | Normalized Levenshtein similarity |
| `norm_osa` | Normalized OSA similarity |
| `norm_hamming` | Normalized Hamming similarity |
| `norm_indel` | Normalized Indel similarity |
| `norm_lcsseq` | Normalized LCS similarity |

**Distance metrics** (lower = more similar):

| Method | Description |
|--------|-------------|
| `levenshtein` | Edit distance (insert/delete/substitute) |
| `osa` | Optimal String Alignment distance |
| `hamming` | Positional differences (equal-length only) |
| `indel` | Insertion/deletion distance |
| `lcsseq` | Longest common subsequence distance |

## Options

| Option | Description |
|--------|-------------|
| `generate(name)` | Output variable name (required) |
| `method(string)` | Algorithm to use; default `ratio` |
| `nocase` | Case-insensitive comparison |
| `replace` | Overwrite existing output variable |
| `prefix_weight(#)` | Jaro-Winkler prefix weight (default 0.1) |
| `threshold(#)` | Minimum score for `rapidfuzz_match` |
| `uvar(varname)` | String variable name in using dataset |

## Platforms

Pre-built binaries are included for:
- macOS Apple Silicon (arm64)
- macOS Intel (x86_64)
- Linux x86_64
- Windows x86_64

## Building from source

```bash
cd c_source
python3 build.py          # Build for current platform
python3 build.py --all    # Build for all platforms
python3 build.py --debug  # Build with sanitizers
```

Requires: `stplugin.h` and `stplugin.c` from [stata.com/plugins](https://www.stata.com/plugins/), and the vendored `rapidfuzz/` headers (already included).

## Testing

```bash
cd tests
python3 generate_test_data.py   # Generate reference data
```

Then in Stata:
```stata
cd tests
do test_rapidfuzz.do
```

## Credits

- [rapidfuzz-cpp](https://github.com/rapidfuzz/rapidfuzz-cpp) by Max Bachmann (MIT License)
- Built with [Claude Code](https://claude.ai/claude-code) using the [stata-skill](https://github.com/dylantmoore/stata-skill) C plugins skill

## License

MIT
