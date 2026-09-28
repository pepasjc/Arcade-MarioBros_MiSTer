//----------------------------------------------------------------------------
//
//  Arcade: Mario Bros by gaz68 (https://github.com/gaz68)
//
//  June 2020
//
//  Based on the original Donkey Kong core by Katsumi Degawa.
//
//  Original Donkey Kong port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//----------------------------------------------------------------------------

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign HDMI_FREEZE = 0;
assign FB_FORCE_BLANK = 0;
assign VGA_DISABLE = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : status[2] ? 12'd2191 : 12'd2560;
assign VIDEO_ARY = status[1] ? 8'd9  : status[2] ? 12'd2560 : 12'd2191;

`include "build_id.v" 
localparam CONF_STR = {
   "RA_MARIO;;",
   "-;",
   "O1,Aspect Ratio,Original,Wide;",
   "O2,Orientation,Horz,Vert;",
   "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
   "ODG,Analogue Sound Vol,100%,Off,10%,20%,30%,40%,50%,60%,70%,80%,90%,;",
   "H1OR,Autosave Hiscores,Off,On;",
   "P1,Pause options;",
   "P1OP,Pause when OSD is open,On,Off;",
   "P1OQ,Dim video after 10s,On,Off;",
   "-;",
   "DIP;",
   //"O89,Lives,3,4,5,6;",
   //"OAB,Coin/Credit,1/1,2/1,1/2,1/3;",
   //"OCD,Extra Life,20000,30000,40000,None;",
   //"OEF,Difficulty,Easy,Medium,Hard,Hardest;",
   "-;",

   "R0,Reset;",
   "J1,Jump,Start 1P,Start 2P,Pause;",
   "jn,A,Start,Select,R,L;",
   "V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;

pll pll
(
   .refclk(CLK_50M),
   .rst(0),
   .outclk_0(clk_sys)  // 48 Mhz
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [10:0] ps2_key;

wire [15:0] joy_0, joy_1;
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
   .clk_sys(clk_sys),
   .HPS_BUS(HPS_BUS),
   .EXT_BUS(),

   .buttons(buttons),
   .status(status),
   .forced_scandoubler(forced_scandoubler),
   .gamma_bus(gamma_bus),
   .direct_video(direct_video),
   .status_menumask({~hs_configured,direct_video}),
	.video_rotated(video_rotated),

   .ioctl_download(ioctl_download),
   .ioctl_upload(ioctl_upload),
   .ioctl_upload_req(ioctl_upload_req),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout),
   .ioctl_din(ioctl_din),
   .ioctl_index(ioctl_index),

   .joystick_0(joy_0),
   .joystick_1(joy_1),
   .ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
   reg old_state;
   old_state <= ps2_key[10];

   if(old_state != ps2_key[10]) begin
      casex(code)
         'hX6B: btn_left        <= pressed; // left
         'hX74: btn_right       <= pressed; // right
         'h029: btn_fire        <= pressed; // space
         'h014: btn_fire        <= pressed; // ctrl

         // JPAC/IPAC/MAME Style Codes

         'h005: btn_one_player  <= pressed; // F1
         'h006: btn_two_players <= pressed; // F2
         'h016: btn_start_1     <= pressed; // 1
         'h01E: btn_start_2     <= pressed; // 2
         'h02E: btn_coin_1      <= pressed; // 5
         'h036: btn_coin_2      <= pressed; // 6
         'h023: btn_left_2      <= pressed; // D
         'h034: btn_right_2     <= pressed; // G
         'h01C: btn_fire_2      <= pressed; // A
         'h02C: btn_test        <= pressed; // T
      endcase
   end
end

reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1 = 0;
reg btn_start_2 = 0;
reg btn_coin_1  = 0;
reg btn_coin_2  = 0;

reg btn_left_2  = 0;
reg btn_right_2 = 0;
reg btn_fire_2  = 0;
reg btn_test    = 0;

wire m_left,m_right;
joy2way joy1
(
   clk_sys,
   {
      btn_left  | joy_0[1],
      btn_right | joy_0[0]
   },
   {m_left,m_right}
);

wire m_left_2,m_right_2;
joy2way joy2
(
   clk_sys,
   {
      btn_left_2  | joy_1[1],
      btn_right_2 | joy_1[0]
   },
   {m_left_2,m_right_2}
);

wire m_fire   = btn_fire | joy_0[4];
wire m_fire_2 = btn_fire_2 | joy_1[4];

wire m_start1 = btn_one_player  | joy_0[5] | joy_1[5];
wire m_start2 = btn_two_players | joy_0[6] | joy_1[6];
wire m_coin   = joy_0[7] | joy_1[7];
wire m_pause   = joy_0[8] | joy_1[8];

// PAUSE SYSTEM
wire				pause_cpu;
wire [7:0]		rgb_out;
pause #(3,3,2,48) pause (
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

//wire [7:0]m_dip = status[15:8];
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

wire [7:0]m_sw1={~btn_test,~{m_start2|btn_start_2},~{m_start1|btn_start_1},~m_fire,1'b1,1'b1,~m_left,~m_right};
wire [7:0]m_sw2={1'b1,1'b1,~{m_coin|btn_coin_1|btn_coin_2},~m_fire_2,1'b1,1'b1,~m_left_2,~m_right_2};

wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [1:0] b;

wire rotate_ccw = 1;
wire no_rotate = ~status[2] | direct_video  ;

wire flip = 0;
wire video_rotated;
// The rotation framebuffer shares the DDR port with the RetroAchievements
// mirror (see below), so its DDRAM outputs go through the RA mux.
wire  [7:0] rot_burstcnt, rot_be;
wire [28:0] rot_addr;
wire [63:0] rot_din;
wire        rot_we, rot_rd;

screen_rotate screen_rotate
(
	.*,
	.DDRAM_CLK(),
	.DDRAM_BURSTCNT(rot_burstcnt),
	.DDRAM_ADDR(rot_addr),
	.DDRAM_DIN(rot_din),
	.DDRAM_BE(rot_be),
	.DDRAM_WE(rot_we),
	.DDRAM_RD(rot_rd)
);

arcade_video#(256,8) arcade_video
(
   .*,

   .clk_video(clk_sys),
   .ce_pix(ce_vid),

   .RGB_in(rgb_out),
   .HBlank(hblank),
   .VBlank(vblank),
   .HSync(~hs),
   .VSync(~vs),

   .fx(status[5:3])
);

assign hblank = hbl[8];

reg  ce_vid;
wire clk_pix;
wire hbl0;
reg [8:0] hbl;
always @(posedge clk_sys) begin
   reg old_pix;
   old_pix <= clk_pix;
   ce_vid <= 0;
   if(~old_pix & clk_pix) begin
      ce_vid <= 1;
      hbl <= (hbl<<1)|hbl0;
   end
end

wire signed [15:0] audio;
assign AUDIO_L   = audio;
assign AUDIO_R   = audio;
assign AUDIO_S   = 1'b1;

wire rom_download = ioctl_download & !ioctl_index;
wire reset = (RESET | status[0] | buttons[1] | rom_download);

// RetroAchievements tap (see RETROACHIEVEMENTS below)
wire [15:0] ra_cpu_a;
wire  [7:0] ra_cpu_do;
wire        ra_cpu_we;

mario_top mariobros
(
   .I_CLK_48M(clk_sys),
   .I_RESETn(~reset),

   .dn_addr(ioctl_addr),
   .dn_data(ioctl_dout),
   .dn_wr(ioctl_wr && rom_download),

   .O_PIX(clk_pix),

   .I_SW1(m_sw1),
   .I_SW2(m_sw2),
   .I_DIPSW(sw[0]),
   //.I_DIPSW(m_dip),
   .I_ANLG_VOL(status[16:13]),

   .O_VGA_R(r),
   .O_VGA_G(g),
   .O_VGA_B(b),
   .O_VGA_HSYNCn(hs),
   .O_VGA_VSYNCn(vs),
   .O_HBLANK(hbl0),
   .O_VBLANK(vblank),

   .O_SOUND_DAT(audio),

   .pause(pause_cpu),

   .hs_address(hs_address),
   .hs_data_out(hs_data_out),
   .hs_data_in(hs_data_in),
   .hs_write(hs_write_enable),
   .hs_access(hs_access_read|hs_access_write),

   .RA_CPU_A(ra_cpu_a),
   .RA_CPU_DO(ra_cpu_do),
   .RA_CPU_WE(ra_cpu_we)
);


// HISCORE SYSTEM
// --------------
wire [15:0]hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write_enable;
wire hs_access_read;
wire hs_access_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write_enable),
	.ram_intent_read(hs_access_read),
	.ram_intent_write(hs_access_write),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

///////////////////   RETROACHIEVEMENTS   //////////////////
//
// RAM mirror for the RetroAchievements fork of Main_MiSTer (mario_ra_mirror.v,
// from jotego's jtframe via the RA jtcores fork). RA arcade sets are written
// against FinalBurn Neo, whose Mario Bros. driver (d_mario.cpp) exposes the
// MemIndex concatenation AllRam..RamEnd as "All Ram":
//     0x0000 DrvZ80RAM  0x1000  Z80 6000-6FFF
//     0x1000 DrvVidRAM  0x0400  Z80 7400-77FF
//     0x1400 DrvSprRAM  0x0400  Z80 7000-73FF
//     0x1800 DrvSndRAM  0x0400  (not mirrored, stays zero)
//     0x1C00 soundlatch, i8039_p[4], i8039_t[4], ... : only i8039_t[0]
//            (0x1C05, the byte the Z80 writes to 7F01, sound CPU T0) is
//            mirrored; the rest stays zero
// The Z80 is 8-bit: shadow byte k is RA address k, so the ARM region table is
// the identity {0, 0x1C1E, 0}. The hiscore system writes RAM 7B (6000-67FF)
// and 7A (6800-6FFF) through their second ports; those writes are mirrored too.
//
// The only other DDR client is the screen rotation framebuffer, which runs on
// CLK_VIDEO (clk_sys), ignores DDRAM_BUSY and writes one pixel per CE_PIXEL
// while VGA_DE is high. So the mirror is clocked by clk_sys too (single clock), and it
// only starts a copy once VGA_DE has been low for 4096 clocks (longer than any
// HBlank): the copy (at most 8k qwords) then runs in VBlank and the
// framebuffer never loses a write. Held off during ROM download.

function automatic [13:0] ra_cpu_map(input [15:0] a);  // {valid, offset}
	if (a == 16'h7F01) ra_cpu_map = { 1'b1, 13'h1C05 };      // i8039_t[0] = data
	else
	casez (a[15:10])
		6'b0110??: ra_cpu_map = { 1'b1, 1'b0, a[11:0] };           // 6000-6FFF
		6'b011100: ra_cpu_map = { 1'b1, 3'b101, a[9:0] };          // 7000-73FF -> 1400
		6'b011101: ra_cpu_map = { 1'b1, 3'b100, a[9:0] };          // 7400-77FF -> 1000
		default:   ra_cpu_map = 0;
	endcase
endfunction

wire [13:0] ra_cpu_m = ra_cpu_map(ra_cpu_a);

// hiscore port B writes: 7B 6000-67FF, 7A 6800-6FFF
wire [13:0] ra_hs_m = hs_address[15:12] == 4'h6 ? { 1'b1, 1'b0, hs_address[11:0] } : 14'd0;

wire [14:0] ra_wr_word;
wire [15:0] ra_wr_din;
wire  [1:0] ra_wr_be;

mario_ra_tap #(.OW(13)) ra_tap
(
	.clk(clk_sys),
	.cpu_we(ra_cpu_we & ra_cpu_m[13]),
	.cpu_off(ra_cpu_m[12:0]),
	.cpu_din(ra_cpu_do),
	.hs_we(hs_write_enable & ra_hs_m[13]),
	.hs_off(ra_hs_m[12:0]),
	.hs_din(hs_data_in),
	.ra_wr_word(ra_wr_word),
	.ra_wr_din(ra_wr_din),
	.ra_wr_be(ra_wr_be)
);

reg [1:0] ra_rst_s, ra_vbl_s, ra_dl_s;
always @(posedge clk_sys) begin
	ra_rst_s <= { ra_rst_s[0], reset };
	ra_vbl_s <= { ra_vbl_s[0], vblank };
	ra_dl_s  <= { ra_dl_s[0],  ioctl_download };
end

reg [11:0] ra_de_idle;
always @(posedge clk_sys) begin
	if (VGA_DE) ra_de_idle <= 0;
	else if (~&ra_de_idle) ra_de_idle <= ra_de_idle + 1'd1;
end

wire  [7:0] ra_burstcnt, ra_be;
wire [28:0] ra_addr;
wire [63:0] ra_din;
wire        ra_we, ra_active;

mario_ra_mirror #(.AW(13)) ra_mirror
(
	.rst(ra_rst_s[1]),
	.clk(clk_sys),
	.lvbl(~ra_vbl_s[1]),
	.hold(ra_dl_s[1]),
	.start_ok(&ra_de_idle),
	.wr_clk(clk_sys),
	.wr_word(ra_wr_word),
	.wr_din(ra_wr_din),
	.wr_be(ra_wr_be),
	.active(ra_active),
	.ddr_busy(DDRAM_BUSY),
	.ddr_burstcnt(ra_burstcnt),
	.ddr_addr(ra_addr),
	.ddr_we(ra_we),
	.ddr_be(ra_be),
	.ddr_din(ra_din)
);

assign DDRAM_CLK      = clk_sys;
assign DDRAM_BURSTCNT = ra_active ? ra_burstcnt : rot_burstcnt;
assign DDRAM_ADDR     = ra_active ? ra_addr     : rot_addr;
assign DDRAM_DIN      = ra_active ? ra_din      : rot_din;
assign DDRAM_BE       = ra_active ? ra_be       : rot_be;
assign DDRAM_WE       = ra_active ? ra_we       : rot_we;
assign DDRAM_RD       = ra_active ? 1'b0        : rot_rd;

endmodule

// Handle the case where Left and Right are pressed simultaneously
// i.e. when using a keyboard.
module joy2way
(
   input        clk,
   input  [1:0] indir,
   output [1:0] outdir
);

reg   [1:0] out = 0;
reg   [1:0] in1,in2;
wire  [1:0] innew = in1 & ~in2;
reg   [1:0] last_h;

assign outdir = out;

always @(posedge clk) begin

   in1 <= indir;
   in2 <= in1;

   if(innew[0]) last_h <= 2'b01; // R
   if(innew[1]) last_h <= 2'b10; // L

   out <= in1 == 2'b11 ? last_h : in1; 
end

endmodule
