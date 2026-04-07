`ifndef LVC_AXI_TYPES_SV
`define LVC_AXI_TYPES_SV

// AXI Burst Type
typedef enum bit [1:0] {
  AXI_BURST_FIXED    = 2'b00,  // Fixed burst - address remains constant
  AXI_BURST_INCR     = 2'b01,  // Incrementing burst
  AXI_BURST_WRAP     = 2'b10,  // Wrapping burst
  AXI_BURST_RESERVED = 2'b11   // Reserved
} lvc_axi_burst_type_e;

// AXI Response Type
typedef enum bit [1:0] {
  AXI_RESP_OKAY   = 2'b00,  // Normal access success
  AXI_RESP_EXOKAY = 2'b01,  // Exclusive access success
  AXI_RESP_SLVERR = 2'b10,  // Slave error
  AXI_RESP_DECERR = 2'b11   // Decode error
} lvc_axi_resp_type_e;

// AXI Lock Type
typedef enum bit {
  AXI_LOCK_NORMAL    = 1'b0,
  AXI_LOCK_EXCLUSIVE = 1'b1
} lvc_axi_lock_type_e;

// AXI Transfer Size
typedef enum bit [2:0] {
  AXI_SIZE_1BYTE   = 3'b000,  // 1 byte
  AXI_SIZE_2BYTES  = 3'b001,  // 2 bytes
  AXI_SIZE_4BYTES  = 3'b010,  // 4 bytes
  AXI_SIZE_8BYTES  = 3'b011,  // 8 bytes
  AXI_SIZE_16BYTES = 3'b100,  // 16 bytes
  AXI_SIZE_32BYTES = 3'b101,  // 32 bytes
  AXI_SIZE_64BYTES = 3'b110,  // 64 bytes
  AXI_SIZE_128BYTES= 3'b111   // 128 bytes
} lvc_axi_size_e;

// AXI Transaction Type
typedef enum bit {
  AXI_READ  = 1'b0,
  AXI_WRITE = 1'b1
} lvc_axi_trans_type_e;

// AXI Cache Type
typedef struct packed {
  bit bufferable;
  bit cacheable;
  bit read_allocate;
  bit write_allocate;
} lvc_axi_cache_t;

// AXI Protection Type
typedef struct packed {
  bit privileged;     // 0: Unprivileged, 1: Privileged
  bit non_secure;     // 0: Secure, 1: Non-secure
  bit instruction;    // 0: Data, 1: Instruction
} lvc_axi_prot_t;

`endif // LVC_AXI_TYPES_SV
