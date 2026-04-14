# Batch mode: run to completion.
# GUI mode: load a useful default wave layout for axi_crossbar_tb.
if {[info command guiIsActive] == ""} {
  run
} else {
  echo "GUI mode"
  dump -add / -depth 0
  do ./axicb_debug_wave.do
}
