{smcl}
{* *! version 0.1  20jun2013}{...}
{cmd:help randomize}
{hline}

{title:Title}

{p2colset 5 13 15 2}{...}
{p2col :{hi:randomize} {hline 2}}Random assignment for experimental trials, including balance checking, blocking, and automated re-randomization.{p_end}
{p2colreset}{...}


{title:Syntax}


{marker desc}{title:Description}


{marker ex}{title:Examples}

{phang}
{cmd:. randomize}

{phang}
{cmd:. randomize, groups(3) balance(age gender) jointp(0.2) coeffthreshold(0.1)}

{phang}
{cmd:. randomize, groups(4) balance(gender race age) block(state) minruns(30) seed(1)}


{title:Author}

{pstd}Christopher B. Mann{p_end}
{pstd}Louisiana State University{p_end}
{pstd}{browse "mailto:christopherbmann@gmail.com":christopherbmann@gmail.com}{p_end}

{pstd}Chris Kennedy{p_end}
{pstd}The Voter Participation Center{p_end}
{pstd}{browse "mailto:chrisken@gmail.com":chrisken@gmail.com}{p_end}


{title:References}

{phang}Lock Morgan, K. and Rubin, D. B. (2012). Rerandomization to improve covariate balance in experiments. Ann. Statist. Volume 40, Number 2, 1263-1282.{p_end}
