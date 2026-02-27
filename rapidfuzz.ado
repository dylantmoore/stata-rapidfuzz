*! version 1.1.0  23feb2026
*! Pairwise string similarity using RapidFuzz algorithms
*!
*! Syntax:
*!   rapidfuzz str1 str2 [if] [in], GENerate(newvar)
*!       [Method(string) NOCASE REPlace PREfix_weight(real 0.1)
*!        Weights(numlist integer min=3 max=3 >0) NOPAD]

program define rapidfuzz, rclass
    version 14.0

    syntax varlist(min=2 max=2 string) [if] [in], ///
        GENerate(name) ///
        [Method(string) NOCASE REPlace PREfix_weight(real 0.1) ///
         Weights(numlist integer min=3 max=3 >0) NOPAD]

    * --- Default method ---
    if "`method'" == "" local method "ratio"

    * --- Validate method ---
    * Fuzz metrics (0-100 similarity)
    local valid_methods "ratio partial_ratio token_sort partial_token_sort"
    local valid_methods "`valid_methods' token_set partial_token_set"
    local valid_methods "`valid_methods' token_ratio partial_token_ratio wratio qratio"
    * Normalized similarity (0-100)
    local valid_methods "`valid_methods' jaro jaro_winkler norm_lev norm_osa"
    local valid_methods "`valid_methods' norm_hamming norm_indel norm_lcsseq"
    local valid_methods "`valid_methods' norm_prefix norm_postfix"
    * Raw distance (integer)
    local valid_methods "`valid_methods' levenshtein osa hamming indel lcsseq"
    local valid_methods "`valid_methods' prefix postfix"
    local method_ok 0
    foreach m of local valid_methods {
        if "`method'" == "`m'" local method_ok 1
    }
    if !`method_ok' {
        display as error "invalid method: `method'"
        display as error "valid methods: `valid_methods'"
        exit 198
    }

    * --- Validate weights option ---
    if "`weights'" != "" {
        if "`method'" != "levenshtein" & "`method'" != "norm_lev" {
            display as error "weights() only allowed with levenshtein or norm_lev"
            exit 198
        }
    }

    * --- Validate nopad option ---
    if "`nopad'" != "" {
        if "`method'" != "hamming" & "`method'" != "norm_hamming" {
            display as error "nopad only allowed with hamming or norm_hamming"
            exit 198
        }
    }

    * --- Handle replace ---
    if "`replace'" != "" {
        capture drop `generate'
    }
    confirm new variable `generate'

    * --- Parse variable names ---
    gettoken str1 str2 : varlist

    * --- Mark sample ---
    marksample touse, strok
    quietly count if `touse'
    local n_use = r(N)
    if `n_use' == 0 {
        display as error "no observations"
        exit 2000
    }

    * --- Load plugin ---
    quietly _rapidfuzz_load_plugin

    * --- Create output variable ---
    quietly gen double `generate' = .

    * --- Build plugin arguments ---
    local nocase_flag ""
    if "`nocase'" != "" local nocase_flag "nocase"

    local pw_flag ""
    if "`method'" == "jaro_winkler" {
        local pw_flag "pw=`prefix_weight'"
    }

    local wt_flag ""
    if "`weights'" != "" {
        local wt_ins : word 1 of `weights'
        local wt_del : word 2 of `weights'
        local wt_rep : word 3 of `weights'
        local wt_flag "wt=`wt_ins',`wt_del',`wt_rep'"
    }

    local nopad_flag ""
    if "`nopad'" != "" local nopad_flag "nopad"

    * --- Stable merge key ---
    tempvar merge_id
    quietly gen long `merge_id' = _n

    * --- Preserve, subset, call plugin ---
    preserve
    quietly keep if `touse'

    plugin call rapidfuzz_plugin `str1' `str2' `generate', ///
        pairwise `method' `nocase_flag' `pw_flag' `wt_flag' `nopad_flag'

    local rc = _rc
    if `rc' != 0 {
        restore
        display as error "rapidfuzz plugin returned error `rc'"
        exit `rc'
    }

    * --- Save results ---
    tempfile results
    quietly keep `merge_id' `generate'
    quietly save `results'
    restore

    * --- Merge results back ---
    quietly merge 1:1 `merge_id' using `results', nogenerate update

    * --- Store return values ---
    return local method "`method'"
    return scalar N = `n_use'
    if "`nocase'" != "" return local nocase "nocase"

    display as text "Computed `method' for `n_use' observation pairs"
    if "`nocase'" != "" display as text "  (case-insensitive)"
end

* --- Plugin loader (gtools-style) ---
program define _rapidfuzz_load_plugin
    if ( inlist("`c(os)'", "MacOSX") | strpos("`c(machine_type)'", "Mac") ) local c_os_ macosx
    else local c_os_: di lower("`c(os)'")

    cap program drop rapidfuzz_plugin
    program rapidfuzz_plugin, plugin using("rapidfuzz_plugin_`c_os_'.plugin")
end
