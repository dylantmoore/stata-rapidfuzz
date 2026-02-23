#!/usr/bin/env python3
"""
Generate reference test data using Python rapidfuzz.

Produces CSV files with known inputs and expected outputs
for validating the Stata plugin against the Python reference.

Requirements:
    pip install rapidfuzz==3.6.1 pandas==2.2.0
"""

import csv
import sys

try:
    from rapidfuzz import fuzz, distance
except ImportError:
    print("ERROR: pip install rapidfuzz==3.6.1")
    sys.exit(1)


def generate_pairwise_tests():
    """Generate pairwise comparison test cases."""
    pairs = [
        # Basic cases
        ("hello", "hello"),
        ("hello", "world"),
        ("", ""),
        ("abc", ""),
        ("", "xyz"),

        # Typos and edits
        ("kitten", "sitting"),
        ("Saturday", "Sunday"),
        ("Robert", "Rupert"),

        # Name matching (common use case)
        ("John Smith", "John Smyth"),
        ("John Smith", "Smith John"),
        ("JOHN SMITH", "john smith"),
        ("John A. Smith", "John Smith"),
        ("John Smith Jr.", "John Smith"),
        ("McDonald's", "McDonalds"),
        ("St. Louis", "Saint Louis"),

        # Company names
        ("Apple Inc.", "Apple Incorporated"),
        ("IBM", "International Business Machines"),
        ("AT&T", "AT&T Inc."),
        ("Walmart", "Wal-Mart"),
        ("JP Morgan Chase", "JPMorgan Chase & Co"),

        # Edge cases
        ("a", "b"),
        ("a", "a"),
        ("ab", "ba"),
        ("abc", "cab"),
        ("abcdef", "fedcba"),

        # Unicode-like (ASCII subset)
        ("cafe", "café"),
        ("naive", "naïve"),

        # Long strings
        ("The quick brown fox jumps over the lazy dog",
         "The quick brown fox jumped over the lazy dogs"),
        ("University of Hawaii at Manoa",
         "Univ. of Hawaii, Manoa"),
    ]

    methods = {
        "ratio": lambda s1, s2: fuzz.ratio(s1, s2),
        "partial_ratio": lambda s1, s2: fuzz.partial_ratio(s1, s2),
        "token_sort": lambda s1, s2: fuzz.token_sort_ratio(s1, s2),
        "token_set": lambda s1, s2: fuzz.token_set_ratio(s1, s2),
        "levenshtein": lambda s1, s2: distance.Levenshtein.distance(s1, s2),
        "norm_lev": lambda s1, s2: distance.Levenshtein.normalized_similarity(s1, s2) * 100,
        "jaro": lambda s1, s2: distance.Jaro.similarity(s1, s2) * 100,
        "jaro_winkler": lambda s1, s2: distance.JaroWinkler.similarity(s1, s2) * 100,
        "hamming": lambda s1, s2: (
            distance.Hamming.distance(s1, s2) if len(s1) == len(s2) else -1
        ),
        "osa": lambda s1, s2: distance.OSA.distance(s1, s2),
    }

    with open("test_pairwise.csv", "w", newline="") as f:
        writer = csv.writer(f)
        header = ["str1", "str2"] + list(methods.keys())
        writer.writerow(header)

        for s1, s2 in pairs:
            row = [s1, s2]
            for name, func in methods.items():
                try:
                    row.append(round(func(s1, s2), 4))
                except Exception:
                    row.append("")
            writer.writerow(row)

    print(f"Generated test_pairwise.csv with {len(pairs)} test pairs")


def generate_match_tests():
    """Generate fuzzy matching test cases."""
    master = [
        "John Smith",
        "Jane Doe",
        "Robert Johnson",
        "Maria Garcia",
        "Apple Inc",
        "Microsft",
        "Gogle",
        "Amazn",
    ]

    reference = [
        "John A. Smith",
        "Jonathan Smith",
        "Jane M. Doe",
        "Janet Doe",
        "Robert B. Johnson",
        "Bob Johnson",
        "Maria L. Garcia",
        "Mary Garcia",
        "Apple Incorporated",
        "Apple Computer",
        "Microsoft Corporation",
        "Microsoft Corp",
        "Google LLC",
        "Google Inc",
        "Amazon.com Inc",
        "Amazon Web Services",
    ]

    with open("test_match_master.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["name"])
        for s in master:
            writer.writerow([s])

    with open("test_match_reference.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["ref_name"])
        for s in reference:
            writer.writerow([s])

    # Compute expected matches for each method
    for method_name, func in [
        ("ratio", lambda s1, s2: fuzz.ratio(s1, s2)),
        ("jaro_winkler", lambda s1, s2: distance.JaroWinkler.similarity(s1, s2) * 100),
        ("token_set", lambda s1, s2: fuzz.token_set_ratio(s1, s2)),
    ]:
        with open(f"test_match_expected_{method_name}.csv", "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["master", "best_match", "score"])
            for m in master:
                best_score = -1
                best_ref = ""
                for r in reference:
                    score = func(m, r)
                    if score > best_score:
                        best_score = score
                        best_ref = r
                writer.writerow([m, best_ref, round(best_score, 4)])

    print(f"Generated match test data: {len(master)} master, {len(reference)} reference")


if __name__ == "__main__":
    generate_pairwise_tests()
    generate_match_tests()
    print("\nDone. Run test_rapidfuzz.do in Stata to validate.")
