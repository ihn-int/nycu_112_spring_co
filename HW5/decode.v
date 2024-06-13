module decode #(parameter DWIDTH = 32)
(
    input [DWIDTH-1:0]  instr,   // Input instruction.

    output reg [3 : 0]      op,      // Operation code for the ALU.
    output reg              ssel,    // Select the signal for either the immediate value or rs2.

    output reg [DWIDTH-1:0] imm,     // The immediate value (if used).
    output reg [4 : 0]      rs1_id,  // register ID for rs.
    output reg [4 : 0]      rs2_id,  // register ID for rt (if used).
    output reg [4 : 0]      rdst_id, // register ID for rd or rt (if used).

	output reg [2 : 0]      jump_type, // Jump type
	output reg [25: 0]      jump_addr, // Jump addr
	output reg              we_dmem,   // write enable, used by sw
	output reg              we_regfile,// write register, used by R type and lw
    output reg [1 : 0]      lw_flag    // flag determines use alu result or memery word
);

/***************************************************************************************
    ---------------------------------------------------------------------------------
    | R_type |    |   opcode   |   rs   |   rt   |   rd   |   shamt   |    funct    |
    ---------------------------------------------------------------------------------
    | I_type |    |   opcode   |   rs   |   rt   |             immediate            |
    ---------------------------------------------------------------------------------
    | J_type |    |   opcode   |                     address                        |
    ---------------------------------------------------------------------------------
                   31        26 25    21 20    16 15    11 10        6 5           0
 ***************************************************************************************/

    localparam [3:0] OP_AND = 4'b0000,
                     OP_OR  = 4'b0001,
                     OP_ADD = 4'b0010,
                     OP_SUB = 4'b0110,
                     OP_NOR = 4'b1100,
                     OP_SLT = 4'b0111,
                     OP_NOT_DEFINED = 4'b1111;

	localparam [2:0] JUMP_ZERO = 3'd0, // no jump
                     JUMP_BEQ  = 3'd1, // beq jump 
					 JUMP_JR   = 3'd2, // jr jump
					 JUMP_JAL  = 3'd3, // jal jump
					 JUMP_J    = 3'd4; // j jump
    localparam [1:0] LOAD_ALU_RES = 2'b00,
                     LOAD_DMEM    = 2'b01,
                     LOAD_PC_4    = 2'b10;

	wire [5:0]  _opcode,_funct;
	wire [4:0]  _shamt;

	assign _opcode  = instr[31:26];
	assign _funct   = instr[5:0];
	assign _shamt   = instr[10:6];
	
	always@(*) begin
		case(_opcode)
		6'h00: begin // R type instr
			rs1_id  = instr[25:21];
			rs2_id  = instr[20:16];
			rdst_id = instr[15:11];

			imm     = 32'h0000_0000; // choose rs2
			ssel    = 1'b1;          // 1 for rs2

			we_dmem    = 1'b0; // R type don't use dmem
            lw_flag    = LOAD_ALU_RES;    // not lw instruction

			case(_funct)
			6'h20: begin // add
				op = OP_ADD;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b1; // R type use register
			end
			6'h22: begin // sub
				op = OP_SUB;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b1; // R type use register
			end
			6'h23: begin // and
				op = OP_AND;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b1; // R type use register
			end
			6'h25: begin // or
				op = OP_OR;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b1; // R type use register
			end
			6'h27: begin // nor
				op = OP_NOR;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b1; // R type use register
			end
			6'h2a: begin // slt
				op = OP_SLT;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b1; // R type use register
			end
			6'h08: begin // !!! jr !!!
				op = OP_NOT_DEFINED; // no alu operation
				jump_type = JUMP_JR;
				jump_addr = 26'h0; // still no jump addr
                we_regfile = 1'b0; // jr not write register
			end
            default: begin
				op = OP_NOT_DEFINED;
				jump_type = JUMP_ZERO;
				jump_addr = 26'h0;
                we_regfile = 1'b0; // invalid opcode
            end
			endcase
		end
		6'h08: begin // I type instr, addi
			rs1_id  = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b0;  // 0 for imm
			op      = OP_ADD;

			jump_type = JUMP_ZERO;
			jump_addr = 26'h0;
			we_dmem   = 1'b0;
			we_regfile= 1'b1;
            lw_flag   = LOAD_ALU_RES;
		end
		6'h0a: begin // I type instr, slti
			rs1_id  = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b0;  // use imm
			op      = OP_SLT;
			
			jump_type = JUMP_ZERO;
			jump_addr = 26'h0;
			we_dmem   = 1'b0;
			we_regfile= 1'b1;
            lw_flag   = LOAD_ALU_RES;
		end
		6'h23: begin // I type instruction, lw
            // use alu to calculate address
			rs1_id  = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b0;  // use imm, imm + rs1
			op      = OP_ADD;
			
			jump_type = JUMP_ZERO;
			jump_addr = 26'h0;
			we_dmem   = 1'b0;
			we_regfile= 1'b1;       // write register
            lw_flag   = LOAD_DMEM;  // lw instruction
		end
		6'h2b: begin // I type instruction, sw
            // use alu to calculate address
			rs1_id  = instr[25:21];
			rs2_id  = instr[20:16];
			rdst_id = 5'b0;
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b0;  // use imm, imm + rs1
			op      = OP_ADD;
			
			jump_type = JUMP_ZERO;
			jump_addr = 26'h0;
			we_dmem   = 1'b1;   // only at sw instruction be high
			we_regfile= 1'b0;   // write register
            lw_flag   = LOAD_ALU_RES;  // not lw instruction
		end
		6'h04: begin // I type instruction, beq
            // beq give "sub rd rs rt",but not write register
            // if zero is high, mean rs == rt, thus jump
			rs1_id  = instr[25:21];
			rs2_id  = instr[20:16];
			rdst_id = 5'b0;
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b1;  // use rs2
			op      = OP_SUB;
			
			jump_type = JUMP_BEQ;
			jump_addr = 26'h0;
			we_dmem   = 1'b0;  
			we_regfile= 1'b0;  // not write register
            lw_flag   = LOAD_ALU_RES;  // not lw instruction
		end
		6'h03: begin // J type instruction, jal
            // R[31]   <- PC + 4
            // PC_next <- target pc
			rs1_id  = 5'b0;
			rs2_id  = 5'b0;
			rdst_id = 5'b11111; // R[31]
			imm     = 32'h0000;
			ssel    = 1'b0;     // not use imm, but also not use rs2_id
			op      = OP_NOT_DEFINED;
			
			jump_type = JUMP_JAL;
			jump_addr = instr[25:0];
			we_dmem   = 1'b0;
			we_regfile= 1'b1;       // write register
            lw_flag   = LOAD_PC_4;  // lw instruction
		end
		6'h02: begin // J type instruction, j
			rs1_id  = 5'b0;
			rs2_id  = 5'b0;
			rdst_id = 5'b0;
			imm     = 32'h0000;
			ssel    = 1'b0;  // not use imm, but also not use rs2_id
			op      = OP_NOT_DEFINED;
			
			jump_type = JUMP_J;
			jump_addr = instr[25:0];
			we_dmem   = 1'b0;
			we_regfile= 1'b0;  // write register
            lw_flag   = LOAD_ALU_RES;  // not lw instruction
		end
		default: begin // invalid opcode
			imm     = 0;
			ssel    = 0;
			rs1_id  = 0;
			rs2_id  = 0;
			rdst_id = 0;
			op      = OP_NOT_DEFINED;
			
			jump_type = JUMP_ZERO;
			jump_addr = 26'h0;
			we_dmem   = 1'b0;
			we_regfile= 1'b0;
            lw_flag   = LOAD_ALU_RES;
		end
		endcase
	end
endmodule
