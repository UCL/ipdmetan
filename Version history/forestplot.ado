* Program to generate forestplots -- used by ipdmetan etc. but can also be run by itself
*! version 1.0  David Fisher  31jan2014

* April 2013
*   Forked from main ipdmetan code

* September 2013
*   Following UK Stata Users Meeting, reworked the plotid() option as recommended by Vince Wiggins

* N.B. 1
* use == 0  subgroup labels
* use == 1  successfully estimated trial-level effects
* use == 2  unsuccessfully estimated trial-level effects ("Insufficient data")
* use == 3  subgroup effects
* use == 4  blank line, or between-subgroup heterogeneity info
* use == 5  overall effect
* use == 9  titles

program define forestplot
version 10		// metan is v9 and this doesn't use any more recent commands/syntaxes; v10 used only for sake of help file extension

syntax [namelist(min=3 max=5)] [if] [in] [, ///
	/// /* Sub-plot identifier for applying different appearance options, and dataset identifier to separate plots */
	PLOTID(string) DATAID(varname) ///
	/// /* General -forestplot- options (including any "passed through" from another program, e.g. ipdmetan) */
	BY(name) Classic DP(integer 2) EFORM EFFect(string) INTERaction LABels(name) LCOLs(namelist) NULLOFF RCOLs(namelist) RENOTE(string)  ///
	noNAme noNUll noOVerall noPRESERVE noSTATs noSUbgroup noWT ///
	/// /* x-axis options */
	XLABel(string) XTICk(string) XTItle(string asis) Range(numlist min=2 max=2) FAVours(string asis) FP(real 999) ///
	/// /* other "fine-tuning" options */
	noADJust ASPECT(real 0) ASText(integer 50) BOXscale(real 100.0) TEXTscale(real 100.0) XSIZe(real 0) YSIZe(real 0) ///
	* ]

	* If forestplot is being run "stand-alone" (i.e. not called from ipdmetan etc.), parse eform option
	if "`preserve'" == "" {
		_get_eformopts, soptions eformopts(`options') allowed(__all__)
		local options `"`s(options)'"'
		local eform = cond(`"`s(eform)'"'=="", "", "eform")
		if `"`effect'"'==`""' local effect = cond(`"`s(str)'"'=="", "Effect", `"`s(str)'"')
		if `"`interaction'"'!=`""' local effect `"Interact. `effect'"'
		preserve	// recreates the "nopreserve" option in Stata 11+
	}
	
	if "`nulloff'"!="" local null "nonull"	// allow "nulloff" as alternative to "nonull" for compatability with -metan-
	local graphopts `"`options'"'			// "graph region" options (also includes plotopts for now)

	* Set up variable names
	if `"`namelist'"'==`""' {		// if not specified, assume "standard" varnames			
		local _ES "_ES"
		local _LCI "_LCI"
		local _UCI "_UCI"
		local _WT "_WT"
		local _USE "_USE"
	}
	else {							// else check syntax of user-specified varnames
		local 0 `namelist'
		syntax varlist(min=3 max=5 numeric)
		tokenize `varlist'
		local _ES `1'
		local _LCI `2'
		local _UCI `3'
		local _WT = cond(`"`4'"'!=`""', `"`4'"', "_WT")
		local _USE = cond(`"`5'"'!=`""', `"`5'"', "_USE")
	}

	* if "`preserve'" == "" preserve	// recreates the "nopreserve" option in Stata 11+

	*** Set up data to use
	capture confirm numeric var `_USE'
	if _rc {
		if _rc!=7 {			// `_USE' does not exist
			tempvar _USE
			qui gen `_USE' = cond(missing(`_ES'*`_LCI'*`_UCI'), 2, 1)
		}
		else {
			disp as err `"_USE: variable `_USE' exists but is not numeric"'
			exit 198
		}
	}
	
	marksample touse
	qui keep if `touse' & !missing(`_USE')
	qui drop if `"`overall'"'!=`""' & `_USE' == 5
	qui drop if `"`subgroup'"'!=`""' & `_USE' == 3
	qui count
	if !r(N) {
		disp as err "no observations"
		exit 2000
	}
	qui drop `touse'
	tempvar obs
	qui gen long `obs'=_n
	
	* Check existence of `_ES', `_LCI', `_UCI' (all required)
	foreach x in _ES _LCI _UCI {
		confirm numeric var ``x''
	}
	
	* Check existence of `_WT'
	capture confirm numeric var `_WT'
	if _rc {
		if _rc!=7 {
			tempvar _WT
			qui gen `_WT' = 1		// generate as constant if doesn't exist
		}
		else {
			disp as err `"_WT: variable `_WT' exists but is not numeric"'
			exit 198
		}
	}
	qui replace `_WT'=`_WT'*100
	local awweight "[aw= `_WT']"
	
	* Check validity of `_USE' (already sorted out existence)
	capture assert !missing(`_ES'*`_LCI'*`_UCI') if `_USE' == 1
	local rctemp = _rc
	capture assert missing(`_ES'*`_LCI'*`_UCI') if `_USE' == 2
	if `rctemp' | _rc {
		disp as err `"effect sizes do not match with value of _USE"'
		exit 198
	}
	
	* Check existence of `labels' and `by'
	foreach x in labels by {
		local X = upper("`x'")
		if `"``x''"'!=`""' confirm var ``x''
		else cap confirm var _`X'
		if !_rc local `x' "_`X'"			// use default varnames if they exist and option not explicitly given
	}

	* Sort out `plotid'
	if `"`plotid'"'==`""' {
		tempvar plotid
		qui gen `plotid'=1		// create plotid as constant if not specified
		local np=1
		sort `obs'
	}
	else {
		if "`preserve'" != "" disp _n _c		// spacing if following on from ipdmetan (etc.)

		capture confirm var _BY
		local _by = cond(_rc, "", "_BY")
		capture confirm var _OVER
		local _over = cond(_rc, "", "_OVER")
		
		local 0 `plotid'
		syntax name(name=plname id="plotid") [, List noGRaph]

		if "`plname'"!="_n" {
			confirm var `plname'
			qui tab `plname', m
			local Nplvals = r(r)
			if `Nplvals'>20 {
				disp as err "plotid: variable takes too many values"
				exit 198
			}
			if `"`_over'"'==`""' {
				qui count if inlist(_USE, 1, 2) & missing(`plname')
				if r(N) {
					disp as err "Warning: plotid contains missing values"
					disp as err "plotid groups and/or allocated ordinal numbers may not be as expected"
					if "`list'"=="" disp as err "This may be checked using the 'list' suboption to 'plotid'"
				}
			}
		}
		
		* Create ordinal version of plotid...
		gen `touse' = inlist(_USE, 1, 2, 3, 5)
		local plvar `plname'

		* ...extra tweaking if passed through from ipdmetan/ipdover (i.e. _STUDY, and possibly _OVER, exists)
		if inlist("`plname'", "_STUDY", "_n", "_LEVEL", "_OVER") {
			capture confirm var _STUDY
			local _study = cond(_rc, "_LEVEL", "_STUDY")
			tempvar smiss
			qui gen `smiss' = missing(`_study')
			
			if "`plname'"=="_STUDY" {
				tempvar plvar
				qui bysort `touse' `smiss' (`_over' `_study') : gen `plvar' = _n if `touse' & !`smiss'
			}
			if "`plname'"=="_LEVEL" {
				tempvar plvar
				qui bysort `touse' `smiss' `_by' (`_over' `_study') : gen `plvar' = _n if `touse' & !`smiss'
			}
			if "`plname'"=="_n" {
				tempvar plvar
				qui bysort `touse' `smiss' (`_over' `_study') : gen `plvar' = _n if `touse' & !`smiss'
			}
		}
		tempvar plobs plotid
		qui bysort `touse' `smiss' `plvar' (`obs') : gen long `plobs' = `obs'[1] if `touse'
		qui bysort `touse' `smiss' `plobs' : gen long `plotid' = (_n==1) if `touse'
		qui replace `plotid' = sum(`plotid')
		local np = `plotid'[_N]					// number of `plotid' levels
		label var `plotid' "plotid"
		sort `obs'
		
		* Optionally list observations contained within each plotid group
		if "`list'" != "" {
			disp as text _n "plotid: observations marked by " as res "`plname'" as text ":"
			forvalues p=1/`np' {
				disp as text _n "-> plotid = " as res `p' as text ":"
				list `dataid' `_USE' `_by' `_over' `labels' if `plotid'==`p' & `touse', table noobs sep(0)
			}
			if `"`graph'"'!=`""' exit
		}
		drop `touse' `plobs' `smiss'
	}
	
	* Generate ordering variable (reverse sequential, since y axis runs bottom to top)
	assert inrange(`_USE', 0, 5)
	tempvar id
	qui gen int `id' = _N - _n + 1
	
	* Test validity of lcols and rcols
	foreach x in lcols rcols {
		if `"``x''"'!=`""' confirm var ``x'' 
	}
	
	* Default "lcol1" (if using ipdmetan) is list of study names, headed "Study ID"
	* If "_LABELS" exists, check whether labels exist for use==1 | use==2
	if `"`labels'"'==`""' local name `"noname"'		// turn on option noNAME
	else {
		capture assert missing(`labels') if inlist(`_USE', 1, 2)
		if !_rc local name `"noname"'				// turn on option noNAME
		else {
			tempvar names
			qui clonevar `names' = `labels' if inlist(`_USE', 1, 2)
		}
	}
	if "`name'" == `""' {
		local lcols = `"`names' `lcols'"'		// N.B. macro `name' is "optionally off"; macro `names' contains study names!
	}

	* ES and weight text columns
	tempvar estText weightText
	if `"`eform'"'!=`""' local xexp "exp"
	qui gen str `estText' = string(`xexp'(`_ES'), "%10.`dp'f") ///
		+ " (" + string(`xexp'(`_LCI'), "%10.`dp'f") + ", " + string(`xexp'(`_UCI'), "%10.`dp'f") + ")" ///
		if inlist(`_USE', 1, 3, 5) & !missing(`_ES')
	qui replace `estText' = "(Insufficient data)" if `_USE' == 2
	if `"`eform'"'==`""' {
		qui replace `estText' = " " + `estText' if `_ES'>=0 & `_USE'!=4	// indent by one character if non-negative, to line up
	}
	qui gen str `weightText' = string(`_WT', "%4.2f") if inlist(`_USE', 1, 3, 5) & !missing(`_ES')
	qui replace `weightText' = "" if `_USE' == 2
	
	
	// GET MIN AND MAX DISPLAY
	// SORT OUT TICKS- CODE PINCHED FROM MIKE AND FIDDLED. TURNS OUT I'VE BEEN USING SIMILAR NAMES...
	// AS SUGGESTED BY JS JUST ACCEPT ANYTHING AS TICKS AND RESPONSIBILITY IS TO USER!
	summ `_LCI', meanonly
	local DXmin = r(min)			// minimum confidence limit
	summ `_UCI', meanonly
	local DXmax = r(max)			// maximum confidence limit
	// DXmin & DXmax ARE THE LEFT AND RIGHT COORDS OF THE GRAPH PART

	local h0=0
	
	* xlabel not supplied by user: choose sensible values
	* default is for symmetrical limits, with 3 labelled values including null
	if "`xlabel'" == "" {
		local Gmodxhi=max(abs(float(`DXmin')), abs(float(`DXmax')))
		if `Gmodxhi'==. {
			local Gmodxhi=2
		}
		local DXmin=-`Gmodxhi'
		local DXmax=`Gmodxhi'
		
		* DF added March 2013: choose "sensible" label values for x-axis
		if `"`eform'"'==`""' {		// linear scale
			local mag = ceil(abs(log10(abs(float(`Gmodxhi')))))*sign(log10(abs(float(`Gmodxhi'))))	// order of magnitude
			local xdiff = abs(float(`Gmodxhi')-`mag')
			local xlab = `"`h0'"'
			foreach i of numlist 1 2 5 10 {
				local ii = `i'^`mag'
				if abs(float(`Gmodxhi') - `ii') <= float(`xdiff') {
					local xdiff = abs(float(`Gmodxhi') - `ii')
					local xlab = `"`xlab' `ii' -`ii'"'
				}
			}
		}
		else {						// log scale
			local mag = round(`Gmodxhi'/ln(2))
			local xdiff = abs(float(`Gmodxhi') - float(ln(2)))
			local xlab `"`h0'"'
			forvalues i=1/`mag' {
				local ii = ln(2^`i')
				local xlab = `"`xlab' `ii' -`ii'"'		// display all powers of 2
			}
			
			* If effect is small, use 1.5, 1.33, 1.25 or 1.11 instead, as appropriate
			foreach i of numlist 1.5 `=1/0.75' 1.25 `=1/0.9' {
				local ii = ln(`i')
				if abs(float(`Gmodxhi') - `ii') <= float(`xdiff') {
					local xdiff = abs(float(`Gmodxhi') - `ii')
					local xlab = `"`xlab' `ii' -`ii'"'
				}
			}					
		}
		numlist `"`xlab'"'
		local xlablist=r(numlist)
	}
	
	* xlabel supplied by user: parse and apply
	else {
		local 0 `"`xlabel'"'
		syntax anything(name=xlablist) [, FORCE *]
		local xlabopts `"`options'"'

		if `"`eform'"'!=`""' {					// assume given on exponentiated scale if "eform" specified, so need to take logs
			numlist "`xlablist'", range(>0)		// in which case, all values must be greater than zero
			local n : word count `r(numlist)'
			forvalues i=1/`n' {
				local xi : word `i' of `r(numlist)'
				local xlablist2 `"`xlablist2' `=ln(`xi')'"'
			}
			local xlablist "`xlablist2'"
		}
		if "`force'" == "" {
			numlist "`xlablist' `DXmin' `DXmax'", sort
			local n : word count `r(numlist)' 
			local DXmin2 : word 1 of `r(numlist)'
			local DXmax2 : word `n' of `r(numlist)'
		
			local Gmodxhi=max(abs(`DXmin'), abs(`DXmax'), abs(`DXmin2'), abs(`DXmax2'))	
			if `Gmodxhi'==.  local Gmodxhi=2
			local DXmin=-`Gmodxhi'
			local DXmax=`Gmodxhi'
		}										// "force" option only changes things if user supplies xlabel
		else {
			numlist "`xlablist'", sort
			local n : word count `r(numlist)' 
			local DXmin : word 1 of `r(numlist)'
			local DXmax : word `n' of `r(numlist)'
		}
	}
	
	* Ticks
	if "`xtick'" == "" {
		local xticklist `xlablist'		// if not specified, default to same as labels
	}
	else {
		gettoken xticklist : xtick, parse(",")
		if `"`eform'"'!=`""' {					// assume given on exponentiated scale if "eform" specified, so need to take logs
			numlist "`xticklist'", range(>0)		// in which case, all values must be greater than zero
			local n : word count `r(numlist)'
			forvalues i=1/`n' {
				local xi : word `i' of `r(numlist)'
				local xticklist2 `"`xticklist2' `=ln(`xi')'"'
			}
			local xticklist "`xticklist2'"
		}
		else {
			numlist "`xticklist'"
			local xticklist=r(numlist)
		}
	}
	
	* Range
	if "`range'" != `""' {
		if `"`eform'"'!=`""' {
			numlist "`range'", range(>0)
			tokenize "`range'"
			local range `"`=ln(`1')' `=ln(`2')'"'
		}
		else {
			numlist "`range'"
			local range=r(numlist)
		}
	}

	* Final calculation of DXmin and DXmax
	if "`range'" == `""' {
		numlist "`xlablist' `xticklist' `DXmin' `DXmax'", sort
		local n : word count `r(numlist)' 
		local DXmin : word 1 of `r(numlist)'
		local DXmax : word `n' of `r(numlist)'
	}
	else {
		numlist "`range'", sort
		local n : word count `r(numlist)' 
		local DXmin : word 1 of `r(numlist)'
		local DXmax : word `n' of `r(numlist)'
	}
		
	* If on exponentiated scale, re-label x-axis with exponentiated values (nothing else should need changing)
	if "`eform'" != "" {
		local xlblcmd ""
		foreach i of numlist `xlablist' {
			local lbl = string(`=exp(`i')',"%7.3g")
			local xlblcmd `"`xlblcmd' `i' "`lbl'""'
		}
	}
	else local xlblcmd `"`xlablist'"'
		
	local DXwidth = `DXmax'-`DXmin'
	if `DXmin' > 0 local h0 = 1				// presumably just an extra failsafe


// END OF TICKS AND LABELS

// MAKE OFF-SCALE ARROWS -- fairly straightforward
quietly {
	tempvar offscaleL offscaleR offLeftX offLeftX2 offRightX offRightX2 offYlo offYhi
	gen `offscaleL' = `_LCI' < `DXmin' & `_USE' == 1
	gen `offscaleR' = `_UCI' > `DXmax' & `_USE' == 1
	
	replace `_LCI' = `DXmin' if `_LCI' < `DXmin' & `_USE' == 1
	replace `_UCI' = `DXmax' if `_UCI' > `DXmax' & `_USE' == 1
	replace `_LCI' = . if `_UCI' < `DXmin' & `_USE' == 1
	replace `_UCI' = . if `_LCI' > `DXmax' & `_USE' == 1
	replace `_ES' = . if `_ES' < `DXmin' & `_USE' == 1
	replace `_ES' = . if `_ES' > `DXmax' & `_USE' == 1
}	// end quietly



*** Columns 
// OPTIONS FOR L-R JUSTIFY?
// HAVE ONE MORE COL POSITION THAN NECESSARY, COULD THEN R-JUSTIFY
// BY ADDING 1 TO LOOP, ALSO HAVE MAX DIST FOR OUTER EDGE
// HAVE USER SPECIFY % OF GRAPH USED FOR TEXT?

quietly {	// KEEP QUIET UNTIL AFTER DIAMONDS

	// TITLES
	summ `id'
	local max = r(max)
	local new = r(N)+4
	if `new' > _N set obs `new'		// create four new observations

	forvalues i = 1/4 {				// up to four lines for titles
		local idNew`i' = `max' + `i'
		local Nnew`i'=r(N)+`i'
		replace `id' = `idNew`i'' + 1 in `Nnew`i''
	}
	local borderline = `idNew1' - 0.25
	
	// LEFT COLUMNS
	* local maxline = 1
	if `"`lcols'"' != "" {
		local lcolsN = 0
		foreach x of local lcols {
			capture confirm var `x'
			if _rc {
				disp as err "Variable `x' not defined"
				exit _rc
			}
			local ++lcolsN
			
			tempvar left`lcolsN' leftLB`lcolsN' leftWD`lcolsN'
			capture confirm string var `x'
			if !_rc gen str `leftLB`lcolsN'' = `x'
			else {
				capture decode `x', gen(`leftLB`lcolsN'')
				if _rc {
					local f: format `x'
					gen str `leftLB`lcolsN'' = string(`x', "`f'")
					replace `leftLB`lcolsN'' = "" if `leftLB`lcolsN'' == "."
				}
			}
			local colName: variable label `x'
			if `"`colName'"' == "" & `"`x'"' !=`"`names'"' local colName = `"`x'"'
			
			// WORK OUT IF TITLE IS BIGGER THAN THE VARIABLE
			// SPREAD OVER UP TO FOUR LINES IF NECESSARY
			local titleln = length(`"`colName'"')
			tempvar tmpln
			gen `tmpln' = length(`leftLB`lcolsN'')
			qui summ `tmpln' if `_USE' != 0
			local otherln = r(max)
			drop `tmpln'
			
			// NOW HAVE LENGTH OF TITLE AND MAX LENGTH OF VARIABLE
			local spread = int(`titleln'/`otherln')+1
			if `spread' > 4 local spread = 4

			local line = 1
			local end = 0
			local count = -1
			local c2 = -2

			local first = word(`"`colName'"', 1)
			local last = word(`"`colName'"', `count')
			local nextlast = word(`"`colName'"', `c2')

			while `end' == 0 {
				replace `_USE' = 9  in `Nnew`line''		// added by DF - use 9 for titles (not used elsewhere)
				replace `leftLB`lcolsN'' = `"`last'"' + " " + `leftLB`lcolsN'' in `Nnew`line''
				local check = `leftLB`lcolsN''[`Nnew`line''] + `" `nextlast'"'	// what next will be

				local --count
				local last = word(`"`colName'"', `count')
				if `"`last'"' == "" local end = 1
	
				if length(`leftLB`lcolsN''[`Nnew`line'']) > `titleln'/`spread' | ///
					length(`"`check'"') > `titleln'/`spread' & `"`first'"' == `"`nextlast'"' {
					if `end' == 0 {
						local ++line
					}
				}
			}
		}		// end of foreach x of local lcols
	}
	* Now copy across previously generated titles (overall, sub est etc.)
	if `"`leftLB1'"'==`""' {
		tempvar left1 leftLB1 leftWD1
		gen `leftLB1'=""
		local lcolsN=1
	}
	if `"`labels'"'!=`""' replace `leftLB1' = `labels' if inlist(`_USE', 0, 3, 4, 5)

	// RIGHT COLUMNS
	// by default, rcols 1 and 2 are effect sizes and weights
	// "`stats'" and "`wt'" turn these optionally off
	if "`wt'" == "" {
		local rcols = "`weightText' " + "`rcols'"
		label var `weightText' "% Weight"
	}
	if "`stats'" == "" {
		local rcols = "`estText' " + "`rcols'"
		if "`effect'" == "" {
			if "`interaction'"!="" local effect "Interaction effect"
			else local effect `"Effect"'
		}
		label var `estText' "`effect' (`c(level)'% CI)"
	}

	// DF - is this "sorted out the extra top line that appears in column labels" ??  (see metan code)
	// Doesn't seem to do anything, but presumably it does on occasion
	tempvar extra
	gen `extra' = ""
	label var `extra' " "
	local rcols = `"`rcols' `extra'"'

	local rcolsN = 0
	if `"`rcols'"' != "" {
		local rcolsN = 0
		foreach x of local rcols {
			capture confirm var `x'
			if _rc {
				disp as err "Variable `x' not defined"
				exit _rc
			}
			local ++rcolsN
			
			tempvar right`rcolsN' rightLB`rcolsN' rightWD`rcolsN'
			cap confirm string var `x'
			if !_rc gen str `rightLB`rcolsN'' = `x'
			else {
				local f: format `x'
				gen str `rightLB`rcolsN'' = string(`x', "`f'")
				replace `rightLB`rcolsN'' = "" if `rightLB`rcolsN'' == "."
			}
			local colName: variable label `x'
			if `"`colName'"' == "" local colName = `"`x'"'
			
			// WORK OUT IF TITLE IS BIGGER THAN THE VARIABLE
			// SPREAD OVER UP TO FOUR LINES IF NECESSARY
			local titleln = length(`"`colName'"')
			tempvar tmpln
			gen `tmpln' = length(`rightLB`rcolsN'')
			qui summ `tmpln' if `_USE' != 0
			local otherln = r(max)
			drop `tmpln'
			
			// NOW HAVE LENGTH OF TITLE AND MAX LENGTH OF VARIABLE
			local spread = int(`titleln'/`otherln')+1
			if `spread' > 4 local spread = 4

			local line = 1
			local end = 0
			local count = -1
			local c2 = -2

			local first = word(`"`colName'"', 1)
			local last = word(`"`colName'"', `count')
			local nextlast = word(`"`colName'"', `c2')

			while `end' == 0 {
				replace `_USE' = 9  in `Nnew`line''		// added by DF - use 9 for titles (not used elsewhere)
				replace `rightLB`rcolsN'' = `"`last'"' + " " + `rightLB`rcolsN'' in `Nnew`line''
				local check = `rightLB`rcolsN''[`Nnew`line''] + `" `nextlast'"'	// what next will be

				local --count
				local last = word(`"`colName'"', `count')
				if `"`last'"' == "" local end = 1
	
				if length(`rightLB`rcolsN''[`Nnew`line'']) > `titleln'/`spread' | ///
					length(`"`check'"') > `titleln'/`spread' & `"`first'"' == `"`nextlast'"' {
					if `end' == 0 {
						local ++line
					}
				}
			}
		}		// end of foreach x of local rcols
	}
	
	// now get rid of extra title rows if they weren't used
	drop if missing(`_USE')

	/* BODGE SOLU- EXTRA COLS */
	while `rcolsN' < 2 {
		local ++rcolsN
		tempvar right`rcolsN' rightLB`rcolsN' rightWD`rcolsN'
		gen str `rightLB`rcolsN'' = " "
	}
	
	// sort out titles for stats and weight, if there
	local skip = 1
	if "`stats'" == "" & "`wt'" == "" local skip = 3
	if "`stats'" != "" & "`wt'" == "" local skip = 2
	if "`stats'" == "" & "`wt'" != "" local skip = 2
	if "`counts'" != "" local skip = `skip' + 2
	
	/* SET TWO DUMMY RCOLS IF NOSTATS NOWEIGHT */
	forvalues i = `skip'/`rcolsN' {					// get rid of junk if not weight, stats or counts
		replace `rightLB`i'' = "" if !inlist(`_USE', 1, 2, 3, 5, 9)
	}
	forvalues i = 1/`rcolsN' {
		replace `rightLB`i'' = "" if `_USE' == 0
	}
	
	// Calculate "leftWDtot" and "rightWDtot" -- the total widths to left and right of graph area
	// Don't use titles or overall stats, just trial stats.
	local leftWDtot = 0
	local rightWDtot = 0
	local leftWDtotNoTi = 0

	forvalues i = 1/`lcolsN' {
		getWidth `leftLB`i'' `leftWD`i''
		summ `leftWD`i'' if inlist(`_USE', 1, 2), meanonly
		local maxL = cond(r(N), r(max), 0)
		local leftWDtot = `leftWDtot' + `maxL'
		replace `leftWD`i'' = `maxL'
	}
	forvalues i = 1/`rcolsN' {
		getWidth `rightLB`i'' `rightWD`i''
		summ `rightWD`i'' if inlist(`_USE', 1, 2), meanonly
		if !r(N) qui summ `rightWD`i''						// if maxL = 0, use all obs, to at least have all data within the plotregion
		local maxL = cond(r(N), r(max), 0)					// (extreme case only)
		local rightWDtot = `rightWDtot' + `maxL'
		replace `rightWD`i'' = `maxL'
	}
	
	// CHECK IF NOT WIDE ENOUGH (I.E., OVERALL INFO TOO WIDE)
	// LOOK FOR EDGE OF DIAMOND summ `_LCI' if `_USE' == ...
	if "`adjust'" != "" {
		tempvar maxLeft
		getWidth `leftLB1' `maxLeft'
		qui count if inlist(`_USE', 0, 3, 5)
		if r(N) {
			summ `maxLeft' if inlist(`_USE', 0, 3, 5), meanonly
			local max = r(max)

			if `max' > `leftWDtot'{
				// WORK OUT HOW FAR INTO PLOT CAN EXTEND
				// We want ymin = x - 1.  Given that, rearrange to find new leftWDtot:
				tempvar lci2
				qui gen `lci2' = cond(`_LCI'>0, 0, `_LCI')
				qui summ `lci2' if inlist(`_USE', 3, 5)
				local lcimin=r(min)
				
				// BUT don't make it any less than before, unless there are no obs with inlist(`_USE', 1, 2)
				local newleftWDtot = ((`max'+`rightWDtot') / ( ( ((`lcimin'-`DXmin')/`DXwidth') * ((100-`astext')/`astext') ) + 1)) - `rightWDtot'
				summ `leftWD`i'' if inlist(`_USE', 1, 2), meanonly
				if r(N) local leftWDtot = max(`leftWDtot', `newleftWDtot')
				else local leftWDtot = `newleftWDtot'

				drop `lci2' `diff'
			}
		}
	}

	// Generate position of lcols, using user-specified `astext'
	// (% of graph width taken by text)
	local textWD = (`DXwidth'/(1-`astext'/100) - `DXwidth') / (`leftWDtot'+`rightWDtot')

	// Now, carry on as before
	local leftWDtot2 = `leftWDtot'
	forvalues i = 1/`lcolsN'{
		gen `left`i'' = `DXmin' - `leftWDtot2'*`textWD'
		local leftWDtot2 = `leftWDtot2'-`leftWD`i''
	}
	
	gen `right1' = `DXmax'
	forvalues i = 2/`rcolsN'{
		local r2 = `i'-1
		gen `right`i'' = `right`r2'' + `rightWD`r2''*`textWD'
	}

	// AXmin AXmax ARE THE OVERALL LEFT AND RIGHT COORDS
	local AXmin = `left1'
	local AXmax = `DXmax' + `rightWDtot'*`textWD'
	
	// DIAMONDS TAKE FOREVER...I DON'T THINK THIS IS WHAT MIKE DID
	tempvar DiamLeftX DiamRightX DiamBottomX DiamTopX DiamLeftY1 DiamRightY1 DiamLeftY2 DiamRightY2 DiamBottomY DiamTopY
	gen `touse' = inlist(`_USE', 3, 5)

	gen `DiamLeftX' = `_LCI' if `touse'
	replace `DiamLeftX' = `DXmin' if `touse' & `_LCI' < `DXmin'
	replace `DiamLeftX' = . if `touse' & `_ES' < `DXmin'

	gen `DiamLeftY1' = `id' if `touse'
	replace `DiamLeftY1' = `id' + 0.4*( abs((`DXmin'-`_LCI')/(`_ES'-`_LCI')) ) if `touse' & `_LCI' < `DXmin'
	replace `DiamLeftY1' = . if `touse' & `_ES' < `DXmin'
	
	gen `DiamLeftY2' = `id' if `touse'
	replace `DiamLeftY2' = `id' - 0.4*( abs((`DXmin'-`_LCI')/(`_ES'-`_LCI')) ) if `touse' & `_LCI' < `DXmin'
	replace `DiamLeftY2' = . if `touse' & `_ES' < `DXmin'

	gen `DiamRightX' = `_UCI' if `touse'
	replace `DiamRightX' = `DXmax' if `touse' & `_UCI' > `DXmax'
	replace `DiamRightX' = . if `touse' & `_ES' > `DXmax'
	
	gen `DiamRightY1' = `id' if `touse'
	replace `DiamRightY1' = `id' + 0.4*( abs((`_UCI'-`DXmax')/(`_UCI'-`_ES')) ) if `touse' & `_UCI' > `DXmax'
	replace `DiamRightY1' = . if `touse' & `_ES' > `DXmax'
	
	gen `DiamRightY2' = `id' if `touse'
	replace `DiamRightY2' = `id' - 0.4*( abs((`_UCI'-`DXmax')/(`_UCI'-`_ES')) ) if `touse' & `_UCI' > `DXmax'
	replace `DiamRightY2' = . if `touse' & `_ES' > `DXmax'
	
	gen `DiamBottomY' = `id' - 0.4 if `touse'
	replace `DiamBottomY' = `id' - 0.4*( abs((`_UCI'-`DXmin')/(`_UCI'-`_ES')) ) if `touse' & `_ES' < `DXmin'
	replace `DiamBottomY' = `id' - 0.4*( abs((`DXmax'-`_LCI')/(`_ES'-`_LCI')) ) if `touse' & `_ES' > `DXmax'
	
	gen `DiamTopY' = `id' + 0.4 if `touse'
	replace `DiamTopY' = `id' + 0.4*( abs((`_UCI'-`DXmin')/(`_UCI'-`_ES')) ) if `touse' & `_ES' < `DXmin'
	replace `DiamTopY' = `id' + 0.4*( abs((`DXmax'-`_LCI')/(`_ES'-`_LCI')) ) if `touse' & `_ES' > `DXmax'

	gen `DiamTopX' = `_ES' if `touse'
	replace `DiamTopX' = `DXmin' if `touse' & `_ES' < `DXmin'
	replace `DiamTopX' = `DXmax' if `touse' & `_ES' > `DXmax'
	replace `DiamTopX' = . if `touse' & (`_UCI' < `DXmin' | `_LCI' > `DXmax')
	gen `DiamBottomX' = `DiamTopX'

}	// END QUI


// v1.11 TEXT SIZE SOLU
// v1.16 TRYING AGAIN!
// IF aspect IS SPECIFIED THEN THIS HELPS TO CALCULATE TEXT SIZE
// IF NO ASPECT, BUT xsize AND ysize USED THEN FIND RATIO MANUALLY
// STATA ALWAYS TRIES TO PRODUCE A GRAPH WITH ASPECT ABOUT 0.77 - TRY TO FIND "NATURAL ASPECT"

// ipdmetan v1.0: FUTURE WORK MIGHT BE TO REFINE THIS,
// TO TAKE ACCOUNT OF THE FACT THAT THE IDEAL ASPECT RATIO VARIES WITH THE NUMBER OF INCLUDED STUDIES
// e.g. ONLY 2 OR 3 = VERY SHORT & WIDE; ipdover MIGHT NEED VERY LONG & NARROW

numlist `"`aspect' `xsize' `ysize'"', range(>=0)				// check that all are >=0
if `xsize' > 0 & `ysize' > 0 & `aspect' == 0 local aspect = `ysize'/`xsize'

local approx_chars = (`leftWDtot' + `rightWDtot')/(`astext'/100)
qui count if `_USE' != 9
local height = r(N)
local natu_aspect = 1.3 * `height'/`approx_chars'

if `aspect' == 0 {
	// sort out relative to text, but not to ridiculous degree
	local new_asp = 0.5 * (`natu_aspect' + 1)
	local graphopts `"`graphopts' aspect(`new_asp')"'			// this will override any previous aspect() option
	local aspectRat = max(`new_asp'/`natu_aspect', `natu_aspect'/`new_asp')
}
else {
	local aspectRat = max(`aspect'/`natu_aspect', `natu_aspect'/`aspect')
}

local adj = 1.25
if `natu_aspect' > 0.7 local adj = 1/(`natu_aspect'^1.3+0.2)

local textSize = `adj' * `textscale' / (`approx_chars' * sqrt(`aspectRat') )

forvalues i = 1/`lcolsN' {
	local lcolCommands `"`macval(lcolCommands)' || scatter `id' `left`i'', msymbol(none) mlabel(`leftLB`i'') mlabcolor(black) mlabpos(3) mlabsize(`textSize')"'
}
forvalues i = 1/`rcolsN' {
	local rcolCommands `"`macval(rcolCommands)' || scatter `id' `right`i'' if `_USE' != 4, msymbol(none) mlabel(`rightLB`i'') mlabcolor(black) mlabpos(3) mlabsize(`textSize')"'
}


// FAVOURS
if `"`favours'"' != `""' {

	* DF added Jan 2013: allow multiple lines (cf twoway title option)
	gettoken leftfav rest : favours, parse("#") quotes
	if `"`leftfav'"'!=`"#"' {
		while `"`rest'"'!=`""' {
			gettoken next rest : rest, parse("#") quotes
			if `"`next'"'==`"#"' continue, break
			local leftfav `"`leftfav' `next'"'
		}
	}
	else local leftfav `""'
	local rightfav `"`rest'"'

	if `fp'>0 & `fp'<999 {					// 999 is a dummy "default"
		local leftfp = -`fp'
		local rightfp = `fp'
	}
	else if "`h0'" != "" & "`null'" == "" {
		local leftfp = `DXmin' + (`h0'-`DXmin')/2
		local rightfp = `h0' + (`DXmax'-`h0')/2
	}
	else {
		local leftfp = `DXmin'
		local rightfp = `DXmax'
	}
	local favopt `"xmlabel(`leftfp' `"`leftfav'"' `rightfp' `"`rightfav'"', noticks labels labsize(`textSize') labgap(5))"'
}

* xtitle - uses 'xmlabel' options, not 'title' options!  Parse all 'title' options to give suitable error message
else if `"`xtitle'"' != `""' {
	local 0 `"`xtitle'"'
	syntax [anything] [, TSTYle(string) ORIENTation(string) SIze(string) Color(string) Justification(string) ///
		ALignment(string) Margin(string) LINEGAP(string) WIDTH(string) HEIGHT(string) BOX NOBOX ///
		BColor(string) FColor(string) LStyle(string) LPattern(string) LWidth(string) LColor(string) ///
		BMargin(string) BEXpand(string) PLACEment(string) *]
	if `"`size'"'!=`""' local labsizeopt `"labsize(`size')"'
	if `"`labsize'"'!=`""' local labsizeopt `"labsize(`labsize')"'
	else local labsizeopt `"labsize(`textSize')"'
	if `"`color'"'!=`""' local labcoloropt `"labcolor(`color')"'
	if `"`labcolor'"'!=`""' local labcoloropt `"labcolor(`labcolor')"'
	if !(`"`tstyle'"'==`""' & `"`orientation'"'==`""' & `"`justification'"'==`""' & `"`alignment'"'==`""' ///
		& `"`margin'"'==`""' & `"`linegap'"'==`""' & `"`width'"'==`""' & `"`height'"'==`""' & `"`box'"'==`""' & `"`nobox'"'==`""' ///
		& `"`bcolor'"'==`""' & `"`fcolor'"'==`""' & `"`lstyle'"'==`""' & `"`lpattern'"'==`""' & `"`lwidth'"'==`""' & `"`lcolor'"'==`""' ///
		& `"`bmargin'"'==`""' & `"`bexpand'"'==`""' & `"`placement'"'==`""') {
		disp as err `"option xtitle uses xmlabel options, not title options!  see help axis_label_options"'
		exit 198
	}
	local xtitleopt `"xmlabel(`h0' `"`anything'"', noticks labels `labsizeopt' `labcoloropt' labgap(5) `options')"'
}


// GRAPH APPEARANCE OPTIONS
local boxSize = `boxscale'/150

summ `id', meanonly
local DYmin = r(min)-1
local DYmax = r(max)+1

tempvar useno
qui gen byte `useno' = `_USE' * inlist(`_USE', 3, 5)

cap confirm var `dataid'
if _rc {
	tempvar dataid
	gen `dataid'=1
}
sort `dataid' `id'
qui replace `useno' = `useno'[_n-1] if `useno'<=`useno'[_n-1] & `dataid'==`dataid'[_n-1]	// find the largest value (from 3 & 5) "so far"

* Flag obs through which the line should be drawn
tempvar ovLine
qui gen `ovLine'=.		// need this var to exist regardless

summ `useno', meanonly
if r(max) {
	tempvar olinegroup check ovMin ovMax
	qui gen int `olinegroup' = (`_USE'==`useno') & `useno'>0
	qui bysort `dataid' (`id') : replace `olinegroup' = sum(`olinegroup') if inlist(`_USE', 1, 2, 3, 5)	// study obs & pooled results

	* Store min and max values for later plotting
	qui gen byte `check' = inlist(`_USE', 1, 2)
	qui bysort `dataid' `olinegroup' (`check') : replace `check' = `check'[_N]		// only draw oline if there are study obs in the same olinegroup
	qui replace `ovLine' = `_ES' if `_USE'==`useno' & `useno'>0 & `check' & !(`_ES' > `DXmax' | `_ES' < `DXmin')

	sort `dataid' `olinegroup' `id'
	qui by `dataid' `olinegroup' : gen `ovMin' = `id'[1]-0.5 if `_USE'==`useno' & `useno'>0 & !missing(`ovLine')
	qui by `dataid' `olinegroup' : gen `ovMax' = `id'[_N]+0.5 if `_USE'==`useno' & `useno'>0 & !missing(`ovLine')
	drop `useno' `olinegroup' `check' `dataid'
}


*** Get options and store plot commands

** "Global" options
local 0 `", `graphopts'"'
syntax [, ///
	/// /* standard options */
	BOXOPts(string asis) DIAMOPts(string asis) POINTOPts(string asis) CIOPts(string asis) OLINEOPts(string asis) ///
	/// /* non-diamond options */
	PPOINTOPts(string asis) PCIOPts(string asis) * ]

local rest `"`options'"'

* Global CI style (bare lines or capped lines)
* (Also test for disallowed options during same parse)
local 0 `", `ciopts'"'
syntax [, HORizontal VERTical Connect(string asis) RCAP * ]
if `"`horizontal'"'!=`""' | `"`vertical'"'!=`""' {
	disp as err "ciopts: options horizontal/vertical not allowed"
	exit 198
}			
if `"`connect'"' != `""' {
	disp as err "ciopts: option connect() not allowed"
	exit 198
}
local ciopts `"`options'"'
local CIPlotType = cond("`rcap'"=="", "rspike", "rcap")
local pCIPlotType `CIPlotType'

* "Default" options
local dispShape = cond("`interaction'"!="", "circle", "square")
local DefColor = cond("`classic'"!="", "black", "180 180 180")
local DefBoxopts = `"mcolor("`DefColor'") msymbol(`dispShape') msize(`boxSize')"'
local DefCIopts `"lcolor(black) mcolor(black)"'		// includes "mcolor" for arrows (doesn't affect rspike/rcap)
local DefPointopts `"msymbol(diamond) mcolor(black) msize(vsmall)"'
local DefOlineopts `"lwidth(thin) lcolor(maroon) lpattern(shortdash)"'
local DefDiamopts `"lcolor("0 0 100")"'
local DefPPointopts `"msymbol("`dispShape'") mlcolor("0 0 100") mfcolor("none")"'
local DefPCIopts `"lcolor("0 0 100")"'

* Loop over possible values of `plotid' and test for plotopts relating specifically to each value
numlist "1/`np'"
local plvals=r(numlist)
local pplvals `plvals'
foreach p of local plvals {

	local 0 `", `rest'"'
	syntax [, ///
		/// /* standard options */
		BOX`p'opts(string asis) DIAM`p'opts(string asis) POINT`p'opts(string asis) CI`p'opts(string asis) OLINE`p'opts(string asis) ///
		/// /* non-diamond options
		PPOINT`p'opts(string asis) PCI`p'opts(string asis) * ]

	local rest `"`options'"'

	* Check if any options were found specifically for this value of `p'
	if `"`box`p'opts'`diam`p'opts'`point`p'opts'`ci`p'opts'`oline`p'opts'`ppoint`p'opts'`pci`p'opts'"' != `""' {
		
		local pplvals : list pplvals - p			// remove from list of "default" plotids
		
		* WEIGHTED SCATTER PLOT
		local 0 `", `box`p'opts'"'
		syntax [, MLABEL(string asis) MSIZe(string asis) * ]			// check for disallowed options
		if `"`mlabel'"' != `""' {
			disp as error "box`p'opts: option mlabel() not allowed"
			exit 198
		}
		if `"`msize'"' != `""' {
			disp as error "box`p'opts: option msize() not allowed"
			exit 198
		}
		qui count if `_USE'==1 & `plotid'==`p'
		if r(N) {
			summ `_WT' if `_USE'==1 & `plotid'==`p', meanonly
			if !r(N) disp as err `"No weights found for plotid `p'"'
			else local scPlot `"`macval(scPlot)' || scatter `id' `_ES' `awweight' if `_USE'==1 & `plotid'==`p', `DefBoxopts' `boxopts' `box`p'opts'"'
		}		
		
		* CONFIDENCE INTERVAL PLOT
		local 0 `", `ci`p'opts'"'
		syntax [, HORizontal VERTical Connect(string asis) RCAP * ]			// check for disallowed options + rcap
		if `"`horizontal'"'!=`""' | `"`vertical'"'!=`""' {
			disp as error "ci`p'opts: options horizontal/vertical not allowed"
			exit 198
		}			
		if `"`connect'"' != `""' {
			di as error "ci`p'opts: option connect() not allowed"
			exit 198
		}
		local ci`p'opts `"`options'"'
		local CIPlot`p'Type `CIPlotType'										// global status
		local CIPlot`p'Type = cond("`rcap'"=="", "`CIPlot`p'Type'", "rcap")		// overwrite global status if appropriate
		local CIPlot `"`macval(CIPlot)' || `CIPlot`p'Type' `_LCI' `_UCI' `id' if `_USE'==1 & `plotid'==`p' & !`offscaleL' & !`offscaleR', hor `DefCIopts' `ciopts' `ci`p'opts'"'		

		qui count if `plotid'==`p' & `offscaleL' & `offscaleR'
		if r(N) {													// both ends off scale
			local CIPlot `"`macval(CIPlot)' || pcbarrow `id' `_LCI' `id' `_UCI' if `plotid'==`p' & `offscaleL' & `offscaleR', `DefCIopts' `ciopts' `ci`p'opts'"'
		}
		qui count if `plotid'==`p' & `offscaleL' & !`offscaleR'
		if r(N) {													// only left off scale
			local CIPlot `"`macval(CIPlot)' || pcarrow `id' `_UCI' `id' `_LCI' if `plotid'==`p' & `offscaleL' & !`offscaleR', `DefCIopts' `ciopts' `ci`p'opts'"'
			if "`CIPlot`p'Type'" == "rcap" {			// add cap to other end if appropriate
				local CIPlot `"`macval(CIPlot)' || rcap `_UCI' `_UCI' `id' if `plotid'==`p' & `offscaleL' & !`offscaleR', hor `DefCIopts' `ciopts' `ci`p'opts'"'
			}
		}
		qui count if `plotid'==`p' & !`offscaleL' & `offscaleR'
		if r(N) {													// only right off scale
			local CIPlot `"`macval(CIPlot)' || pcarrow `id' `_LCI' `id' `_UCI' if `plotid'==`p' & !`offscaleL' & `offscaleR', `DefCIopts' `ciopts' `ci`p'opts'"'
			if "`CIPlot`p'Type'" == "rcap" {			// add cap to other end if appropriate
				local CIPlot `"`macval(CIPlot)' || rcap `_LCI' `_LCI' `id' if `plotid'==`p' & !`offscaleL' & `offscaleR', hor `DefCIopts' `ciopts' `ci`p'opts'"'
			}
		}

		* POINT PLOT (point estimates -- except if "classic")
		if "`classic'" == "" {
			local pointPlot `"`macval(pointPlot)' || scatter `id' `_ES' if `_USE'==1 & `plotid'==`p', `DefPointopts' `pointopts' `point`p'opts'"'
		}
		
		* OVERALL LINE(S) (if appropriate)
		summ `ovLine' if `plotid'==`p', meanonly
		if r(N) {
			local olinePlot `"`macval(olinePlot)' || rspike `ovMin' `ovMax' `ovLine' if `plotid'==`p', `DefOlineopts' `olineopts' `oline`p'opts'"'
		}		

		* POOLED EFFECT - DIAMOND
		* Assume diamond if no "pooled point/CI" options, and no "interaction" option
		if `"`ppointopts'`ppoint`p'opts'`pciopts'`pci`p'opts'`interaction'"' == `""' {
			local diamPlot `"`macval(diamPlot)' || pcspike `DiamLeftY1' `DiamLeftX' `DiamTopY' `DiamTopX' if `plotid'==`p', `DefDiamopts' `diamopts' `diam`p'opts'"'
			local diamPlot `"`macval(diamPlot)' || pcspike `DiamTopY' `DiamTopX' `DiamRightY1' `DiamRightX' if `plotid'==`p', `DefDiamopts' `diamopts' `diam`p'opts'"'
			local diamPlot `"`macval(diamPlot)' || pcspike `DiamRightY2' `DiamRightX' `DiamBottomY' `DiamBottomX' if `plotid'==`p', `DefDiamopts' `diamopts' `diam`p'opts'"'
			local diamPlot `"`macval(diamPlot)' || pcspike `DiamBottomY' `DiamBottomX' `DiamLeftY2' `DiamLeftX' if `plotid'==`p', `DefDiamopts' `diamopts' `diam`p'opts'"'
		}
		
		* POOLED EFFECT - PPOINT/PCI
		else {
			if `"`diam`p'opts'"'!=`""' {
				disp as err `"plotid `p': cannot specify options for both diamond and pooled point/CI"'
				disp as err `"diamond options will be ignored"'
			}	
		
			local 0 `", `pci`p'opts'"'
			syntax [, HORizontal VERTical Connect(string asis) RCAP *]
			if `"`horizontal'"'!=`""' | `"`vertical'"'!=`""' {
				disp as error "pci`p'opts: options horizontal/vertical not allowed"
				exit 198
			}			
			if `"`connect'"' != `""' {
				di as error "pci`p'opts: option connect() not allowed"
				exit 198
			}
			local pCIPlot`p'Type `pCIPlotType'											// global status
			local pCIPlot`p'Type = cond("`rcap'"=="", "`pCIPlot`p'Type'", "rcap")		// overwrite global status if appropriate
			local pCIPlot `"`macval(pCIPlot)' || `pCIPlotType' `_LCI' `_UCI' `id' if inlist(`_USE', 3, 5) & `plotid'==`p', hor `DefPCIopts' `pciopts' `pci`p'opts'"'
			local ppointPlot `"`macval(ppointPlot)' || scatter `id' `_ES' if inlist(`_USE', 3, 5) & `plotid'==`p', `DefPPointopts' `ppointopts' `ppoint`p'opts'"'
		}
	}
}

* Find invalid/repeated options
* any such options would generate a suitable error message at the plotting stage
* so just exit here with error, to save the user's time
if regexm(`"`rest'"', "(box|diam|point|ci|oline|ppoint|pci)([0-9]+)") {
	local badopt = regexs(1)
	local badp = regexs(2)
	
	disp as err `"`badopt'`badp'opts: "' _c
	if `: list badp in plvals' disp as err "option supplied multiple times; should only be supplied once"
	else disp as err `"`badp' is not a valid plotid value"'
	exit 198
}

local graphopts `rest'		// this is now *just* the standard "twoway" options
							// i.e. the specialist "forestplot" options have been filtered out

				
* FORM "DEFAULT" TWOWAY PLOT COMMAND (if appropriate)
if `"`pplvals'"'!=`""' {

	local pplvals : subinstr local pplvals " " ",", all		// so that "inlist" may be used

	* WEIGHTED SCATTER PLOT
	local 0 `", `boxopts'"'
	syntax [, MLABEL(string asis) MSIZe(string asis) * ]	// check for disallowed options
	if `"`mlabel'"' != `""' {
		disp as err "boxopts: option mlabel() not allowed"
		exit 198
	}
	if `"`msize'"' != `""' {
		disp as err "boxopts: option msize() not allowed"
		exit 198
	}
	qui summ `_WT' if `_USE'==1 & inlist(`plotid', `pplvals')
	if r(N) local scPlot `"`macval(scPlot)' || scatter `id' `_ES' `awweight' if `_USE'==1 & inlist(`plotid', `pplvals'), `DefBoxopts' `boxopts'"'
	
	* CONFIDENCE INTERVAL PLOT
	local 0 `", `ciopts'"'
	syntax [, HORizontal VERTical Connect(string asis) RCAP * ]		// check for disallowed options + rcap
	if `"`horizontal'"'!=`""' | `"`vertical'"'!=`""' {
		disp as error "ciopts: options horizontal/vertical not allowed"
		exit 198
	}			
	if `"`connect'"' != `""' {
		di as error "ciopts: option connect() not allowed"
		exit 198
	}
	local ciopts `"`options'"'
	local CIPlotType = cond("`rcap'"=="", "`CIPlotType'", "rcap")		// overwrite global status if appropriate
	local CIPlot `"`macval(CIPlot)' || `CIPlotType' `_LCI' `_UCI' `id' if `_USE'==1 & inlist(`plotid', `pplvals') & !`offscaleL' & !`offscaleR', hor `DefCIopts' `ciopts'"'

	qui count if inlist(`plotid', `pplvals') & `offscaleL' & `offscaleR'
	if r(N) {													// both ends off scale
		local CIPlot `"`macval(CIPlot)' || pcbarrow `id' `_LCI' `id' `_UCI' if inlist(`plotid', `pplvals') & `offscaleL' & `offscaleR', `DefCIopts' `ciopts'"'
	}
	qui count if inlist(`plotid', `pplvals') & `offscaleL' & !`offscaleR'
	if r(N) {													// only left off scale
		local CIPlot `"`macval(CIPlot)' || pcarrow `id' `_UCI' `id' `_LCI' if inlist(`plotid', `pplvals') & `offscaleL' & !`offscaleR', `DefCIopts' `ciopts'"'
		if "`CIPlotType'" == "rcap" {			// add cap to other end if appropriate
			local CIPlot `"`macval(CIPlot)' || rcap `_UCI' `_UCI' `id' if inlist(`plotid', `pplvals') & `offscaleL' & !`offscaleR', hor `DefCIopts' `ciopts'"'
		}
	}
	qui count if inlist(`plotid', `pplvals') & !`offscaleL' & `offscaleR'
	if r(N) {													// only right off scale
		local CIPlot `"`macval(CIPlot)' || pcarrow `id' `_LCI' `id' `_UCI' if inlist(`plotid', `pplvals') & !`offscaleL' & `offscaleR', `DefCIopts' `ciopts'"'
		if "`CIPlotType'" == "rcap" {			// add cap to other end if appropriate
			local CIPlot `"`macval(CIPlot)' || rcap `_LCI' `_LCI' `id' if inlist(`plotid', `pplvals') & !`offscaleL' & `offscaleR', hor `DefCIopts' `ciopts'"'
		}
	}

	* POINT PLOT
	local pointPlot `"`macval(pointPlot)' || scatter `id' `_ES' if `_USE'==1 & inlist(`plotid', `pplvals'), `DefPointopts' `pointopts'"'

	* OVERALL LINE(S) (if appropriate)
	summ `ovLine' if inlist(`plotid', `pplvals'), meanonly
	if r(N) {
		local olinePlot `"`macval(olinePlot)' || rspike `ovMin' `ovMax' `ovLine' if inlist(`plotid', `pplvals'), `DefOlineopts' `olineopts'"'
	}

	* POOLED EFFECT - DIAMOND
	* Assume diamond if no "pooled point/CI" options, and no "interaction" option
	if `"`ppointopts'`pciopts'`interaction'"' == `""' {
		local diamPlot `"`macval(diamPlot)' || pcspike `DiamLeftY1' `DiamLeftX' `DiamTopY' `DiamTopX' if inlist(`plotid', `pplvals'), `DefDiamopts' `diamopts'"'
		local diamPlot `"`macval(diamPlot)' || pcspike `DiamTopY' `DiamTopX' `DiamRightY1' `DiamRightX' if inlist(`plotid', `pplvals'), `DefDiamopts' `diamopts'"'
		local diamPlot `"`macval(diamPlot)' || pcspike `DiamRightY2' `DiamRightX' `DiamBottomY' `DiamBottomX' if inlist(`plotid', `pplvals'), `DefDiamopts' `diamopts'"'
		local diamPlot `"`macval(diamPlot)' || pcspike `DiamBottomY' `DiamBottomX' `DiamLeftY2' `DiamLeftX' if inlist(`plotid', `pplvals'), `DefDiamopts' `diamopts'"'
	}
	
	* POOLED EFFECT - PPOINT/PCI
	else {
		if `"`diamopts'"'!=`""' {
			disp as err _n `"plotid: cannot specify options for both diamond and pooled point/CI"'
			disp as err `"diamond options will be ignored"'
		}
		
		local 0 `", `pciopts'"'
		syntax [, HORizontal VERTical Connect(string asis) RCAP *]		// check for disallowed options + rcap
		if `"`horizontal'"'!=`""' | `"`vertical'"'!=`""' {
			disp as error "pciopts: options horizontal/vertical not allowed"
			exit 198
		}			
		if `"`connect'"' != `""' {
			di as error "pciopts: option connect() not allowed"
			exit 198
		}
		local pCIPlotType = cond("`rcap'"=="", "`pCIPlotType'", "rcap")		// overwrite global status if appropriate
		local pCIPlot `"`macval(pCIPlot)' || `pCIPlotType' `_LCI' `_UCI' `id' if inlist(`_USE', 3, 5) & inlist(`plotid', `pplvals'), hor `DefPCIopts' `pciopts'"'
		local ppointPlot `"`macval(ppointPlot)' || scatter `id' `_ES' if inlist(`_USE', 3, 5) & inlist(`plotid', `pplvals'), `DefPPointopts' `ppointopts'"'
	}
}
	
// END GRAPH OPTS


* Note for random-effects analyses
if `"`renote'"'!=`""' {
	summ `id', meanonly
	local noteposy = r(min) - 1.5 		// ypos for note is 1.5 lines below last obs
	summ `left1', meanonly
	local noteposx = r(mean) 			// xpos is middle of left-hand-side (but text will be left-justified in scatter)
	local notelab `"NOTE: Weights are from `renote' analysis"'
	local notecmd `"text(`noteposy' `noteposx' "`notelab'", placement(3) size(`textSize'))"'
}

// DF: modified to use added line approach instead of pcspike (less complex & poss. more efficient as fewer vars)
// null line (unless switched off)
if "`null'" == "" {
	local nullCommand `"|| function y=`h0', range(`DYmin' `borderline') horiz n(2) lwidth(thin) lcolor(black)"'
}

// final addition- if aspect() given but not xsize() ysize(), put these in to get rid of gaps
// need to fiddle to allow space for bottom title
// should this just replace the aspect option?
// suppose good to keep- most people hopefully using xsize and ysize and can always change themselves if using aspect
if `xsize' == 0 & `ysize' == 0 & `aspect' > 0 {
	if `aspect' > 1 {
		local xx = (11.5 + 2*(1-1/`aspect'))/`aspect'
		local yy = 12
	}
	else {
		local yy = 12*`aspect'
		local xx = 11.5 - 2*(1 - `aspect')
	}
	local graphopts `"`graphopts' xsize(`xx') ysize(`yy')"'		// these will override any previous xsize/ysize options
}


***************************
***     DRAW GRAPH      ***
***************************

#delimit ;

twoway
/* OVERALL AND NULL LINES FIRST */ 
	`olinePlot' `nullCommand'
/* PLOT BOXES AND PUT ALL THE GRAPH OPTIONS IN THERE, PLUS NOTE FOR RANDOM-EFFECTS */ 
	`scPlot' `notecmd'
		yscale(range(`DYmin' `DYmax') noline) ylabel(none) ytitle("")
		xscale(range(`AXmin' `AXmax')) xlabel(`xlblcmd', labsize(`textSize'))
		yline(`borderline', lwidth(thin) lcolor(gs12))
/* FAVOURS OR XTITLE */
		`favopt' `xtitleopt'
/* PUT LABELS UNDER xticks? Yes as labels now extended */
		xtitle("") legend(off) xtick("`xticklist'")
/* NEXT, CONFIDENCE INTERVALS (plus offscale if necessary) */
	`CIPlot'
/* DIAMONDS (or markers+CIs if appropriate) FOR SUMMARY ESTIMATES */
	`diamPlot' `ppointPlot' `pCIPlot'
/* COLUMN VARIBLES (including effect sizes and weights on RHS by default) */
	`lcolCommands' `rcolCommands'
/* LAST OF ALL PLOT EFFECT MARKERS TO CLARIFY */
	`pointPlot'
/* Other options */
	|| , `graphopts' /* RMH added */ plotregion(margin(zero)) ;

#delimit cr


end





program define getWidth
version 9.0

//	ROSS HARRIS, 13TH JULY 2006
//	TEXT SIZES VARY DEPENDING ON CHARACTER
//	THIS PROGRAM GENERATES APPROXIMATE DISPLAY WIDTH OF A STRING
//	FIRST ARG IS STRING TO MEASURE, SECOND THE NEW VARIABLE

//	PREVIOUS CODE DROPPED COMPLETELY AND REPLACED WITH SUGGESTION
//	FROM Jeff Pitblado

qui{

gen `2' = 0
count
local N = r(N)
forvalues i = 1/`N'{
	local this = `1'[`i']
	local width: _length `"`this'"'
	replace `2' =  `width' +1 in `i'
}

} // end qui

end



* exit

//	METAN UPDATE
//	ROSS HARRIS, DEC 2006
//	MAIN UPDATE IS GRAPHICS IN THE _dispgby PROGRAM
//	ADDITIONAL OPTIONS ARE lcols AND rcols
//	THESE AFFECT DISPLAY ONLY AND ALLOW USER TO SPECIFY
//	VARIABLES AS A FORM OF TABLE. THIS EXTENDS THE label(namevar yearvar)
//	SYNTAX, ALLOWING AS MANY LEFT COLUMNS AS REQUIRED (WELL, LIMIT IS 10)
//	IF rcols IS OMMITTED DEFAULT IS THE STUDY EFFECT (95% CI) AND WEIGHT
//	AS BEFORE- THESE ARE ALWAYS IN UNLESS OMITTED USING OPTIONS
//	ANYTHING ADDED TO rcols COMES AFTER THIS.


********************
** May 2007 fixes **
********************

//	"nostandard" had disappeared from help file- back in
//	I sq. in return list
//	sorted out the extra top line that appears in column labels
//	fixed when using aspect ratio using xsize and ysize so inner bit matches graph area- i.e., get rid of spaces for long/wide graphs
//	variable display format preserved for lcols and rcols
//	abbreviated varlist now allowed
//	between groups het. only available with fixed
//	warnings if any heterogeneity with fixed (for between group het if any sub group has het, overall est if any het)
// 	nulloff option to get rid of line
