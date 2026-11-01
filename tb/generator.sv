class generator;

    transaction tr;
  int generated_count=0;

    mailbox #(transaction) mbxgd;

    event done;
    event drvnext;

    int count = 0;


    function new(mailbox #(transaction) mbxgd);

        this.mbxgd = mbxgd;

    endfunction


    task run();

        repeat(count) begin

            tr = new();

            assert(tr.randomize())
            else
                $fatal("[GEN] Randomization failed");
          
          generated_count++;

            mbxgd.put(tr);

            $display(
              "[GEN] Testcase=%0d OP=%0d ADDR=%0d DIN=%0d",
                generated_count,
                tr.op,
                tr.addr,
                tr.din
            );

            @(drvnext);

        end
       $display("[GEN] TOTAL TESTCASES GENERATED = %0d",
                 generated_count);

        ->done;

    endtask

endclass
