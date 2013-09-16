
program define randomize
version 12.0

/*
* Conduct random assignment of a target population, dividing the recordly evenly across 2 or more groups.
* Optionally re-randomize a given number of times and choose the randomization with the best balance across a set of covariates.
* Also supports blocking.
* 
* Stata version 12 is required due to the p-value matrix on regression results, but CM has a code fix to support version 11.

* CREDITS: Thank you to Debby Kermer for earlier contributions to parts of the algorithm.

*!Author: Christopher B. Mann, Chris J. Kennedy
*!Date: 2013-03-14
*/

/*---------------------------------*
* Example syntax: randomize
 - optional settings:
	groups(integer) -> number of groups to create of equal size within the assignment variable, default to 2.
	minruns() -> minimum number of randomizations to run, default to 10. If blocks are specified this parameter will be per-block.
	maxruns() -> maximum number of randomizations to run, default to 10. If blocks are specified this parameter will be per-block.
	coeffthreshold() -> minimum p-value for an individual coefficient allowable to accept a given randomization. [may need to rename/rethink if we add mahalanohbis distance support.]
	jointp() -> minimum joint p-value allowable to accept a given randomization. [may need to rename/rethink if we add mahalanohbis distance support.]
	gen(newvar) -> name of the assignment variable, defaulting to _assignment.
	block(varlist) -> list of variables to block on.
	seed(integer) -> the random number generator seed to use, which ensures the randomization is deterministically repeatable.
	replace -> specify if the assignment variable can be replaced upon generation. If not, the script will generate an error if the assignment variable already exists.
 - options to potentially add later:	
 	mahalanobis distance support.
 	model(mlogit, mprobit, mahalanobis, etc.) -> algorithm used to assess balance. (Not Supported Yet)
 	nolog -> don't show the re-randomization log.
	TARgets(numlist >0 <=3 integer) -> moments of each covariate to control for, 1 = mean, 2 = variance, 3 = skewness.
	support for maximation customization, e.g. iterations(#) vce(passthru)
	saveseed(varname) if blocking is used, save the randomization seed used within each strata for QC purposes.

NOTES:
How to add this ado file to your Stata search path:
- You can type "sysdir" to see which folders you can put the ado file into for Stata to pick it up.
- Or you can type: adopath + "~/somefolder" to have Stata also search a new folder for .ado programs.

TODO/Thoughts:
- Should sortseed also be a parameter so that it is defaulted?
- Blocking code still needs to be tested - may be buggy.
- Convert local variables to tempvars so that we don't pollute the global namespace (for local variables).
- Scale down what should be displayed to the user.
- Do we want the result to also be randomly ordered, or not? Presume yes - useful when a voter contact program does not run through all records (e.g. phones).
- Would we want to save the probability that a record is assigned to a given class across all attempted randomizations? May be useful for randomization inference.
- This is basically bootstrapped randomization - may suggest similar parameters and output strategies. Also should look at MCMC simulation programming.
- Create unit tests to confirm that the randomization algorithm works correctly for a variety of experimental scenarios.
- Allow percentage breakdown between assignment groups (e.g. 70%/20%/10%) but then don't do automatic re-randomization per Lock / Rubin.
- Support cluster randomization directly within the algorithm eventually.

====================================*/



syntax [if] [in] [, GRoups(integer 2) MINruns(integer 10) MAXruns(integer 10) BALance(varlist) BLock(varlist) COEFFthreshold(real 0.05) JOintp(real 0.5) GENerate(name) seed(real 37) REPlace]

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
   * Drop the prior assignment variable if it is the default name or if the replace option was chosen.
   if "`generate'" == "`default_generate'" | "`replace'" != ""  {
	 cap drop `default_generate'
   }
   else {
     dis as err "variable `generate' already defined."
     exit	 
   }
}

* Create the assignment variable.
cap gen `generate' = . if `touse'


*++++++++++++++++++++++++++++++++++
* Begin randomization algorithm.
*++++++++++++++++++++++++++++++++++

* Create temporary variables.
tempvar strata_current strata_cnt rand_assign_current strata_cnt standard_order
* tempname balance_vars

* Create temporary local macros.
* tempname ***

	
*----------------------------------
* Display current setup.
*----------------------------------
	
dis "Balance variables: " as result "`balance'" as text "."
local num_balance_vars: word count `balance'
dis "Number of balance variables: " as result "`num_balance_vars'" as text "."
	
* Renumber Strata for each data subset
if "`block'" != "" {
	egen `strata_current' = group(`block') if `touse', label missing
}
else {
	* No blocking needed.
	gen `strata_current' = 1 if `touse'
}
qui tab `strata_current'
local num_strata = r(r)

*-------------------------------------------------------------------------- 
* Automated re-randomization until the balance regression passes criteria
*-------------------------------------------------------------------------- 

* Setup basic variables.
cap gen `rand_assign_current' = .
bysort `strata_current': gen `strata_cnt' = _n
gen `standard_order' = _n
	
* Stratified randomization with optimization in each strata.
* This loop will run once if we are not blocking on anything.
forvalues strata_num = 1/`num_strata' {
    * TODO: determine if this next line should be commented out? may be a bug.
	cap sum `strata_cnt' if `strata_current' == `strata_num'
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
			
		cap replace `rand_assign_current' = runiform() if `touse'
		* Sort each strata in random order and calculate size of each strata
		sort `strata_current' `rand_assign_current'
		cap bysort `strata_current' (`rand_assign_current'): replace `strata_cnt' = _n if `strata_current' == `strata_num'
		* Loop through the groups and assign a proportional allocation to each.
		forvalues rand_group = `groups'(-1)1 {
			* dis "replace `generate' = `rand_group' if `strata_cnt' <= round(`strata_size' * `rand_group' / `groups') & `strata_current' == `strata_num'"
			cap replace `generate' = `rand_group' if `strata_cnt' <= round(`strata_size' * `rand_group' / `groups') & `strata_current' == `strata_num'
		}
	
		*----------------------------------
		* Multinomial logit balance check.
		*----------------------------------
		* Use "noommitted" option so that omitted collinnear terms are not examined in p-value check.
		* This is not strictly necessary, but is cleaner.
		cap mlogit `generate' `balance_vars' if `strata_current' == `strata_num', base(1) noomitted				

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
						

		* String variable to output if we updated our best attempt with this try.
		local used_try = ""
 				
 		if ( (`joint_p' >= `coeffthreshold' & `temp_min' >= `coeffthreshold' & `min' < `coeffthreshold') ///
			| (`joint_p' >= `best_joint_p' & (`temp_min' >= `coeffthreshold' | `min' < `coeffthreshold' | `best_joint_p' < `jointp'))) {
			local best_run = `tries'
			local min = `temp_min'		
			local best_joint_p = `joint_p'
			local best_start_seed = "`starting_seed'"
			local best_end_seed = c(seed)
			local used_try = "*"
		}
		dis "Strata `strata_num', Try " as result %2.0f `tries' as text ": LR Test p-value = " as result %06.4f `joint_p' as text "; minimum coeff p = " as result %05.3f `temp_min' as text ".`used_try'" 
	}
	dis "----"
	dis "Strata `strata_num'. Tries: `tries'. Best run: `best_run'. LR Test p-value: " as result %06.4f round(`best_joint_p', .0001) as text ", min coeff p-value: " as result %05.3f `min' as text "."
	dis "Start seed: `best_start_seed'. End seed: `best_end_seed'."
		
	*------------------------------------------
	* Re-run Best Randomization for Assignment
	*------------------------------------------
		
	dis "Skip to run `best_run'. Seed start: `best_start_seed'"
	set seed `best_start_seed'
	
	* Confirm that we are at the correct RNG state.
	assert("`best_start_seed'" == c(seed))
		
	* Save the seed for this strata in case we want to re-run anything.
	* TODO: decide if we actually want to enable this.
	* cap replace `strata_seed' = "`best_start_seed'" if strata_current == `strata_num' 
	
	* Sort by a deterministic order.
	sort `standard_order'
	cap replace `rand_assign_current' = runiform() if `touse'
	* Sort each strata in random order and calculate size of each strata
	sort `strata_current' `rand_assign_current'
	cap bysort `strata_current' (`rand_assign_current'): replace `strata_cnt' = _n if `touse'

	* Loop through the groups and assign a proportional allocation to each.
	forvalues rand_group = `groups'(-1)1 {
		cap replace `generate' = `rand_group' if `strata_cnt' <= round(`strata_size' * `rand_group' / `groups') & `strata_current' == `strata_num'
	}

	dis "Ended at seed: " as result c(seed)
	
	* Confirm that we finished at the correct RNG state.
	assert(c(seed) == "`best_end_seed'")
		
	* Look at the results for this strata.
	tab `generate' if `strata_current' == `strata_num', missing
		
	* Confirm final balance.
	mlogit `generate' `balance_vars' if `strata_current' == `strata_num', base(1) noomitted nolog
			
}
	
* TODO: display timer count.

end
