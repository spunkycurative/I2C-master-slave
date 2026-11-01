module i2c_assertions(i2c_if vif);
  
  property p_reset;
    
    @(posedge vif.clk)
    vif.rst |-> (
      !vif.busy &&
      !vif.done );    
  endproperty
  
  assert property(p_reset)
    else
      $error("I2C master reset failed");
    
    
    property p_done_one_cycle;
      @(posedge vif.clk)
      disable iff(vif.rst)
      vif.done |=> !vif.done;
    endproperty
    
    assert property(p_done_one_cycle)
      else
        $error("I2C ERROR: DONE is not one-cycle pulse");
 
   
      property p_newd_starts_transaction;
        @(posedge vif.clk)
        disable iff(vif.rst)
        vif.newd|=>vif.busy;      
      endproperty
      
      assert property(p_newd_starts_transaction)
        else
          $error("ASSERTION FAILED:busy not asserted after newd");
  
        
        property p_done_busy_relation;
          @(posedge vif.clk)
          disable iff(vif.rst)
          vif.done |-> !vif.busy;
        endproperty
        
        assert property(p_done_busy_relation)
          else
            $error("ASSERTION FAILED:");
 
  
endmodule
          
          
          module i2c_slave_assertions(
            input logic clk,
            input logic rst,
            input logic scl,
            input logic sda,
            input logic rising_scl,
            input logic [3:0] bitcnt,
            input logic sda_t,
            input logic sda_en,
            input logic [3:0] state
                     
          );
            
            localparam logic [3:0] IDLE       =  4'd0;
            localparam logic [3:0] READ_ADDR  =  4'd1;
            localparam logic [3:0] SEND_ACK   =  4'd2;
            localparam logic [3:0] READ_DATA  =  4'd3;
            localparam logic [3:0] WRITE_MEM  =  4'd4;
            localparam logic [3:0] SEND_ACK2  =  4'd5;
            localparam logic [3:0] SEND_DATA  =  4'd6;
            localparam logic [3:0] MASTER_ACK =  4'd7;
            localparam logic [3:0] STOP       =  4'd8;   
            
            
            property p_bitcnt_range;
              @(posedge vif.clk)
              disable iff(vif.rst)
              bitcnt inside {[0:8]};          
            endproperty
            
            assert property(p_bitcnt_range)
              else
                $error("ASSERTION FAILED : bitcount out of range");
              

         property p_send_data_sda_enable;
             @(posedge clk)
             disable iff (rst)
             (state == SEND_DATA && bitcnt < 4'd8)|-> sda_en;
         endproperty

           assert property(p_send_data_sda_enable)
              else 
                $error("I2C ASSERTION FAILED: SDA not enabled while sending data");
                
                
                property p_sda_stable_scl_high;
                  @(posedge vif.clk)
                  disable iff(vif.rst)
                  (state==SEND_DATA && scl) |-> $stable(sda_t);
                endproperty
                
                assert property(p_sda_stable_scl_high)
                  else
                    $error("ASSERTION FAILED:sda changed while scl high");
                  
                  
                  property p_send_ack_low;
                    @(posedge vif.clk)
                    disable iff(vif.rst)
                    (state==SEND_ACK) |=> (sda_en && !sda_t);                    
                  endproperty
                  
                  assert property(p_send_ack_low)
                    else
                      $error("ASSERTION FAILED : send ack did not drive sda low");
                    
                    
                    property p_send_ack2_low;
                      @(posedge vif.clk)
                      disable iff(vif.rst)
                      (state==SEND_ACK2 && !rising_scl) |-> (sda_en && !sda_t);
                    endproperty
                    
                    assert property (p_send_ack2_low)
                      else
                        $error("ASSERTION FAILED:send_ack2 did not drive sda low");
                      
                      
                      property p_stop_release_sda;
                        @(posedge vif.clk)
                        disable iff(vif.rst)
                        (state==STOP) |-> !sda_en;
                      endproperty
                      
                      assert property(p_stop_release_sda)
                        else
                          $error("ASSERTION FAILED : sda not released in stop state");
                      

                    endmodule
                    
                    bind i2c_slave i2c_slave_assertions sva_inst(
                      
                      .clk(clk),
                      .rst(rst),
                      .scl(scl),
                      .sda(sda),
                      .bitcnt(bitcnt),
                      .sda_en(sda_en),
                      .sda_t(sda_t),
                      .state(state)                                    
                    );
