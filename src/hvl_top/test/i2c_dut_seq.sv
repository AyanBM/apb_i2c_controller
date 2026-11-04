`ifndef I2C_DUT_SEQ_INCLUDED_
`define I2C_DUT_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Sequences used by the DUT tests.
//   dut_apb_raw_seq   : one APB access with exactly the paddr/pwdata given (no randomize, so
//                       apb_master_tx.post_randomize cannot move the address). Used where the
//                       RAL cannot be used (reads of WO registers, writes to RO registers).
//   dut_target_resp_seq : runs on the target sequencer. Answers every transfer the DUT (master)
//                       starts (ACK the address, return rdata[] on a read).
//   dut_ctrl_seq      : runs on the controller sequencer. One transfer towards the DUT (slave).
//--------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------
// dut_apb_raw_seq
//--------------------------------------------------------------------------------------------
class dut_apb_raw_seq extends uvm_sequence #(apb_master_tx);
  `uvm_object_utils(dut_apb_raw_seq)

  bit [apb_global_pkg::ADDRESS_WIDTH-1:0] addr;
  bit                     is_write;
  bit [DATA_WIDTH-1:0]    wdata;

  // results
  bit [DATA_WIDTH-1:0]    rdata;
  bit                     slverr;

  function new(string name = "dut_apb_raw_seq");
    super.new(name);
  endfunction : new

  task body();
    req = apb_master_tx::type_id::create("req");
    start_item(req);
    req.paddr  = addr;
    req.pselx  = apb_global_pkg::SLAVE_0;
    req.pwrite = is_write ? apb_global_pkg::WRITE : apb_global_pkg::READ;
    req.pwdata = wdata;
    req.pstrb  = 4'b1111;
    finish_item(req);
    rdata  = req.prdata;
    slverr = req.pslverr;
  endtask : body
endclass : dut_apb_raw_seq


//--------------------------------------------------------------------------------------------
// dut_target_resp_seq
//   rdata[]  : bytes returned when the DUT (master) reads.
// What the target BFM actually saw is NOT visible here (the driver proxy hands the converted
// packet back through an output argument, so this item is not updated). Tests read it from
// the target monitor analysis port instead.
//--------------------------------------------------------------------------------------------
class dut_target_resp_seq extends uvm_sequence #(i3c_target_tx);
  `uvm_object_utils(dut_target_resp_seq)

  bit [DATA_WIDTH-1:0] rdata[$];

  function new(string name = "dut_target_resp_seq");
    super.new(name);
  endfunction : new

  task body();
    forever begin
      req = i3c_target_tx::type_id::create("req");
      start_item(req);
      if(!req.randomize() with {
            targetAddressStatus == ACK;
            readData.size() == rdata.size();
            foreach(readData[i]) readData[i] == rdata[i];
         }) begin
        `uvm_error(get_type_name(), "Randomization failed")
      end
      finish_item(req);
    end
  endtask : body
endclass : dut_target_resp_seq


//--------------------------------------------------------------------------------------------
// dut_ctrl_seq : one I2C transfer from the controller BFM towards the DUT
//   (results come from the controller monitor, see dut_base_test)
//--------------------------------------------------------------------------------------------
class dut_ctrl_seq extends uvm_sequence #(i3c_controller_tx);
  `uvm_object_utils(dut_ctrl_seq)

  operationType_e                       op;
  bit [I2C_MAX_ADDRESS_WIDTH-1:0]       addr;
  i2c_address_mode_e                    mode = I2C_ADDR_7BIT;
  bit [DATA_WIDTH-1:0]                  wdata[$];   // for WRITE
  int                                   nread = 1;  // for READ

  function new(string name = "dut_ctrl_seq");
    super.new(name);
  endfunction : new

  task body();
    req = i3c_controller_tx::type_id::create("req");
    start_item(req);
    if(op == WRITE) begin
      if(!req.randomize() with {
            operation     == WRITE;
            targetAddress == addr;
            addressMode   == mode;
            writeData.size() == wdata.size();
            foreach(writeData[i]) writeData[i] == wdata[i];
         }) `uvm_error(get_type_name(), "Randomization failed")
    end
    else begin
      if(!req.randomize() with {
            operation     == READ;
            targetAddress == addr;
            addressMode   == mode;
            readDataStatus.size() == nread;
            foreach(readDataStatus[i]) readDataStatus[i] == ((i == nread-1) ? NACK : ACK);
         }) `uvm_error(get_type_name(), "Randomization failed")
    end
    finish_item(req);
  endtask : body
endclass : dut_ctrl_seq

`endif

