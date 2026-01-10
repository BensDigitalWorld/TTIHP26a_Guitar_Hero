`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 19:46:01
// Design Name: 
// Module Name: tri_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tri_gen(
  input wire logic clk_i,
  input wire logic rst_n,
  input wire logic tick_clk,
  //input logic start,
  
  output logic [11:0] tri_delta_phase
  );
  
  logic [5:0] pattern_pos_q, pattern_pos_d;
  logic [6:0] tick_counter_q, tick_counter_d;
  
  //REGISTERS
  always_ff @(posedge tick_clk or negedge rst_n) begin
    if (~rst_n) begin
      pattern_pos_q <= 0;
      tick_counter_q <= 0;
    end else begin
      pattern_pos_q <= pattern_pos_d;
      tick_counter_q <= tick_counter_d;
    end
  end
  
  
  //NEXT STATE LOGIC
  always_comb begin
    //defaults
    tick_counter_d = tick_counter_q;
    pattern_pos_d = pattern_pos_q;
    
    tick_counter_d = pattern_pos_q[0]? (tick_counter_q == 7'd72 ? 0 : tick_counter_q + 1) : 
                                       (tick_counter_q == 7'd56 ? 0 : tick_counter_q + 1);
                                       
    pattern_pos_d = pattern_pos_q[0]? (tick_counter_q == 7'd72 ? pattern_pos_q + 1 : pattern_pos_q) : 
                                      (tick_counter_q == 7'd56 ? pattern_pos_q + 1 : pattern_pos_q);    
  end
  
  //OUTPUT LOGIC
  always_comb begin
    if ((pattern_pos_q == 7'd36) || (pattern_pos_q == 7'd37)) begin
      case (pattern_pos_q[1:0])
        2'd0: tri_delta_phase = 12'd138;
        2'd1: tri_delta_phase = 12'd207;
        default: tri_delta_phase = 12'd0;
      endcase
    end else begin
      case (pattern_pos_q[1:0])
        2'd0: tri_delta_phase = 12'd92;
        2'd1: tri_delta_phase = 12'd104;
        2'd2: tri_delta_phase = 12'd36;
        2'd3: tri_delta_phase = 12'd116;
        default: tri_delta_phase = 12'd0;
      endcase
    end
  end
endmodule
