/*
 *    Author : Che-Yu Wu @ EISL
 *    Date   : 2022-03-30
 */

module decode #(parameter DWIDTH = 32)
(
    input [DWIDTH-1:0]  instr,   // Input instruction.

    output reg [3 : 0]      op,      // Operation code for the ALU.
    output reg              ssel,    // Select the signal for either the immediate value or rs2.

    output reg [DWIDTH-1:0] imm,     // The immediate value (if used).
    output reg [4 : 0]      rs1_id,  // register ID for rs.
    output reg [4 : 0]      rs2_id,  // register ID for rt (if used).
    output reg [4 : 0]      rdst_id  // register ID for rd or rt (if used).
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

	wire[5:0]  _opcode,_funct;
	wire [4:0]  _shamt;
	
	assign _opcode = instr[31:26];
	assign _funct  = instr[5:0];
	assign _shamt  = instr[10:6];
	
	always@(*) begin
		case(_opcode)
		6'b000000: begin // R type instr
			rs1_id  = instr[25:21];
			rs2_id  = instr[20:16];
			rdst_id = instr[15:11];

			imm     = 32'h0000_0000; // choose rs2
			ssel    = 1'b1;          // 

			case(_funct)
			6'b100000: begin // add
				op = OP_ADD;
			end
			6'b100010: begin // sub
				op = OP_SUB;	
			end
			6'b100100: begin // and
				op = OP_AND;
			end
			6'b100101: begin // or
				op = OP_OR;
			end
			6'b100111: begin // nor
				op = OP_NOR;
			end
			6'b101010: begin // slt
				op = OP_SLT;
			end
			default:
				op = OP_NOT_DEFINED;
			endcase
		end
		6'b001000: begin // I type instr, addi
			rs1_id  = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b0;
			op      = OP_ADD;
		end
		6'b001010: begin // I type instr, slti
			rs1_id  = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm     = { {16{instr[15]}}, instr[15:0] };
			ssel    = 1'b0;
			op      = OP_SLT;
		end
		default: begin // invalid opcode
			imm     = 0;
			ssel    = 0;
			rs1_id  = 0;
			rs2_id  = 0;
			rdst_id = 0;
			op      = OP_NOT_DEFINED;
		end
		endcase
	end
endmodule
