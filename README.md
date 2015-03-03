randomize.ado
=============

Stata module for random assignment, including balance checking, blocking, and automated re-randomization.

Examples
--------

1. Minimal - randomize a dataset into two groups, choosing the best of 10 randomizations based on balance by gender.

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

<To be added>

5. Clustered Randomization v2 - select a random record within the cluster, conduct the randomization on those records, then apply the assignment to the full cluster.

<To be added>
