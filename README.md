randomize.ado
=============

Stata module for random assignment, including blocking, balance checking, and automated rerandomization.

Installation
--------

Download the .ado & .shlp files and put them in a directory, such as ~/Documents/randomize/. Then add that folder to Stata's search path for ado files: adopath + "~/Documents/randomize/". You will then be able to run the command and view the help files within Stata.

Examples
--------

1. Randomize a dataset into 2 groups, checking for balance by gender.

  ```
  randomize, balance(gender)
  ```

2. Randomize a dataset into 5 equally-sized groups, blocking by state and gender.

  ```
  randomize, groups(5) block(state gender)
  ```

3. Randomize a dataset into 3 groups, checking for balance on age and gender. Rerandomize up to 100 times or until the balance p-value exceeds 0.2.

  ```
  randomize, groups(3) balance(age gender) jointp(0.2) maxruns(100)
  ```

4. Create 4 groups, check for covariate balance on gender, race, and age, block on state, choose the most balanced of 500 randomizations within each block, and specify the random number generator seed.

  ```stata
  randomize, groups(4) balance(gender race age) block(state) minruns(500) seed(1)
  ```

5. Create a 30% / 70% split by randomizing into 10 equally sized groups then aggregating those assignments.

  ```stata
  randomize, groups(10) aggregate(3 7)
  ```  
  
6. Clustered Randomization v1 - compress the dataset to the cluster level, conduct the randomization, then move assignment back to the full dataset.

  ```stata
  <To be added>
  ```

7. Clustered Randomization v2 - select a random record within the cluster, conduct the randomization on those records, then apply the assignment to the full cluster.

  ```stata
  <To be added>
  ```

8. Quiet randomization - use the quiet prefix to hide all randomization output.

  ```stata
  qui randomize, balance(state) minruns(1000)
  ```

9. Detailed randomization - use the details option show all randomization output.

  ```stata
  randomize, balance(state) minruns(1000) details
  ```
