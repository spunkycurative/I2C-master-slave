// ================= SLAVE ===================
`timescale 1ns/1ps

module i2c_slave(
  input        scl,
  input        clk,
  input        rst,
  inout        sda,
  output reg   ack_err,
  output reg   done
);

  // fix enum name: idle (not ideal)
  typedef enum logic [3:0] {
    idle = 0,
    read_addr = 1,
    send_ack = 2,
    send_data = 3,
    master_ack = 4,
    read_data = 5,
    send_ack2 = 6,
    wait_p = 7,
    detect_stop = 8
  } state_type;
  state_type state = idle;

  reg [7:0] mem [0:127]; // slave memory
  reg [7:0] r_addr;      // register pointer (address)
  reg [6:0] addr;        // slave address to match
  reg       r_mem = 0;   // read enable (master reading from slave)
  reg       w_mem = 0;   // write enable (master writing to slave)
  reg [7:0] dout;        // data out from slave to master
  reg [7:0] din;         // data in from master to slave
  reg sda_t;             // value to drive sda
  reg sda_en;            // controls sda driving
  reg [3:0] bitcnt = 0;  // counts bits 0-7

  // initialize memory and variables
  always @(posedge clk) begin
    if (rst) begin
      integer i;
      for (i = 0; i < 128; i = i + 1)
        mem[i] = i;
      dout <= 8'h00;
    end else begin
      if (r_mem == 1'b1) begin
        dout <= mem[addr];
      end else if (w_mem == 1'b1) begin
        mem[addr] <= din;
      end
    end
  end

  parameter sys_freq = 40000000;
  parameter i2c_freq = 100000;

  parameter clk_count4 = sys_freq / i2c_freq;
  parameter clk_count1 = clk_count4 / 4;
  integer count1 = 0;
  reg i2c_clk = 0;

  reg [1:0] pulse = 0;
  reg busy;

  // pulse generator for slave
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      pulse <= 0;
      count1 <= 0;
    end else if (busy == 1'b0) begin
      pulse <= 2;
      count1 <= 202;
    end else if (count1 == clk_count1 - 1) begin
      pulse <= 1;
      count1 <= count1 + 1;
    end else if (count1 == clk_count1 * 2 - 1) begin
      pulse <= 2;
      count1 <= count1 + 1;
    end else if (count1 == clk_count1 * 3 - 1) begin
      pulse <= 3;
      count1 <= count1 + 1;
    end else if (count1 == clk_count1 * 4 - 1) begin
      pulse <= 0;
      count1 <= 0;
    end else begin
      count1 <= count1 + 1;
    end
  end

  // detect start: falling edge of SDA while SCL high
  reg scl_t;
  wire start;
  always @(posedge clk) begin
    scl_t <= scl;
  end
  assign start = (~scl) & scl_t;

  reg r_ack;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      bitcnt <= 0;
      state <= idle;
      r_addr <= 7'b0000000;
      sda_en <= 1'b0;
      sda_t <= 1'b0;
      addr <= 0;
      r_mem <= 0;
      din <= 8'h00;
      ack_err <= 0;
      done <= 1'b0;
      busy <= 1'b0;
      r_ack <= 1'b1;
      dout <= 8'h00;
      w_mem <= 1'b0;
    end else begin
      case (state)
        idle: begin
          if (scl == 1'b1 && sda == 1'b0) begin
            busy <= 1'b1;
            state <= wait_p;
          end else begin
            state <= idle;
          end
        end

        wait_p: begin
          // wait until pulses align (use integer compare as you used in master)
          if ((pulse == 2'b11) && (count1 == clk_count1 * 4 - 1)) begin
            state <= read_addr;
          end else begin
            state <= wait_p;
          end
        end

        // ---------- read address bits ----------
        read_addr: begin
          sda_en <= 1'b0; // listen
          if (bitcnt <= 7) begin
            case (pulse)
              0: begin end
              1: begin end
              2: begin r_addr <= (count1 == (clk_count1 * 2)) ? {r_addr[6:0], sda} : r_addr; end
              3: begin end
            endcase
            if (count1 == clk_count1 * 4 - 1) begin
              state <= read_addr;
              bitcnt <= bitcnt + 1;
            end else begin
              state <= read_addr;
            end
          end else begin
            state <= send_ack;
            bitcnt <= 0;
            sda_en <= 1'b1;
            addr <= r_addr[7:1];
          end
        end

        // ---------- send ack after address ----------
        send_ack: begin
          case (pulse)
            0: begin sda_t <= 1'b0; end
            1: begin end
            2: begin end
            3: begin end
          endcase
          if (count1 == clk_count1 * 4 - 1) begin
            if (r_addr[0] == 1'b1) begin
              // master wants to read -> slave will send data
              state <= send_data;
              r_mem <= 1'b1;
            end else begin
              // master wants to write -> slave will read data
              state <= read_data;
              r_mem <= 1'b0;
            end
          end else begin
            state <= send_ack;
          end
        end

        // ---------- read data from master (write from master's perspective) ----------
        read_data: begin
          sda_en <= 1'b0;
          if (bitcnt <= 7) begin
            case (pulse)
              0: begin end
              1: begin end
              2: begin din <= (count1 == (clk_count1 * 2)) ? {din[6:0], sda} : din; end
              3: begin end
            endcase
            if (count1 == clk_count1 * 4 - 1) begin
              state <= read_data;
              bitcnt <= bitcnt + 1;
            end else begin
              state <= read_data;
            end
          end else begin
            state <= send_ack2;
            bitcnt <= 0;
            sda_en <= 1'b1;
            w_mem <= 1'b1;
          end
        end

        // ---------- send ACK after receiving data ----------
        send_ack2: begin
          case (pulse)
            0: begin sda_t <= 1'b0; end
            1: begin w_mem <= 1'b0; end
            2: begin end
            3: begin end
          endcase
          if (count1 == clk_count1 * 4 - 1) begin
            state <= detect_stop;
          end else begin
            state <= send_ack2;
          end
        end

        // ---------- send data to master (master read) ----------
        send_data: begin
          sda_en <= 1'b1; // drive SDA
          if (bitcnt <= 7) begin
            r_mem <= 1'b0;
            case (pulse)
              0: begin end
              1: begin sda_t <= (count1 == (clk_count1)) ? dout[7 - bitcnt] : sda_t; end
              2: begin end
              3: begin end
            endcase
            if (count1 == clk_count1 * 4 - 1) begin
              state <= send_data;
              bitcnt <= bitcnt + 1;
            end else begin
              state <= send_data;
            end
          end else begin
            state <= master_ack;
            bitcnt <= 0;
            sda_en <= 1'b0;
          end
        end

        // ---------- master ack after slave sends data ----------
        master_ack: begin
          case (pulse)
            0: begin end
            1: begin end
            2: begin r_ack <= (count1 == (clk_count1 * 2)) ? sda : r_ack; end
            3: begin end
          endcase
          if (count1 == clk_count1 * 4 - 1) begin
            if (r_ack == 1'b1) begin
              // NACK (master not interested in more data)
              ack_err <= 1'b0;
              state <= detect_stop;
              sda_en <= 1'b0;
            end else begin
              // ACK (master wants more) -> treat as not error but still proceed to detect stop
              ack_err <= 1'b1;
              state <= detect_stop;
              sda_en <= 1'b0;
            end
          end else begin
            state <= master_ack;
          end
        end

        // ---------- detect STOP ----------
        detect_stop: begin
          if ((pulse == 2'b11) && (count1 == clk_count1 * 4 - 1)) begin
            state <= idle;
            busy <= 1'b0;
            done <= 1'b1;
          end else begin
            state <= detect_stop;
          end
        end

        default: state <= idle;

      endcase
    end
  end

  // I2C open-drain behavior
  assign sda = (sda_en == 1'b1) ? sda_t : 1'bz;

endmodule
