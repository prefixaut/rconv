type
    NoteRange* = range[0..15] ## \
    ## Range of note indices which need to be pressed/held at some time.
    ## e.g. [3, 10] -> button 3 and 10 need to be pressed.
    ##
    ## This file format indexes buttons starting from 0 to 15::
    ##
    ##  0  1  2  3
    ##  4  5  6  7
    ##  8  9  10 11
    ##  12 13 14 15
    ##

    RowIndex* = range[0..3] ## \
    ## Range of how many row-indices may exist (4).
