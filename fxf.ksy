meta:
  id: fxf
  title: FXF Chart File
  file-extension: fxf
  endian: le
seq:
  - id: data
    type: fxf
types:
  fxf:
    seq:
    - id: version
      type: u4
    - id: title
      type: strz
      encoding: UTF-8
    - id: artist
      type: strz
      encoding: UTF-8
    - id: audio
      type: strz
      encoding: UTF-8
    - id: jacket
      type: strz
      encoding: UTF-8
    - id: offset
      type: s4
    - id: num_bpm
      type: u4
    - id: bpm_change
      type: bpm_change
      repeat: expr
      repeat-expr: num_bpm
    - id: charts
      type: charts
  bpm_change:
    seq:
      - id: bpm
        type: f4
      - id: time
        type: f4
      - id: snap_size
        type: u2
      - id: snap_index
        type: u2
  charts:
    seq:
      - id: bsc_present
        type: u1
      - id: adv_present
        type: u1
      - id: ext_present
        type: u1
      - id: basic
        type: chart
        if: bsc_present != 0
      - id: advanced
        type: chart
        if: adv_present != 0
      - id: extreme
        type: chart
        if: ext_present != 0
  chart:
    seq:
      - id: rating
        type: u4
      - id: num_tick
        type: u4
      - id: ticks
        type: tick
        repeat: expr
        repeat-expr: num_tick
  tick:
    seq:
      - id: time
        type: f4
      - id: snap_size
        type: u2
      - id: snap_index
        type: u2
      - id: num_notes
        type: u1
      - id: notes
        type: u1
        repeat: expr
        repeat-expr: num_notes
      - id: num_holds
        type: u1
      - id: holds
        type: hold
        repeat: expr
        repeat-expr: num_holds
  hold:
    seq:
      - id: from
        type: u1
      - id: to
        type: u1
      - id: release_on
        type: f4
