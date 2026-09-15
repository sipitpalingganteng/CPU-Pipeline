module hazard_unit (
    input        id_rs_valid,
    input        id_rt_valid,
    input  [4:0] id_rs,
    input  [4:0] id_rt,
    input  [4:0] ex_dest,
    input        ex_gr_we,
    input        ex_res_from_mem,
    input  [4:0] mem_dest,
    input        mem_gr_we,
    output       stall_if,
    output       stall_id,
    output       forward_rs_from_ex,
    output       forward_rs_from_mem,
    output       forward_rt_from_ex,
    output       forward_rt_from_mem
);
    wire ex_load_hazard_rs = ex_res_from_mem && ex_gr_we &&
                             (ex_dest != 5'b0) && id_rs_valid &&
                             (ex_dest == id_rs);
    wire ex_load_hazard_rt = ex_res_from_mem && ex_gr_we &&
                             (ex_dest != 5'b0) && id_rt_valid &&
                             (ex_dest == id_rt);

    assign stall_if = ex_load_hazard_rs || ex_load_hazard_rt;
    assign stall_id = stall_if;

    assign forward_rs_from_ex = ex_gr_we && !ex_res_from_mem &&
                                (ex_dest != 5'b0) && id_rs_valid &&
                                (ex_dest == id_rs);
    assign forward_rs_from_mem = mem_gr_we && (mem_dest != 5'b0) &&
                                 id_rs_valid && (mem_dest == id_rs);
    assign forward_rt_from_ex = ex_gr_we && !ex_res_from_mem &&
                                (ex_dest != 5'b0) && id_rt_valid &&
                                (ex_dest == id_rt);
    assign forward_rt_from_mem = mem_gr_we && (mem_dest != 5'b0) &&
                                 id_rt_valid && (mem_dest == id_rt);
endmodule
