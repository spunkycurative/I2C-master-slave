class scoreboard;
  transaction tr;
  mailbox #(transaction) mbxms;
  event sconext;
  
  bit [7:0] temp;
  bit [7:0] mem[128];
  
  function new(mailbox #(transaction) mbxms);
    this.mbxms=mbxms;
    for(int i=0;i<128;i++) begin
      mem[i]=i; // optional initialization
    end
  endfunction
  
  task run();
    tr=new();
    forever begin
      mbxms.get(tr);
      temp=mem[tr.addr];
      if(tr.op==1'b0) begin
        mem[tr.addr]=tr.din;
        $display("[SCO]:DATA STORED -> ADDR=%0d , DATA=%0d",tr.addr,tr.din);
      end
      else begin
        if(tr.dout==temp)
          $display("[SCO]:READ MATCH: exp=%0d, got=%0d",temp,tr.dout);
        else
          $display("[SCO]:READ MISMATCH: exp=%0d, got=%0d",temp,tr.dout);
      end
      $display("--------------------------");
      ->sconext;
    end
  endtask
endclass
