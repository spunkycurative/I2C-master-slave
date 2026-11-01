
// ============================================================
// I2C SLAVE
// ============================================================

module i2c_slave(

    input        clk,
    input        rst,

    input        scl,
    inout        sda,

    output reg   ack_err,
    output reg   done
);

    // --------------------------------------------------------
    // Memory
    // --------------------------------------------------------

    reg [7:0] mem [0:127];

    integer i;

    // --------------------------------------------------------
    // Internal registers
    // --------------------------------------------------------

    reg [7:0] rx_data;
    reg [7:0] tx_data;

    reg [6:0] addr;

    reg       rw;

    reg [3:0] bitcnt;

    reg       sda_t;
    reg       sda_en;

    reg       busy;

    // --------------------------------------------------------
    // Previous SCL/SDA
    // --------------------------------------------------------

    reg scl_prev;
    reg sda_prev;

    wire rising_scl;
    wire falling_scl;

    assign rising_scl  = (~scl_prev) & scl;
    assign falling_scl = scl_prev & (~scl);

    // START:
    // SDA HIGH -> LOW while SCL HIGH

    wire start_condition;

    assign start_condition =
        sda_prev & (~sda) & scl;

    // STOP:
    // SDA LOW -> HIGH while SCL HIGH

    wire stop_condition;

    assign stop_condition =
        (~sda_prev) & sda & scl;

    // --------------------------------------------------------
    // Open drain SDA
    // --------------------------------------------------------

    assign sda =
        (sda_en && !sda_t) ?
        1'b0 :
        1'bz;


    // ========================================================
    // Memory initialization
    // ========================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            for (i = 0; i < 128; i = i + 1)
                mem[i] <= i;

        end
    end


    // ========================================================
    // Previous bus values
    // ========================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            scl_prev <= 1'b0;
            sda_prev <= 1'b1;

        end

        else begin

            scl_prev <= scl;
            sda_prev <= sda;

        end
    end


    // ========================================================
    // Slave FSM
    // ========================================================

    typedef enum logic [3:0] {

        IDLE       = 4'd0,
        READ_ADDR  = 4'd1,
        SEND_ACK   = 4'd2,
        READ_DATA  = 4'd3,
        WRITE_MEM  = 4'd4,
        SEND_ACK2  = 4'd5,
        SEND_DATA  = 4'd6,
        MASTER_ACK = 4'd7,
        STOP       = 4'd8

    } state_t;

    state_t state;


    // ========================================================
    // Main FSM
    // ========================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state    <= IDLE;

            rx_data  <= 0;
            tx_data  <= 0;

            addr     <= 0;
            rw       <= 0;

            bitcnt   <= 0;

            sda_t    <= 1'b1;
            sda_en   <= 1'b0;

            busy     <= 1'b0;
            ack_err  <= 1'b0;
            done     <= 1'b0;
        end

        else begin

            case (state)


            // =================================================
            // IDLE
            // =================================================

            IDLE: begin

                done   <= 1'b0;
                sda_en <= 1'b0;
                sda_t  <= 1'b1;

                if (start_condition) begin

                    busy   <= 1'b1;
                    bitcnt <= 0;
                    rx_data <= 0;

                    state <= READ_ADDR;
                end
            end


            // =================================================
            // RECEIVE 7-BIT ADDRESS + R/W
            // =================================================

            READ_ADDR: begin

                sda_en <= 1'b0;

                if (rising_scl) begin

                    if (bitcnt < 4'd7) begin

                        // First 7 bits = address
                        addr <= {
                            addr[5:0],
                            sda
                        };

                        bitcnt <= bitcnt + 1'b1;
                    end

                    else begin

                        // 8th bit = R/W
                        rw <= sda;

                        bitcnt <= 0;

                        state <= SEND_ACK;
                    end
                end
            end


            // =================================================
            // SEND ADDRESS ACK
            // =================================================

            SEND_ACK: begin

                // ACK = SDA LOW
                sda_en <= 1'b1;
                sda_t  <= 1'b0;

                if (rising_scl) begin

                    bitcnt <= 0;

                    if (rw == 1'b0) begin

                        // WRITE operation
                        rx_data <= 0;

                        state <= READ_DATA;
                    end

                    else begin

                        // READ operation
                        tx_data <= mem[addr];

                        bitcnt <= 0;

                        state <= SEND_DATA;
                    end
                end
            end


            // =================================================
            // RECEIVE DATA FROM MASTER
            // =================================================

            READ_DATA: begin

                sda_en <= 1'b0;

                if (rising_scl) begin

                    rx_data <= {
                        rx_data[6:0],
                        sda
                    };

                    if (bitcnt == 4'd7) begin

                        bitcnt <= 0;

                        state <= WRITE_MEM;
                    end

                    else begin
                        bitcnt <= bitcnt + 1'b1;
                    end
                end
            end


            // =================================================
            // WRITE DATA TO MEMORY
            // =================================================

            WRITE_MEM: begin

                mem[addr] <= rx_data;

                state <= SEND_ACK2;
            end


            // =================================================
            // SEND DATA ACK
            // =================================================

            SEND_ACK2: begin

                sda_en <= 1'b1;
                sda_t  <= 1'b0;

                if (rising_scl) begin

                    // Release SDA after ACK clock
                    sda_en <= 1'b0;

                    state <= STOP;
                  
                     $display("[SLAVE] READ ACK: ADDR=%0d MEM=%0d TIME=%0t",
             addr, mem[addr], $time);
                end
            end


        // =================================================
// SEND DATA TO MASTER
//
// SDA changes ONLY when SCL LOW
// =================================================

SEND_DATA: begin

    sda_en <= 1'b1;

    if (falling_scl) begin
    if (bitcnt < 4'd8) begin
        sda_t <= tx_data[7-bitcnt];
        sda_en <= 1'b1;

        $display("[SLAVE] TX BIT=%0d VALUE=%0b TIME=%0t",
                 bitcnt, tx_data[7-bitcnt], $time);

        bitcnt <= bitcnt + 1'b1;
    end
    else begin
        sda_en <= 1'b0;
        bitcnt <= 0;
        state <= MASTER_ACK;
    end
end
end



            // =================================================
            // MASTER ACK / NACK
            // =================================================

            MASTER_ACK: begin

                // Master owns SDA
                sda_en <= 1'b0;

                if (rising_scl) begin

                    if (sda == 1'b1) begin

                        // NACK
                        state <= STOP;
                    end

                    else begin

                        // ACK
                        state <= SEND_DATA;
                    end
                end
            end


            // =================================================
            // STOP
            // =================================================

            STOP: begin

                sda_en <= 1'b0;

                if (stop_condition) begin

                    busy    <= 1'b0;
                    done    <= 1'b1;
                    ack_err <= 1'b0;

                    bitcnt <= 0;

                    state <= IDLE;
                end
            end


            default: begin

                state <= IDLE;
                busy  <= 1'b0;

            end

            endcase
        end
    end

endmodule
