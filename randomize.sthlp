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
[{opt {ul on}bal{ul off}ance:(varlist)}
{opt {ul on}gr{ul off}oups:(num)}
{opt {ul on}gen{ul off}erate:(_assignment)}
{opt {ul on}bl{ul off}ock:(varlist)}
{opt {ul on}minr{ul off}uns:(num)}
{opt {ul on}maxr{ul off}uns:(num)}
{opt jointp(real)}
{opt seed:(num)}
{opt replace}]

{marker desc}{title:Description}

{pstd} {cmd:randomize} conducts random assignment of units to equally sized groups. It can check for balance on a specified list of covariates.
If blocking variables are specified it will conduct the randomization within blocks. It can rerandomize within blocks a certain number of times, such as taking the
randomization with the best covariate balance out of 100 tries. It can also rerandomize until the balance statistic (likelihood ratio on a multinomial logit)
exceeds a certain cut-off value (e.g. 0.2). If unequal allocation sizes are desired, multiple groups can be aggregated after the randomization.

{pstd} For clustered random assignment, one will need to handle the clustering manually, such as collapsing the dataset to the cluster level or choosing one representative unit
per cluster. The randomization algorithm can then be run on that dataset, and the assignments can be copied to all units in the cluster.

{marker desc}{title:Options}

{pstd} {opt {ul on}bal{ul off}ance:(varlist)} - list of variables on which to test for balance. {p_end}

{pstd} {opt {ul on}gr{ul off}oups:(integer)} - number of groups to create of equal size within the assignment variable, default to 2. {p_end}

{pstd} {opt {ul on}gen{ul off}erate(newvar)} - name of the assignment variable, defaulting to _assignment. {p_end}

{pstd} {opt {ul on}bl{ul off}ock(varlist)} - list of variables to block on. These are combined into a strata variable, and randomizations are conducted within blocks. {p_end}

{pstd} {opt {ul on}minr{ul off}uns(num)} - minimum number of randomizations to run, default to 1. If blocks are specified this parameter will be per-block. {p_end}

{pstd} {opt {ul on}maxr{ul off}uns(num)} - maximum number of randomizations to run, default to 1. If blocks are specified this parameter will be per-block. {p_end}

{pstd} {opt jointp(real)} - minimum joint p-value allowable to accept a given randomization, ranging from 0 to 1. This p-value comes from a likelihood ratio test on a multinomial logit. {p_end}

{pstd} {opt seed(integer)} - the random number generator seed to use, which ensures the randomization is deterministically repeatable. {p_end}

{pstd} {opt replace} - overwrite the assignment variable if it already exists in the dataset. The script will generate an error if the assignment variable already exists and replace is not specified. {p_end}

{marker ex}{title:Examples}

{phang}
{cmd:. randomize, balance(gender)}

{phang}
{cmd:. randomize, groups(3) balance(age gender) jointp(0.2)}

{phang}
{cmd:. randomize if in_sample == 1, groups(4) balance(gender race age) block(state) minruns(500) seed(1)}

{title:References}

{phang}Lock Morgan, K. and Rubin, D. B. (2012). Rerandomization to improve covariate balance in experiments. Ann. Statist. Volume 40, Number 2, 1263-1282.{p_end}

{title:Author}

{pstd}Chris J. Kennedy{p_end}
{pstd}University of California, Berkeley{p_end}
{pstd}{browse "mailto:ck37@berkeley.edu":ck37@berkeley.edu}{p_end}

{pstd}Christopher B. Mann{p_end}
{pstd}Louisiana State University{p_end}
{pstd}{browse "mailto:christopherbmann@gmail.com":christopherbmann@gmail.com}{p_end}

{title:Acknowledgements}

{phang} Thank you to Debby Kermer for earlier contributions to parts of the algorithm, and to John Ternovski for helpful comments.
