randomize.ado
=============

Stata module for random assignment, including balance checking, blocking, and automated re-randomization.

Examples
--------

1. Minimal - randomize a dataset into two groups.

  ```
  randomize
  ```

2. Basic - randomize a dataset into three groups, check for balance on age and gender, ensuring that the joint balance test (LR) is greater than 0.2, and no individual covariate has a p-value less than 0.1.

  ```
  randomize, groups(3) balance(age gender) jointp(0.2) coeffthreshold(0.1)
  ```

3. Advanced - create 4 groups, check for covariate balance on gender, race, and age, block on state, choose the best of 30+ randomizations within each block, and specify the random number generator seed.

  ```
  randomize, groups(4) balance(gender race age) block(state) minruns(30) seed(1)
  ```
