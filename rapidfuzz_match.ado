*! version 1.0.0  22feb2026
*! Fuzzy string matching against a reference dataset
*!
*! Syntax:
*!   rapidfuzz_match str_var using filename, GENerate(score_var match_var)
*!       [Uvar(varname) Method(string) THReshold(real 0)
*!        NOCASE PREfix_weight(real 0.1)]

program define rapidfuzz_match, rclass
    version 14.0

    syntax varname(string) using/, ///
        GENerate(namelist min=2 max=2) ///
        [Uvar(string) Method(string) THReshold(real 0) ///
         NOCASE PREfix_weight(real 0.1)]

    * --- Parse output variable names ---
    gettoken score_var match_var : generate

    * --- Defaults ---
    if "`method'" == "" local method "ratio"
    if "`uvar'" == "" local uvar "`varlist'"

    * --- Validate method ---
    local valid_methods "ratio partial_ratio token_sort partial_token_sort"
    local valid_methods "`valid_methods' token_set partial_token_set"
    local valid_methods "`valid_methods' token_ratio partial_token_ratio wratio qratio"
    local valid_methods "`valid_methods' jaro jaro_winkler norm_lev norm_osa"
    local valid_methods "`valid_methods' norm_hamming norm_indel norm_lcsseq"
    local valid_methods "`valid_methods' levenshtein osa hamming indel lcsseq"
    local method_ok 0
    foreach m of local valid_methods {
        if "`method'" == "`m'" local method_ok 1
    }
    if !`method_ok' {
        display as error "invalid method: `method'"
        exit 198
    }

    * --- Check output variables don't exist ---
    confirm new variable `score_var'
    confirm new variable `match_var'

    * --- Load plugin ---
    quietly _rapidfuzz_load_plugin

    * --- Count master observations ---
    local n_master = _N
    if `n_master' == 0 {
        display as error "no observations in master dataset"
        exit 2000
    }

    * --- Create stable merge key ---
    tempvar merge_id
    quietly gen long `merge_id' = _n

    * --- Save master data ---
    preserve

    * --- Rename master string var to common name ---
    tempvar str_all
    quietly gen str244 `str_all' = `varlist'

    * --- Append reference dataset ---
    local using_clean = subinstr(`"`using'"', `"""', "", .)
    tempfile master_tmp
    quietly save `master_tmp'

    use `"`using_clean'"', clear

    * --- Check that uvar exists in using data ---
    capture confirm variable `uvar'
    if _rc {
        display as error "variable `uvar' not found in using dataset"
        restore
        exit 111
    }

    * --- Keep only the reference string variable ---
    quietly gen str244 `str_all' = `uvar'
    quietly gen long `merge_id' = .
    keep `str_all' `merge_id'

    * --- Append master data ---
    append using `master_tmp'

    * --- Sort: master first (merge_id non-missing), ref second ---
    quietly gen byte _is_ref = missing(`merge_id')
    quietly sort _is_ref `merge_id'

    local n_ref = _N - `n_master'
    if `n_ref' == 0 {
        display as error "no observations in using dataset"
        restore
        exit 2000
    }

    * --- Create output variables ---
    quietly gen double _best_score = .
    quietly gen double _best_idx = .

    * --- Build plugin arguments ---
    local nocase_flag ""
    if "`nocase'" != "" local nocase_flag "nocase"
    local pw_flag ""
    if "`method'" == "jaro_winkler" local pw_flag "pw=`prefix_weight'"

    * --- Call plugin in match mode ---
    display as text "Matching `n_master' observations against " ///
        "`n_ref' reference strings..."
    display as text "  method: `method'"

    plugin call rapidfuzz_plugin `str_all' _best_score _best_idx, ///
        match `method' `n_master' `n_ref' `nocase_flag' `pw_flag'

    local rc = _rc
    if `rc' != 0 {
        restore
        display as error "rapidfuzz_match plugin returned error `rc'"
        exit `rc'
    }

    * --- Look up matched strings ---
    * _best_idx is 1-based index into reference observations
    * Reference observations are at positions (n_master+1) to (n_master+n_ref)
    quietly gen str244 _matched_str = ""
    forvalues i = 1/`n_master' {
        local idx = _best_idx[`i']
        if !missing(`idx') {
            local ref_obs = `n_master' + `idx'
            local matched_val = `str_all'[`ref_obs']
            quietly replace _matched_str = `"`matched_val'"' in `i'
        }
    }

    * --- Apply threshold for similarity methods ---
    local is_similarity = 0
    foreach m in ratio partial_ratio token_sort partial_token_sort ///
                 token_set partial_token_set token_ratio ///
                 partial_token_ratio wratio qratio ///
                 jaro jaro_winkler norm_lev norm_osa ///
                 norm_hamming norm_indel norm_lcsseq {
        if "`method'" == "`m'" local is_similarity = 1
    }
    if `is_similarity' & `threshold' > 0 {
        quietly replace _matched_str = "" if _best_score < `threshold'
        quietly replace _best_score = . if _best_score < `threshold'
    }

    * --- Save results for merge ---
    quietly keep if !missing(`merge_id')
    rename _best_score `score_var'
    rename _matched_str `match_var'
    keep `merge_id' `score_var' `match_var'

    tempfile match_results
    quietly save `match_results'

    * --- Restore and merge ---
    restore

    quietly merge 1:1 `merge_id' using `match_results', nogenerate

    * --- Return values ---
    return local method "`method'"
    return scalar N_master = `n_master'
    return scalar N_ref = `n_ref'
    if "`nocase'" != "" return local nocase "nocase"
    if `threshold' > 0 return scalar threshold = `threshold'

    display as text "Matching complete."
    display as text "  `n_master' master obs matched against `n_ref' references"

    * --- Summary stats ---
    quietly summarize `score_var'
    if r(N) > 0 {
        display as text "  mean score: " %6.1f r(mean) ///
            "  min: " %6.1f r(min) "  max: " %6.1f r(max)
    }
end

* --- Plugin loader (shared with rapidfuzz.ado) ---
capture program drop _rapidfuzz_load_plugin
program define _rapidfuzz_load_plugin
    capture program rapidfuzz_plugin, plugin using("rapidfuzz_plugin.darwin-arm64.plugin")
    if _rc {
        capture program rapidfuzz_plugin, plugin using("rapidfuzz_plugin.darwin-x86_64.plugin")
        if _rc {
            capture program rapidfuzz_plugin, plugin using("rapidfuzz_plugin.linux-x86_64.plugin")
            if _rc {
                capture program rapidfuzz_plugin, plugin using("rapidfuzz_plugin.windows-x86_64.plugin")
                if _rc {
                    display as error "rapidfuzz: cannot load plugin"
                    display as error "Ensure .plugin files are installed."
                    exit 601
                }
            }
        }
    }
end
