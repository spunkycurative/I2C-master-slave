interface i2c_if;
  logic clk;
  logic rst;
  logic newd;
  logic op;
  logic [7:0] din;
  logic [6:0] addr;
  logic [7:0] dout;
  logic done;
  logic busy;
  logic ack_err;
endinterface
