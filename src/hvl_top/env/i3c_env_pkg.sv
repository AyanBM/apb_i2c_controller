
`ifndef I3C_ENV_PKG_INCLUDED_
`define I3C_ENV_PKG_INCLUDED_

package i3c_env_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import i3c_globals_pkg::*;
  import i3c_controller_pkg::*;
  import i3c_target_pkg::*;
  import apb_master_pkg::*;
  // Environment configuration
  `include "i3c_env_config.sv"

  // RAL register classes
  `include "i2c_reg.sv"

  // RAL register block
  `include "regblock.sv"

  // APB RAL adapter
  


  // Virtual sequencer and scoreboard
  `include "i3c_virtual_sequencer.sv"
  `include "i3c_scoreboard.sv"
 

  // Environment
  `include "i3c_env.sv"

endpackage : i3c_env_pkg

`endif

