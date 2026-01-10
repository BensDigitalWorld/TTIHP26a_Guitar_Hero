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
  logic hsync;
  logic vsync;
  logic [1:0] R;
  logic [1:0] G;
  logic [1:0] B;
  logic video_active;
  logic [9:0] pix_x;
  logic [9:0] pix_y;
  logic sound;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out[7] = sound;
  assign uio_out[6:0] = 0;
  assign uio_oe[7] = 1;
  assign uio_oe[6:0] = 0;

  // Suppress unused signals warning
  logic _unused_ok = &{ena, ui_in, uio_in};

  logic [9:0] counter;
  
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );
/*
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

*/
  
  logic [9:0] moving_x = pix_x + counter;

  assign R = video_active ? {moving_x[5], pix_y[2]} : 2'b00;
  assign G = video_active ? {moving_x[6], pix_y[2]} : 2'b00;
  assign B = video_active ? {moving_x[7], pix_y[5]} : 2'b00;
  
  always_ff @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end
  
  logic [7:0] bit_sound;


tri_phase_accumulator tri_phase_accumulator1(
    .clk_i(clk),               
    .rst_n(rst_n),             
    .freq_delta_i(tri_freq_delta), 
    .triangle_o(bit_sound) 
 );
 
 pdm_dac pdm_dac1(
  .data_i(bit_sound),
  .clk_i(clk),
  .rst_n(rst_n),
  .data_o(sound)
);

 
  logic [9:0]   hsync_counter_q, hsync_counter_d;
  logic [11:0]  tri_freq_delta;
  logic tick_clk;
  

  always_ff @(posedge hsync or negedge rst_n) begin
    if (~rst_n) begin
      hsync_counter_q <= 0;
    end else begin
      hsync_counter_q <= hsync_counter_d;
    end
  end
  
  always_comb begin
    hsync_counter_d = (hsync_counter_q == 10'd855) ? 0 : hsync_counter_q + 1;
    tick_clk = (hsync_counter_q == 10'd855) ? 1 : 0;
  end

  
  tri_gen trigen1(
    .clk_i(clk),
    .rst_n(rst_n),
    .tick_clk(tick_clk),
    //.start(),
    .tri_delta_phase(tri_freq_delta)
  );


endmodule 

`default_nettype wire