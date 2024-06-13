module core_top #(
    parameter DWIDTH = 32
)(
    input                 clk,
    input                 rst
);

// hope this work UwU

// Jump type
localparam [2:0] JUMP_ZERO = 3'd0, // no jump
                 JUMP_BEQ  = 3'd1, // beq jump 
                 JUMP_JR   = 3'd2, // jr jump
                 JUMP_JAL  = 3'd3, // jal jump
                 JUMP_J    = 3'd4; // j jump

// rdst_data
localparam [1:0] LOAD_ALU_RES = 2'b00,
                 LOAD_DMEM    = 2'b01,
                 LOAD_PC_4    = 2'b10;

localparam [2:0] FWD_ORI = 3'b000, // one-hot encoding is easier
                 FWD_EX  = 3'b001,
                 FWD_MEM = 3'b010,
                 FWD_WB  = 3'b100;

// module declaration

// pc module
wire [31: 0] pc_addr, pc_4;
assign pc_4 = pc_addr + 4;
pc pc_inst(
    // input
    .clk(clk),
    .rst(rst),
    .pc_4(pc_4),
    .bran_jump(bran_jump),
    .bran_target_pc(bran_target_pc),
    .BHT_jump(BHT_jump),
    .BHT_target_pc(BHT_target_pc),
    .hazard_flush(hazard_flush),
    .hazard_stall(hazard_stall),
    .idex_jump(idex_jump),
    .idex_pc_4(idex_pc_4),

    // output 
    .addr(pc_addr)
); // end of pc module

// imem module
wire [31: 0] imem_instr;
imem imem_inst(
    // input
    .addr(pc_addr[7 : 0]),
    
    // output
    .rdata(imem_instr)
); // end of imem module

// if_id module
wire [31: 0] ifid_pc_4, ifid_instr;
wire         ifid_jump;
if_id ifid_inst(
    // input
    .clk(clk),
    .stall(hazard_stall),
    .rst(rst),
    .flush(hazard_flush),
    
    ._pc_4(pc_4),
    ._instr(imem_instr),
    ._jump(BHT_jump),
    
    // output
    .pc_4(ifid_pc_4),
    .instr(ifid_instr),
    .jump(ifid_jump)
); // end of if_id module

// decode module
wire [2 : 0] dec_jump_type;
wire [25: 0] dec_jump_addr;
wire         dec_we_dmem, dec_we_regfile;
wire [1 : 0] dec_lw_flag;
wire         dec_ssel;
wire [31: 0] dec_extend_imm;
wire [3 : 0] dec_alu_op;
wire [4 : 0] dec_rdst_id, dec_rs1_id, dec_rs2_id;
decode decode_inst(
    // input
    .instr(ifid_instr),
    
    // output
    .op(dec_alu_op),
    .ssel(dec_ssel),
    .imm(dec_extend_imm),
    .rs1_id(dec_rs1_id),
    .rs2_id(dec_rs2_id),
    .rdst_id(dec_rdst_id),
    .jump_type(dec_jump_type),
    .jump_addr(dec_jump_addr),
    .we_dmem(dec_we_dmem),
    .we_regfile(dec_we_regfile),
    .lw_flag(dec_lw_flag)
); // end of decode module

// regfile module
wire [31: 0] regfile_rs1_data, regfile_rs2_data;
reg_file reg_file_inst(
    // input
    .clk(clk),
    .rst(rst),
    
    .rs1_id(dec_rs1_id),
    .rs2_id(dec_rs2_id),
    .we(memwb_we_regfile),
    .rdst_id(memwb_rdst_id),
    .rdst(memwb_rdst_data),
    
    // output
    .rs1(regfile_rs1_data),
    .rs2(regfile_rs2_data)
); // end of regfile module

//=========================================================
// hazard module
wire         hazard_flush, hazard_stall;
wire [2 : 0] hazard_fwd_rs1, hazard_fwd_rs2;
hazard_ctrl hazard_inst(
    // input
    // data hazard
    .dec_rs1_id(dec_rs1_id),
    .dec_rs2_id(dec_rs2_id),
    .idex_rdst_id(idex_rdst_id),
    .idex_lw_flag(idex_lw_flag),
    .exmem_rdst_id(exmem_rdst_id),
    .memwb_rdst_id(memwb_rdst_id),
    
    // control hazard
    .bran_jump(bran_jump),
    .BHT_jump(idex_jump),
    
    // output
    .fwd_rs1(hazard_fwd_rs1),
    .fwd_rs2(hazard_fwd_rs2),
    .hazard_flush(hazard_flush),
    .hazard_stall(hazard_stall)
); // end of hazard module

// BHT module
wire         BHT_jump;
wire [31: 0] BHT_target_pc;
wire [31: 0] BHT_update_pc;
wire         BHT_update_valid;

assign BHT_update_pc = idex_pc_4 - 4;
assign BHT_update_valid = (idex_jump_type == JUMP_BEQ);

BHT BHT_inst(
    // input
    .clk(clk),
    .rst(rst),

    .read_pc(pc_addr),

    .update_pc(BHT_update_pc),
    .update_target(bran_target_pc),
    .update_valid(BHT_update_valid),
    .update_value(bran_jump),

    .jump(BHT_jump),
    .target_pc(BHT_target_pc)
);

//=========================================================
// id_ex module

// forwarding mux for rs1 and rs2
reg  [31: 0] idex_rs1_l, idex_rs2_l;
always@(*) begin // idex_rs1_l
    case(hazard_fwd_rs1)
    FWD_ORI: idex_rs1_l = regfile_rs1_data;
    FWD_EX : idex_rs1_l = alu_result;
    FWD_MEM: idex_rs1_l = mux_rdst_data;
    FWD_WB : idex_rs1_l = memwb_rdst_data;
    default: idex_rs1_l = regfile_rs1_data;
    endcase
end
always@(*) begin // idex_rs1_l
    case(hazard_fwd_rs2)
    FWD_ORI: idex_rs2_l = regfile_rs2_data;
    FWD_EX : idex_rs2_l = alu_result;
    FWD_MEM: idex_rs2_l = mux_rdst_data;
    FWD_WB : idex_rs2_l = memwb_rdst_data;
    default: idex_rs2_l = regfile_rs2_data;
    endcase
end
wire [31: 0] idex_pc_4;
wire [2 : 0] idex_jump_type;
wire [25: 0] idex_jump_addr;
wire         idex_we_dmem, idex_we_regfile, idex_ssel;
wire [1 : 0] idex_lw_flag;
wire [31: 0] idex_extend_imm;
wire [3 : 0] idex_alu_op;
wire [31: 0] idex_rs1_data, idex_rs2_data;
wire [4 : 0] idex_rdst_id;
wire         idex_jump;
id_ex idex_inst(
    // input
    .clk(clk),
    .rst(rst),
    .flush(hazard_flush),
    .stall(hazard_stall),
    
    ._pc_4(ifid_pc_4),
    ._jump_type(dec_jump_type),
    ._jump_addr(dec_jump_addr),
    ._we_dmem(dec_we_dmem),
    ._we_regfile(dec_we_regfile),
    ._lw_flag(dec_lw_flag),
    
    ._ssel(dec_ssel),
    ._signed_extend_imm(dec_extend_imm),
    ._alu_op(dec_alu_op),
    ._rs1_data(idex_rs1_l),
    ._rs2_data(idex_rs2_l),
    ._rdst_id(dec_rdst_id),
    ._jump(ifid_jump),
    
    // output
    .pc_4(idex_pc_4),
    .jump_type(idex_jump_type),
    .jump_addr(idex_jump_addr),
    .we_dmem(idex_we_dmem),
    .we_regfile(idex_we_regfile),
    .lw_flag(idex_lw_flag),
    
    .ssel(idex_ssel),
    .signed_extend_imm(idex_extend_imm),
    .alu_op(idex_alu_op),
    .rs1_data(idex_rs1_data),
    .rs2_data(idex_rs2_data),
    .rdst_id(idex_rdst_id),
    .jump(idex_jump)
); // end of id_ex module
//=========================================================


// branch module
wire [31: 0] bran_target_pc;
wire         bran_jump;
branch branch_inst(
    // input
    .pc_4(idex_pc_4),
    .jump_type(idex_jump_type),
    .jump_addr(idex_jump_addr),
    .rs1_data(idex_rs1_data),
    .signed_extend_imm(idex_extend_imm),
    .zero(alu_zero),

    // output
    .jump(bran_jump),
    .new_pc(bran_target_pc)
); // end of branch module

// alu module
wire [31: 0] alu_result;
wire         alu_zero, alu_overflow;
// mux for alu rs2
wire [31: 0] alu_rs2_data;
assign alu_rs2_data = (idex_ssel) ? idex_rs2_data : idex_extend_imm;

alu alu_inst(
    // input
    .op(idex_alu_op),
    .rs1(idex_rs1_data),
    .rs2(alu_rs2_data),

    // output
    .rd(alu_result),
    .zero(alu_zero),
    .overflow(alu_overflow)
); // end of alu module

// ex_mem module
wire [31: 0] exmem_pc_4;
wire         exmem_we_dmem, exmem_we_regfile;
wire [1 : 0] exmem_lw_flag;
wire [31: 0] exmem_result;
wire [4 : 0] exmem_rdst_id;
wire [31: 0] exmem_rs2_data;
ex_mem exmem_inst(
    // input
    .clk(clk),
    .rst(rst),
    //.flush(hazard_flush),

    ._pc_4(idex_pc_4),
    ._we_mem(idex_we_dmem),
    ._we_regfile(idex_we_regfile),
    ._lw_flag(idex_lw_flag),
    ._result(alu_result),
    ._rdst_id(idex_rdst_id),
    ._rs2_data(idex_rs2_data),
    
    // output
    .pc_4(exmem_pc_4),
    .we_mem(exmem_we_dmem),
    .we_regfile(exmem_we_regfile),
    .lw_flag(exmem_lw_flag),
    .result(exmem_result),
    .rdst_id(exmem_rdst_id),
    .rs2_data(exmem_rs2_data)
); // end of ex_mem module

// dmem module
wire [31: 0] dmem_read_data;
dmem dmem_inst(
    // input
    .clk(clk),
    .addr(exmem_result[7 : 0]),
    .we(exmem_we_dmem),
    .re(exmem_lw_flag[0]),
    .wdata(exmem_rs2_data),

    // output
    .rdata(dmem_read_data)
); // end of dmem module

// mem_wb module
wire [4 : 0] memwb_rdst_id;
wire [31: 0] memwb_rdst_data;
wire         memwb_we_regfile;
wire [31: 0] mux_rdst_data;
reg  [31: 0] mux_rdst_data_l;
assign mux_rdst_data = mux_rdst_data_l;
always@(*) begin
    case(exmem_lw_flag)
    LOAD_ALU_RES: mux_rdst_data_l = exmem_result;
    LOAD_DMEM   : mux_rdst_data_l = dmem_read_data;
    LOAD_PC_4   : mux_rdst_data_l = exmem_pc_4;
    default     : mux_rdst_data_l = exmem_result; 
    endcase
end
mem_wb memwb_inst(
    // input
    .clk(clk),
    .rst(rst),
    //.flush(hazard_flush),

    ._we_regfile(exmem_we_regfile),
    ._rdst_id(exmem_rdst_id),
    ._rdst_data(mux_rdst_data),

    // output
    .we_regfile(memwb_we_regfile),
    .rdst_id(memwb_rdst_id),
    .rdst_data(memwb_rdst_data)
); // end of mem_wb module
    
    

endmodule

// below are the module that not included in the submission list
// pc module
module pc(
    input          clk,
    input          rst,
    input  [31: 0] pc_4,
    input          bran_jump,
    input  [31: 0] bran_target_pc,
    input          BHT_jump,
    input  [31: 0] BHT_target_pc,
    input          hazard_flush,
    input          hazard_stall,
    input          idex_jump,
    input  [31: 0] idex_pc_4,
    
    output [31: 0] addr
);

reg [31: 0] pc_cnt, pc_next_addr;
assign addr = pc_cnt;

always@(*) begin
    if(hazard_flush) begin
        if(idex_jump) pc_next_addr = idex_pc_4;
        else pc_next_addr = bran_target_pc;
    end
    else if(BHT_jump) pc_next_addr = BHT_target_pc;
    else pc_next_addr = pc_4;
end

always@(posedge clk) begin
    if(rst) pc_cnt <= 32'h0;
    else if(hazard_stall) pc_cnt <= pc_cnt;
    else pc_cnt <= pc_next_addr;
end

endmodule
// end of pc module

// branch module
module branch(
    input  [31: 0] pc_4,
    input  [2 : 0] jump_type,// j and jal
    input  [25: 0] jump_addr,// j, jal and beq
    input  [31: 0] rs1_data, // jr
    input  [31: 0] signed_extend_imm,
    input          zero,

    output reg         jump,
    output reg [31: 0] new_pc
);
// Jump type
localparam [2:0] JUMP_ZERO = 3'd0, // no jump
                 JUMP_BEQ  = 3'd1, // beq jump 
                 JUMP_JR   = 3'd2, // jr jump
                 JUMP_JAL  = 3'd3, // jal jump
                 JUMP_J    = 3'd4; // j jump
wire [31: 0] branch_addr;
reg  [31: 0] target_pc;    // used as latch
wire [31: 0] pc;
assign jump = 
    ( jump_type == JUMP_BEQ & zero ) |
    ( jump_type == JUMP_JR )         |
    ( jump_type == JUMP_JAL )        |
    ( jump_type == JUMP_J );
/** /
In stage 3 we'll get the info whether to jump or not.
If to jump, we assert the jump signal and give target_pc.
All pipeline registers have to flush the data.
At the next clock, pc will update the new pc and fetch new instr.
/**/
assign branch_addr = pc_4 + (signed_extend_imm << 2);
assign pc = pc_4 - 4;
assign target_pc   = { pc[31:28], jump_addr, 2'b00 };

always@(*) begin
    case(jump_type)
    JUMP_ZERO : new_pc = 32'h0;
    JUMP_BEQ  : new_pc = zero ? branch_addr : 32'h0;
    JUMP_JR   : new_pc = rs1_data;
    JUMP_JAL  : new_pc = target_pc;
    JUMP_J    : new_pc = target_pc;
    default   : new_pc = 32'h0;
    endcase
end

endmodule
// end of branch module

// if/id register module
module if_id(
    input         clk,
    input         rst,
    input         stall,
    input         flush,
    
    input [31: 0] _pc_4,
    input [31: 0] _instr,
    input         _jump,

    output reg [31: 0] pc_4,
    output reg [31: 0] instr,
    output reg         jump
);

always@(posedge clk) begin
    if(flush | rst) begin
        instr <= 32'h0;
        pc_4  <= 32'h0;
        jump  <= 1'b0;
    end
    else if(stall) begin
        instr <= instr;
        pc_4  <= pc_4;
        jump  <= jump;
    end
    else begin
        instr <= _instr;
        pc_4 <= _pc_4;
        jump <= _jump;
    end
end

endmodule
// end of if/id register module

// id/ex register module
module id_ex(
    input          clk,
    input          rst,
    input          flush,
    input          stall,
    
    input  [31: 0] _pc_4,
    input  [2 : 0] _jump_type,
    input  [25: 0] _jump_addr,
    input          _we_dmem, 
    input          _we_regfile,
    input  [1 : 0] _lw_flag, // determine whether use dmem data or alu result, if 1, read memory. re_dmem.
    
    input          _ssel,
    input  [31: 0] _signed_extend_imm,
    input  [3 : 0] _alu_op,  // omit the reg_dst signal
    input  [31: 0] _rs1_data,
    input  [31: 0] _rs2_data,
    input  [4 : 0] _rdst_id,   // different from textbook.
                               // decode module will decide rdst.
    input          _jump,

    output reg [31: 0] pc_4,
    output reg [2 : 0] jump_type,
    output reg [25: 0] jump_addr,
    output reg         we_dmem, 
    output reg         we_regfile,
    output reg [1 : 0] lw_flag, // determine whether use dmem data or alu result, if 1, read memory. re_dmem.
    output reg         ssel,
    output reg [31: 0] signed_extend_imm,
    output reg [3 : 0] alu_op,  // omit the reg_dst signal
    output reg [31: 0] rs1_data,
    output reg [31: 0] rs2_data,
    output reg [4 : 0] rdst_id,   // different from textbook.
                               // decode module will decide rdst.
    output reg         jump
);

always@(posedge clk) begin
    if (flush | stall | rst) begin
        pc_4              <= 32'b0;
        jump_type         <= 3'o0;
        jump_addr         <= 26'h0;
        we_dmem           <= 1'b0;
        we_regfile        <= 1'b0;
        lw_flag           <= 2'b0;
        ssel              <= 1'b0;
        signed_extend_imm <= 32'h0;
        alu_op            <= 4'h0;
        rs1_data          <= 32'h0;
        rs2_data          <= 32'h0;
        rdst_id           <= 5'h0;
        jump              <= 1'b0;
    end
    else begin
        pc_4              <= _pc_4;
        jump_type         <= _jump_type;
        jump_addr         <= _jump_addr;
        we_dmem           <= _we_dmem;
        we_regfile        <= _we_regfile;
        lw_flag           <= _lw_flag;
        ssel              <= _ssel;             
        signed_extend_imm <= _signed_extend_imm;
        alu_op            <= _alu_op;
        rs1_data          <= _rs1_data;
        rs2_data          <= _rs2_data;
        rdst_id           <= _rdst_id;
        jump              <= _jump;
    end
end

endmodule
// end of id/ex register module

// ex/mem register module
module ex_mem(
    input          clk,
    input          rst,
    //input          flush,
    
    input  [31: 0] _pc_4,
    input          _we_mem,
    input          _we_regfile,
    input  [1 : 0] _lw_flag,
    input  [31: 0] _result,
    input  [4 : 0] _rdst_id,
    input  [31: 0] _rs2_data,
    
    output reg [31: 0] pc_4,
    output reg         we_mem,
    output reg         we_regfile,
    output reg [1 : 0] lw_flag,
    output reg [31: 0] result,
    output reg [4 : 0] rdst_id,
    output reg [31: 0] rs2_data
);

always@(posedge clk) begin
    if(/*flush |*/ rst) begin
        pc_4       <= 32'h0;
        we_mem     <= 1'b0;
        we_regfile <= 1'b0;
        lw_flag    <= 2'b00;
        result     <= 32'h0;
        rdst_id    <= 5'h0;
        rs2_data   <= 32'h0;
    end
    else begin
        pc_4       <= _pc_4;
        we_mem     <= _we_mem;
        we_regfile <= _we_regfile;
        lw_flag    <= _lw_flag;
        result     <= _result;
        rdst_id    <= _rdst_id;
        rs2_data   <= _rs2_data;
    end
end

endmodule
// end of ex/mem register module

// mem/wb register module
module mem_wb(
    input          clk,
    input          rst,
    //input          flush,
    input          _we_regfile,
    input  [4 : 0] _rdst_id,
    input  [31: 0] _rdst_data,
    
    output reg         we_regfile,
    output reg [4 : 0] rdst_id,
    output reg [31: 0] rdst_data
);

always@(posedge clk) begin
    if(/*flush |*/ rst) begin
        we_regfile <= 1'b0;
        rdst_id <= 5'h0;
        rdst_data <= 32'h0;
    end
    else begin
        we_regfile <= _we_regfile;
        rdst_id   <= _rdst_id;
        rdst_data <= _rdst_data;
    end
end

endmodule
// end of mem/wb register module