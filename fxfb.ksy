meta:
  id: fxfb
  title: FXF Chart Bundle
  file-extension: fxfb
  endian: le
  imports: fxf
seq:
  - id: version
    type: u4
  - id: chart
    type: fxf
  - id: resources
    type: s4
    repeat: eos
