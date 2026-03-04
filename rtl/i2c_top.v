/ ================= TOP ===================
`timescale 1ns/1ps
module i2c_top(
  input clk,
  input rst,
  input newd,
  input op,
  input [7:0] din,
  input [6:0] addr,
  output [7:0] dout,
  output busy,
  output ack_err,
  output done
);

  wire sda, scl;
  wire ack_errm, ack_errs;

  // instantiate master (note port order kept similar to your original)
  i2c_master master(
    .clk(clk),
    .rst(rst),
    .newd(newd),
    .addr(addr),
    .op(op),
    .sda(sda),
    .scl(scl),
    .din(din),
    .dout(dout),
    .busy(busy),
    .ack_err(ack_errm),
    .done(done)
  );

  // instantiate slave (original port order: scl,clk,rst,sda,ack_errs)
  i2c_slave slave(
    .scl(scl),
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .ack_err(ack_errs),
    .done() // not connected to top done (keep separate)
  );

  // fixed typo here: ack_errm (not acke_rrm)
  assign ack_err = ack_errs | ack_errm;

endmodule
