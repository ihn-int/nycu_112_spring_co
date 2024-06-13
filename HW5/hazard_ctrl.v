module hazard_ctrl(  // combinational logic
    // input
    // data hazard and forwarding
    input  [4 : 0] dec_rs1_id, // rs
    input  [4 : 0] dec_rs2_id, // rt, for rt == 0, we assume it won't cause any hazard.
    input  [4 : 0] idex_rdst_id,
    input  [1 : 0] idex_lw_flag, // used for load use hazard
    input  [4 : 0] exmem_rdst_id,
    input  [4 : 0] memwb_rdst_id,
    
    // control hazard
    input          bran_jump,
    input          BHT_jump,

    // output
    output [2 : 0] fwd_rs1,
    output [2 : 0] fwd_rs2,
    output         hazard_flush,
    output         hazard_stall
);

localparam [1:0] LOAD_ALU_RES = 2'b00,
                 LOAD_DMEM    = 2'b01,
                 LOAD_PC_4    = 2'b10;

localparam [2:0] FWD_ORI = 3'b000, // one-hot encoding is easier
                 FWD_EX  = 3'b001,
                 FWD_MEM = 3'b010,
                 FWD_WB  = 3'b100;

// we take the result of stage 3(EX), 4(MEM) to id/ex register
// Thus, we need to consider the value of
// be aware of the priority
wire ex_fwd_rs1, ex_fwd_rs2, mem_fwd_rs1, mem_fwd_rs2,
     wb_fwd_rs1, wb_fwd_rs2;

// if hazard happens and idex equals to 01 -> load use hazard !!!!
// we can't forward the value at this situation
// otherwise forward the data;
assign hazard_stall = 
    ((dec_rs1_id != 0) & (dec_rs1_id == idex_rdst_id) & (idex_lw_flag[0])) | 
    ((dec_rs2_id != 0) & (dec_rs2_id == idex_rdst_id) & (idex_lw_flag[0]));
assign ex_fwd_rs1 = (dec_rs1_id != 0) &
        (dec_rs1_id == idex_rdst_id) & (~idex_lw_flag[0]);
assign ex_fwd_rs2 = (dec_rs2_id != 0) &
        (dec_rs2_id == idex_rdst_id) & (~idex_lw_flag[0]);
assign mem_fwd_rs1 = (dec_rs1_id != 0) & (dec_rs1_id == exmem_rdst_id);
assign mem_fwd_rs2 = (dec_rs2_id != 0) & (dec_rs2_id == exmem_rdst_id);
assign wb_fwd_rs1 = (dec_rs1_id != 0) & (dec_rs1_id == memwb_rdst_id);
assign wb_fwd_rs2 = (dec_rs2_id != 0) & (dec_rs2_id == memwb_rdst_id);

assign fwd_rs1 = { 3{~hazard_stall} } & { wb_fwd_rs1, mem_fwd_rs1, ex_fwd_rs1 };
assign fwd_rs2 = { 3{~hazard_stall} } & { wb_fwd_rs2, mem_fwd_rs2, ex_fwd_rs2 };

// control hazard
assign hazard_flush = bran_jump ^ BHT_jump;

endmodule

// BHT module, direct mapping, 64 entries
module BHT( 
    // input
    input clk,  // system clk
    input rst,  // system rst

    // IF stage
    input [31: 0] read_pc,      // pc_addr

    // EX stage
    input [31: 0] update_pc,    // pc
    input [31: 0] update_target,// target_pc
    input update_valid,         // jump_type == BEQ
    input update_value,         // bran_jump

    // output, predict part
    output jump,    // jump
    output [31: 0] target_pc
);

// IF stage
wire [5 : 0] pred_addr;
assign pred_addr = read_pc[7:2];
assign jump = jumps[pred_addr];
assign target_pc = target[pred_addr];

// EX stage
reg  [63: 0] jumps;
reg  [31: 0] target[63: 0];
wire [5 : 0] update_addr;

assign update_addr = update_pc[7:2];
integer idx;
initial begin
    for (idx = 0; idx < 64; idx = idx+1) begin
        target[idx] = 32'h0;
        jumps[idx] = 1'b0;
    end
end


always@(posedge clk) begin // update target pc and predict
    /**/
    if(update_valid) begin
        target[update_addr] <= update_target;
        jumps[update_addr] <= update_value;
    end
    else begin
        target[update_addr] <= target[update_addr];
        jumps[update_addr] <= jumps[update_addr];
    end
    /**/
end


endmodule