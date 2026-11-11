`ifndef DUT_SCOREBOARD_INCLUDED_
`define DUT_SCOREBOARD_INCLUDED_

//--------------------------------------------------------------------------------------------
// dut_scoreboard : checks the APB4 I2C DUT against what the APB side programmed.
//
// Inputs (analysis fifos):
//   apb_fifo  : every APB access seen by the APB monitor (register writes / reads of the DUT)
//   tgt_fifo  : every I2C transfer seen by the target monitor      (used when the DUT is master)
//   ctrl_fifo : every I2C transfer seen by the controller monitor  (used when the DUT is slave)
//
// Reference model (mirrors the DUT as understood from the RTL):
//   * Every register write that is accepted goes into ONE ordered queue ev_q, like the DUT's
//     command FIFO: config writes (ADDR/MODE/SELF_ADDR/timeouts), TX_DATA and RX_DATA commands.
//   * Config writes only take effect when the DUT is idle, so the model applies the config
//     events that sit at the head of the queue just before it looks at the next bus transfer.
//   * Writes are dropped while PSLVERR=1 (IRQ_CLEAR excepted).
//   * DUT master : bus transfer must have the programmed address, direction and TX bytes;
//                  the address ACK/NACK must agree with the VIP target address. After a NACK
//                  the DUT keeps the command and sends it again.
//                  Bytes read from the bus are what RX_FIFO must return.
//   * DUT slave  : controller transfer to the DUT's own address must be ACKed (other address
//                  NACKed). Written bytes must show up in RX_FIFO (one RX command per byte),
//                  read bytes must be the queued TX_DATA bytes.
//   * IRQ_STATUS : only the safe one-way checks - NACK seen on the bus and not cleared since
//                  -> bit4 must be 1;  illegal access made and not cleared -> bit5 must be 1.
//
// Known limits (kept simple on purpose):
//   * one transfer = the consecutive TX (or RX) commands at the head of the queue
//   * bytes the DUT slave may NACK because no command is queued are not checked
//   * timeouts, arbitration, clock stretching, glitch filter are not modelled
//--------------------------------------------------------------------------------------------
class dut_scoreboard extends uvm_component;
  `uvm_component_utils(dut_scoreboard)

  i3c_env_config env_cfg;

  uvm_tlm_analysis_fifo #(apb_master_tx)     apb_fifo;
  uvm_tlm_analysis_fifo #(i3c_target_tx)     tgt_fifo;
  uvm_tlm_analysis_fifo #(i3c_controller_tx) ctrl_fifo;

  // ordered command / config queue
  typedef enum {EV_CFG, EV_TX, EV_RX} ev_kind_e;
  typedef struct {
    ev_kind_e kind;
    bit [4:0] addr;
    bit [7:0] data;
  } ev_t;
  ev_t ev_q[$];

  // active command (kept while the DUT retries after a NACK)
  bit  cur_valid;
  ev_t cur;

  // DUT configuration as applied by the model
  bit [1:0] tgt_h, self_h;
  bit [7:0] tgt_l, self_l;
  bit       cfg_master;
  bit [1:0] cfg_speed;
  bit       cfg_addr10;

  // RX FIFO model: bytes seen on the bus / bytes read through APB, matched in order
  bit [7:0] rx_exp_q[$];
  bit [7:0] rx_got_q[$];

  // sticky flag models
  bit nack_seen;
  bit illegal_seen;

  // statistics
  int unsigned err_cnt;
  int unsigned chk_cnt;
  int unsigned apb_cnt, tgt_cnt, ctrl_cnt;
  int unsigned nack_cnt;

  extern function new(string name = "dut_scoreboard", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

  extern task apb_proc();
  extern task tgt_proc();
  extern task ctrl_proc();

  extern function void handle_apb(apb_master_tx t);
  extern function void handle_target(i3c_target_tx t);
  extern function void handle_ctrl(i3c_controller_tx c);

  extern function void apply_cfg_events();
  extern function bit  fetch_cmd();
  extern function bit  rx_expected_later();
  extern function void add_rx_expected(bit [7:0] b);
  extern function void rx_fifo_read(bit [7:0] d);
  extern function void check_eq(string what, longint unsigned got, longint unsigned exp);
  extern function bit [9:0] dut_target_addr();
  extern function bit [9:0] dut_self_addr();
endclass : dut_scoreboard


function dut_scoreboard::new(string name = "dut_scoreboard", uvm_component parent = null);
  super.new(name, parent);
  apb_fifo  = new("apb_fifo",  this);
  tgt_fifo  = new("tgt_fifo",  this);
  ctrl_fifo = new("ctrl_fifo", this);
endfunction : new

function void dut_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if(!uvm_config_db #(i3c_env_config)::get(this, "", "i3c_env_config", env_cfg))
    `uvm_fatal("DUT_SCB", "cannot get i3c_env_config")
endfunction : build_phase

task dut_scoreboard::run_phase(uvm_phase phase);
  fork
    apb_proc();
    tgt_proc();
    ctrl_proc();
  join_none
endtask : run_phase

task dut_scoreboard::apb_proc();
  apb_master_tx t;
  forever begin
    apb_fifo.get(t);
    apb_cnt++;
    handle_apb(t);
  end
endtask : apb_proc

task dut_scoreboard::tgt_proc();
  i3c_target_tx t;
  forever begin
    tgt_fifo.get(t);
    tgt_cnt++;
    handle_target(t);
  end
endtask : tgt_proc

task dut_scoreboard::ctrl_proc();
  i3c_controller_tx c;
  forever begin
    ctrl_fifo.get(c);
    ctrl_cnt++;
    handle_ctrl(c);
  end
endtask : ctrl_proc

//--------------------------------------------------------------------------------------------
// small helpers
//--------------------------------------------------------------------------------------------
function void dut_scoreboard::check_eq(string what, longint unsigned got, longint unsigned exp);
  chk_cnt++;
  if(got !== exp) begin
    err_cnt++;
    `uvm_error("DUT_SCB", $sformatf("MISMATCH %s : got 0x%0h expected 0x%0h", what, got, exp))
  end
  else
    `uvm_info("DUT_SCB", $sformatf("MATCH    %s = 0x%0h", what, got), UVM_NONE)
endfunction : check_eq

function bit [9:0] dut_scoreboard::dut_target_addr();
  return cfg_addr10 ? {tgt_h, tgt_l} : {3'b000, tgt_l[6:0]};
endfunction : dut_target_addr

function bit [9:0] dut_scoreboard::dut_self_addr();
  return cfg_addr10 ? {self_h, self_l} : {3'b000, self_l[6:0]};
endfunction : dut_self_addr

// config events at the head of the queue take effect while the DUT is idle (no command pending)
function void dut_scoreboard::apply_cfg_events();
  if(cur_valid) return;
  while(ev_q.size() > 0 && ev_q[0].kind == EV_CFG) begin
    ev_t e = ev_q.pop_front();
    case(e.addr)
      5'h00: tgt_h  = e.data[1:0];
      5'h01: tgt_l  = e.data;
      5'h02: begin
               cfg_master = e.data[3];
               cfg_speed  = e.data[2:1];
               cfg_addr10 = e.data[0];
               `uvm_info("DUT_SCB", $sformatf("MODE applied: role=%s speed=%0d addr10=%0d",
                         cfg_master ? "MASTER" : "SLAVE", cfg_speed, cfg_addr10), UVM_NONE)
             end
      5'h0C: self_h = e.data[1:0];
      5'h0D: self_l = e.data;
      default: ;   // timeouts: not modelled
    endcase
  end
endfunction : apply_cfg_events

// make the next queued command the active one (returns 0 if the queue holds none)
function bit dut_scoreboard::fetch_cmd();
  if(cur_valid) return 1;
  if(ev_q.size() == 0) return 0;
  cur = ev_q.pop_front();
  cur_valid = 1;
  return 1;
endfunction : fetch_cmd

// is a read command (or slave-receive command) still waiting, so data may still arrive in RX FIFO
function bit dut_scoreboard::rx_expected_later();
  if(cur_valid && cur.kind == EV_RX) return 1;
  foreach(ev_q[i]) if(ev_q[i].kind == EV_RX) return 1;
  return 0;
endfunction : rx_expected_later

// a byte that must appear in the RX FIFO; matched against an APB read that may already have happened
function void dut_scoreboard::add_rx_expected(bit [7:0] b);
  if(rx_got_q.size() > 0) begin
    bit [7:0] g = rx_got_q.pop_front();
    check_eq("RX_FIFO byte (read before bus transfer was reported)", g, b);
  end
  else
    rx_exp_q.push_back(b);
endfunction : add_rx_expected

function void dut_scoreboard::rx_fifo_read(bit [7:0] d);
  if(rx_exp_q.size() > 0) begin
    bit [7:0] e = rx_exp_q.pop_front();
    check_eq("RX_FIFO byte", d, e);
  end
  else if(rx_expected_later())
    rx_got_q.push_back(d);          // bus transfer not reported yet, compare when it is
  else
    `uvm_info("DUT_SCB", $sformatf("RX_FIFO read 0x%0h with no data expected (empty FIFO read) - not checked", d), UVM_NONE)
endfunction : rx_fifo_read

//--------------------------------------------------------------------------------------------
// APB side
//--------------------------------------------------------------------------------------------
function void dut_scoreboard::handle_apb(apb_master_tx t);
  bit [4:0] a      = t.paddr[4:0];
  bit       is_wr  = (t.pwrite == apb_global_pkg::WRITE);
  bit       err    = (t.pslverr != apb_global_pkg::NO_ERROR);
  bit [7:0] wd     = t.pwdata[7:0];
  bit [7:0] rdv    = t.prdata[7:0];
  ev_t      e;

  // illegal access: write to a read-only address (PADDR[4]=1) or read of a write-only one
  if((is_wr && a[4]) || (!is_wr && !a[4])) begin
    illegal_seen = 1;
    `uvm_info("DUT_SCB", $sformatf("illegal APB %s at 0x%0h -> ILLEGAL_ACCESS expected",
              is_wr ? "write" : "read", a), UVM_NONE)
    return;
  end

  if(is_wr) begin
    if(a == 5'h0B) begin                 // IRQ_CLEAR works even while PSLVERR=1
      if(wd[0]) illegal_seen = 0;
      if(wd[1]) nack_seen    = 0;
      return;
    end
    if(err) begin
      `uvm_info("DUT_SCB", $sformatf("write to 0x%0h dropped (PSLVERR=1)", a), UVM_NONE)
      return;
    end
    e.addr = a; e.data = wd;
    case(a)
      5'h00, 5'h01, 5'h02, 5'h03, 5'h04, 5'h05, 5'h06, 5'h07, 5'h08, 5'h0C, 5'h0D: begin
        e.kind = EV_CFG; ev_q.push_back(e);
      end
      5'h09: begin e.kind = EV_TX; ev_q.push_back(e); end
      5'h0A: begin e.kind = EV_RX; ev_q.push_back(e); end
      default: ;
    endcase
  end
  else begin
    case(a)
      5'h10: rx_fifo_read(rdv);
      5'h15: begin                       // IRQ_STATUS : one-way checks only
        if(illegal_seen) check_eq("IRQ_STATUS.ILLEGAL_ACCESS (bit5) after illegal access", rdv[5], 1'b1);
        if(nack_seen)    check_eq("IRQ_STATUS.NACK (bit4) after NACK on the bus",          rdv[4], 1'b1);
      end
      default: ;
    endcase
  end
endfunction : handle_apb

//--------------------------------------------------------------------------------------------
// DUT = master : transfer reported by the target monitor
//--------------------------------------------------------------------------------------------
function void dut_scoreboard::handle_target(i3c_target_tx t);
  bit [9:0] exp_addr, obs_addr, vip_addr;
  bit       exp_ack, vip_is10;

  apply_cfg_events();
  if(!cfg_master) return;               // DUT is slave: this is the controller VIP's transfer

  if(!fetch_cmd()) begin
    err_cnt++;
    `uvm_error("DUT_SCB", "DUT started a transfer as master but no TX/RX command is queued")
    return;
  end

  // ---- address phase
  exp_addr = dut_target_addr();
  vip_addr = env_cfg.i3c_target_agent_cfg_h[0].targetAddress;
  vip_is10 = (env_cfg.i3c_target_agent_cfg_h[0].addressMode == I2C_ADDR_10BIT);
  exp_ack  = (vip_is10 == cfg_addr10) &&
             (cfg_addr10 ? (exp_addr == vip_addr) : (exp_addr[6:0] == vip_addr[6:0]));

  check_eq("DUT address format (1=10-bit)", t.addressMode == I2C_ADDR_10BIT, cfg_addr10);
  if(cfg_addr10) begin
    obs_addr = t.targetAddress[9:0];
    check_eq("DUT address [9:8]", obs_addr[9:8], exp_addr[9:8]);
    if(t.targetAddressStatus == ACK) check_eq("DUT address [7:0]", obs_addr[7:0], exp_addr[7:0]);
  end
  else
    check_eq("DUT address", t.targetAddress[6:0], exp_addr[6:0]);

  check_eq("address ACK (1=ACK)", t.targetAddressStatus == ACK, exp_ack);

  if(t.targetAddressStatus == NACK) begin
    nack_cnt++;
    nack_seen = 1;
    `uvm_info("DUT_SCB", "address NACK on the bus: DUT keeps the command and will retry", UVM_NONE)
    return;
  end

  // ---- data phase
  if(cur.kind == EV_TX) begin
    int n = t.writeData.size();
    check_eq("operation (1=WRITE)", t.operation == WRITE, 1'b1);
    if(n == 0) begin
      err_cnt++;
      `uvm_error("DUT_SCB", "write transfer with no data byte on the bus")
    end
    for(int i = 0; i < n; i++) begin
      if(i == 0)
        check_eq("write byte[0] on the bus", t.writeData[0], cur.data);
      else if(ev_q.size() > 0 && ev_q[0].kind == EV_TX) begin
        ev_t nx = ev_q.pop_front();
        check_eq($sformatf("write byte[%0d] on the bus", i), t.writeData[i], nx.data);
      end
      else begin
        err_cnt++;
        `uvm_error("DUT_SCB", $sformatf("byte[%0d]=0x%0h on the bus but no matching TX command queued", i, t.writeData[i]))
      end
    end
  end
  else begin
    int n = t.readData.size();
    check_eq("operation (1=READ)", t.operation == READ, 1'b1);
    if(n == 0) begin
      err_cnt++;
      `uvm_error("DUT_SCB", "read transfer with no data byte on the bus")
    end
    for(int i = 0; i < n; i++) begin
      if(i > 0) begin
        if(ev_q.size() > 0 && ev_q[0].kind == EV_RX) void'(ev_q.pop_front());
        else begin
          err_cnt++;
          `uvm_error("DUT_SCB", $sformatf("read byte[%0d] on the bus but no matching RX command queued", i))
        end
      end
      add_rx_expected(t.readData[i]);
    end
  end
  cur_valid = 0;
endfunction : handle_target

//--------------------------------------------------------------------------------------------
// DUT = slave : transfer reported by the controller monitor
//--------------------------------------------------------------------------------------------
function void dut_scoreboard::handle_ctrl(i3c_controller_tx c);
  bit [9:0] exp_addr, obs_addr;
  bit       exp_ack;

  apply_cfg_events();
  if(cfg_master) return;                // DUT is master: this is the target VIP's view of its own transfer

  exp_addr = dut_self_addr();
  obs_addr = c.targetAddress[9:0];
  exp_ack  = (cfg_addr10 ? (obs_addr == exp_addr) : (obs_addr[6:0] == exp_addr[6:0]));
  if((c.addressMode == I2C_ADDR_10BIT) != cfg_addr10) exp_ack = 0;   // wrong address format

  check_eq("DUT (slave) address ACK (1=ACK)", c.targetAddressStatus == ACK, exp_ack);
  if(c.targetAddressStatus == NACK) begin
    nack_cnt++;
    return;
  end

  if(c.operation == WRITE) begin
    // controller wrote bytes, the DUT needs one RX command per byte to store them
    for(int i = 0; i < c.writeData.size(); i++) begin
      if(c.writeDataStatus[i] != ACK) continue;
      if(ev_q.size() > 0 && ev_q[0].kind == EV_RX) begin
        void'(ev_q.pop_front());
        add_rx_expected(c.writeData[i]);
      end
      else
        `uvm_info("DUT_SCB", $sformatf("slave write byte[%0d]=0x%0h ACKed but no RX command queued - not checked", i, c.writeData[i]), UVM_NONE)
    end
  end
  else begin
    // controller read bytes, they must be the queued TX_DATA bytes
    for(int i = 0; i < c.readData.size(); i++) begin
      if(ev_q.size() > 0 && ev_q[0].kind == EV_TX) begin
        ev_t nx = ev_q.pop_front();
        check_eq($sformatf("slave read byte[%0d] received by the controller", i), c.readData[i], nx.data);
      end
      else
        `uvm_info("DUT_SCB", $sformatf("slave read byte[%0d]=0x%0h with no TX command queued - not checked", i, c.readData[i]), UVM_NONE)
    end
  end
endfunction : handle_ctrl

//--------------------------------------------------------------------------------------------
function void dut_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);
  if(rx_got_q.size() > 0)
    `uvm_warning("DUT_SCB", $sformatf("%0d RX_FIFO read(s) never matched a bus byte", rx_got_q.size()))
  if(rx_exp_q.size() > 0)
    `uvm_info("DUT_SCB", $sformatf("%0d byte(s) received by the DUT were never read from RX_FIFO", rx_exp_q.size()), UVM_NONE)
  if(cur_valid)
    `uvm_info("DUT_SCB", "a command was still active at the end (retrying after NACK)", UVM_NONE)
  `uvm_info("DUT_SCB", $sformatf("SUMMARY : apb=%0d target_tx=%0d controller_tx=%0d nack=%0d checks=%0d errors=%0d",
            apb_cnt, tgt_cnt, ctrl_cnt, nack_cnt, chk_cnt, err_cnt), UVM_NONE)
endfunction : report_phase

`endif

