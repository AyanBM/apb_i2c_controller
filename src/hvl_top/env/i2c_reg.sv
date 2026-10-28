
`ifndef I2C_REG_WIDTH
  `define I2C_REG_WIDTH 8
`endif

// --------------------------------------------------
// I2C_SLAVE_ADDRESS_HIGH: 0x00
// I2C_SLAVE_SELF_ADDRESS_HIGH: 0x0C
// --------------------------------------------------
class i2c_addrh_reg extends uvm_reg;
  `uvm_object_utils(i2c_addrh_reg)

  rand uvm_reg_field addr_h;

  function new(string name = "i2c_addrh_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    addr_h = uvm_reg_field::type_id::create("addr_h");
    addr_h.configure(this, 2, 0, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// I2C_SLAVE_ADDRESS_LOW: 0x01
// I2C_SLAVE_SELF_ADDRESS_LOW: 0x0D
// --------------------------------------------------
class i2c_addrl_reg extends uvm_reg;
  `uvm_object_utils(i2c_addrl_reg)

  rand uvm_reg_field addr_l;

  function new(string name = "i2c_addrl_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    addr_l = uvm_reg_field::type_id::create("addr_l");
    addr_l.configure(this, 8, 0, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// MODE: 0x02
// --------------------------------------------------
class i2c_mode_reg extends uvm_reg;
  `uvm_object_utils(i2c_mode_reg)

  rand uvm_reg_field role;
  rand uvm_reg_field speed;
  rand uvm_reg_field addr_type;

  function new(string name = "i2c_mode_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    addr_type = uvm_reg_field::type_id::create("addr_type");
    addr_type.configure(this, 1, 0, "WO", 0, 0, 1, 1, 0);

    speed = uvm_reg_field::type_id::create("speed");
    speed.configure(this, 2, 1, "WO", 0, 0, 1, 1, 0);

    role = uvm_reg_field::type_id::create("role");
    role.configure(this, 1, 3, "WO", 0, 0, 1, 1, 0);
  endfunction

  function void set_mode(bit master, bit [1:0] spd,
                         bit addr_10bit);
    role.set(master);
    speed.set(spd);
    addr_type.set(addr_10bit);
  endfunction
endclass


// --------------------------------------------------
// SCL_TIMEOUT2/1/0 and SDA_TIMEOUT2/1/0
// Addresses: 0x03 through 0x08
// --------------------------------------------------
class i2c_timeout_reg extends uvm_reg;
  `uvm_object_utils(i2c_timeout_reg)

  rand uvm_reg_field timeout_byte;

  function new(string name = "i2c_timeout_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    timeout_byte = uvm_reg_field::type_id::create("timeout_byte");
    timeout_byte.configure(this, 8, 0, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// TX_DATA: 0x09
// --------------------------------------------------
class i2c_tx_data_reg extends uvm_reg;
  `uvm_object_utils(i2c_tx_data_reg)

  rand uvm_reg_field tx_data;

  function new(string name = "i2c_tx_data_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    tx_data = uvm_reg_field::type_id::create("tx_data");
    tx_data.configure(this, 8, 0, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// RX_DATA: 0x0A
// Write triggers a CMD_RX request.
// --------------------------------------------------
class i2c_rx_data_reg extends uvm_reg;
  `uvm_object_utils(i2c_rx_data_reg)

  rand uvm_reg_field rx_req;

  function new(string name = "i2c_rx_data_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    rx_req = uvm_reg_field::type_id::create("rx_req");
    rx_req.configure(this, 8, 0, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// IRQ_CLEAR: 0x0B
// --------------------------------------------------
class i2c_irq_clear_reg extends uvm_reg;
  `uvm_object_utils(i2c_irq_clear_reg)

  rand uvm_reg_field clr_illegal_access;
  rand uvm_reg_field clr_nack;
  rand uvm_reg_field clr_arb_lost;
  rand uvm_reg_field clr_rx_fifo_empty;

  function new(string name = "i2c_irq_clear_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    clr_illegal_access =
      uvm_reg_field::type_id::create("clr_illegal_access");
    clr_illegal_access.configure(this, 1, 0, "WO", 0, 0, 1, 1, 0);

    clr_nack = uvm_reg_field::type_id::create("clr_nack");
    clr_nack.configure(this, 1, 1, "WO", 0, 0, 1, 1, 0);

    clr_arb_lost = uvm_reg_field::type_id::create("clr_arb_lost");
    clr_arb_lost.configure(this, 1, 2, "WO", 0, 0, 1, 1, 0);

    clr_rx_fifo_empty =
      uvm_reg_field::type_id::create("clr_rx_fifo_empty");
    clr_rx_fifo_empty.configure(this, 1, 3, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// MAX_GLITCH_COUNT: 0x0E
// --------------------------------------------------
class i2c_glitch_reg extends uvm_reg;
  `uvm_object_utils(i2c_glitch_reg)

  rand uvm_reg_field max_glitch;

  function new(string name = "i2c_glitch_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    max_glitch = uvm_reg_field::type_id::create("max_glitch");
    max_glitch.configure(this, 8, 0, "WO", 0, 0, 1, 1, 0);
  endfunction
endclass


// --------------------------------------------------
// RX_FIFO: 0x10
// Read pops one byte from the FIFO.
// --------------------------------------------------
class i2c_rx_fifo_reg extends uvm_reg;
  `uvm_object_utils(i2c_rx_fifo_reg)

  uvm_reg_field rx_data;

  function new(string name = "i2c_rx_fifo_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    rx_data = uvm_reg_field::type_id::create("rx_data");
    rx_data.configure(this, 8, 0, "RO", 1, 0, 1, 0, 0);
  endfunction
endclass


// --------------------------------------------------
// TX_COUNT_HIGH/LOW and RX_COUNT_HIGH/LOW
// Addresses: 0x11 through 0x14
// --------------------------------------------------
class i2c_count_reg extends uvm_reg;
  `uvm_object_utils(i2c_count_reg)

  uvm_reg_field count;

  function new(string name = "i2c_count_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    count = uvm_reg_field::type_id::create("count");
    count.configure(this, 8, 0, "RO", 1, 0, 1, 0, 0);
  endfunction
endclass


// --------------------------------------------------
// IRQ_STATUS: 0x15
// --------------------------------------------------
class i2c_irq_status_reg extends uvm_reg;
  `uvm_object_utils(i2c_irq_status_reg)

  uvm_reg_field sda_hung;
  uvm_reg_field bus_busy;
  uvm_reg_field scl_hung;
  uvm_reg_field arb_lost;
  uvm_reg_field nack;
  uvm_reg_field illegal_access;
  uvm_reg_field cmd_fifo_full;
  uvm_reg_field rx_fifo_empty;

  function new(string name = "i2c_irq_status_reg");
    super.new(name, `I2C_REG_WIDTH, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    sda_hung = uvm_reg_field::type_id::create("sda_hung");
    sda_hung.configure(this, 1, 0, "RO", 1, 0, 1, 0, 0);

    bus_busy = uvm_reg_field::type_id::create("bus_busy");
    bus_busy.configure(this, 1, 1, "RO", 1, 0, 1, 0, 0);

    scl_hung = uvm_reg_field::type_id::create("scl_hung");
    scl_hung.configure(this, 1, 2, "RO", 1, 0, 1, 0, 0);

    arb_lost = uvm_reg_field::type_id::create("arb_lost");
    arb_lost.configure(this, 1, 3, "RO", 1, 0, 1, 0, 0);

    nack = uvm_reg_field::type_id::create("nack");
    nack.configure(this, 1, 4, "RO", 1, 0, 1, 0, 0);

    illegal_access = uvm_reg_field::type_id::create("illegal_access");
    illegal_access.configure(this, 1, 5, "RO", 1, 0, 1, 0, 0);

    cmd_fifo_full = uvm_reg_field::type_id::create("cmd_fifo_full");
    cmd_fifo_full.configure(this, 1, 6, "RO", 1, 0, 1, 0, 0);

    rx_fifo_empty = uvm_reg_field::type_id::create("rx_fifo_empty");
    rx_fifo_empty.configure(this, 1, 7, "RO", 1, 0, 1, 0, 0);
  endfunction
endclass

/*
// ==================================================
// I2C REGISTER BLOCK
// ==================================================
class i2c_reg_block extends uvm_reg_block;
  `uvm_object_utils(i2c_reg_block)

  i2c_addrh_reg          slv_addrh;
  i2c_addrl_reg          slv_addrl;
  i2c_mode_reg           mode_reg;

  i2c_timeout_reg        scl_timeout2;
  i2c_timeout_reg        scl_timeout1;
  i2c_timeout_reg        scl_timeout0;
  i2c_timeout_reg        sda_timeout2;
  i2c_timeout_reg        sda_timeout1;
  i2c_timeout_reg        sda_timeout0;

  i2c_tx_data_reg        tx_data_reg;
  i2c_rx_data_reg        rx_data_reg;
  i2c_irq_clear_reg      irq_clear_reg;

  i2c_addrh_reg          slv_self_addrh;
  i2c_addrl_reg          slv_self_addrl;
  i2c_glitch_reg         glitch_reg;

  i2c_rx_fifo_reg        rx_fifo_reg;
  i2c_count_reg          tx_count_high;
  i2c_count_reg          tx_count_low;
  i2c_count_reg          rx_count_high;
  i2c_count_reg          rx_count_low;
  i2c_irq_status_reg     irq_status_reg;

  uvm_reg_map default_map;

  function new(string name = "i2c_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();

    // Create register instances
    slv_addrh = i2c_addrh_reg::type_id::create("slv_addrh");
    slv_addrh.configure(this);
    slv_addrh.build();

    slv_addrl = i2c_addrl_reg::type_id::create("slv_addrl");
    slv_addrl.configure(this);
    slv_addrl.build();

    mode_reg = i2c_mode_reg::type_id::create("mode_reg");
    mode_reg.configure(this);
    mode_reg.build();

    scl_timeout2 = i2c_timeout_reg::type_id::create("scl_timeout2");
    scl_timeout2.configure(this);
    scl_timeout2.build();

    scl_timeout1 = i2c_timeout_reg::type_id::create("scl_timeout1");
    scl_timeout1.configure(this);
    scl_timeout1.build();

    scl_timeout0 = i2c_timeout_reg::type_id::create("scl_timeout0");
    scl_timeout0.configure(this);
    scl_timeout0.build();

    sda_timeout2 = i2c_timeout_reg::type_id::create("sda_timeout2");
    sda_timeout2.configure(this);
    sda_timeout2.build();

    sda_timeout1 = i2c_timeout_reg::type_id::create("sda_timeout1");
    sda_timeout1.configure(this);
    sda_timeout1.build();

    sda_timeout0 = i2c_timeout_reg::type_id::create("sda_timeout0");
    sda_timeout0.configure(this);
    sda_timeout0.build();

    tx_data_reg = i2c_tx_data_reg::type_id::create("tx_data_reg");
    tx_data_reg.configure(this);
    tx_data_reg.build();

    rx_data_reg = i2c_rx_data_reg::type_id::create("rx_data_reg");
    rx_data_reg.configure(this);
    rx_data_reg.build();

    irq_clear_reg = i2c_irq_clear_reg::type_id::create("irq_clear_reg");
    irq_clear_reg.configure(this);
    irq_clear_reg.build();

    slv_self_addrh = i2c_addrh_reg::type_id::create("slv_self_addrh");
    slv_self_addrh.configure(this);
    slv_self_addrh.build();

    slv_self_addrl = i2c_addrl_reg::type_id::create("slv_self_addrl");
    slv_self_addrl.configure(this);
    slv_self_addrl.build();

    glitch_reg = i2c_glitch_reg::type_id::create("glitch_reg");
    glitch_reg.configure(this);
    glitch_reg.build();

    rx_fifo_reg = i2c_rx_fifo_reg::type_id::create("rx_fifo_reg");
    rx_fifo_reg.configure(this);
    rx_fifo_reg.build();

    tx_count_high = i2c_count_reg::type_id::create("tx_count_high");
    tx_count_high.configure(this);
    tx_count_high.build();

    tx_count_low = i2c_count_reg::type_id::create("tx_count_low");
    tx_count_low.configure(this);
    tx_count_low.build();

    rx_count_high = i2c_count_reg::type_id::create("rx_count_high");
    rx_count_high.configure(this);
    rx_count_high.build();

    rx_count_low = i2c_count_reg::type_id::create("rx_count_low");
    rx_count_low.configure(this);
    rx_count_low.build();

    irq_status_reg =
      i2c_irq_status_reg::type_id::create("irq_status_reg");
    irq_status_reg.configure(this);
    irq_status_reg.build();

    // Byte-addressed map: use only if the APB adapter and DUT
    // support byte-wide register accesses at these offsets.
    default_map = create_map(
      "default_map", 'h0, 1, UVM_LITTLE_ENDIAN, 1
    );

    default_map.add_reg(slv_addrh,       'h00, "WO");
    default_map.add_reg(slv_addrl,       'h01, "WO");
    default_map.add_reg(mode_reg,        'h02, "WO");

    default_map.add_reg(scl_timeout2,    'h03, "WO");
    default_map.add_reg(scl_timeout1,    'h04, "WO");
    default_map.add_reg(scl_timeout0,    'h05, "WO");

    default_map.add_reg(sda_timeout2,    'h06, "WO");
    default_map.add_reg(sda_timeout1,    'h07, "WO");
    default_map.add_reg(sda_timeout0,    'h08, "WO");

    default_map.add_reg(tx_data_reg,     'h09, "WO");
    default_map.add_reg(rx_data_reg,     'h0A, "WO");
    default_map.add_reg(irq_clear_reg,   'h0B, "WO");

    default_map.add_reg(slv_self_addrh,  'h0C, "WO");
    default_map.add_reg(slv_self_addrl,  'h0D, "WO");
    default_map.add_reg(glitch_reg,      'h0E, "WO");

    default_map.add_reg(rx_fifo_reg,     'h10, "RO");
    default_map.add_reg(tx_count_high,   'h11, "RO");
    default_map.add_reg(tx_count_low,    'h12, "RO");
    default_map.add_reg(rx_count_high,   'h13, "RO");
    default_map.add_reg(rx_count_low,    'h14, "RO");
    default_map.add_reg(irq_status_reg,  'h15, "RO");

    lock_model();
  endfunction
endclass
*/
