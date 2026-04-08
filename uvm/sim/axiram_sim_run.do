# Crossbar smoke run script
if {[info command guiIsActive]==""} {
  run
} else {
  echo "GUI mode"
  dump -add /axiram_tb -depth 3
  do ./axiram_debug_wave.do
}
