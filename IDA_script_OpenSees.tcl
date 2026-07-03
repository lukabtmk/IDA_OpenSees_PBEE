# -----------------------------------------------------------------------------------------------------------------
# Script to conduct IDA analysis from a set of GM files 
# Author: Luka Naumovski
# Upadted version 2.0: Avgust 2025, Created: May 2023 
# Latess version: 2.0

# ------------------------------------------------------------------------------------------------------------------
# ------------------------------------------ Script overview -------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------
# This is a script that will conduct IDA analysis from a provided set of ground motions for a given structural model. 
# The user needs to provide: 
#
#							1. A structural SDOF/MDOF model that would contain material behaviour-properties and node mass/masses,  
#							2. Set of ground motions,
#							3. Time increment steps and the duration of the ground motion. 
#  
# The algorithm begins by normalizing a provided set of ground motions. It then creates a directory to store separate 
# normalized ground motion .txt files, which are saved in a normalized list of ground motions. The time increments and 
# duration for each ground motion file are read from the provided .txt file and saved into separate increment and 
# duration lists, which are later used for the analysis. The algorithm performs a time history analysis for each 
# ground motion from the normalized list by incrementing the values in a while loop until the maximum increment 
# provided by the user is reached. The calculated maximum displacements and acceleration for each ground motion and the current ground 
# motion factor are saved in separate directories. Finally, all the calculated maximum displacements and accelerations are written into 
# two .txt files. The first file is a column matrix that includes all the calculated maximum displacements/accelerations, while 
# the second file additionally contains the ground motion factor and name of the ground motion - complete description.
#    
# -------------------------------------------------------------------------------------------------------------------
# Possible issues:
#
# *Strain too large - model failure: structural failure or non-convergence issues - possible structural resurrection of IDA curve.

# -------------------------------------------------------------------------------------------------------------------
# Inputs:
#
#	1. A structural SDOF/MDOF model that contains, 
#		assigned nodal mass for nodes, material model and defined recorder for displacement of free node.
#											(fixed node)1o----o2(free node)  X-> 							  
#	2. $GroundMotionsDirectoryPath - Set of ground motions in a seperate directory that inclueds a list of .txt files from i to n, 
#	3. $GroundMotionsParameters - Ground motion parameters for every ground motion from the list i to n in a .txt format file  
#		 (The format of the .txt file: column 1 values for Tf, column 2 values for dt),
#	4. $maximumGMfact - Maximum ground motion scale factor,
#	5. $GMfactIncrement - Ground motion increment used during the analysis,
#	5. $DampingRatio - Damping ratio used for the calculation of the RayleighDamping, typically 0.02 upto 0.05
# 
# -------------------------------------------------------------------------------------------------------------------
# Outputs:
#	
# The procedure will print the results into a seperate Results directory for every gmFact:"results/%s_gmFact_%.2f" which
# contain Umax/Amax and info for every ground motion and increment. 
# 
# $DFree.out - contains the last recorded results from NRHA in a two column file (time-displacement) 
# 
# $"Umax_all.txt" - all maximum displacements in a single numeric column matrix file.
# $"Umax_all_text.txt" - all maximum displacements in a single text column file with gm record. and gm factor info.
# the same applies for Amax
# -------------------------------------------------------------------------------------------------------------------
# REQUIREMENTS:
# 
# To run this script, the following is also required:
#	1. .tcl file with defined units: "Units.SI.tcl" - if applicable for the SDOF/MDOF model
#
# ___________________________________________________________________________________________________________________
# Script:

wipe;
# Inputs:
# -------------------------------------------------------------------------------------------------------------------

# ---- User parameters ------------------------------------------------
wipe;

# Inputs:
# -------------------------------------------------------------------------------------------------------------------
# ---- User parameters ------------------------------------------------
set maximumGMfact 1.0
set GMfactIncrement 0.025
set DampingRatio 0.01
set ModelDirectoryPath "Set Model Directory Path"
set GroundMotionsDirectoryPath "Set Ground Motions Directory Path"
set GroundMotionsParameters "Set Ground Motions Parameters"
set g 9.81
set patternID 0

# Generate list of GM factors
set gmFactList {}
set val $GMfactIncrement
while {$val <= $maximumGMfact + 1e-9} {  # Adding a small tolerance
    lappend gmFactList $val
    set val [expr {$val + $GMfactIncrement}]
}


# ---- Normalized directory (will be created next to original GMs) ----
set NormalizedDir [file join $GroundMotionsDirectoryPath "normalized_gmdir"]
if {![file exists $NormalizedDir]} {
    file mkdir $NormalizedDir
}

# Collect all GM input files (full paths)
set rawFiles [glob -nocomplain -directory $GroundMotionsDirectoryPath *.txt]
if {[llength $rawFiles] == 0} {
    puts "ERROR: No .txt files found in $GroundMotionsDirectoryPath"
    exit 1
}

# Normalize each GM to max-abs = 1 and write to $NormalizedDir
set normalizedTimeSeriesFiles {}
foreach gmfile $rawFiles {
    puts "Normalizing: [file tail $gmfile] ..."
    set inId [open $gmfile r]
    set maxVal 0.0
    while {[gets $inId line] >= 0} {
        set line [string trim $line]
        if {$line eq ""} { continue }
        if {![string is double -strict $line]} {
            if {[regexp {(-?\d+\.?\d*(?:[eE][+-]?\d+)?)$} $line -> token]} {
                set val [expr {$token + 0.0}]
            } else {
                puts "WARNING: Skipping non-numeric line in $gmfile: $line"
                continue
            }
        } else {
            set val [expr {$line + 0.0}]
        }
        if {[expr {abs($val)}] > $maxVal} { set maxVal [expr {abs($val)}] }
    }
    close $inId

    if {$maxVal == 0.0} {
        puts "WARNING: Max value is 0 for [file tail $gmfile] — writing zeros unchanged"
        set maxVal 1.0
    }

    # Write normalized file
    set outFile [file join $NormalizedDir [format "normalized_%s" [file tail $gmfile]]]
    set inId2 [open $gmfile r]
    set outId [open $outFile w]
    while {[gets $inId2 line] >= 0} {
        set lineTrim [string trim $line]
        if {$lineTrim eq ""} {
            puts $outId ""
            continue
        }
        if {![string is double -strict $lineTrim]} {
            if {[regexp {(-?\d+\.?\d*(?:[eE][+-]?\d+)?)$} $lineTrim -> token]} {
                set val [expr {$token + 0.0}]
            } else {
                puts $outId $lineTrim
                continue
            }
        } else {
            set val [expr {$lineTrim + 0.0}]
        }
        set normalizedVal [expr {$val / $maxVal}]
        puts $outId [format "%.6f" $normalizedVal]
    }
    close $inId2
    close $outId
    lappend normalizedTimeSeriesFiles $outFile
    puts "  -> written: [file tail $outFile]"
}

# Numeric sort helper (sort by number found in filename)
proc extractNumFromName {fname} {
    if {[regexp {(\d+)} $fname -> n]} {
        return [expr {int($n)}]
    }
    return -1
}

proc compareNumeric {a b} {
    set ta [file tail $a]
    set tb [file tail $b]
    set na [extractNumFromName $ta]
    set nb [extractNumFromName $tb]
    if {$na == -1 && $nb == -1} {
        return [string compare $ta $tb]
    } elseif {$na == -1} {
        return 1
    } elseif {$nb == -1} {
        return -1
    } else {
        return [expr {$na - $nb}]
    }
}

set sortedNormalizedTimeSeriesFiles [lsort -command compareNumeric $normalizedTimeSeriesFiles]

# Read Tf and dt parameters
if {![file exists $GroundMotionsParameters]} {
    puts "ERROR: Time series parameters file not found: $GroundMotionsParameters"
    exit 1
}

set paramsContent [read [open $GroundMotionsParameters r]]
set timeSeriesParams [split [string trim $paramsContent] "\n"]

# Prepare lists that map sorted files -> params
set numTimeSeries [llength $sortedNormalizedTimeSeriesFiles]
set timeSeriesTagsList {}
set NstepsList {}
set dtLists {}
set Tflist {}

for {set idx 0} {$idx < $numTimeSeries} {incr idx} {
    set nmfile [lindex $sortedNormalizedTimeSeriesFiles $idx]
    set tail [file tail $nmfile]
    if {[regexp {normalized[_-]?gmr[_-]?(\d+)\.txt$} $tail -> gmNumber] == 0} {
        if {[regexp {(\d+)} $tail -> gmNumber] == 0} {
            puts "ERROR: Cannot extract GM number from filename: $tail"
            exit 1
        }
    }
    set paramIndex [expr {$gmNumber - 1}]
    if {$paramIndex < 0 || $paramIndex >= [llength $timeSeriesParams]} {
        puts "ERROR: Parameter index $paramIndex out of range for $tail"
        exit 1
    }
    set line [string trim [lindex $timeSeriesParams $paramIndex]]
    set tokens [regexp -all -inline {\S+} $line]
    if {[llength $tokens] < 2} {
        puts "ERROR: Expected at least 'Tf dt' in params file for GM $gmNumber, line: '$line'"
        exit 1
    }
    scan [lindex $tokens 0] "%f" TfVal
    scan [lindex $tokens 1] "%f" dtVal

    if {$TfVal <= 0.0 || $dtVal <= 0.0} {
        puts "ERROR: Tf and dt must be positive for GM $gmNumber (Tf=$TfVal dt=$dtVal)"
        exit 1
    }
    if {$dtVal > $TfVal} {
        puts "ERROR: dt ($dtVal) > Tf ($TfVal) for GM $gmNumber"
        exit 1
    }

    set Nsteps [expr {int($TfVal / $dtVal)}]
    lappend timeSeriesTagsList $gmNumber
    lappend dtLists $dtVal
    lappend NstepsList $Nsteps
    lappend Tflist $TfVal
    puts "Mapped GM file [file tail $nmfile] -> gmNumber $gmNumber, Tf=$TfVal, dt=$dtVal, Nsteps=$Nsteps"
}

puts "PARAMETER MAPPING COMPLETE: $numTimeSeries ground motions."

# Main IDA loops: for each GM and for each scaling factor
set numScalingSteps [expr {int(ceil($maximumGMfact / $GMfactIncrement))}]
if {$numScalingSteps < 1} { set numScalingSteps 1 }

# Ensure results directory exists
if {![file exists "results"]} { file mkdir results }

for {set gmIdx 0} {$gmIdx < $numTimeSeries} {incr gmIdx} {
    set normalizedFile [lindex $sortedNormalizedTimeSeriesFiles $gmIdx]
    set timeSeriesTag [lindex $timeSeriesTagsList $gmIdx]
    set dt [lindex $dtLists $gmIdx]
    set Nsteps [lindex $NstepsList $gmIdx]
    set Tf [lindex $Tflist $gmIdx]

    puts "------------------------------------------------------------"
    puts "Processing GM [expr {$gmIdx + 1}]/$numTimeSeries: [file tail $normalizedFile]"
    puts "  tag=$timeSeriesTag dt=$dt Tf=$Tf Nsteps=$Nsteps"

    set gmFactorCount 0
    foreach gmFact $gmFactList {
        incr gmFactorCount
        puts "  Processing scale factor $gmFact"

        # Source model (defines nodes, materials, elements, etc.)
        source $ModelDirectoryPath

        # Create results directory for this run
        set runDir [file join results [format "%s_gmFact_%.3f" [file tail $normalizedFile] $gmFact]]
        file mkdir $runDir

        # Unique timeSeries tag and pattern tag based on gm index and step
        set tsTag [expr {($gmIdx + 1) * 10000 + $gmFactorCount}]
        set patTag [expr {($gmIdx + 1) * 100000 + $gmFactorCount}]

        # Create timeSeries (unique tag) and a unique UniformExcitation pattern
        timeSeries Path $tsTag -dt $dt -filePath $normalizedFile -factor $g
        pattern UniformExcitation $patTag 1 -accel $tsTag -factor $gmFact

        # Analysis setup
        set DtAnalysis $dt
        set TmaxAnalysis $Tf
        constraints Transformation
        numberer Plain
        system BandGeneral
        set Tol 1.e-8
        set maxNumIter 50
        set printFlag 0
        set TestType EnergyIncr
        test $TestType $Tol $maxNumIter $printFlag
        set algorithmType KrylovNewton
        algorithm $algorithmType
        set NewmarkGamma 0.6
        set NewmarkBeta 0.3025
        integrator Newmark $NewmarkGamma $NewmarkBeta
        analysis Transient

        set xDamp $DampingRatio
        set lambda [eigen -fullGenLapack 1]
        if {[llength $lambda] > 1} { set lambdaVal [lindex $lambda 0] } else { set lambdaVal $lambda }
        set omega [expr {sqrt(double($lambdaVal))}]
        set alphaM 0.06
		set freq  [expr { $omega / (2.0 * 3.14 )}]
        set betaKcurr 0.00
        set betaKcomm [expr {2.0 * $xDamp / $omega}]
        set betaKinit 0.003
        rayleigh $alphaM $betaKcurr $betaKinit $betaKcomm

        # Run time stepping with convergence handling
        puts "    Starting dynamic analysis for gmFact $gmFact ..."
        set analysisComplete 0
        set Umax 0.0
        set Amax 0.0

        for {set j 0} {$j < $Nsteps} {incr j} {
            set ok [analyze 1 $DtAnalysis]
            if {$ok != 0} {
                puts "    Analysis failed at step [expr {$j+1}] -> trying recovery ..."
                set recovered 0

                # Strategy 1: Newton with Initial Tangent
                if {$ok != 0} {
                    test NormDispIncr $Tol 1000 0
                    algorithm Newton -initial
                    set ok [analyze 1 $DtAnalysis]
                    test $TestType $Tol $maxNumIter $printFlag
                    algorithm $algorithmType
                    if {$ok == 0} { set recovered 1 }
                }

                # Strategy 2: Broyden
                if {$ok != 0} {
                    algorithm Broyden 8
                    set ok [analyze 1 $DtAnalysis]
                    algorithm $algorithmType
                    if {$ok == 0} { set recovered 1 }
                }

                # Strategy 3: Newton with Line Search
                if {$ok != 0} {
                    algorithm NewtonLineSearch 0.8
                    set ok [analyze 1 $DtAnalysis]
                    algorithm $algorithmType
                    if {$ok == 0} { set recovered 1 }
                }

                # Strategy 4: Subdivide time step
                if {$ok != 0} {
                    set subSteps 10
                    set subDt [expr {$DtAnalysis / $subSteps}]
                    set subOk 0
                    for {set sub 1} {$sub <= $subSteps} {incr sub} {
                        set subOk [analyze 1 $subDt]
                        if {$subOk != 0} { break }
                    }
                    if {$subOk == 0} {
                        set ok 0
                        set recovered 1
                    }
                }

                if {$ok != 0} {
                    puts "    *** CONVERGENCE FAILED at GM factor $gmFact - saving failure info and continuing ***"
                    catch {
                        set failureFile [open [file join $runDir "analysis_failure.txt"] "w"]
                        puts $failureFile "Analysis failed at step [expr {$j+1}] of $Nsteps"
                        puts $failureFile "GM Factor: $gmFact"
                        puts $failureFile "Time reached (s): [getTime]"
                        puts $failureFile "Error code: $ok"
                        close $failureFile
                    }
                    catch {reset}
                    catch {remove loadPattern $patternID}
                    catch {wipe}
                    break
                }
            }

            # If successful, record max displacement/accel (node 6 DOF 1 as in original)
            set U [nodeDisp 6 1]
            if {[expr {abs($U)}] > $Umax} { set Umax [expr {abs($U)}] }
            set A [nodeAccel 6 1]
            if {[expr {abs($A)}] > $Amax} { set Amax [expr {abs($A)}] }

            if {[expr {($j+1) % 500}] == 0} {
                puts "    Completed step [expr {$j+1}]/$Nsteps  (Time: [getTime])"
            }
        }

        set finalTime [getTime]
        if {$finalTime >= [expr {$TmaxAnalysis * 0.99}]} {
            set analysisComplete 1
            puts "    *** ANALYSIS COMPLETED SUCCESSFULLY ***"
        } else {
            puts "    *** ANALYSIS INCOMPLETE - Reached time: $finalTime of $TmaxAnalysis ***"
        }

        # Save outputs
        set umaxFile [open [file join $runDir "Umax.txt"] "w"]
        puts $umaxFile $Umax
        close $umaxFile

        set amaxFile [open [file join $runDir "Amax.txt"] "w"]
        puts $amaxFile $Amax
        close $amaxFile

        set statusFile [open [file join $runDir "status.txt"] "w"]
        if {$analysisComplete} {
            puts $statusFile "COMPLETED"
        } else {
            puts $statusFile "FAILED"
        }
        puts $statusFile "Final_time: $finalTime"
        puts $statusFile "Target_time: $TmaxAnalysis"
        puts $statusFile "Umax: $Umax"
        puts $statusFile "Amax: $Amax"
        close $statusFile

        if {$analysisComplete} {
            set statusStr "COMPLETED"
        } else {
            set statusStr "FAILED"
        }
        puts "    Results saved (Umax=$Umax Amax=$Amax freq_i=$freq Status=$statusStr)"

        # Cleanup before next increment
        catch {reset}
        catch {remove loadPattern $patternID}
        catch {wipe}
    }
    puts "Completed GM [expr {$gmIdx+1}]/$numTimeSeries: [file tail $normalizedFile] - processed $gmFactorCount factors"
}

# Aggregate outputs
puts "\n*** WRITING OUTPUT FILES ***"

set outputFileU "Umax_all_text.txt"
set outputFileA "Amax_all_text.txt"

if {![file exists "results"]} {
    file mkdir results
}

set fileListU [glob -directory results -nocomplain -type f **/Umax.txt]
set fileListA [glob -directory results -nocomplain -type f **/Amax.txt]

# Write detailed text files
if {[llength $fileListU] > 0} {
    set out [open $outputFileU "w"]
    puts $out "# Maximum Displacements from IDA Analysis"
    foreach f $fileListU {
        if {[catch {
            set c [string trim [read [open $f r]]]
            puts $out "File: $f"
            puts $out "Directory: [file dirname $f]"
            puts $out "Umax: $c"
            puts $out "---"
        } err]} {
            puts "Error reading $f: $err"
            puts $out "Error reading file: $f"
            puts $out "---"
        }
    }
    close $out
} else {
    set o [open $outputFileU "w"]
    puts $o "# No displacement files found"
    close $o
}

if {[llength $fileListA] > 0} {
    set out2 [open $outputFileA "w"]
    puts $out2 "# Maximum Accelerations from IDA Analysis"
    foreach f $fileListA {
        if {[catch {
            set c [string trim [read [open $f r]]]
            puts $out2 "File: $f"
            puts $out2 "Directory: [file dirname $f]"
            puts $out2 "Amax: $c"
            puts $out2 "---"
        } err]} {
            puts "Error reading $f: $err"
            puts $out2 "Error reading file: $f"
            puts $out2 "---"
        }
    }
    close $out2
} else {
    set o2 [open $outputFileA "w"]
    puts $o2 "# No acceleration files found"
    close $o2
}

# Write numeric-only output columns (Umax_all.txt, Amax_all.txt)
set fileListU1 [glob -directory results -nocomplain -type f **/Umax.txt]
set fileListA1 [glob -directory results -nocomplain -type f **/Amax.txt]

# Sort the file lists using dictionary order
set fileListU1 [lsort -dictionary $fileListU1]
set fileListA1 [lsort -dictionary $fileListA1]

set outputFileU1 "Umax_all.txt"
set outputFileA1 "Amax_all.txt"

set out1 [open $outputFileU1 "w"]
foreach f $fileListU1 {
    if {[catch {
        puts $out1 [string trim [read [open $f r]]]
    } err]} {
        puts "Error reading $f: $err"
    }
}
close $out1

set out2 [open $outputFileA1 "w"]
foreach f $fileListA1 {
    if {[catch {
        puts $out2 [string trim [read [open $f r]]]
    } err]} {
        puts "Error reading $f: $err"
    }
}
close $out2

wipe
puts "\n*** FINISHED IDA RUN ***"
puts "Output files: Umax_all.txt, Amax_all.txt, and their detailed text versions."
