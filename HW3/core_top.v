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

    // Program Counter signals
    reg  [DWIDTH-1:0] pc;

    //===============================================================
    // wire declare
    // input and output port for module
    
    // pc
    // input
    wire [31: 0] pc_next_addr;
    // output
    wire [31: 0] pc_addr;

    // instruction memory
    // input
    wire [31: 0] imem_addr;
    // output
    wire [31: 0] imem_data;

    // instruction decoder
    // input
    wire [31: 0] dec_instr;
    // output
    wire [2 : 0] dec_jump_type;
    wire [25: 0] dec_jump_addr;
    wire         dec_we_regfile, dec_we_dmem, dec_ssel;
    wire [1 : 0] dec_lw_flag;
    wire [31: 0] dec_extend_imm; // sign extend imm, not zero extend
    wire [3 : 0] dec_op_alu;
    wire [4 : 0] dec_rs1_id, dec_rs2_id, dec_rdst_id;

    // register file
    // input
    wire [4 : 0] regfile_rs1_id, regfile_rs2_id, regfile_rdst_id;
    wire         regfile_we;
    wire [31: 0] regfile_rdst_data;
    // output
    wire [31: 0] regfile_rs1_data, regfile_rs2_data;

    // ALU
    // input
    wire [3 : 0] alu_op_alu;
    wire [31: 0] alu_rs1_data, alu_rs2_data;
    // output
    wire alu_zero, alu_overflow;
    wire [31: 0] alu_data;

    // data memory
    // input
    wire [31: 0] dmem_addr;
    wire         dmem_we;
    wire [31: 0] dmem_write_data;
    // output
    wire [31: 0] dmem_read_data;

    // end of wire declare
    //===============================================================

    //===============================================================
    // some combinational block
    
    // adder for pc + 4
    wire [31: 0] pc_4;
    assign pc_4 = pc_addr + 32'd4;

    // mux2to1 for ssel ? imm : rs2_data
    wire [31: 0] mux_ssel;
    assign mux_ssel = (dec_ssel) ? regfile_rs2_data : dec_extend_imm;

    // mux3to1 for lw_flag ? rdata : alu_data
    reg  [31: 0] mux_lw_flag;
    always@(*) begin
        case(dec_lw_flag)
            LOAD_ALU_RES: mux_lw_flag = alu_data;
            LOAD_DMEM   : mux_lw_flag = dmem_read_data;
            LOAD_PC_4   : mux_lw_flag = pc_4;
            default     : mux_lw_flag = 32'h0000_0000;
        endcase
    end
    
    // 32-bits adder for dmem_addr
    wire [31: 0] add_dmem_addr;
    assign add_dmem_addr = dec_extend_imm + regfile_rs1_data;

    // submodule for target_pc
    wire [31: 0] target_pc;
    assign target_pc = { pc_4[31:28], dec_jump_addr, 2'b00 };

    //  for beq addr
    wire [31: 0] branch_addr;
    assign branch_addr = pc_4 + (dec_extend_imm << 2);

    // mux4to1 for pc_next_addr
    reg  [31: 0] pc_next_addr_l; // l for latch
    assign pc_next_addr = pc_next_addr_l;
    always@(*) begin
        case(dec_jump_type) // dec_jump_type [2 : 0]
            JUMP_ZERO:
                pc_next_addr_l = pc_4;
            JUMP_BEQ:
                pc_next_addr_l = (alu_zero) ? branch_addr : pc_4;
            JUMP_JR :
                pc_next_addr_l = regfile_rs1_data;
            JUMP_JAL:
                pc_next_addr_l = target_pc;
            JUMP_J  :
                pc_next_addr_l = target_pc;
            default   :
                pc_next_addr_l = pc_4;
        endcase
    end
    
    // end of combinational block
    //===============================================================

    // pc module
    assign pc_addr = pc;
    always @(posedge clk) begin
        if (rst) pc <= 0;
        else pc <= pc_next_addr;
    end
    
    // imem module
    imem imem_inst(
        // input
        .addr(imem_addr),

        // output
        .rdata(imem_data)
    );
    assign imem_addr = pc_addr;

    // decode module
    decode decode_inst (
        // input
        .instr(dec_instr),

        // output  
        .jump_type(dec_jump_type),
        .jump_addr(dec_jump_addr),
        .we_regfile(dec_we_regfile),
        .we_dmem(dec_we_dmem),
        .lw_flag(dec_lw_flag),

        .op(dec_op_alu),
        .ssel(dec_ssel),
        .imm(dec_extend_imm),
        .rs1_id(dec_rs1_id),
        .rs2_id(dec_rs2_id),
        .rdst_id(dec_rdst_id)
    );
    assign dec_instr = imem_data;

    // register file module
    reg_file reg_file_inst (
        // input
        .clk(clk),
        .rst(rst),

        .rs1_id(regfile_rs1_id),
        .rs2_id(regfile_rs2_id),

        .we(regfile_we),
        .rdst_id(regfile_rdst_id),
        .rdst(regfile_rdst_data),

        // output 
        .rs1(regfile_rs1_data), // rs
        .rs2(regfile_rs2_data)  // rt
    );
    assign regfile_rs1_id    = dec_rs1_id;
    assign regfile_rs2_id    = dec_rs2_id;
    assign regfile_rdst_id   = dec_rdst_id;
    assign regfile_rdst_data = mux_lw_flag;
    assign regfile_we        = dec_we_regfile;

    // alu module
    alu alu_inst (
        // input
        .op(alu_op_alu),
        .rs1(alu_rs1_data),
        .rs2(alu_rs2_data),

        // output
        .rd(alu_data),
        .zero(alu_zero),
        .overflow(alu_overflow)
    );
    assign alu_op_alu   = dec_op_alu;
    assign alu_rs1_data = regfile_rs1_data;
    assign alu_rs2_data = mux_ssel;

    // Dmem
    dmem dmem_inst (
        // input
        .clk(clk),
        .addr(dmem_addr),
        .we(dmem_we),
        .wdata(dmem_write_data),

        // output
        .rdata(dmem_read_data)
    );
    assign dmem_addr       = add_dmem_addr;
    assign dmem_we         = dec_we_dmem;
    assign dmem_write_data = regfile_rs2_data; 

    /** / 
    // temporary banned

    // target_pc
    branch_addr bran_addr_inst (
        .pc(),
        .jump_addr(),

        .bran_addr()
    );

    //branch_addr
    /**/

endmodule

/** /
module target_pc(
    input  [3 : 0] pc,
    input  [25: 0] jump_addr,

    output [31: 0] target_pc_addr
);

assign target_pc_addr = { pc, jump_addr, 2'b00 }

endmodule
/**/
