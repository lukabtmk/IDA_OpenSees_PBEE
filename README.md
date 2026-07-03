# IDA_OpenSees_PBEE
OpenSees TCL script for Incremental Dynamic Analysis (IDA)

------------------------------------------------------------------------------------------------------------------
Script overview 
------------------------------------------------------------------------------------------------------------------
This is a script that will conduct IDA analysis from a provided set of ground motions for a given structural model. 
The user needs to provide: 

1. A structural SDOF/MDOF model that would contain material behaviour-properties and node mass/masses,  
2. Set of ground motions,
3. Time increment steps and the duration of the ground motion. 
 
The algorithm begins by normalizing a provided set of ground motions. It then creates a directory to store separate 
normalized ground motion .txt files, which are saved in a normalized list of ground motions. The time increments and 
duration for each ground motion file are read from the provided .txt file and saved into separate increment and 
duration lists, which are later used for the analysis. The algorithm performs a time history analysis for each 
ground motion from the normalized list by incrementing the values in a while loop until the maximum increment 
provided by the user is reached. The calculated maximum displacements and acceleration for each ground motion and the current ground 
motion factor are saved in separate directories. Finally, all the calculated maximum displacements and accelerations are written into 
two .txt files. The first file is a column matrix that includes all the calculated maximum displacements/accelerations, while 
the second file additionally contains the ground motion factor and name of the ground motion - complete description.

-------------------------------------------------------------------------------------------------------------------
Inputs:

1. A structural SDOF/MDOF model that contains, assigned nodal mass for nodes, material model and defined recorder for displacement of free node.
											(fixed node)1o----o2(free node)  X-> 							  
2. $GroundMotionsDirectoryPath - Set of ground motions in a seperate directory that inclueds a list of .txt files from i to n, 
3. $GroundMotionsParameters - Ground motion parameters for every ground motion from the list i to n in a .txt format file  
(The format of the .txt file: column 1 values for Tf, column 2 values for dt),
4. $maximumGMfact - Maximum ground motion scale factor,
5. $GMfactIncrement - Ground motion increment used during the analysis,
5. $DampingRatio - Damping ratio used for the calculation of the RayleighDamping, typically 0.02 upto 0.05
 
-------------------------------------------------------------------------------------------------------------------
Outputs:

The procedure will print the results into a seperate Results directory for every gmFact:"results/%s_gmFact_%.2f" which contain Umax/Amax and info for every ground motion and increment. 
 
$DFree.out - contains the last recorded results from NRHA in a two column file (time-displacement) 
 
$"Umax_all.txt" - all maximum displacements in a single numeric column matrix file.

$"Umax_all_text.txt" - all maximum displacements in a single text column file with gm record. and gm factor info. the same applies for Amax

-------------------------------------------------------------------------------------------------------------------
REQUIREMENTS:
To run this script, the following is also required:
  1. .tcl file with defined units: "Units.SI.tcl" - if applicable for the SDOF/MDOF model

-------------------------------------------------------------------------------------------------------------------
Possible errors:
Strain too large - model failure: structural failure or non-convergence issues - possible structural resurrection of IDA curve.
-------------------------------------------------------------------------------------------------------------------
