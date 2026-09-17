// forward.v - forwarding unit
//
// Selects the freshest value for each register-file read port: the EX result,
// the MEM/WB result, or the value written back on the same cycle. EX loads
// are not forwarded (they are stalled by hazard.v instead).
module forward (
    input        id_rs_valid,
    input        id_rt_valid,
    input  [4:0] id_rs,
    input  [4:0] id_rt,
    input  [4:0] ex_dest,
    input        ex_gr_we,
    input        ex_res_from_mem,
    input  [4:0] mem_dest,
    input        mem_gr_we,
    output       forward_rs_from_ex,
    output       forward_rs_from_mem,
    output       forward_rt_from_ex,
    output       forward_rt_from_mem
);
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
