class driver;

    virtual i2c_if vif;

    transaction tr;

    mailbox #(transaction) mbxgd;

    event drvnext;


    function new(mailbox #(transaction) mbxgd);

        this.mbxgd = mbxgd;

    endfunction


    task reset();

        vif.rst  <= 1'b1;
        vif.newd <= 1'b0;
        vif.op   <= 1'b0;
        vif.din  <= 8'h00;
        vif.addr <= 7'h00;

        repeat(10)
            @(posedge vif.clk);

        vif.rst <= 1'b0;

        $display("[DRV] RESET DONE");
        $display("--------------------------------");

    endtask


    task write();

        vif.op   <= 1'b0;
        vif.din  <= tr.din;
        vif.addr <= tr.addr;
        vif.newd <= 1'b1;

        @(posedge vif.clk);

        vif.newd <= 1'b0;

        @(posedge vif.done);

        $display(
            "[DRV] WRITE ADDR=%0d DATA=%0d",
            tr.addr,
            tr.din
        );

    endtask


    task read();

        vif.op   <= 1'b1;
        vif.din  <= 8'h00;
        vif.addr <= tr.addr;
        vif.newd <= 1'b1;

        @(posedge vif.clk);

        vif.newd <= 1'b0;

        @(posedge vif.done);

        // Give DUT one clock to settle
        @(posedge vif.clk);

        tr.dout = vif.dout;

        $display(
            "[DRV] READ ADDR=%0d DATA=%0d",
            tr.addr,
            tr.dout
        );

    endtask


    task run();

        forever begin

            mbxgd.get(tr);

            wait(vif.busy == 1'b0);

            if(tr.op == 1'b0)
                write();
            else
                read();

            ->drvnext;

        end

    endtask

endclass
