/*
    test_rapidfuzz.do

    Validates the Stata rapidfuzz plugin against Python reference data.

    Prerequisites:
    1. Run generate_test_data.py to create reference CSVs
    2. Install rapidfuzz plugin (net install or adopath)

    Usage:
        cd tests/
        do test_rapidfuzz.do
*/

clear all
set more off

* --- Ensure plugin is on the ado path ---
adopath + "../"

* ============================================================
* TEST 1: Pairwise Comparison (All Methods)
* ============================================================

display as text _n "=== TEST 1: Pairwise Comparison ==="

* Import reference data
import delimited "test_pairwise.csv", clear stringcols(1 2)

* Rename columns for clarity
rename v1 str1
rename v2 str2
capture rename v3 py_ratio
capture rename v4 py_partial_ratio
capture rename v5 py_token_sort
capture rename v6 py_token_set
capture rename v7 py_levenshtein
capture rename v8 py_norm_lev
capture rename v9 py_jaro
capture rename v10 py_jaro_winkler
capture rename v11 py_hamming
capture rename v12 py_osa

* Test each method
local methods "ratio partial_ratio token_sort token_set levenshtein norm_lev jaro jaro_winkler osa"
local n_pass = 0
local n_fail = 0

foreach m of local methods {
    display as text _n "Testing method: `m'"

    * Compute Stata scores
    capture drop stata_`m'
    rapidfuzz str1 str2, gen(stata_`m') method(`m')

    * Compare with Python reference
    capture confirm variable py_`m'
    if _rc {
        display as error "  SKIP: no Python reference for `m'"
        continue
    }

    * Allow small floating point differences (0.5 tolerance)
    gen double diff_`m' = abs(stata_`m' - py_`m')
    quietly summarize diff_`m'
    local max_diff = r(max)
    local mean_diff = r(mean)

    if `max_diff' < 0.5 {
        display as result "  PASS: max diff = " %8.4f `max_diff' ///
            ", mean diff = " %8.4f `mean_diff'
        local n_pass = `n_pass' + 1
    }
    else {
        display as error "  FAIL: max diff = " %8.4f `max_diff'

        * Show worst cases
        gsort -diff_`m'
        list str1 str2 stata_`m' py_`m' diff_`m' in 1/5, noobs
        local n_fail = `n_fail' + 1
    }
}

* Test hamming separately (missing values for unequal lengths)
display as text _n "Testing method: hamming"
capture drop stata_hamming
rapidfuzz str1 str2, gen(stata_hamming) method(hamming)

* Hamming should be missing when lengths differ
gen byte len_equal = (strlen(str1) == strlen(str2))
gen byte hamming_correct = (len_equal == 0 & missing(stata_hamming)) | ///
    (len_equal == 1 & !missing(stata_hamming))
quietly count if !hamming_correct
if r(N) == 0 {
    display as result "  PASS: missing value handling correct"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: " r(N) " incorrect missing values"
    local n_fail = `n_fail' + 1
}

* ============================================================
* TEST 2: Case Insensitive Mode
* ============================================================

display as text _n "=== TEST 2: Case Insensitive Mode ==="

clear
input str30 str1 str30 str2
"HELLO" "hello"
"John SMITH" "john smith"
"ABC" "abc"
end

rapidfuzz str1 str2, gen(score_case) method(ratio)
rapidfuzz str1 str2, gen(score_nocase) method(ratio) nocase

* Case-insensitive should give 100 for all
quietly count if score_nocase != 100
if r(N) == 0 {
    display as result "  PASS: nocase mode works"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: nocase mode incorrect"
    list, noobs
    local n_fail = `n_fail' + 1
}

* ============================================================
* TEST 3: if/in Conditions
* ============================================================

display as text _n "=== TEST 3: if/in Conditions ==="

clear
input str20 str1 str20 str2 byte use_obs
"hello" "hello" 1
"abc" "xyz" 0
"test" "test" 1
"foo" "bar" 0
end

rapidfuzz str1 str2 if use_obs == 1, gen(score_if) method(ratio)

* Only obs 1 and 3 should have scores
quietly count if !missing(score_if) & use_obs == 0
local bad = r(N)
quietly count if missing(score_if) & use_obs == 1
local bad = `bad' + r(N)

if `bad' == 0 {
    display as result "  PASS: if condition works"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: if condition incorrect"
    list, noobs
    local n_fail = `n_fail' + 1
}

* ============================================================
* TEST 4: Replace Option
* ============================================================

display as text _n "=== TEST 4: Replace Option ==="

clear
input str10 s1 str10 s2
"abc" "abc"
end

rapidfuzz s1 s2, gen(score) method(ratio)
local first_score = score[1]

rapidfuzz s1 s2, gen(score) method(levenshtein) replace
local second_score = score[1]

if `first_score' == 100 & `second_score' == 0 {
    display as result "  PASS: replace works"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: replace incorrect"
    local n_fail = `n_fail' + 1
}

* ============================================================
* TEST 5: Edge Cases
* ============================================================

display as text _n "=== TEST 5: Edge Cases ==="

clear
input str1 s1 str1 s2
"" ""
"a" ""
"" "b"
end

rapidfuzz s1 s2, gen(score) method(ratio)

* Both empty -> 100, one empty -> 0
local pass = 1
if score[1] != 100 local pass = 0
if score[2] != 0 local pass = 0
if score[3] != 0 local pass = 0

if `pass' {
    display as result "  PASS: empty string handling"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: empty string handling"
    list, noobs
    local n_fail = `n_fail' + 1
}

* ============================================================
* TEST 6: Fuzzy Match Mode
* ============================================================

display as text _n "=== TEST 6: Fuzzy Match ==="

* Check if match test data exists
capture confirm file "test_match_master.csv"
if _rc {
    display as text "  SKIP: run generate_test_data.py first"
}
else {
    import delimited "test_match_master.csv", clear stringcols(_all)
    rename name master_name

    * Save as Stata dataset for using
    preserve
    import delimited "test_match_reference.csv", clear stringcols(_all)
    tempfile ref_data
    save `ref_data'
    restore

    rapidfuzz_match master_name using `ref_data', ///
        gen(match_score matched_name) uvar(ref_name) ///
        method(jaro_winkler) nocase

    * Check that all master obs got a match
    quietly count if missing(match_score)
    if r(N) == 0 {
        display as result "  PASS: all observations matched"
        local n_pass = `n_pass' + 1
    }
    else {
        display as error "  FAIL: " r(N) " observations not matched"
        local n_fail = `n_fail' + 1
    }

    * Display results
    list master_name matched_name match_score, noobs
}

* ============================================================
* Summary
* ============================================================

display as text _n "{hline 50}"
display as text "RESULTS: " as result "`n_pass' passed" ///
    as text ", " as error "`n_fail' failed"
display as text "{hline 50}"

if `n_fail' > 0 {
    exit 9
}
