class monitor;

    virtual i2c_if vif;

    transaction tr;

    mailbox #(transaction) mbxms;


    function new(mailbox #(transaction) mbxms);

        this.mbxms = mbxms;

    endfunction


    task run();

        forever begin

            @(posedge vif.done);

            tr = new();

            tr.op   = vif.op;
            tr.addr = vif.addr;
            tr.din  = vif.din;
            tr.dout = vif.dout;

            tr.ack_err = vif.ack_err;

            mbxms.put(tr);

            $display(
                "[MON] OP=%0d ADDR=%0d DIN=%0d DOUT=%0d",
                tr.op,
                tr.addr,
                tr.din,
                tr.dout
            );

        end

    endtask

endclass
