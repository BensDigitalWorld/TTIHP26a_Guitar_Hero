/*
 * Copyright (c) 2025 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_BensDigitalWorld (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  wire sound;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );
  
  wire [9:0] moving_x = pix_x + counter;

  assign R = video_active ? {moving_x[5], pix_y[2]} : 2'b00;
  assign G = video_active ? {moving_x[6], pix_y[2]} : 2'b00;
  assign B = video_active ? {moving_x[7], pix_y[5]} : 2'b00;
  
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end
  
endmodule



/*
 * Copyright (c) 2025 Pat Deegan, https://psychogenic.com
 * SPDX-License-Identifier: Apache-2.0
 * Version: 1.0.1
 *
 * Interfacing code for the Gamepad Pmod from Psycogenic Technologies,
 * designed for Tiny Tapeout.
 *
 * There are two high-level modules that most users will be interested in:
 * - gamepad_pmod_single: for a single controller;
 * - gamepad_pmod_dual: for two controllers.
 * 
 * There are also two lower-level modules that you can use if you want to
 * handle the interfacing yourself:
 * - gamepad_pmod_driver: interfaces with the Pmod and provides the raw data;
 * - gamepad_pmod_decoder: decodes the raw data into button states.
 *
 * The docs, schematics, PCB files, and firmware code for the Gamepad Pmod
 * are available at https://github.com/psychogenic/gamepad-pmod.
 */

/**
 * gamepad_pmod_driver -- Serial interface for the Gamepad Pmod.
 *
 * This module reads raw data from the Gamepad Pmod *serially*
 * and stores it in a shift register. When the latch signal is received, 
 * the data is transferred into `data_reg` for further processing.
 *
 * Functionality:
 *   - Synchronizes the `pmod_data`, `pmod_clk`, and `pmod_latch` signals 
 *     to the system clock domain.
 *   - Captures serial data on each falling edge of `pmod_clk`.
 *   - Transfers the shifted data into `data_reg` when `pmod_latch` goes low.
 *
 * Parameters:
 *   - `BIT_WIDTH`: Defines the width of `data_reg` (default: 24 bits).
 *
 * Inputs:
 *   - `rst_n`: Active-low reset.
 *   - `clk`: System clock.
 *   - `pmod_data`: Serial data input from the Pmod.
 *   - `pmod_clk`: Serial clock from the Pmod.
 *   - `pmod_latch`: Latch signal indicating the end of data transmission.
 *
 * Outputs:
 *   - `data_reg`: Captured parallel data after shifting is complete.
 */
module gamepad_pmod_driver #(
    parameter BIT_WIDTH = 24
) (
    input wire rst_n,
    input wire clk,
    input wire pmod_data,
    input wire pmod_clk,
    input wire pmod_latch,
    output reg [BIT_WIDTH-1:0] data_reg
);

  reg pmod_clk_prev;
  reg pmod_latch_prev;
  reg [BIT_WIDTH-1:0] shift_reg;

  // Sync Pmod signals to the clk domain:
  reg [1:0] pmod_data_sync;
  reg [1:0] pmod_clk_sync;
  reg [1:0] pmod_latch_sync;

  always @(posedge clk) begin
    if (~rst_n) begin
      pmod_data_sync  <= 2'b0;
      pmod_clk_sync   <= 2'b0;
      pmod_latch_sync <= 2'b0;
    end else begin
      pmod_data_sync  <= {pmod_data_sync[0], pmod_data};
      pmod_clk_sync   <= {pmod_clk_sync[0], pmod_clk};
      pmod_latch_sync <= {pmod_latch_sync[0], pmod_latch};
    end
  end

  always @(posedge clk) begin
    if (~rst_n) begin
      /* Initialize data and shift registers to all 1s so they're detected as "not present".
       * This accounts for cases where we have:
       *  - setup for 2 controllers;
       *  - only a single controller is connected; and
       *  - the driver in those cases only sends bits for a single controller.
       */
      data_reg <= {BIT_WIDTH{1'b1}};
      shift_reg <= {BIT_WIDTH{1'b1}};
      pmod_clk_prev <= 1'b0;
      pmod_latch_prev <= 1'b0;
    end else begin
      pmod_clk_prev   <= pmod_clk_sync[1];
      pmod_latch_prev <= pmod_latch_sync[1];

      // Capture data on rising edge of pmod_latch:
      if (pmod_latch_sync[1] & ~pmod_latch_prev) begin
        data_reg <= shift_reg;
      end

      // Sample data on rising edge of pmod_clk:
      if (pmod_clk_sync[1] & ~pmod_clk_prev) begin
        shift_reg <= {shift_reg[BIT_WIDTH-2:0], pmod_data_sync[1]};
      end
    end
  end

endmodule


/**
 * gamepad_pmod_decoder -- Decodes raw data from the Gamepad Pmod.
 *
 * This module takes a 12-bit parallel data register (`data_reg`) 
 * and decodes it into individual button states. It also determines
 * whether a controller is connected.
 *
 * Functionality:
 *   - If `data_reg` contains all `1's` (`0xFFF`), it indicates that no controller is connected.
 *   - Otherwise, it extracts individual button states from `data_reg`.
 *
 * Inputs:
 *   - `data_reg [11:0]`: Captured button state data from the gamepad.
 *
 * Outputs:
 *   - `b, y, select, start, up, down, left, right, a, x, l, r`: Individual button states (`1` = pressed, `0` = released).
 *   - `is_present`: Indicates whether a controller is connected (`1` = connected, `0` = not connected).
 */
module gamepad_pmod_decoder (
    input wire [11:0] data_reg,
    output wire b,
    output wire y,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right,
    output wire a,
    output wire x,
    output wire l,
    output wire r,
    output wire is_present
);

  // When the controller is not connected, the data register will be all 1's
  wire reg_empty = (data_reg == 12'hfff);
  assign is_present = reg_empty ? 0 : 1'b1;
  assign {b, y, select, start, up, down, left, right, a, x, l, r} = reg_empty ? 0 : data_reg;

endmodule


/**
 * gamepad_pmod_single -- Main interface for a single Gamepad Pmod controller.
 * 
 * This module provides button states for a **single controller**, reducing 
 * resource usage (fewer flip-flops) compared to a dual-controller version.
 * 
 * Inputs:
 *   - `pmod_data`, `pmod_clk`, and `pmod_latch` are the signals from the PMOD interface.
 * 
 * Outputs:
 *   - Each button's state is provided as a single-bit wire (e.g., `start`, `up`, etc.).
 *   - `is_present` indicates whether the controller is connected (`1` = connected, `0` = not detected).
 */
module gamepad_pmod_single (
    input wire rst_n,
    input wire clk,
    input wire pmod_data,
    input wire pmod_clk,
    input wire pmod_latch,

    output wire b,
    output wire y,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right,
    output wire a,
    output wire x,
    output wire l,
    output wire r,
    output wire is_present
);

  wire [11:0] gamepad_pmod_data;

  gamepad_pmod_driver #(
      .BIT_WIDTH(12)
  ) driver (
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(pmod_data),
      .pmod_clk(pmod_clk),
      .pmod_latch(pmod_latch),
      .data_reg(gamepad_pmod_data)
  );

  gamepad_pmod_decoder decoder (
      .data_reg(gamepad_pmod_data),
      .b(b),
      .y(y),
      .select(select),
      .start(start),
      .up(up),
      .down(down),
      .left(left),
      .right(right),
      .a(a),
      .x(x),
      .l(l),
      .r(r),
      .is_present(is_present)
  );

endmodule


/**
 * gamepad_pmod_dual -- Main interface for the Pmod gamepad.
 * This module provides button states for two controllers using
 * 2-bit vectors for each button (e.g., start[1:0], up[1:0], etc.).
 * 
 * Each button state is represented as a 2-bit vector:
 *   - Index 0 corresponds to the first controller (e.g., up[0], y[0], etc.).
 *   - Index 1 corresponds to the second controller (e.g., up[1], y[1], etc.).
 *
 * The `is_present` signal indicates whether a controller is connected:
 *   - `is_present[0] == 1` when the first controller is connected.
 *   - `is_present[1] == 1` when the second controller is connected.
 *
 * Inputs:
 *   - `pmod_data`, `pmod_clk`, and `pmod_latch` are the 3 wires coming from the Pmod interface.
 *
 * Outputs:
 *   - Button state vectors for each controller.
 *   - Presence detection via `is_present`.
 */
module gamepad_pmod_dual (
    input wire rst_n,
    input wire clk,
    input wire pmod_data,
    input wire pmod_clk,
    input wire pmod_latch,

    output wire [1:0] b,
    output wire [1:0] y,
    output wire [1:0] select,
    output wire [1:0] start,
    output wire [1:0] up,
    output wire [1:0] down,
    output wire [1:0] left,
    output wire [1:0] right,
    output wire [1:0] a,
    output wire [1:0] x,
    output wire [1:0] l,
    output wire [1:0] r,
    output wire [1:0] is_present
);

  wire [23:0] gamepad_pmod_data;

  gamepad_pmod_driver driver (
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(pmod_data),
      .pmod_clk(pmod_clk),
      .pmod_latch(pmod_latch),
      .data_reg(gamepad_pmod_data)
  );

  gamepad_pmod_decoder decoder1 (
      .data_reg(gamepad_pmod_data[11:0]),
      .b(b[0]),
      .y(y[0]),
      .select(select[0]),
      .start(start[0]),
      .up(up[0]),
      .down(down[0]),
      .left(left[0]),
      .right(right[0]),
      .a(a[0]),
      .x(x[0]),
      .l(l[0]),
      .r(r[0]),
      .is_present(is_present[0])
  );

  gamepad_pmod_decoder decoder2 (
      .data_reg(gamepad_pmod_data[23:12]),
      .b(b[1]),
      .y(y[1]),
      .select(select[1]),
      .start(start[1]),
      .up(up[1]),
      .down(down[1]),
      .left(left[1]),
      .right(right[1]),
      .a(a[1]),
      .x(x[1]),
      .l(l[1]),
      .r(r[1]),
      .is_present(is_present[1])
  );

endmodule


module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);
    input clk;
    input reset;
    output reg hsync, vsync;
    output display_on;
    output reg [9:0] hpos;
    output reg [9:0] vpos;

    // declarations for TV-simulator sync parameters
    // horizontal constants
    parameter H_DISPLAY       = 640; // horizontal display width
    parameter H_BACK          =  48; // horizontal left border (back porch)
    parameter H_FRONT         =  16; // horizontal right border (front porch)
    parameter H_SYNC          =  96; // horizontal sync width
    // vertical constants
    parameter V_DISPLAY       = 480; // vertical display height
    parameter V_TOP           =  33; // vertical top border
    parameter V_BOTTOM        =  10; // vertical bottom border
    parameter V_SYNC          =   2; // vertical sync # lines
    // derived constants
    parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
    parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
    parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
    parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

    wire hmaxxed = (hpos == H_MAX) || reset;  // set when hpos is maximum
    wire vmaxxed = (vpos == V_MAX) || reset;  // set when vpos is maximum
    
    // horizontal position counter
    always @(posedge clk)
    begin
      hsync <= (hpos>=H_SYNC_START && hpos<=H_SYNC_END);
      if(hmaxxed)
        hpos <= 0;
      else
        hpos <= hpos + 1;
    end

    // vertical position counter
    always @(posedge clk)
    begin
      vsync <= (vpos>=V_SYNC_START && vpos<=V_SYNC_END);
      if(hmaxxed)
        if (vmaxxed)
          vpos <= 0;
        else
          vpos <= vpos + 1;
    end
    
    // display_on is set when beam is in "safe" visible frame
    assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);
endmodule