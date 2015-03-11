{smcl}
{* *! version 0.2  3mar2015}{...}
{cmd:help randomize}
{hline}

{title:Title}

{pstd}
{hi:randomize} {hline 2} Random assignment for experimental trials, including blocking, balance checking, and automated rerandomization.
{p_end}

{marker syntax}{title:Syntax}

{pstd} 
{cmd:randomize} {ifin}{cmd:, }
[{it:options}]

{synoptset 23 tabbed}{...}
{synopthdr}
{synoptline}

{syntab:Main}
{synopt:{opt {ul on}bal{ul off}ance:(varlist)}} List of variables on which to test for balance. {p_end}
{synopt:{opt {ul on}gr{ul off}oups:(#)}} Number of groups to create of equal size within the assignment variable; default is {cmd:2}. {p_end}
{synopt:{opt {ul on}gen{ul off}erate(newvar)}} Name of the assignment variable; default is {cmd:_assignment}. {p_end}
{synopt:{opt {ul on}bl{ul off}ock(varlist)}} List of variables to block on. These are combined into a strata variable, and randomizations are conducted within blocks. {p_end}
{synopt:{opt {ul on}minr{ul off}uns(#)}} Minimum number of randomizations to run; default is {cmd:1}. Per-block. {p_end}
{synopt:{opt {ul on}maxr{ul off}uns(#)}} Maximum number of randomizations to run; default is {cmd:1}. Per-block. {p_end}
{synopt:{opt seed(integer)}} The random number generator seed to use, which ensures the randomization is replicable. Can also be set manually. {p_end}
{synopt:{opt replace}} Overwrite existing assignment variable. {p_end}
{synopt:{opt {ul on}agg{ul off}regate(numlist)}} Provide a list of numbers denoting how the resulting assignments should be aggregated into larger groups.
This allows for unequal allocation sizes while still checking balance on equally sized groups. The list of numbers must sum to the number of groups.

{syntab:Advanced}
{synopt:{opt jointp(real)}} Minimum balance p-value allowable to accept a given randomization, ranging from 0 to 1. {p_end}
{synopt:{opt details}} Show the detailed results for each randomization attempt, which are hidden by default.

{marker desc}{title:Description}

{pstd} {cmd:randomize} conducts random assignment of units to equally sized groups. It can check for balance on a specified list of covariates.
If blocking variables are specified it will conduct the randomization within blocks. It can rerandomize within blocks a certain number of times, such as conducting 100 randomizations
and choosing the randomization with the best balance across covariates. It can also rerandomize until the balance statistic (likelihood ratio on a multinomial logit)
exceeds a certain cut-off value (e.g. 0.2). If unequal allocation sizes are desired, multiple groups can be aggregated after the randomization.

{pstd} For clustered random assignment, one will need to handle the clustering manually, such as collapsing the dataset to the cluster level or choosing one representative unit
per cluster. The randomization algorithm can then be run on that dataset, and the assignments can be copied to all units in the cluster.

{marker ex}{title:Examples}

{phang}
{cmd:. randomize, balance(gender)}

{phang}
{cmd:. randomize, groups(3) balance(age gender) jointp(0.2)}

{phang}
{cmd:. randomize if in_sample == 1, groups(4) balance(gender race age) block(state) minruns(500) seed(1)}

{title:References}

{phang}
Lock Morgan, K. and Rubin, D. B. (2012). Rerandomization to improve covariate balance in experiments. Ann. Statist. Volume 40, Number 2, 1263-1282.
{p_end}

{phang}
Lock Morgan, K. (2011). Rerandomization to improve covariate balance in randomized experiments. PhD dissertation. Harvard University, Department of Statistics.
{p_end}

{title:Authors}

{pstd}Chris J. Kennedy{p_end}
{pstd}University of California, Berkeley{p_end}
{pstd}{browse "mailto:ck37@berkeley.edu":ck37@berkeley.edu}{p_end}
{pstd}{browse "http://ck37.com":http://ck37.com}{p_end}

{pstd}Christopher B. Mann{p_end}
{pstd}Louisiana State University{p_end}
{pstd}{browse "mailto:christopherbmann@gmail.com":christopherbmann@gmail.com}{p_end}
{pstd}{browse "http://www.christopherbmann.com/":http://www.christopherbmann.com}{p_end}

{title:Acknowledgements}

{phang} We thank Debby Kermer for earlier contributions to parts of the algorithm, John Ternovski for helpful comments, and Kari Lock Morgan for the underlying theory and suggestion of the Wilks lambda balance statistic.
