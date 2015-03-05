
program define randomize
version 12.0

/*
*
*!Author: Chris J. Kennedy, Christopher B. Mann
*!Date: 2015-03-05
*
* Note: Stata version 12 is required due to the p-value matrix on regression results, but CM has a code fix to support version 11 if needed.
*/

/*
Future potential options:
- mahalanobis distance support.
- model(mlogit, mprobit, mahalanobis, etc.) -> algorithm used to assess balance. (Not Supported Yet)
- TARgets(numlist >0 <=3 integer) -> moments of each covariate to control for, 1 = mean, 2 = variance, 3 = skewness.
- support for maximation customization, e.g. iterations(#) vce(passthru)
- saveseed(varname) if blocking is used, save the randomization seed used within each strata for QC purposes.

TODO/Thoughts:
- Create unit tests to confirm that the randomization algorithm works correctly for a variety of experimental scenarios.
- Support cluster randomization directly within the algorithm eventually.
- Should sortseed also be a parameter so that it is defaulted?
- Develop an algorithm to rank how imbalanced given covariates are.
- Give a warning if the smallest strata size appearse too small to randomize to the given number of groups (e.g. at least 20 records per randomization group as a rule of thumb, or something relative to the # of balance covariates, e.g. twice).

====================================*/



syntax [if] [in] [, GRoups(integer 2) MINruns(integer 1) MAXruns(integer 1) BALance(string) BLock(varlist) COEFFthreshold(real 0) JOintp(real 0.5) GENerate(name) seed(real -1) REPlace AGGregate(string) details]

* Exclude observations that do not meet the IF or IN criteria (if specified).
qui: marksample touse

tempname balance_vars rand_seed total hide_details default_generate gen_internal value

loc `default_generate' = "_assignment"

local `balance_vars' "`balance'"
local `rand_seed' `seed'

* Process the generate option.
if "`generate'" == "" {
  * If the generate parameter is not specified use the default variable name to store the final assignments.
  loc generate = "``default_generate''"
}

* Check if the specified generate variable already exists.
cap confirm variable `generate', exact
if _rc == 0 {
   * Drop the prior assignment variable if the replace option was chosen.
   if "`replace'" != ""  {
	 qui drop `generate'
   }
   else {
     dis as err "Error: variable `generate' already defined. Use the 'replace' option if you would like to automatically overwrite the assignment variable."
     exit	 
   }
}

* By default hide the detailed calculations.
local `hide_details' = "qui"
if "`details'" != "" {
	* If the details options is specified, don't hide the detailed calculations.
	local `hide_details' = ""
}

* Audit the aggregate values if that option is being used.
if "`aggregate'" != "" {
	local `total' = 0
	foreach `value' in `aggregate' {
		local `total' = ``total'' + ``value''
	}
	if ``total'' != `groups' {
		dis as err "Error: aggregation values do not sum to the total number of groups. Please correct the aggregation values."
		exit
	}
}

* Create the assignment variable.
qui gen `generate' = . if `touse'

* Create temporary dataset variables.
tempvar strata_current strata_cnt rand_assign_current strata_cnt standard_order

* Create temporary macro variables.
tempname num_balance_vars strata_size strata_num tries min best_run best_joint_p best_start_seed best_end_seed best_run rand_group num_strata starting_seed p used_try joint_p temp_min
tempname size pos val rand_vals
	
*----------------------------------
* Display current setup.
*----------------------------------
	
local `num_balance_vars': word count `balance'
	
* Renumber strata for each data subset.
if "`block'" != "" {
	egen `strata_current' = group(`block') if `touse', label missing
	dis "Strata breakdown:"
	tab `strata_current' if `touse'
	local `num_strata' = r(r)
}
else {
	* No blocking needed.
	gen `strata_current' = 1 if `touse'
	local `num_strata' = 1
}


*-------------------------------------------------------------------------- 
* Automated re-randomization until the balance regression passes criteria
*-------------------------------------------------------------------------- 

* This saves the original order of the dataset, which is also restored at the end of the program.
gen `standard_order' = _n 
* Use double so that we have a lower incidence of ties.
qui gen double `rand_assign_current' = .
bysort `strata_current': gen `strata_cnt' = _n
	
* Set seed if defined.
if "`seed'" != "-1" {
	set seed ``rand_seed''
}

* Blocked randomization with optimization in each strata.
* This loop will simply run once if we are not blocking on anything.
forvalues `strata_num' = 1/``num_strata'' {
	qui sum `strata_cnt' if `strata_current' == ``strata_num''
	local `strata_size' = r(max)
	if "`block'" == "" {
		* No blocking.
		dis "Randomizing ``strata_size'' records."
	}
	else {
		dis "Randomizing stratum ``strata_num'' with ``strata_size'' records."
	}
	
	* Tracking variations for the rerandomization procedure.
	local `tries' = 0
	local `min' = 0
	local `best_run' = -1
	local `best_joint_p' = -1

	**** Possible feature: could let people pass in a list of seeds once we have identified the best seed for each stratum, so that rerandomization is no longer necessary.
		
	while ``tries'' < `minruns' | (``tries'' < `maxruns' & (``min'' < `coeffthreshold' | ``best_joint_p'' < `jointp')) {
			
		* Update randomization count in the timer.
		timer off 37
		timer on 37
			
		local ++`tries'

		* Save the starting seed so that we can re-run this randomization if it is the best.
		local `starting_seed' = c(seed)
			
		* Sort by a deterministic order so that we have no dependence on prior randomizations or strata.
		sort `standard_order'
			
		qui replace `rand_assign_current' = runiform() if `touse'
		* Sort each strata in random order and calculate size of each strata
		qui bysort `strata_current' (`rand_assign_current'): replace `strata_cnt' = _n if `strata_current' == ``strata_num''

		* Create a sequence of possible assignment values.
		local `rand_vals' = ""
		forvalues seq = 1/`groups'{
			 * Append to the list
			local `rand_vals': list `rand_vals' | seq
		}
		
		* Loop through the groups and assign a proportional allocation to each.
		* During assignment we create a random permutation of group orderings so that the groups have equal chance of receiving an extra unit due to rounding.
		* TODO: See if we can convert this to use seq(), per JohnT's suggestion.
		forvalues `rand_group' = `groups'(-1)1 {
			* Find current size of the possible random assignments.
			local `size': list sizeof `rand_vals'
			* Choose a random position (integer) in the list of random assignments.
			local `pos' = floor((``size'')*runiform()+1)
			* Extract the assignment value at that location.
			local `val': word ``pos'' of ``rand_vals''
			* Remove that value from the list of possible assignments so that we sample without replacement.
			local `rand_vals': list `rand_vals' - `val'
			
			* Assign a portion of the stratum to the randomly chosen assignment value.
			qui replace `generate' = ``val'' if `strata_cnt' <= ceil(``strata_size'' * ``rand_group'' / `groups') & `strata_current' == ``strata_num''
		}
	
		* Use "noommitted" option so that omitted collinnear terms are not examined in p-value check.
		* This is not strictly necessary, but is cleaner.
		
		* Old balance check: run a multinomial logistic regression.
		* ``hide_details'' mlogit `generate' ``balance_vars'' if `strata_current' == ``strata_num'', base(1) noomitted
		
		* manova `balance_vars' = `generate' if `strata_current' == `strata_num'
		
		* Do a multivariate comparison of means for the balance check, extracting the Wilk's lambda p-value.
		``hide_details'' mvtest means ``balance_vars'' if `strata_current' == ``strata_num'', by(`generate')
		matrix `p' = r(stat_m)
		* Extract the Wilks' lambda.
		local `joint_p' = `p'[1, 5]
		* Set this just to keep the current algorithm working.
		local `temp_min' = 0

		* String variable to output if we updated our best attempt with this try.
		local `used_try' = ""
		
		* Save this randomization as the current best if at least one of three criteria are met:
		* 1. The LR p-value threshold is exceeded, our minimum coefficient p-value threshold is exceeded, and the minimum coefficent p-value is higher than our prior best.
		* 2. The current LR p-value is better than our previous best.
		* 3. The current LR p-value is equal to our previous best but the minimum coefficient p-value is higher.
		* Note: the logic for case #3 may need to be tweaked in the below algorithm.
 		if ( (``joint_p'' >= `coeffthreshold' & ``temp_min'' >= `coeffthreshold' & ``min'' < `coeffthreshold') ///
			| (``joint_p'' >= ``best_joint_p'' & (``temp_min'' >= `coeffthreshold' | ``min'' < `coeffthreshold' | ``best_joint_p'' < `jointp'))) {
			local `best_run' = ``tries''
			local `min' = ``temp_min''		
			local `best_joint_p' = ``joint_p''
			local `best_start_seed' = "``starting_seed''"
			local `best_end_seed' = c(seed)
			local `used_try' = "*"
		}
		``hide_details'' dis "Strata ``strata_num'', Try " as result %2.0f ``tries'' as text ": LR Test p-value = " as result %06.4f ``joint_p'' as text "; minimum coeff p = " as result %05.3f ``temp_min'' as text ".`used_try'" 
	}
	``hide_details'' dis "----"
	``hide_details'' dis "Strata ``strata_num''. Tries: ``tries''. Best run: ``best_run''. LR Test p-value: " as result %06.4f round(``best_joint_p'', .0001) as text ", min coeff p-value: " as result %05.3f ``min'' as text "."
	``hide_details'' dis "Start seed: ``best_start_seed''. End seed: ``best_end_seed''."
		
	*------------------------------------------
	* Re-run Best Randomization for Assignment
	*------------------------------------------
		
	``hide_details'' dis "Skip to run ``best_run''. Seed start: ``best_start_seed''"
	set seed ``best_start_seed''
	
	* Confirm that we are at the correct RNG state.
	assert("``best_start_seed''" == c(seed))
		
	* Save the seed for this strata in case we want to re-run anything.
	* TODO: decide if we actually want to enable this.
	* cap replace `strata_seed' = "`best_start_seed'" if strata_current == `strata_num' 
	
	* Sort by a deterministic order so that we have no dependence on prior randomizations or strata.
	sort `standard_order'
	qui replace `rand_assign_current' = runiform() if `touse'
	* Sort each strata in random order and calculate size of each strata
	sort `strata_current' `rand_assign_current'
	qui bysort `strata_current' (`rand_assign_current'): replace `strata_cnt' = _n if `touse'
	
	* Create a sequence of possible assignment values.
	local `rand_vals' = ""
	forvalues seq = 1/`groups' {
		 * Append to the list.
		local `rand_vals': list `rand_vals' | seq
	}
	
	* Loop through the groups and assign a proportional allocation to each.
	* During assignment we create a random permutation of group orderings so that the groups have equal chance of receiving an extra unit due to rounding.
	* TODO: See if we can convert this to use seq(), per JohnT's suggestion.
	forvalues `rand_group' = `groups'(-1)1 {
		* Find current size of the possible random assignments.
		local `size': list sizeof `rand_vals'
		* Choose a random position in the list of random assignments.
		local `pos' = floor((``size'')*runiform()+1)
		* Extract the assignment value at that location.
		local `val': word ``pos'' of ``rand_vals''
		* Remove that location from the list of possible assignments so that we sample without replacement.
		local `rand_vals': list `rand_vals' - `val'
		
		* Assign a portion of the stratum to the randomly chosen assignment value.
		qui replace `generate' = ``val'' if `strata_cnt' <= ceil(``strata_size'' * ``rand_group'' / `groups') & `strata_current' == ``strata_num''
	}

	``hide_details'' dis "Ended at seed: " as result c(seed)
	
	* Confirm that we finished at the correct RNG state.
	assert(c(seed) == "``best_end_seed''")
		
	* Look at the results for this strata.
	if "`block'" != "" {
		dis as text _n "Assignment results for block ``strata_num'':"
	}
	else {
		dis as text _n "Assignment results:"
	}
	tab `generate' if `strata_current' == ``strata_num'', missing

	if "`block'" != "" {
		dis as text _n "Review balance within block ``strata_num'':"
	}
	else {
		dis as text _n "Review balance:"
	}
	mlogit `generate' ``balance_vars'' if `strata_current' == ``strata_num'', base(1) noomitted nolog
			
}

* Review the group assignments across all blocks.
dis as text _n "Assignment results:"
tab `generate' if `touse', m

* Aggregate the groups if desired, in order to generate unbalanced allocations from equally sized groups.
if "`aggregate'" != "" {
	tempvar temp_assignment
	tempname group_start assignment_iterator
	qui gen `temp_assignment' = .
	local `group_start' = 1
	local `assignment_iterator' = 1
	
	* Loop over each value of aggregate and merge the assignment groups.
	foreach `value' in `aggregate' {
		qui replace `temp_assignment' = ``assignment_iterator'' if `generate' >= ``group_start'' & `generate' < (``group_start'' + ``value'')
		
		* Iterate the aggregated assignment value.
		local ++`assignment_iterator'

		* Move up the assignment values we are working with, so that the next iteration will process that set of assignments.
		local `group_start' = ``group_start'' + ``value''
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

