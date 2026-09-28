//============================================================================
//  Mario Bros. for MiSTer FPGA - RetroAchievements RAM tap
//
//  Turns the CPU writes (and the hiscore system's writes) to the RAMs that
//  RetroAchievements reads into the single write port of mario_ra_mirror.
//  The core computes the FinalBurn Neo "All Ram" byte offset of each write
//  (see the RETROACHIEVEMENTS section of the top level); this module only
//  arbitrates between the two sources.
//
//  The CPU signals go through two register stages first: on some of these
//  cores the CPU runs on a derived clock (or clock enable) of clk, and a Z80
//  write keeps its address and data stable for several clocks around WR_n,
//  so the delayed copies are always a consistent sample.
//
//  Each source has a one-deep latch, so a write that collides with the other
//  source is written a clock later. The CPU strobe is a level held for the
//  whole bus write cycle (several clocks) and the latch keeps the last value,
//  which is the one the RAM keeps. The hiscore strobe has priority.
//
//  Adapted from galaxian_ra_tap.sv (RetroAchievements port of the Galaxian
//  MiSTer core).
//
//  SPDX-License-Identifier: GPL-3.0-or-later
//============================================================================

module mario_ra_tap #(parameter OW = 16) (
    input             clk,

    input             cpu_we,     // level: CPU write to a mirrored RAM
    input    [OW-1:0] cpu_off,    // its FBNeo "All Ram" offset
    input      [ 7:0] cpu_din,

    input             hs_we,      // hiscore write to a mirrored RAM
    input    [OW-1:0] hs_off,
    input      [ 7:0] hs_din,

    // mirror write port
    output reg [14:0] ra_wr_word,
    output reg [15:0] ra_wr_din,
    output reg [ 1:0] ra_wr_be
);

// first stage: cpu_*_s0 (the target of any cross-clock SDC constraint)
reg           cpu_we_s0,  cpu_we_s1;
reg  [OW-1:0] cpu_off_s0, cpu_off_s1;
reg  [ 7:0]   cpu_din_s0, cpu_din_s1;
always_ff @(posedge clk) begin
    cpu_we_s0  <= cpu_we;   cpu_we_s1  <= cpu_we_s0;
    cpu_off_s0 <= cpu_off;  cpu_off_s1 <= cpu_off_s0;
    cpu_din_s0 <= cpu_din;  cpu_din_s1 <= cpu_din_s0;
end

localparam N = 2;
wire [N-1:0] req = { cpu_we_s1, hs_we };
wire [15:0]  r_addr[0:N-1];
wire [ 7:0]  r_din[0:N-1];

// Order is the output priority
wire [15:0] hs_off16  = hs_off;   // zero-extended
wire [15:0] cpu_off16 = cpu_off_s1;
assign r_addr[0] = hs_off16;
assign r_din[0]  = hs_din;
assign r_addr[1] = cpu_off16;
assign r_din[1]  = cpu_din_s1;

reg  [N-1:0] pend;
reg  [15:0]  p_addr[0:N-1];
reg  [ 7:0]  p_din[0:N-1];

// first pending latch
reg [N-1:0] grant;
always_comb begin
    grant = 0;
    for (int i = N-1; i >= 0; i--) if (pend[i]) begin grant = 0; grant[i] = 1'b1; end
end

always_ff @(posedge clk) begin
    ra_wr_be <= 2'b00;
    for (int i = 0; i < N; i++) begin
        if (grant[i]) begin
            ra_wr_word <= p_addr[i][15:1];
            ra_wr_din  <= { 2{p_din[i]} };
            ra_wr_be   <= p_addr[i][0] ? 2'b10 : 2'b01;
            pend[i]    <= 0;
        end
        // a new (or still held) strobe re-arms the latch with current values
        if (req[i]) begin
            pend[i]   <= 1;
            p_addr[i] <= r_addr[i];
            p_din[i]  <= r_din[i];
        end
    end
end

initial pend = 0;

endmodule
