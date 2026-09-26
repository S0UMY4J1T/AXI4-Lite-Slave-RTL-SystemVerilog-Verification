interface axi_if;
    logic clk, resetn;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic arvalid, arready, rvalid, rready;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [1:0]  bresp, rresp;

    modport drv (
        input clk, awready, wready, bvalid, bresp,
        input arready, rvalid, rdata, rresp,
        output resetn, awvalid, awaddr, wvalid, wdata, bready,
        output arvalid, araddr, rready
    );

    modport mon (
        input clk, resetn, awvalid, awready, wvalid, wready, bvalid, bready, bresp,
        input arvalid, arready, rvalid, rready, awaddr, wdata, araddr, rdata, rresp
    );
endinterface

class transaction;
    randc bit        op;
    rand  bit [31:0] awaddr;
    rand  bit [31:0] wdata;
    rand  bit [31:0] araddr;
          bit [31:0] rdata;
          bit [1:0]  bresp;
          bit [1:0]  rresp;

  constraint valid_addr_range { awaddr < 20 ; araddr < 20; }
  constraint valid_data_range { wdata < 100; }
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbxgd;
    event done;  // genrator specified no of transaction sending is done
    event compareDone; // scorebboard checking is done
    int count = 0;

    function new (mailbox #(transaction) mbxgd);
        this.mbxgd = mbxgd;
        tr = new(); 
    endfunction

    task run();
        for(int i=0; i<count; i++) begin
            assert (tr.randomize) else $error ("Randomization Failed");
            $display("[GEN]: op:%0b | awaddr:%0d | araddr:%0d | wdata:%0d | rdata:%0d",
                                  tr.op, tr.awaddr, tr.araddr, tr.wdata, tr.rdata);
            mbxgd.put(tr);
            @(compareDone);
        end
        -> done;
    endtask
endclass

class driver;
    virtual axi_if.drv intf;
    transaction tr;
    mailbox #(transaction) mbxgd;
    mailbox #(transaction) mbxdm; // for checking
    
    function new(mailbox #(transaction) mbxgd, mailbox #(transaction) mbxdm, virtual axi_if.drv intf);
        this.mbxgd = mbxgd;
        this.mbxdm = mbxdm;
        this.intf = intf;
    endfunction

    task reset();
        intf.resetn = 0;
        intf.awvalid = 0;
        intf.awaddr = 0;
        intf.wvalid = 0;
        intf.wdata = 0;
        intf.bready = 0;
        intf.arvalid = 0;
        intf.araddr = 0;
        intf.rready = 0;
        repeat(5) @(posedge intf.clk);
        intf.resetn = 1;
        $display("----------------[DRV] : RESET DONE------------------");
    endtask

    task write_data(input transaction tr);
        mbxdm.put(tr);
        $display("[DRV]: op:%0b | awaddr:%0d | wdata:%0d ",
                                tr.op, tr.awaddr, tr.wdata);
        intf.resetn <= 1;
        intf.arvalid <= 0;  // disable read
        intf.araddr <= 0;
        intf.awvalid <= 1;  // enable write
        intf.awaddr <= tr.awaddr;  // send address
        @(negedge intf.awready);
        intf.awvalid <= 0;
        intf.awaddr <= 0; 
        
        intf.wvalid <= 1;
        intf.wdata <= tr.wdata;  // send data
        @(negedge intf.wready);
        intf.wvalid <= 0;
        intf.wdata <= 0;

        intf.bready <= 1;
        intf.rready <= 0;
        @(negedge intf.bvalid);
        intf.bready <= 0;
    endtask

    task read_data(input transaction tr);
        mbxdm.put(tr);
        $display("[DRV]: op:%0b | araddr:%0d | rdata:%0d",
                                  tr.op, tr.araddr, tr.rdata);
        intf.resetn <= 1;
        intf.awvalid <= 0;  // disable write
        intf.awaddr <= 0;  
        intf.wvalid <= 0;
        intf.wdata <= 0;
        intf.bready <= 0;
        intf.arvalid <= 1;  // enable read
        intf.araddr <= tr.araddr; // send address
        @(negedge intf.arready);
        intf.arvalid <= 0;
        intf.araddr <= 0;

        intf.rready <= 1;
        @(negedge intf.rvalid);
        intf.rready <= 0;

    endtask    

    task run();
        forever begin
            mbxgd.get(tr);
            @(posedge intf.clk);
            if(tr.op) write_data(tr);
            else read_data(tr);
        end
    endtask
endclass

class monitor;
    virtual axi_if.mon intf;
    transaction tr;
    mailbox #(transaction) mbxdm;
    mailbox #(transaction) mbxms;

    function new(mailbox #(transaction) mbxdm, mailbox #(transaction) mbxms, virtual axi_if.mon intf);
        this.mbxdm = mbxdm;
        this.mbxms = mbxms;
        this.intf = intf;
    endfunction

    task run();
        forever begin
            @(posedge intf.clk);
            mbxdm.get(tr);
            if(tr.op == 1) begin
                @(posedge intf.bvalid);
                tr.bresp = intf.bresp;
                @(negedge intf.bvalid);
                $display("[MON]: op:%0b | awaddr:%0d | wdata:%0d | bresp:%0d",
                                    tr.op, tr.awaddr, tr.wdata, tr.bresp);
                mbxms.put(tr);
            end else begin
                @(posedge intf.rvalid);
                tr.rdata = intf.rdata;
                tr.rresp = intf.rresp;
                @(negedge intf.rvalid);
                $display("[MON]: op:%0b | araddr:%0d | rdata:%0d | rresp:%0d",
                                    tr.op, tr.araddr, tr.rdata, tr.rresp);
                mbxms.put(tr);
            end 
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mbxms;
    event compareDone;

    function new(mailbox #(transaction) mbxms);
        this.mbxms = mbxms;
    endfunction

    bit[31:0] temp;
    bit[31:0] data [128] = '{default:0};

    task run();
        forever begin
            mbxms.get(tr);
            if (tr.op) begin
                // $display("[SCO]: op:%0b | awaddr:%0d | wdata:%0d | bresp:%0d",
                //                     tr.op, tr.awaddr, tr.wdata, tr.bresp);
                if(tr.bresp == 3) $display("[SCO]: DECODE ERROR !!!");
                else begin
                    data[tr.awaddr] = tr.wdata;
                    $display("[SCO]: DATA STORED AT ADDR: %0d AND DATA: %0d", tr.awaddr, data[tr.awaddr]);
                end
            end else begin
                // $display("[SCO]: op:%0b | araddr:%0d | rdata:%0d | rresp:%0d",
                //                     tr.op, tr.araddr, tr.rdata, tr.rresp);
                temp = data[tr.araddr];
                if(tr.rresp == 3) $display("[SCO]: DECODE ERROR !!!");
                else if (tr.rresp == 0 && tr.rdata == temp) $display("[SCO]: RESULTS MATCHED");
                else $display("[SCO]: RESULTS MISMATCHED");
            end
            $display("-----------------------------------------------------------");
            -> compareDone;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    mailbox #(transaction) mbxgd, mbxdm, mbxms;

    function new(virtual axi_if.drv intf_drv, virtual axi_if.mon intf_mon);
        mbxgd = new();
        mbxdm = new();
        mbxms = new();

        gen = new(mbxgd);
        drv = new(mbxgd, mbxdm, intf_drv);
        mon = new(mbxdm, mbxms, intf_mon);
        sco = new(mbxms);
        
        gen.compareDone = sco.compareDone;
    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test(); 
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask

    task post_test();
        wait (gen.done.triggered);
        $finish;
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask
endclass

module tb;
    environment env;
    axi_if intf();

    axilite_s dut(
        .s_axi_aclk    (intf.clk),
        .s_axi_aresetn (intf.resetn),

        .s_axi_awvalid (intf.awvalid),
        .s_axi_awready (intf.awready),
        .s_axi_awaddr  (intf.awaddr),

        .s_axi_wvalid  (intf.wvalid),
        .s_axi_wready  (intf.wready),
        .s_axi_wdata   (intf.wdata),

        .s_axi_bvalid  (intf.bvalid),
        .s_axi_bready  (intf.bready),
        .s_axi_bresp   (intf.bresp),

        .s_axi_arvalid (intf.arvalid),
        .s_axi_arready (intf.arready),
        .s_axi_araddr  (intf.araddr),

        .s_axi_rvalid  (intf.rvalid),
        .s_axi_rready  (intf.rready),
        .s_axi_rdata   (intf.rdata),
        .s_axi_rresp   (intf.rresp)
    );
 
    initial intf.clk = 0;
    always #5 intf.clk = ~intf.clk;

    initial begin
        env = new(intf,intf);
        env.gen.count = 50;
        env.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule