``
proc conditioner_crc32d8_module { name WIDTH NSRC SRC_WIDTH OVERSAMPLING {entsrc sbentsrc} } {

	set SAMPLED_WIDTH [expr $NSRC*$SRC_WIDTH]
	#/* synthesis syn_hier = "hard" */
``
module `$name` (
	input wire i_reset,
	input wire i_clk,
	input wire i_read,
	output reg [`$WIDTH`-1:0] o_dat,
	output reg o_valid,
	output wire [`$SAMPLED_WIDTH`-1:0] o_sampled
) /* synthesis syn_hier = "hard" */ ;

// polynomial: (0 1 2 8)
// data width: 32
// convention: the first serial bit is D[31]
function [7:0] nextCRC8_D32;
	input [31:0] Data;
	input [7:0] crc;
	reg [31:0] d;
	reg [7:0] c;
	reg [7:0] newcrc;
	begin
		d = Data;
		c = crc;

		newcrc[0] = d[31] ^ d[30] ^ d[28] ^ d[23] ^ d[21] ^ d[19] ^ d[18] ^ d[16] ^ d[14] ^ d[12] ^ d[8] ^ d[7] ^ d[6] ^ d[0] ^ c[4] ^ c[6] ^ c[7];
		newcrc[1] = d[30] ^ d[29] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[18] ^ d[17] ^ d[16] ^ d[15] ^ d[14] ^ d[13] ^ d[12] ^ d[9] ^ d[6] ^ d[1] ^ d[0] ^ c[0] ^ c[4] ^ c[5] ^ c[6];
		newcrc[2] = d[29] ^ d[28] ^ d[25] ^ d[24] ^ d[22] ^ d[17] ^ d[15] ^ d[13] ^ d[12] ^ d[10] ^ d[8] ^ d[6] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[4] ^ c[5];
		newcrc[3] = d[30] ^ d[29] ^ d[26] ^ d[25] ^ d[23] ^ d[18] ^ d[16] ^ d[14] ^ d[13] ^ d[11] ^ d[9] ^ d[7] ^ d[3] ^ d[2] ^ d[1] ^ c[1] ^ c[2] ^ c[5] ^ c[6];
		newcrc[4] = d[31] ^ d[30] ^ d[27] ^ d[26] ^ d[24] ^ d[19] ^ d[17] ^ d[15] ^ d[14] ^ d[12] ^ d[10] ^ d[8] ^ d[4] ^ d[3] ^ d[2] ^ c[0] ^ c[2] ^ c[3] ^ c[6] ^ c[7];
		newcrc[5] = d[31] ^ d[28] ^ d[27] ^ d[25] ^ d[20] ^ d[18] ^ d[16] ^ d[15] ^ d[13] ^ d[11] ^ d[9] ^ d[5] ^ d[4] ^ d[3] ^ c[1] ^ c[3] ^ c[4] ^ c[7];
		newcrc[6] = d[29] ^ d[28] ^ d[26] ^ d[21] ^ d[19] ^ d[17] ^ d[16] ^ d[14] ^ d[12] ^ d[10] ^ d[6] ^ d[5] ^ d[4] ^ c[2] ^ c[4] ^ c[5];
		newcrc[7] = d[30] ^ d[29] ^ d[27] ^ d[22] ^ d[20] ^ d[18] ^ d[17] ^ d[15] ^ d[13] ^ d[11] ^ d[7] ^ d[6] ^ d[5] ^ c[3] ^ c[5] ^ c[6];
		nextCRC8_D32 = newcrc;
	end
endfunction

``
set NCRC [expr ($SAMPLED_WIDTH+31)/32]
set CRC_STATE_WIDTH [expr $NCRC*8]
``
localparam NCRC = `$NCRC`;
localparam CRC_STATE_WIDTH = `$CRC_STATE_WIDTH`;
localparam WIDTH = `$WIDTH`;
reg [CRC_STATE_WIDTH-1:0] crc_state;
wire [CRC_STATE_WIDTH-1:0] crc_input = i_read & o_valid ? {CRC_STATE_WIDTH{1'b0}} : crc_state;//start a new output byte, keep them independent
``if {$NCRC==1} {``
wire [CRC_STATE_WIDTH-1:0] crc_sampled = nextCRC8_D32(o_sampled,crc_input);
always @(*) o_dat = crc_state;
``} else {``
reg [CRC_STATE_WIDTH-1:0] crc_sampled;
always @(*) begin: CRC_SAMPLED_BLOCK
``for {set i 0} {$i<$NCRC} {incr i} {``
	crc_sampled[`$i`*8+:8] = nextCRC8_D32(o_sampled[`$i`*8+:8],crc_input[`$i`*8+:8]);
``}``
end
always @(*) begin: O_DAT_BLOCK
	o_dat={WIDTH{1'b0}};
``for {set i 0} {$i<$NCRC} {incr i} {``
	o_dat = o_dat ^ crc_state[`$i`*8+:8];//TODO: compute a CRC rather than simple xor
``}``
end
``}``
localparam SRC_WIDTH = `$SRC_WIDTH`;
localparam SAMPLED_WIDTH = `$SAMPLED_WIDTH`;
localparam TARGET_CNT = `$OVERSAMPLING` * WIDTH /8;
``for {set i 0} {$i<$NSRC} {incr i} {``
`$entsrc` #(.RNG_WIDTH(SRC_WIDTH)) u`$i`_rnd_src (.i_reset(i_reset), .i_clk(i_clk), .i_en(1'b1), .o_rnd(o_sampled[`$i`*SRC_WIDTH+:SRC_WIDTH]));
``}``
localparam CNT_WIDTH = 4;
reg [CNT_WIDTH-1:0] cnt;
reg [CNT_WIDTH-1:0] cnt2;	
always @(posedge i_clk) begin
	if(i_reset) begin
		cnt <= {CNT_WIDTH{1'b0}};
		cnt2 <= {CNT_WIDTH{1'b0}};
		crc_state <= {CRC_STATE_WIDTH{1'b0}};
	end else begin
		if(i_read & o_valid) begin
			cnt <= {CNT_WIDTH{1'b0}};
			cnt2 <= {CNT_WIDTH{1'b0}};
			crc_state <= crc_sampled;
		end else begin
			crc_state <= crc_sampled;
			if(~o_valid) begin
				cnt <= cnt + 1'b1;
				if(cnt=={CNT_WIDTH{1'b1}}) cnt2 <= cnt2 + 1'b1;
			end
		end
	end
end
always @* o_valid = {cnt2,cnt}==TARGET_CNT;
endmodule
``
	return [::tgpp::getProcOutput]
}
