`ifndef I3C_TARGET_DRIVER_BFM_INCLUDED_
`define I3C_TARGET_DRIVER_BFM_INCLUDED_

import i3c_globals_pkg::*;
interface i3c_target_driver_bfm(input pclk,
                               input areset,
                               input scl_i,
                               output reg scl_o,
                               output reg scl_oen,
                               input sda_i,
                               output reg sda_o,
                               output reg sda_oen
                             );

  i3c_fsm_state_e state;
  bit [7:0] rdata;
  bit [1:0] scl_local = 2'b11;

  // [NEW] first data bit that was already sampled while deciding "data or repeated start"
  bit preValid;
  bit preBit;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import i3c_target_pkg::i3c_target_driver_proxy;

  i3c_target_driver_proxy i3c_target_drv_proxy_h;

  //-------------------------------------------------------
  // Creating the memory
  //-------------------------------------------------------
  bit [DATA_WIDTH-1:0]targetFIFOMemory[$];

  string name = "I3C_TARGET_DRIVER_BFM";
  initial begin
    $display(name);
  end

  task wait_for_system_reset();
    state = RESET_DEACTIVATED;
    @(negedge areset);
    state = RESET_ACTIVATED;
    @(posedge areset);
    state = RESET_DEACTIVATED;
  endtask: wait_for_system_reset


  task drive_idle_state();
    @(posedge pclk);
    drive_scl(1);
    drive_sda(1);
    state <= IDLE;
  endtask: drive_idle_state


  task wait_for_idle_state();
    @(posedge pclk);
    while(scl_i!=1 && sda_i!=1) begin
      @(posedge pclk);
    end
    state = IDLE;
    `uvm_info(name, $sformatf("I3C bus is free state detected"), UVM_HIGH);
  endtask: wait_for_idle_state


  // [CHANGED] 7-bit flow unchanged; 10-bit flow added
  task drive_data(inout i3c_transfer_bits_s dataPacketStruck,
                  input i3c_transfer_cfg_s configPacketStruck);
    bit isSr;

    preValid = 1'b0;
    dataPacketStruck.addressMode = configPacketStruck.addressMode;
    dataPacketStruck.targetAddressStatus2 = NACK;

    detect_start();
    sample_target_address(configPacketStruck,dataPacketStruck);
    sample_operation(dataPacketStruck.operation);

    // [NEW] a read header is only accepted after a matching write header + 2nd byte + Sr,
    // which is handled below, so a read header straight after START is NACKed in 10-bit mode
    if(configPacketStruck.addressMode == I2C_ADDR_10BIT && dataPacketStruck.operation == READ)
      dataPacketStruck.targetAddressStatus = NACK;

    driveAddressAck(dataPacketStruck.targetAddressStatus);

    if(configPacketStruck.addressMode == I2C_ADDR_10BIT && dataPacketStruck.targetAddressStatus == ACK) begin
      // ---- 10-bit: header (write form) matched, now the 2nd address byte
      sample_address_byte2(configPacketStruck, dataPacketStruck);
      driveAddressAck(dataPacketStruck.targetAddressStatus2);

      if(dataPacketStruck.targetAddressStatus2 == NACK) begin
        dataPacketStruck.targetAddressStatus = NACK;
        detect_stop();
        return;
      end

      // after the 2nd byte either data (write) or a repeated start (read) follows
      wait_data_or_repeated_start(isSr);
      if(isSr) begin
        sample_target_address(configPacketStruck,dataPacketStruck);        // header again, R form
        sample_operation(dataPacketStruck.operation);
        if(dataPacketStruck.operation != READ) dataPacketStruck.targetAddressStatus = NACK;
        driveAddressAck(dataPacketStruck.targetAddressStatus);
        if(dataPacketStruck.targetAddressStatus == ACK) begin
          driveReadDataAndSampleACK(dataPacketStruck, configPacketStruck);
        end else begin
          detect_stop();
        end
      end else begin
        dataPacketStruck.operation = WRITE;
        sampleWriteDataAndDriveACK(dataPacketStruck, configPacketStruck);
      end
    end else if(dataPacketStruck.targetAddressStatus == ACK) begin
      // ---- 7-bit (unchanged)
      if(dataPacketStruck.operation == WRITE) begin
        sampleWriteDataAndDriveACK(dataPacketStruck,
                                   configPacketStruck);
      end else begin
        driveReadDataAndSampleACK(dataPacketStruck,
                                  configPacketStruck);
      end
    end else begin
      detect_stop();
    end
  endtask: drive_data


  task sampleWriteDataAndDriveACK(inout i3c_transfer_bits_s dataPacketStruck,
                                  input i3c_transfer_cfg_s configPacketStruck);
    fork
      begin
        for(int i=0;i<MAXIMUM_BYTES;i++) begin
          sample_write_data(configPacketStruck,dataPacketStruck,i);
          driveWdataAck(dataPacketStruck.writeDataStatus[i]);
          if(dataPacketStruck.writeDataStatus[i] == NACK)
            break;
        end
      end
    join_none

    wrDetect_stop();
    disable fork;
  endtask: sampleWriteDataAndDriveACK


  task driveReadDataAndSampleACK(inout i3c_transfer_bits_s dataPacketStruck,
                                 input i3c_transfer_cfg_s configPacketStruck);
    fork
      begin
        for(int i=0;i<MAXIMUM_BYTES;i++) begin
          if(targetFIFOMemory.size()==0) begin
            rdata = configPacketStruck.defaultReadData;
          end else begin
            rdata = targetFIFOMemory.pop_front();
          end

          drive_read_data(rdata,
                          dataPacketStruck,i,
                          configPacketStruck.dataTransferDirection);

          sample_ack(dataPacketStruck.readDataStatus[i]);
          if(dataPacketStruck.readDataStatus[i] == NACK)
            break;
        end
      end
    join_none

    wrDetect_stop();
    disable fork;
  endtask: driveReadDataAndSampleACK


  task detect_start();
    // 2bit shift register to check the edge on sda and stability on scl
    bit [1:0] scl_local;
    bit [1:0] sda_local;

    state = START;
    do begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
      sda_local = {sda_local[0], sda_i};
    end while(!(sda_local == NEGEDGE && scl_local == 2'b11) );
    `uvm_info(name, $sformatf("Start condition is detected"), UVM_HIGH);
  endtask: detect_start


  // [CHANGED] samples the first 7 bits after START / Sr.
  //   7-bit : the whole address         -> compared with cfg.targetAddress[6:0]
  //   10-bit: 11110 A9 A8 (the header)  -> compared with {11110, cfg.targetAddress[9:8]}
  task sample_target_address(input i3c_transfer_cfg_s cfg_pkt, inout i3c_transfer_bits_s pkt);
    bit [TARGET_ADDRESS_WIDTH-1:0] local_addr;

    state = ADDRESS;
    for(int k=TARGET_ADDRESS_WIDTH-1;k>=0; k--) begin
      detectEdge_scl(POSEDGE);
      local_addr[k] = sda_i;
      drive_sda(1);
    end

    `uvm_info(name, $sformatf("DEBUG :: Value of local_addr = %0x", local_addr[6:0]), UVM_NONE);

    if(cfg_pkt.addressMode == I2C_ADDR_7BIT) begin
      pkt.targetAddress = local_addr;                       // upper bits become 0
      `uvm_info(name, $sformatf("DEBUG :: Value of target_address = %0x", cfg_pkt.targetAddress), UVM_NONE);
      if(local_addr != cfg_pkt.targetAddress[6:0]) begin
        pkt.targetAddressStatus = NACK;
      end
      else begin
        pkt.targetAddressStatus = ACK;
      end
    end else begin
      pkt.targetAddress[9:8] = local_addr[1:0];
      if(local_addr[6:2] == 5'b11110 && local_addr[1:0] == cfg_pkt.targetAddress[9:8]) begin
        pkt.targetAddressStatus = ACK;
      end else begin
        pkt.targetAddressStatus = NACK;
      end
    end
  endtask: sample_target_address


  // [NEW] 2nd address byte of a 10-bit address
  task sample_address_byte2(input i3c_transfer_cfg_s cfg_pkt, inout i3c_transfer_bits_s pkt);
    bit [7:0] b;

    state = ADDRESS;
    for(int k=7;k>=0; k--) begin
      detectEdge_scl(POSEDGE);
      b[k] = sda_i;
      drive_sda(1);
    end
    pkt.targetAddress[7:0] = b;
    pkt.targetAddressStatus2 = (b == cfg_pkt.targetAddress[7:0]) ? ACK : NACK;
    `uvm_info(name, $sformatf("DEBUG :: 10-bit low byte = %0x, expected %0x", b, cfg_pkt.targetAddress[7:0]), UVM_NONE);
  endtask: sample_address_byte2


  // [NEW] after the ACK of the 2nd address byte: is the next thing a data byte (write) or a
  // repeated start (read)?  Look at the first SCL rise:
  //   SDA falls while SCL is still high -> repeated start
  //   SCL falls first                   -> that was the first (MSB-side) bit of a data byte
  task wait_data_or_repeated_start(output bit isSr);
    isSr     = 1'b0;
    preValid = 1'b0;

    detectEdge_scl(POSEDGE);
    preBit   = sda_i;
    preValid = 1'b1;

    forever begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
      if(scl_i == 1'b0) break;                              // data bit
      if(sda_i == 1'b0 && preBit == 1'b1) begin             // SDA fell while SCL high
        isSr = 1'b1;
        break;
      end
    end
    if(isSr) begin
      preValid = 1'b0;
      `uvm_info(name, $sformatf("Repeated start is detected"), UVM_HIGH);
    end
  endtask: wait_data_or_repeated_start


  task sample_operation(output operationType_e wr_rd);
    bit operation;

    state = WR_BIT;
    detectEdge_scl(POSEDGE);
    operation = sda_i;
    drive_sda(1);

    if(operation == 1'b0) begin
      wr_rd = WRITE;
    end else begin
      wr_rd = READ;
    end
  endtask: sample_operation


  task driveAddressAck(input bit ack);
    state = ACK_NACK;
    detectEdge_scl(NEGEDGE);
    drive_sda(ack);
    detectEdge_scl(NEGEDGE);
    drive_sda(1);
  endtask: driveAddressAck


  task sample_write_data(input i3c_transfer_cfg_s cfg_pkt, inout i3c_transfer_bits_s pkt, input int i);
    bit [DATA_WIDTH-1:0] wdata;
    state = WRITE_DATA;

    `uvm_info("DEBUG_TARGET_DRIVER_BFM", $sformatf("dir %s ",cfg_pkt.dataTransferDirection.name()), UVM_HIGH);
    for(int k=0, bit_no = 0; k<DATA_WIDTH; k++) begin
      // Logic for MSB first or LSB first
      bit_no = (cfg_pkt.dataTransferDirection == MSB_FIRST) ?
                ((DATA_WIDTH - 1) - k) : k;

      if(preValid) begin                                    // [NEW] first bit already sampled
        wdata[bit_no] = preBit;
        preValid = 1'b0;
      end else begin
        detectEdge_scl(POSEDGE);
        wdata[bit_no] = sda_i;
      end
      pkt.no_of_i3c_bits_transfer++;
    end

    `uvm_info(name, $sformatf("DEBUG :: Value of sampled write data = %0x", wdata[7:0]), UVM_NONE);
    targetFIFOMemory.push_back(wdata);
    `uvm_info("DEBUG_READ", $sformatf("size of write fifo = %0d",
                                       targetFIFOMemory.size()), UVM_HIGH);

    pkt.writeData[i] = wdata;
  endtask: sample_write_data


  task driveWdataAck(input bit ack);
    state = ACK_NACK;
    detectEdge_scl(NEGEDGE);
    drive_sda(ack);
    detectEdge_scl(NEGEDGE);
    drive_sda(1);
  endtask: driveWdataAck


  task drive_read_data(input bit[7:0] rdata,inout i3c_transfer_bits_s pkt,input int i, input dataTransferDirection_e dir);
    `uvm_info("DEBUG", $sformatf("Driving byte = %0b",rdata), UVM_NONE)
    state = READ_DATA;
    for(int k=0, bit_no = 0; k<DATA_WIDTH; k++) begin
      // Logic for MSB first or LSB first
      bit_no = (dir == MSB_FIRST) ?
                ((DATA_WIDTH - 1) - k) : k;

      drive_sda(rdata[bit_no]);
      pkt.no_of_i3c_bits_transfer++;
      detectEdge_scl(NEGEDGE);
    end
    pkt.readData[i] = rdata;
    drive_sda(1);
  endtask :drive_read_data


  task sample_ack(output bit ack);
    state    = ACK_NACK;
    detectEdge_scl(POSEDGE);
    ack     = sda_i;
    detectEdge_scl(NEGEDGE);
  endtask :sample_ack


  task wrDetect_stop();
    // 2bit shift register to check the edge on sda and stability on scl
    bit [1:0] scl_local;
    bit [1:0] sda_local;

    do begin
      @(negedge pclk);
      #1;
      scl_local = {scl_local[0], scl_i};
      sda_local = {sda_local[0], sda_i};
    end while(!(sda_local == POSEDGE && scl_local == 2'b11) );
    state = STOP;
    `uvm_info(name, $sformatf("Stop condition is detected"), UVM_HIGH);
  endtask: wrDetect_stop


  task detect_stop();
    // 2bit shift register to check the edge on sda and stability on scl
    bit [1:0] scl_local;
    bit [1:0] sda_local;

    state = STOP;
    do begin
      @(negedge pclk);
      #1;
      scl_local = {scl_local[0], scl_i};
      sda_local = {sda_local[0], sda_i};
    end while(!(sda_local == POSEDGE && scl_local == 2'b11) );
    `uvm_info(name, $sformatf("Stop condition is detected"), UVM_HIGH);
  endtask: detect_stop


  task drive_sda(input bit value);
    sda_oen <= value ? TRISTATE_BUF_OFF : TRISTATE_BUF_ON;
    sda_o   <= value;
  endtask: drive_sda


  task drive_scl(input bit value);
    scl_oen <= value ? TRISTATE_BUF_OFF : TRISTATE_BUF_ON;
    scl_o   <= value;
  endtask: drive_scl


  task detectEdge_scl(input edge_detect_e edgeSCL);
    // scl_local 2bit shift register to check the edge on scl
    edge_detect_e scl_edge_value;

    do begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
    end while(!(scl_local == edgeSCL));

    scl_edge_value = edge_detect_e'(scl_local);
    `uvm_info("TARGET_DRIVER_BFM", $sformatf("scl %s detected", scl_edge_value.name()), UVM_HIGH);
  endtask: detectEdge_scl

endinterface : i3c_target_driver_bfm

`endif
