module hazard_ctrl(  // combinational logic
    // input
    // data hazard
    input  [4 : 0] dec_rs1_id, // rs
    input  [4 : 0] dec_rs2_id, // rt, for rt == 0, we assume it won't cause any hazard.
    input  [4 : 0] idex_rdst_id,
    input  [4 : 0] exmem_rdst_id,
    input  [4 : 0] memwb_rdst_id,
    
    // control hazard
    input          bran_jump,
    
    // output
    output         hazard_flush,
    output         hazard_stall
);

assign hazard_flush = bran_jump;
assign hazard_stall = 
    (dec_rs1_id != 0 & (dec_rs1_id == idex_rdst_id | dec_rs1_id == exmem_rdst_id | dec_rs1_id == memwb_rdst_id)) |
    (dec_rs2_id != 0 & (dec_rs2_id == idex_rdst_id | dec_rs2_id == exmem_rdst_id | dec_rs2_id == memwb_rdst_id));
    

/** /
consider the asm of "add $t0, $s0, $s1; add $t0, $t0, $s2;"
clk 3: id  -> instr 2 => stall
       ex  -> instr 1 => work (idex)
clk 4: id  -> instr 2 (ifid and pc didn't change) => stall
       ex  -> empty instr (32'h0)
       mem -> instr 1 => work (exmem)
clk 5: id  -> instr 2
       wb  -> instr 1 => work (the data in memwb will be update at the next clk raise)
/**/

endmodule
    
