## Description

**Randomize** conducts random assignment of units to equally sized groups. It can check for balance on a specified list of covariates.  If blocking variables are specified it will conduct the randomization within blocks. It can rerandomize within blocks a certain number of times, such as conducting 100 randomizations and choosing the randomization with the best balance across covariates. It can also rerandomize until the balance statistic (Wilks lambda from manova, similar to a likelihood ratio on a multinomial logit) exceeds a certain cut-off value (e.g. 0.2). If unequal allocation sizes are desired, multiple groups can be aggregated after the randomization.

For clustered random assignment, one will need to handle the clustering manually, such as collapsing the dataset to the cluster level or choosing one representative unit per cluster. The randomization algorithm can then be run on that dataset, and the assignments can be copied to all units in the cluster. Examples are provided below.

## Installation

### Net install (Recommended)

Stata 13 can install directly from github. If using Stata 12 this method may not work due to the "https".

  ```stata
  . net install randomize, from(https://raw.githubusercontent.com/ck37/randomize_ado/master/)
  ```

### Manual install

Download the zip file of the repository ([link](https://github.com/ck37/randomize_ado/archive/master.zip)), unzip it, then add that folder to Stata's search path for ado files. Example:

  ```stata
  . adopath + "~/Documents/randomize_ado-master/"
  ```

You will then be able to run the command and view the help file within Stata.

### Git install

Install the [stata-git package](https://github.com/coderigo/stata-git), then use that to install randomize.ado directly from github.com. This requires that your system have [git](http://git-scm.com/) available via the command line.

  ```stata
  . ssc install git
  . git install http://github.com/ck37/randomize_ado
  ```


## Examples

1. Randomize a dataset into 2 groups, checking for balance by gender.

  ```stata
  . randomize, balance(gender)
  ```

2. Randomize a dataset into 5 equally-sized groups, blocking by state and gender.

  ```stata
  . randomize, groups(5) block(state gender)
  ```

3. Randomize a dataset into 3 groups, checking for balance on age and gender. Rerandomize up to 100 times or until the balance p-value exceeds 0.2.

  ```stata
  . randomize, groups(3) balance(age gender) jointp(0.2) maxruns(100)
  ```

4. Create 4 groups, check for covariate balance on gender, race, and age, block on state, choose the most balanced of 500 randomizations within each block, and specify the random number generator seed.

  ```stata
  . randomize, groups(4) balance(gender race age) block(state) minruns(500) seed(1)
  ```

5. Create a 10% / 20% / 70% split by randomizing into 10 equally sized groups then aggregating those assignments.

  ```stata
  . randomize, groups(10) aggregate(1 2 7)
  ```  

6. Use the quiet prefix to hide all randomization output and just get the result.

  ```stata
  . quiet randomize, balance(state) minruns(1000)
  ```

7. Use the details option to show all randomization output.

  ```stata
  . randomize, balance(state) minruns(1000) details
  ```
  
8. Simulated dataset example - randomize 10,000 records across 4 blocks, and take the best randomization out of 500 per block.

  ```stata
  clear
  set obs 10000
  set seed 2
  gen covariate = uniform()
  gen block_var = ceil(uniform() * 4)
  randomize, block(block_var) balance(covariate) minruns(500)
  ```

9. Clustered Randomization v1 - select a random record within the cluster, conduct the randomization on those records, then apply the assignment to the full cluster.

  ```stata
  * Create a combined cluster id
  egen cluster_id = group(cluster_field1 cluster_field2)
  set seed 1
  set sortseed 2
  gen double random = runiform()
  * Randomly order individuals within clusters.
  bysort cluster_id (random): egen cluster_seq = seq()
  * Randomize using the demographics of the first cluster member to check for balance.
  randomize if cluster_seq == 1, balance(covar1 covar2) block(blockvar1 blockvar2) replace
  * Expand assignment to all units in the cluster.
  bysort cluster_id: egen assignment = mode(_assignment)
  ```

 One could skip the last step and treat a random unit per cluster in order to measure spillover effects within treatment clusters.

10. Clustered Randomization v2 - compress the dataset to the cluster level, conduct the randomization, then merge the assignment back to the full dataset.

  ```stata
  * Create a combined cluster id
  egen cluster_id = group(cluster_field1 cluster_field2)
  set seed 1
  set sortseed 2
  * Save the uncompressed version of the dataset.
  preserve
  * Aggregate to the cluster level, creating summary statistics for the randomization.
  collapse (mean) covar1 covar2 (max) rare_covar3 (count) cluster_size, by(cluster_id)
  * Execute the randomization at the cluster level.
  randomize, balance(covar1 covar2 rare_covar3) replace
  * Restrict to the data that we need.
  keep cluster_id _assignment
  save "cluster-assignments.dta", replace
  * Switch back to the full dataset.
  restore
  merge m:1 cluster_id using "cluster-assignments.data"
  ```
