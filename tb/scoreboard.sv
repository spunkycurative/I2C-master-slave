class scoreboard;

    transaction tr;
  int completed_count=0;
  int pass_count=0;
  int fail_count=0;

    mailbox #(transaction) mbxms;

    bit [7:0] mem [0:127];

    bit [7:0] expected;


    function new(mailbox #(transaction) mbxms);

        this.mbxms = mbxms;

        for(int i = 0; i < 128; i++)
            mem[i] = i;

    endfunction


    task run();

        forever begin

            mbxms.get(tr);
          completed_count++;

            if(tr.op == 1'b0) begin

                // WRITE

                mem[tr.addr] = tr.din;

                $display(
                    "[SCO] WRITE STORED: ADDR=%0d DATA=%0d",
                    tr.addr,
                    tr.din
                );

            end

            else begin

                // READ

                expected = mem[tr.addr];

                if(tr.dout === expected) begin
                  
                  pass_count++;

                    $display(
                      "[SCO] [READ PASS]: ADDR=%0d EXP=%0d GOT=%0d",
                        tr.addr,
                        expected,
                        tr.dout
                    );

                end

                else begin
                  
                  fail_count++;

                    $error(
                      "[SCO] [READ FAIL]: ADDR=%0d EXP=%0d GOT=%0d",
                        tr.addr,
                        expected,
                        tr.dout
                    );

                end

            end
          
          $display("[SCO] COMPLETED=%0d PASS=%0d FAIL=%0d",completed_count,pass_count,fail_count);

            $display("--------------------------------");

        end

    endtask

endclass
