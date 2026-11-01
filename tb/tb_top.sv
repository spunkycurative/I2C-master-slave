
module tb;

    i2c_if vif();


    // ========================================================
    // DUT
    // ========================================================

    i2c_top dut (

        .clk(vif.clk),
        .rst(vif.rst),

        .newd(vif.newd),

        .op(vif.op),

        .din(vif.din),
        .addr(vif.addr),

        .dout(vif.dout),

        .busy(vif.busy),
        .ack_err(vif.ack_err),
        .done(vif.done)

    );
  i2c_assertions sva(vif);


    environment env;


    // ========================================================
    // Clock
    // ========================================================

    initial begin

        vif.clk = 1'b0;

        forever
            #5 vif.clk = ~vif.clk;

    end


    // ========================================================
    // Test
    // ========================================================

    initial begin

        env = new(vif);

        env.gen.count = 30;

        env.run();

        $display("");
        $display("==============================================");
        $display("           TEST COMPLETED");
        $display("==============================================");

        #100;

        $finish;

    end


    // ========================================================
    // Waveform
    // ========================================================

    initial begin

        $dumpfile("dump.vcd");
        $dumpvars(0,tb);

    end


    // ========================================================
    // Timeout
    // ========================================================

    initial begin

        #10_000_000;

        $error("TIMEOUT");

        $finish;

    end

endmodule
