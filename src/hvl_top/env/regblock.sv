
`ifndef I2C_REG_WIDTH
  `define I2C_REG_WIDTH 8
`endif

class i2c_reg_block extends uvm_reg_block;
  `uvm_object_utils(i2c_reg_block)

  rand i2c_addrh_reg       slv_addrh;
  rand i2c_addrl_reg       slv_addrl;
  rand i2c_mode_reg        mode_reg;

  rand i2c_timeout_reg     scl_timeout2;
  rand i2c_timeout_reg     scl_timeout1;
  rand i2c_timeout_reg     scl_timeout0;
  rand i2c_timeout_reg     sda_timeout2;
  rand i2c_timeout_reg     sda_timeout1;
  rand i2c_timeout_reg     sda_timeout0;

  rand i2c_tx_data_reg     tx_data_reg;
  rand i2c_rx_data_reg     rx_data_reg;
  rand i2c_irq_clear_reg   irq_clear_reg;

  rand i2c_addrh_reg       slv_self_addrh;
  rand i2c_addrl_reg       slv_self_addrl;

  // Reserved for future use: RTL write decode for 0x0E is not implemented.
  // rand i2c_glitch_reg      glitch_reg;

  i2c_rx_fifo_reg          rx_fifo_reg;
  i2c_count_reg            tx_count_high;
  i2c_count_reg            tx_count_low;
  i2c_count_reg            rx_count_high;
  i2c_count_reg            rx_count_low;
  i2c_irq_status_reg       irq_status_reg;

  uvm_reg_map default_map;

  function new(string name = "i2c_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();

    slv_addrh = i2c_addrh_reg::type_id::create("slv_addrh");
    slv_addrh.configure(this, null, "");
    slv_addrh.build();

    slv_addrl = i2c_addrl_reg::type_id::create("slv_addrl");
    slv_addrl.configure(this, null, "");
    slv_addrl.build();

    mode_reg = i2c_mode_reg::type_id::create("mode_reg");
    mode_reg.configure(this, null, "");
    mode_reg.build();

    scl_timeout2 = i2c_timeout_reg::type_id::create("scl_timeout2");
    scl_timeout2.configure(this, null, "");
    scl_timeout2.build();

    scl_timeout1 = i2c_timeout_reg::type_id::create("scl_timeout1");
    scl_timeout1.configure(this, null, "");
    scl_timeout1.build();

    scl_timeout0 = i2c_timeout_reg::type_id::create("scl_timeout0");
    scl_timeout0.configure(this, null, "");
    scl_timeout0.build();

    sda_timeout2 = i2c_timeout_reg::type_id::create("sda_timeout2");
    sda_timeout2.configure(this, null, "");
    sda_timeout2.build();

    sda_timeout1 = i2c_timeout_reg::type_id::create("sda_timeout1");
    sda_timeout1.configure(this, null, "");
    sda_timeout1.build();

    sda_timeout0 = i2c_timeout_reg::type_id::create("sda_timeout0");
    sda_timeout0.configure(this, null, "");
    sda_timeout0.build();

    tx_data_reg = i2c_tx_data_reg::type_id::create("tx_data_reg");
    tx_data_reg.configure(this, null, "");
    tx_data_reg.build();

    rx_data_reg = i2c_rx_data_reg::type_id::create("rx_data_reg");
    rx_data_reg.configure(this, null, "");
    rx_data_reg.build();

    irq_clear_reg = i2c_irq_clear_reg::type_id::create("irq_clear_reg");
    irq_clear_reg.configure(this, null, "");
    irq_clear_reg.build();

    slv_self_addrh = i2c_addrh_reg::type_id::create("slv_self_addrh");
    slv_self_addrh.configure(this, null, "");
    slv_self_addrh.build();

    slv_self_addrl = i2c_addrl_reg::type_id::create("slv_self_addrl");
    slv_self_addrl.configure(this, null, "");
    slv_self_addrl.build();

    // glitch_reg = i2c_glitch_reg::type_id::create("glitch_reg");
    // glitch_reg.configure(this, null, "");
    // glitch_reg.build();

    rx_fifo_reg = i2c_rx_fifo_reg::type_id::create("rx_fifo_reg");
    rx_fifo_reg.configure(this, null, "");
    rx_fifo_reg.build();

    tx_count_high = i2c_count_reg::type_id::create("tx_count_high");
    tx_count_high.configure(this, null, "");
    tx_count_high.build();

    tx_count_low = i2c_count_reg::type_id::create("tx_count_low");
    tx_count_low.configure(this, null, "");
    tx_count_low.build();

    rx_count_high = i2c_count_reg::type_id::create("rx_count_high");
    rx_count_high.configure(this, null, "");
    rx_count_high.build();

    rx_count_low = i2c_count_reg::type_id::create("rx_count_low");
    rx_count_low.configure(this, null, "");
    rx_count_low.build();

    irq_status_reg = i2c_irq_status_reg::type_id::create("irq_status_reg");
    irq_status_reg.configure(this, null, "");
    irq_status_reg.build();

    default_map = create_map("default_map", 'h0,
                             `I2C_REG_WIDTH/8,
                             UVM_LITTLE_ENDIAN, 1);

    default_map.add_reg(slv_addrh,      'h00, "WO");
    default_map.add_reg(slv_addrl,      'h01, "WO");
    default_map.add_reg(mode_reg,       'h02, "WO");

    default_map.add_reg(scl_timeout2,   'h03, "WO");
    default_map.add_reg(scl_timeout1,   'h04, "WO");
    default_map.add_reg(scl_timeout0,   'h05, "WO");

    default_map.add_reg(sda_timeout2,   'h06, "WO");
    default_map.add_reg(sda_timeout1,   'h07, "WO");
    default_map.add_reg(sda_timeout0,   'h08, "WO");

    default_map.add_reg(tx_data_reg,    'h09, "WO");
    default_map.add_reg(rx_data_reg,    'h0A, "WO");
    default_map.add_reg(irq_clear_reg,  'h0B, "WO");

    default_map.add_reg(slv_self_addrh, 'h0C, "WO");
    default_map.add_reg(slv_self_addrl, 'h0D, "WO");

    // Address 0x0E: MAX_GLITCH_COUNT
    // Commented out because RTL write decode is not implemented.
    // default_map.add_reg(glitch_reg,  'h0E, "WO");

    default_map.add_reg(rx_fifo_reg,    'h10, "RO");
    default_map.add_reg(tx_count_high,  'h11, "RO");
    default_map.add_reg(tx_count_low,   'h12, "RO");
    default_map.add_reg(rx_count_high,  'h13, "RO");
    default_map.add_reg(rx_count_low,   'h14, "RO");
    default_map.add_reg(irq_status_reg, 'h15, "RO");

    lock_model();
  endfunction

  function void set_scl_timeout(bit [23:0] t);
    scl_timeout2.timeout_byte.set(t[23:16]);
    scl_timeout1.timeout_byte.set(t[15:8]);
    scl_timeout0.timeout_byte.set(t[7:0]);
  endfunction

  function void set_sda_timeout(bit [23:0] t);
    sda_timeout2.timeout_byte.set(t[23:16]);
    sda_timeout1.timeout_byte.set(t[15:8]);
    sda_timeout0.timeout_byte.set(t[7:0]);
  endfunction

  task write_scl_timeout(bit [23:0] t,
                         output uvm_status_e status,
                         input uvm_path_e path = UVM_FRONTDOOR);
    scl_timeout2.write(status, t[23:16], path);
    scl_timeout1.write(status, t[15:8], path);
    scl_timeout0.write(status, t[7:0], path);
  endtask

  task write_sda_timeout(bit [23:0] t,
                         output uvm_status_e status,
                         input uvm_path_e path = UVM_FRONTDOOR);
    sda_timeout2.write(status, t[23:16], path);
    sda_timeout1.write(status, t[15:8], path);
    sda_timeout0.write(status, t[7:0], path);
  endtask

endclass


