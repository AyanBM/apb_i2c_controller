`ifndef HDL_TOP_INCLUDED_
`define HDL_TOP_INCLUDED_

import i3c_globals_pkg::*;
// Description : hdl top has a interface and controller and target agent bfm
module hdl_top;
 bit clk;
 bit rst;

 wire I3C_SCL;
 wire I3C_SDA;

 initial begin
   $display("HDL TOP");
 end

 initial begin
   clk = 1'b0;
   forever #10 clk = ~clk;
 end

 //-------------------------------------------------------
 // System Reset Generation
 // Active low reset
 //-------------------------------------------------------
 initial begin
   rst = 1'b1;

   repeat (2) begin
     @(posedge clk);
   end
   rst = 1'b0;

   repeat (2) begin
     @(posedge clk);
   end
   rst = 1'b1;
 end

 // Variable : intf_controller
 // I3C Interface Instantiation
 i3c_if intf_controller(.pclk(clk),
                    .areset(rst),
                    .SCL(I3C_SCL),
                    .SDA(I3C_SDA));

 // Variable : intf_target
 // I3C Interface Instantiation
 i3c_if intf_target(.pclk(clk),
                   .areset(rst),
                   .SCL(I3C_SCL),
                   .SDA(I3C_SDA));

 // MSHA: // Implementing week0 and week1 concept
 // MSHA: // Logic for Pull-up registers using opne-drain concept
 // MSHA: assign (weak0,weak1) SCL = 1'b1;
 // MSHA: assign (weak0,weak1) SDA = 1'b1;

  // Below table shows different values for each strength .
  //
  // Strength    Value     Value displayed by display tasks
  //   supply       7         Su
  //   strong       6         St
  //   pull         5         Pu
  //   large        4         La
  //   weak         3         We
  //   medium       2         Me
  //   small        1         Sm
  //   highz        0         HiZ

  //  To display strength of a signal %v is used with the signal name
  //  assign (weak1, weak0) io_dq = (direction) ? io : 1'bz;
  //  ex: $display("%v",io_dq);
    
 // Pullup for I3C interface
 pullup p1 (I3C_SCL);
 pullup p2 (I3C_SDA);

 // Variable : controller_agent_bfm_h
 // I3C controller BFM Agent Instantiation 
 //i3c_controller_agent_bfm i3c_controller_agent_bfm_h(intf_controller); 

 // TODO(mshariff): 
 // The interface should have SDA and SCL along with
 // (sda_o, sda_oe and sda_i) 
 // (scl_o, scl_oe and scl_i) 
 // But no clock and reset
 //
 // The clock and reset should be given to the agent_bfm block

 
 // Variable : target_agent_bfm_h
 // I3C target BFM Agent Instantiation
 //i3c_target_agent_bfm i3c_target_agent_bfm_h(intf_target);

 //-------------------------------------------------------
 // APB interface (connects APB master agent BFM to the DUT)
 // preset_n is the same active-low reset used by the I2C interfaces
 //-------------------------------------------------------
 apb_if apb_intf(.pclk(clk), .preset_n(rst));

 // APB master agent BFM (drives the DUT register interface)
 apb_master_agent_bfm apb_master_agent_bfm_h(apb_intf);

`ifdef WITH_DUT
 //-------------------------------------------------------
 // DUT : APB4 I2C master/slave controller
 // DUT has 5-bit PADDR and 8-bit data, the APB VIP bus is wider,
 // so only the low bits are connected and upper PRDATA bits are 0.
 // clk period is 20ns = 50MHz -> PCLK_FREQ_MHZ = 50
 //-------------------------------------------------------
 wire [7:0] dut_prdata;
 apb4_i2c_top #(.PCLK_FREQ_MHZ(50)) dut (
   .PCLK    (clk),
   .PRESETn (rst),
   .PADDR   (apb_intf.paddr[4:0]),
   .PSEL    (apb_intf.pselx[0]),
   .PENABLE (apb_intf.penable),
   .PWRITE  (apb_intf.pwrite),
   .PWDATA  (apb_intf.pwdata[7:0]),
   .PREADY  (apb_intf.pready),
   .PSLVERR (apb_intf.pslverr),
   .PRDATA  (dut_prdata),
   .SCL     (I3C_SCL),
   .SDA     (I3C_SDA)
 );
 assign apb_intf.prdata = {{(apb_global_pkg::DATA_WIDTH-8){1'b0}}, dut_prdata};
`endif

  genvar i;
  generate
    for (i=0; i<NO_OF_CONTROLLERS; i++) begin : i3c_controller_agent_bfm
      i3c_controller_agent_bfm i3c_controller_agent_bfm_h(intf_controller); 
    end
    for (i=0; i<NO_OF_TARGETS; i++) begin : i3c_target_agent_bfm
      i3c_target_agent_bfm i3c_target_agent_bfm_h(intf_target);
    end
  endgenerate

 initial begin
   $dumpfile("i3c_avip.vcd");
   $dumpvars();
 end

endmodule : hdl_top

`endif
