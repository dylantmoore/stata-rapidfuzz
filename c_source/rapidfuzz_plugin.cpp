/*
 * rapidfuzz_plugin.cpp
 *
 * Stata C++ plugin wrapping the rapidfuzz-cpp header-only library.
 * Thin extern "C" interface — all algorithms come from the library.
 *
 * https://github.com/rapidfuzz/rapidfuzz-cpp  (MIT License)
 */

extern "C" {
#include "stplugin.h"
}

#include <rapidfuzz/rapidfuzz_all.hpp>
#include <string>
#include <vector>
#include <cstring>
#include <cstdio>
#include <cctype>
#include <algorithm>
#include <stdexcept>

#define MAX_STR_BUF 2048

/* Wrappers to silence string-literal-to-char* warnings from stplugin.h */
static void sf_error(const char *msg) { SF_error(const_cast<char*>(msg)); }
static void sf_display(const char *msg) { SF_display(const_cast<char*>(msg)); }

/* ================================================================
 * Method dispatch
 * ================================================================ */

enum Method {
    /* Fuzz metrics (0-100 similarity) */
    M_RATIO, M_PARTIAL_RATIO,
    M_TOKEN_SORT, M_PARTIAL_TOKEN_SORT,
    M_TOKEN_SET, M_PARTIAL_TOKEN_SET,
    M_TOKEN_RATIO, M_PARTIAL_TOKEN_RATIO,
    M_WRATIO, M_QRATIO,
    /* Distance metrics (normalized similarity 0-100) */
    M_JARO, M_JARO_WINKLER,
    M_NORM_LEV, M_NORM_OSA,
    M_NORM_HAMMING, M_NORM_INDEL, M_NORM_LCSSEQ,
    /* Distance metrics (raw count) */
    M_LEVENSHTEIN, M_OSA,
    M_HAMMING, M_INDEL, M_LCSSEQ,
    M_INVALID
};

static Method parse_method(const char *name) {
    /* fuzz */
    if (!strcmp(name, "ratio"))              return M_RATIO;
    if (!strcmp(name, "partial_ratio"))      return M_PARTIAL_RATIO;
    if (!strcmp(name, "token_sort"))         return M_TOKEN_SORT;
    if (!strcmp(name, "partial_token_sort")) return M_PARTIAL_TOKEN_SORT;
    if (!strcmp(name, "token_set"))          return M_TOKEN_SET;
    if (!strcmp(name, "partial_token_set"))  return M_PARTIAL_TOKEN_SET;
    if (!strcmp(name, "token_ratio"))        return M_TOKEN_RATIO;
    if (!strcmp(name, "partial_token_ratio"))return M_PARTIAL_TOKEN_RATIO;
    if (!strcmp(name, "wratio"))             return M_WRATIO;
    if (!strcmp(name, "qratio"))             return M_QRATIO;
    /* normalized similarity */
    if (!strcmp(name, "jaro"))               return M_JARO;
    if (!strcmp(name, "jaro_winkler"))       return M_JARO_WINKLER;
    if (!strcmp(name, "norm_lev"))           return M_NORM_LEV;
    if (!strcmp(name, "norm_osa"))           return M_NORM_OSA;
    if (!strcmp(name, "norm_hamming"))       return M_NORM_HAMMING;
    if (!strcmp(name, "norm_indel"))         return M_NORM_INDEL;
    if (!strcmp(name, "norm_lcsseq"))        return M_NORM_LCSSEQ;
    /* raw distance */
    if (!strcmp(name, "levenshtein"))        return M_LEVENSHTEIN;
    if (!strcmp(name, "osa"))                return M_OSA;
    if (!strcmp(name, "hamming"))            return M_HAMMING;
    if (!strcmp(name, "indel"))              return M_INDEL;
    if (!strcmp(name, "lcsseq"))             return M_LCSSEQ;
    return M_INVALID;
}

static bool is_similarity_method(Method m) {
    return m <= M_NORM_LCSSEQ;
}

/*
 * Compute score for a single string pair.
 * Similarity metrics return 0-100; distance metrics return raw counts.
 * Returns SV_missval on error (e.g., hamming with unequal lengths).
 */
static double compute_score(const std::string &s1, const std::string &s2,
                            Method method, double prefix_weight) {
    using namespace rapidfuzz;
    try {
        switch (method) {
        /* fuzz — already 0-100 */
        case M_RATIO:              return fuzz::ratio(s1, s2);
        case M_PARTIAL_RATIO:      return fuzz::partial_ratio(s1, s2);
        case M_TOKEN_SORT:         return fuzz::token_sort_ratio(s1, s2);
        case M_PARTIAL_TOKEN_SORT: return fuzz::partial_token_sort_ratio(s1, s2);
        case M_TOKEN_SET:          return fuzz::token_set_ratio(s1, s2);
        case M_PARTIAL_TOKEN_SET:  return fuzz::partial_token_set_ratio(s1, s2);
        case M_TOKEN_RATIO:        return fuzz::token_ratio(s1, s2);
        case M_PARTIAL_TOKEN_RATIO:return fuzz::partial_token_ratio(s1, s2);
        case M_WRATIO:             return fuzz::WRatio(s1, s2);
        case M_QRATIO:             return fuzz::QRatio(s1, s2);

        /* normalized similarity (0-1) → scale to 0-100 */
        case M_JARO:         return jaro_similarity(s1, s2)          * 100.0;
        case M_JARO_WINKLER: return jaro_winkler_similarity(s1, s2, prefix_weight) * 100.0;
        case M_NORM_LEV:     return levenshtein_normalized_similarity(s1, s2) * 100.0;
        case M_NORM_OSA:     return osa_normalized_similarity(s1, s2) * 100.0;
        case M_NORM_HAMMING: return hamming_normalized_similarity(s1, s2) * 100.0;
        case M_NORM_INDEL:   return indel_normalized_similarity(s1, s2) * 100.0;
        case M_NORM_LCSSEQ:  return lcs_seq_normalized_similarity(s1, s2) * 100.0;

        /* raw distance counts */
        case M_LEVENSHTEIN: return (double)levenshtein_distance(s1, s2);
        case M_OSA:         return (double)osa_distance(s1, s2);
        case M_HAMMING:     return (double)hamming_distance(s1, s2);
        case M_INDEL:       return (double)indel_distance(s1, s2);
        case M_LCSSEQ:      return (double)lcs_seq_distance(s1, s2);

        default: return SV_missval;
        }
    } catch (...) {
        return SV_missval;
    }
}

/* ================================================================
 * String helpers
 * ================================================================ */

static std::string read_string(ST_int var, ST_int obs) {
    char buf[MAX_STR_BUF];
    buf[0] = '\0';
    SF_sdata(var, obs, buf);
    return std::string(buf);
}

static std::string to_lower(const std::string &s) {
    std::string out(s);
    std::transform(out.begin(), out.end(), out.begin(),
                   [](unsigned char c){ return std::tolower(c); });
    return out;
}

/* ================================================================
 * Pairwise mode
 *
 * Variables: str1  str2  output_score
 * argv:      "pairwise" method [nocase] [pw=0.1]
 * ================================================================ */

static ST_retcode do_pairwise(int argc, char *argv[]) {
    if (argc < 2) {
        sf_error("rapidfuzz pairwise: requires method argument\n");
        return 198;
    }

    Method method = parse_method(argv[1]);
    if (method == M_INVALID) {
        char buf[256];
        snprintf(buf, sizeof(buf), "rapidfuzz: unknown method '%s'\n", argv[1]);
        sf_error(buf);
        return 198;
    }

    bool nocase = false;
    double pw = 0.1;
    for (int a = 2; a < argc; a++) {
        if (!strcmp(argv[a], "nocase")) nocase = true;
        else if (!strncmp(argv[a], "pw=", 3)) pw = atof(argv[a] + 3);
    }

    ST_int nobs = SF_nobs();
    if (SF_nvar() != 3) {
        sf_error("rapidfuzz pairwise: need exactly 3 variables\n");
        return 198;
    }

    for (ST_int obs = 1; obs <= nobs; obs++) {
        std::string s1 = read_string(1, obs);
        std::string s2 = read_string(2, obs);
        if (nocase) { s1 = to_lower(s1); s2 = to_lower(s2); }

        double score = compute_score(s1, s2, method, pw);
        SF_vstore(3, obs, score);
    }
    return 0;
}

/* ================================================================
 * Match mode
 *
 * Variables: str_all  best_score  best_idx
 * argv:      "match" method n_master n_ref [nocase] [pw=0.1]
 *
 * Obs 1..n_master = master, (n_master+1)..(n_master+n_ref) = reference.
 * For each master obs, finds the best-scoring reference obs.
 * ================================================================ */

static ST_retcode do_match(int argc, char *argv[]) {
    if (argc < 4) {
        sf_error("rapidfuzz match: requires method, n_master, n_ref\n");
        return 198;
    }

    Method method = parse_method(argv[1]);
    if (method == M_INVALID) {
        char buf[256];
        snprintf(buf, sizeof(buf), "rapidfuzz: unknown method '%s'\n", argv[1]);
        sf_error(buf);
        return 198;
    }

    int n_master = atoi(argv[2]);
    int n_ref    = atoi(argv[3]);
    bool nocase = false;
    double pw = 0.1;
    for (int a = 4; a < argc; a++) {
        if (!strcmp(argv[a], "nocase")) nocase = true;
        else if (!strncmp(argv[a], "pw=", 3)) pw = atof(argv[a] + 3);
    }

    if (SF_nobs() != n_master + n_ref) {
        sf_error("rapidfuzz match: observation count mismatch\n");
        return 198;
    }

    bool higher_better = is_similarity_method(method);

    /* Read all strings into memory */
    std::vector<std::string> master(n_master), ref(n_ref);
    for (int i = 0; i < n_master; i++) {
        master[i] = read_string(1, i + 1);
        if (nocase) master[i] = to_lower(master[i]);
    }
    for (int j = 0; j < n_ref; j++) {
        ref[j] = read_string(1, n_master + j + 1);
        if (nocase) ref[j] = to_lower(ref[j]);
    }

    int report_every = n_master / 10;
    if (report_every < 1) report_every = 1;

    for (int i = 0; i < n_master; i++) {
        double best = higher_better ? -1.0 : 1e18;
        int best_j = 0;

        for (int j = 0; j < n_ref; j++) {
            double s = compute_score(master[i], ref[j], method, pw);
            if (SF_is_missing(s)) continue;

            if (higher_better ? (s > best) : (s < best)) {
                best = s;
                best_j = j;
            }
        }

        SF_vstore(2, i + 1, best);
        SF_vstore(3, i + 1, (double)(best_j + 1));

        if ((i + 1) % report_every == 0) {
            char msg[128];
            snprintf(msg, sizeof(msg), "  matched %d of %d\n", i + 1, n_master);
            sf_display(msg);
        }
    }
    return 0;
}

/* ================================================================
 * Entry point — exception-safe boundary
 *
 * STDLL already expands to `extern "C" ST_retcode`, so no extra
 * extern "C" wrapper needed.
 * ================================================================ */

STDLL stata_call(int argc, char *argv[]) {
    if (argc < 1) {
        sf_error("rapidfuzz: requires mode (pairwise or match)\n");
        return 198;
    }

    try {
        if (!strcmp(argv[0], "pairwise")) return do_pairwise(argc, argv);
        if (!strcmp(argv[0], "match"))    return do_match(argc, argv);

        char buf[256];
        snprintf(buf, sizeof(buf), "rapidfuzz: unknown mode '%s'\n", argv[0]);
        sf_error(buf);
        return 198;

    } catch (const std::exception &e) {
        char buf[512];
        snprintf(buf, sizeof(buf), "rapidfuzz: %s\n", e.what());
        sf_error(buf);
        return 909;
    } catch (...) {
        sf_error("rapidfuzz: unknown C++ exception\n");
        return 909;
    }
}
