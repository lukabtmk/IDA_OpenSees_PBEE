# --------------------------------------------------------------------------------------------------
# LibUnits.tcl -- define system of units
#		Silvia Mazzoni & Frank McKenna, 2006
#

# define UNITS ----------------------------------------------------------------------------
set m   1.; 				# define basic units -- output units
set kN  1.; 				# define basic units -- output units
set sec 1.; 				# define basic units -- output units
set LunitTXT "m";			# define basic-unit text for output
set FunitTXT "kN";			# define basic-unit text for output
set TunitTXT "sec";			# define basic-unit text for output

set N   [expr $kN*pow(10,-3)];
set Pa  [expr $N/pow($m,2)];
set kPa [expr $Pa*pow(10,3)];
set MPa [expr $Pa*pow(10,6)];
set GPa [expr $Pa*pow(10,9)];
set mm  [expr $m*pow(10,-3)];
set cm  [expr $m*pow(10,-2)]; 		
set cm2 [expr pow($cm,2)];
set cm4 [expr pow($cm,4)];
set m3  [expr pow($m,3)];
set kg  [expr $N*pow($sec,2)/$m];
set t   [expr $kg*pow(10,3)];		

set PI [expr 2*asin(1.0)]; 		# define constants
set g [expr 9.81*$m/pow($sec,2)]; 	# gravitational acceleration
set Ubig 1.0E+16; 			# a really large number
set Usmall [expr 1/$Ubig]; 		# a really small number
