
class environment;

    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sco;

    event nextgd;

    mailbox #(transaction) mbxgd;
    mailbox #(transaction) mbxms;

    virtual i2c_if vif;


    function new(virtual i2c_if vif);

        this.vif = vif;

        mbxgd = new();
        mbxms = new();

        gen = new(mbxgd);
        drv = new(mbxgd);
        mon = new(mbxms);
        sco = new(mbxms);

        drv.vif = vif;
        mon.vif = vif;

        gen.drvnext = nextgd;
        drv.drvnext = nextgd;

    endfunction


    task pre_test();

        drv.reset();

    endtask


    task test();

        fork

            gen.run();
            drv.run();
            mon.run();
            sco.run();

        join_none

    endtask


    task post_test();

        wait(gen.done.triggered);

        // Allow monitor and scoreboard to finish
        repeat(5)
            @(posedge vif.clk);
         $display("");
    $display("========== I2C TEST SUMMARY ==========");
    $display("Transactions generated : %0d",
             gen.generated_count);
    $display("Transactions completed : %0d",
             sco.completed_count);
    $display("Transactions passed    : %0d",
             sco.pass_count);
    $display("Transactions failed    : %0d",
             sco.fail_count);
    $display("======================================");
    $display("");

    endtask


    task run();

        pre_test();

        test();

        post_test();

    endtask

endclass
