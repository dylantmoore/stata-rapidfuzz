{smcl}
{* *! version 1.0.0  22feb2026}{...}
{viewerjumpto "Syntax" "rapidfuzz##syntax"}{...}
{viewerjumpto "Description" "rapidfuzz##description"}{...}
{viewerjumpto "Options" "rapidfuzz##options"}{...}
{viewerjumpto "Methods" "rapidfuzz##methods"}{...}
{viewerjumpto "Examples" "rapidfuzz##examples"}{...}
{viewerjumpto "Matching" "rapidfuzz##matching"}{...}
{viewerjumpto "Stored results" "rapidfuzz##results"}{...}

{title:Title}

{phang}
{bf:rapidfuzz} {hline 2} String similarity and fuzzy matching using RapidFuzz algorithms

{marker syntax}{...}
{title:Syntax}

{pstd}
{it:Pairwise comparison}

{p 8 17 2}
{cmdab:rapidfuzz}
{it:strvar1} {it:strvar2}
{ifin}
{cmd:,} {opt gen:erate(newvar)} [{it:options}]

{pstd}
{it:Fuzzy matching against reference dataset}

{p 8 17 2}
{cmdab:rapidfuzz_match}
{it:strvar}
{cmd:using} {it:filename}
{cmd:,} {opt gen:erate(scorevar matchvar)} [{it:match_options}]

{synoptset 28 tabbed}{...}
{synopthdr:options}
{synoptline}
{syntab:Required}
{synopt:{opt gen:erate(newvar)}}name of new variable for scores{p_end}

{syntab:Method}
{synopt:{opt m:ethod(string)}}similarity method; default is {bf:ratio}{p_end}
{synopt:{opt nocase}}case-insensitive comparison{p_end}
{synopt:{opt pre:fix_weight(#)}}Jaro-Winkler prefix weight; default is 0.1{p_end}

{syntab:Other}
{synopt:{opt replace}}replace existing output variable{p_end}
{synoptline}

{synoptset 28 tabbed}{...}
{synopthdr:match_options}
{synoptline}
{syntab:Required}
{synopt:{opt gen:erate(scorevar matchvar)}}names for score and matched string variables{p_end}

{syntab:Method}
{synopt:{opt m:ethod(string)}}similarity method; default is {bf:ratio}{p_end}
{synopt:{opt uvar(varname)}}string variable in using dataset; default is same as master{p_end}
{synopt:{opt thr:eshold(#)}}minimum score for a valid match (similarity methods){p_end}
{synopt:{opt nocase}}case-insensitive comparison{p_end}
{synopt:{opt pre:fix_weight(#)}}Jaro-Winkler prefix weight; default is 0.1{p_end}
{synoptline}

{marker description}{...}
{title:Description}

{pstd}
{cmd:rapidfuzz} computes string similarity scores between pairs of string
variables, observation by observation. It implements the core algorithms from
the RapidFuzz library (MIT License).

{pstd}
{cmd:rapidfuzz_match} performs fuzzy matching: for each observation in the
master dataset, it finds the best-matching string in a reference dataset and
returns the match score and matched string.

{marker options}{...}
{title:Options}

{phang}
{opt method(string)} specifies the similarity or distance algorithm.
See {help rapidfuzz##methods:Methods} below. Default is {bf:ratio}.

{phang}
{opt nocase} converts both strings to lowercase before comparison.

{phang}
{opt prefix_weight(#)} sets the prefix weight for Jaro-Winkler.
Must be between 0 and 0.25. Default is 0.1.

{phang}
{opt threshold(#)} for {cmd:rapidfuzz_match}, sets the minimum score for
similarity methods. Matches below this threshold are set to missing.

{phang}
{opt uvar(varname)} for {cmd:rapidfuzz_match}, specifies the string variable
in the using dataset. Defaults to the same name as the master variable.

{marker methods}{...}
{title:Methods}

{pstd}
{it:Similarity metrics} return scores from 0 (no match) to 100 (identical):

{phang2}{bf:ratio} {hline 1} Normalized Indel similarity based on longest
common subsequence. The default and most general-purpose metric.{p_end}

{phang2}{bf:partial_ratio} {hline 1} Best substring match. Useful when one
string contains the other (e.g., "John" vs "John Smith").{p_end}

{phang2}{bf:token_sort} {hline 1} Sorts words alphabetically before computing
ratio. Useful for names in different order ("Smith John" vs "John Smith").{p_end}

{phang2}{bf:token_set} {hline 1} Decomposes words into intersection and
differences. Handles extra words gracefully.{p_end}

{phang2}{bf:jaro} {hline 1} Jaro similarity. Good for short strings and
typo detection.{p_end}

{phang2}{bf:jaro_winkler} {hline 1} Jaro with bonus for matching prefixes.
Best for personal names where the first few characters are reliable.{p_end}

{phang2}{bf:norm_lev} {hline 1} Normalized Levenshtein similarity
(1 - distance/max_length, scaled 0-100).{p_end}

{pstd}
{it:Distance metrics} return raw edit counts (lower = more similar):

{phang2}{bf:levenshtein} {hline 1} Classic edit distance: minimum insertions,
deletions, and substitutions to transform one string into another.{p_end}

{phang2}{bf:hamming} {hline 1} Number of positions where characters differ.
Requires equal-length strings; returns missing if lengths differ.{p_end}

{phang2}{bf:osa} {hline 1} Optimal String Alignment distance: Levenshtein
plus adjacent transpositions.{p_end}

{marker examples}{...}
{title:Examples}

{pstd}Pairwise comparison of two name variables:{p_end}
{phang2}{cmd:. rapidfuzz name1 name2, gen(score) method(jaro_winkler) nocase}{p_end}

{pstd}Token-based matching ignoring word order:{p_end}
{phang2}{cmd:. rapidfuzz company_a company_b, gen(sim) method(token_sort)}{p_end}

{pstd}Levenshtein edit distance:{p_end}
{phang2}{cmd:. rapidfuzz str1 str2, gen(edist) method(levenshtein)}{p_end}

{pstd}Fuzzy merge against a reference file:{p_end}
{phang2}{cmd:. rapidfuzz_match name using "reference.dta", gen(score matched_name) method(jaro_winkler) nocase threshold(80)}{p_end}

{pstd}Match with different variable names:{p_end}
{phang2}{cmd:. rapidfuzz_match company using "firms.dta", gen(score best_firm) uvar(firm_name) method(token_set)}{p_end}

{marker matching}{...}
{title:Fuzzy matching workflow}

{pstd}
A typical fuzzy merge workflow:

{phang2}1. Load your master data with the variable to match.{p_end}
{phang2}2. Run {cmd:rapidfuzz_match} against a reference dataset.{p_end}
{phang2}3. Review matches, especially those near the threshold.{p_end}
{phang2}4. Merge additional variables from the reference using the matched key.{p_end}

{pstd}
For large datasets, Jaro-Winkler is fastest. Token-based methods are slower
but handle name variations better.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:rapidfuzz} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations compared{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(method)}}method used{p_end}
{synopt:{cmd:r(nocase)}}"nocase" if case-insensitive{p_end}

{pstd}
{cmd:rapidfuzz_match} additionally stores:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_master)}}number of master observations{p_end}
{synopt:{cmd:r(N_ref)}}number of reference observations{p_end}
{synopt:{cmd:r(threshold)}}threshold used (if specified){p_end}

{title:References}

{pstd}
Based on the RapidFuzz library ({browse "https://github.com/StrategicProjects/RapidFuzz"}).

{pstd}
Algorithms originally from: Levenshtein (1966), Jaro (1989), Winkler (1990),
and the FuzzyWuzzy project by SeatGeek.

{title:Author}

{pstd}
Generated with Claude Code using the Stata C Plugins skill.
{p_end}
