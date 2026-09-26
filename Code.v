module axilite_s(
    input  wire         s_axi_aclk,
    input  wire         s_axi_aresetn,
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,
    input  wire [31: 0] s_axi_awaddr,

    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,
    input  wire [31: 0] s_axi_wdata,

    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,
    output reg  [1: 0]  s_axi_bresp,

    input wire          s_axi_arvalid,  
    output reg          s_axi_arready,
    input wire [31: 0]  s_axi_araddr,

    output reg          s_axi_rvalid,
    input wire          s_axi_rready,
    output reg [31: 0]  s_axi_rdata,
    output reg  [1: 0]  s_axi_rresp
    );

    localparam idle = 0,
               W_send_addr_ack = 1,
               W_send_data_ack = 2,
               W_update_mem = 3,
               W_send_resp = 4,
               W_send_err = 5,
               R_send_addr_ack = 6,
               R_fetch_data = 7,
               R_send_err = 8 ;

    reg [3:0] state = idle;
    reg [1:0] count = 0; // for data fetching
    reg [31:0] waddr, raddr, wdata, rdata; // temp variables
    reg [31:0] mem[128]; // 128 registers each of 32 bits
    int mem_max_addr = 128;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state = idle;
            for (int i=0; i<128; i++) mem[i] = 0;
            s_axi_awready <= 0;
            s_axi_wready <= 0;
            s_axi_bvalid <= 0;
            s_axi_bresp <= 0;
            s_axi_arready <= 0;
            s_axi_rvalid <= 0;
            s_axi_rdata <= 0;
            s_axi_rresp <= 0;
            waddr <= 0;
            raddr <= 0;
            wdata <= 0;
            rdata <= 0;
            count <= 0;
        end 
        else begin
        case(state) 
            idle: begin
                s_axi_awready <= 0;
                s_axi_wready <= 0;
                s_axi_bvalid <= 0;
                s_axi_bresp <= 0;
                s_axi_arready <= 0;
                s_axi_rvalid <= 0;
                s_axi_rdata <= 0;
                s_axi_rresp <= 0;
                waddr <= 0;
                raddr <= 0;
                wdata <= 0;
                rdata <= 0;
                count <= 0;
                s_axi_rvalid <= 0;

                if(s_axi_awvalid == 1) begin
                    state <= W_send_addr_ack;
                    waddr <= s_axi_awaddr;
                    s_axi_awready <= 1;
                end
                else if (s_axi_arvalid == 1) begin
                    state <= R_send_addr_ack;
                    raddr <= s_axi_araddr;
                    s_axi_arready <= 1;
                end
                else begin
                    state <= idle;
                end
            end
            W_send_addr_ack: begin
                s_axi_awready <= 0;
                if (s_axi_wvalid) begin
                    wdata <= s_axi_wdata;
                    state <= W_send_data_ack;
                    s_axi_wready <= 1;
                end 
                else state <= W_send_addr_ack; 
            end
            W_send_data_ack: begin
                s_axi_wready <= 0;
                if (waddr < mem_max_addr) begin
                    state <= W_update_mem;
                end
                else begin
                    state <= W_send_err;
                end
            end
            W_update_mem: begin
                mem[waddr] <= wdata;
                state <= W_send_resp;
            end
            W_send_resp: begin
                s_axi_bresp <= 2'b00;    // No error
                s_axi_bvalid <= 1;
                if(s_axi_bready) state <= idle;
                else state <= W_send_resp;
            end
            W_send_err: begin
                s_axi_bresp <= 2'b11;   // decode error
                s_axi_bvalid <= 1;
                if(s_axi_bready) state <= idle;
                else state <= W_send_err;
            end
            R_send_addr_ack: begin
                s_axi_arready <= 0;
                if(raddr < mem_max_addr) state <= R_fetch_data;
                else state <= R_send_err;
            end
            R_fetch_data: begin
                if(count<2) begin
                    rdata <= mem[raddr];
                    count <= count + 1;
                    state <= R_fetch_data;
                end
                else begin
                    s_axi_rdata <= rdata;
                    s_axi_rresp <= 2'b00;
                    s_axi_rvalid <= 1;
                    if (s_axi_rready) state <= idle;
                    else state <= R_fetch_data;
                end
            end
            R_send_err: begin
                s_axi_rdata <= 0;
                s_axi_rresp <= 2'b11;  // decode error
                s_axi_rvalid <= 1;
                if (s_axi_rready) state <= idle;
                else state <= R_send_err;
            end
        endcase
        end
    end
endmodule