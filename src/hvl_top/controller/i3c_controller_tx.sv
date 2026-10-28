
`ifndef I3C_CONTROLLER_TX_INCLUDED_
`define I3C_CONTROLLER_TX_INCLUDED_

class i3c_controller_tx extends uvm_sequence_item;
  `uvm_object_utils(i3c_controller_tx)

  // Reserved 8 address for first group 0000_XXX
  typedef enum bit[6:0] {
    GRP0_RSVD0 = 7'b0000_000,
    GRP0_RSVD1 = 7'b0000_001,
    GRP0_RSVD2 = 7'b0000_010,
    GRP0_RSVD3 = 7'b0000_011,
    GRP0_RSVD4 = 7'b0000_100,
    GRP0_RSVD5 = 7'b0000_101,
    GRP0_RSVD6 = 7'b0000_110,
    GRP0_RSVD7 = 7'b0000_111
  } group0_e;

  // Reserved 8 address for second group 1111_XXX
  typedef enum bit[6:0] {
    GRP1_RSVD0 = 7'b1111_000,
    GRP1_RSVD1 = 7'b1111_001,
    GRP1_RSVD2 = 7'b1111_010,
    GRP1_RSVD3 = 7'b1111_011,
    GRP1_RSVD4 = 7'b1111_100,
    GRP1_RSVD5 = 7'b1111_101,
    GRP1_RSVD6 = 7'b1111_110,
    GRP1_RSVD7 = 7'b1111_111
  } group1_e;

  rand operationType_e operation;
  // [CHANGED] widened: 7-bit mode uses targetAddress[6:0], 10-bit mode uses [9:0]
  rand bit [I2C_MAX_ADDRESS_WIDTH-1:0] targetAddress;
  // [NEW] 7-bit or 10-bit addressing for this transfer
  rand i2c_address_mode_e addressMode;
  rand bit [DATA_WIDTH-1:0] writeData[];
  rand acknowledge_e readDataStatus[];

       bit [DATA_WIDTH-1:0] readData[];
       acknowledge_e targetAddressStatus;
       // [NEW] ACK of the 2nd address byte (10-bit only)
       acknowledge_e targetAddressStatus2;
       acknowledge_e writeDataStatus[];

  //-------------------------------------------------------
  // Constraints
  //-------------------------------------------------------

  // [NEW] 7-bit is the default so every existing sequence keeps working.
  // A sequence selects 10-bit with:  randomize() with {addressMode == I2C_ADDR_10BIT;}
  constraint addressModeDefault_c {
    soft addressMode == I2C_ADDR_7BIT;
  }

  // [CHANGED] 7-bit: upper bits must be 0 and the address must not be a reserved one.
  //           10-bit: any value is legal (0x000..0x3FF).
  constraint addressRange_c {
    if (addressMode == I2C_ADDR_7BIT) {
      targetAddress[I2C_MAX_ADDRESS_WIDTH-1:7] == 0;
    }
  }

  constraint reservedTargetAddressGroup0_c {
    if (addressMode == I2C_ADDR_7BIT)
      !(targetAddress[6:0] inside {[GRP0_RSVD0 : GRP0_RSVD7]});
  }

  constraint reservedTargetAddressGroup1_c {
    if (addressMode == I2C_ADDR_7BIT)
      !(targetAddress[6:0] inside {[GRP1_RSVD0 : GRP1_RSVD7]});
  }


  constraint writeDataSize_c {
    writeData.size() <= MAXIMUM_BYTES;
  }

  constraint readDataStatusSize_c {
    readDataStatus.size() <= MAXIMUM_BYTES;
  }

  constraint readDataStatusValue_c{foreach(readDataStatus[i])
                                      soft readDataStatus[i] == ACK;}

  constraint operationWRITExwriteDataSize_c {
                    if(operation == WRITE)
                      (writeData.size() > 0);
                    else
                      writeData.size() == 0;}

  constraint operationREADxreadDataStatusSize_c {
                    if(operation == READ)
                      (readDataStatus.size() > 0);
                    else
                      readDataStatus.size() == 0;}


  extern function new(string name = "i3c_controller_tx");
  extern function void post_randomize();
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs,
                            uvm_comparer comparer);
  extern function void do_print(uvm_printer printer);
  extern function bit[1:0] getWriteDataStatus();
  extern function bit[1:0] getReadDataStatus();

endclass : i3c_controller_tx

function i3c_controller_tx::new(string name = "i3c_controller_tx");
  super.new(name);
endfunction : new


function void i3c_controller_tx::do_copy (uvm_object rhs);
  i3c_controller_tx controller_rhs;

  if(!$cast(controller_rhs,rhs)) begin
    `uvm_fatal("do_copy","cast of the rhs object failed")
  end
  super.do_copy(rhs);

  targetAddress = controller_rhs.targetAddress;
  addressMode = controller_rhs.addressMode;                       // [NEW]
  targetAddressStatus = controller_rhs.targetAddressStatus;
  targetAddressStatus2 = controller_rhs.targetAddressStatus2;     // [NEW]
  operation = controller_rhs.operation;
  writeData = controller_rhs.writeData;
  writeDataStatus = controller_rhs.writeDataStatus;
  readData = controller_rhs.readData;
  readDataStatus = controller_rhs.readDataStatus;

endfunction : do_copy

function bit  i3c_controller_tx::do_compare (uvm_object rhs,uvm_comparer comparer);
  i3c_controller_tx controller_rhs;

  if(!$cast(controller_rhs,rhs)) begin
  `uvm_fatal("FATAL_I3C_controller_TX_DO_COMPARE_FAILED","cast of the rhs object failed")
  return 0;
  end

  return super.do_compare(rhs,comparer) &&
  targetAddress == controller_rhs.targetAddress &&
  addressMode == controller_rhs.addressMode &&                    // [NEW]
  targetAddressStatus == controller_rhs.targetAddressStatus &&
  // 2nd address byte exists only in 10-bit mode
  (addressMode == I2C_ADDR_7BIT || targetAddressStatus2 == controller_rhs.targetAddressStatus2) &&
  operation == controller_rhs.operation &&
  writeData == controller_rhs.writeData &&
  writeDataStatus == controller_rhs.writeDataStatus &&
  readData == controller_rhs.readData &&
  readDataStatus == controller_rhs.readDataStatus;
endfunction : do_compare


function void i3c_controller_tx::do_print(uvm_printer printer);
  super.do_print(printer);

  printer.print_field($sformatf("targetAddress"),this.targetAddress,$bits(targetAddress),UVM_HEX);
  printer.print_string($sformatf("addressMode"),addressMode.name());            // [NEW]
  printer.print_string($sformatf("targetAddressStatus"),targetAddressStatus.name());
  if (addressMode == I2C_ADDR_10BIT)                                            // [NEW]
    printer.print_string($sformatf("targetAddressStatus2"),targetAddressStatus2.name());
  printer.print_string($sformatf("operation"),operation.name());

  if(operation == WRITE) begin
    foreach(writeData[i]) begin
      printer.print_field($sformatf("writeData[%0d]",i),this.writeData[i],$bits(writeData[i]),UVM_HEX);
    end

    foreach(writeDataStatus[i]) begin
      printer.print_string($sformatf("writeDataStatus[%0d]",i),writeDataStatus[i].name());
    end
  end else begin
    foreach(readData[i]) begin
      printer.print_field($sformatf("readData[%0d]",i),this.readData[i],$bits(readData[i]),UVM_HEX);
    end

    foreach(readDataStatus[i]) begin
      printer.print_string($sformatf("readDataStatus[%0d]",i),readDataStatus[i].name());
    end
  end

endfunction : do_print

function void i3c_controller_tx::post_randomize();
  // [CHANGED] guard: for a WRITE the array is empty and index -1 is out of range
  if (readDataStatus.size() > 0)
    readDataStatus[readDataStatus.size()-1] = NACK;
endfunction: post_randomize


function bit[1:0] i3c_controller_tx::getWriteDataStatus();
  int counterAckReceived;
  int counterNAckReceived;
  bit ack_value;
  bit nack_value;

  foreach(writeDataStatus[i]) begin
    if(writeDataStatus[i] == ACK) begin
      counterAckReceived++;
    end
    if(writeDataStatus[i] == NACK) begin
      counterNAckReceived++;
    end
  end

  ack_value = counterAckReceived > 0 ? ACK : NACK;
  nack_value = counterNAckReceived > 0 ? NACK : ACK;

  return ({ack_value, nack_value});

endfunction: getWriteDataStatus

function bit[1:0] i3c_controller_tx::getReadDataStatus();
  int counterAckReceived;
  int counterNAckReceived;
  bit ack_value;
  bit nack_value;

  foreach(readDataStatus[i]) begin
    if(readDataStatus[i] == ACK) begin
      counterAckReceived++;
    end
    if(readDataStatus[i] == NACK) begin
      counterNAckReceived++;
    end
  end

  ack_value = counterAckReceived > 0 ? ACK : NACK;
  nack_value = counterNAckReceived > 0 ? NACK : ACK;

  return ({ack_value, nack_value});

endfunction: getReadDataStatus
`endif

