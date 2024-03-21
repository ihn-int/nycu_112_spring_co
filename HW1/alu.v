module alu #(parameter DWIDTH = 32)
(
	input [3 : 0] op,
	input [DWIDTH-1 : 0] rs1,
	input [DWIDTH-1 : 0] rs2,

	output [DWIDTH-1 : 0] rd,
	output zero,
	output overflow
);

wire [2:0] _overflow;
assign _overflow = { rs1[DWIDTH-1], rs2[DWIDTH-1], rd[DWIDTH-1] };
reg [DWIDTH-1 : 0] trd;
assign rd = trd;
reg _invalid;

always@(*) begin
	case(op)
		4'b0000: begin // and 0
			trd = rs1 & rs2;
			_invalid = 1'b1;
		end
		4'b0001: begin // or 1
			trd = rs1 | rs2;
			_invalid = 1'b1;
		end
		4'b0010: begin // add 2
			trd = rs1 + rs2;
			_invalid = 1'b1;
		end
		4'b0110: begin // sub 6
			trd = rs1 - rs2;
			_invalid = 1'b1;
		end
		4'b1100: begin // nor C
			trd = ~(rs1 | rs2);
			_invalid = 1'b1;
		end
		4'b0111: begin // slt 7
			case(_overflow[2:1]):
				2'b00: trd <= (rs1 < rs2) ? 32'b1 : 32'b0;
				2'b11: trd <= (rs1 < rs2) ? 32'b1 : 32'b0;
				2'b01: trd <= 32'b1;
				2'b10: trd <= 32'b0;
				default: trd <= 32'b0;
			endcase
			_invalid = 1'b1;
		end
		default: begin // invalid op code
			trd = 32'h0;
			_invalid = 1'b0;
		end
	endcase
end

assign zero =
	(_invalid && |(rd) == 0);
assign overflow = 
	(op == 4'b0010 && _overflow == 3'b001) || 
	(op == 4'b0010 && _overflow == 3'b110) ||
	(op == 4'b0110 && _overflow == 3'b011) ||
	(op == 4'b0110 && _overflow == 3'b100);

endmodule
