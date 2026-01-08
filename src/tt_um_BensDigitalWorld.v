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
  assign uio_out[7] = sound;
  assign uio_out[6:0] = 0;
  assign uio_oe[7] = 1;
  assign uio_oe[6:0] = 0;

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

  wire gamepad_start, gamepad_up, gamepad_down, gamepad_left, gamepad_right;
  reg gamepad_start_prev;

  gamepad_pmod_single gamepad(
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(ui_in[6]),
      .pmod_clk(ui_in[5]),
      .pmod_latch(ui_in[4]),

      // Outputs:
      .start(gamepad_start),
      .up(gamepad_up),
      .down(gamepad_down),
      .left(gamepad_left),
      .right(gamepad_right)
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



  phase_accumulator tri_low(
    .clk(clk),
    .reset(~rst_n),
    .freq_delta(tri_freq_delta  >> 1),
    .triangle_out(tri_low)
  );

  phase_accumulator tri_mid(
    .clk(clk),
    .reset(~rst_n),
    .freq_delta(tri_freq_delta),
    .triangle_out(tri_mid)
  );

  phase_accumulator tri_high(
    .clk(clk),
    .reset(~rst_n),
    .freq_delta(tri_freq_delta  << 1),
    .triangle_out(tri_high)
  );

  myPWM pwm_audio(
    .clk(clk),
    .reset(~rst_n),
    .sample(eight_bit_tri),
    .pwm(sound)
  );


  assign eight_bit_tri = (tri_mid + tri_high + tri_low) / 3;
  
  reg [9:0]   hsync_cnt = 0;
  
  
  reg [6:0]   tri_tick_cnt = 0;
  reg         tri_dur_index = 0;   
  reg [1:0]   tri_pattern_index = 0;
  reg [5:0]   tri_pattern_cnt = 0;
  reg [2:0]   tri_note_index;
  
  reg [11:0] tri_freq_delta;
  //wire [7:0]  eight_bit_audio;
  wire [7:0]  eight_bit_tri;
  wire [7:0]  tri_low;
  wire [7:0]  tri_mid;
  wire [7:0]  tri_high;
  
  wire [6:0]  tri_dur;
  wire 	      tri_pattern_select; 



  // LUT für die Dauer (Dauer-Werte in 1/16 Ticks)
  assign tri_dur = tri_dur_index ? 7'd56 : 7'd72; // Beispiel: Wechsel zwischen 12 und 4 Ticks
  assign tri_pattern_select = tri_pattern_cnt >> 2  == {2'b0, 4'd9} ? 1 : 0;
  
  always @(posedge hsync) begin
    if (~rst_n) begin
          hsync_cnt <= 0;
          tri_tick_cnt <= 0;
          tri_pattern_index <= 0;
          tri_dur_index <= 0;
          tri_pattern_cnt <= 0;

        
      end else begin
          // 1. HSYNC-Zähler (Zeilen zählen)
          if (hsync_cnt >= 10'd855) begin
              hsync_cnt <= 0;

              // 2. Tick-Zähler (1/16 Noten-Einheiten zählen)
              if (tri_tick_cnt >= tri_dur - 1) begin
                  tri_tick_cnt <= 0;
                  tri_dur_index <= ~tri_dur_index;   
                  tri_pattern_index <= tri_pattern_index + 1;
                  tri_pattern_cnt <=  tri_pattern_cnt == 56-1 ? 0: tri_pattern_cnt + 1; 
              end else begin
                  tri_tick_cnt <= tri_tick_cnt + 1;

              end
            
          end else begin
              hsync_cnt <= hsync_cnt + 1;
          end
      end
  end
  
  //TRI WAVE PATTERN LUT
    always @(*) begin
      if (tri_pattern_select == 1'b0) begin
          // --- PATTERN A ---
          case (tri_pattern_index)
              2'd0: tri_note_index = 3'd2;
              2'd1: tri_note_index = 3'd3;
              2'd2: tri_note_index = 3'd1;
              2'd3: tri_note_index = 3'd4;
              default: tri_note_index = 3'd0;
          endcase
      end else begin
          // --- PATTERN B ---
          case (tri_pattern_index)
              2'd0: tri_note_index = 3'd5;
              2'd1: tri_note_index = 3'd6;
              2'd2: tri_note_index = 3'd1;
              2'd3: tri_note_index = 3'd4;
              default: tri_note_index = 3'd0;
          endcase
      end
  end
  
  //TRI WAVE PHASE LUT, Values are gotten by freq_delta = freq_of_Note * 2^24 / (25175000)
  always @(*) begin
    case (tri_note_index)
        3'd0: tri_freq_delta = 12'd0;    // Stille / Pause
        3'd1: tri_freq_delta = 12'd870;   // MIDI 36
        3'd2: tri_freq_delta = 12'd920;   // MIDI 37
        3'd3: tri_freq_delta = 12'd1040;  // MIDI 39
        3'd4: tri_freq_delta = 12'd1160;  // MIDI 41
        3'd5: tri_freq_delta = 12'd1380;  // MIDI 44
        3'd6: tri_freq_delta = 12'd2070;  // MIDI 51
        default: tri_freq_delta = 12'd0;
    endcase
  end 
endmodule




module phase_accumulator (
    input wire clk,               // Systemtakt (z.B. 25,175 MHz)
    input wire reset,             // Globaler Reset
    input wire [11:0] freq_delta, // Der Wert aus deiner LUT
    output wire [7:0] triangle_out // Das fertige 8-Bit Audio-Signal
);
    reg [23:0] phase_acc;
    // Triangle-Logik: Wir nutzen das Bit 23 als Richtungsanzeiger
    wire top_bit = phase_acc[23];
    //assign triangle_out = {8{top_bit}};
    assign triangle_out = phase_acc[23] ? ~phase_acc[22:15] : phase_acc[22:15];
    always @(posedge clk) begin
        if (reset) begin
            phase_acc <= 24'd0;
        end else begin
            // Prüfen, ob eine neue Note beginnt (freq_delta hat sich geändert)
                // Normales Aufsummieren
          phase_acc <= phase_acc + {12'b0, freq_delta};
        end
    end
endmodule




module myPWM(
  input clk,
  input [7:0] sample,
  input wire reset,             
  output pwm
);
  reg [7:0] audio_pwm_accum;
  wire [8:0] audio_pwm_accum_next = audio_pwm_accum + sample;
  assign pwm = audio_pwm_accum_next[8];
  always @(posedge clk) begin
    if (reset) begin
            audio_pwm_accum <= 8'd0;
        end else begin
            audio_pwm_accum <= audio_pwm_accum_next[7:0];
        end
  end
endmodule
