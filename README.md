randomize.ado
=============

Stata module for random assignment, including blocking, balance checking, and automated rerandomization.

Installation
--------

Download the .ado and .shlp files, putting them in a directory, like ~/Documents/randomize/. Then add that folder to Stata's search path for ado files: adopath + "~/Documents/randomize/". You will then be able to run the command and view the help files within Stata.

Examples
--------

1. Minimal - randomize a dataset into two groups, checking for balance by gender.

  ```
  randomize, balance(gender)
  ```

2. Basic - randomize a dataset into three groups, check for balance on age and gender, ensuring that the joint balance test (LR) is greater than 0.2.

  ```
  randomize, groups(3) balance(age gender) jointp(0.2)
  ```

3. Advanced - create 4 groups, check for covariate balance on gender, race, and age, block on state, choose the most balanced of 500 randomizations within each block, and specify the random number generator seed.

  ```stata
  randomize, groups(4) balance(gender race age) block(state) minruns(500) seed(1)
  ```
  
4. Clustered Randomization v1 - compress the dataset to the cluster level, conduct the randomization, then move assignment back to the full dataset.

  ```stata
  <To be added>
  ```

5. Clustered Randomization v2 - select a random record within the cluster, conduct the randomization on those records, then apply the assignment to the full cluster.

  ```stata
  <To be added>
  ```

6. Quiet randomization - use the quiet prefix to hide randomization output.
  ```stata
  qui randomize, balance(state) minruns(1000)
  ```
