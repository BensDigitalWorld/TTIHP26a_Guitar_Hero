module pdm_dac(
  input wire logic [7:0] data_i,
  input wire logic clk_i,
  input wire logic rst_n,

  output logic data_o
);
  //LOGIC NEEDED
  logic [8:0] accumulator;

  //SEQ LOGIC
  always_ff @(posedge clk_i) begin
    if(~rst_n) begin
      accumulator <= 0;
    end else begin
      accumulator <= (accumulator[7:0] + data_i);
    end
  end

  //OUTPUT
  assign data_o = accumulator[8];
endmodule
