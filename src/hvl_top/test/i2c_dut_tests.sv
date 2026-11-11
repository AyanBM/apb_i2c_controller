`ifndef I2C_DUT_TESTS_INCLUDED_
`define I2C_DUT_TESTS_INCLUDED_

//--------------------------------------------------------------------------------------------
// DUT tests for apb4_i2c_top.  The APB master agent + RAL configure the DUT, the I2C VIP is
// the other side of the bus:
//   DUT = master : the target agent answers (ACK + read data), target monitor shows what the
//                  DUT put on the bus.
//   DUT = slave  : the controller agent drives the transfer, controller monitor shows the result.
// The old VIP scoreboard is disabled (it compares controller vs target, not DUT vs VIP).
//--------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------
// dut_base_test : helpers shared by all DUT tests
//--------------------------------------------------------------------------------------------
class dut_base_test extends i3c_base_test;
  `uvm_component_utils(dut_base_test)

  // addresses used by the tests
  localparam bit [I2C_MAX_ADDRESS_WIDTH-1:0] TGT7   = 10'h068;  // VIP target address (DUT master)
  localparam bit [I2C_MAX_ADDRESS_WIDTH-1:0] SELF7  = 10'h055;  // DUT own address     (DUT slave)
  localparam bit [I2C_MAX_ADDRESS_WIDTH-1:0] TGT10  = 10'h2A5;
  localparam bit [I2C_MAX_ADDRESS_WIDTH-1:0] SELF10 = 10'h1B3;
  localparam bit [I2C_MAX_ADDRESS_WIDTH-1:0] WRONG7 = 10'h011;  // nobody answers here

  localparam bit [7:0] RD_BYTE = 8'h3C;   // byte a DUT master reads from the VIP target

  // IRQ_STATUS bits
  localparam int IRQ_SCL_HUNG = 2, IRQ_NACK = 4, IRQ_ILLEGAL = 5, IRQ_RX_EMPTY = 7;

  i2c_reg_block rm;
  uvm_tlm_analysis_fifo #(i3c_target_tx)     tgt_mon_fifo;
  uvm_tlm_analysis_fifo #(i3c_controller_tx) ctrl_mon_fifo;
  dut_target_resp_seq tgt_resp_seq_h;

  int unsigned err_cnt;

  extern function new(string name = "dut_base_test", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual function void setup_env_cfg();
  extern virtual function void setup_controller_agent_cfg();
  extern virtual function void setup_target_agent_cfg();
  extern virtual task run_phase(uvm_phase phase);
  extern virtual task test_body();

  // APB / RAL helpers
  extern task wr(uvm_reg r, bit [7:0] v, bit chk = 1);
  extern task rd(uvm_reg r, output bit [7:0] v, input bit chk = 1);
  extern task raw_apb(bit [apb_global_pkg::ADDRESS_WIDTH-1:0] a, bit is_wr, bit [7:0] d, output bit [7:0] q, output bit err);
  extern task config_dut(bit master, bit [1:0] spd, bit a10,
                         bit [I2C_MAX_ADDRESS_WIDTH-1:0] tgt,
                         bit [I2C_MAX_ADDRESS_WIDTH-1:0] self);
  extern task push_tx(bit [7:0] d);
  extern task push_rx();
  extern task read_irq(output bit [7:0] v);
  extern task clear_irq(bit [3:0] mask);
  extern task wait_rx_count(int n, int timeout_us = 3000);

  // VIP helpers
  extern task start_target_responder(bit [DATA_WIDTH-1:0] rdata[$]);
  extern task get_target_tx(output i3c_target_tx t, input int timeout_us = 3000);
  extern task get_ctrl_tx(output i3c_controller_tx t, input int timeout_us = 3000);
  extern task send_to_dut(operationType_e op, bit [I2C_MAX_ADDRESS_WIDTH-1:0] a,
                          i2c_address_mode_e mode, bit [DATA_WIDTH-1:0] wdata[$], int nread = 1);

  // checking
  extern function void check_eq(string what, longint unsigned got, longint unsigned exp);
endclass : dut_base_test


function dut_base_test::new(string name = "dut_base_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void dut_base_test::build_phase(uvm_phase phase);
  super.build_phase(phase);
  tgt_mon_fifo  = new("tgt_mon_fifo", this);
  ctrl_mon_fifo = new("ctrl_mon_fifo", this);
endfunction : build_phase

function void dut_base_test::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  rm = i3c_env_h.reg_model;
  i3c_env_h.i3c_target_agent_h[0].i3c_target_mon_proxy_h.target_analysis_port.connect(tgt_mon_fifo.analysis_export);
  i3c_env_h.i3c_controller_agent_h[0].i3c_controller_mon_proxy_h.controller_analysis_port.connect(ctrl_mon_fifo.analysis_export);
endfunction : connect_phase

function void dut_base_test::setup_env_cfg();
  super.setup_env_cfg();
  i3c_env_cfg_h.has_scoreboard     = 0;   // VIP-to-VIP scoreboard does not apply to DUT tests
  i3c_env_cfg_h.has_dut_scoreboard = 1;   // DUT-aware scoreboard (APB intent vs I2C bus)
endfunction : setup_env_cfg

// The controller BFM needs a real SCL for the DUT (2FF synchronizer + glitch filter):
// 1 phase = clockRateDividerValue pclk cycles (see tick() in the controller driver BFM)
function void dut_base_test::setup_controller_agent_cfg();
  super.setup_controller_agent_cfg();
  foreach(i3c_env_cfg_h.i3c_controller_agent_cfg_h[i])
    i3c_env_cfg_h.i3c_controller_agent_cfg_h[i].set_clockrate_divider_value(.primary_prescalar(5),
                                                                          .secondary_prescalar(0));
endfunction : setup_controller_agent_cfg

function void dut_base_test::setup_target_agent_cfg();
  super.setup_target_agent_cfg();
  foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i]) begin
    i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress = TGT7;
    i3c_env_cfg_h.i3c_target_agent_cfg_h[i].addressMode   = I2C_ADDR_7BIT;
    // The target BFM does NOT use the readData of the sequence item: on a read it sends the bytes
    // written earlier to it (targetFIFOMemory) or else cfg.defaultReadData. So the byte the DUT
    // reads is set here.
    i3c_env_cfg_h.i3c_target_agent_cfg_h[i].defaultReadData = RD_BYTE;
  end
endfunction : setup_target_agent_cfg

task dut_base_test::run_phase(uvm_phase phase);
  phase.raise_objection(this, get_type_name());
  #(20 * 1us) ;               // reset + settle
  test_body();
  #(20 * 1us);                // let the monitors publish the last transfer to the scoreboard
  if(i3c_env_h.dut_scoreboard_h != null) err_cnt += i3c_env_h.dut_scoreboard_h.err_cnt;
  if(err_cnt == 0) `uvm_info(get_type_name(), "DUT TEST RESULT : PASS", UVM_NONE)
  else             `uvm_error(get_type_name(), $sformatf("DUT TEST RESULT : FAIL (%0d checks failed)", err_cnt))
  phase.drop_objection(this, get_type_name());
endtask : run_phase

task dut_base_test::test_body();
  `uvm_info(get_type_name(), "empty test_body", UVM_NONE)
endtask : test_body

//--------------------------------------------------------------------------------------------
// APB / RAL helpers
//--------------------------------------------------------------------------------------------
task dut_base_test::wr(uvm_reg r, bit [7:0] v, bit chk = 1);
  uvm_status_e st;
  r.write(st, v);
  if(chk && st != UVM_IS_OK) begin
    err_cnt++;
    `uvm_error(get_type_name(), $sformatf("write of %s returned status %s", r.get_name(), st.name()))
  end
endtask : wr

task dut_base_test::rd(uvm_reg r, output bit [7:0] v, input bit chk = 1);
  uvm_status_e st;
  uvm_reg_data_t d;
  r.read(st, d);
  v = d[7:0];
  if(chk && st != UVM_IS_OK) begin
    err_cnt++;
    `uvm_error(get_type_name(), $sformatf("read of %s returned status %s", r.get_name(), st.name()))
  end
endtask : rd

// one APB access without the RAL: used for the illegal accesses the RAL does not allow
task dut_base_test::raw_apb(bit [apb_global_pkg::ADDRESS_WIDTH-1:0] a, bit is_wr, bit [7:0] d, output bit [7:0] q, output bit err);
  dut_apb_raw_seq s = dut_apb_raw_seq::type_id::create("raw_apb_seq");
  s.addr = a; s.is_write = is_wr; s.wdata = d;
  s.start(i3c_env_h.apb_master_agent_h.apb_master_seqr_h);
  q   = s.rdata[7:0];
  err = s.slverr;
endtask : raw_apb

// MODE = {role(1=master), speed[1:0], addr10}; the mode write goes last (config is applied in core IDLE)
task dut_base_test::config_dut(bit master, bit [1:0] spd, bit a10,
                               bit [I2C_MAX_ADDRESS_WIDTH-1:0] tgt,
                               bit [I2C_MAX_ADDRESS_WIDTH-1:0] self);
  wr(rm.slv_addrh,      {6'b0, tgt[9:8]});
  wr(rm.slv_addrl,      tgt[7:0]);
  wr(rm.slv_self_addrh, {6'b0, self[9:8]});
  wr(rm.slv_self_addrl, self[7:0]);
  wr(rm.mode_reg,       {4'b0, master, spd, a10});
endtask : config_dut

task dut_base_test::push_tx(bit [7:0] d);
  wr(rm.tx_data_reg, d);
endtask : push_tx

// one read command (master: read one byte; slave: be ready to receive one byte)
task dut_base_test::push_rx();
  wr(rm.rx_data_reg, 8'h01);
endtask : push_rx

task dut_base_test::read_irq(output bit [7:0] v);
  rd(rm.irq_status_reg, v, 0);    // PSLVERR is high while an IRQ is pending, so no status check
endtask : read_irq

task dut_base_test::clear_irq(bit [3:0] mask);
  wr(rm.irq_clear_reg, {4'b0, mask}, 0);   // write itself sees PSLVERR when an IRQ is pending
endtask : clear_irq

task dut_base_test::wait_rx_count(int n, int timeout_us = 3000);
  bit [7:0] v;
  repeat(timeout_us) begin
    rd(rm.rx_count_low, v);
    if(v >= n) return;
    #(1 * 1us);
  end
  err_cnt++;
  `uvm_error(get_type_name(), $sformatf("RX FIFO count never reached %0d (last %0d)", n, v))
endtask : wait_rx_count

//--------------------------------------------------------------------------------------------
// VIP helpers
//--------------------------------------------------------------------------------------------
task dut_base_test::start_target_responder(bit [DATA_WIDTH-1:0] rdata[$]);
  tgt_resp_seq_h = dut_target_resp_seq::type_id::create("tgt_resp_seq_h");
  tgt_resp_seq_h.rdata = rdata;
  fork
    tgt_resp_seq_h.start(i3c_env_h.i3c_virtual_seqr_h.i3c_target_seqr_h);
  join_none
endtask : start_target_responder

task dut_base_test::get_target_tx(output i3c_target_tx t, input int timeout_us = 3000);
  bit got = 0;
  fork : wait_t
    begin tgt_mon_fifo.get(t); got = 1; end
    begin #(timeout_us * 1us); end
  join_any
  disable wait_t;
  if(!got) begin
    err_cnt++;
    t = null;
    `uvm_error(get_type_name(), "timeout: target monitor saw no transfer")
  end
endtask : get_target_tx

task dut_base_test::get_ctrl_tx(output i3c_controller_tx t, input int timeout_us = 3000);
  bit got = 0;
  fork : wait_c
    begin ctrl_mon_fifo.get(t); got = 1; end
    begin #(timeout_us * 1us); end
  join_any
  disable wait_c;
  if(!got) begin
    err_cnt++;
    t = null;
    `uvm_error(get_type_name(), "timeout: controller monitor saw no transfer")
  end
endtask : get_ctrl_tx

task dut_base_test::send_to_dut(operationType_e op, bit [I2C_MAX_ADDRESS_WIDTH-1:0] a,
                                i2c_address_mode_e mode, bit [DATA_WIDTH-1:0] wdata[$], int nread = 1);
  dut_ctrl_seq s = dut_ctrl_seq::type_id::create("dut_ctrl_seq_h");
  s.op = op; s.addr = a; s.mode = mode; s.wdata = wdata; s.nread = nread;
  s.start(i3c_env_h.i3c_virtual_seqr_h.i3c_controller_seqr_h);
endtask : send_to_dut

function void dut_base_test::check_eq(string what, longint unsigned got, longint unsigned exp);
  if(got !== exp) begin
    err_cnt++;
    `uvm_error(get_type_name(), $sformatf("CHECK FAILED %s : got 0x%0h expected 0x%0h", what, got, exp))
  end
  else
    `uvm_info(get_type_name(), $sformatf("CHECK OK     %s = 0x%0h", what, got), UVM_NONE)
endfunction : check_eq


//==========================================================================================
// TEST 1 : register reset values + illegal access flags
//==========================================================================================
class dut_reg_reset_test extends dut_base_test;
  `uvm_component_utils(dut_reg_reset_test)
  function new(string name = "dut_reg_reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    bit [7:0] v, q;
    bit e;

    // read-only registers at reset (all zero: no transfer, FIFOs empty, no IRQ)
    rd(rm.tx_count_high, v); check_eq("TX_COUNT_HIGH reset", v, 8'h00);
    rd(rm.tx_count_low,  v); check_eq("TX_COUNT_LOW reset",  v, 8'h00);
    rd(rm.rx_count_high, v); check_eq("RX_COUNT_HIGH reset", v, 8'h00);
    rd(rm.rx_count_low,  v); check_eq("RX_COUNT_LOW reset",  v, 8'h00);
    rd(rm.irq_status_reg, v, 0); check_eq("IRQ_STATUS reset", v, 8'h00);

    // reading RX_FIFO while empty -> RX_FIFO_EMPTY (bit7) sticks
    rd(rm.rx_fifo_reg, v, 0);
    read_irq(v); check_eq("IRQ_STATUS after empty RX read", v[IRQ_RX_EMPTY], 1'b1);
    clear_irq(4'b1000);                                   // IRQ_CLEAR bit3 = RX_FIFO_EMPTY
    read_irq(v); check_eq("IRQ_STATUS after clear bit3", v, 8'h00);

    // write to a read-only address (PADDR[4]=1) -> ILLEGAL_ACCESS (bit5)
    raw_apb(5'h11, 1'b1, 8'h55, q, e);
    read_irq(v); check_eq("ILLEGAL_ACCESS after write to RO", v[IRQ_ILLEGAL], 1'b1);
    clear_irq(4'b0001);                                   // IRQ_CLEAR bit0 = ILLEGAL_ACCESS
    read_irq(v); check_eq("IRQ_STATUS after clear bit0", v, 8'h00);

    // read from a write-only address (PADDR[4]=0) -> ILLEGAL_ACCESS
    raw_apb(5'h02, 1'b0, 8'h00, q, e);
    read_irq(v); check_eq("ILLEGAL_ACCESS after read of WO", v[IRQ_ILLEGAL], 1'b1);
    clear_irq(4'b0001);
    read_irq(v); check_eq("IRQ_STATUS after 2nd clear", v, 8'h00);

    // while an IRQ is pending PSLVERR=1 : prove it and that the clear works anyway
    raw_apb(5'h11, 1'b1, 8'h55, q, e);                    // set ILLEGAL_ACCESS
    raw_apb(5'h15, 1'b0, 8'h00, q, e);
    check_eq("PSLVERR high while IRQ pending", e, 1'b1);
    clear_irq(4'b0001);
    raw_apb(5'h15, 1'b0, 8'h00, q, e);
    check_eq("PSLVERR low after clear", e, 1'b0);
  endtask
endclass : dut_reg_reset_test


//==========================================================================================
// TEST 2 : DUT master, 7-bit write 1 byte
//==========================================================================================
class dut_master_write7_test extends dut_base_test;
  `uvm_component_utils(dut_master_write7_test)
  function new(string name = "dut_master_write7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    start_target_responder(none);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);
    push_tx(8'hA5);
    get_target_tx(t);
    if(t != null) begin
      check_eq("target address seen",   t.targetAddress, TGT7);
      check_eq("operation seen (WRITE)", t.operation == WRITE, 1);
      check_eq("write data count",      t.writeData.size(), 1);
      if(t.writeData.size() > 0) check_eq("write data[0]", t.writeData[0], 8'hA5);
    end
  endtask
endclass : dut_master_write7_test


//==========================================================================================
// TEST 3 : DUT master, 7-bit read 1 byte
//==========================================================================================
class dut_master_read7_test extends dut_base_test;
  `uvm_component_utils(dut_master_read7_test)
  function new(string name = "dut_master_read7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] rdata[$];
    bit [7:0] v;
    start_target_responder(rdata);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);
    push_rx();
    get_target_tx(t);
    if(t != null) begin
      check_eq("target address seen",   t.targetAddress, TGT7);
      check_eq("operation seen (READ)", t.operation == READ, 1);
    end
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("RX_FIFO data (master read)", v, RD_BYTE);
  endtask
endclass : dut_master_read7_test


//==========================================================================================
// TEST 4 : DUT slave, 7-bit write (VIP controller writes, DUT receives)
//==========================================================================================
class dut_slave_write7_test extends dut_base_test;
  `uvm_component_utils(dut_slave_write7_test)
  function new(string name = "dut_slave_write7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_controller_tx t;
    bit [DATA_WIDTH-1:0] wd[$] = '{8'h96};
    bit [7:0] v;
    config_dut(1'b0, 2'b00, 1'b0, TGT7, SELF7);
    push_rx();                                   // slave must have a read command queued
    #(2 * 1us);
    send_to_dut(WRITE, SELF7, I2C_ADDR_7BIT, wd);
    get_ctrl_tx(t);
    if(t != null) check_eq("DUT ACKed its address", t.targetAddressStatus == ACK, 1);
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("RX_FIFO data (slave write)", v, 8'h96);
  endtask
endclass : dut_slave_write7_test


//==========================================================================================
// TEST 5 : DUT slave, 7-bit read (VIP controller reads, DUT sends TX_DATA)
//==========================================================================================
class dut_slave_read7_test extends dut_base_test;
  `uvm_component_utils(dut_slave_read7_test)
  function new(string name = "dut_slave_read7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_controller_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    config_dut(1'b0, 2'b00, 1'b0, TGT7, SELF7);
    push_tx(8'hC3);                              // slave must have a TX command queued
    #(2 * 1us);
    send_to_dut(READ, SELF7, I2C_ADDR_7BIT, none, 1);
    get_ctrl_tx(t);
    if(t != null) begin
      check_eq("DUT ACKed its address", t.targetAddressStatus == ACK, 1);
      check_eq("read data count", t.readData.size(), 1);
      if(t.readData.size() > 0) check_eq("read data[0] from DUT", t.readData[0], 8'hC3);
    end
  endtask
endclass : dut_slave_read7_test


//==========================================================================================
// TEST 6 : DUT master, address NACK -> NACK IRQ -> clear
//   The DUT keeps the TX command and re-sends it after the clear (retry loop), so the NACK
//   comes back. The test checks: NACK set, cleared by IRQ_CLEAR bit1, and that it is
//   NACKed again (proves the retry).
//==========================================================================================
class dut_master_addr_nack_test extends dut_base_test;
  `uvm_component_utils(dut_master_addr_nack_test)
  function new(string name = "dut_master_addr_nack_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    bit [7:0] v;
    bit [DATA_WIDTH-1:0] none[$];
    start_target_responder(none);                // target at TGT7, DUT will address WRONG7
    config_dut(1'b1, 2'b00, 1'b0, WRONG7, SELF7);
    push_tx(8'h5A);

    // wait for NACK
    repeat(3000) begin
      read_irq(v);
      if(v[IRQ_NACK]) break;
      #(1 * 1us);
    end
    check_eq("NACK flag set", v[IRQ_NACK], 1'b1);

    // The core still sets the flag while it finishes the address phase and the STOP, so a clear
    // issued the moment the flag appears is overwritten. Let the STOP finish first; the retry
    // START + address byte takes far longer than this wait.
    #(30 * 1us);
    clear_irq(4'b0010);                          // IRQ_CLEAR bit1 = NACK
    read_irq(v);
    check_eq("NACK flag right after clear", v[IRQ_NACK], 1'b0);

    // DUT retries -> NACK again
    repeat(3000) begin
      read_irq(v);
      if(v[IRQ_NACK]) break;
      #(1 * 1us);
    end
    check_eq("NACK again after retry", v[IRQ_NACK], 1'b1);
  endtask
endclass : dut_master_addr_nack_test


//==========================================================================================
// TEST 7a : DUT master, 10-bit write
//==========================================================================================
class dut_master_write10_test extends dut_base_test;
  `uvm_component_utils(dut_master_write10_test)
  function new(string name = "dut_master_write10_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void setup_target_agent_cfg();
    super.setup_target_agent_cfg();
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i]) begin
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress = TGT10;
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].addressMode   = I2C_ADDR_10BIT;
    end
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    start_target_responder(none);
    config_dut(1'b1, 2'b00, 1'b1, TGT10, SELF10);
    push_tx(8'hB7);
    get_target_tx(t);
    if(t != null) begin
      check_eq("10-bit address seen",   t.targetAddress, TGT10);
      check_eq("operation seen (WRITE)", t.operation == WRITE, 1);
      check_eq("write data count",      t.writeData.size(), 1);
      if(t.writeData.size() > 0) check_eq("write data[0]", t.writeData[0], 8'hB7);
    end
  endtask
endclass : dut_master_write10_test


//==========================================================================================
// TEST 7b : DUT master, 10-bit read
//==========================================================================================
class dut_master_read10_test extends dut_base_test;
  `uvm_component_utils(dut_master_read10_test)
  function new(string name = "dut_master_read10_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void setup_target_agent_cfg();
    super.setup_target_agent_cfg();
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i]) begin
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress = TGT10;
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].addressMode   = I2C_ADDR_10BIT;
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].defaultReadData = 8'h4E;
    end
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] rdata[$];
    bit [7:0] v;
    start_target_responder(rdata);
    config_dut(1'b1, 2'b00, 1'b1, TGT10, SELF10);
    push_rx();
    get_target_tx(t);
    if(t != null) begin
      check_eq("10-bit address seen",   t.targetAddress, TGT10);
      check_eq("operation seen (READ)", t.operation == READ, 1);
    end
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("RX_FIFO data (10-bit master read)", v, 8'h4E);
  endtask
endclass : dut_master_read10_test


//==========================================================================================
// TEST 7c : DUT slave, 10-bit write
//==========================================================================================
class dut_slave_write10_test extends dut_base_test;
  `uvm_component_utils(dut_slave_write10_test)
  function new(string name = "dut_slave_write10_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_controller_tx t;
    bit [DATA_WIDTH-1:0] wd[$] = '{8'h2D};
    bit [7:0] v;
    config_dut(1'b0, 2'b00, 1'b1, TGT10, SELF10);
    push_rx();
    #(2 * 1us);
    send_to_dut(WRITE, SELF10, I2C_ADDR_10BIT, wd);
    get_ctrl_tx(t);
    if(t != null) begin
      check_eq("DUT ACKed 1st address byte", t.targetAddressStatus == ACK, 1);
      check_eq("DUT ACKed 2nd address byte", t.targetAddressStatus2 == ACK, 1);
    end
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("RX_FIFO data (10-bit slave write)", v, 8'h2D);
  endtask
endclass : dut_slave_write10_test


//==========================================================================================
// TEST 7d : DUT slave, 10-bit read
//==========================================================================================
class dut_slave_read10_test extends dut_base_test;
  `uvm_component_utils(dut_slave_read10_test)
  function new(string name = "dut_slave_read10_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_controller_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    config_dut(1'b0, 2'b00, 1'b1, TGT10, SELF10);
    push_tx(8'hE1);
    #(2 * 1us);
    send_to_dut(READ, SELF10, I2C_ADDR_10BIT, none, 1);
    get_ctrl_tx(t);
    if(t != null) begin
      check_eq("DUT ACKed address", t.targetAddressStatus == ACK, 1);
      check_eq("read data count", t.readData.size(), 1);
      if(t.readData.size() > 0) check_eq("read data[0] from DUT", t.readData[0], 8'hE1);
    end
  endtask
endclass : dut_slave_read10_test

//==========================================================================================
// TEST 8 : DUT master, 7-bit READ followed by WRITE to the SAME address
//   Each command is sent only after the previous transfer finished, so the DUT does two
//   separate transfers (START..STOP each) and not one transfer joined by a repeated start.
//==========================================================================================
class dut_master_read_then_write7_test extends dut_base_test;
  `uvm_component_utils(dut_master_read_then_write7_test)
  function new(string name = "dut_master_read_then_write7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    bit [7:0] v;
    start_target_responder(none);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);

    // ---- 1st transfer : READ from TGT7 (target sends RD_BYTE)
    push_rx();
    get_target_tx(t);
    if(t != null) begin
      check_eq("READ  : address seen",   t.targetAddress, TGT7);
      check_eq("READ  : operation (READ)", t.operation == READ, 1);
    end
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("READ  : RX_FIFO data", v, RD_BYTE);

    // ---- 2nd transfer : WRITE to the same TGT7
    push_tx(8'hA5);
    get_target_tx(t);
    if(t != null) begin
      check_eq("WRITE : address seen",   t.targetAddress, TGT7);
      check_eq("WRITE : operation (WRITE)", t.operation == WRITE, 1);
      check_eq("WRITE : data count",     t.writeData.size(), 1);
      if(t.writeData.size() > 0) check_eq("WRITE : data[0]", t.writeData[0], 8'hA5);
    end
  endtask
endclass : dut_master_read_then_write7_test

//==========================================================================================
// TEST 9 : DUT master, 7-bit WRITE then READ from the SAME address, read data must equal
//          the written data.
//   The target BFM keeps every byte it receives in an internal FIFO (targetFIFOMemory) and
//   sends those bytes back on the next read, so the VIP acts like a small memory/loopback.
//   Result checked: byte written by the DUT == byte the DUT reads back into its RX FIFO.
//==========================================================================================
class dut_master_write_then_read7_test extends dut_base_test;
  `uvm_component_utils(dut_master_write_then_read7_test)
  function new(string name = "dut_master_write_then_read7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    bit [7:0] wdata = 8'hA5;
    bit [7:0] v;
    start_target_responder(none);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);

    // ---- WRITE wdata to TGT7
    push_tx(wdata);
    get_target_tx(t);
    if(t != null) begin
      check_eq("WRITE : address seen",      t.targetAddress, TGT7);
      check_eq("WRITE : operation (WRITE)", t.operation == WRITE, 1);
      if(t.writeData.size() > 0) check_eq("WRITE : data[0] on the bus", t.writeData[0], wdata);
    end

    // ---- READ back from the same TGT7 (after the write transfer finished)
    push_rx();
    get_target_tx(t);
    if(t != null) begin
      check_eq("READ  : address seen",     t.targetAddress, TGT7);
      check_eq("READ  : operation (READ)", t.operation == READ, 1);
    end
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("READ  : data read back == data written", v, wdata);
  endtask
endclass : dut_master_write_then_read7_test

//==========================================================================================
// CLOCK STRETCHING (the target holds SCL low after every ACK bit)
//   The target BFM stretches for cfg.stretchClks pclk (20 ns each) after the address ACK, after
//   every write-data ACK and after every master ACK of a read byte.
//==========================================================================================

//------------------------------------------------------------------------------------------
// TEST 10 : DUT master write, target stretches SCL. The DUT must wait and still deliver the
//           correct address and data. Timing check: the transfer must take at least as long
//           as the stretching added (2 stretch points: address ACK + data ACK).
//------------------------------------------------------------------------------------------
class dut_master_write_stretch7_test extends dut_base_test;
  `uvm_component_utils(dut_master_write_stretch7_test)
  localparam int STRETCH_CLKS = 500;                 // 500 x 20 ns = 10 us per stretch point
  function new(string name = "dut_master_write_stretch7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void setup_target_agent_cfg();
    super.setup_target_agent_cfg();
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i])
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].stretchClks = STRETCH_CLKS;
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    time t0, t1;
    start_target_responder(none);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);
    t0 = $time;
    push_tx(8'hA5);
    get_target_tx(t);
    t1 = $time;
    if(t != null) begin
      check_eq("stretched WRITE : address seen",   t.targetAddress, TGT7);
      check_eq("stretched WRITE : operation (WRITE)", t.operation == WRITE, 1);
      check_eq("stretched WRITE : data count",     t.writeData.size(), 1);
      if(t.writeData.size() > 0) check_eq("stretched WRITE : data[0]", t.writeData[0], 8'hA5);
    end
    `uvm_info(get_type_name(), $sformatf("transfer time with stretching = %0t", t1 - t0), UVM_NONE)
    check_eq("transfer lasted at least the added stretch time (1=yes)",
             (t1 - t0) >= (2 * STRETCH_CLKS * 20ns), 1);
  endtask
endclass : dut_master_write_stretch7_test


//------------------------------------------------------------------------------------------
// TEST 11 : DUT master read, target stretches SCL. Read data must still arrive intact.
//------------------------------------------------------------------------------------------
class dut_master_read_stretch7_test extends dut_base_test;
  `uvm_component_utils(dut_master_read_stretch7_test)
  localparam int STRETCH_CLKS = 500;
  function new(string name = "dut_master_read_stretch7_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void setup_target_agent_cfg();
    super.setup_target_agent_cfg();
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i])
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].stretchClks = STRETCH_CLKS;
  endfunction

  task test_body();
    i3c_target_tx t;
    bit [DATA_WIDTH-1:0] none[$];
    bit [7:0] v;
    start_target_responder(none);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);
    push_rx();
    get_target_tx(t);
    if(t != null) begin
      check_eq("stretched READ : address seen",   t.targetAddress, TGT7);
      check_eq("stretched READ : operation (READ)", t.operation == READ, 1);
    end
    wait_rx_count(1);
    rd(rm.rx_fifo_reg, v);
    check_eq("stretched READ : RX_FIFO data", v, RD_BYTE);
  endtask
endclass : dut_master_read_stretch7_test


//------------------------------------------------------------------------------------------
// TEST 12 : stretch longer than the DUT's SCL timeout -> SCL_HUNG (IRQ_STATUS bit2).
//   SCL timeout registers 0x03..0x05 = 24-bit count of pclk cycles SCL may stay low.
//   Timeout 4000 pclk (80 us) is longer than a normal SCL low phase; the target stretches 60000
//   pclk (1.2 ms). The DUT behaviour after the hang (recovery) is not modelled, so the
//   scoreboard is off for this test and only the flag is checked.
//------------------------------------------------------------------------------------------
class dut_master_scl_hung_test extends dut_base_test;
  `uvm_component_utils(dut_master_scl_hung_test)
  localparam int          STRETCH_CLKS = 60000;
  localparam bit [23:0]   SCL_TIMEOUT  = 24'd4000;
  function new(string name = "dut_master_scl_hung_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void setup_env_cfg();
    super.setup_env_cfg();
    i3c_env_cfg_h.has_dut_scoreboard = 0;
  endfunction

  function void setup_target_agent_cfg();
    super.setup_target_agent_cfg();
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i])
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].stretchClks = STRETCH_CLKS;
  endfunction

  task test_body();
    bit [DATA_WIDTH-1:0] none[$];
    bit [7:0] v;
    bit hung = 0;
    start_target_responder(none);
    // timeouts first: all config is applied in order, before the transfer starts
    wr(rm.scl_timeout2, SCL_TIMEOUT[23:16]);
    wr(rm.scl_timeout1, SCL_TIMEOUT[15:8]);
    wr(rm.scl_timeout0, SCL_TIMEOUT[7:0]);
    config_dut(1'b1, 2'b00, 1'b0, TGT7, SELF7);
    push_tx(8'hA5);
    repeat(3000) begin
      read_irq(v);
      if(v[IRQ_SCL_HUNG]) begin hung = 1; break; end
      #(1 * 1us);
    end
    check_eq("SCL_HUNG flag (bit2) set after long stretch", hung, 1);
    #(1500 * 1us);                  // let the target release SCL before the test ends
  endtask
endclass : dut_master_scl_hung_test

`endif

