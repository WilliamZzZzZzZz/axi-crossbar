`ifndef AXI_TYPES_SV
`define AXI_TYPES_SV

    localparam int DATA_WIDTH    = 32;
    localparam int ADDR_WIDTH    = 32;
    localparam int ID_WIDTH      = 8;
    localparam int M_ID_WIDTH    = ID_WIDTH + 1;
    localparam int STRB_WIDTH    = (DATA_WIDTH/8);
    localparam int QOS_WIDTH     = 4;
    localparam int REGION_WIDTH  = 4;
    localparam int AWUSER_WIDTH  = 1;
    localparam int WUSER_WIDTH   = 1;
    localparam int BUSER_WIDTH   = 1;
    localparam int ARUSER_WIDTH  = 1;
    localparam int RUSER_WIDTH   = 1;

    typedef enum bit {
        WRITE = 0,
        READ  = 1
    } trans_type_enum;

    typedef enum bit[7:0] {
        BURST_LEN_SINGLE  = 8'b00000000,
        BURST_LEN_DOUBLE  = 8'b00000001,
        BURST_LEN_3BEATS  = 8'b00000010,
        BURST_LEN_4BEATS  = 8'b00000011,
        BURST_LEN_5BEATS  = 8'b00000100,
        BURST_LEN_6BEATS  = 8'b00000101,
        BURST_LEN_7BEATS  = 8'b00000110,
        BURST_LEN_8BEATS  = 8'b00000111,
        BURST_LEN_16BEATS = 8'b00010001
    } burst_len_enum;

    typedef enum bit[2:0] {
        BURST_SIZE_1BYTE     = 3'b000,
        BURST_SIZE_2BYTES    = 3'b001,
        BURST_SIZE_4BYTES    = 3'b010,
        BURST_SIZE_8BYTES    = 3'b011,
        BURST_SIZE_16BYTES   = 3'b100,
        BURST_SIZE_32BYTES   = 3'b101,
        BURST_SIZE_64BYTES   = 3'b110,
        BURST_SIZE_128BYTES  = 3'b111
    } burst_size_enum;

    typedef enum bit[1:0] {
        FIXED = 2'b00,
        INCR  = 2'b01,
        WRAP  = 2'b10
    } burst_type_enum;

    typedef enum bit {
        NORMAL    = 0,
        EXCLUSIVE = 1
    } lock_type_enum;

    typedef enum bit[3:0] {
        NONBUFFER = 4'b0000,
        BUFFER    = 4'b0001
    } cache_type_enum;
    
    //somke test only
    typedef enum bit[2:0] {
        NPRI_SEC_DATA = 3'b000,
        NPRI_SEC_INST = 3'b001
    } prot_type_enum;

    typedef enum bit[1:0] {
        OKAY   = 2'b00,
        EXOKAY = 2'b01,
        SLVERR = 2'b10,
        DECERR = 2'b11
    } resp_type_enum;

`endif 