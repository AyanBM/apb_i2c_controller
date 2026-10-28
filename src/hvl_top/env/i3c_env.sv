
`ifndef I3C_ENV_INCLUDED_
`define I3C_ENV_INCLUDED_

class i3c_env extends uvm_env;
  `uvm_component_utils(i3c_env)

  i3c_controller_agent i3c_controller_agent_h[];
  i3c_target_agent i3c_target_agent_h[];

  i3c_virtual_sequencer i3c_virtual_seqr_h;
  i3c_env_config i3c_env_cfg_h;
  i3c_scoreboard i3c_scoreboard_h;

  // APB environment and RAL handles
  apb_master_agent apb_master_agent_h;
  i2c_reg_block reg_model;
  apb_master_adapter apb_adapter;

  extern function new(string name = "i3c_env",
                      uvm_component parent = null);

  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);

endclass : i3c_env


function i3c_env::new(string name = "i3c_env",
                      uvm_component parent = null);
  super.new(name, parent);
endfunction : new


function void i3c_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (!uvm_config_db #(i3c_env_config)::get(
      this, "", "i3c_env_config", i3c_env_cfg_h)) begin
    `uvm_fatal("CONFIG",
      "Cannot get i3c_env_config from uvm_config_db")
  end

  // Create I3C controller agents
  i3c_controller_agent_h =
      new[i3c_env_cfg_h.no_of_controllers];

  foreach (i3c_controller_agent_h[i]) begin
    i3c_controller_agent_h[i] =
      i3c_controller_agent::type_id::create(
        $sformatf("i3c_controller_agent_h[%0d]", i), this);
  end

  // Create I3C target agents
  i3c_target_agent_h =
      new[i3c_env_cfg_h.no_of_targets];

  foreach (i3c_target_agent_h[i]) begin
    i3c_target_agent_h[i] =
      i3c_target_agent::type_id::create(
        $sformatf("i3c_target_agent_h[%0d]", i), this);
  end

  // Create virtual sequencer
  if (i3c_env_cfg_h.has_virtual_sequencer) begin
    i3c_virtual_seqr_h =
      i3c_virtual_sequencer::type_id::create(
        "i3c_virtual_seqr_h", this);
  end

  // Create scoreboard
  if (i3c_env_cfg_h.has_scoreboard) begin
    i3c_scoreboard_h =
      i3c_scoreboard::type_id::create(
        "i3c_scoreboard_h", this);
  end

  // Create APB environment
  apb_master_agent_h =
    apb_master_agent::type_id::create("apb_master_agent_h", this);

  // Create RAL register model
  reg_model =
    i2c_reg_block::type_id::create("reg_model");

  reg_model.build();
  reg_model.lock_model();

  // Create APB adapter
  apb_adapter =
    apb_master_adapter::type_id::create("apb_adapter");

endfunction : build_phase


function void i3c_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  // Connect I3C virtual sequencer and scoreboard
  if (i3c_env_cfg_h.has_virtual_sequencer) begin

    foreach (i3c_controller_agent_h[i]) begin
      i3c_virtual_seqr_h.i3c_controller_seqr_h =
        i3c_controller_agent_h[i].i3c_controller_seqr_h;

      if (i3c_env_cfg_h.has_scoreboard) begin
        i3c_controller_agent_h[i].
          i3c_controller_mon_proxy_h.
          controller_analysis_port.connect(
            i3c_scoreboard_h.controller_analysis_fifo.analysis_export);
      end
    end

    foreach (i3c_target_agent_h[i]) begin
      i3c_virtual_seqr_h.i3c_target_seqr_h =
        i3c_target_agent_h[i].i3c_target_seqr_h;

      if (i3c_env_cfg_h.has_scoreboard) begin
        i3c_target_agent_h[i].
          i3c_target_mon_proxy_h.
          target_analysis_port.connect(
            i3c_scoreboard_h.target_analysis_fifo.analysis_export);
      end
    end
  end

  // Connect RAL to APB master sequencer
  reg_model.default_map.set_sequencer(
    apb_master_agent_h.apb_master_seqr_h,
    apb_adapter
);

  // Enable automatic register prediction
  reg_model.default_map.set_auto_predict(1);

endfunction : connect_phase

`endif


