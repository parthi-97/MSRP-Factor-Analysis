* ------------------------------------------ Import the data -------------------------------------------------;
proc import datafile="/home/u63852129/sasuser.v94/asia.xlsx"
dbms=xlsx out=asia;
run;
proc import datafile="/home/u63852129/sasuser.v94/europe.xlsx"
dbms=xlsx out=europe;
run;
proc import datafile="/home/u63852129/sasuser.v94/usa.xlsx"
dbms=xlsx out=usa;
run;
proc import datafile="/home/u63852129/sasuser.v94/carspec.xlsx"
dbms=xlsx out=carspec;
run;


* -------------------------------------------- Concatenation -------------------------------------------------;
data allregion;
	length MAKE $13 MODEL $39;
	set asia europe usa;
run;

* ------------------------------------------------- Merge-----------------------------------------------------;
proc sort data=allregion;
	by MAKE MODEL;
run;

proc sort data=carspec;
	by MAKE MODEL;
run;

data cars;
	merge allregion carspec;
	by MAKE MODEL;
run;


* --------------------------------------- investigate the categorical variables ------------------------------;
proc freq data=cars;
	tables MAKE TYPE Origin DriveTrain;
run;


data prepare;
	set cars;
* extract the number of doors;
	label Noofdr = "Number of doors";
	* method 1;
	/*if find(MODEL, "1dr") then Noofdr = 1;
	else if find(MODEL, "2dr") then Noofdr = 2;
	else if find(MODEL, "3dr") then Noofdr = 3;
	else if find(MODEL, "4dr") then Noofdr = 4;
	else if find(MODEL, "5dr") then Noofdr = 5;*/
	* method 2;
	if find(MODEL, "dr") and not find(MODEL, "dra") then do;
		Noofdr = input(substr(MODEL, find(MODEL, "dr") - 2, 2), best.);
	end;
* Fuel economy;
	Fuel_eco = MPG_City * .55 + MPG_Highway * .45;


*  ------------------ Make dummies for each make - This is only when you want to account for the make, because there are so many makes and makes the regression complex;
	array _charval (38) $200 _temporary_ ("Acura" "Audi" "BMW" "Buick" "Cadillac" "Chevrolet" "Chrysler" "Dodge" "Ford" "GMC"
						"Honda" "Hummer" "Hyundai" "Infiniti" "Isuzu" "Jaguar" "Jeep" "Kia" "Land Rover"
						"Lexus" "Lincoln" "MINI" "Mazda" "Mercedes-B" "Mercury" "Mitsubishi" "Nissan"
						"Oldsmobile" "Pontiac" "Porsche" "Saab" "Saturn" "Scion" "Subaru" "Suzuki" "Toyota"
						"Volkswagen" "Volvo");

	array _var (*) Acura Audi BMW Buick Cadillac Chevrolet Chrysler Dodge Ford GMC 
					Honda Hummer Hyundai Infiniti Isuzu Jaguar Jeep Kia Land_Rover 
					Lexus Lincoln MINI Mazda Mercedes Mercury Mitsubishi Nissan
					Oldsmobile Pontiac Porsche Saab Saturn Scion Subaru Suzuki Toyota
					Volkswagen Volvo;

	do i = 1 to dim(_var);
		if MAKE = _charval(i) then _var(i) = 1;
		else _var(i) = 0;
	end;

*  ------------------------------------------ Make dummies for Type -----------------------------------------------;
	array _type (6) $200 _temporary_ ("Hybrid" "SUV" "Sedan" "Sports" "Truck" "Wagon");
	array _typevar (6) Hybrid SUV Sedan Sports Truck Wagon;
	do i = 1 to 6;
		if TYPE = _type(i) then _typevar(i) = 1;
		else _typevar(i) = 0;
	end;

* ----------------------------------------- Make dummies for origin ---------------------------------------------;
	array _origin (3) $200 _temporary_ ("Asia" "Euro" "USA");
	array _origvar (3) Asia Euro USA;
	do i = 1 to 3;
		if ORIGIN = _origin(i) then _origvar(i) = 1;
		else _origvar(i) = 0;
	end;

* -------------------------------------------- Make dummies for DriveTrain -------------------------------------;
	array _DriveTrain (3) $200 _temporary_ ("All" "Front" "Rear");
	array _DTvar (3) ALL FRONT REAR;
	do i = 1 to 3;
		if DriveTrain = _DriveTrain(i) then _DTvar(i) = 1;
		else _DTvar(i) = 0;
	end;	
	drop i;
run;


* ------------------------------------------------- First we include every variable ---------------------------------;
proc reg data=prepare;
model MSRP = EngineSize -- REAR;
run;
quit;
* Interpretation: turn out that we do not have enough number of observations so parameters with DF=B are biased;

* ----------------------------------------------- Try out the make first ----------------------------------------;
proc reg data=prepare;
model MSRP = Acura -- Volvo;
run;
quit;


* ---------------------------------------------   Try out other variables --------------------------------------;
proc reg data=prepare;
model MSRP = EngineSize -- Fuel_eco Hybrid -- REAR;
run;
quit;
* MPG_CITY MPG_HIGHWAY are grouped into one variable Fuel_eco, and they are biased, so we remove them;


* ----------------------------------------------------- Try out the rest --------------------------------------------;
proc reg data=prepare;
model MSRP = EngineSize -- Horsepower Weight--Fuel_eco Hybrid -- REAR;
run;
quit;
* There are still a few that are biased. What we can do now is that we only take those with large parameter estimates with significant p-value because they 
have the largest impact on the dependent variables, and remove the dummies;

* --------------------------------------- Try out the large parameter estimates -----------------------------------;
proc reg data=prepare;
model MSRP = EngineSize -- Horsepower Weight--Fuel_eco;
run;
quit;
* Length and Weight can be removed because of their low parameter estimates;
proc reg data=prepare;
model MSRP = EngineSize -- Horsepower Wheelbase Noofdr Fuel_eco;
run;
quit;
* Wheelbase becomes insignificant now remove;
proc reg data=prepare;
model MSRP = EngineSize -- Horsepower Noofdr Fuel_eco;
run;
quit;

* Now we have a model with a few variables that will give a decent estimate of the MSRP, with a adj R-sq = 0.7549;