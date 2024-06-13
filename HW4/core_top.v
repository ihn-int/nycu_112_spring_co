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

// module declaration

// pc module
reg  [DWIDTH-1:0] pc, pc_addr, pc_4, pc_next_addr;
assign pc_addr = pc;
assign pc_4 = pc_addr + 4;
assign pc_next_addr = (bran_jump) ? bran_target_pc : pc_4;
always@(posedge clk) begin
    if(rst) pc <= 32'h0;
    else if(hazard_stall) pc <= pc;
    else pc <= pc_next_addr;
end // end of pc module

// imem module
wire [31: 0] imem_instr;
imem imem_inst(
    // input
    .addr(pc_addr),
    
    // output
    .rdata(imem_instr)
); // end of imem module

// if_id module
wire [31: 0] ifid_pc_4, ifid_instr;
if_id ifid_inst(
    // input
    .clk(clk),
    .stall(hazard_stall),
    .rst(rst),
    .flush(hazard_flush),
    
    ._pc_4(pc_4),
    ._instr(imem_instr),
    
    // output
    .pc_4(ifid_pc_4),
    .instr(ifid_instr)
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

// hazard module
wire         hazard_flush, hazard_stall;
hazard_ctrl hazard_inst(
    // input
    // data hazard
    .dec_rs1_id(dec_rs1_id),
    .dec_rs2_id(dec_rs2_id),
    .idex_rdst_id(idex_rdst_id),
    .exmem_rdst_id(exmem_rdst_id),
    .memwb_rdst_id(memwb_rdst_id),
    
    // control hazard
    .bran_jump(bran_jump),
    
    // output
    .hazard_flush(hazard_flush),
    .hazard_stall(hazard_stall)
); // end of hazard module

// id_ex module
wire [31: 0] idex_pc_4;
wire [2 : 0] idex_jump_type;
wire [25: 0] idex_jump_addr;
wire         idex_we_dmem, idex_we_regfile, idex_ssel;
wire [1 : 0] idex_lw_flag;
wire [31: 0] idex_extend_imm;
wire [3 : 0] idex_alu_op;
wire [31: 0] idex_rs1_data, idex_rs2_data;
wire [4 : 0] idex_rdst_id;
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
    ._rs1_data(regfile_rs1_data),
    ._rs2_data(regfile_rs2_data),
    ._rdst_id(dec_rdst_id),
    
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
    .rdst_id(idex_rdst_id)
); // end of id_ex module
    
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
    .addr(exmem_result),
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
// branch module
module branch(
    input  [31: 0] pc_4,
    input  [25: 0] jump_type,// j and jal
    input  [31: 0] jump_addr,// j, jal and beq
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
If to jump, we assert the jump siganl and give target_pc.
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
    
    input [32: 0] _pc_4,
    input [32: 0] _instr,

    output reg [32: 0] pc_4,
    output reg [32: 0] instr
);

always@(posedge clk) begin
    if(flush | rst) begin
        instr <= 32'h0;
        pc_4  <= 32'h0;
    end
    else if(stall) begin
        instr <= instr;
        pc_4 <= pc_4;
    end
    else begin
        instr <= _instr;
        pc_4 <= _pc_4;
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
    output reg [4 : 0] rdst_id   // different from textbook.
                               // decode module will decide rdst.
);

always@(posedge clk) begin
    if (flush | stall | rst) begin
        pc_4              <= 1'b0;
        jump_type         <= 3'o0;
        jump_addr         <= 28'h0;
        we_dmem           <= 1'b0;
        we_regfile        <= 1'b0;
        lw_flag           <= 1'b0;
        ssel              <= 1'b0;
        signed_extend_imm <= 32'h0;
        alu_op            <= 4'h0;
        rs1_data          <= 32'h0;
        rs2_data          <= 32'h0;
        rdst_id           <= 5'h0;
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