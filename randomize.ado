
program define randomize
version 12.0

/*
* 
* Stata version 12 is required due to the p-value matrix on regression results, but CM has a code fix to support version 11.
*
*!Author: Chris J. Kennedy, Christopher B. Mann
*!Date: 2015-03-05
*/

/*
Future potential options:
- mahalanobis distance support.
- model(mlogit, mprobit, mahalanobis, etc.) -> algorithm used to assess balance. (Not Supported Yet)
- TARgets(numlist >0 <=3 integer) -> moments of each covariate to control for, 1 = mean, 2 = variance, 3 = skewness.
- support for maximation customization, e.g. iterations(#) vce(passthru)
- saveseed(varname) if blocking is used, save the randomization seed used within each strata for QC purposes.

TODO/Thoughts:
- Use of "if `touse'" needs to be reviewed & tested, as there may be some edge cases that should be fixed.
- Blocking code still needs to be formally tested.
- Should sortseed also be a parameter so that it is defaulted?
- Convert local variables to tempvars so that we don't pollute the global namespace (for local variables).
- Do we want the result to also be randomly ordered, or not? Presume yes - useful when a voter contact program does not run through all records (e.g. phones).
- Would we want to save the probability that a record is assigned to a given class across all attempted randomizations? May be useful for randomization inference.
- This is basically bootstrapped randomization - may suggest similar parameters and output strategies. Also should look at MCMC simulation programming.
- Create unit tests to confirm that the randomization algorithm works correctly for a variety of experimental scenarios.
- Support cluster randomization directly within the algorithm eventually.
- Develop an algorithm to rank how imbalanced given covariates are.
- Give a warning if the smallest strata size appearse too small to randomize to the given number of groups (e.g. at least 20 records per randomization group as a rule of thumb, or something relative to the # of balance covariates, e.g. twice).

====================================*/



syntax [if] [in] [, GRoups(integer 2) MINruns(integer 1) MAXruns(integer 1) BALance(string) BLock(varlist) COEFFthreshold(real 0) JOintp(real 0.5) GENerate(name) seed(real 37) REPlace AGGregate(string) details]

qui: marksample touse // Exclude observations that do not meet the IF or IN criteria (if specified).

loc default_generate = "_assignment"

local balance_vars "`balance'"
local rand_seed `seed'

* Process the generate option.
if "`generate'" == "" {
  * If the generate parameter is not specified use the default variable name to store the final assignments.
  loc generate = "`default_generate'"
}

* Check if the specified generate variable already exists.
cap confirm variable `generate', exact
if _rc == 0 {
   * Drop the prior assignment variable if the replace option was chosen.
   if "`replace'" != ""  {
	 qui drop `default_generate'
   }
   else {
     dis as err "Error: variable `generate' already defined. Use the 'replace' option if you would like to automatically overwrite the assignment variable."
     exit	 
   }
}

* By default hide the detailed calculations.
local hide_details = "qui"
if "`details'" != "" {
	* If the details options is specified, don't hide the detailed calculations.
	local hide_details = ""
}

* Audit the aggregate values if that option is being used.
if "`aggregate'" != "" {
	local total = 0
	foreach value in `aggregate' {
		local total = `total' + `value'
	}
	if `total' != `groups' {
		dis as err "Error: aggregation values do not sum to the total number of groups. Please correct the aggregation values."
		exit
	}
}

* Create the assignment variable.
qui gen `generate' = . if `touse'

* Create temporary variables.
tempvar strata_current strata_cnt rand_assign_current strata_cnt standard_order
* tempname balance_vars

* Create temporary local macros.
* tempname ***

	
*----------------------------------
* Display current setup.
*----------------------------------
	
* dis "Balance variables: " as result "`balance'" as text "."
local num_balance_vars: word count `balance'
* dis "Number of balance variables: " as result "`num_balance_vars'" as text "."
	
* Renumber Strata for each data subset
if "`block'" != "" {
	egen `strata_current' = group(`block') if `touse', label missing
}
else {
	* No blocking needed.
	gen `strata_current' = 1 if `touse'
}
dis "Strata breakdown:"
tab `strata_current' if `touse'
local num_strata = r(r)

*-------------------------------------------------------------------------- 
* Automated re-randomization until the balance regression passes criteria
*-------------------------------------------------------------------------- 

* Setup basic variables.
* This saves the original order of the dataset, which can also be restored at the end of the program.
gen `standard_order' = _n 
qui gen `rand_assign_current' = .
bysort `strata_current': gen `strata_cnt' = _n
	
* Stratified randomization with optimization in each strata.
* This loop will run once if we are not blocking on anything.
forvalues strata_num = 1/`num_strata' {
    * TODO: determine if this next line should be commented out? may be a bug.
	qui sum `strata_cnt' if `strata_current' == `strata_num'
	local strata_size = r(max)
	dis "Randomizing stratum `strata_num' with `strata_size' records."

	* Indicators for re-randomization procedure
	local tries = 0
	local min = 0
	local best_run = -1
	local best_joint_p = -1

	* Set seed.
	set seed `rand_seed'
	**** TODO: need to let people pass in a list of seeds once we have identified the best seed for each stratum.
		
	while `tries' < `minruns' | (`tries' < `maxruns' & (`min' < `coeffthreshold' | `best_joint_p' < `jointp')) {
			
		* Update randomization count in the timer.
		timer off 37
		timer on 37
			
		local tries = `tries' + 1
		*--------------
		* Randomize
		*--------------
		* Save the starting seed so that we can re-run this randomization if it is the best.
		local starting_seed = c(seed)
			
		* Sort these records deterministically.
		sort `standard_order'
			
		qui replace `rand_assign_current' = runiform() if `touse'
		* Sort each strata in random order and calculate size of each strata
		qui bysort `strata_current' (`rand_assign_current'): replace `strata_cnt' = _n if `strata_current' == `strata_num'
		* Loop through the groups and assign a proportional allocation to each.
		* NOTE: may be able to simplify using seq(), although this may result in group 1 getting slightly more cases in which case it isn't worth it - TBD.
		forvalues rand_group = `groups'(-1)1 {
			* dis "replace `generate' = `rand_group' if `strata_cnt' <= round(`strata_size' * `rand_group' / `groups') & `strata_current' == `strata_num'"
			qui replace `generate' = `rand_group' if `strata_cnt' <= round(`strata_size' * `rand_group' / `groups') & `strata_current' == `strata_num'
		}
	
		*----------------------------------
		* Multinomial logit balance check.
		*----------------------------------
		* Use "noommitted" option so that omitted collinnear terms are not examined in p-value check.
		* This is not strictly necessary, but is cleaner.
		
		* Note: we may want to examine n-1 potential bases for a 3+ group assignment in the future, for the minimum coefficient p-value statistic.
		`hide_details' mlogit `generate' `balance_vars' if `strata_current' == `strata_num', base(1) noomitted
		
		* manova `balance_vars' = `generate' if `strata_current' == `strata_num'
* 		return list

		`hide_details' mvtest means `balance_vars' if `strata_current' == `strata_num', by(`generate')
		matrix p = r(stat_m)
		* Extract the Wilks' lambda.
		local joint_p = p[1, 5]
		* Set this just to keep the current algorithm working.
		local temp_min = 0
/*
		*** TODO: rename this joint_p to not be as similar to the program parameter.
		local joint_p = e(p)
		* Create p-value matrix for each variable
		matrix results = r(table)
		matrix pvalues = results["pvalue", 1...]			
		local num_columns = colsof(pvalues)
		local temp_min = 1
		forvalues i = 1/`num_columns' {
			* If we aren't on the constant term...
			if mod(`i', (`num_balance_vars' + 1)) != 0 {
				local pvalue = pvalues[1,`i']
				local temp_min = min(`pvalue', `temp_min') 
				* Min() ignores p-values that are missing, such as for the base case.
			}
		}
		*/
						

		* String variable to output if we updated our best attempt with this try.
		local used_try = ""
		
		* Save this randomization as the current best if at least one of three criteria are met:
		* 1. The LR p-value threshold is exceeded, our minimum coefficient p-value threshold is exceeded, and the minimum coefficent p-value is higher than our prior best.
		* 2. The current LR p-value is better than our previous best.
		* 3. The current LR p-value is equal to our previous best but the minimum coefficient p-value is higher.
		* Note: the logic for case #3 may need to be tweaked in the below algorithm.
 		if ( (`joint_p' >= `coeffthreshold' & `temp_min' >= `coeffthreshold' & `min' < `coeffthreshold') ///
			| (`joint_p' >= `best_joint_p' & (`temp_min' >= `coeffthreshold' | `min' < `coeffthreshold' | `best_joint_p' < `jointp'))) {
			local best_run = `tries'
			local min = `temp_min'		
			local best_joint_p = `joint_p'
			local best_start_seed = "`starting_seed'"
			local best_end_seed = c(seed)
			local used_try = "*"
		}
		`hide_details' dis "Strata `strata_num', Try " as result %2.0f `tries' as text ": LR Test p-value = " as result %06.4f `joint_p' as text "; minimum coeff p = " as result %05.3f `temp_min' as text ".`used_try'" 
	}
	`hide_details' dis "----"
	`hide_details' dis "Strata `strata_num'. Tries: `tries'. Best run: `best_run'. LR Test p-value: " as result %06.4f round(`best_joint_p', .0001) as text ", min coeff p-value: " as result %05.3f `min' as text "."
	`hide_details' dis "Start seed: `best_start_seed'. End seed: `best_end_seed'."
		
	*------------------------------------------
	* Re-run Best Randomization for Assignment
	*------------------------------------------
		
	`hide_details' dis "Skip to run `best_run'. Seed start: `best_start_seed'"
	set seed `best_start_seed'
	
	* Confirm that we are at the correct RNG state.
	assert("`best_start_seed'" == c(seed))
		
	* Save the seed for this strata in case we want to re-run anything.
	* TODO: decide if we actually want to enable this.
	* cap replace `strata_seed' = "`best_start_seed'" if strata_current == `strata_num' 
	
	* Sort by a deterministic order.
	sort `standard_order'
	qui replace `rand_assign_current' = runiform() if `touse'
	* Sort each strata in random order and calculate size of each strata
	sort `strata_current' `rand_assign_current'
	qui bysort `strata_current' (`rand_assign_current'): replace `strata_cnt' = _n if `touse'

	* Loop through the groups and assign a proportional allocation to each.
	* TODO: generate a random permutation of group orderings so that the groups have equal chance of receiving an extra unit due to rounding.
	* TODO: See if we can convert this to use seq(), per JohnT's suggestion.
	forvalues rand_group = `groups'(-1)1 {
		qui replace `generate' = `rand_group' if `strata_cnt' <= round(`strata_size' * `rand_group' / `groups') & `strata_current' == `strata_num'
	}

	`hide_details' dis "Ended at seed: " as result c(seed)
	
	* Confirm that we finished at the correct RNG state.
	assert(c(seed) == "`best_end_seed'")
		
	* Look at the results for this strata.
	dis as text _n "Assignment results for block `strata_num':"
	tab `generate' if `strata_current' == `strata_num', missing
		
	dis as text _n "Review balance within block `strata_num':"
	mlogit `generate' `balance_vars' if `strata_current' == `strata_num', base(1) noomitted nolog
			
}

* Review the group assignments across all blocks.
dis as text _n "Assignment results:"
tab `generate' if `touse', m

* Aggregate the groups if desired, in order to generate unbalanced allocations from equally sized groups.
if "`aggregate'" != "" {
	tempvar temp_assignment
	qui gen `temp_assignment' = .
	local group_start = 1
	local assignment_iterator = 1
	* Loop over each value of aggregate and merge the assignment groups.
	foreach value in `aggregate' {
		qui replace `temp_assignment' = `assignment_iterator' if `generate' >= `group_start' & `generate' < (`group_start' + `value')
		* Iterate the aggregated assignment value.
		local assignment_iterator = `assignment_iterator' + 1
		* Move up the assignment values we are working with, so that the next iteration will process that set of assignments.
		local group_start = `group_start' + `value'
	}

	* Now move those aggregated assignments back into the main assignment variable.
	qui replace `generate' = `temp_assignment'

	dis as text _n "Aggregated assignment results:"
	tab `generate'
	
}

* Restore the original ordering of the dataset in case it was being used.
sort `standard_order'
	
* TODO: display timer count.

end

