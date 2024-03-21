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
    output reg [4 : 0]      rdst_id // register ID for rd or rt (if used).
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


	reg [5:0]  _opcode, _funct;
	reg [4:0]   _shamt;
	reg [15:0] _imm;
	// wire [25:0] _addr; // no J type instr

	assign _opcode = instr[31:26];

	always@(*) begin
		case(_opcode)
		6'h00: begin // R type instr
			//{ _rs, _rt, _rd, _shamt, _funct } = instr[25:0];

			/**/
			rs1_id    = instr[25:21];
			rs2_id    = instr[20:16];
			rdst_id    = instr[15:11];
			_shamt = instr[10:6];
			_funct = instr[5:0];
			/**/

			imm = 32'h0000_0000; // choose rs2
			ssel = 1'b1;     // 

			case(_funct)
			6'h20: begin // add
				op = OP_ADD;
			end
			6'h22: begin // sub
				op = OP_SUB;	
			end
			6'h24: begin // and
				op = OP_AND;
			end
			6'h25: begin // or
				op = OP_OR;
			end
			6'h27: begin // nor
				op = OP_NOR;
			end
			6'h2a: begin // slt
				op = OP_SLT;
			end
			default:
				op = OP_NOT_DEFINED;
			endcase
		end
		6'h08: begin // I type instr, addi
			//{ _rs, _rt, _imm } = instr[25:0];
			
			rs1_id = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm = { {16{instr[15]}}, instr[15:0] };
			
			ssel   = 1'b0;
			_shamt = 0;
			op = OP_ADD;
			_funct = 0;
		end
		6'h0a: begin // I type instr, slti
			// { _rs, _rt, _imm } = instr[25:0];
			
			rs1_id = instr[25:21];
			rs2_id  = 0;
			rdst_id = instr[20:16];
			imm = { {16{instr[15]}}, instr[15:0] };
			
			ssel   = 1'b0;
			_shamt = 0;
			op = OP_SLT;
			_funct = 0;
		end
		default: begin // invalid opcode
			// {_rs, _rt, _rd, _shamt, _funct } =  0;
			
			_shamt = 0;
			_funct = 0;
			
			imm = 0;
			ssel = 0;
			op = OP_NOT_DEFINED;
			rs1_id  = 0;
			rs2_id  = 0;
			rdst_id = 0;
		end
		endcase
	end
endmodule
