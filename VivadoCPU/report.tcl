# report.tcl - regenerate the synthesis/implementation utilization and timing
# reports for the five-stage MIPS pipeline (top: mips_pipeline) without
# clicking through the Vivado GUI.
#
# Run from anywhere:
#   vivado -mode batch -source VivadoCPU/report.tcl
#
# Writes to VivadoCPU/reports/:
#   utilization_synth.rpt   post-synthesis resource usage
#   timing_synth.rpt        post-synthesis static timing (setup + hold)
#   utilization_impl.rpt    post-place-and-route resource usage
#   timing_impl.rpt         post-place-and-route static timing
#
# Set RUN_IMPL to 0 to stop after synthesis (much faster). Note that hold
# timing is only meaningful after implementation, because it depends on
# routing and clock skew.

set RUN_IMPL 1
if {[info exists ::env(RUN_IMPL)]} { set RUN_IMPL $::env(RUN_IMPL) }

set script_dir [file dirname [file normalize [info script]]]
set project    [file join $script_dir VivadoCPU.xpr]
set out_dir    [file join $script_dir reports]
file mkdir $out_dir

open_project $project

# Synthesise the pipeline top, not a testbench.
set_property top mips_pipeline [get_filesets sources_1]

# ---- Synthesis -------------------------------------------------------------
reset_run synth_1
launch_runs synth_1 -jobs [exec nproc]
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 failed - check the run log in VivadoCPU/VivadoCPU.runs/synth_1"
}

open_run synth_1 -name synth_1
report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 -input_pins \
    -file [file join $out_dir timing_synth.rpt]
close_design

# ---- Implementation (place and route) --------------------------------------
if {$RUN_IMPL} {
    reset_run impl_1
    launch_runs impl_1 -jobs [exec nproc]
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "impl_1 failed - check the run log in VivadoCPU/VivadoCPU.runs/impl_1"
    }

    open_run impl_1 -name impl_1
    report_utilization -file [file join $out_dir utilization_impl.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained \
        -check_timing_verbose -max_paths 10 -input_pins \
        -file [file join $out_dir timing_impl.rpt]
    close_design
}

puts "Reports written to $out_dir"
