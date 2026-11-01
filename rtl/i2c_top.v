// ============================================================
// TOP MODULE
// ============================================================

module i2c_top(

    input        clk,
    input        rst,
    input        newd,

    input        op,
    input  [7:0] din,
    input  [6:0] addr,

    output [7:0] dout,

    output       busy,
    output       ack_err,
    output       done
);

    wire sda;
    wire scl;

    wire ack_err_master;
    wire ack_err_slave;

    // --------------------------------------------------------
    // I2C pull-ups
    // --------------------------------------------------------

    pullup(sda);
    pullup(scl);


    // --------------------------------------------------------
    // MASTER
    // --------------------------------------------------------

    i2c_master #(
        .SYS_FREQ(40_000_000),
        .I2C_FREQ(100_000)
    ) master (

        .clk(clk),
        .rst(rst),

        .newd(newd),

        .addr(addr),
        .op(op),
        .din(din),

        .sda(sda),
        .scl(scl),

        .dout(dout),

        .busy(busy),
        .ack_err(ack_err_master),
        .done(done)
    );


    // --------------------------------------------------------
    // SLAVE
    // --------------------------------------------------------

    i2c_slave slave (

        .clk(clk),
        .rst(rst),

        .scl(scl),
        .sda(sda),

        .ack_err(ack_err_slave),
        .done()
    );


    assign ack_err =
        ack_err_master |
        ack_err_slave;

endmodule        
