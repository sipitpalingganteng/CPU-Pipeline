// hazard.v - load-use hazard detection
//
// Stalls IF and ID for one cycle when the instruction in EX is a load whose
// destination is read by the instruction in ID. Other data hazards are
// resolved by forward.v.
module hazard (
    input        id_rs_valid,
    input        id_rt_valid,
    input  [4:0] id_rs,
    input  [4:0] id_rt,
    input  [4:0] ex_dest,
    input        ex_gr_we,
    input        ex_res_from_mem,
    output       stall_if,
    output       stall_id
);
    wire ex_load_hazard_rs = ex_res_from_mem && ex_gr_we &&
                             (ex_dest != 5'b0) && id_rs_valid &&
                             (ex_dest == id_rs);
    wire ex_load_hazard_rt = ex_res_from_mem && ex_gr_we &&
                             (ex_dest != 5'b0) && id_rt_valid &&
                             (ex_dest == id_rt);

    assign stall_if = ex_load_hazard_rs || ex_load_hazard_rt;
    assign stall_id = stall_if;
endmodule
