module tb;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd;
  event nextgs;
  
  mailbox #(transaction) mbxgd, mbxms;
  
  i2c_if vif();
  i2c_top dut(vif.clk,vif.rst,vif.newd,vif.op,vif.addr,vif.din,vif.dout,vif.busy,vif.ack_err,vif.done);
  
  initial begin
    vif.clk = 0; 
    forever #5 vif.clk = ~vif.clk; // FIX: initialize clock
  end
  
  initial begin
    mbxgd=new();
    mbxms=new();
    
    gen=new(mbxgd);
    drv=new(mbxgd);
    mon=new(mbxms);
    sco=new(mbxms);
    
    gen.count=10;
    
    drv.vif=vif;
    mon.vif=vif;
    
    gen.drvnext=nextgd;
    drv.drvnext=nextgd;
    gen.sconext=nextgs;
    sco.sconext=nextgs;
    
    run();
  end
  
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
    //$finish();
  endtask
    
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,tb);
  end
  
   initial begin
    #300;
    $display("TIMEOUT");
    $finish;
  end
  
endmodule
