class generator;
  transaction tr;
  mailbox #(transaction) mbxgd;
  event done;
  event drvnext;
  event sconext;
  
  int count=0;
  
  function new(mailbox #(transaction) mbxgd);
    this.mbxgd=mbxgd;
  endfunction
  
  task run();
    repeat(count) begin
      tr = new();   // FIX: create new transaction object each iteration
      assert(tr.randomize()) else $error("randomization failed");
      mbxgd.put(tr);
      $display("[GEN]:op=%0d, addr=%0d, din=%0d", tr.op, tr.addr, tr.din);
      @(drvnext);
      //@(sconext);
    end
    ->done;
  endtask
endclass
