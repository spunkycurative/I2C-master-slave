`timescale 1ns/1ps

// ================= MASTER ===================
module i2c_master(
  input         clk,
  input         rst,
  input         newd,
  input  [6:0]  addr,
  input         op,            // type of operation 1-read 0-write
  inout         sda,
  output        scl,
  input  [7:0]  din,
  output [7:0]  dout,
  output reg    busy,          // to convey the status of our master whether its busy or processing the current register
  output reg    ack_err,
  output reg    done
);

  // temporary storing the value of sda and scl before sending to ports
  reg scl_t = 0;
  reg sda_t = 0;

  parameter sys_freq  = 40000000; // 40 MHz
  parameter i2c_freq  = 100000;   // 100 kHz

  parameter clk_count4 = (sys_freq / i2c_freq);
  parameter clk_count1 = clk_count4 / 4; // 4 diff duration

  // ---- declarations moved to module scope (was inside always) ----
  integer count1 = 0;
  reg [1:0] pulse = 0;
  reg [3:0] bitcount = 0;
  reg [7:0] data_addr = 0, data_tx = 0;
  reg       r_ack = 0;
  reg [7:0] rx_data = 0;
  reg       sda_en = 0;

  // state typedef (SystemVerilog)
  typedef enum logic [3:0] {
    idle = 0,
    start = 1,
    write_addr = 2,
    ack_1 = 3,
    write_data = 4,
    read_data = 5,
    stop = 6,
    ack_2 = 7,
    master_ack = 8
  } state_type;
  state_type state = idle;

  // ---------- pulse / clock division (generate pulse) ----------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      pulse  <= 0;
      count1 <= 1;
    end else if (busy == 1'b0) begin
      // pulse count shouldn't increment while idle
      pulse  <= 0;
      count1 <= 0;
    end else if (count1 == clk_count1 - 1) begin
      pulse  <= 1;
      count1 <= count1 + 1;
    end else if (count1 == clk_count1 * 2 - 1) begin
      pulse  <= 2;
      count1 <= count1 + 1;
    end else if (count1 == clk_count1 * 3 - 1) begin
      pulse  <= 3;
      count1 <= count1 + 1;
    end else if (count1 <= clk_count1 * 4 - 1) begin
      pulse  <= 0;
      count1 <= count1 + 1;
    end else begin
      count1 <= count1 + 1;
    end
  end

  // ---------- main master FSM ----------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      bitcount <= 0;
      data_addr <= 0;
      data_tx <= 0;
      scl_t <= 0;
      sda_t <= 0;
      state <= idle;
      busy <= 1'b0;
      ack_err <= 1'b0;
      done <= 1'b0;
      r_ack <= 0;
      rx_data <= 0;
      sda_en <= 0;
      count1 <= 0;
      pulse <= 0;
    end else begin
      case (state)
        // ---------- IDLE ----------
        idle: begin
          done <= 1'b0;
          if (newd == 1'b1) begin
            data_addr <= {addr, op}; // storing type of operation and address
            data_tx <= din;
            busy <= 1'b1;
            state <= start;
            ack_err <= 1'b0;
            bitcount <= 0;
          end else begin
            data_addr <= 8'b0;
            data_tx <= 8'b0;
            busy <= 1'b0;
            state <= idle;
            ack_err <= 1'b0;
          end
        end

        // ---------- START ----------
        start: begin
          sda_en <= 1'b1; // send start to slave
          case (pulse)
            0: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            1: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; end
            3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
          endcase

          // we stay in this state until we complete clk_count1*4 ticks
          if (count1 == clk_count1 * 4 - 1) begin
            state <= write_addr;
            scl_t <= 1'b0;
            bitcount <= 0;
          end else begin
            state <= start;
          end
        end

        // ---------- WRITE ADDR ----------
        write_addr: begin
          sda_en <= 1'b1; // send addr to slave
          if (bitcount <= 7) begin
            case (pulse)
              0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
              1: begin scl_t <= 1'b0; sda_t <= data_addr[7 - bitcount]; end
              2: begin scl_t <= 1'b1; end
              3: begin scl_t <= 1'b1; end
            endcase
            if (count1 == clk_count1 * 4 - 1) begin
              state <= write_addr;
              scl_t <= 1'b0;
              bitcount <= bitcount + 1;
            end else begin
              state <= write_addr;
            end
          end else begin
            // finished address bits, go to acknowledgment
            state <= ack_1;
            bitcount <= 0;
            sda_en <= 1'b0; // release SDA to let slave ACK/NACK
          end
        end

        // ---------- ACK 1 (after address) ----------
        ack_1: begin
          sda_en <= 1'b0; // master releases SDA
          case (pulse)
            0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= 1'b0; end
            3: begin scl_t <= 1'b1; end
          endcase

          if (count1 == clk_count1 * 4 - 1) begin
            // check ack and decide next state based on R/W bit (data_addr[0])
            if (r_ack == 1'b0 && data_addr[0] == 1'b0) begin
              state <= write_data;
              sda_t <= 1'b0;
              sda_en <= 1'b1; // master drives SDA to write
              bitcount <= 0;
            end else if (r_ack == 1'b0 && data_addr[0] == 1'b1) begin
              state <= read_data;
              sda_t <= 1'b1;
              sda_en <= 1'b0; // release SDA to read
              bitcount <= 0;
            end else begin
              // no ack -> stop with error
              state <= stop;
              sda_en <= 1'b1;
              ack_err <= 1'b1;
            end
          end else begin
            state <= ack_1;
          end
        end

        // ---------- WRITE DATA ----------
        write_data: begin
          if (bitcount <= 7) begin
            case (pulse)
              0: begin scl_t <= 1'b0; end
              1: begin scl_t <= 1'b0; sda_en <= 1'b1; sda_t <= data_tx[7 - bitcount]; end
              2: begin scl_t <= 1'b1; end
              3: begin scl_t <= 1'b1; end
            endcase

            if (count1 == clk_count1 * 4 - 1) begin
              state <= write_data;
              scl_t <= 1'b0;
              bitcount <= bitcount + 1;
            end
          end else begin
            // after sending the 8 bits, go to ack_2
            state <= ack_2;
            bitcount <= 0;
            sda_en <= 1'b0; // release SDA for ack from slave
          end
        end

        // ---------- ACK 2 (after data) ----------
        ack_2: begin
          sda_en <= 1'b0; // recv ack from slave
          /*Setting sda_en = 0 means the master stops driving SDA.
Now the slave can pull SDA low for ACK or leave it high for NACK.*/
          case (pulse)
            0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda; end // recv ack
            3: begin scl_t <= 1'b1; end
          endcase

          if (count1 == clk_count1 * 4 - 1) begin
            sda_t <= 1'b0;
            sda_en <= 1'b1; // prepare to drive for STOP
            if (r_ack == 1'b0) begin
              state <= stop;
              ack_err <= 1'b0;
            end else begin
              state <= stop;
              ack_err <= 1'b1;
            end
          end else begin
            state <= ack_2;
          end
        end

        // ---------- STOP ----------
        stop: begin
          sda_en <= 1'b1; // master drives SDA
          case (pulse)
            0: begin scl_t <= 1'b1; sda_t <= 1'b0; end
            1: begin scl_t <= 1'b1; sda_t <= 1'b0; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
          endcase

          if (count1 == clk_count1 * 4 - 1) begin
            state <= idle;
            scl_t <= 1'b0;
            busy <= 1'b0;
            sda_en <= 1'b1;
            done <= 1'b1;
          end else begin
            state <= stop;
          end
        end

        // ---------- READ DATA ----------
        read_data: begin
          sda_en <= 1'b0; // master is listening to slave not driving so sda_en=0
          if (bitcount <= 7) begin
            case (pulse)
              0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
              1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
              2: begin scl_t <= 1'b1;/*Master samples SDA at count1 == clk_count1*2 → middle of clock high period (safe sampling point).
              Shift sampled bit into rx_data from MSB to LSB.*/
                  // sample at a point during high window
                rx_data <= (count1 == (clk_count1 * 2)) ? {rx_data[6:0], sda} : rx_data;//rx_data->register where received byte is stored.
              end
              3: begin scl_t <= 1'b1; end
            endcase

            if (count1 == clk_count1 * 4 - 1) begin
              state <= read_data;
              scl_t <= 1'b0;
              bitcount <= bitcount + 1;
            end else begin
              state <= read_data;
            end
          end else begin
            state <= master_ack;
            bitcount <= 0;
            sda_en <= 1'b1; // master will drive ACK/NACK back
          end
        end

        // ---------- MASTER ACK (after read) ----------
        master_ack: begin
          sda_en <= 1'b1;
          case (pulse)
            0: begin scl_t <= 1'b0; sda_t <= 1'b1; end/*pulse 0&1->SDA = 1 → master is setting the NACK/ACK value on the data line (in this case, 1 → NACK).*/
            1: begin scl_t <= 1'b0; sda_t <= 1'b1; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            /*Pulse 2 & 3:
            SCL = 1 → clock high.
            SDA = 1 → maintain value while slave samples the ACK/NACK.*/
          endcase

          if (count1 == clk_count1 * 4 - 1) begin
            // prepare STOP (drive low then release)
            sda_t <= 1'b0;
            state <= stop;
            sda_en <= 1'b1;
          end else begin
            state <= master_ack;
          end
        end

        default: begin
          state <= idle;
        end
      endcase
    end
  end

  // final assigns
  assign sda = (sda_en == 1) ? ((sda_t == 0) ? 1'b0 : 1'bz) : 1'bz;
  assign scl = scl_t;
  assign dout = rx_data;

endmodule
