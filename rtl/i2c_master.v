`timescale 1ns/1ps

// ============================================================
// I2C MASTER
// ============================================================

module i2c_master #(
    parameter SYS_FREQ = 40_000_000,
    parameter I2C_FREQ = 100_000
)(
    input        clk,
    input        rst,
    input        newd,

    input  [6:0] addr,
    input        op,              // 0 = WRITE, 1 = READ
    input  [7:0] din,

    inout        sda,
    output       scl,

    output reg [7:0] dout,
    output reg       busy,
    output reg       ack_err,
    output reg       done
);

    // --------------------------------------------------------
    // Clock generation
    // 40 MHz / 100 kHz = 400 clocks per I2C clock
    // 400 / 4 = 100 clocks per quarter phase
    // --------------------------------------------------------

    localparam integer CLK_COUNT     = SYS_FREQ / I2C_FREQ;
    localparam integer QUARTER_COUNT = CLK_COUNT / 4;

    integer clk_count;

    reg [1:0] pulse;

    // --------------------------------------------------------
    // I2C signals
    // --------------------------------------------------------

    reg scl_t;
    reg sda_t;
    reg sda_en;

    assign scl = scl_t;

    // Open-drain SDA
    // 0 -> drive LOW
    // 1 -> release
    assign sda = (sda_en && !sda_t) ? 1'b0 : 1'bz;

    // --------------------------------------------------------
    // Internal registers
    // --------------------------------------------------------

    reg [3:0] bitcount;

    reg [7:0] data_addr;
    reg [7:0] data_tx;

    reg [7:0] rx_data;

    reg       r_ack;

    // --------------------------------------------------------
    // FSM
    // --------------------------------------------------------

    typedef enum logic [3:0] {
        IDLE        = 4'd0,
        START       = 4'd1,
        WRITE_ADDR  = 4'd2,
        ACK_1       = 4'd3,
        WRITE_DATA  = 4'd4,
        ACK_2       = 4'd5,
        READ_DATA   = 4'd6,
        MASTER_ACK  = 4'd7,
        STOP        = 4'd8
    } state_t;

    state_t state;

    // --------------------------------------------------------
    // Quarter-cycle generator
    // --------------------------------------------------------

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            clk_count <= 0;
            pulse     <= 2'd0;
        end

        else if (busy) begin

            if (clk_count == QUARTER_COUNT-1) begin
                clk_count <= 0;

                if (pulse == 2'd3)
                    pulse <= 2'd0;
                else
                    pulse <= pulse + 1'b1;
            end

            else begin
                clk_count <= clk_count + 1;
            end
        end

        else begin
            clk_count <= 0;
            pulse     <= 2'd0;
        end
    end

    // --------------------------------------------------------
    // Main FSM
    // --------------------------------------------------------

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state     <= IDLE;

            bitcount  <= 0;

            data_addr <= 0;
            data_tx   <= 0;

            rx_data   <= 0;

            scl_t     <= 1'b0;
            sda_t     <= 1'b1;
            sda_en    <= 1'b0;

            busy      <= 1'b0;
            ack_err   <= 1'b0;
            done      <= 1'b0;

            r_ack     <= 1'b1;
        end

        else begin

            case (state)

            // =================================================
            // IDLE
            // =================================================

            IDLE: begin

                done <= 1'b0;

                scl_t  <= 1'b0;
                sda_t  <= 1'b1;
                sda_en <= 1'b0;

                if (newd) begin

                    data_addr <= {addr, op};
                    data_tx   <= din;

                    bitcount <= 0;
                    rx_data  <= 0;

                    busy    <= 1'b1;
                    ack_err <= 1'b0;

                    state <= START;
                end

                else begin
                    busy <= 1'b0;
                end
            end


            // =================================================
            // START CONDITION
            //
            // SDA: HIGH -> LOW
            // while SCL is HIGH
            // =================================================

            START: begin

                sda_en <= 1'b1;

                case (pulse)

                    2'd0,
                    2'd1: begin
                        scl_t <= 1'b1;
                        sda_t <= 1'b1;
                    end

                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                        sda_t <= 1'b0;
                    end

                endcase

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t    <= 1'b0;
                    bitcount <= 0;

                    state <= WRITE_ADDR;
                end
            end


            // =================================================
            // WRITE ADDRESS + R/W
            //
            // 7-bit address + 1 R/W bit
            // =================================================

            WRITE_ADDR: begin

                sda_en <= 1'b1;

                case (pulse)

                    // SCL LOW
                    2'd0: begin
                        scl_t <= 1'b0;
                    end

                    // Put data on SDA while SCL LOW
                    2'd1: begin
                        scl_t <= 1'b0;
                        sda_t <= data_addr[7-bitcount];
                    end

                    // SCL HIGH
                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                    end

                endcase

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t <= 1'b0;

                    if (bitcount == 4'd7) begin

                        bitcount <= 0;

                        // Release SDA for slave ACK
                        sda_en <= 1'b0;

                        state <= ACK_1;
                    end

                    else begin
                        bitcount <= bitcount + 1'b1;
                    end
                end
            end


            // =================================================
            // ACK AFTER ADDRESS
            // =================================================

            ACK_1: begin

                // Slave owns SDA
                sda_en <= 1'b0;

                case (pulse)

                    2'd0,
                    2'd1: begin
                        scl_t <= 1'b0;
                    end

                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                    end

                endcase

                // Sample ACK during SCL HIGH
                if (pulse == 2'd2 &&
                    clk_count == 0) begin

                    r_ack <= sda;
                end

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t <= 1'b0;

                    if (r_ack == 1'b0) begin

                        bitcount <= 0;

                        if (data_addr[0] == 1'b0) begin

                            // WRITE
                            sda_en <= 1'b1;
                            state  <= WRITE_DATA;
                        end

                        else begin

                            // READ
                            sda_en <= 1'b0;
                            state  <= READ_DATA;
                        end
                    end

                    else begin

                        ack_err <= 1'b1;
                        sda_en  <= 1'b1;
                        sda_t   <= 1'b0;

                        state <= STOP;
                    end
                end
            end


            // =================================================
            // WRITE DATA
            // =================================================

            WRITE_DATA: begin

                sda_en <= 1'b1;

                case (pulse)

                    2'd0: begin
                        scl_t <= 1'b0;
                    end

                    2'd1: begin
                        scl_t <= 1'b0;
                        sda_t <= data_tx[7-bitcount];
                    end

                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                    end

                endcase

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t <= 1'b0;

                    if (bitcount == 4'd7) begin

                        bitcount <= 0;

                        // Release SDA for slave ACK
                        sda_en <= 1'b0;

                        state <= ACK_2;
                    end

                    else begin
                        bitcount <= bitcount + 1'b1;
                    end
                end
            end


            // =================================================
            // ACK AFTER WRITE DATA
            // =================================================

            ACK_2: begin

                sda_en <= 1'b0;

                case (pulse)

                    2'd0,
                    2'd1: begin
                        scl_t <= 1'b0;
                    end

                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                    end

                endcase

                if (pulse == 2'd2 &&
                    clk_count == 0) begin

                    r_ack <= sda;
                end

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t <= 1'b0;

                    if (r_ack != 1'b0)
                        ack_err <= 1'b1;

                    sda_en <= 1'b1;
                    sda_t  <= 1'b0;

                    state <= STOP;
                end
            end


          READ_DATA: begin
    sda_en <= 1'b0; // Release SDA; slave drives data

    case (pulse)
        2'd0, 2'd1: begin
            scl_t <= 1'b0;
        end

        2'd2: begin
            scl_t <= 1'b1;
        end

        2'd3: begin
            scl_t <= 1'b1;

            // Sample exactly once per bit.
            if (clk_count == QUARTER_COUNT/2) begin
                rx_data <= {rx_data[6:0], sda};
            end
        end
    endcase

    if (pulse == 2'd3 &&
        clk_count == QUARTER_COUNT-1) begin

        scl_t <= 1'b0;

        if (bitcount == 4'd7) begin
            bitcount <= 0;
            state <= MASTER_ACK;
        end
        else begin
            bitcount <= bitcount + 1'b1;
        end
    end
end


            // =================================================
            // MASTER NACK
            //
            // Single-byte read:
            // Master sends NACK = SDA HIGH
            // =================================================

            MASTER_ACK: begin

                sda_en <= 1'b1;

                case (pulse)

                    2'd0,
                    2'd1: begin
                        scl_t <= 1'b0;
                        sda_t <= 1'b1;
                    end

                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                        sda_t <= 1'b1;
                    end

                endcase

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t <= 1'b0;

                    // Prepare STOP
                    sda_t <= 1'b0;

                    state <= STOP;
                end
            end


            // =================================================
            // STOP CONDITION
            //
            // SDA: LOW -> HIGH
            // while SCL is HIGH
            // =================================================

            STOP: begin

                sda_en <= 1'b1;

                case (pulse)

                    2'd0,
                    2'd1: begin
                        scl_t <= 1'b1;
                        sda_t <= 1'b0;
                    end

                    2'd2,
                    2'd3: begin
                        scl_t <= 1'b1;
                        sda_t <= 1'b1;
                    end

                endcase

                if (pulse == 2'd3 &&
                    clk_count == QUARTER_COUNT-1) begin

                    scl_t <= 1'b0;
                    sda_t <= 1'b1;

                    sda_en <= 1'b0;

                    busy <= 1'b0;
                    done <= 1'b1;

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

    assign dout = rx_data;

endmodule
