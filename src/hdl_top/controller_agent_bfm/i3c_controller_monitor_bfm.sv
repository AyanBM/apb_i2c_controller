`ifndef I3C_CONTROLLER_MONITOR_BFM_INCLUDED_
`define I3C_CONTROLLER_MONITOR_BFM_INCLUDED_

import i3c_globals_pkg::*;

interface i3c_controller_monitor_bfm(input pclk,
                                 input areset,
                                 input scl_i,
                                 input scl_o,
                                 input scl_oen,
                                 input sda_i,
                                 input sda_o,
                                 input sda_oen
                                );

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import i3c_controller_pkg::*;
  import i3c_controller_pkg::i3c_controller_monitor_proxy;

  i3c_controller_monitor_proxy i3c_controller_mon_proxy_h;
  i3c_fsm_state_e state;

  // [NEW] first data bit already sampled while deciding "data or repeated start" (10-bit)
  bit preValid;
  bit preBit;

  string name = "I3C_CONTROLLER_MONITOR_BFM";
  initial begin
    $display(name);
  end

  task wait_for_reset();
    @(negedge areset);
    @(posedge areset);
  endtask: wait_for_reset

  task sample_idle_state();
    @(posedge pclk);
    state <= IDLE;
  endtask: sample_idle_state

  task wait_for_idle_state();
    @(posedge pclk);
    while(scl_i!=1 && sda_i!=1) begin
     @(posedge pclk);
    end
    state = IDLE;
  endtask: wait_for_idle_state

  // [CHANGED] 7-bit flow unchanged. A first byte of the form 11110xx (10-bit header) selects the
  // 10-bit flow:  START | hdr(W) | ACK | A7..A0 | ACK | { data... | Sr | hdr(R) | ACK | data... }
  // A 10-bit read is reported as ONE transaction (operation = READ, full 10-bit address).
  task sample_data(inout i3c_transfer_bits_s struct_packet,input i3c_transfer_cfg_s struct_cfg);
    bit isSr;

    preValid = 1'b0;
    struct_packet.addressMode = I2C_ADDR_7BIT;
    struct_packet.targetAddressStatus2 = NACK;

    detect_start();
    sample_target_address(struct_packet);
    sample_operation(struct_packet.operation);
    sampleAddressAck(struct_packet.targetAddressStatus);

    if(struct_packet.targetAddress[6:0] >> 2 == 5'b11110) begin
      // ---------------- 10-bit ----------------
      struct_packet.addressMode = I2C_ADDR_10BIT;
      struct_packet.targetAddress = {struct_packet.targetAddress[1:0], 8'h00};

      if(struct_packet.targetAddressStatus == NACK) begin
        detect_stop();
      end else begin
        sample_address_byte2(struct_packet);
        sampleAddressAck(struct_packet.targetAddressStatus2);

        if(struct_packet.targetAddressStatus2 == NACK) begin
          struct_packet.targetAddressStatus = NACK;
          detect_stop();
        end else begin
          wait_data_or_repeated_start(isSr);
          if(isSr) begin
            // header again, read form
            sample_header_after_sr(struct_packet);
            if(struct_packet.targetAddressStatus == ACK && struct_packet.operation == READ) begin
              sampleReadDataAndACK(struct_packet, struct_cfg);
            end else begin
              detect_stop();
            end
          end else begin
            struct_packet.operation = WRITE;
            sampleWriteDataAndACK(struct_packet, struct_cfg);
          end
        end
      end
    end else begin
      // ---------------- 7-bit (unchanged) ----------------
      if(struct_packet.targetAddressStatus == ACK) begin
        if(struct_packet.operation == WRITE) begin
          sampleWriteDataAndACK(struct_packet, struct_cfg);
        end else begin
          sampleReadDataAndACK(struct_packet, struct_cfg);
          end
        end else begin
        detect_stop();
      end
    end
  endtask: sample_data


  task sampleWriteDataAndACK(inout i3c_transfer_bits_s structPacket,
                             input i3c_transfer_cfg_s structConfig);
    fork
      begin
        for(int i=0;i<MAXIMUM_BYTES;i++) begin
          sample_write_data(structPacket,
                            i,
                            structConfig.dataTransferDirection);
          sampleWdataAck(structPacket.writeDataStatus[i]);
          if(structPacket.writeDataStatus[i] == NACK)
            break;
        end
      end
    join_none

    wrDetect_stop();
    disable fork;
  endtask: sampleWriteDataAndACK


  task sampleReadDataAndACK(inout i3c_transfer_bits_s structPacket,
                             input i3c_transfer_cfg_s structConfig);
    fork
      begin
        for(int i=0;i<MAXIMUM_BYTES;i++) begin
          sample_read_data(structPacket,i,
                           structConfig.dataTransferDirection);
          sample_ack(structPacket.readDataStatus[i]);
          if(structPacket.readDataStatus[i] == NACK)
            break;
        end
      end
    join_none

    wrDetect_stop();
    disable fork;
  endtask: sampleReadDataAndACK


  task detect_start();
    bit [1:0] scl_local;
    bit [1:0] sda_local;
    state = START;

    do begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
      sda_local = {sda_local[0], sda_i};
    end while(!(sda_local == NEGEDGE && scl_local == 2'b11) );
  endtask: detect_start


  // samples the first 7 bits after START / Sr (the address, or the 10-bit header)
  task sample_target_address(inout i3c_transfer_bits_s pkt);
    bit [TARGET_ADDRESS_WIDTH-1:0] address;
    state = ADDRESS;
    for(int k=TARGET_ADDRESS_WIDTH-1;k>=0; k--) begin
      detectEdge_scl(POSEDGE);
      address[k] = sda_i;
    end
    pkt.targetAddress = address;
  endtask: sample_target_address


  // [NEW] 2nd address byte of a 10-bit address
  task sample_address_byte2(inout i3c_transfer_bits_s pkt);
    bit [7:0] b;
    state = ADDRESS;
    for(int k=7;k>=0; k--) begin
      detectEdge_scl(POSEDGE);
      b[k] = sda_i;
    end
    pkt.targetAddress[7:0] = b;
  endtask: sample_address_byte2


  // [NEW] after the ACK of the 2nd address byte: data byte (write) or repeated start (read)?
  //   SDA falls while SCL is still high -> repeated start
  //   SCL falls first                   -> the first bit of a data byte was already sampled
  task wait_data_or_repeated_start(output bit isSr);
    isSr     = 1'b0;
    preValid = 1'b0;

    detectEdge_scl(POSEDGE);
    preBit   = sda_i;
    preValid = 1'b1;

    forever begin
      @(negedge pclk);
      if(scl_i == 1'b0) break;
      if(sda_i == 1'b0 && preBit == 1'b1) begin
        isSr = 1'b1;
        break;
      end
    end
    if(isSr) preValid = 1'b0;
  endtask: wait_data_or_repeated_start


  // [NEW] header + R/W + ACK that follow the repeated start of a 10-bit read.
  // The 10-bit address already stored in pkt is kept; only the status and the direction are updated.
  task sample_header_after_sr(inout i3c_transfer_bits_s pkt);
    bit [TARGET_ADDRESS_WIDTH-1:0] hdr;
    state = ADDRESS;
    for(int k=TARGET_ADDRESS_WIDTH-1;k>=0; k--) begin
      detectEdge_scl(POSEDGE);
      hdr[k] = sda_i;
    end
    sample_operation(pkt.operation);
    sampleAddressAck(pkt.targetAddressStatus);
    if(hdr != {5'b11110, pkt.targetAddress[9:8]}) pkt.targetAddressStatus = NACK;
  endtask: sample_header_after_sr


  task sample_operation(output operationType_e wr_rd);
    bit operation;
    state = WR_BIT;
    detectEdge_scl(POSEDGE);
    operation = sda_i;
   if(operation == 0)
     wr_rd = WRITE;
   else
     wr_rd = READ;
  endtask: sample_operation


  task sampleAddressAck(output bit ack);
    state = ACK_NACK;
    detectEdge_scl(POSEDGE);
    ack = sda_i;
  endtask: sampleAddressAck


  task sample_write_data(inout i3c_transfer_bits_s pkt, input int i, input dataTransferDirection_e dir);
    bit[DATA_WIDTH-1:0] wdata;
    state = WRITE_DATA;
    `uvm_info("Controller_Monitor_BFM", $sformatf("Direction %s", dir.name()), UVM_HIGH);
    for(int k=0, bit_no=0; k<DATA_WIDTH; k++) begin
      // Logic for MSB first or LSB first
      bit_no = (dir == MSB_FIRST) ?
                ((DATA_WIDTH - 1) - k) : k;

      if(preValid) begin                       // [NEW] first bit already sampled
        wdata[bit_no] = preBit;
        preValid = 1'b0;
      end else begin
        detectEdge_scl(POSEDGE);
        wdata[bit_no] = sda_i;
      end
      pkt.no_of_i3c_bits_transfer++;
    end
    pkt.writeData[i] = wdata;
  endtask: sample_write_data


  task sampleWdataAck(output bit ack);
    state = ACK_NACK;
    detectEdge_scl(POSEDGE);
    ack = sda_i;
  endtask: sampleWdataAck


  task sample_read_data(inout i3c_transfer_bits_s pkt,input int i, input dataTransferDirection_e dir);
    bit [DATA_WIDTH-1:0] rdata;
    state = READ_DATA;
    for(int k=0, bit_no=0; k<DATA_WIDTH; k++) begin
      // Logic for MSB first or LSB first
      bit_no = (dir == MSB_FIRST) ?
                ((DATA_WIDTH - 1) - k) : k;

      detectEdge_scl(POSEDGE);
      rdata[bit_no] = sda_i;
      pkt.no_of_i3c_bits_transfer++;
    end
    pkt.readData[i] = rdata;
  endtask :sample_read_data


  task sample_ack(output bit ack);
    state    = ACK_NACK;
    detectEdge_scl(POSEDGE);
    ack = sda_i;
  endtask :sample_ack


  task wrDetect_stop();
    // 2bit shift register to check the edge on sda and stability on scl
    bit [1:0] scl_local;
    bit [1:0] sda_local;

    do begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
      sda_local = {sda_local[0], sda_i};
    end while(!(sda_local == POSEDGE && scl_local == 2'b11) );
    state = STOP;
    `uvm_info(name, $sformatf("Stop condition is detected"), UVM_HIGH);
  endtask: wrDetect_stop


  task detect_stop();
    bit [1:0] scl_local;
    bit [1:0] sda_local;
    state = STOP;

    do begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
      sda_local = {sda_local[0], sda_i};
    end while(!(sda_local == POSEDGE && scl_local == 2'b11) );
  endtask: detect_stop


  task detectEdge_scl(input edge_detect_e edgeSCL);
    // 2bit shift register to check the edge on scl
    bit [1:0] scl_local;
    edge_detect_e scl_edge_value;
    // default value of scl_local is logic 1
    scl_local = 2'b11;

    do begin
      @(negedge pclk);
      scl_local = {scl_local[0], scl_i};
    end while(!(scl_local == edgeSCL));

    scl_edge_value = edge_detect_e'(scl_local);
    `uvm_info("TARGET_DRIVER_BFM", $sformatf("scl %s detected", scl_edge_value.name()), UVM_HIGH);
  endtask: detectEdge_scl

endinterface : i3c_controller_monitor_bfm

`endif

