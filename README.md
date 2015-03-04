randomize.ado
=============

Stata module for random assignment, including blocking, balance checking, and automated rerandomization.

Installation
--------

*Net install version*

Stata 13 can install directly from github. If using Stata 12 this method may not work due to the "https".

  ```stata
  net install randomize, from(https://raw.githubusercontent.com/ck37/randomize_ado/master/)
  ``

*Manual version*

Download the zip file of the repository ([link](https://github.com/ck37/randomize_ado/archive/master.zip)), unzip it, then add that folder to Stata's search path for ado files. Example:

  ```stata
  . adopath + "~/Documents/randomize_ado-master/"
  ```

You will then be able to run the command and view the help file within Stata.

*Git version*

Install the [stata-git package](https://github.com/coderigo/stata-git), then use that to install randomize.ado directly from github.com. This requires that your system have "git" available via the command line.

  ```stata
  . ssc install git
  . git install http://github.com/ck37/randomize_ado
  ```


Examples
--------

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

8. Clustered Randomization v1 - compress the dataset to the cluster level, conduct the randomization, then move assignment back to the full dataset.

  ```stata
  <To be added>
  ```

9. Clustered Randomization v2 - select a random record within the cluster, conduct the randomization on those records, then apply the assignment to the full cluster.

  ```stata
  <To be added>
  ```
