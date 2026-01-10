module tri_phase_accumulator(
    input wire logic clk_i,               
    input wire logic rst_n,             
    input wire logic [11:0] freq_delta_i, 

    output logic [7:0] triangle_o 
);
    //LOGIC NEEDED
    logic [24:0] phase_acc, phase_acc_prev;
    logic [7:0] tri_low, tri_mid, tri_high;    
    logic [9:0] tri_sum;

    //COMBINATIONAL LOGIC
    always_comb begin
      tri_mid  = phase_acc[23] ? ~phase_acc[22:15] : phase_acc[22:15];
      tri_high = phase_acc[22] ? ~phase_acc[21:14] : phase_acc[21:14];
      tri_low  = phase_acc[24] ? ~phase_acc[23:16] : phase_acc[23:16];

      tri_sum = {2'b0, tri_mid} + {2'b0, tri_high} + {2'b0, tri_low};
      
      phase_acc_prev = phase_acc +{13'b0, freq_delta_i};
    end

    //SEQ LOGIC
    always_ff @(posedge clk_i) begin
        if (~rst_n) begin
            phase_acc <= 25'd0;
        end else begin
          phase_acc <= phase_acc_prev;
        end
    end

    //OUTPUT
    assign triangle_o = tri_sum[9:2];
endmodule
