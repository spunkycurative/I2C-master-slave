class monitor;
  virtual i2c_if vif;
  transaction tr;
  mailbox #(transaction) mbxms;
  
  function new(mailbox #(transaction) mbxms);
    this.mbxms=mbxms;
  endfunction
  
  task run();
    tr=new();
    forever begin
      @(posedge vif.done);
      //transaction tr = new();   // FIX: allocate new transaction object
      tr.din  = vif.din;
      tr.addr = vif.addr;
      tr.op   = vif.op;
      tr.dout = vif.dout;
      mbxms.put(tr);
      $display("[MON]:op=%0d, addr=%0d, din=%0d, dout=%0d",
               tr.op, tr.addr, tr.din, tr.dout);
    end
  endtask
endclass
